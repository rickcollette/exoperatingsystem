* The environment (included in lib2.asm): records NAME=VALUE, each ending
* in EOL, then a 0, at ENV_P: under the OS ROM (memory index 2, 256 bytes,
* ENVBUF), or, after ENV.SYS, in an extended bank of its own (16 KiB at
* $4000). Every byte goes through ev_rd/ev_wr at the 16-bit offset ev_o,
* so names and values are copied to low memory (LBUFF) first: a program's
* name may itself be in $4000-$7FFF.

ev_zp   equ $43                ; (a pointer of the FMS's, kept)
EV_BIG  equ $4000              ; ENV.SYS's size

* ev_rd: A = the byte at ev_o (Z, N from it); ev_wr: A to it. Keep X, Y.
ev_wr   sta ev_a
        lda #0
        beq ev_go
ev_rd   lda #$80
ev_go   sta ev_dirf
        txa
        pha
        tya
        pha
        lda ev_zp
        pha
        lda ev_zp+1
        pha
        clc
        lda ENV_P
        adc ev_o
        sta ev_zp
        lda ENV_P+1
        adc ev_o+1
        sta ev_zp+1
        lda ENV_P+2
        cmp #2
        bne er_bank
        lda PORTB              ; under the OS ROM
        pha
        and #$FE
        sta PORTB
        jsr er_do
        pla
        sta PORTB
        jmp er_x
er_bank jsr k_setme            ; in its bank (A: its index)
        jsr er_do
        jsr k_popme
er_x    pla
        sta ev_zp+1
        pla
        sta ev_zp
        pla
        tay
        pla
        tax
        lda ev_a
        rts
er_do   ldy #0
        bit ev_dirf
        bpl er_w
        lda (ev_zp),y
        sta ev_a
        rts
er_w    lda ev_a
        sta (ev_zp),y
        rts

* ev_lim: the environment's size, in ev_t
ev_lim  lda #0
        sta ev_t
        lda #1
        ldx ENV_P+2
        cpx #2
        beq vel1
        lda #>EV_BIG
vel1     sta ev_t+1
        rts

* ev_nxt: ev_o past the record at ev_o (its EOL); A = the byte there then
ev_nxt  jsr ev_rd
        jsr ev_inc
        cmp #EOL
        bne ev_nxt
        jmp ev_rd
ev_inc  inc ev_o
        bne vei1
        inc ev_o+1
vei1     rts

* en_find: the name at (fadr) (ended by = or EOL; below $4000) looked up: C=0, ev_s its
* record, ev_v its value, ev_e the next record; C=1 none (ev_s: the end)
en_find lda #0
        sta ev_o
        sta ev_o+1
vef_rec  lda ev_o
        sta ev_s
        lda ev_o+1
        sta ev_s+1
        jsr ev_rd
        beq vef_no
        ldy #0
vef_c    lda (fadr),y
        cmp #'='
        beq vef_end
        cmp #EOL
        beq vef_end
        sta ev_t
        jsr ev_rd
        cmp ev_t
        bne vef_skip
        jsr ev_inc
        iny
        bne vef_c
vef_end  jsr ev_rd
        cmp #'='
        bne vef_skip
        jsr ev_inc
        lda ev_o
        sta ev_v
        lda ev_o+1
        sta ev_v+1
        jsr ev_nxt             ; past the EOL: the next record
        lda ev_o
        sta ev_e
        lda ev_o+1
        sta ev_e+1
        clc
        rts
vef_skip lda ev_s               ; the next record
        sta ev_o
        lda ev_s+1
        sta ev_o+1
        jsr ev_nxt
        jmp vef_rec
vef_no   sec
        rts

* en_name: the string at AX (to its EOL, 127 at most) to LBUFF
en_name sta fadr
        stx fadr+1
        ldy #0
ven1     lda (fadr),y
        sta LBUFF,y
        cmp #EOL
        beq ven2
        iny
        bpl ven1
        lda #EOL
        sta LBUFF+127
ven2     rts

* GETENV: AX = the name (EOL ended); A=0, N=0 and the value in LBUFF, or
* A=$FF, N=1 when there is none
en_get  jsr en_name
        jsr en_find
        bcs en_none
        lda ev_v
        sta ev_o
        lda ev_v+1
        sta ev_o+1
        ldx #0
* en_copy: from ev_o to LBUFF+X, with its EOL (127 at most)
en_copy jsr ev_rd
        sta LBUFF,x
        cmp #EOL
        beq vec_ok
        jsr ev_inc
        inx
        bpl en_copy
        lda #EOL
        sta LBUFF+127
vec_ok   lda #0
        rts
en_none lda #$FF
        rts

* NUMENV: A = a variable's number: A=0, N=0 and NAME=VALUE in LBUFF, or
* A=$FF, N=1
en_num  sta ev_n
        lda #0
        sta ev_o
        sta ev_o+1
vnm1     jsr ev_rd
        beq en_none
        dec ev_n
        bmi vnm2
        jsr ev_nxt
        jmp vnm1
vnm2     ldx #0
        jmp en_copy

* PUTENV: AX = NAME=VALUE (EOL ended): the variable replaced; NAME alone
* deletes it. A = its first character, N=0; A=$FF, N=1 when it does not
* fit.
en_put  jsr en_name
        jsr en_find
        bcs vep_add
        lda ev_e               ; the old one out: the rest moves down
        sta ev_o
        lda ev_e+1
        sta ev_o+1
vep1     jsr ev_rd
        pha
        lda ev_s
        sta ev_o
        lda ev_s+1
        sta ev_o+1
        pla
        jsr ev_wr
        cmp #0
        beq vep2
        inc ev_s
        bne vep1a
        inc ev_s+1
vep1a    inc ev_e
        bne vep1b
        inc ev_e+1
vep1b    lda ev_e
        sta ev_o
        lda ev_e+1
        sta ev_o+1
        jmp vep1
vep2     lda #0                 ; the end
        sta ev_o
        sta ev_o+1
vep3     jsr ev_rd
        beq vep_add2
        jsr ev_nxt
        jmp vep3
vep_add  lda ev_s               ; (en_find left the end there)
        sta ev_o
        lda ev_s+1
        sta ev_o+1
vep_add2 ldy #0                 ; NAME alone: deleted, nothing more
vep4     lda LBUFF,y
        cmp #'='
        beq vep5
        iny
        cmp #EOL
        bne vep4
        beq vep_ok
vep5     ldy #0                 ; its length with the EOL and the 0 after it
vep6     lda LBUFF,y
        iny
        cmp #EOL
        bne vep6
        iny
        sty ev_n
        jsr ev_lim             ; room?
        clc
        lda ev_o
        adc ev_n
        tax
        lda ev_o+1
        adc #0
        cpx ev_t
        sbc ev_t+1
        bcs vep_no
        ldy #0                 ; appended
vep7     lda LBUFF,y
        jsr ev_wr
        jsr ev_inc
        iny
        cmp #EOL
        bne vep7
        lda #0
        jsr ev_wr
vep_ok   lda LBUFF
        rts
vep_no   lda #0                 ; (the old one was deleted: the end again)
        jsr ev_wr
        lda #$FF
        rts

* en_getx: the command processor's envget: the value of cp_nm (EOL ended)
* to LBUFF+X, up to LBUFF+cp_lim: C=0, X past it; C=1 none (X kept)
en_getx stx ev_x2
        lda #<cp_nm            ; (not copied: LBUFF holds the caller's line)
        sta fadr
        lda #>cp_nm
        sta fadr+1
        jsr en_find
        bcs veg_no
        lda ev_v
        sta ev_o
        lda ev_v+1
        sta ev_o+1
        ldx ev_x2
veg1     jsr ev_rd
        cmp #EOL
        beq veg2
        cpx cp_lim
        bcs veg2
        sta LBUFF,x
        jsr ev_inc
        inx
        bne veg1
veg2     clc
        rts
veg_no   ldx ev_x2
        sec
        rts

* en_front: the last variable moved to the front (the command processor's
* SET order for a startup batch file's _01 ...)
en_front lda #0                ; the last one's start (ev_s) and the end
        sta ev_o
        sta ev_o+1
        sta ev_s
        sta ev_s+1
vef1     jsr ev_rd
        beq vef3
        lda ev_o
        sta ev_s
        lda ev_o+1
        sta ev_s+1
        jsr ev_nxt
        jmp vef1
vef3     lda ev_o               ; its length (to LBUFF), ev_e the end
        sta ev_e
        lda ev_o+1
        sta ev_e+1
        lda ev_s
        sta ev_o
        lda ev_s+1
        sta ev_o+1
        ldx #0
vef4     lda ev_o
        cmp ev_e
        lda ev_o+1
        sbc ev_e+1
        bcs vef5
        jsr ev_rd
        sta LBUFF,x
        jsr ev_inc
        inx
        bpl vef4
vef5     stx ev_n               ; the others up by it, from the top down
vef6     lda ev_s
        ora ev_s+1
        beq vef7
        lda ev_s
        bne vef6a
        dec ev_s+1
vef6a    dec ev_s
        lda ev_s
        sta ev_o
        lda ev_s+1
        sta ev_o+1
        jsr ev_rd
        pha
        clc
        lda ev_s
        adc ev_n
        sta ev_o
        lda ev_s+1
        adc #0
        sta ev_o+1
        pla
        jsr ev_wr
        jmp vef6
vef7     ldx #0                 ; it at the front
        stx ev_o
        stx ev_o+1
vef8     cpx ev_n
        bcs vef9
        lda LBUFF,x
        jsr ev_wr
        jsr ev_inc
        inx
        bne vef8
vef9     rts

* en_big: ENV.SYS: the environment to a bank of its own (16 KiB at $4000,
* the top free one: NBANKS less one, as CON.SYS takes its bank), resident
en_big  lda ENV_P+2
        cmp #2
        bne veb_ret             ; (already)
        ldy COMTAB+$1D         ; NBANKS
        beq veb_ret             ; no extended RAM: it stays where it is
        dey
        sty COMTAB+$1D
        tya
        clc
        adc #4
        sta ev_n               ; the bank's memory index
        lda #0                 ; the 256 bytes over, a byte at a time
        sta ev_o
        sta ev_o+1
veb1     jsr ev_rd              ; (from ENVBUF)
        pha
        lda ENV_P+2
        pha
        lda #<$4000
        sta ENV_P
        lda #>$4000
        sta ENV_P+1
        lda ev_n
        sta ENV_P+2
        pla
        tax
        pla
        jsr ev_wr              ; (to the bank)
        stx ENV_P+2
        lda #<ENVBUF
        sta ENV_P
        lda #>ENVBUF
        sta ENV_P+1
        inc ev_o
        bne veb1
        lda #<$4000            ; from now on there
        sta ENV_P
        lda #>$4000
        sta ENV_P+1
        lda ev_n
        sta ENV_P+2
        dec INSTALL            ; (the bank stays taken)
veb_ret  rts
