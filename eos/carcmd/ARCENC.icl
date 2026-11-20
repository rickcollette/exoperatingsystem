* ARC: packing (runs) and crunching (LZW) a file

* rle_emit / lzw_emit: where the packed bytes and the crunched bytes go
* (the operands are set by setv); both keep X
rle_emit jmp $FFFF
lzw_emit jmp $FFFF

* setv: rle_emit to vtab entry X, lzw_emit to entry Y
setv    lda vtab,x
        sta rle_emit+1
        lda vtab+1,x
        sta rle_emit+2
        lda vtab,y
        sta lzw_emit+1
        lda vtab+1,y
        sta lzw_emit+2
        rts

V_P1RLE  equ 0
V_P1LZ   equ 2
V_OUT    equ 4
V_LZW    equ 6

* ---- runs: 3 to 255 equal bytes as the byte, $90, n; $90 always as $90 0 -
rle_init lda #0
        sta rl_have
        rts

* rle_in: A packed; keeps X
rle_in  ldy rl_have
        beq rl_new
        cmp rl_c
        bne rl_diff
        inc rl_n
        lda rl_n
        cmp #255
        bne rl_r
        jsr rl_flush
        lda #0
        sta rl_have
rl_r    rts
rl_diff pha
        jsr rl_flush
        pla
rl_new  sta rl_c
        lda #1
        sta rl_n
        sta rl_have
        rts

rle_end lda rl_have
        beq rl_r
        lda #0
        sta rl_have

* rl_flush: the run held
rl_flush stx rl_x
        lda rl_c
        jsr rle_emit
        lda rl_c
        cmp #DLE
        bne rf1
        lda #0
        jsr rle_emit
rf1     ldy rl_n
        dey
        beq rf_r
        sty rl_k
        lda rl_c               ; $90 is never a run
        cmp #DLE
        beq rf_lit
        cpy #2                 ; 3 or more: as a run
        bcs rf_run
rf_lit  lda rl_c
        jsr rle_emit
        lda rl_c
        cmp #DLE
        bne rf_l1
        lda #0
        jsr rle_emit
rf_l1   dec rl_k
        bne rf_lit
        beq rf_r
rf_run  lda #DLE
        jsr rle_emit
        lda rl_n
        jsr rle_emit
rf_r    ldx rl_x
        rts

* ---- crunching: 9 to 12 bit LZW ------------------------------------------
* Strings are kept as a tree: for each code the first longer string (child)
* and the next one with the same beginning (next), 12 bits each: the low
* bytes in a table, the high 4 bits two to a byte; and its last byte.
lzw_init lda #<257
        sta free
        lda #>257
        sta free+1
        lda #9
        sta gc_bits
        lda #0
        sta lim
        sta ncodes
        sta ob
        sta obn
        sta lz_last
        lda #2
        sta lim+1
        lda #1
        sta lz_first
        lda #0                 ; no children for the bytes
        sta zp1
        sta zp2
        lda e_cl
        sta zp1+1
        lda e_ch
        sta zp2+1
        ldy #0
        tya
li0     sta (zp1),y
        sta (zp2),y
        iny
        bne li0
        rts

* lzw_in: the byte A crunched; keeps X
lzw_in  sta lz_c
        lda lz_first
        beq lzi1
        lda lz_c
        sta ent
        lda #0
        sta ent+1
        sta lz_first
        rts
lzi1    lda ent                ; the strings that continue ent
        sta cv
        lda ent+1
        sta cv+1
        jsr chget
lzi2    lda cx
        ora cx+1
        beq lzi_new
        lda cx                 ; ending in the byte?
        sta zp1
        sta cv
        lda cx+1
        sta cv+1
        clc
        adc e_sf
        sta zp1+1
        ldy #0
        lda (zp1),y
        cmp lz_c
        beq lzi_f
        lda cx+1               ; no: the next one
        clc
        adc e_sl
        sta zp1+1
        lda (zp1),y
        sta cx
        lda e_sh
        jsr nibget
        sta cx+1
        jmp lzi2
lzi_f   lda cx
        sta ent
        lda cx+1
        sta ent+1
        rts
