; EOS CAR: shared part of X and CAR: an Atari DOS binary file loaded and
; run with the cartridge switched off, so $A000-$BFFF is RAM for it.
;
; The program in this file stays in main memory while the other runs. The
; library is in the cartridge, so it is only used with the cartridge on:
; the file is read with FREAD into xs_buf and copied to its place with the
; cartridge off (or read straight there when the place is plain main
; memory). INIT and RUN routines run with the cartridge off. The kernel's
; D: handler and devices switch the cartridge on for each call and back off
; afterwards (farcall reselects the bank in _CURBANK).
;
; Uses the kernel's _CURBANK (the byte curbank) and _SETBANK (setbank:
; select bank A, $80 = cartridge off).
;
; Interface: xs_name = the file (EOL ended; .COM added when there is no
; extension), xs_mode = loading mode as U_LOAD's FLAG ($00 INIT and RUN,
; run from the first segment without RUN; $40 RUN only when given; $80
; neither; $C0 INIT only), xs_top <> 0 moves the screen to the top of
; memory (RAMTOP $C0, X) else it stays (CAR), xs_clr <> 0 clears $80-$FF,
; $0400-$06FF and MEMLO-MEMTOP first. jsr xs_go: back when the program
; ends with RTS or JMP (DOSVEC); errors go to U_FAIL after the system is
; put back. The including program defines the addresses (Xequ.icl) before
; its blk reloc.

xs_go   jsr xs_open            ; the file, from here or along $PATH
        jsr xs_get2            ; a binary file: $FFFF
        jcs xs_nbin
        lda xs_w
        and xs_w+1
        cmp #$FF
        jne xs_nbin
        lda _CURBANK           ; the system's bank, to come back to
        sta xs_lib
        lda DOSVEC
        sta xs_dosv
        lda DOSVEC+1
        sta xs_dosv+1
        lda RAMTOP
        sta xs_rtop
        lda xs_trap            ; errors from here on: the system back first
        ldx xs_trap+1
        jsr U_SFAIL
        tsx
        stx xs_sp
        lda #CARTOFF
        jsr _SETBANK
        lda xs_top             ; X: the screen to the top of memory
        beq xg1
        lda #$C0
        sta RAMTOP
        jsr xs_scr
xg1     lda xs_clr
        beq xg2
        jsr xs_clear
xg2     lda xs_lib
        jsr _SETBANK
        lda #0
        sta RUNAD
        sta RUNAD+1
        sta xs_first+1
        jsr xs_load
        lda xs_fid
        sta file_id
        jsr FCLOSE
        jsr U_XFAIL
        bit xs_mode            ; $80, $C0: not run
        bmi xs_back
        lda RUNAD
        ora RUNAD+1
        bne xg3
        bit xs_mode            ; $40: only with a RUN address
        bvs xs_back
        lda xs_first
        sta RUNAD
        lda xs_first+1
        sta RUNAD+1
xg3     lda xs_dosa            ; JMP (DOSVEC) comes back here
        sta DOSVEC
        lda xs_dosa+1
        sta DOSVEC+1
        tsx
        stx xs_sp
        lda #CARTOFF
        jsr _SETBANK
        jsr xs_run
xs_dos  ldx xs_sp              ; the program has ended
        txs
        lda xs_dosv
        sta DOSVEC
        lda xs_dosv+1
        sta DOSVEC+1
xs_back jsr xs_rest
        rts
xs_run  jmp (RUNAD)

* the system back: the screen below the cartridge, the cartridge on
xs_rest lda #CARTOFF
        jsr _SETBANK
        lda RAMTOP
        cmp xs_rtop
        beq xr1
        lda xs_rtop
        sta RAMTOP
        jsr xs_scr
xr1     lda xs_lib
        jmp _SETBANK

* an error after the switch: the system back, then the error
xs_err  sta xs_code
        ldx xs_sp
        txs
        jsr xs_rest
        lda xs_code
        jmp U_FAIL
xs_nbin lda #152               ; not an Atari DOS binary file
        jmp U_FAIL

* xs_scr (cartridge off): E: closed and opened again, so the OS puts the
* screen under the new RAMTOP. Opening E: clears the screen; SDX keeps
* what is on it, so a text screen (graphics 0) is copied to the new place
* with the cursor where it was: its position, the logical line map and
* the character under the cursor (OLDCHR at OLDADR).
xs_scr  ldx #11                ; ROWCRS ... OLDADR, and LOGMAP
xs1     lda ROWCRS,x
        sta xs_crs,x
        dex
        bpl xs1
        ldx #2
