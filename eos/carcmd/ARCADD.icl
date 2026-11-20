* ARC: A, M, U and F

LISTSZ  equ 18

do_add  ldx #3                 ; the list's memory: as much as there is
da0     stx da_k
        lda lsz_l,x
        sta bytbuf
        lda lsz_h,x
        sta bytbuf+1
        ldx #0
        ldy #0
        jsr MALLOC
        bpl da1
        ldx da_k
        dex
        bpl da0
        lda #158
        jmp gfail
da1     lda addpos
        sta lbase
        lda addpos+1
        sta lbase+1
        ldx da_k
        lda lcap_l,x
        sta lcap
        lda lcap_h,x
        sta lcap+1
        lda #0
        sta ln
        sta ln+1
        sta bl_i
da2     ldx bl_i               ; every filelist item searched
        cpx nspec
        bcs da3
        jsr bl_spec
        inc bl_i
        bne da2
da3     lda ln
        ora ln+1
        bne da4
        jsr PRINTF
        dta c'Nothing to add!',EOL,0
        rts
da4     jsr sp_arc             ; the archive there already?
        jsr setfp
        lda #4
        jsr try_open
        bcc da5
        lda #0
        sta had_old
        sta old_on
        jsr PRINTF
        dta c'Creating new archive: %s',EOL,0
        dta a(dname)
        jmp da6
da5     lda file_id
        sta h_ain
        jsr ain_init
        lda #1
        sta had_old
        jsr next_old
da6     jsr open_tmp
        lda #0
        sta li
        sta li+1
mg1     jsr li_end             ; Z=1: the list done
        bne mg2
        lda old_on
        jeq mg_end
        jsr copy_ent           ; old ones after the list
        jsr next_old
        jmp mg1
mg2     jsr lptr
        lda old_on
        beq mg_add
        jsr lcmp
        beq mg_eq
        bcs mg_add
        jsr copy_ent           ; the old one comes first
        jsr next_old
        jmp mg1
mg_eq   lda cmd                ; the same name
        cmp #'U'
        beq mg_eq1
        cmp #'F'
        bne mg_rep
mg_eq1  jsr newer
        beq mg_keep
        bcs mg_rep
mg_keep jsr copy_ent
        jmp mg_nx
mg_rep  jsr skip_rest
        lda #1
        sta da_rep
        jsr add_one
mg_nx   jsr next_old
        jmp mg_inc
mg_add  lda cmd                ; not in the archive
        cmp #'F'
        beq mg_inc
        lda #0
        sta da_rep
        jsr add_one
mg_inc  inc li
        bne mg1
        inc li+1
        jmp mg1
mg_end  jsr close_ain
        jsr fin_tmp
        jsr replace
        lda cmd                ; M: the files added are deleted
        cmp #'M'
        bne mv_r
        lda #0
        sta li
        sta li+1
mv1     jsr li_end
        beq mv_r
        jsr lptr
        ldy #L_SPEC
        lda (zp3),y
        bpl mv2
        and #$7F
        tax
        jsr sp_spec
        lda zp3
        sta zd
        lda zp3+1
        sta zd+1
        jsr mkpath
        jsr REMOVE
mv2     inc li
        bne mv1
        inc li+1
        jmp mv1
mv_r    rts

* next_old: the next member of the old archive; old_on = 0 at its end
next_old lda #0
        sta old_on
        lda h_ain
        beq no_r
        jsr read_hdr
        bcs no_r
        inc old_on
no_r    rts

* li_end: Z=1 when li = ln
li_end  lda li
        cmp ln
        bne le_r
        lda li+1
        cmp ln+1
le_r    rts

