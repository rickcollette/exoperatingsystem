* EOS (Extendable Operating System): bank 0, cold and warm start
*
* Copies the RAM kernel to $0700, sets up the OS vectors, prints the banner
* and enters the command processor.

        icl 'equ.icl'
        icl 'kernel.icl'

        opt h-f+

* zero page used only while booting
src     equ $80
dst     equ $82

        org CARTLO
        jmp coldwarm           ; $A000 cold and warm start (tail.icl)
        jmp applyuse           ; $A003 the USE setting (command processor)
        jmp warm               ; $A006 DOSINI at a reset (k_dosini)

coldwarm cld
        ldx #$FF
        txs
* the XL OS leaves internal BASIC enabled with a cartridge present: switch
* it off so $A000-$BFFF is RAM whenever the cartridge is off
        lda PORTB
        ora #$02
        sta PORTB
        lda #$01
        sta BASICF
        lda TRIG3
        sta GINTLK
        lda #0                  ; EOS starts with lower-case keyboard input
        sta SHFLOK

* copy the kernel image to $0700; after a reset the drive map (sio_index,
* SWAP and MAP) stays as it was until a cold start
        lda WARMST             ; a reset keeps the kernel as it is (its
        bne kc2                ; symbols, drivers, files), as SDX does
kc0     lda #<kimg
        sta src
        lda #>kimg
        sta src+1
        lda #<$0700
        sta dst
        lda #>$0700
        sta dst+1
        ldy #0
        ldx #>(kend-$0700+$FF)
cpy     lda (src),y
        sta (dst),y
        iny
        bne cpy
        inc src+1
        inc dst+1
        dex
        bne cpy
kc2     lda #BK_BOOT
        sta curbank

