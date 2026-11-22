* ARC: files, buffers, CRC and names

* ---- specifications ----------------------------------------------------

* sp_arc: zs at the archive's specification
sp_arc  lda arca
        sta zs
        lda arca+1
        sta zs+1
        rts

* sp_spec: zs at filelist item X
sp_spec lda speca
        clc
        adc specofs,x
        sta zs
        lda speca+1
        adc #0
        sta zs+1
        rts

* setfp: FILE_P = zs
setfp   lda zs
        sta FILE_P
        lda zs+1
        sta FILE_P+1
        rts

* sp_tmp: FILE_P at the temporary archive, in the archive's directory
sp_tmp  jsr sp_arc
        lda tmpna
        sta zd
        lda tmpna+1
        sta zd+1
        jmp mkpath

* namepos: Y = where the name starts in the specification at zs (after
* the last ':', '>', '<' or backslash)
namepos ldy #0
        sty np_r
np1     lda (zs),y
        beq np3
        cmp #EOL
        beq np3
        iny
        cmp #':'
        beq np2
        cmp #'/'
        beq np2
        cmp #'<'
        beq np2
        cmp #BSLASH
        bne np1
np2     sty np_r
        jmp np1
np3     ldy np_r
        rts

* mk11: the name at (zs),y as 8+3 characters in n11, '*' filled with '?';
* no name at all gives ???????????
mk11    ldx #10
        lda #' '
m11a    sta n11,x
        dex
        bpl m11a
        ldx #0
        lda #8
        sta m11_l
        lda (zs),y
        beq m11e
        cmp #EOL
        bne m11b
m11e    ldx #10
        lda #'?'
m11f    sta n11,x
        dex
        bpl m11f
        rts
m11b    lda (zs),y
        beq m11r
        cmp #EOL
        beq m11r
        cmp #' '
        beq m11r
        iny
        cmp #'.'
        beq m11d
        cmp #'*'
        beq m11s
        cpx m11_l
        bcs m11b
        sta n11,x
        inx
        bne m11b
m11s    lda #'?'
m11t    cpx m11_l
        bcs m11b
        sta n11,x
        inx
        bne m11t
m11d    ldx #8
        lda #11
        sta m11_l
        bne m11b
m11r    rts

* mkpath: pathbuf = the directory part of the specification at zs and the
* name at zd (0 or EOL ended); zs and FILE_P at pathbuf
mkpath  jsr namepos
        sty mp_n
        ldy #0
mp1     cpy mp_n
        bcs mp2
        lda (zs),y
        sta pathbuf,y
        iny
        bne mp1
mp2     sty mp_o
        ldy #0
mp3     lda (zd),y
        beq mp4
        cmp #EOL
        beq mp4
        ldx mp_o
        sta pathbuf,x
        inc mp_o
        iny
        bne mp3
mp4     ldx mp_o
        lda #EOL
        sta pathbuf,x
        lda pba
        sta zs
        lda pba+1
        sta zs+1
        jmp setfp

* upc: A in capitals
upc     cmp #'a'
        bcc up1
        cmp #'z'+1
        bcs up1
        and #$DF
up1     rts

* ---- opening, trapped -------------------------------------------------

* try_open: FOPEN in mode A on FILE_P; C=1 (A = the error) when it fails
try_open sta mode
        lda #0
        sta scan
        sta attr
        lda to_a
        ldx to_a+1
        jsr U_SFAIL
        jsr FOPEN
        jsr U_XFAIL
        clc
        rts
to_fail sec                    ; the trap: the stack is try_open's
        rts

* try_rm: REMOVE FILE_P, an error ignored
try_rm  lda tr_a
        ldx tr_a+1
        jsr U_SFAIL
        jsr REMOVE
        jsr U_XFAIL
tr_fail rts

* ---- the archive read ---------------------------------------------------

* open_ain: the archive opened for reading
open_ain jsr sp_arc
        jsr setfp
        lda #4
        jsr try_open
        bcc oa1
        jsr PRINTF
        dta c'Cannot read archive: %s',EOL,0
        dta a(dname)
        sec
        rts
oa1     lda file_id
        sta h_ain
        jsr ain_init
        clc
        rts
ain_init lda #0
        sta rh_cnt
        sta rh_badf
        sta ain_i
        sta ain_eof
        lda #1
        sta ain_nd
        rts

close_ain lda h_ain
        beq ca_r
        sta file_id
        lda #0
        sta h_ain
        jmp FCLOSE
ca_r    rts

* ain_get: A = the next byte of the archive, C=1 at its end; keeps X
ain_get lda ain_nd
        bne ag_f
ag_go   ldy ain_i
        lda (zabuf),y
        iny
        sty ain_i
        cpy ain_e
        bne ag_ok
        inc ain_nd
ag_ok   clc
        rts
ag_f    jsr ain_fill
        bcc ag_go
        rts

ain_fill lda ain_eof
        bne af_eof
        lda h_ain
        sta file_id
        lda zabuf
        sta addpos
        lda zabuf+1
        sta addpos+1
        lda #0
        sta bytbuf
        sta memreix
        lda #1
        sta bytbuf+1
        stx af_x
        jsr FREAD
        php
        ldx af_x
        plp
        bpl af1
        inc ain_eof
af1     lda bytbuf
        ora bytbuf+1
        beq af_eof
        lda bytbuf
        sta ain_e
        lda #0
        sta ain_i
        sta ain_nd
        clc
        rts
af_eof  sec
        rts

