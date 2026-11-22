* ARC: reading members; L, V, X, E, P and D

* read_hdr: the next member's header to hdr, pk_left = its packed size;
* C=1 at the end of the archive
read_hdr jsr ain_get
        jcs rh_end
        cmp #$1A
        bne rh_bad
        jsr ain_get
        jcs rh_end
        sta hdr
        cmp #0
        jeq rh_end
        ldx #1
rh1     jsr ain_get
        bcs rh_bad
        sta hdr,x
        inx
        cpx #H_LEN
        bcc rh1
        lda hdr
        cmp #1
        beq rh_m1
rh2     jsr ain_get
        bcs rh_bad
        sta hdr,x
        inx
        cpx #H_LEN+4
        bcc rh2
        bcs rh3
rh_m1   ldx #3                 ; the old header: no length, never packed
rh4     lda hdr+H_SIZE,x
        sta hdr+H_LEN,x
        dex
        bpl rh4
rh3     lda #0
        sta hdr+13
        ldx #3
rh5     lda hdr+H_SIZE,x
        sta pk_left,x
        dex
        bpl rh5
        inc rh_cnt
        ldx #0                 ; the name in capitals, for matching
rh6     lda hdr+1,x
        jsr upc
        sta mname,x
        inx
        cpx #13
        bcc rh6
        clc
        rts
rh_bad  jsr PRINTF              ; not a header
        dta c'Bad header in %s',EOL,0
        dta a(dname)
        lda rh_cnt
        bne rh_b1
        jsr PRINTF
        dta c'%s is not an archive',EOL,0
        dta a(dname)
rh_b1   lda #1
        sta rh_badf
        sec
        rts
rh_end  sec
        rts

* match: C=0 when the member matches a filelist item, X = the item
match   lda mna
        sta zs
        lda mna+1
        sta zs+1
        ldy #0
        jsr mk11
        ldx #0
        ldy #0
mt1     cpx nspec
        bcs mt_no
        stx mt_i
        sty mt_o
        ldx #0
mt2     lda masks,y
        cmp #'?'
        beq mt3
        cmp n11,x
        bne mt_nx
mt3     iny
        inx
        cpx #11
        bcc mt2
        ldx mt_i
        clc
        rts
mt_nx   lda mt_o
        clc
        adc #11
        tay
        ldx mt_i
        inx
        bne mt1
mt_no   sec
        rts

* ---- L and V -----------------------------------------------------------
do_list ldx #9
dl0     lda #0
        sta tot,x
        dex
        bpl dl0
        lda cmd
        cmp #'V'
        beq dl2
        jsr PRINTF
        dta b(EOL),c'Filename     Length   Date     Time',EOL
        dta c'============ ======== ======== ======',EOL,0
        jmp dl3
dl2     jsr PRINTF
        dta b(EOL),c'Filename     Length   S SF   Size now',EOL
        dta c'============ ======== = ==== ========',EOL,0
dl3     jsr open_ain
        bcc dl4
        rts
dl4     jsr read_hdr
        jcs dl_end
        jsr match
        jcs dl_skip
        inc tot
        bne dl4a
        inc tot+1
dl4a    clc
        ldx #0
        ldy #4
dl5     lda tot+2,x
        adc hdr+H_LEN,x
        sta tot+2,x
        inx
        dey
        bne dl5
        clc
        ldx #0
        ldy #4
dl6     lda tot+6,x
        adc hdr+H_SIZE,x
        sta tot+6,x
        inx
        dey
        bne dl6
        lda cmd
        cmp #'V'
        beq dl7
        jsr dosdt
        jsr PRINTF
        dta c'%12s%9l %2b-%02b-%02b %2b:%02b ',EOL,0
        dta a(hdr+1,hdr+H_LEN,dt_d,dt_m,dt_y,dt_h,dt_mi)
        jmp dl_skip
dl7     jsr sfact
        ldx hdr
        cpx #10
        bcc dl8
        ldx #0
dl8     lda stw_c,x
        sta stw_l
        jsr PRINTF
        dta c'%12s%9l %c %3b%% %8l',EOL,0
        dta a(hdr+1,hdr+H_LEN,stw_l,sf_r,hdr+H_SIZE)
