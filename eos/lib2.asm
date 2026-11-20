* EOS (Extendable Operating System): bank 6, more of the library
*
* Functions the library bank has no room for; their symbols point to stubs
* in the library (bank 1) that farcall these.

        icl 'equ.icl'
        icl 'kernel.icl'

        opt h-f+

E_EOF   equ 136
E_NOFUNC equ 146

LBUF    equ COMTAB+CT_LBUF

        org CARTLO
        jmp fd_open            ; $A000 FDOPEN
        jmp fd_getc            ; $A003 FDGETC
        jmp fd_close           ; $A006 FDCLOSE
        jmp bw_enter           ; $A009 BW-DOS programs (bw.icl)
        jmp bw_leave           ; $A00C
        jmp bw_out             ; $A00F
        jmp bw_in              ; $A012
        jmp bw_crn             ; $A015
        jmp bw_conv            ; $A018
        jmp bw_gtd             ; $A01B
        jmp bw_std             ; $A01E
        jmp fd_open6           ; $A021 D: open mode 6 (dev.asm)
        jmp fd_form            ; $A024 misc_formdir (jmisc 4)
        jmp blk_io             ; $A027 jblock_io
        jmp rx_load            ; $A02A RUNEXT.SYS: the configuration
        jmp rx_find            ; $A02D RUNEXT: an association for COMFNAM
        jmp rx_show            ; $A030 the RUNEXT command
        jmp dk_load            ; $A033 DOSKEY.SYS
        jmp dk_line            ; $A036 DOSKEY: the command line
        jmp eos_drv            ; $A039 _EOSDRV: A = 0 COMEXE, 1 RUNEXT, 2 DOSKEY
        jmp en_get             ; $A03C GETENV (env.icl)
        jmp en_num             ; $A03F NUMENV
        jmp en_put             ; $A042 PUTENV
        jmp en_getx            ; $A045 the command processor's envget
        jmp en_front           ; $A048 and envfront
        jmp bw_go              ; $A04B D: while a BW-DOS program runs (kernel k_bwdh)