xs2     lda LOGMAP,x
        sta xs_lmap,x
        dex
        bpl xs2
        lda DINDEX             ; graphics 0: the text is copied
        sta xs_gr
        lda SAVMSC
        sta xs_from
        lda SAVMSC+1
        sta xs_from+1
        ldx #0
        lda #12
        sta IOCB0+2
        jsr CIOV
        ldx #0
        lda #3
        sta IOCB0+2
        lda xs_ena
        sta IOCB0+4
        lda xs_ena+1
        sta IOCB0+5
        lda #12
        sta IOCB0+10
        lda #0
        sta IOCB0+11
        jsr CIOV
        lda xs_gr
        bne xs_sret
        lda DINDEX
        bne xs_sret
        lda xs_from            ; 960 bytes: 3 pages and 192
        sta xs_ld+1
        lda xs_from+1
        sta xs_ld+2
        lda SAVMSC
        sta xs_st+1
        lda SAVMSC+1
        sta xs_st+2
        ldx #4
        ldy #0
xs_ld   lda $FFFF,y
xs_st   sta $FFFF,y
        iny
        cpx #1
        bne xs3
        cpy #192
        beq xs4
xs3     tya
        bne xs_ld
        inc xs_ld+2
        inc xs_st+2
        dex
        bne xs_ld
xs4     sec                    ; OLDADR: the same place on the new screen
        lda xs_crs+10
        sbc xs_from
        sta xs_crs+10
        lda xs_crs+11
        sbc xs_from+1
        sta xs_crs+11
        clc
        lda xs_crs+10
        adc SAVMSC
        sta xs_crs+10
        lda xs_crs+11
        adc SAVMSC+1
        sta xs_crs+11
        ldx #11                ; the cursor, except DINDEX and SAVMSC
xs5     cpx #3
        beq xs6
        cpx #4
        beq xs6
        cpx #5
        beq xs6
        lda xs_crs,x
        sta ROWCRS,x
xs6     dex
        bpl xs5
        ldx #2
xs7     lda xs_lmap,x
        sta LOGMAP,x
        dex
        bpl xs7
xs_sret rts

* xs_clear (cartridge off): $80-$FF, $0400-$06FF, MEMLO up to MEMTOP
xs_clear lda #0
        ldx #$80
xc1     sta $00,x
        inx
        bne xc1
        ldx #0
xc2     sta $0400,x
        sta $0500,x
        sta $0600,x
        inx
        bne xc2
        lda MEMLO
        sta xs_p
        lda MEMLO+1
        sta xs_p+1
xc3     lda xs_p+1
        cmp MEMTOP+1
        bcc xc4
        bne xc5
        lda xs_p
        cmp MEMTOP
        beq xc4
        bcs xc5
xc4     lda #0
        ldx xs_p+1             ; one byte at (xs_p)
        stx xc_st+2
        ldx xs_p
        stx xc_st+1
xc_st   sta $FFFF
        inc xs_p
        bne xc3
        inc xs_p+1
        bne xc3
xc5     rts

* ---- the segments ----------------------------------------------------------
xs_load jsr xs_get2            ; start, or another $FFFF
        bcs xl_ret             ; the end of the file
        lda xs_w
        and xs_w+1
        cmp #$FF
        beq xs_load
        lda xs_w
        sta xs_beg
        lda xs_w+1
        sta xs_beg+1
        jsr xs_get2            ; end
        jcs xs_trunc
        sec                    ; length = end - start + 1
        lda xs_w
        sbc xs_beg
        sta xs_len
        lda xs_w+1
        sbc xs_beg+1
        sta xs_len+1
        jcc xs_trunc
        inc xs_len
        bne xl1
        inc xs_len+1
xl1     lda xs_first+1         ; the first segment: RUN without a RUN address
        bne xl2
        lda xs_beg
        sta xs_first
        lda xs_beg+1
        sta xs_first+1
xl2     lda xs_w+1             ; not over the kernel or this program
        cmp #$07               ; ($0700 up to MEMLO)
        bcc xl3
        lda xs_beg+1
        cmp MEMLO+1
        bcc xl_conf
        bne xl3
        lda xs_beg
        cmp MEMLO
        bcs xl3
xl_conf lda #179
        jmp U_FAIL
xl_ret  rts
xl3     lda #0
        sta INITAD
        sta INITAD+1
        jsr xs_data
        lda INITAD
        ora INITAD+1
        beq xs_load
        bit xs_mode            ; $80: no INIT ($C0 has it)
        bpl xl4
        jvc xs_load
xl4     lda #CARTOFF
        jsr _SETBANK
        jsr xs_init
        lda xs_lib
        jsr _SETBANK
        jmp xs_load
xs_init jmp (INITAD)
xs_trunc lda #152              ; the file ends inside a segment
        jmp U_FAIL

