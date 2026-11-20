* ARC: unpacking a member (stored, packed, squeezed, crunched)

* methok: C=0 when the member's method can be unpacked
methok  lda hdr
        beq mo_no
        cmp #5
        bcc mo_ok
        cmp #8
        beq mo_ok
mo_no   sec
        rts
mo_ok   clc
        rts

* decode: the member's packed data (pk_left bytes) through its method to
* the sink (0 none, 1 the output file, 2 the standard output); crc and
* out_left are left for crc_chk
decode  lda #0
        sta pwi
        sta crc
        sta crc+1
        sta dc_bad
        sta ur_st
        sta ur_last
        sta gb_n
        sta gb_eof
        ldx #3
dc0     lda hdr+H_LEN,x
        sta out_left,x
        dex
        bpl dc0
        lda hdr
        cmp #3
        beq dc_pk
        cmp #4
        jeq dc_sq
        cmp #8
        jeq dc_cr
dc_st   jsr pk_get             ; stored
        bcs dc_r
        jsr fin_put
        jmp dc_st
dc_pk   jsr pk_get             ; packed
        bcs dc_r
        jsr unrle_put
        jmp dc_pk
dc_bad1 lda #1
        sta dc_bad
dc_r    rts

* pk_get: A = the member's next packed byte, decrypted; C=1 at its end;
* keeps X
pk_get  lda pk_left
        ora pk_left+1
        ora pk_left+2
        ora pk_left+3
        beq pg_end
        lda pk_left
        bne pg0
        lda pk_left+1
        bne pg1
        lda pk_left+2
        bne pg2
        dec pk_left+3
pg2     dec pk_left+2
pg1     dec pk_left+1
pg0     dec pk_left
        jsr ain_get
        bcs pg_end
        jsr crypt
        clc
        rts
pg_end  sec
        rts

* left0: Z=1 when the whole length has come out
left0   lda out_left
        ora out_left+1
        ora out_left+2
        ora out_left+3
        rts

* fin_put: A to the sink, counted into the CRC; what is beyond the length
* is dropped; keeps X
fin_put sta fp_c
        jsr left0
        beq fp_r
        lda out_left
        bne fp0
        lda out_left+1
        bne fp1
        lda out_left+2
        bne fp2
        dec out_left+3
fp2     dec out_left+2
fp1     dec out_left+1
fp0     dec out_left
        lda fp_c
        jsr crc_upd
        lda sink
        beq fp_r
        cmp #1
        bne fp_con
        lda fp_c
        jmp out_put
fp_con  lda fp_c
        jmp PUTC
fp_r    rts

* unrle_put: A through the run decoding ($90 n: the byte before n-1 more
* times, $90 0: $90 itself) to fin_put; keeps X
unrle_put ldy ur_st
        bne ur_rep
        cmp #DLE
        beq ur_dle
        sta ur_last
        jmp fin_put
ur_dle  inc ur_st
        rts
ur_rep  ldy #0
        sty ur_st
        cmp #0
        bne ur_n
        lda #DLE
        sta ur_last
        jmp fin_put
ur_n    sta ur_cnt
ur_l    dec ur_cnt
        beq ur_r
        lda ur_last
        jsr fin_put
        jmp ur_l
ur_r    rts

* getbit: C = the next bit (lowest first); at the end gb_eof = 1; keeps X
getbit  dec gb_n
        bpl gb1
        jsr pk_get
        bcs gb_e
        sta gb_b
        lda #7
        sta gb_n
gb1     lsr gb_b
        rts
gb_e    lda #1
        sta gb_eof
        lda #0
        sta gb_n
        clc
        rts

* getcode: code = the next gc_bits bits; C=1 at the end
getcode lda #0
        sta code
        sta code+1
        ldx gc_bits
gc1     jsr getbit
        ror code+1
        ror code
        dex
        bne gc1
        lda #16
        sec
        sbc gc_bits
        tax
gc2     lsr code+1
        ror code
        dex
        bne gc2
        inc ncodes
        lda gb_eof
        cmp #1
        rts

* ---- squeezed: a Huffman tree, then the codes ----------------------------
dc_sq   jsr pk_get
        jcs dc_r
        sta sq_n
        jsr pk_get
        jcs dc_r
        sta sq_n+1
        beq dsq0
        cmp #1
        jne dc_bad1
        lda sq_n
        jne dc_bad1
dsq0    lda #0                 ; the nodes, 4 bytes each, to table 0
        sta zp1
        lda tbase
        sta zp1+1
        lda sq_n
        sta sq_c
        lda sq_n+1
        sta sq_c+1
dsq0a   lda sq_c
        ora sq_c+1
        beq dsq1
        ldx #4
dsq0b   jsr pk_get
        jcs dc_r
        ldy #0
        sta (zp1),y
        inc zp1
        bne dsq0c
        inc zp1+1
dsq0c   dex
        bne dsq0b
        lda sq_c
        bne dsq0d
        dec sq_c+1
dsq0d   dec sq_c
        jmp dsq0a
dsq1    lda sq_n
        ora sq_n+1
        jeq dc_r
dsq2    jsr left0
        jeq dc_r
        lda #0
        sta nd
        sta nd+1
