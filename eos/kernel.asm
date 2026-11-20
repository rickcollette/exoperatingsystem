* EOS (Extendable Operating System): RAM resident kernel, $0700 up to MEMLO
*
* Assembled on its own into a flat image that the boot bank copies to $0700.
* The cartridge banks include the label file of this assembly
* (build/eos/kernel.icl), so they can call into it directly; the kernel
* reaches code in the banks only through farcall and the bank jump tables.

        icl 'equ.icl'

        opt h-f+

* ---- page 7 -------------------------------------------------------------
        org $0700
        dta c'S'               ; $0700 SpartaDOS
        dta b($45)             ; $0701 version 4.5, as SDX 4.5 reports
        dta b($00)             ; $0702 subversion
        jmp k_kernel           ; $0703 jkernel
        jmp k_blkio            ; $0706 jblock_io
        jmp k_misc             ; $0709 jmisc
        jmp k_secio            ; $070C jsector_io
        jmp k_hwctrl           ; $070F jhwctrl
        org $0718
        dta a(0,0,0,k_hsdrv)   ; $0718 sio_vector: high speed SIO in the last
        org $0740
        :16 dta b($FF)         ; $0740 dev_index: device of each open file
        dta a(kd_dsk)          ; $0750 dev_vector, in DEVNAME order
        dta a(kd_clk)
        dta a(kd_car)
        dta a(kd_con)
        dta a(kd_prn)
        dta a(kd_nul)
        dta a(0,0)
        org $0760
        :128 dta b(0)          ; $0760 kernel parameter table
        org $07E0
        jmp k_rts              ; $07E0
        dta a(COMTAB_ADR)      ; $07E3 vdos
        dta a(k_rts)           ; $07E5
        dta a(k_rts)           ; $07E7
        dta a(k_rts)           ; $07E9
        jmp k_jfsym            ; $07EB jfsymbol
        jmp k_rts              ; $07EE
        jmp setme              ; $07F1 V_setme
        jmp popme              ; $07F4 V_popme
        jmp k_setmx            ; $07F7 memory index A in, the last one out
        jmp k_rts              ; $07FA
        jmp k_rts              ; $07FD

* ---- kernel code ---------------------------------------------------------
        org $0800

* currently selected cartridge bank, CARTOFF when the cartridge is off
curbank dta b(BK_BOOT)

* select bank A (CARTOFF switches the cartridge off); keeps X and Y
setbank sta curbank
        stx sb_x
        tax
.ifdef SIDE
        ora #$40               ; (SIDE: the top cartridge off as well)
        sta BANKLATCH
.elseif .def MYIDE2
        bmi sb_off             ; MyIDE II: the page, then the left window
        sta $D508              ; on as flash, or every window off
        lda #$3C
        bne sb_w
sb_off  lda #$FC
sb_w    sta $D50F
.elseif .def SIDE3
        bmi sb_off             ; SIDE3: the windows first, then bank B
        lda #$E8               ; (its high bits are taken when $D5F9 is
        sta $D5FA              ; written)
        txa
        ora #$C0
        sta $D5F9
        bne sb_x1
sb_off  lda #$E0
        sta $D5FA
sb_x1
.elseif .def BANKLATCH
        sta BANKLATCH          ; (U1MB, SIC!: the bank is the value)
.else
        sta MAXBANK,x
.endif
        ldx sb_x
k_rts   rts
sb_x    dta b(0)

* far call into a cartridge bank, from RAM or from any bank:
*       jsr farcall
*       dta b(bank),a(address)
* A, X, Y and the flags pass through to the callee and back to the caller;
* the caller's bank is selected again on return
farcall sta fc_a
        stx fc_x
        php
        pla
        sta fc_p
        pla                    ; return address = parameters - 1
        sta fc_rd+1
        pla
        sta fc_rd+2
        clc                    ; caller continues after the parameters
        lda fc_rd+1
        adc #3
        tax
        lda fc_rd+2
        adc #0
        pha
        txa
        pha
        lda curbank
        pha
        ldx #3
fc_rd   lda $FFFF,x
        sta fc_par-1,x
        dex
        bne fc_rd
        lda fc_par+1
        sta fc_jsr+1
        lda fc_par+2
        sta fc_jsr+2
        lda fc_par
        jsr setbank
        ldx fc_x
        lda fc_p
        pha
        lda fc_a
        plp
fc_jsr  jsr $FFFF
        php
        sta fc_a
        pla
        sta fc_p
        pla
        jsr setbank
        lda fc_p
        pha
        lda fc_a
        plp
        rts
fc_a    dta b(0)
fc_x    dta b(0)
fc_p    dta b(0)
fc_par  dta b(0),a(0)

* kernel entry (jkernel): Y = function code,
* parameters in the page 7 table. Functions 0-7 work on the open file
* file_id, the others on device; from 11 on file_id is forced to $FF. The
* status comes back in A (negative: error) with the flags set from it.
k_kernel cpy #11
        bcc kk_file
        lda #$FF
        sta file_id
kk_dev  lda device
        jmp kk_go
kk_file cpy #8
        bcs kk_dev
        ldx file_id
        cpx #16
        bcs kk_badh
        lda dev_index,x
        cmp #$FF
        bne kk_go
