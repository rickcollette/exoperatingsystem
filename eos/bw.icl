* BW-DOS programs (included in lib2.asm). BW-DOS keeps its COMTAB in page 7
* ($0700-$07B8: "BW" at $0703, version $15 at $0705, the command line at
* $0765 ...) where SDX, and so EOS, keeps jkernel, the device tables and
* the kernel's parameters. While a BW-DOS program runs (the loader knows
* one by the check every BW-DOS command starts with) page 7 holds a BW-DOS
* COMTAB whose vectors lead into EOS, and DOSVEC points at it ($0726).
* Each way back into EOS (CIO D:, CRNAME, GETTD, SETTD, BW_FAIL, DOSVEC,
* RESET) puts EOS's page 7 back meanwhile. EOS's page 7 waits at BW_SAVE,
* the BW-DOS one at BW_IMG, both under the OS ROM.

BW_N    equ $C0                ; page 7 bytes swapped ($0700-$07BF)
BW_BUFOFF equ $0730
BW_DATER equ $0733
BW_TIMER equ $0736
BW_COMFNAM equ $0747
BW_LBUF equ $0765
BW_CURDRV equ $07A6
BW_DECOUT equ $0713
BW_DECIN equ $0720

* bw_enter: run address RUNAD: the BW-DOS page 7 for it, swapped in
bw_enter jsr k_romoff
        ldx #0
wbe1    lda bw_tpl,x
        sta BW_IMG,x
        inx
        cpx #BW_N
        bne wbe1
        ldx #63                ; the command line and where the program's