* skip_rest: the rest of the member (pk_left bytes) skipped
skip_rest
sk0     lda pk_left
        ora pk_left+1
        ora pk_left+2
        ora pk_left+3
        beq sk_r
        lda ain_nd
        beq sk1
        jsr ain_fill
        bcs sk_r
sk1     sec                    ; what the buffer holds: 1-256
        lda ain_e
        sbc ain_i
        sta sk_a
        lda #0
        sta sk_a+1
        lda sk_a
        bne sk2
        inc sk_a+1
sk2     lda pk_left+3
        ora pk_left+2
        bne sk_all
        lda pk_left+1
        cmp sk_a+1
        bcc sk_part
        bne sk_all
        lda pk_left
        cmp sk_a
        bcc sk_part
sk_all  sec
        lda pk_left
        sbc sk_a
        sta pk_left
        lda pk_left+1
        sbc sk_a+1
        sta pk_left+1
        lda pk_left+2
        sbc #0
        sta pk_left+2
        lda pk_left+3
        sbc #0
        sta pk_left+3
        lda #1
        sta ain_nd
        jmp sk0
sk_part clc
        lda ain_i
        adc pk_left
        sta ain_i
        lda #0
        sta pk_left
sk_r    rts

* ---- the source file ----------------------------------------------------

* open_src: FILE_P opened for reading
open_src lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta h_src
        lda #0
        sta src_i
        sta src_eof
        lda #1
        sta src_nd
        rts

close_src lda h_src
        beq cs_r
        sta file_id
        lda #0
        sta h_src
        jmp FCLOSE
cs_r    rts

* src_get: A = the next byte of the source file, C=1 at its end; keeps X
src_get lda src_nd
        bne sg_f
sg_go   ldy src_i
        lda (zsbuf),y
        iny
        sty src_i
        cpy src_e
        bne sg_ok
        inc src_nd
sg_ok   clc
        rts
sg_f    lda src_eof
        bne sg_eof
        lda h_src
        sta file_id
        lda zsbuf
        sta addpos
        lda zsbuf+1
        sta addpos+1
        lda #0
        sta bytbuf
        sta memreix
        lda #1
        sta bytbuf+1
        stx af_x
        jsr FREAD
        php
        ldx af_x
        plp
        bpl sg1
        inc src_eof
sg1     lda bytbuf
        ora bytbuf+1
        beq sg_eof
        lda bytbuf
        sta src_e
        lda #0
        sta src_i
        sta src_nd
        jmp sg_go
sg_eof  sec
        rts

* ---- the output file ----------------------------------------------------

* open_out: FILE_P opened for writing
open_out lda #8
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta h_out
        lda #0
        sta out_i
        rts

close_out jsr out_flush
        lda h_out
        beq co_r
        sta file_id
        lda #0
        sta h_out
        jmp FCLOSE
co_r    rts

* out_put: A to the output file; keeps X
out_put ldy out_i
        sta (zobuf),y
        iny
        sty out_i
        beq op_w
        rts
op_w    lda #0
        sta ow_n
        lda #1
        sta ow_n+1
        bne out_wr

out_flush lda out_i
        beq of_r
        sta ow_n
        lda #0
        sta ow_n+1
        sta out_i
out_wr  stx ow_x
        lda h_out
        sta file_id
        lda zobuf
        sta addpos
        lda zobuf+1
        sta addpos+1
        lda ow_n
        sta bytbuf
        lda ow_n+1
        sta bytbuf+1
        lda #0
        sta memreix
        jsr FWRITE
        ldx ow_x
of_r    rts

* out_cr: A to the output file, encrypted with the password; keeps X
out_cr  jsr crypt
        jmp out_put

* crypt: A exclusive-ored with the password's next character; keeps X
crypt   ldy pw_on
        beq cr_r
        stx cr_x
        ldx pwi
        eor pw,x
        inx
        ldy pw,x
        cpy #EOL
        bne cr1
        ldx #0
cr1     stx pwi
        ldx cr_x
cr_r    rts

* ---- CRC-16 (polynomial $A001), a nibble at a time ----------------------

* crc_upd: the CRC updated with A; keeps X
crc_upd eor crc
        sta crc
        jsr crc4
crc4    lda crc
        and #$0F
        tay
        lsr crc+1
        ror crc
        lsr crc+1
        ror crc
        lsr crc+1
        ror crc
        lsr crc+1
        ror crc
        lda crc
        eor crctl,y
        sta crc
        lda crc+1
        eor crcth,y
        sta crc+1
        rts
crctl   dta b($00,$01,$01,$00,$01,$00,$00,$01,$01,$00,$00,$01,$00,$01,$01,$00)
crcth   dta b($00,$CC,$D8,$14,$F0,$3C,$28,$E4,$A0,$6C,$78,$B4,$50,$9C,$88,$44)

* ---- data ------------------------------------------------------------------
arca    dta a(arcspec)
speca   dta a(specs)
pba     dta a(pathbuf)
tmpna   dta a(tmpname)
to_a    dta a(to_fail)
tr_a    dta a(tr_fail)
np_r    dta 0
m11_l   dta 0
mp_n    dta 0
mp_o    dta 0
ain_i   dta 0
ain_e   dta 0
ain_nd  dta 0
ain_eof dta 0
src_i   dta 0
src_e   dta 0
src_nd  dta 0
src_eof dta 0
out_i   dta 0
ow_n    dta a(0)
ow_x    dta 0
af_x    dta 0
cr_x    dta 0
sk_a    dta a(0)
pk_left dta a(0,0)
crc     dta a(0)