kk_badh lda #134               ; invalid handle
        rts
kk_nodev lda #130              ; non-existent device
        rts
kk_go   pha                    ; device byte, for open/close bookkeeping
        lsr @
        lsr @
        lsr @
        lsr @
        asl @
        tax
        lda dev_vector,x
        sta kk_jmp+1
        lda dev_vector+1,x
        sta kk_jmp+2
        ora kk_jmp+1
        bne kk_call
        pla
        jmp kk_nodev
kk_call tya
        pha
kk_jmp  jsr $FFFF
        sta kk_st
        pla
        tay
        pla
        tax                    ; X = device byte
        lda kk_st
        bpl kk_ok
        cpy #10                ; kd_first finding nothing keeps its handle
        bne kk_ret
        cmp #136
        bne kk_ret
kk_ok   cpy #9                 ; kd_open, kd_first: register the handle
        beq kk_reg
        cpy #10
        beq kk_reg
        cpy #7                 ; kd_close: free it
        bne kk_ret
        ldx #$FF
kk_reg  txa
        ldx file_id
        sta dev_index,x
        lda SYSLEVEL           ; FCLOSEAL closes it at this level and above
        sta f_level,x
kk_ret  lda kk_st
        rts
kk_st   dta b(0)

* ---- RAM under the OS ROM ---------------------------------------------------
* k_romoff: the OS ROM off (RAM at $C000-$CFFF, $D800-$FFFF); k_romon: back
* as before. Both keep A, X, Y and the flags.
k_romoff php
        pha
        lda PORTB
        sta k_pbsave
        and #$FE
        sta PORTB
        pla
        plp
        rts
k_romon php
        pha
        lda k_pbsave
        sta PORTB
        pla
        plp
        rts
k_pbsave dta b($FF)

* interrupts while the ROM is off arrive here (vectors under the ROM): the
* OS handler runs with the ROM on and returns to k_irqr, which turns it off
* again. The status pushed for the OS has B clear (not a BRK).
k_nmi   pha
        lda PORTB
        pha
        ora #$01
        sta PORTB
        lda #>k_irqr
        pha
        lda #<k_irqr
        pha
        lda #$24
        pha
        jmp ($FFFA)
k_irq   pha
        lda PORTB
        pha
        ora #$01
        sta PORTB
        lda #>k_irqr
        pha
        lda #<k_irqr
        pha
        lda #$24
        pha
        jmp ($FFFE)
k_irqr  pla
        sta PORTB
        pla
        rti

* CIO handler for D: (Atari OS handler table, installed in HATABS at boot)
k_dhand dta a(kc_open-1,kc_close-1,kc_get-1,kc_put-1,kc_stat-1,kc_spec-1)
        jmp k_rts
kc_open jsr farcall
        dta b(BK_DEV),a(CARTLO+$09)
        rts
kc_close jsr farcall
        dta b(BK_DEV),a(CARTLO+$0C)
        rts
kc_stat jsr farcall
        dta b(BK_DEV),a(CARTLO+$15)
        rts
kc_spec jsr farcall
        dta b(BK_DEV),a(CARTLO+$18)
        rts

* kernel devices: drivers in the cartridge banks
kd_dsk  jsr farcall
        dta b(BK_FMS),a(CARTLO)
        rts
kd_con  jsr farcall
        dta b(BK_DEV),a(CARTLO)
        rts
kd_prn  jsr farcall
        dta b(BK_DEV),a(CARTLO+3)
        rts
kd_nul  jsr farcall
        dta b(BK_DEV),a(CARTLO+6)
        rts
kd_clk  jsr farcall
        dta b(BK_DEV),a(CARTLO+$1B)
        rts

k_nofunc lda #146              ; function not implemented
        rts

* k_trap: U_FAIL into a trap (U_SFAIL): the trap's bank in A, then its
* handler (ke_adr) with the error code in A and N=1
k_trap  jsr setbank
        lda uf_err
        jmp (ke_adr)

* jmisc: the misc_ interface, in the library bank
k_misc  jsr farcall
        dta b(BK_LIB),a(CARTLO+$1E)
        rts


setme   jmp k_setme            ; V_setme / V_popme: after COMTAB
popme   jmp k_popme

* read a command line from E: into LBUF; returns the CIO status in Y
* (tools/eos_test.py breaks here: the prompt is on the screen)
k_getline ldx #0
        lda #C_GETR
        sta IOCB0+ICCOM
        lda #<(COMTAB+CT_LBUF)
        sta IOCB0+ICBAL
        lda #>(COMTAB+CT_LBUF)
        sta IOCB0+ICBAH
        lda #64
        sta IOCB0+ICBLL
        lda #0
        sta IOCB0+ICBLH
        jmp CIOV