* lptr: zp3 at list entry li
lptr    lda li
        sta zp3
        lda li+1
        sta zp3+1
        asl zp3                ; * 2
        rol zp3+1
        lda zp3
        sta lp_t
        lda zp3+1
        sta lp_t+1
        asl zp3                ; * 16
        rol zp3+1
        asl zp3
        rol zp3+1
        asl zp3
        rol zp3+1
        clc
        lda zp3
        adc lp_t
        sta zp3
        lda zp3+1
        adc lp_t+1
        sta zp3+1
        clc
        lda zp3
        adc lbase
        sta zp3
        lda zp3+1
        adc lbase+1
        sta zp3+1
        rts

* lcmp: the old member's name against entry zp3: C=0 below, Z=1 the same
lcmp    ldy #0
lc1     lda mname,y
        cmp (zp3),y
        bne lc_r
        cmp #0
        beq lc_r
        iny
        cpy #13
        bcc lc1
lc_r    rts

* newer: entry zp3 against the old member: Z=0 and C=1 when it is newer
newer   ldy #L_DATE+1
        lda (zp3),y
        cmp hdr+H_DATE+1
        bne nw_r
        dey
        lda (zp3),y
        cmp hdr+H_DATE
        bne nw_r
        ldy #L_TIME+1
        lda (zp3),y
        cmp hdr+H_TIME+1
        bne nw_r
        dey
        lda (zp3),y
        cmp hdr+H_TIME
nw_r    rts

* ---- the list ----------------------------------------------------------

* bl_spec: the files of filelist item X into the list, sorted by name
bl_spec jsr sp_spec
        jsr setfp
        lda #$80               ; files, not directories
        sta scan
        jsr FFIRST
        bpl bl1
        jsr PRINTF
        dta c'No files match: %p',EOL,0
        dta a(zs)
        rts
bl1     ldx #0                 ; NAME.EXT
        ldy #0
bl2     lda dentry+6,y
        cmp #' '
        beq bl3
        sta le,x
        inx
bl3     iny
        cpy #8
        bcc bl2
        lda dentry+14
        cmp #' '
        beq bl5
        lda #'.'
        sta le,x
        inx
bl4     lda dentry+6,y
        cmp #' '
        beq bl4a
        sta le,x
        inx
bl4a    iny
        cpy #11
        bcc bl4
bl5     lda #0
        sta le,x
        inx
        cpx #13
        bcc bl5
        lda bl_i
        sta le+L_SPEC
        lda dentry+19          ; the date and time as DOS has them
        cmp #80
        bcc bl6
        sbc #80
        jmp bl7
bl6     adc #20
bl7     sta bl_t
        lda dentry+18
        lsr @
        lsr @
        lsr @
        asl bl_t
        ora bl_t
        sta le+L_DATE+1
        lda dentry+18
        asl @
        asl @
        asl @
        asl @
        asl @
        ora dentry+17
        sta le+L_DATE
        lda dentry+21
        lsr @
        lsr @
        lsr @
        sta bl_t
        lda dentry+20
        asl @
        asl @
        asl @
        ora bl_t
        sta le+L_TIME+1
        lda dentry+22
        lsr @
        sta bl_t
        lda dentry+21
        asl @
        asl @
        asl @
        asl @
        asl @
        ora bl_t
        sta le+L_TIME
        lda ana                ; not the archive itself
        ldx ana+1
        jsr lesame
        beq bl8
        lda tmpna
        ldx tmpna+1
        jsr lesame
        beq bl8
        jsr insert
bl8     jsr FNEXT
        jpl bl1
        jsr FCLOSE
bl_r    rts

* lesame: Z=1 when le is the name at AX (0 or EOL ended)
lesame  sta zd
        stx zd+1
        ldy #0
ls1     lda (zd),y
        cmp #EOL
        bne ls2
        lda #0
ls2     cmp le,y
        bne ls_r
        cmp #0
        beq ls_r
        iny
        cpy #13
        bcc ls1
ls_r    rts

* insert: le into the list at its place; the same name replaces the entry
insert  lda #0
        sta li
        sta li+1
is1     jsr li_end
        beq is_new
        jsr lptr
        ldy #0
is2     lda le,y
        cmp (zp3),y
        bne is3
        cmp #0
        jeq is_set
        iny
        cpy #13
        bcc is2
        jcs is_set