dl_skip jsr skip_rest
        jmp dl4
dl_end  jsr close_ain
        lda rh_badf
        bne dl_r
        lda cmd
        cmp #'V'
        beq dl10
        jsr PRINTF
        dta c'        ==== ========',EOL
        dta c'Total%7d %8e',EOL,0
        dta a(tot,tot+2)
dl_r    rts
dl10    jsr PRINTF
        dta c'        ==== ========        ========',EOL
        dta c'Total%7d %8e        %8e',EOL,0
        dta a(tot,tot+2,tot+6)
        rts

* sfact: sf_r = 100 - size * 100 / length (0 for an empty or grown member)
sfact   lda #0
        sta sf_r
        lda hdr+H_LEN
        ora hdr+H_LEN+1
        ora hdr+H_LEN+2
        ora hdr+H_LEN+3
        jeq sf_r0
        ldx #3                 ; size * 100 = * 64 + * 32 + * 4
sf2     lda hdr+H_SIZE,x
        sta sf_t,x
        lda #0
        sta sf_n,x
        dex
        bpl sf2
        ldy #0
sf3     cpy #2
        beq sf4
        cpy #5
        beq sf4
        cpy #6
        bne sf5
sf4     clc
        ldx #0
sf4a    lda sf_n,x
        adc sf_t,x
        sta sf_n,x
        inx
        txa
        eor #4
        bne sf4a
sf5     asl sf_t
        rol sf_t+1
        rol sf_t+2
        rol sf_t+3
        iny
        cpy #7
        bcc sf3
        lda #0                 ; / length
        sta sf_t
        sta sf_t+1
        sta sf_t+2
        sta sf_t+3
        ldy #32
sf6     asl sf_n
        rol sf_n+1
        rol sf_n+2
        rol sf_n+3
        rol sf_t
        rol sf_t+1
        rol sf_t+2
        rol sf_t+3
        sec
        lda sf_t
        sbc hdr+H_LEN
        tax
        lda sf_t+1
        sbc hdr+H_LEN+1
        sta sf_q
        lda sf_t+2
        sbc hdr+H_LEN+2
        sta sf_q+1
        lda sf_t+3
        sbc hdr+H_LEN+3
        bcc sf7
        sta sf_t+3
        lda sf_q+1
        sta sf_t+2
        lda sf_q
        sta sf_t+1
        stx sf_t
        inc sf_n
sf7     dey
        bne sf6
        lda sf_n+1
        ora sf_n+2
        ora sf_n+3
        bne sf_r0
        lda #100
        sec
        sbc sf_n
        bcc sf_r0
        sta sf_r
sf_r0   rts

* dosdt: the member's DOS date and time as day, month, year, hour, minute
dosdt   lda hdr+H_DATE
        and #$1F
        sta dt_d
        lda hdr+H_DATE+1
        lsr @
        php
        clc
        adc #80
        cmp #100
        bcc dd1
        sbc #100
dd1     sta dt_y
        plp
        lda hdr+H_DATE
        rol @
        rol @
        rol @
        rol @
        and #$0F
        sta dt_m
        lda hdr+H_TIME+1
        lsr @
        lsr @
        lsr @
        sta dt_h
        lda hdr+H_TIME+1
        and #$07
        sta dt_mi
        lda hdr+H_TIME
        lsr @
        lsr @
        lsr @
        lsr @
        lsr @
        asl dt_mi
        asl dt_mi
        asl dt_mi
        ora dt_mi
        sta dt_mi
        rts

* ---- X, E and P ------------------------------------------------------------
do_ext  jsr open_ain
        bcc ex_0a
        rts
ex_0a   lda #0
        sta ow_all
ex1     jsr read_hdr
        jcs ex_end
        jsr match
        jcs ex_skip
        stx ex_m
        jsr methok
        bcc ex_0
        lda opt_w
        jne ex_skip
        jsr PRINTF
        dta c'Cannot unpack %s (method %b)',EOL,0
        dta a(mname,hdr)
        jmp ex_skip
ex_0    lda cmd
        cmp #'P'
        bne ex_f
        lda #2                 ; P: to the standard output
        sta sink
        jsr decode
        jmp ex_chk
