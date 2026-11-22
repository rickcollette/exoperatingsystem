* RUNEXT.SYS (included in lib2.asm): file associations. rx_load reads the
* configuration (the parameter, else CAR:RUNEXT.CFG) to the memory at
* MEMLO, which stays raised; rx_find: a typed NAME.EXT with an association
* becomes PROGRAM [PARMS] (% the name, else the name at the end) and the
* rest of the line; rx_show lists the configuration (the RUNEXT command).
* A line: [!^]EXT[:EXT...],PROGRAM[,PARMS]; ; or * a comment; ! SHIFT and
* ^ CTRL held (with the RETURN that ended the line: KBCODE; in a batch
* file neither).

RX_MAX  equ 2048
rx_p    equ fadr               ; (the library's pointer)
rx_e    equ LBUFF+$70          ; scratch (the new line is built at LBUFF)
rx_k    equ LBUFF+$71
rx_m    equ LBUFF+$72
rx_t    equ LBUFF+$73
rx_pc   equ LBUFF+$74

rx_load jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        bne xl2
        ldx #0                 ; none: CAR:RUNEXT.CFG
xl1     lda rx_def,x
        sta COMTAB+CT_COMFNAM,x
        inx
        cmp #EOL
        bne xl1
xl2     lda #<(COMTAB+CT_COMFNAM)
        sta FILE_P
        lda #>(COMTAB+CT_COMFNAM)
        sta FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        jsr farcall
        dta b(BK_LIB),a(L_FOPEN)
        lda MEMLO
        sta rx_buf
        sta addpos
        lda MEMLO+1
        sta rx_buf+1
        sta addpos+1
        lda #<RX_MAX
        sta bytbuf
        lda #>RX_MAX
        sta bytbuf+1
        lda #0
        sta memreix
        jsr farcall
        dta b(BK_LIB),a(L_FREAD)
        jsr farcall
        dta b(BK_LIB),a(L_FCLOSE)
        lda rx_buf             ; its end: a 0, MEMLO past it
        clc
        adc bytbuf
        sta rx_p
        lda rx_buf+1
        adc bytbuf+1
        sta rx_p+1
        ldy #0
        tya
        sta (rx_p),y
        lda rx_p
        clc
        adc #1
        sta MEMLO
        lda rx_p+1
        adc #0
        sta MEMLO+1
        lda #$80
        sta rx_on
        rts
rx_def  dta c'CAR:runext.cfg',b(EOL)

* rx_show: the configuration as it is in memory
rx_show bit rx_on
        bpl xs_ret
        lda rx_buf
        sta rx_q
        lda rx_buf+1
        sta rx_q+1
xs1     lda rx_q               ; (PUTC uses fadr)
        sta rx_p
        lda rx_q+1
        sta rx_p+1
        ldy #0
        lda (rx_p),y
        beq xs_ret
        jsr farcall
        dta b(BK_LIB),a(L_PUTC)
        inc rx_q
        bne xs1
        inc rx_q+1
        bne xs1
xs_ret  rts

* rx_find: C=0 when COMFNAM's extension has an association: LBUF is the
* new command line; C=1 none
rx_find bit rx_on
        jpl xf_no
        ldx #0                 ; the extension: after the last dot of the name
        ldy #0
xf1     lda COMTAB+CT_COMFNAM,x
        cmp #EOL
        beq xf3
        inx
        cmp #'.'
        bne xf2
        txa
        tay
xf2     cmp #'/'
        beq xf2a
        cmp #':'
        beq xf2a
        cmp #BSLASH
        bne xf1
xf2a    ldy #0
        beq xf1
xf3     tya
        jeq xf_no
        sty rx_e
        lda #0                 ; SHIFT $40, CTRL $80 with the RETURN typed
        ldx cp_bat             ; (none in a batch file)
        bpl xf3a
        lda KBCODE
        and #$C0
xf3a    sta rx_k
        lda rx_buf
        sta rx_p
        lda rx_buf+1
        sta rx_p+1
xf_line ldy #0                 ; a line at rx_p
        lda (rx_p),y
        jeq xf_no
        cmp #';'
        beq xf_next
        cmp #'*'
        beq xf_next
        cmp #EOL
        beq xf_next
        lda #0
        sta rx_m
xf_mod  lda (rx_p),y
        cmp #'!'
        bne xf_m2
        lda #$40
        bne xf_m3
xf_m2   cmp #'^'
        bne xf_ext
        lda #$80
xf_m3   ora rx_m
        sta rx_m
        iny
        bne xf_mod
xf_ext  ldx rx_e               ; one extension of the list against the name's
xf_e1   lda (rx_p),y
        cmp #':'
        beq xf_e2
        cmp #','
        beq xf_e2
        cmp #EOL
        beq xf_next
        cmp COMTAB+CT_COMFNAM,x
        bne xf_skip
        iny
        inx
        bne xf_e1
xf_e2   lda COMTAB+CT_COMFNAM,x ; the whole extension?
        cmp #EOL
        bne xf_skip
        lda rx_m
        cmp rx_k
        beq xf_hit
xf_skip lda (rx_p),y           ; the next extension of the list
        cmp #EOL
        beq xf_next
        cmp #','
        beq xf_next
        iny
        cmp #':'
        bne xf_skip
        beq xf_ext
xf_next ldy #0                 ; past the EOL
xn1     lda (rx_p),y
        beq xf_no
        iny
        cmp #EOL
        bne xn1
        tya
        clc
        adc rx_p
        sta rx_p
        jcc xf_line
        inc rx_p+1
        jne xf_line
xf_no   sec
        rts
xf_hit  lda (rx_p),y           ; to the program
        cmp #','
        beq xh1
        iny
        bne xf_hit
xh1     iny
        ldx #0                 ; the program
xh2     lda (rx_p),y
        cmp #','
        beq xh3
        cmp #EOL
        beq xh3
        sta LBUFF,x
        inx
        iny
        bne xh2
xh3     sta rx_t
        lda #' '
        sta LBUFF,x
        inx
        lda #0
        sta rx_pc
        lda rx_t
        cmp #','
        bne xh_name
        iny
xh4     lda (rx_p),y           ; the parameters, % the name
        cmp #EOL
        beq xh6
        iny
        cmp #'%'
        bne xh5
        dec rx_pc
        sty rx_t
        jsr xh_nm
        ldy rx_t
        jmp xh4
xh5     cpx #63
        bcs xh4
        sta LBUFF,x
        inx
        bne xh4
xh6     lda rx_pc
        bne xh_rest
xh_name lda #' '               ; no %: the name at the end
        cpx #63
        bcs xh_rest
        dex                    ; (no double blank)
        lda LBUFF,x
        inx
        cmp #' '
        beq xh7
        lda #' '
        sta LBUFF,x
        inx
xh7     jsr xh_nm
xh_rest ldy COMTAB+CT_BUFOFF    ; the rest of the line, after a blank
        lda LBUF,y
        cmp #EOL
        beq xr2
        cmp #' '
        beq xr1
        lda #' '
        sta LBUFF,x
        inx
xr1     lda LBUF,y
        cmp #EOL
        beq xr2
        cpx #63
        bcs xr2
        sta LBUFF,x
        inx
        iny
        bne xr1
xr2     lda #EOL
        sta LBUFF,x
        ldx #0
xr3     lda LBUFF,x
        sta LBUF,x
        inx
        cmp #EOL
        bne xr3
        clc
        rts
* xh_nm: the file's name (COMFNAM) to LBUFF+X
xh_nm   ldy #0
xm1     lda COMTAB+CT_COMFNAM,y
        cmp #EOL
        beq xm2
        cpx #63
        bcs xm2
        sta LBUFF,x
        inx
        iny
        bne xm1
xm2     rts