* the interrupt vectors under the OS ROM, for the time it is off: set
* before anything turns the ROM off (the bank count, the environment, the
* devices' initz)
        sei
        lda #0
        sta NMIEN
        jsr k_romoff
        lda #<k_nmi
        sta $FFFA
        lda #>k_nmi
        sta $FFFB
        lda #<k_irq
        sta $FFFE
        lda #>k_irq
        sta $FFFF
        lda #0                 ; no pipe running (a reset ends one)
        sta P_N
        sta P_MORE
        lda WARMST             ; a cold start: no unit's speed known yet
        bne bhs1               ; (high speed SIO asks each one once)
        ldx #17                ; (on, REFRESH 0, WAITACK 2: the OS's)
bhs0    sta hs_off,x
        dex
        bpl bhs0
        lda #2
        sta hs_tab
bhs1    jsr k_romon
        lda #$40
        sta NMIEN
        cli
.ifdef IDE
        jsr farcall            ; the CompactFlash card: out of reset, its
        dta b(BK_DEV),a(CARTLO+$2A) ; APT drives
.endif

* the OS ROM's character set ($E000-$E3FF) copied to the RAM under it, as
* SDX does: while EOS has the ROM off (its cache and data are under it)
* the screen is still drawn with it. 128 bytes at a time through LBUFF
* (with the ROM on, writes to $E000 do not reach the RAM).
        lda #<$E000
        sta src
        lda #>$E000
        sta src+1
fc1     ldy #127
fc2     lda (src),y
        sta LBUFF,y
        dey
        bpl fc2
        sei                    ; (an interrupt with the ROM off and no font
        jsr k_romoff           ; copied yet would still work: k_nmi)
        ldy #127
fc3     lda LBUFF,y
        sta (src),y
        dey
        bpl fc3
        jsr k_romon
        cli
        clc
        lda src
        adc #128
        sta src
        bcc fc1
        inc src+1
        lda src+1
        cmp #>$E400
        bcc fc1

* OS vectors
        lda #<COMTAB
        sta DOSVEC
        lda #>COMTAB
        sta DOSVEC+1
        lda WARMST             ; a resident program's DOSINI (it chains to
        beq di1                ; EOS's) stays over a reset, so it can put
        lda DOSINI+1           ; its handler back (RHND850)
        cmp #>k_dosini
        bne di2
        lda DOSINI
        cmp #<k_dosini
        bne di2
di1     lda #<k_dosini
        sta DOSINI
        lda #>k_dosini
        sta DOSINI+1
di2
        lda WARMST             ; MEMLO: after a reset as k_dosini and the
        bne ml1                ; resident programs set it
        lda #<k_memlo
        sta MEMLO
        sta res_ml
        lda #>k_memlo
        sta MEMLO+1
        sta res_ml+1
ml1
        lda BOOT
        ora #$01
        sta BOOT
        lda WARMST             ; extended memory: counted at a cold start
        bne xb1
        ldx #5                 ; the OS's serial interrupt routines (k_siov)
sv1     lda VSERIN,x
        sta os_vs,x
        dex
        bpl sv1
        jsr banks
        lda #0                 ; no USE from EOSSYS.SYS yet, no RAM disk,
        sta cfg_use            ; no clock driver
        ldx #NRD-1
ru1     sta rd_unit,x
        sta rd_n,x
        dex
        bpl ru1
        sta clk_on
        sta cx_on              ; no COMEXE, RUNEXT, no $COMSPEC shell tried yet
        sta rx_on
        sta dk_on
        sta cs_try
xb1     lda xb_n
        sta COMTAB2-3          ; _EXTBNK
        jsr applyuse
        lda #0
        sta xb_cur
        lda WARMST             ; reset routines (S_ADDIZ) stay over a reset
        bne iz0
        sta iz_n
iz0     lda #0
        sta vs_sp
        sta dv_on              ; no redirection
        sta dv_on+1
        lda #$FF               ; no batch file after a reset
        sta cp_bat
        lda #0                 ; ECHO OFF, ERROR OFF
        sta cp_fail
        sta cp_inb
        sta cp_echo
        sta cp_erron
        sta cp_front
        jsr k_romoff           ; no program's name yet (U_FAIL, 170)
        lda #EOL
        sta CMDNAME
        jsr k_romon
        lda WARMST             ; the startup batch file only on a cold start
        eor #$FF
        sta cp_cold
        lda #0
        sta COLDST
        lda WARMST             ; a cold start: the default environment, as
        bne ce2                ; SDX sets it up without a CONFIG.SYS
        jsr k_romoff
        ldx #0
ce1     lda defenv,x
        sta ENVBUF,x
        inx
        cpx #defenv_end-defenv
        bne ce1
        jsr k_romon
        jsr farcall            ; four-line command history by default
        dta b(BK_LIB2),a(L2_DKDEFAULT)
ce2     lda WARMST             ; a reset: standard input and output are
        beq ce4                ; opened again
        ldx #1
ce3     stx cp_i
        lda COMTAB+6,x
        tax
        lda dev_index,x
        cmp #$FF
        beq ce5
        stx file_id
        ldy #7                 ; kd_close
        jsr jkernel
ce5     ldx cp_i
        dex
        bpl ce3
ce4     jsr k_initz
* standard output and input: CON:, handles 0 and 1 as on SDX (output 0)
        ldx #0
so1     stx cp_i
        lda #$31
        sta device
        lda #$0C
        sta mode
        ldy #9                 ; kd_open
        jsr jkernel
        lda file_id
        ldx cp_i
        sta COMTAB+6,x
        inx
        cpx #2
        bcc so1

        jsr hatd


* banner: after a reset; at a cold start the command processor shows it
* after EOSSYS.SYS (as SDX does after CONFIG.SYS)
        lda WARMST
        beq bn_skip
        ldx #0
        lda #C_PUTB
        sta IOCB0+ICCOM
        lda #<banner
        sta IOCB0+ICBAL
        lda #>banner
        sta IOCB0+ICBAH
        lda #<(banner_end-banner)
        sta IOCB0+ICBLL
        lda #>(banner_end-banner)
        sta IOCB0+ICBLL+1
        jsr CIOV
bn_skip jmp (DOSVEC)

* applyuse: the memory setup for cfg_use (EOSSYS.SYS USE, C3), as SDX:
* 0 (no USE): NBANKS all banks, OSRMFLG $FE, MALLOC $02 from main memory;
* 1 OSRAM: OSRMFLG $FF, MALLOC $02 from $E400-$FFBF under the OS ROM;
* 2 BANKED (with banks; else as OSRAM): the highest bank is the system's
* (T_ index 2, NBANKS one less, BANKFLG $FF, OSRMFLG 0), MALLOC $02 from
* it ($4000-$7FFF). Again from the start each time: USE may come twice.
applyuse lda #0                 ; PBMASK: the PORTB bits the banks use
        sta COMTAB+$1C         ; (130XE: $1C)
        lda xb_n
        sta bk_x
        beq au0
au00    lda bk_x
        clc
        adc #3
        jsr k_tconv
        eor #$FF
        ora COMTAB+$1C
        sta COMTAB+$1C
        dec bk_x
        bne au00
au0     lda xb_n
        sta COMTAB+$1D         ; NBANKS: none used yet
        lda #$FE
        sta T_+6
        sta COMTAB+$1F
        lda #0
        sta COMTAB+$1E
        sta sx_ptr+1           ; MALLOC $02: main memory
        lda cfg_use            ; no USE: BANKED above 128K, as SDX
        bne au1
        lda xb_n
        cmp #5
        bcc au_ret
        lda #2
au1     cmp #2
        bne au_os
        lda xb_n
        beq au_os
        clc                    ; the system bank: the highest
        adc #3
        jsr k_tconv
        ora #$01               ; the OS ROM on
        sta T_+6
        dec COMTAB+$1D
        lda #$FF
        sta COMTAB+$1E
        lda #0
        sta COMTAB+$1F
        lda #<$4000
        ldx #>$4000
        ldy #>$8000-1
        bne au_sx
au_os   lda #$FF
        sta COMTAB+$1F
        lda #<$E400
        ldx #>$E400
        ldy #>$FFBF
au_sx   sta sx_ptr
        stx sx_ptr+1
        sty sx_lim
au_ret  lda #0                 ; E1: above 128K the top free bank is the
        sta l2_pb              ; second-level sector cache's (dev bank
        lda xb_n               ; l2.icl), before the RAM disks' are counted
        cmp #5                 ; (they lie below it)
        bcc au_l2
        lda COMTAB+$1D
        beq au_l2
        clc
        adc #3
        jsr k_tconv
        and #$FE
        sta l2_pb
        dec COMTAB+$1D
        jsr farcall
        dta b(BK_DEV),a(CARTLO+$3F)