ex_f    jsr ex_path
        jsr isnul
        beq ex_go
        lda ow_all
        bne ex_go
        lda #4
        jsr try_open
        bcs ex_go
        jsr FCLOSE
        jsr scron2
ex_ask  jsr PRINTF
        dta c'%s',EOL
        dta c'File exists - Overwrite (Y/N/A) ? ',0
        dta a(mname)
        jsr U_GETKEY
        jsr upc
        sta ex_k
        cmp #'Y'
        beq ex_k1
        cmp #'N'
        beq ex_k1
        cmp #'A'
        beq ex_k1
        lda #EOL
        jsr PUTC
        jmp ex_ask
ex_k1   jsr PUTC
        lda #EOL
        jsr PUTC
        jsr scroff
        lda ex_k
        cmp #'N'
        beq ex_skip
        cmp #'A'
        bne ex_go
        sta ow_all
ex_go   lda opt_n
        bne ex_g1
        jsr PRINTF
        dta c'Extracting file: %12s ',0
        dta a(hdr+1)
ex_g1   jsr dosdt              ; the file gets the member's date and time
        ldx #4
ex_g2   lda dt_d,x
        sta date,x
        dex
        bpl ex_g2
        lda hdr+H_TIME
        and #$1F
        asl @
        sta date+5
        lda #$FF
        sta dateset
        jsr ex_path
        jsr open_out
        lda #1
        sta sink
        jsr decode
        jsr close_out
        jsr crc_chk
        lda opt_n
        bne ex_skip
        jsr PRINTF
        dta c'Done.',EOL,0
        jmp ex_skip
ex_chk  jsr crc_chk
ex_skip jsr skip_rest
        jmp ex1
ex_end  jmp close_ain

* ex_path: FILE_P at the destination: the directory of filelist item ex_m
* and the member's name
ex_path ldx ex_m
        jsr sp_spec
        lda mna
        sta zd
        lda mna+1
        sta zd+1
        jmp mkpath

* isnul: Z=1 when the destination is NUL:
isnul   ldx #3
in1     lda pathbuf,x
        cmp nulnm,x
        bne in2
        dex
        bpl in1
        lda #0
in2     rts

* scron2 / scroff: the screen on for a question, then off again (H)
scron2  lda opt_h
        beq so_r
        lda dmsave
        sta SDMCTL
so_r    rts
scroff  lda opt_h
        beq so_r
        lda #0
        sta SDMCTL
        rts

* crc_chk: the warning when the member came out wrong
crc_chk lda dc_bad
        bne cc_w
        lda out_left
        ora out_left+1
        ora out_left+2
        ora out_left+3
        bne cc_w
        lda crc
        cmp hdr+H_CRC
        bne cc_w
        lda crc+1
        cmp hdr+H_CRC+1
        beq cc_r
cc_w    lda opt_w
        bne cc_r
        jsr PRINTF
        dta c'WARNING: %s fails CRC ',0
        dta a(hdr+1)
cc_r    rts

* ---- D ---------------------------------------------------------------------
do_del  jsr sp_arc             ; no archive: an empty one is made
        jsr setfp
        lda #4
        jsr try_open
        bcc dd_0
        jsr PRINTF
        dta c'Creating new archive: %s',EOL,0
        dta a(dname)
        lda #0
        sta had_old
        jsr open_tmp
        jsr fin_tmp
        jmp replace
dd_0    lda file_id
        sta h_ain
        jsr ain_init
        lda #1
        sta had_old
        jsr open_tmp
dd_1    jsr read_hdr
        bcs dd_end
        jsr match
        bcs dd_keep
        lda opt_n
        bne dd_2
        jsr PRINTF
        dta c'Deleting: %s',EOL,0
        dta a(hdr+1)
dd_2    jsr skip_rest
        jmp dd_1
dd_keep jsr copy_ent
        jmp dd_1
dd_end  jsr close_ain
        jsr fin_tmp
        lda rh_badf             ; a bad archive stays as it is
        beq dd_e1
        lda #0
        sta tmp_on
        jsr sp_tmp
        jmp REMOVE
dd_e1   jmp replace