is3     bcc is_new
        inc li
        bne is1
        inc li+1
        jmp is1
is_new  lda ln                 ; room for one more?
        cmp lcap
        lda ln+1
        sbc lcap+1
        bcc is4
        lda #158
        jmp gfail
is4     lda li                 ; the entries from li on move up one
        pha
        lda li+1
        pha
        lda ln
        sta li
        lda ln+1
        sta li+1
        jsr lptr
        lda zp3                ; zp1 = the end, zp2 = the end + 18
        sta zp1
        clc
        adc #LISTSZ
        sta zp2
        lda zp3+1
        sta zp1+1
        adc #0
        sta zp2+1
        pla
        sta li+1
        pla
        sta li
        jsr lptr
        ldy #0
is5     lda zp1
        cmp zp3
        bne is6
        lda zp1+1
        cmp zp3+1
        beq is7
is6     lda zp1
        bne is6a
        dec zp1+1
is6a    dec zp1
        lda zp2
        bne is6b
        dec zp2+1
is6b    dec zp2
        lda (zp1),y
        sta (zp2),y
        jmp is5
is7     inc ln
        bne is_set
        inc ln+1
is_set  ldy #LISTSZ-1
is8     lda le,y
        sta (zp3),y
        dey
        bpl is8
        rts

* ---- adding one file ----------------------------------------------------

* add_one: list entry li (at zp3) added to the output
add_one ldy #LISTSZ-1
ao0     lda (zp3),y
        sta cur,y
        dey
        bpl ao0
        lda cur+L_SPEC         ; marked as added (for M)
        ora #$80
        ldy #L_SPEC
        sta (zp3),y
        lda opt_n
        bne ao1
        lda da_rep
        bne ao0a
        jsr PRINTF
        dta c'Adding:   %12s ',0
        dta a(cur)
        jmp ao1
ao0a    jsr PRINTF
        dta c'Updating: %12s ',0
        dta a(cur)
ao1     lda opt_s              ; S (no compression): error 146
        beq ao1a
        lda #146
        jmp gfail
ao1a    jsr cur_path
        jsr open_src
        lda #0                 ; first: analysed
        sta crc
        sta crc+1
        ldx #11
ao2     sta alen,x
        dex
        bpl ao2
        lda #1                 ; the crunched size counts its first byte
        sta lzsz
        ldx #V_P1RLE
        ldy #V_P1LZ
        jsr setv
        jsr rle_init
        jsr lzw_init
ao3     jsr src_get
        bcs ao4
        pha
        jsr crc_upd
        pla
        inc alen
        bne ao3a
        inc alen+1
        bne ao3a
        inc alen+2
        bne ao3a
        inc alen+3
ao3a    jsr rle_in
        jmp ao3
ao4     jsr rle_end
        jsr lzw_end
        jsr close_src
        lda #2                 ; the smallest way
        sta meth
        ldx #3
ao5     lda alen,x
        sta asize,x
        dex
        bpl ao5
        lda #3
        ldx #rlsz-alen
        jsr ao_less
        lda #8
        ldx #lzsz-alen
        jsr ao_less
ao8     lda opt_n
        bne ao9
        ldx meth
        lda vb_i,x
        tax
        lda vb_a,x
        sta vb_p
        lda vb_a+1,x
        sta vb_p+1
        jsr PRINTF
        dta c'%9p',0
        dta a(vb_p)
ao9     jsr cur_path           ; then: written
        jsr open_src
        lda #$1A
        jsr out_put
        lda meth
        jsr out_put
        ldy #0                 ; the name over the one written before:
ao10    lda cur,y              ; what follows its 0 stays
        sta (zhn),y
        beq ao10a
        iny
        bne ao10
ao10a   lda #0
        sta ao_y
ao10b   ldy ao_y
        lda (zhn),y
        jsr out_put
        inc ao_y
        lda ao_y
        cmp #13
        bcc ao10b
        ldx #0