* xs_data: xs_len bytes of the file to xs_beg; straight there when the
* place is main memory from MEMLO up to $9FFF, else through xs_buf
xs_data lda xs_beg+1
        cmp MEMLO+1
        bcc xd_buf
        bne xd1
        lda xs_beg
        cmp MEMLO
        bcc xd_buf
xd1     clc                    ; the end at most $A000
        lda xs_beg
        adc xs_len
        tax
        lda xs_beg+1
        adc xs_len+1
        bcs xd_buf
        cmp #$A0
        bcc xd1a
        bne xd_buf
        cpx #0
        bne xd_buf
xd1a    lda xs_beg
        sta addpos
        lda xs_beg+1
        sta addpos+1
        lda xs_len
        sta bytbuf
        lda xs_len+1
        sta bytbuf+1
        jsr xs_read
        lda bytbuf
        cmp xs_len
        jne xs_trunc
        lda bytbuf+1
        cmp xs_len+1
        jne xs_trunc
        rts
xd_buf  lda xs_len             ; a piece: up to 256 bytes
        ora xs_len+1
        jeq xd_ret
        lda xs_len+1
        beq xd2
        lda #0                 ; 256
        sta xs_n
        lda #1
        bne xd3
xd2     lda xs_len
        sta xs_n
        lda #0
xd3     sta bytbuf+1
        lda xs_n
        sta bytbuf
        lda xs_bufa
        sta addpos
        lda xs_bufa+1
        sta addpos+1
        jsr xs_read
        lda bytbuf             ; all of it?
        cmp xs_n
        jne xs_trunc
        lda xs_n
        bne xd4
        lda bytbuf+1
        jeq xs_trunc
xd4     lda xs_beg             ; copy it with the cartridge off
        sta xd_st+1
        lda xs_beg+1
        sta xd_st+2
        lda xs_bufa
        sta xd_ld+1
        lda xs_bufa+1
        sta xd_ld+2
        lda #CARTOFF
        jsr _SETBANK
        ldy #0
xd_ld   lda $FFFF,y
xd_st   sta $FFFF,y
        iny
        cpy xs_n
        bne xd_ld
        lda xs_lib
        jsr _SETBANK
        lda xs_n               ; the rest
        bne xd5
        dec xs_len+1           ; 256 done
        inc xs_beg+1
        jmp xd_buf
xd5     sec
        lda xs_len
        sbc xs_n
        sta xs_len
        bcs xd6
        dec xs_len+1
xd6     clc
        lda xs_beg
        adc xs_n
        sta xs_beg
        jcc xd_buf
        inc xs_beg+1
        jmp xd_buf
xd_ret  rts

* xs_read: FREAD from the file into main memory
xs_read lda xs_fid
        sta file_id
        lda #0
        sta memreix
        jmp FREAD

* xs_get2: the next two bytes to xs_w; C=1 at the end of the file
xs_get2 lda xs_wa
        sta addpos
        lda xs_wa+1
        sta addpos+1
        lda #2
        sta bytbuf
        lda #0
        sta bytbuf+1
        jsr xs_read
        lda bytbuf
        cmp #2
        bcc xg_end
        clc
        rts
xg_end  sec
        rts

* ---- the file -------------------------------------------------------------
* xs_open: xs_name opened (.COM when it has no extension), as given, then
* (a name without device or directory) after each $PATH entry; xs_fid.
* None: 170.
xs_open ldx #0                 ; the extension, and whether a device or
        stx xs_dir             ; directory is given
        stx xs_dot
xo1     lda xs_name,x
        cmp #EOL
        beq xo3
        cmp #'.'
        bne xo2
        sta xs_dot
xo2     cmp #':'
        beq xo2a
        cmp #'>'
        beq xo2a
        cmp #BSLASH
        bne xo2b
xo2a    sta xs_dir
        lda #0
        sta xs_dot
xo2b    inx
        bne xo1
xo3     lda xs_dot
        bne xo4
        ldy #0
xo3a    lda xs_com,y
        sta xs_name,x
        inx
        iny
        cmp #EOL
        bne xo3a
xo4     ldx #0                 ; as given
        jsr xs_try
        bcc xo_ret
        lda xs_dir
        bne xo_no
        lda xs_pna             ; $PATH, to a buffer of its own
        ldx xs_pna+1
        jsr GETENV
        bmi xo_no
        ldx #0
xo5     lda $0580,x
        sta xs_path,x
        inx
        cmp #EOL
        beq xo5a
        cpx #63
        bcc xo5
        lda #EOL
        sta xs_path,x
xo5a    lda #0
        sta xs_pi