* DOSINI: the cartridge run vector does the reset work
* DOSINI: at a reset, before the resident programs that chained to it put
* their own back (RHND850's R:), MEMLO, D: and the S_ADDIZ routines
k_dosini jsr kb_leave           ; (a BW-DOS program's page 7 goes)
        lda WARMST
        beq kdi_r
        jsr farcall
        dta b(BK_BOOT),a(CARTLO+$06)
kdi_r   rts

* DOSVEC target: (re)enter the command processor in its bank (from BASIC's
* DOS too: the internal BASIC goes off again)
k_cp    lda PORTB
        ora #$02
        sta PORTB
        lda #1
        sta BASICF
        lda #BK_CP
        jsr setbank
        jmp CARTLO

* k_coldn: COLD /N: the cartridge off, then the OS's cold start (a boot
* disk boots, as without cartridges)
k_coldn lda #CARTOFF
        jsr setbank
        jmp COLDSV

kcode_end equ *
        ert kcode_end>COMTAB_ADR-$30

* ---- COMTAB ($0A3A on SDX 4.5) -------------------------------------------
        org COMTAB_ADR-$30
        :$25 dta b(0)
        jmp k_lsio             ; COMTAB-11 lsio: jsector_io to main memory
        dta b(0)
        dta b($FF)             ; COMTAB-7: no batch file here (SC reads it)
        :4 dta b(0)            ; COMTAB-6 divend
k_wrtcmd dta c'P'              ; COMTAB-2 WRTCMD: SIO write command, P or W (VERIFY)
        dta b(0)
COMTAB  jmp k_cpx              ; +$00 COMTAB: enter the command processor
        jmp k_crunch           ; +$03 ZCRNAME (_CRUNCH)
        dta a(k_rts)           ; +$06 DIVIO
        dta a(k_rts)           ; +$08 XDIVIO
        dta b(0)               ; +$0A BUFOFF
        dta a($0700)           ; +$0B ZORIG
        dta b(1,1,25)          ; +$0D DATER
        dta b(0,0,0)           ; +$10 TIMER
        dta b(1,1,25)          ; +$13 ODATER
        dta b(0,0,0)           ; +$16 OTIMER
        dta b(0)               ; +$19 TDOVER
        dta b(0)               ; +$1A FILLEN
        dta b(0)               ; +$1B _800FLG
        dta b(0)               ; +$1C PBMASK
        dta b(0)               ; +$1D NBANKS
        dta b(0)               ; +$1E BANKFLG
        dta b($FE)             ; +$1F OSRMFLG ($FE on SDX with USE OSRAM)
        dta b(0)               ; +$20
        dta c'D1:',b(EOL)      ; +$21 COMFNAM, 30 bytes
        :26 dta b(0)
        :64 dta b(EOL)         ; +$3F LBUF
        :$80 dta b(0)          ; +$7F ... +$FE
        ert *<>COMTAB+$FF
        ert COMTAB<>COMTAB_ADR

* ---- after COMTAB --------------------------------------------------------

        :12 dta b(0)           ; +$FF MUL_32/DIV_32 operands and result

* COMTAB2, with the values
* real SDX has on a 64K 6502 machine
        dta b(1)               ; -6 CPU clock in 100% (MACH.COM prints it)
        dta b(0)               ; -5 _SEGBEG: no 65816 high RAM
        dta b(0)               ; -4 _SEGCNT
        dta b(0)               ; -3 _EXTBNK: extended memory banks found
        dta b(0)               ; -2 _EXTTYP: bit 7 Axlon
        dta b($05)             ; -1 micro-buffers on: DSK, CAR
COMTAB2 dta b(0)               ; +0 _816FLG: 6502
        dta b($01)             ; +1 (as on SDX)
        dta b(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15) ; +2 sio_index

* maptab (_MAPTAB, CAR:MAP): MAP's own table, apart from SWAP's sio_index
* (as SDX keeps them): the disk unit each unit 1-15 reaches, then each
* one's mode (0 normal: PBI devices, then SIO; 2 SIO: no PBI device; 4
* OFF: no answer, 138). k_secio applies them to $31 requests (the speed
* is SIOSET's). Kept over a RESET.
maptab  dta b(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15)
        :15 dta b(0)

* kernel devices: names in dev_vector order
        dta b(8)               ; DEVSPEC-1: number of entries
DEVSPEC :8 dta b(0)
DEVNAME dta c'DSK CLK CAR CON PRN NUL         '

* library variables exported as symbols
FILE_P  dta a(COMTAB+CT_COMFNAM) ; file specification for the library
FLAG    dta b(0)               ; U_LOAD control
CURDEV  dta b($01)             ; current device (DSK1)
SYSLEVEL dta b(0)
INSTALL dta b(0)
EXTENDED :19 dta b(0)          ; +0 memory index used by the loader, +1 its
                               ; blocks, +3 each block's index (PG 3.7.4)
ENV_P   dta a(ENVBUF),b(2)     ; the environment: address, memory index
PUT_V   dta a(0)               ; vectored output: FPUTC to handle 100
SYMBOL  dta a(0)               ; RAM symbol list (newest first), then the ROM table
        :12 dta b(0)           ; +2 name, +$0A level, +$0B address (S_LOOKUP ...)

* jfsymbol ($07EB): AX = the space padded name;
* found: Z=0, AX = its address, Y = memory index. Else Z=1.
k_jfsym sta fadr
        stx fadr+1
        ldy #7
kj1     lda (fadr),y
        sta ld_name,y
        dey
        bpl kj1
        jsr farcall
        dta b(BK_LD),a(LD_LOOKUP)
        bcs kj_no
        lda ld_val
        ldx ld_val+1
        ldy #0
        cpy #1                 ; Z=0
        rts
kj_no   lda #0
        rts

* kd_initz for every installed device (cold and warm start)
k_initz ldx #0
ki1     stx ki_x
        txa                    ; X = 2 * device number
        asl @
        asl @
        asl @
        ora #1
        sta device
        lda dev_vector+1,x
        beq ki2
        ldy #8
        jsr jkernel
ki2     ldx ki_x
        inx
        inx
        cpx #16
        bcc ki1
        rts
ki_x    dta b(0)

* T_: memory index to register value, as on a 64K
* SDX: +0 Axlon, +4 PORTB for indices 0-3 (2: the RAM under the OS ROM),
* +8 PORTB bank bits for indices 4 and up
T_      dta b(0,0,0,0)
        dta b($FF,$FF,$FE,$FF)
        dta b($E3,$A3,$C3,$83,$E1,$A1,$C1,$81)
        dta b($63,$23,$43,$03,$61,$21,$41,$01)

* V_setme ($07F1): memory index A in, the previous setting kept on a stack
* (16 deep); keeps X, Y and the flags. V_popme ($07F4): the previous one
* back; keeps A, X, Y and the flags.
k_setme php
        stx vs_x
        pha
        lda PORTB
        ldx vs_sp
        sta vs_stk,x
        inx
        txa
        and #15
        sta vs_sp
        pla
        jsr k_tconv
        sta PORTB
        ldx vs_x
        plp
        rts
* k_rt8: register X of the R-Time 8 cartridge ($D5B8: two reads to resync,
* the register number, then its two BCD digits): A = the value, C=1 when
* the digits are not BCD (no clock). The AtariMax cartridge's control area
* is there too: its bank is selected again afterwards. Keeps Y.
k_rt8   lda RT8
        lda RT8
        stx RT8
        lda RT8
        and #$0F
        sta kr_h
        lda RT8
        and #$0F
        sta kr_l
        lda curbank
        jsr setbank
        lda kr_h
        cmp #10
        bcs kr8_no
        asl @                  ; tens * 10 + units
        sta kr_t
        asl @
        asl @
        adc kr_t
        adc kr_l
        ldx kr_l
        cpx #10
        rts                    ; C=1 when the units are not BCD
kr8_no  rts
kr_h    dta 0
kr_l    dta 0
kr_t    dta 0
RT8     equ $D5B8

* k_ownml: MEMLO as EOS itself set it for the running program (the loader,
* MALLOC): when the program ends with MEMLO elsewhere, the program set
* MEMLO itself (an old style resident driver) and it stays, as on SDX.
* Keeps A, X, Y.
k_ownml pha
        txa
        pha
        ldx SYSLEVEL
        beq ko1
        lda MEMLO
        sta ld_owl-1,x
        lda MEMLO+1
        sta ld_owh-1,x
ko1     pla
        tax
        pla
        rts


* ---- BW-DOS programs (lib2 bank, bw.icl) ------------------------------------
* k_cpx: DOSVEC (EOS's COMTAB and the BW-DOS one): a BW-DOS program that
* ends this way leaves its page 7 behind first
k_cpx   jsr kb_leave
        jmp k_cp
kb_leave bit bw_on
        bpl kb_r
        jsr farcall
        dta b(BK_LIB2),a(L2_BWLEAVE)
kb_r    rts

* k_bwdh: D: in HATABS while a BW-DOS program runs: EOS's page 7 is put
* back for the call (A, X, Y and the flags pass both ways)
k_bwdh  dta a(kb_open-1,kb_close-1,kb_get-1,kb_put-1,kb_stat-1,kb_spec-1)
        jmp k_rts
kb_open sta bw_a
        ldy #0
        beq kb_go
kb_close sta bw_a
        ldy #2
        bne kb_go
kb_get  ldy #4
        bne kb_go
kb_put  sta bw_a
        ldy #6
        bne kb_go
kb_stat ldy #8
        bne kb_go
kb_spec ldy #10
kb_go   sty bw_y               ; (lib2 bw.icl bw_go)
        jsr farcall
        dta b(BK_LIB2),a(L2_BWGO)
        rts

* the BW-DOS COMTAB's vectors
kb_fail pha                    ; BW_FAIL: the error in A, then the command
        jsr kb_leave           ; processor
        pla
        jsr farcall
        dta b(BK_LIB),a(L_FAIL)
kb_crn  jsr farcall            ; CRNAME
        dta b(BK_LIB2),a(L2_BWCRN)
        rts
kb_conv jsr farcall            ; CONVDC
        dta b(BK_LIB2),a(L2_BWCONV)
        rts
kb_gtd  jsr farcall            ; GETTD
        dta b(BK_LIB2),a(L2_BWGTD)
        rts
kb_std  jsr farcall            ; SETTD
        dta b(BK_LIB2),a(L2_BWSTD)
        rts

* k_rdfind: A = a drive: C=0 when it is a RAM disk (rd_cx = its entry);
* keeps A and Y
k_rdfind ldx #NRD-1
krf1    cmp rd_unit,x
        beq krf2
        dex
        bpl krf1
        sec
        rts
krf2    stx rd_cx
        clc
        rts

* k_siov: the OS's SIOV with the ROM on. Meanwhile the serial interrupts
* go to the OS's own routines (as at a cold start); a program's (an R:
* handler in concurrent mode) come back after, with its POKMSK and SKCTL
* (the OS's SIO leaves the serial interrupts off). Out: Y = status, N.
k_siov  lda PORTB
        pha
        ora #$01
        sta PORTB
        ldx #5
kv1     lda VSERIN,x
        sta kv_vs,x
        lda os_vs,x
        sta VSERIN,x
        dex
        bpl kv1
        lda POKMSK
        sta kv_pm
        lda SSKCTL
        sta kv_sk
        jsr SIOV
        php
        sei
        ldx #5
kv2     lda kv_vs,x
        sta VSERIN,x
        dex
        bpl kv2
        lda kv_pm
        sta POKMSK
        sta IRQEN
        lda kv_sk
        sta SSKCTL
        sta SKCTL
        plp
        pla
        sta PORTB
        tya
        rts


* ---- E: with redirection ------------------------------------------------------

* k_ehand: the screen editor E:, wrapped while standard input is redirected
* to a file (k_ewrap puts it in HATABS, the handler there before copied to
* ke_tab; k_eunwrap puts that back, so programs such as CON64.SYS see the
* OS's E: otherwise, as on SDX). GET reads the file: a program reading E: (BASIC
* <<AUTOGO) gets the file's lines. At the file's end (or on an error) the
* redirection ends and E: reads the keyboard again.
k_ehand dta a(ke_open-1,ke_close-1,ke_get-1,ke_put-1,ke_stat-1,ke_spec-1)
        jmp k_rts
ke_open ldy #0
        beq ke_fwd
ke_close ldy #2
        bne ke_fwd
ke_put  ldy #6
        bne ke_fwd
ke_stat ldy #8
        bne ke_fwd
ke_spec ldy #10
ke_fwd  sta ke_a               ; the OS's routine for offset Y
        lda ke_tab+1,y
        pha
        lda ke_tab,y
        pha
        lda ke_a
        rts
ke_get  lda dv_on+1
        beq ke_kbd
        stx ke_x
        bit bw_on              ; (a BW-DOS program's page 7 out meanwhile)
        bpl ke_g0
        jsr farcall
        dta b(BK_LIB2),a(L2_BWOUT)
ke_g0   jsr farcall            ; a byte of the file (the device bank's e_read)
        dta b(BK_DEV),a(CARTLO+$21)
        ldx ke_x
        bcs ke_end
        jsr ke_bw
        ldy #1
        rts
ke_end  ldy #1                 ; the end: input from the keyboard again
        jsr farcall
        dta b(BK_LIB),a(L_XDIVIO)
        jsr ke_bw
        ldx ke_x
ke_kbd  ldy #4
        jmp ke_fwd
ke_bw   bit bw_on              ; (keeps A and C)
        bpl ke_b1
        jsr farcall
        dta b(BK_LIB2),a(L2_BWIN)
ke_b1   rts

ke_old  dta a(0)
ke_tab  :16 dta 0              ; the E: table wrapped
ke_a    dta 0
ke_x    dta 0

* k_blkio (jblock_io $0706): in lib2
k_blkio jsr farcall
        dta b(BK_LIB2),a(L2_BLKIO)
        rts

* k_hwctrl (jhwctrl $070F): X = 0 the library at $A000-$BFFF again (the
* bank the program had), 1 the RAM under the cartridge, 2 the internal
* BASIC, 3 the external cartridge (none here: as 1), 4 the cartridge's
* type in A ($03 MaxFlash 8Mbit: the AtariMax 1MB) and its name in copybuf.
* GINTLK follows TRIG3 so that the OS does not stop. Keeps Y.
k_hwctrl cpx #4
        bcs kh_id
        php
        sei
        txa
        bne kh_off
        lda kh_bk              ; 0: the library
        jsr setbank
        lda PORTB
        ora #$02
        sta PORTB
        jmp kh_gl
kh_off  lda curbank
        cmp #CARTOFF
        beq kh_o1
        sta kh_bk
kh_o1   lda #CARTOFF
        jsr setbank
        cpx #2
        bne kh_gl
        lda PORTB              ; 2: BASIC on
        and #$FD
        sta PORTB
kh_gl   lda TRIG3
        sta GINTLK
        plp
        rts
kh_id   ldx #3
kh_i1   lda kh_nm,x
        sta COMTAB+$BF,x
        dex
        bpl kh_i1
        lda #$03
        rts
kh_bk   dta b(BK_LIB)
kh_nm   dta c'EOS',b(EOL)

* k_basic: enter the internal BASIC (the BASIC command): EOS's cartridge
* off, BASIC on, then its init and run vectors as the OS calls them
k_basic lda #CARTOFF
        jsr setbank
        lda PORTB
        and #$FD
        sta PORTB
        lda #0
        sta BASICF
        ldx #$FF
        txs
        lda #>(kb_run-1)
        pha
        lda #<(kb_run-1)
        pha
        jmp ($BFFE)
kb_run  jmp ($BFFA)

* ---- sector I/O --------------------------------------------------------------

* k_lsio (COMTAB-11): k_secio with memreix 0, the transfer in main memory
k_lsio  lda #0
        sta memreix

* k_secio (jsector_io $070C): the transfer the DCB asks for. The drivers
* in sio_vector first, in table order: one that returns C=0 has done it.
* Then EOS's own: the RAM disk's drive, else the OS's SIOV (with the OS
* ROM on). An XDCB (DDEVIC bit 7) goes on as a DCB when its sector number
* and buffer fit in 16 bits; else, with a PBI device enabled (PDVMSK) and
* the buffer in main memory, as it is to the OS's SIO, whose PBI devices
* see it first (the IDE2.0PLUS BIOS's 32-bit sectors); else 184. memreix: the memory DBUF is in
* (SIO through fs_sbuf then). Out: A = Y = status, N=1 on an error.
k_secio lda DDEVIC             ; MAP for a disk unit 1-15: its unit, its
        cmp #$31               ; mode (OFF: 138; SIO: no PBI device asked)
        bne ks_body
        ldx DUNIT
        dex
        cpx #15
        bcs ks_body
        lda maptab+15,x
        cmp #4
        beq ks_off
        sta ks_md
        lda maptab,x
        cmp DUNIT
        bne ks_map
        ldy ks_md
        beq ks_body            ; (as it is: the usual way)
ks_map  ldx DUNIT              ; the caller's DUNIT back afterwards
        stx ks_un
        sta DUNIT
        lda PDVMSK
        sta ks_pd
        lda ks_md              ; SIO: the PBI devices left out meanwhile
        beq ks_m1
        lda #0
        sta PDVMSK
ks_m1   jsr ks_body
        sta ks_st
        lda ks_pd
        sta PDVMSK
        lda ks_un
        sta DUNIT
        lda ks_st
        tay
        rts
ks_off  lda #138               ; OFF: the drive does not answer
        sta DSTATS
        tay
        rts
ks_un   dta b(0)
ks_st   dta b(0)
ks_md   dta b(0)
ks_pd   dta b(0)
ks_body ldx #0
ks1     lda sio_vector+1,x
        beq ks2
        stx ks_x
        jsr ks_go
        bcc ks_ok
        ldx ks_x
ks2     inx
        inx
        cpx #8
        bcc ks1
        lda DDEVIC
        bpl ks_own
        lda DAUX1+2            ; an XDCB: 16 bits only
        ora DAUX1+3
        ora DAUX1+4
        bne ks_arch
        lda DDEVIC
        and #$7F
        sta DDEVIC
        jsr ks_own
        php
        pha
        lda DDEVIC
        ora #$80
        sta DDEVIC
        pla
        plp
        rts
ks_arch lda PDVMSK             ; a PBI device (an IDE2.0PLUS BIOS) takes
        beq ks_ar1             ; the XDCB as it is: the OS's SIO asks it
        lda memreix            ; first (main memory only)
        bne ks_ar1
        jmp ks_sio
ks_ar1  lda #184
        sta DSTATS
        tay
        rts
ks_own  lda DDEVIC
        cmp #$31
        bne ks_sio
        lda DUNIT
        jsr k_rdfind
        jcc ks_rd
ks_sio  lda memreix
        bne ks_bnc
        jsr k_siov
ks_ok   tay
        rts
* ks_bnc: SIO through fs_sbuf, the data between it and DBUF in memory
* memreix
ks_bnc  lda DBUFLO
        sta ks_db
        lda DBUFHI
        sta ks_db+1
        lda DSTATS
        sta ks_dst             ; (SIO puts its status there)
        bpl kbn1
        sec                    ; writing: the data to fs_sbuf first
        jsr ks_cp
kbn1    lda #<fs_sbuf
        sta DBUFLO
        lda #>fs_sbuf
        sta DBUFHI
        jsr k_siov
        pha
        lda ks_db
        sta DBUFLO
        lda ks_db+1
        sta DBUFHI
        pla
        bmi kbn_x
        bit ks_dst             ; (read: $40)
        bvc kbn_x
        pha
        clc                    ; read: the data to DBUF
        jsr ks_cp
        pla
kbn_x    tay
        rts
* ks_cp: DBYT bytes, C=1 from DBUF (memreix) to fs_sbuf, C=0 back
ks_cp   lda #0
        rol @
        sta ks_dir
        lda ks_zq
        pha
        lda ks_zq+1
        pha
        lda ks_zt
        pha
        lda ks_zt+1
        pha
        lda ks_db
        sta ks_zq
        lda ks_db+1
        sta ks_zq+1
        lda #<fs_sbuf
        sta ks_zt
        lda #>fs_sbuf
        sta ks_zt+1
        lda DBYTLO
        sta ks_n
        lda DBYTLO+1
        sta ks_n+1
        lda memreix
        jsr k_setme
        ldy #0
ksc1     lda ks_n
        ora ks_n+1
        beq ksc_end
        lda ks_dir
        beq ksc_in
        lda (ks_zq),y
        sta (ks_zt),y
        jmp ksc2
ksc_in   lda (ks_zt),y
        sta (ks_zq),y
ksc2     iny
        bne ksc3
        inc ks_zq+1
        inc ks_zt+1
ksc3     lda ks_n
        bne ksc4
        dec ks_n+1
ksc4     dec ks_n
        jmp ksc1
ksc_end  jsr k_popme
        pla
        sta ks_zt+1
        pla
        sta ks_zt
        pla
        sta ks_zq+1
        pla
        sta ks_zq
        rts
ks_dir  dta 0
ks_dst  dta 0
ks_db   dta a(0)
ks_go   lda sio_vector,x
        sta ks_v
        lda sio_vector+1,x
        sta ks_v+1
        jmp (ks_v)

ks_zq   equ $45                ; (the FMS's zp_q and zp_t, saved)
ks_zt   equ $47

* ks_rd: the RAM disk's SIO command (dev bank rd_sio; ks_pb, ks_pm, ks_n
* and ks_v are its variables here)
ks_rd   jsr farcall
        dta b(BK_DEV),a(CARTLO+$27)
        rts

ks_x    dta 0
ks_v    dta a(0)
ks_pb   dta 0
ks_pm   dta 0
ks_n    dta a(0)

* k_tconv: memory index A to its PORTB value (T_); changes X
k_tconv cmp #4
        bcs kt_bank
        tax
        lda T_+4,x
        rts
kt_bank pha                    ; T_+8: the bank bits for index / 4
        lsr @
        lsr @
        tax
        pla
        and #3
        asl @
        asl @
        ora T_+8-1,x
        rts

* k_setmx ($07F7, not in the Programming Guide; CON.SYS copies itself to
* its bank with it): memory index A (as for V_setme) in, no stack: A = the
* index before. Keeps X and Y.
k_setmx stx vs_x
        pha
        jsr k_curmx
        stx k_mxo
        pla
        sta k_mxi
        jsr k_tconv            ; (X goes)
        sta PORTB
        lda k_mxo
        ldx vs_x
        rts
* k_curmx: X = the index of the memory PORTB selects now: the last one
* $07F7 set when its bank is in, else found in T_ (EOS's own and V_setme's
* switches do not go through $07F7); 0 when none fits
k_curmx lda COMTAB+$1C         ; PBMASK: the bank bits
        beq kcm_0
        ldx k_mxi
        jsr kcm_eq
        beq kcm_x
        ldx #2                 ; the system bank, then 4 on
        jsr kcm_eq
        beq kcm_x
        ldx #4
kcm_1   jsr kcm_eq
        beq kcm_x
        inx
        cpx #4+64
        bcc kcm_1
kcm_0   ldx #0
        stx k_mxi
kcm_x   rts
kcm_eq  stx k_mxt              ; Z=1 when index X has PORTB's bank bits
        txa
        jsr k_tconv
        eor PORTB
        and COMTAB+$1C
        ldx k_mxt
        cmp #0
        rts
k_mxi   dta 0
k_mxo   dta 0
k_mxt   dta 0

k_popme php
        pha
        stx vs_x
        lda vs_sp
        sec
        sbc #1
        and #15
        sta vs_sp
        tax
        lda vs_stk,x
        sta PORTB
        ldx vs_x
        pla
        plp
        rts

* k_exec: call the code at ke_adr with the library bank selected (programs
* and their INIT routines), then reselect the caller's bank. ke_sp is the
* stack pointer the code starts with: U_FAIL with a status for the parent
* returns through it (k_ret) as if the program had done an RTS.
k_exec  lda curbank
        pha
        lda ke_sp
        pha
        lda #BK_LIB
        jsr setbank
        tsx
        stx ke_sp
        jsr ke_go
k_ret   pla
        sta ke_sp
        pla
        jmp setbank
ke_go   jmp (ke_adr)
ke_adr  dta a(0)
ke_sp   dta b($FF)
STATUS  dta b(0)               ; a program's status for its parent (U_LOAD)
ERRNO   dta b(0)               ; the last error

k_crunch jsr farcall           ; ZCRNAME: in the library
        dta b(BK_LIB),a(L_CRUNCH)
        rts

* _HSDRV: the high speed SIO driver (dev.asm hs.icl), for sio_vector
* (SIOSET n US puts it there)
k_hsdrv jsr farcall
        dta b(BK_DEV),a(CARTLO+$24)
        rts

* _EOSDRV (CAR:COMEXE.SYS A=0, RUNEXT.SYS 1, DOSKEY.SYS 2, RAMDISK.SYS 3,
* RTIME8.SYS 4, JIFFY.SYS 5): EOS's own drivers, through lib2
k_eosdrv jsr farcall
        dta b(BK_LIB2),a(L2_EOSDRV)
        rts

* CAR: (car.asm): the files are in banks of their own
kd_car  jsr farcall
        dta b(BK_CAR),a(CARTLO)
        rts
* k_bcopy: bc_n bytes (0 = 256) from bank bc_bank at ($43) to ($45), with
* PORTB = bc_mx meanwhile when that is not 0 (memreix); the caller's bank
* again on return
k_bcopy lda curbank
        pha
        lda bc_bank
        jsr setbank
        lda bc_mx
        beq kb0
        lda PORTB
        sta bc_pb
        lda bc_mx
        sta PORTB
kb0     ldy #0
kb1     lda ($43),y
        sta ($45),y
        iny
        cpy bc_n
        bne kb1
        lda bc_mx
        beq kb2
        lda bc_pb
        sta PORTB
kb2     pla
        jmp setbank
* GET and PUT: kc_from = the high byte of the caller's address. CIO (in
* ROM) lets the handler move a whole block at once (dev.asm d_burst); a
* program calling the handler's vector itself (BASIC, exBASIC) has its own
* page 0 left from an earlier CIO call, and gets the one byte only.
* First the byte window (dev.asm fw.icl): after the FMS read or wrote one
* byte of a file, the rest of that sector in its cache (under the OS ROM)
* is taken or stored here, byte by byte, with no bank changed: fw_h the
* file's handle (+$40: written; $FF none), fw_n the bytes left, kf_op
* LDA or STA of the next one's address. The FMS settles it at its next call.
kc_get  ldy #0
        beq kc_io
kc_put  sta dc_b
        ldy #$40
kc_io   jsr kf_io
        bcc kfx_r
        lda dc_b               ; (PUT's byte)
        jsr farcall            ; dev.asm w_gp: Y=0 GET, $40 PUT
        dta b(BK_DEV),a(CARTLO+$33)
kfx_r   rts
* kf_io: Y=0 GET, $40 PUT (the byte in dc_b). C=0: done, A the byte, Y=1.
* Not for CIO's calls of a GET or PUT CHARACTERS with 2 bytes or more
* left (d_burst may take them). C=1: kc_from set. Keeps X and Y then.
kf_io   tya                    ; (EOR: a listing's $FE, PUT $BE)
        eor IOCB0+ICAX6,x
        cmp fw_h
        bne kfx_w
        lda fw_n
        beq kfx_w
        lda ICCOMZ             ; (7 and 11: CHARACTERS)
        and #3
        cmp #3
        bne kfx1
        lda ICBLLZ+1
        bne kfx_c
        lda ICBLLZ
        cmp #2
        bcc kfx1
kfx_c   clc                    ; C=0: CIO's call goes to d_burst
        dta b($24)             ; (BIT zp: skips the SEC)
kfx_w   sec                    ; C=1: not in the window
        php
        stx dc_x
        tsx
        lda $0105,x            ; (P, kf_io's return, then the caller's)
        sta kc_from
        ldx dc_x
        plp
        bcs kfx_n
        cmp #$C0
        bcc kfx1
kfx_n   sec
        rts
kfx1    dec fw_n
        lda PORTB
        tay
        and #$FE
        sta PORTB
        lda dc_b
kf_op   lda $FFFF              ; (LDA or STA: fw_set)
        sty PORTB
        inc kf_op+1
        bne kfx2
        inc kf_op+2
kfx2    ldy #1
        clc
        rts
kc_from dta b(0)
fw_h    dta b($FF)
fw_n    dta b(0)

bc_bank dta b(0)
bc_n    dta b(0)
bc_mx   dta b(0)
bc_pb   dta b(0)

kend    equ *

* ---- uninitialised data (not in the image) ----------------------------
        icl 'fms_sbuf.icl'
        icl 'libdata.icl'

k_memlo equ *
        ert k_memlo>$1802      ; (Mutineer: RHND850 below REMMS at $1E00)
        ert <ks_v=$FF          ; JMP () vectors must not sit at $xxFF (the
        ert <ke_adr=$FF        ; 6502 would take the high byte from $xx00)

* the FMS's data under the OS ROM, after ENVBUF and CMDNAME
        org $C200
        icl 'fmsdata.icl'
bk_szl  .ds 16                 ; jblock_io: each unit's sector size (bm_set)
bk_szh  .ds 16
lb_save .ds 68                 ; FORMAT, BUILDDIR: the caller's LBUF, BUFOFF,
                               ; FILE_P, FLAG meanwhile
hs_off  .ds 1                  ; $80: DEVICE SIO /A or /C, the OS's SIO only
hs_ref  .ds 1                  ; SIOSET REFRESH (128: a unit that fails is asked again)
hs_tab  .ds 16                 ; high speed SIO (dev.asm hs.icl): each unit's
                               ; POKEY divisor, 0 not asked yet, $80 none,
                               ; $81 NORMAL; hs_tab+0: SIOSET WAITACK
ix_m    .ds 2                  ; EOSFS directory index (dos2i.icl): its list,
ix_f    .ds 1                  ; $FF there is one (header +20..22, open_dir)
ix_k    .ds 2
ix_h    .ds 1
ix_n    .ds 2
ix_t    .ds 2
ix_p    .ds 2
ix_csi  .ds 2
ix_cs   .ds 2
ix_l    .ds 2
ix_v    .ds 1
ix_b    .ds 1
fms_end equ *
        ert fms_end>BF_DAT2