wbe2     lda COMTAB+CT_LBUF,x   ; parameters start
        sta BW_IMG+BW_LBUF-$0700,x
        dex
        bpl wbe2
        lda COMTAB+CT_BUFOFF
        sta BW_IMG+BW_BUFOFF-$0700
        lda CURDEV             ; "Dn:" for names without a drive
        and #$0F
        ora #'0'
        sta BW_IMG+BW_CURDRV-$0700+1
        lda k_wrtcmd
        sta BW_IMG+$24
        lda MEMLO
        sta BW_IMG+$44
        lda MEMLO+1
        sta BW_IMG+$45
        lda RUNAD
        sta BW_IMG+$63
        lda RUNAD+1
        sta BW_IMG+$64
        jsr k_romon
        jsr bw_in              ; ($07xx now BW-DOS's)
        ldx #33                ; D: through k_bwdh
wbe3     lda HATABS,x
        cmp #'D'
        beq wbe4
        dex
        dex
        dex
        bpl wbe3
        bmi wbe5
wbe4     lda #<k_bwdh
        sta HATABS+1,x
        lda #>k_bwdh
        sta HATABS+2,x
wbe5     lda #$80
        sta bw_on
        rts

* bw_leave: EOS's page 7 back for good (a BW-DOS program ended)
bw_leave bit bw_on
        bpl wbl_ret
        jsr bw_out
        lda #0
        sta bw_on
        ldx #33
wbl1     lda HATABS,x
        cmp #'D'
        beq wbl2
        dex
        dex
        dex
        bpl wbl1
wbl_ret  rts
wbl2     lda #<k_dhand
        sta HATABS+1,x
        lda #>k_dhand
        sta HATABS+2,x
        rts

* bw_go: the kernel's k_bwdh, D: called by a BW-DOS program: EOS's page 7
* in for the call (bw_y the entry's offset in k_dhand; A, X, Y and the
* flags pass both ways). OPEN, STATUS and XIO with a name in page 7
* (COMFNAM, LBUF): EOS reads a copy of it (bw_buf).
bw_go   lda #0
        sta bw_bh
        cpy #4
        beq wgo1
        cpy #6
        beq wgo1
        lda ICBALZ+1
        cmp #$07
        bne wgo1
        sta bw_bh
        lda ICBALZ
        sta bw_bl
        ldy #63
wgo0    lda (ICBALZ),y
        sta bw_buf,y
        dey
        bpl wgo0
        lda #<bw_buf
        sta ICBALZ
        lda #>bw_buf
        sta ICBALZ+1
wgo1    lda bw_a               ; (PUT's byte)
        jsr bw_out
        jsr wgo_call
        jsr bw_in
        php
        pha
        lda bw_bh              ; the name's own address again
        beq wgo2
        sta ICBALZ+1
        lda bw_bl
        sta ICBALZ
wgo2    pla
        plp
        rts
wgo_call sta bw_a              ; EOS's entry (k_dhand)
        ldy bw_y
        lda k_dhand+1,y
        pha
        lda k_dhand,y
        pha
        lda bw_a
        rts

* bw_out: EOS's page 7 in, the BW-DOS one kept; bw_in: back. A, X, Y and
* the flags are kept.
bw_out  php
        pha
        txa
        pha
        jsr k_romoff
        ldx #0
wbo1    lda $0700,x
        sta BW_IMG,x
        lda BW_SAVE,x
        sta $0700,x
        inx
        cpx #BW_N
        bne wbo1
        lda #<COMTAB_ADR
        ldx #>COMTAB_ADR
        jmp wbw_dv
bw_in   php
        pha
        txa
        pha
        jsr k_romoff
        ldx #0
wbi1    lda $0700,x
        sta BW_SAVE,x
        lda BW_IMG,x
        sta $0700,x
        inx
        cpx #BW_N
        bne wbi1
        lda #<$0726
        ldx #>$0726
wbw_dv   sta DOSVEC
        stx DOSVEC+1
        jsr k_romon
        pla
        tax
        pla
        plp
        rts

* bw_crn: CRNAME: the next word of the command line (from BUFOFF; ended
* by a blank or EOL) to COMFNAM as a name with a device: "D2:X" stays,
* "D:X" becomes "D1:X", a name alone gets the current drive ("D1:X").
* EOL after it, BUFOFF after it. Z=1 (X=3) when there was none.
bw_crn  ldy BW_BUFOFF
wbc0     lda BW_LBUF,y
        cmp #' '
        bne wbc1
        iny
        bne wbc0
wbc1     ldx #0
        cmp #EOL
        beq wbc_def
        lda BW_LBUF+1,y        ; "D:": the drive is 1
        cmp #':'
        bne wbc2
        lda BW_LBUF,y
        sta BW_COMFNAM
        lda #'1'
        sta BW_COMFNAM+1
        ldx #2
        iny
        bne wbc_cp
wbc2     cmp #EOL               ; (a one letter name)
        beq wbc_def
        lda BW_LBUF+2,y        ; "D2:" as it is
        cmp #':'
        beq wbc_cp
wbc_def  lda BW_CURDRV,x        ; else the current drive first
        sta BW_COMFNAM,x
        inx
        cpx #3
        bcc wbc_def
wbc_cp   lda BW_LBUF,y          ; the word
        cmp #' '
        beq wbc_e
        cmp #EOL
        beq wbc_e
        cpx #27
        bcs wbc_n
        sta BW_COMFNAM,x
        inx
wbc_n    iny
        cpy #64
        bcc wbc_cp
wbc_e    sty BW_BUFOFF
        lda #EOL
        sta BW_COMFNAM,x
        cpx #3
        rts

* bw_conv: CONVDC: DECIN (24 bits) to DECOUT, 8 digits right aligned with
* blanks before them; DECIN ends as 0
bw_conv ldx #7
wcv1     lda #0                 ; DECIN / 10, the remainder in A
        ldy #24
wcv2     asl BW_DECIN
        rol BW_DECIN+1
        rol BW_DECIN+2
        rol @
        cmp #10
        bcc wcv3
        sbc #10
        inc BW_DECIN
wcv3     dey
        bne wcv2
        ora #'0'
        sta BW_DECOUT,x
        dex
        bmi wcv_ret
        lda BW_DECIN
        ora BW_DECIN+1
        ora BW_DECIN+2
        bne wcv1
wcv4     lda #' '
        sta BW_DECOUT,x
        dex
        bpl wcv4
wcv_ret  rts

* bw_gtd, bw_std: GETTD and SETTD: EOS's clock (CLK:) to and from DATER and
* TIMER
bw_gtd  jsr bw_out
        ldy #100               ; kd_gettd
        jsr farcall
        dta b(BK_DEV),a(CARTLO+$1B)
        ldx #5
wbg1     lda date,x
        sta bw_tdt,x
        dex
        bpl wbg1
        jsr bw_in
        ldx #5
wbg2     lda bw_tdt,x
        sta BW_DATER,x
        dex
        bpl wbg2
        clc
        rts
bw_std  ldx #5
wbs1     lda BW_DATER,x
        sta bw_tdt,x
        dex
        bpl wbs1
        jsr bw_out
        ldx #5
wbs2     lda bw_tdt,x
        sta date,x
        dex
        bpl wbs2
        ldy #101               ; kd_settd
        jsr farcall
        dta b(BK_DEV),a(CARTLO+$1B)
        jsr bw_in
        clc
        rts

* the BW-DOS page 7: its COMTAB with EOS's routines (filled in by bw_enter:
* the command line, BUFOFF, the drive, WRTCMD, MEMLO, the run address)
bw_tpl  dta c'S',b($32,$00)    ; $0700 SpartaDOS 3.2 compatible
        dta c'BW',b($15)       ; $0703 BW-DOS 1.5
        dta a(kb_gtd)          ; $0706 GETTD
        dta a(kb_std)          ; $0708 SETTD
        dta a(kb_conv)         ; $070A CONVDC
        jmp $071B              ; $070C SIO
        dta a(kb_fail)         ; $070F an error (A) and the command processor
        dta b($FF,$80)         ; $0711
        :8 dta c' '            ; $0713 DECOUT
        jmp k_siov             ; $071B SIO (LSIO at $071C)
        dta b($FF,$FF)         ; $071E ECHOFLG, BATFLG: none
        dta b(0,0,0,0)         ; $0720 DECIN
        dta c'P',b($FF)        ; $0724 WRTCMD, SWARMST
        jmp k_cpx              ; $0726 COMTAB (DOSVEC)
        jmp kb_crn             ; $0729 CRNAME
        dta a(k_rts,k_rts)     ; $072C DIVIO, XDIVIO
        dta b(0)               ; $0730 BUFOFF
        dta a($0700)           ; $0731 ZORIG
        dta b(1,1,25,0,0,0)    ; $0733 DATER, TIMER
        dta b(1,1,25,0,0,0)    ; $0739 ODATER, OTIMER
        dta b(0)               ; $073F TDOVER
        dta a(k_rts)           ; $0740 TRUN
        dta a(BW_SAVE)         ; $0742 SECBUF (VERS looks at it)
        dta a(0)               ; $0744 SMEMLO
        dta b(0)               ; $0746 INCMND
        :28 dta b(EOL)         ; $0747 COMFNAM
        dta a(0)               ; $0763 RUNLOC
        :64 dta b(EOL)         ; $0765 LBUF
        dta b(EOL)             ; $07A5 PROMPT
        dta c'D1:',b(EOL)      ; $07A6 the current drive
        dta b(1)               ; $07AA DOSDRV
        dta c'.BAT',b(EOL)     ; $07AB
        dta c'.COM',b(EOL)     ; $07B0
        dta c'*.*',b(EOL)      ; $07B5
        :BW_N-(*-bw_tpl) dta b(0)
        ert *-bw_tpl<>BW_N