dsq3    jsr getbit
        lda #0
        rol @
        asl @
        sta sq_o
        ldx gb_eof
        jne dc_r
        lda nd                 ; table 0 + node * 4 + bit * 2
        asl @
        sta zp1
        lda nd+1
        rol @
        sta zp1+1
        asl zp1
        rol zp1+1
        lda zp1
        clc
        adc sq_o
        sta zp1
        lda zp1+1
        adc tbase
        sta zp1+1
        ldy #0
        lda (zp1),y
        sta nd
        iny
        lda (zp1),y
        sta nd+1
        bpl dsq3
        cmp #$FE               ; -257: the end
        bne dsq4
        lda nd
        cmp #$FF
        jeq dc_r
dsq4    lda nd                 ; -1..-256: the byte
        eor #$FF
        jsr unrle_put
        jmp dsq2

* ---- crunched: 9 to 12 bit LZW, code 256 starts again ----------------------
dc_cr   jsr pk_get
        jcs dc_r
        sta maxb
        cmp #9
        jcc dc_bad1
        cmp #13
        jcs dc_bad1
dcr0    lda #9
        sta gc_bits
        lda #0
        sta lim
        sta ncodes
        lda #2
        sta lim+1
        lda #<257
        sta free
        lda #>257
        sta free+1
        lda #$FF
        sta prev+1
dcr1    jsr left0
        jeq dc_r
        jsr getcode
        jcs dc_r
        lda code+1
        cmp #1
        bne dcr2
        lda code
        bne dcr2
        jsr dcr_al             ; 256: the table cleared
        jmp dcr0
dcr2    lda prev+1
        bpl dcr3
        lda code+1             ; the first code: a byte
        jne dc_bad1
        lda code
        sta finch
        sta prev
        lda #0
        sta prev+1
        lda code
        jsr unrle_put
        jmp dcr_b
dcr3    lda code
        sta incode
        lda code+1
        sta incode+1
        lda #0
        sta zsp
        lda d_st
        sta zsp+1
        lda code+1
        cmp free+1
        bcc dcr5
        jne dc_bad1
        lda code
        cmp free
        bcc dcr5
        jne dc_bad1
        lda finch              ; the code being made: the last string and
        jsr push               ; its first byte
        lda prev
        sta code
        lda prev+1
        sta code+1
dcr5    lda code+1             ; the string, backwards, to the stack
        beq dcr6
        lda code
        sta zp1
        sta cv
        lda code+1
        sta cv+1
        clc
        adc d_sf
        sta zp1+1
        ldy #0
        lda (zp1),y
        jsr push
        lda code+1
        clc
        adc d_pl
        sta zp1+1
        ldy #0
        lda (zp1),y
        sta code
        lda d_ph
        jsr nibget
        sta code+1
        jmp dcr5
dcr6    lda code
        sta finch
        jsr push
dcr7    jsr pop
        bcs dcr8
        jsr unrle_put
        jmp dcr7
dcr8    lda free+1             ; the new string: prev + its first byte
        cmp #$10
        bcs dcr9
        lda free
        sta zp1
        sta zp3
        sta cv
        lda free+1
        sta cv+1
        clc
        adc d_pl
        sta zp1+1
        lda free+1
        clc
        adc d_sf
        sta zp3+1
        ldy #0
        lda prev
        sta (zp1),y
        lda finch
        sta (zp3),y
        lda prev+1
        sta nb_v
        lda d_ph
        jsr nibset
        inc free
        bne dcr9
        inc free+1
dcr9    lda incode
        sta prev
        lda incode+1
        sta prev+1
dcr_b   lda gc_bits            ; the table full for this width: one more bit
        cmp maxb
        jcs dcr1
        lda free+1
        cmp lim+1
        jcc dcr1
        bne dcr_b1
        lda free
        cmp lim
        jcc dcr1
dcr_b1  jsr dcr_al
        inc gc_bits
        asl lim
        rol lim+1
        jmp dcr1

* dcr_al: the rest of the group of 8 codes skipped
dcr_al  lda ncodes
        and #7
        beq da_r
        jsr getcode
        bcc dcr_al
da_r    lda #0
        sta ncodes
        rts

* push / pop: the decoder's stack (table 3)
push    ldy #0
        sta (zsp),y
        inc zsp
        bne pu1
        inc zsp+1
pu1     rts
pop     lda zsp
        bne po1
        lda zsp+1
        cmp d_st
        beq po_e
        dec zsp+1
po1     dec zsp
        ldy #0
        lda (zsp),y
        clc
        rts
po_e    sec
        rts

* ---- data ------------------------------------------------------------------
sink    dta 0
dc_bad  dta 0
fp_c    dta 0
out_left dta a(0,0)
ur_st   dta 0
ur_last dta 0
ur_cnt  dta 0
gb_n    dta 0
gb_b    dta 0
gb_eof  dta 0
gc_bits dta 0
code    dta a(0)
ncodes  dta 0
maxb    dta 0
lim     dta a(0)
free    dta a(0)
prev    dta a(0)
incode  dta a(0)
finch   dta 0
sq_n    dta a(0)
sq_c    dta a(0)
sq_o    dta 0
nd      dta a(0)