* copy_ent: the member read last, header and data, to the output
copy_ent lda opt_n
        bne ce0
        jsr PRINTF
        dta c'Copying:  %s',EOL,0
        dta a(hdr+1)
ce0     lda #$1A
        jsr out_put
        ldx #H_LEN
        lda hdr
        cmp #1
        beq ce1
        ldx #H_LEN+4
ce1     stx ce_n
        ldx #0
ce2     lda hdr,x
        jsr out_put
        inx
        cpx ce_n
        bcc ce2
ce3     lda pk_left
        ora pk_left+1
        ora pk_left+2
        ora pk_left+3
        beq ce_r
        jsr ain_get
        bcs ce_r
        jsr out_put
        lda pk_left
        bne ce4
        lda pk_left+1
        bne ce5
        lda pk_left+2
        bne ce6
        dec pk_left+3
ce6     dec pk_left+2
ce5     dec pk_left+1
ce4     dec pk_left
        jmp ce3
ce_r    rts

* open_tmp: the temporary archive opened for writing
open_tmp jsr sp_tmp
        jsr open_out
        lda #1
        sta tmp_on
        rts

* fin_tmp: the end mark, the temporary archive closed
fin_tmp lda #$1A
        jsr out_put
        lda #0
        jsr out_put
        jmp close_out

* replace: the temporary archive takes the archive's place (B: the old
* one kept as .BAK)
replace lda had_old
        beq rp_new
        lda opt_b
        beq rp_del
        ldx #0                 ; NAME.BAK
rp1     lda arcname,x
        sta bakname,x
        beq rp2
        cmp #'.'
        beq rp2
        inx
        bne rp1
rp2     ldy #0
rp3     lda dotbak,y
        sta bakname,x
        inx
        iny
        cpy #5
        bcc rp3
        jsr sp_arc
        lda bka
        sta zd
        lda bka+1
        sta zd+1
        jsr mkpath
        jsr try_rm
        jsr sp_arc             ; "archive NAME.BAK"
        lda bka
        sta zd
        lda bka+1
        sta zd+1
        jsr rnstr
        jsr RENAME
        jmp rp_new
rp_del  jsr sp_arc
        jsr setfp
        jsr REMOVE
rp_new  jsr sp_tmp             ; "temporary NAME.ARC"
        lda pba
        sta zs
        lda pba+1
        sta zs+1
        lda ana
        sta zd
        lda ana+1
        sta zd+1
        jsr rnstr
        jsr RENAME
        lda #0
        sta tmp_on
        rts

* rnstr: rnbuf = the specification at zs, a space, the name at zd; FILE_P
* at rnbuf
rnstr   ldy #0
rs1     lda (zs),y
        cmp #EOL
        beq rs2
        sta rnbuf,y
        iny
        bne rs1
rs2     lda #' '
        sta rnbuf,y
        iny
        sty mp_o
        ldy #0
rs3     lda (zd),y
        beq rs4
        cmp #EOL
        beq rs4
        ldx mp_o
        sta rnbuf,x
        inc mp_o
        iny
        bne rs3
rs4     ldx mp_o
        lda #EOL
        sta rnbuf,x
        lda rna
        sta FILE_P
        lda rna+1
        sta FILE_P+1
        rts

* ---- data ------------------------------------------------------------------
mna     dta a(mname)
bka     dta a(bakname)
ana     dta a(arcname)
rna     dta a(rnbuf)
nulnm   dta c'NUL:'
dotbak  dta c'.bak',0
stw_c   dta c' --PQCCCCQ'
stw_l   dta 0
rh_cnt  dta 0
rh_badf dta 0
hdr     :H_LEN+4 dta 0
mname   :14 dta 0
mt_i    dta 0
mt_o    dta 0
tot     :10 dta 0
dt_d    dta 0
dt_m    dta 0
dt_y    dta 0
dt_h    dta 0
dt_mi   dta 0
sf_n    :4 dta 0
sf_t    :4 dta 0
sf_q    :2 dta 0
sf_r    dta 0
ex_m    dta 0
ex_k    dta 0
ow_all  dta 0
had_old dta 0
ce_n    dta 0
bakname :16 dta 0
rnbuf   :96 dta 0