ao11    lda asize,x
        jsr out_put
        inx
        cpx #4
        bcc ao11
        lda cur+L_DATE
        jsr out_put
        lda cur+L_DATE+1
        jsr out_put
        lda cur+L_TIME
        jsr out_put
        lda cur+L_TIME+1
        jsr out_put
        lda crc
        jsr out_put
        lda crc+1
        jsr out_put
        ldx #0
ao12    lda alen,x
        jsr out_put
        inx
        cpx #4
        bcc ao12
        lda #0
        sta pwi
        lda meth
        cmp #3
        beq ao_pk
        cmp #8
        beq ao_cr
ao_st   jsr src_get            ; stored
        bcs ao_e
        jsr out_cr
        jmp ao_st
ao_pk   ldx #V_OUT             ; packed
        ldy #V_OUT
        jsr setv
        jsr rle_init
        jmp ao_rl
ao_cr   lda #12                ; crunched
        jsr out_cr
        ldx #V_LZW
        ldy #V_OUT
        jsr setv
        jsr rle_init
        jsr lzw_init
        jsr ao_rlp
        jsr lzw_end
        jmp ao_e
ao_rl   jsr ao_rlp
ao_e    jsr close_src
        lda opt_n
        bne ao_e1
        jsr PRINTF
        dta c'Done.',EOL,0
ao_e1   rts

* ao_rlp: the source through rle_in
ao_rlp  jsr src_get
        bcs ar_r
        jsr rle_in
        jmp ao_rlp
ar_r    jmp rle_end

* ao_less: when the size at alen+X is below asize: method A, that size
ao_less sta al_m
        sec
        lda alen,x
        sbc asize
        lda alen+1,x
        sbc asize+1
        lda alen+2,x
        sbc asize+2
        lda alen+3,x
        sbc asize+3
        bcs al_r
        lda al_m
        sta meth
        ldy #0
al1     lda alen,x
        sta asize,y
        inx
        iny
        cpy #4
        bcc al1
al_r    rts

* cur_path: FILE_P at the file of entry cur
cur_path lda cur+L_SPEC
        and #$7F
        tax
        jsr sp_spec
        lda cura
        sta zd
        lda cura+1
        sta zd+1
        jmp mkpath

* p1_rle / p1_lz: the first pass counts the packed and crunched bytes
p1_rle  inc rlsz
        bne p1r1
        inc rlsz+1
        bne p1r1
        inc rlsz+2
        bne p1r1
        inc rlsz+3
p1r1    jmp lzw_in
p1_lz   inc lzsz
        bne p1l1
        inc lzsz+1
        bne p1l1
        inc lzsz+2
        bne p1l1
        inc lzsz+3
p1l1    rts


* ---- data ------------------------------------------------------------------
lsz_l   dta l(1024,2048,4096,8192)
lsz_h   dta h(1024,2048,4096,8192)
lcap_l  dta l(1024/LISTSZ,2048/LISTSZ,4096/LISTSZ,8192/LISTSZ)
lcap_h  dta h(1024/LISTSZ,2048/LISTSZ,4096/LISTSZ,8192/LISTSZ)
vb_i    dta b(0,0,0,2,0,0,0,0,4)
vb_a    dta a(vb_st,vb_pk,vb_cr)
vb_st   dta c'Store:',0
vb_pk   dta c'Packing:',0
vb_cr   dta c'Crunch:',0
vb_p    dta a(0)
cura    dta a(cur)
da_k    dta 0
da_rep  dta 0
lbase   dta a(0)
lcap    dta a(0)
ln      dta a(0)
li      dta a(0)
lp_t    dta a(0)
bl_i    dta 0
bl_t    dta 0
old_on  dta 0
meth    dta 0
al_m    dta 0
ao_y    dta 0
alen    :4 dta 0
rlsz    :4 dta 0
lzsz    :4 dta 0
asize   :4 dta 0
le      :LISTSZ dta 0
cur     :LISTSZ dta 0