* eos_drv: _EOSDRV, the .SYS stubs of EOS's own extensions: A = 0
* COMEXE (.EXE through X), 1 RUNEXT (rx.icl), 2 DOSKEY (dk.icl), 3 RAMDISK,
* 4 RTIME8, 5 JIFFY (the command processor's), 6 ENV.SYS (env.icl)
eos_drv cmp #1
        beq ed_rx
        bcs ed_2
        lda #$80
        sta cx_on
        rts
ed_rx   jmp rx_load
ed_2    cmp #2
        bne ed_3
        jmp dk_load
ed_3    cmp #4                 ; 3 RAMDISK, 4 RTIME8, 5 JIFFY: the shell's
        beq ed_4
        bcs ed_5
        jsr farcall
        dta b(BK_CP),a(CARTLO+3)
        rts
ed_4    jsr farcall
        dta b(BK_CP),a(CARTLO+6)
        rts
ed_5    cmp #6
        beq ed_6
        jsr farcall
        dta b(BK_CP),a(CARTLO+9)
        rts
ed_6    jmp en_big             ; 6 ENV.SYS

* ---- jblock_io $0706 (chapter 23): Y = 0 bm_read, 1 bm_write, 2 bm_flush,
* 3 bm_abort, 4 bm_fread, 5 bm_set; the drive in DDEVIC/DUNIT, the sector
* in DAUX, the buffer in DBUF. The transfers go through jsector_io (the
* drives as they are: EOS's cache is DSK:'s); the sector size is the one
* bm_set or bm_fread found (128 when none), sectors 1-3 are 128 bytes.
* A = status.
blk_io  cpy #6
        jcs bk_nf
        lda DUNIT
        and #$0F
        tax
        cpy #5
        beq bk_set
        cpy #2
        bcc bk_xfer
        cpy #4
        beq bk_xfer
        jsr farcall            ; 2 flush, 3 abort
        dta b(BK_FMS),a(CARTLO+$15)
        rts
* bk_probe (bm_fread): the disk's sector size from DSK:'s information on
* it (kd_check: path+1 $80 128, $00 256, $01 512), remembered for the
* unit; nothing when the disk is not one DSK: reads. Keeps the DCB.
bk_probe ldx #0                 ; (the DCB kept on the stack)
bp1     lda DDEVIC,x
        pha
        inx
        cpx #12
        bcc bp1
        lda DUNIT
        and #$0F
        sta device
        ldy #19
        jsr jkernel
        sta bk_fn              ; (its status)
        ldx #11
bp2     pla
        sta DDEVIC,x
        dex
        bpl bp2
        lda #4
        ldy bk_fn
        sta bk_fn
        tya
        bmi bp_ret
        lda DUNIT
        and #$0F
        tax
        lda #0                 ; 256
        ldy #1
        lda path+1
        cmp #$80
        bne bp3
        lda #128
        ldy #0
        beq bp4
bp3     cmp #1
        bne bp3a
        ldy #2
bp3a    lda #0
bp4     jsr k_romoff
        sta bk_szl,x
        tya
        sta bk_szh,x
        jsr k_romon
bp_ret  rts

bk_set  jsr k_romoff            ; 5: the size (kept under the OS ROM)
        lda DBYTLO
        sta bk_szl,x
        lda DBYTLO+1
        sta bk_szh,x
        jsr k_romon
        lda #1
        rts
bk_nf   lda #E_NOFUNC
        rts
bk_xfer sty bk_fn
        cpy #1                 ; written or read past the cache: it forgets
        beq bk_x1              ; the drive's sectors
        cpy #4
        bne bk_x2
bk_x1   ldy #3
        jsr farcall
        dta b(BK_FMS),a(CARTLO+$15)
        lda bk_fn
        cmp #4
        bne bk_x1a
        jsr bk_probe
bk_x1a  ldx DUNIT
        txa
        and #$0F
        tax
bk_x2   jsr k_romoff
        lda bk_szl,x
        sta DBYTLO
        lda bk_szh,x
        sta DBYTLO+1
        jsr k_romon
        ora DBYTLO
        bne bk_x3
        lda #128
        sta DBYTLO
bk_x3   lda DAUX1+1            ; sectors 1-3: 128 bytes
        bne bk_x4
        lda DAUX1
        cmp #4
        bcs bk_x4
        lda #128
        sta DBYTLO
        lda #0
        sta DBYTLO+1
bk_x4   lda #8
        sta DTIMLO
        lda #'R'
        ldx #$40
        ldy bk_fn
        cpy #1
        bne bk_x5
        lda COMTAB-2           ; WRTCMD: P or W
        ldx #$80
bk_x5   sta DCOMND
        stx DSTATS
        jsr jsector_io
        rts


* The directory listing as SDX formats it (measured with tests/eos/FDT.asm).
* mode: $80 long; $40 attributes p a h; $20 a space between name and
* extension, a dot with $10; $08 short: (with $02) a colon marks
* directories, long: no seconds; $02 two columns, * for protected; $01
* short: size in sectors, long: 10 digits. $00 means $0B and $80 $A8.
* Lines are built in LBUF, as on SDX.

* fd_open: FILE_P, mode, scan; fd_open6: the same for D:'s mode 6, an
* error returned (A, N=1) instead of ending the program
fd_open lda #0
        sta fd_nf
        beq fd_o0
fd_open6 lda #$80
        sta fd_nf
fd_o0   lda mode
        jsr fd_mmode
        jsr farcall            ; the volume name and the sector size
        dta b(BK_LIB),a(L_GEFINA)
        lda device
        sta fd_dev
        ldy #19                ; kd_check
        jsr jkernel
        bmi fo_fail
        ldx #7
fo3     lda path+6,x
        sta fd_vol,x
        dex
        bpl fo3
        lda path+1             ; $80 128, $00 256, $01 512 bytes
        ldx #7
        cmp #$80
        beq fo4
        inx
        cmp #0
        beq fo4
        inx
fo4     stx fd_shf
        jsr farcall            ; the first entry
        dta b(BK_LIB),a(L_GEFINA)
        ldy #10                ; kd_first
        jsr jkernel
        sta fd_have
        bpl fo5
        cmp #E_EOF
        bne fo_fail
        lda #0                 ; nothing there
        sta fd_have
fo5     lda file_id
        sta fd_hnd
        lda #0
        sta fd_pos
        sta fd_len
        bit fd_mode
        bmi fo6
        lda #1                 ; short: no header
fo6     sta fd_st
        rts
fo_fail bit fd_nf
        bmi fo_err
        jsr farcall
        dta b(BK_LIB),a(L_FAIL)
fo_err  cmp #0                 ; (N=1)
        rts

* fd_close: the directory is closed
fd_close lda fd_hnd
        sta file_id
        ldy #7                 ; kd_close
        jmp jkernel

* fd_getc: the next byte in A, N=0; at the end N=1
fd_getc ldx fd_pos
        cpx fd_len
        bcc fg_byte
        lda fd_st              ; the next line
        cmp #3
        bcs fg_end
        lda #0
        sta fd_len
        sta fd_pos
        lda fd_st
        bne fg1
        jsr hdr
        jmp fd_getc
fg1     cmp #1
        bne fg2
        jsr entry
        jmp fd_getc
fg2     jsr free
        jmp fd_getc
fg_byte lda LBUF,x
        inc fd_pos
        sta fd_t
        php                    ; N=0
        pla
        and #$7F
        pha
        lda fd_t
        plp
        rts
fg_end  ldx #$FF
        lda #E_EOF             ; N=1
        rts

* hdr: the long format's header
hdr     lda #EOL
        jsr put
        ldy #voltxt-texts      ; Volume:
        jsr text0
        ldx #0
h1      lda fd_vol,x
        jsr put
        inx
        cpx #8
        bcc h1
        lda #EOL
        jsr put
        ldy #dirhtxt-texts     ; Directory:
        jsr text0
        ldx #0
h2      lda dir_name,x
        jsr put
        inx
        cpx #8
        bcc h2
        lda #EOL
        jsr put
        lda #EOL
        jsr put
        lda #1
        sta fd_st
        rts

* entry: the line for dentry, then the next entry
entry   lda fd_have
        bne en0
        lda #2                 ; no more: the free sectors
        sta fd_st
        rts
en0     jsr enline
        lda fd_hnd             ; the next entry
        sta file_id
        ldy #6                 ; kd_next
        jsr jkernel
        bpl en_ok
        lda #0
        sta fd_have
en_ok   rts

* fd_form: misc_formdir: dentry's line in LBUF as FDOPEN shows it, with
* the mode in attr; Y = its length (with the EOL)
fd_form lda attr
        jsr fd_mmode
        lda #0
        sta fd_len
        jsr enline
        ldy fd_len
        rts
* fd_mmode: FDOPEN's mode A ($00 and $80 as the old formats) to fd_mode
fd_mmode bne fm1
        lda #$0B
fm1     cmp #$80
        bne fm2
        lda #$A8
fm2     sta fd_mode
        rts

* enline: the line for dentry in LBUF
enline  lda fd_mode
        and #$02
        beq en3
        lda dentry             ; * protected
        and #$01
        beq en2a
        lda #'*'
        bne en2b
en2a    lda #' '
en2b    jsr put
        lda #' '               ; : a directory (short)
        bit fd_mode
        bmi en2c
        lda dentry
        and #$20
        beq en2d
        lda #':'
        dta b($2C)             ; bit abs: skip the next lda
en2c    lda #' '
        dta b($2C)
en2d    lda #' '
        jsr put
en3     ldx #0                 ; the name
en4     lda dentry+6,x
        jsr put
        inx
        cpx #8
        bcc en4
        lda fd_mode            ; space or dot
        and #$20
        beq en5
        lda fd_mode
        and #$10
        beq en4a
        lda #'.'
        dta b($2C)
en4a    lda #' '
        jsr put
en5     ldx #8                 ; the extension
en6     lda dentry+6,x
        jsr put
        inx
        cpx #11
        bcc en6
        bit fd_mode            ; attributes
        bvc en8
        lda #' '
        jsr put
        lda dentry
        ldx #'p'
        and #$01
        jsr atflag
        lda dentry
        ldx #'a'
        and #$04
        jsr atflag
        lda dentry
        ldx #'h'
        and #$02
        jsr atflag
en8     bit fd_mode
        bmi en_long
        lda fd_mode            ; short: sectors
        and #$01
        jeq en_eol
        lda #' '
        jsr put
        jsr sectors
        lda #3
        sta fd_w
        lda #'0'
        jsr num
        jmp en_eol
en_long lda #6                 ; long: size (6 or 10 digits) or <DIR>
        tax
        lda fd_mode
        and #$01
        beq en9
        ldx #10
en9     stx fd_w
        lda dentry
        and #$20
        beq en10
        txa                    ; a directory: <DIR> at the end of the field
        sec
        sbc #6
        tax
en9a    lda #' '
        jsr put
        dex
        bpl en9a
        ldy #dirtxt-texts
        jsr text0
        lda #' '
        jsr put
        jmp en11
en10    lda #' '
        jsr put
        ldx #2
en10a   lda dentry+3,x
        sta fd_v,x
        dex
        bpl en10a
        lda #0
        sta fd_v+3
        lda #' '
        jsr num
en11    lda dentry+17          ; no date (Atari DOS 2): none shown, as SDX
        jeq en_eol
        lda #' '               ; date d-mm-yy
        jsr put
        lda dentry+17
        ldx #' '
        jsr num2
        lda #'-'
        jsr put
        lda dentry+18
        ldx #'0'
        jsr num2
        lda #'-'
        jsr put
        lda dentry+19
        ldx #'0'
        jsr num2
        lda #' '               ; time h:mm[:ss]
        jsr put
        lda dentry+20
        ldx #' '
        jsr num2
        lda #':'
        jsr put
        lda dentry+21
        ldx #'0'
        jsr num2
        lda fd_mode
        and #$08
        bne en_eol
        lda #':'
        jsr put
        lda dentry+22
        ldx #'0'
        jsr num2
en_eol  lda #EOL
        jmp put

* free: the free sectors line, then the end
free    lda fd_dev
        sta device
        ldy #19                ; kd_check
        jsr jkernel
        lda path+4
        sta fd_v
        lda path+5
        sta fd_v+1
        lda #0
        sta fd_v+2
        sta fd_v+3
        bit fd_mode
        bmi fr_long
        lda fd_v+1             ; short: at most 999, 3 digits
        cmp #>1000
        bcc fr1
        bne fr0
        lda fd_v
        cmp #<1000
        bcc fr1
fr0     lda #<999
        sta fd_v
        lda #>999
        sta fd_v+1
fr1     lda #3
        sta fd_w
        lda #'0'
        bne fr2
fr_long lda #8
        sta fd_w
        lda #' '
fr2     jsr num
        ldy #freetxt-texts
        jsr text0
        lda #EOL
        jsr put
        lda #0                 ; as SDX 4.46: dentry's status 0 at the end
        sta dentry
        lda #3
        sta fd_st
        rts

* sectors: fd_v = dentry's length in sectors, rounded up
sectors ldx #2
se1     lda dentry+3,x
        sta fd_v,x
        dex
        bpl se1
        lda #0
        sta fd_v+3
        sta fd_t               ; any bits shifted out: one more
        ldy fd_shf
se2     lsr fd_v+2
        ror fd_v+1
        ror fd_v
        bcc se3
        inc fd_t
se3     dey
        bne se2
        lda fd_t
        beq se4
        inc fd_v
        bne se4
        inc fd_v+1
se4     rts

* atflag: X if A is not 0, else a dot
atflag  beq fl1
        txa
        dta b($2C)
fl1     lda #'.'
* put: A to the line
put     ldy fd_len
        sta LBUF,y
        inc fd_len
        rts

* num2: A (0-99) in two digits, the first one X when it is 0
num2    stx fd_t
        ldx #'0'-1
n2a     inx
        sec
        sbc #10
        bcs n2a
        adc #10+'0'
        pha
        txa
        cmp #'0'
        bne n2b
        lda fd_t
n2b     jsr put
        pla
        jmp put

* num: fd_v in decimal, at least fd_w places, padded with A
num     pha
        ldx #0                 ; digits, last first
nm1     lda #0
        ldy #32
nm2     asl fd_v
        rol fd_v+1
        rol fd_v+2
        rol fd_v+3
        rol @
        cmp #10
        bcc nm3
        sbc #10
        inc fd_v
nm3     dey
        bne nm2
        ora #'0'
        sta fd_dig,x
        inx
        lda fd_v
        ora fd_v+1
        ora fd_v+2
        ora fd_v+3
        bne nm1
        stx fd_t
        sec                    ; padding: fd_w - digits places
        lda fd_w
        sbc fd_t
        beq nm5
        bcc nm5
        sta fd_w
        pla
        pha
nm4     jsr put
        dec fd_w
        bne nm4
nm5     pla
        ldx fd_t
nm6     lda fd_dig-1,x
        jsr put
        dex
        bne nm6
        rts

* text0: the text at texts+Y (0 ended) to the line
text0   lda texts,y
        beq tx1
        jsr put_y
        iny
        bne text0
tx1     iny
        rts
put_y   sty fd_t
        jsr put
        ldy fd_t
        rts

texts
voltxt  dta c'Volume:    ',b(0)
dirhtxt dta c'Directory: ',b(0)
dirtxt  dta c'<DIR>',b(0)
freetxt dta c' FREE SECTORS',b(0)

        icl 'bw.icl'
        icl 'rx.icl'
        icl 'dk.icl'
        icl 'env.icl'

        icl 'tail.icl'