lzi_new stx lz_x
        lda ent
        ldx ent+1
        jsr putcode
        lda free+1
        cmp #$10
        jcs lzi_x
        lda free               ; the new string: ent and the byte
        sta zp1
        sta cv
        lda free+1
        sta cv+1
        clc
        adc e_sf
        sta zp1+1
        ldy #0
        lda lz_c
        sta (zp1),y
        lda free+1             ; no child
        clc
        adc e_cl
        sta zp1+1
        lda #0
        sta (zp1),y
        sta nb_v
        lda e_ch
        jsr nibset
        lda ent                ; its next: ent's first child
        sta cv
        lda ent+1
        sta cv+1
        jsr chget
        lda free
        sta zp1
        sta cv
        lda free+1
        sta cv+1
        clc
        adc e_sl
        sta zp1+1
        ldy #0
        lda cx
        sta (zp1),y
        lda cx+1
        sta nb_v
        lda e_sh
        jsr nibset
        lda ent                ; ent's first child: the new one
        sta zp1
        sta cv
        lda ent+1
        sta cv+1
        clc
        adc e_cl
        sta zp1+1
        ldy #0
        lda free
        sta (zp1),y
        lda free+1
        sta nb_v
        lda e_ch
        jsr nibset
        inc free
        bne lzi_x
        inc free+1
lzi_x   lda lz_c
        sta ent
        lda #0
        sta ent+1
        ldx lz_x
        rts

* chget: cx = the first child of code cv
chget   lda cv
        sta zp1
        lda cv+1
        clc
        adc e_cl
        sta zp1+1
        ldy #0
        lda (zp1),y
        sta cx
        lda e_ch
        jsr nibget
        sta cx+1
        rts

* nibadr: zp2 at the byte holding the 4 bits of code cv in the table of
* page A; C=1: the high 4 bits; Y=0
nibadr  sta nb_b
        lda cv+1
        lsr @
        sta nb_t
        lda cv
        ror @
        sta zp2
        php
        lda nb_t
        clc
        adc nb_b
        sta zp2+1
        plp
        ldy #0
        rts

* nibget: A = the 4 bits of code cv in the table of page A
nibget  jsr nibadr
        lda (zp2),y
        bcc ng1
        lsr @
        lsr @
        lsr @
        lsr @
ng1     and #$0F
        rts

* nibset: the 4 bits of code cv in the table of page A = nb_v
nibset  jsr nibadr
        lda (zp2),y
        bcs ns1
        and #$F0
        ora nb_v
        sta (zp2),y
        rts
ns1     and #$0F
        sta nb_t
        lda nb_v
        asl @
        asl @
        asl @
        asl @
        ora nb_t
        sta (zp2),y
        rts

* lzw_end: the last string and the bits held
lzw_end stx lz_x
        lda lz_first
        bne le1
        lda #1
        sta lz_last
        lda ent
        ldx ent+1
        jsr putcode
le1     lda obn
        beq le3
le2     lsr ob
        inc obn
        lda obn
        cmp #8
        bne le2
        lda ob
        jsr lzw_emit
le3     ldx lz_x
        rts

* putcode: the code AX in gc_bits bits; then, when the codes have
* outgrown the width, the group of 8 codes is filled up and the width grows
putcode sta pcv
        stx pcv+1
        ldx gc_bits
        jsr putbits
        inc ncodes
        lda lz_last
        bne pc_r
        lda gc_bits
        cmp #12
        bcs pc_r
        lda free+1
        cmp lim+1
        bcc pc_r
        bne pc_b
        lda free
        cmp lim
        bcc pc_r
pc_b    lda ncodes
        and #7
        beq pc_b2
        lda #0
        sta pcv
        sta pcv+1
        ldx gc_bits
        jsr putbits
        inc ncodes
        jmp pc_b
pc_b2   lda #0
        sta ncodes
        inc gc_bits
        asl lim
        rol lim+1
pc_r    rts

* putbits: X bits of pcv, the lowest first
putbits lsr pcv+1
        ror pcv
        ror ob
        inc obn
        lda obn
        cmp #8
        bne pb2
        lda ob
        jsr lzw_emit
        lda #0
        sta obn
pb2     dex
        bne putbits
        rts

* ---- data ------------------------------------------------------------------
vtab    dta a(p1_rle,p1_lz,out_cr,lzw_in)
rl_have dta 0
rl_c    dta 0
rl_n    dta 0
rl_k    dta 0
rl_x    dta 0
lz_first dta 0
lz_last dta 0
lz_c    dta 0
lz_x    dta 0
ent     dta a(0)
cx      dta a(0)
cv      dta a(0)
nb_b    dta 0
nb_t    dta 0
nb_v    dta 0
pcv     dta a(0)
ob      dta 0
obn     dta 0