au_l2   lda COMTAB+$1D         ; the RAM disks' banks are not free (RAMDISK)
        ldx #NRD-1
au_r0   sec
        sbc rd_n,x
        bcc au_r2
        dex
        bpl au_r0
        bmi au_r1
au_r2   lda #0
au_r1   sta COMTAB+$1D
        rts

* banks: xb_n = the PORTB banks (T_ order, index 4 up) that are separate
* memory: each gets its number at $4000, from the last to the first, main
* memory $FF; counted from the first until one reads back wrong
banks   lda $4000
        pha
        lda $0000              ; main memory's other 16K blocks: a bank that
        pha                    ; is one of them (RAMBO 320K: 4 of its 16)
        lda $8000              ; writes its number there; $FF never is one
        pha
        lda #$FF
        sta $0000
        sta $8000
        sei
        jsr k_romoff
        lda $C000
        sta bk_c
        lda #$FF
        sta $C000
        jsr k_romon
        cli
        ldx #63
bk1     txa
        jsr bk_sel
        txa
        sta $4000
        dex
        bpl bk1
        lda #$FF
        sta PORTB
        sta $4000
        ldx #0
bk2     txa
        jsr bk_sel
        txa
        cmp $4000
        bne bk3
        inx
        cpx #64
        bcc bk2
bk3     stx xb_n
        lda #$FF
        sta PORTB
        lda $0000              ; a bank seen in main memory: the count ends
        jsr bk_alias           ; before it
        lda $8000
        jsr bk_alias
        sei
        jsr k_romoff
        lda $C000
        ldx bk_c
        stx $C000
        jsr k_romon
        cli
        jsr bk_alias
        pla
        sta $8000
        pla
        sta $0000
        pla
        sta $4000
        rts
* bk_alias: A = a bank number found in main memory ($FF none): xb_n at
* most that
bk_alias cmp xb_n
        bcs ba1
        sta xb_n
ba1     rts
* bk_sel: bank A (0 = index 4) selected, the OS ROM on; keeps X
bk_sel  stx bk_x
        clc
        adc #4
        jsr k_tconv
        ldx bk_x
        sta PORTB
        rts

defenv  dta c'PATH=CAR:',b(EOL)
        dta c'PROMPT=D$N$P/',b(EOL)
        dta c'SYSERR=CAR:syserr.msg',b(EOL)
        dta c'MAXDRV=O:',b(EOL)
        dta c'MANPATH=CAR:',b(EOL)
        dta b(0)               ; BOOT comes after EOSSYS.SYS (SDX's order)
defenv_end equ *

banner  dta b(EOL)
        dta c'EOS v'
        icl 'version.icl'
        dta c' (c)2026 Rick Collette',b(EOL)
banner_end equ *

* D: in the OS handler table: replace an entry for D, else take a free one
hatd    ldx #0
hd1     lda HATABS,x
        cmp #'D'
        beq hd3
        inx
        inx
        inx
        cpx #36
        bcc hd1
        ldx #0
hd2     lda HATABS,x
        beq hd3
        inx
        inx
        inx
        cpx #36
        bcc hd2
        bcs hd4
hd3     lda #'D'
        sta HATABS,x
        lda #<k_dhand
        sta HATABS+1,x
        lda #>k_dhand
        sta HATABS+2,x
hd4     rts

* warm: DOSINI at a reset (k_dosini). MEMLO as it was at the prompt, D: in
* HATABS, then the reset routines (S_ADDIZ), oldest first
warm    lda res_ml
        sta MEMLO
        lda res_ml+1
        sta MEMLO+1
        jsr hatd
        ldx #0
wm1     cpx iz_n
        bcs wm_ret
        txa
        pha
        lda #>(wm2-1)
        pha
        lda #<(wm2-1)
        pha
        lda iz_lo,x
        sec
        sbc #1
        tay
        lda iz_hi,x
        sbc #0
        pha
        tya
        pha
        rts
wm2     pla
        tax
        inx
        bne wm1
wm_ret  rts

kimg    ins 'kernel.bin'
        ert *>$BFF0

        icl 'tail.icl'