xo6     ldy xs_pi              ; the next entry
        lda xs_path,y
        cmp #EOL
        beq xo_no
        ldx #0
xo7     lda xs_path,y
        cmp #';'
        beq xo8
        cmp #EOL
        beq xo9
        sta xs_try1,x
        inx
        iny
        cpx #32
        bcc xo7
xo8     iny
xo9     sty xs_pi
        txa                    ; a separator after a directory name
        beq xo10
        lda xs_try1-1,x
        cmp #':'
        beq xo10
        cmp #'>'
        beq xo10
        cmp #BSLASH
        beq xo10
        lda #'>'
        sta xs_try1,x
        inx
xo10    jsr xs_try
        bcs xo6
xo_ret  rts
xo_no   lda #170               ; not named (SDX)
        jmp fe_end

* xs_try: xs_try1+X = xs_name, opened for reading: C=0 xs_fid, C=1 not
xs_try  ldy #0
xt1     lda xs_name,y
        sta xs_try1,x
        inx
        iny
        cmp #EOL
        beq xt2
        cpx #95
        bcc xt1
        lda #EOL
        sta xs_try1,x
xt2     lda xs_t1a
        sta FILE_P
        lda xs_t1a+1
        sta FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        lda xs_tna
        ldx xs_tna+1
        jsr U_SFAIL
        jsr FOPEN
        jsr U_XFAIL
        lda file_id
        sta xs_fid
        clc
        rts
xs_tno  sec
        rts

* xs_lmode: the loading mode at COMTAB+$21+X: S, A, N, I or a number
xs_lmode lda COMTAB+$22,x
        cmp #EOL
        bne xm_num
        lda COMTAB+$21,x
        ldy #3
xm_lm1  cmp xm_ch,y
        beq xm_lm2
        dey
        bpl xm_lm1
        bmi xm_num
xm_lm2  lda xm_val,y
        sta xs_mode
        rts

* xm_num: the decimal or $hex number 0-255 at COMTAB+$21+X to xs_mode
* (anything else leaves xs_mode as it is)
xm_num  lda #0
        sta xm_v
        lda COMTAB+$21,x
        cmp #'$'
        beq xm_n_hex
xm_n1   lda COMTAB+$21,x
        cmp #EOL
        beq xm_n_end
        sec
        sbc #'0'
        cmp #10
        jcs xm_ret
        sta xm_d
        lda xm_v                ; v = v * 10 + d
        asl @
        jcs xm_ret
        asl @
        jcs xm_ret
        adc xm_v
        jcs xm_ret
        asl @
        jcs xm_ret
        adc xm_d
        jcs xm_ret
        sta xm_v
        inx
        bne xm_n1
xm_n_hex inx
        lda COMTAB+$21,x
        cmp #EOL
        jeq xm_ret
xm_n2   lda COMTAB+$21,x
        cmp #EOL
        beq xm_n_end
        sec
        sbc #'0'
        cmp #10
        bcc xm_n3
        sbc #7
        cmp #10
        jcc xm_ret
        cmp #16
        jcs xm_ret
xm_n3   sta xm_d
        lda xm_v
        cmp #16
        jcs xm_ret
        asl @
        asl @
        asl @
        asl @
        ora xm_d
        sta xm_v
        inx
        bne xm_n2
xm_n_end lda xm_v
        sta xs_mode
xm_ret  rts


xs_trap dta a(xs_err)
xs_tna  dta a(xs_tno)
xs_dosa dta a(xs_dos)
xs_ena  dta a(xs_e)
xs_bufa dta a(xs_buf)
xs_wa   dta a(xs_w)
xs_pna  dta a(xs_pnm)
xs_t1a  dta a(xs_try1)
xs_e    dta c'E:',EOL
xs_pnm  dta c'PATH',EOL
xs_com  dta c'.COM',EOL
xs_mode dta 0
xs_top  dta 0
xs_clr  dta 0
xs_lib  dta 0
xs_rtop dta 0
xs_sp   dta 0
xs_fid  dta 0
xs_code dta 0
xs_crs  :12 dta 0
xs_lmap :3 dta 0
xs_gr   dta 0
xs_from dta a(0)
xs_dosv dta a(0)
xs_first dta a(0)
xs_beg  dta a(0)
xs_len  dta a(0)
xs_n    dta 0
xs_p    dta a(0)
xs_w    dta a(0)
xs_dir  dta 0
xs_dot  dta 0
xs_pi   dta 0
xm_v    dta 0
xm_d    dta 0
xm_ch   dta c'SANI'
xm_val  dta b(0,64,128,192)
xs_name :64 dta 0
xs_path :64 dta 0
xs_try1 :100 dta 0
xs_buf  :256 dta 0
