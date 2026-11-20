* DSK: file system, the writing half (included by fms.asm)

* ---- 1 kd_write ---------------------------------------------------------
f_write jsr find_fcb
        bcs fw_ret
        lda fc_flg,x
        and #FL_WRITE
        bne fw1
        lda #E_RDONLY
        rts
fw1     jsr set_mx
        lda addpos
        sta zp_q
        lda addpos+1
        sta zp_q+1
        lda bytbuf
        sta fs_cnt
        lda bytbuf+1
        sta fs_cnt+1
        jsr wr_core
        pha
        ldx fs_fcb             ; written: the entry gets the time at close
        lda fc_flg,x
        ora #FL_EDIRTY
        sta fc_flg,x
        lda fs_done
        sta bytbuf
        lda fs_done+1
        sta bytbuf+1
        pla
fw_ret  rts

* ---- opening for writing: 8 write, 9 append, C read/write ---------------
* the file is looked for among all files; it is created when missing
fo_write lda dateset           ; dateset 0: the clock's date and time now;
        sta fs_kdt             ; else the ones in date/time (kept: KEEPDT)
        bne fw_d
        ldy #100               ; kd_gettd
        jsr farcall
        dta b(BK_DEV),a(CARTLO+$1B)
fw_d    lda #0                 ; dateset clears after use
        sta dateset
        lda #$80               ; files only, any attributes
        sta fs_scn
        jsr scan_name
        bcc fow_have
        cmp #E_EOF
        bne fow_ret
        jsr nowild             ; create it
        bcs fow_ret
        ldx #10                ; not with the name of a directory
fow0    lda name,x
        sta fs_cname,x
        dex
        bpl fow0
        jsr name_taken
        bcs fow_ret
        jsr alloc              ; its first sector map, empty (as SDX)
        bcs fow_ret
        lda al_s
        sta fs_sec
        sta cd_map
        lda al_s+1
        sta fs_sec+1
        sta cd_map+1
        jsr newsec
        bcs fow_ret
        lda attr               ; attributes, and $40 makes a symbolic link
        and #ST_PROT|ST_HID|ST_ARC|ST_LINK
        ora #ST_USED
        jsr mk_entry
        bcs fow_ret
        jsr new_fcb
        bcs fow_ret
        lda cd_map
        sta fc_maplo,x
        lda cd_map+1
        sta fc_maphi,x
        lda #0
        sta fc_len0,x
        sta fc_len1,x
        sta fc_len2,x
        jsr fow_ent
        lda #FL_WRITE|FL_EDIRTY
        sta fc_flg,x
        jsr fcb_rewind
        jmp fo_ent
fow_ret rts
fow_have lda fs_ent            ; a protected file is not replaced (8: 151),
        and #ST_PROT           ; but it opens to append (9) and to read and
        beq fow0a              ; write (C), as on SDX
        lda mode
        and #$0F
        cmp #$08
        bne fow0a
        lda #E_EXISTS
        rts
fow0a   bit attr               ; a symbolic link does not replace a file
        bvc fow1
        bit fs_ent
        bvs fow1
        lda #E_EXISTS
        rts
fow1    jsr ent_pos            ; the entry is the one just read
        jsr new_fcb
        bcs fow_ret
        lda fs_ent+1
        sta fc_maplo,x
        lda fs_ent+2
        sta fc_maphi,x
        lda fs_ent+3
        sta fc_len0,x
        lda fs_ent+4
        sta fc_len1,x
        lda fs_ent+5
        sta fc_len2,x
        jsr fow_ent
        lda #FL_WRITE
        sta fc_flg,x
        jsr fcb_rewind
        lda mode
        and #$0F
        cmp #$08
        bne fow_app
        jsr trunc              ; write: from length 0
        bcs fow_ret
        ldx fs_fcb
        lda #FL_WRITE|FL_EDIRTY
        sta fc_flg,x
        jmp fo_ent
fow_app cmp #$09
        bne fow_ok
        lda fc_len0,x          ; append: from the end
        sta fc_pos0,x
        lda fc_len1,x
        sta fc_pos1,x
        lda fc_len2,x
        sta fc_pos2,x
fow_ok  jmp fo_ent

* fow_ent: the FCB X remembers where its directory entry is (fs_dmap, fs_epos)
fow_ent lda fs_dmap
        sta fc_dmlo,x
        lda fs_dmap+1
        sta fc_dmhi,x
        lda fs_epos
        sta fc_eplo,x
        lda fs_epos+1
        sta fc_ephi,x
        rts

* ent_pos: fs_epos = position of the entry the internal FCB just read
ent_pos sec
        lda fc_pos0+NFCB
        sbc #23
        sta fs_epos
        lda fc_pos1+NFCB
        sbc #0
        sta fs_epos+1
        rts

* nowild: C=1, A = 163 when name has a wildcard
nowild  ldx #10
nw1     lda name,x
        cmp #'?'
        beq nw_bad
        dex
        bpl nw1
        clc
        rts
nw_bad  lda #E_WILD
        sec
        rts

* ---- closing a file that was written ----------------------------------------
* sectors past the end are freed (left over after a disk full), the directory
* entry gets the map, the length and the time, then all of the drive's
* changes go to the disk
cl_write lda fc_flg,x          ; a directory written in place (mode $1C):
        bpl clwx               ; only the changed sectors go out (EOSFS:
        jsr farcall            ; its name index is dropped)
        dta b(BK_DOS2),a(CARTLO+$1B)
        jmp clw1
clwx
        jsr trim
        jcs clw_ret
        ldx fs_cfcb
        lda fc_flg,x
        and #FL_EDIRTY
        beq clw1
        lda fc_dmlo,x
        sta fs_dmap
        lda fc_dmhi,x
        sta fs_dmap+1
        lda fc_eplo,x
        sta fs_epos
        lda fc_ephi,x
        sta fs_epos+1
        lda fc_maplo,x
        sta cl_map
        lda fc_maphi,x
        sta cl_map+1
        lda fc_len0,x
        sta fs_l
        lda fc_len1,x
        sta fs_l+1
        lda fc_len2,x
        sta fs_l+2
        jsr ent_read
        bcs clw_ret
        lda cl_map
        sta fs_ent+1
        lda cl_map+1
        sta fs_ent+2
        lda fs_l
        sta fs_ent+3
        lda fs_l+1
        sta fs_ent+4
        lda fs_l+2
        sta fs_ent+5
        lda fs_ent             ; a changed file is not archived any more
        and #$FF-ST_ARC
        sta fs_ent
        ldx fs_cfcb            ; the time of the change, unless dateset
        lda fc_flg,x           ; gave one at the open
        and #FL_KEEPDT
        bne clw0
        ldy #100               ; kd_gettd
        jsr farcall
        dta b(BK_DEV),a(CARTLO+$1B)
clw0    jsr stamp
        jsr ent_write
        bcs clw_ret
clw1    jmp flush_drv
clw_ret rts

* ---- 12 kd_delete ---------------------------------------------------------
f_delete jsr setdrv
        bcs fdl_ret
        jsr resolve
        bcs fdl_ret
        jsr scan_init
        bcs fdl_ret
        lda scan
        ora #$80               ; files only
        sta fs_scn
fdl1    jsr scan_next
        bcs fdl_end
        lda fs_ent
        and #ST_PROT
        bne fdl1
        jsr ent_pos
        lda fs_ent+1
        sta tr_m
        lda fs_ent+2
        sta tr_m+1
        jsr free_chain
        bcs fdl_ret
        jsr ent_read           ; the chain walk used the cache: read it again
        bcs fdl_ret
        lda #ST_DEL
        sta fs_ent
        jsr ent_write
        bcs fdl_ret
        inc fs_hits
        jmp fdl1
fdl_end cmp #E_EOF
        bne fdl_ret
        jmp hits_done
fdl_ret rts

* ---- 11 kd_rename: name to x_name ('?' keeps a character) ------------------
f_rename jsr setdrv
        jcs frn_ret
        jsr resolve
        jcs frn_ret
        jsr scan_init
        jcs frn_ret
        lda scan               ; files only, unless RENDIR asks for
        and #$08               ; directories (scan $08)
        beq frn0
        lda scan
        bne frn0a
frn0    lda scan
        ora #$80
frn0a   sta fs_scn
frn1    jsr scan_next
        jcs frn_end
        lda fs_ent             ; protected entries keep their names (SDX:
        and #ST_PROT           ; 170 when nothing else matched)
        bne frn1
        jsr ent_pos
        ldx #10                ; the new name
frn2    lda x_name,x
        cmp #'?'
        bne frn3
        lda fs_ent+6,x
frn3    sta fs_cname,x
        dex
        bpl frn2
        jsr name_taken         ; not the name of another entry
        jcs frn_ret
        jsr ent_read
        jcs frn_ret
        ldx #10
frn4    lda fs_cname,x
        sta fs_ent+6,x
        dex
        bpl frn4
        jsr ent_write
        bcs frn_ret
        lda fs_ent             ; a directory: its own header (entry 0 of
        and #ST_DIR            ; its file) gets the name too, as SDX's CD
        beq frn6               ; shows the new name
        lda fs_dmap
        sta rn_dm
        lda fs_dmap+1
        sta rn_dm+1
        lda fs_epos
        sta rn_ep
        lda fs_epos+1
        sta rn_ep+1
        lda fs_ent+1
        sta fs_dmap
        lda fs_ent+2
        sta fs_dmap+1
        lda #0
        sta fs_epos
        sta fs_epos+1
        jsr ent_read
        bcs frn5
        ldx #10
frn4a   lda fs_cname,x
        sta fs_ent+6,x
        dex
        bpl frn4a
        jsr ent_write
frn5    php                    ; the parent again, at the renamed entry
        pha
        lda rn_dm
        sta fs_dmap
        lda rn_dm+1
        sta fs_dmap+1
        lda rn_ep
        sta fs_epos
        lda rn_ep+1
        sta fs_epos+1
        pla
        plp
        bcs frn_ret
        jsr ent_seek
        bcs frn_ret
frn6    inc fs_hits
        jsr scan_back          ; go on after this entry
        jmp frn1
frn_end cmp #E_EOF
        bne frn_ret
        jmp hits_done
frn_ret rts

* ---- 13 kd_setatr: attr bits 0-2 set P H A, bits 4-6 clear them; bit 7
* (EOS) stamps the entries with the current date and time (or date/time
* when dateset is set): CHTD on directories ---------------------------------
f_setatr jsr setdrv
        bcs fsa_ret
        jsr resolve
        bcs fsa_ret
        jsr scan_init
        bcs fsa_ret
        lda scan
        sta fs_scn
        bit attr
        bpl fsa1
        lda dateset            ; the time: given, or the clock's now
        bne fsa0
        ldy #100               ; kd_gettd
        jsr farcall
        dta b(BK_DEV),a(CARTLO+$1B)
fsa0    lda #0
        sta dateset
fsa1    jsr scan_next
        bcs fsa_end
        jsr ent_pos
        lda attr
        and #ST_PROT|ST_HID|ST_ARC
        ora fs_ent
        sta fs_ent
        lda attr
        lsr @
        lsr @
        lsr @
        lsr @
        and #ST_PROT|ST_HID|ST_ARC
        eor #$FF
        and fs_ent
        sta fs_ent
        bit attr
        bpl fsa2
        jsr stamp
fsa2    jsr ent_write
        bcs fsa_ret
        inc fs_hits
        jmp fsa1
fsa_end cmp #E_EOF
        bne fsa_ret
        jmp hits_done
fsa_ret rts

* ---- 14 kd_credir -------------------------------------------------------------
f_credir jsr setdrv
        jcs fcd_ret
        jsr resolve
        jcs fcd_ret
        jsr nowild
        jcs fcd_ret
        ldx #10
fcd0    lda name,x
        sta fs_cname,x
        dex
        bpl fcd0
        jsr name_taken
        jcs fcd_ret
        lda #ST_USED|ST_DIR
        jsr mk_entry
        jcs fcd_ret
        jsr farcall            ; EOSFS: its name index, an empty list
        dta b(BK_DOS2),a(CARTLO+$15) ; (ix_cs; 0 none)
        jcs fcd_ret
        jsr alloc              ; its sector map
        jcs fcd_ret
        lda al_s
        sta cd_map
        sta fs_sec
        lda al_s+1
        sta cd_map+1
        sta fs_sec+1
        jsr newsec
        jcs fcd_ret
        jsr alloc              ; and its first sector
        jcs fcd_ret
        lda cd_map
        sta fs_sec
        lda cd_map+1
        sta fs_sec+1
        jsr getsec
        bcs fcd_ret
        ldy #4
        lda al_s
        sta (zp_p),y
        iny
        lda al_s+1
        sta (zp_p),y
        jsr is_x               ; EOSFS: an extent of one sector
        bne fcd_m
        ldy #6
        lda #1
        sta (zp_p),y
fcd_m   lda #$FF
        sta bf_dirty,x
        lda al_s
        sta fs_sec
        lda al_s+1
        sta fs_sec+1
        jsr newsec
        bcs fcd_ret
        ldy #22                ; the header: the new entry as its parent
fcd1    lda fs_ent,y           ; holds it, the parent's map, length 23
        sta (zp_p),y
        dey
        bpl fcd1
        ldy #1
        lda fs_dmap
        sta (zp_p),y
        iny
        lda fs_dmap+1
        sta (zp_p),y
        iny
        lda #23
        sta (zp_p),y
        lda ix_cs              ; the index at +20..22 (for the time's
        ora ix_cs+1            ; seconds: $FF)
        beq fcd_n2
        ldy #20
        lda ix_cs
        sta (zp_p),y
        iny
        lda ix_cs+1
        sta (zp_p),y
        iny
        lda #$FF
        sta (zp_p),y
fcd_n2
        lda cd_map               ; the parent's entry: map, length 23
        sta fs_ent+1
        lda cd_map+1
        sta fs_ent+2
        lda #23
        sta fs_ent+3
        jsr ent_write
        bcs fcd_ret
        jmp flush_ok
fcd_ret rts

* ---- 15 kd_deldir: an empty directory ------------------------------------------
f_deldir jsr setdrv
        jcs fdd_ret
        jsr resolve
        bcs fdd_ret
        ldx #10
fdd0    lda name,x
        sta fs_cname,x
        dex
        bpl fdd0
        jsr find_dir           ; its map in fs_dmap, the parent's entry
        bcc fdd_f              ; position in fs_epos, the parent in fs_pmap
        cmp #E_PATH            ; not there: 170, as on SDX
        bne fdd_ret
        lda #E_NOTFOUND
        rts
fdd_f
        jsr open_dir
        bcs fdd_ret
fdd1    jsr dir_next           ; nothing may be left in it
        bcs fdd2
        lda #E_NOTEMPTY
        rts
fdd2    cmp #E_EOF
        bne fdd_ret
        jsr farcall            ; EOSFS: its name index goes too
        dta b(BK_DOS2),a(CARTLO+$18)
        jcs fdd_ret
        ldx fs_drv             ; the current directory goes: main again
        lda fs_dmap
        sta tr_m
        cmp dv_cwdlo,x
        bne fdd3
        lda fs_dmap+1
        cmp dv_cwdhi,x
        bne fdd3
        lda dv_mainlo,x
        sta dv_cwdlo,x
        lda dv_mainhi,x
        sta dv_cwdhi,x
fdd3    lda fs_dmap+1
        sta tr_m+1
        jsr free_chain
        bcs fdd_ret
        lda fs_pmap
        sta fs_dmap
        lda fs_pmap+1
        sta fs_dmap+1
        jsr ent_read
        bcs fdd_ret
        lda #ST_DEL
        sta fs_ent
        jsr ent_write
        bcs fdd_ret
        jmp flush_ok
fdd_ret rts

* ---- 20 kd_chvol: the volume name from name --------------------------------
f_chvol jsr setdrv
        bcs fcv_ret
        jsr mount
        bcs fcv_ret
        lda #1
        sta fs_sec
        lda #0
        sta fs_sec+1
        jsr getsec
        bcs fcv_ret
        ldy #22+7
fcv1    lda name-22,y
        sta (zp_p),y
        dey
        cpy #22
        bcs fcv1
        lda #$FF
        sta bf_dirty,x
        jmp flush_ok
fcv_ret rts

* ---- 18 kd_boot: the file becomes the one booted (header $28: its map) -----
f_boot  jsr setdrv
        bcs fbt_ret
        jsr resolve
        bcs fbt_ret
        lda scan
        ora #$80               ; a file, not a directory
        sta fs_scn
        jsr scan_name
        bcc fbt1
        cmp #E_EOF             ; none: not found
        bne fbt_er
        lda #E_NOTFOUND
fbt_er  sec
        rts
fbt1    lda fs_ent+1
        sta cl_map
        lda fs_ent+2
        sta cl_map+1
        lda #1
        sta fs_sec
        lda #0
        sta fs_sec+1
        jsr getsec
        bcs fbt_ret
        ldy #$28
        lda cl_map
        sta (zp_p),y
        iny
        lda cl_map+1
        sta (zp_p),y
        lda #$FF
        sta bf_dirty,x
        jmp flush_ok
fbt_ret rts

* ---- helpers for the calls above ---------------------------------------------

* scan_init: internal FCB on directory fs_dmap, the pattern from name
scan_init lda #0
        sta fs_hits
        lda #NFCB
        sta fs_fcb
        jsr open_dir
        bcs si_ret
        ldx #10
si1     lda name,x
        sta fs_pat,x
        dex
        bpl si1
        clc
si_ret  rts

* scan_next: the next entry matching fs_pat and fs_scn; C=1 at the end
scan_next lda #NFCB
        sta fs_fcb
sx1     jsr dir_next
        bcs sx_ret
        jsr match
        bcs sx1
sx_ret  rts

* scan_back: the internal FCB to the entry after fs_epos (it was moved)
scan_back clc
        lda fs_epos
        adc #23
        sta fc_pos0+NFCB
        lda fs_epos+1
        adc #0
        sta fc_pos1+NFCB
        lda #0
        sta fc_pos2+NFCB
        rts

* hits_done: E_OK after a changed entry (and the changes to the disk), else
* "file not found"
hits_done lda fs_hits
        bne flush_ok
        lda #E_NOTFOUND
        rts
flush_ok jsr flush_drv
        bcs fo_r
        lda #E_OK
fo_r    rts

* name_taken: C=1, A = 151 when fs_cname is used in directory fs_dmap
* (keeps the internal FCB's position)
name_taken lda fc_pos0+NFCB
        pha
        lda fc_pos1+NFCB
        pha
        lda #NFCB
        sta fs_fcb
        jsr open_dir
        bcs nt_err
nt1     jsr dir_next
        bcs nt_end
        ldx #10
nt2     lda fs_ent+6,x
        cmp fs_cname,x
        bne nt1
        dex
        bpl nt2
        lda #E_EXISTS
        bne nt_err
nt_end  cmp #E_EOF
        bne nt_err
        pla
        sta fc_pos1+NFCB
        pla
        sta fc_pos0+NFCB
        lda #0
        sta fc_pos2+NFCB
        clc
        rts
nt_err  tax
        pla
        pla
        txa
        sec
        rts

* ent_read, ent_write: the entry at fs_epos of directory fs_dmap to and from
* fs_ent, through the internal FCB
ent_read jsr ent_seek
        bcs er_ret
        jmp dir_read
ent_write ldx #22               ; open_dir reads the header to fs_ent
ew1     lda fs_ent,x
        sta fs_ent2,x
        dex
        bpl ew1
        jsr ent_seek
        bcs er_ret
        ldx #22
ew2     lda fs_ent2,x
        sta fs_ent,x
        dex
        bpl ew2
        lda #<fs_ent2
        sta zp_q
        lda #>fs_ent2
        sta zp_q+1
        lda #23
        sta fs_cnt
        lda #0
        sta fs_cnt+1
        jsr wr_core
        bcs ew_ret
        lda fs_epos            ; EOSFS: the name index too
        sta ix_p
        lda fs_epos+1
        sta ix_p+1
        jsr farcall
        dta b(BK_DOS2),a(CARTLO+$12)
ew_ret  rts
ent_seek lda #NFCB
        sta fs_fcb
        jsr open_dir
        bcs er_ret
        lda fs_epos
        sta fc_pos0+NFCB
        lda fs_epos+1
        sta fc_pos1+NFCB
        lda #0
        sta fc_pos2+NFCB
        clc
er_ret  rts

* mk_entry: a new entry with status A and the name name in directory
* fs_dmap: a free slot is reused, else the directory grows. Out: fs_ent,
* fs_epos.
mk_entry sta fs_st
        lda #NFCB
        sta fs_fcb
        jsr open_dir
        jcs mk_ret
        lda fc_len0+NFCB
        sta fs_dlen
        lda fc_len1+NFCB
        sta fs_dlen+1
mk1     jsr dir_read
        bcs mk_end
        lda fs_ent
        and #ST_USED
        bne mk1
        jsr ent_pos            ; a free slot
        jmp mk_have
mk_end  cmp #E_EOF
        jne mk_err
        lda fc_len0+NFCB       ; at the end
        sta fs_epos
        lda fc_len1+NFCB
        sta fs_epos+1
mk_have lda fs_st
        sta fs_ent
        ldx #4
        lda #0
mk2     sta fs_ent+1,x
        dex
        bpl mk2
        ldx #10
mk3     lda name,x
        sta fs_ent+6,x
        dex
        bpl mk3
        jsr stamp
        jsr ent_write
        bcs mk_ret
        sec                    ; did the directory grow?
        lda fc_pos0+NFCB
        cmp fs_dlen
        lda fc_pos1+NFCB
        sbc fs_dlen+1
        bcc mk_ok
        lda fc_len0+NFCB       ; then its header gets the new length
        sta fs_l
        lda fc_len1+NFCB
        sta fs_l+1
        lda fc_len2+NFCB
        sta fs_l+2
        lda #3
        sta fc_pos0+NFCB
        lda #0
        sta fc_pos1+NFCB
        sta fc_pos2+NFCB
        lda #<fs_l
        sta zp_q
        lda #>fs_l
        sta zp_q+1
        lda #3
        sta fs_cnt
        lda #0
        sta fs_cnt+1
        jsr wr_core
        bcs mk_ret
        lda fs_epos            ; fs_ent is the new entry again
        sta fc_pos0+NFCB
        jsr ent_read
        bcs mk_ret
mk_ok   clc
mk_ret  rts
mk_err  sec
        rts

* stamp: the current date and time into fs_ent
stamp   ldx #5
st1     lda date,x
        sta fs_ent+17,x
        dex
        bpl st1
        rts

* ---- writing data ----------------------------------------------------------

* wr_core: write fs_cnt bytes from (zp_q) to FCB fs_fcb, allocating sectors
* as needed. Out: fs_done; A = status, C=1 unless E_OK.
wr_core lda #0
        sta fs_done
        sta fs_done+1
wc_loop lda fs_cnt
        ora fs_cnt+1
        bne wc1
        lda #E_OK
        clc
        rts
wc1     lda #$FF
        sta fs_alloc
        jsr locate
        ldx #0                 ; keeps the status in A
        stx fs_alloc
        jcs wc_ret
        ldy fs_drv             ; fs_n = min(bytes left in the sector, fs_cnt)
        sec
        lda dv_szlo,y
        sbc fs_off
        sta fs_n
        lda dv_szhi,y
        sbc fs_off+1
        sta fs_n+1
        lda fs_cnt
        ldx fs_cnt+1
        jsr min_n
        bit fs_new
        bpl wc2
        lda fs_off             ; a new sector is not read, nor zeroed when
        ora fs_off+1           ; it is written whole
        bne wcz
        ldy fs_drv
        lda fs_n
        cmp dv_szlo,y
        bne wcz
        lda fs_n+1
        cmp dv_szhi,y
        bne wcz
        jsr farcall            ; whole: straight from the caller's buffer
        dta b(BK_DOS2),a(CARTLO+$24) ; when it is in main memory (dos2)
        inx
        beq wcn                ; (X=$FF: it is not)
        cmp #$80
        jcs wc_ret             ; (C=1, A = the status)
        jmp wc_dn
wcn     sec                    ; through the cache, not zeroed
        bcs wcy
wcz     clc
wcy     jsr ns_c
        jmp wc3
wc2     jsr getsec
wc3     jcs wc_ret
        stx fs_ub
        lda #$FF
        sta bf_dirty,x
        clc
        lda zp_p
        adc fs_off
        sta zp_p
        lda zp_p+1
        adc fs_off+1
        sta zp_p+1
        jsr farcall            ; copy_w: fs_n bytes from (zp_q) to (zp_p),
        dta b(BK_DOS2),a(CARTLO+$27) ; zp_q past them (dos2 bank)
        jsr used_up
wc_dn   ldx fs_fcb
        clc
        lda fc_pos0,x
        adc fs_n
        sta fc_pos0,x
        lda fc_pos1,x
        adc fs_n+1
        sta fc_pos1,x
        bcc wc4
        inc fc_pos2,x
wc4     lda fc_len0,x          ; past the end: a longer file
        cmp fc_pos0,x
        lda fc_len1,x
        sbc fc_pos1,x
        lda fc_len2,x
        sbc fc_pos2,x
        bcs wc5
        lda fc_pos0,x
        sta fc_len0,x
        lda fc_pos1,x
        sta fc_len1,x
        lda fc_pos2,x
        sta fc_len2,x
        lda fc_flg,x
        ora #FL_EDIRTY
        sta fc_flg,x
wc5     sec
        lda fs_cnt
        sbc fs_n
        sta fs_cnt
        lda fs_cnt+1
        sbc fs_n+1
        sta fs_cnt+1
        clc
        lda fs_done
        adc fs_n
        sta fs_done
        lda fs_done+1
        adc fs_n+1
        sta fs_done+1
        jmp wc_loop
wc_ret  rts

* newsec: sector fs_sec into the cache without reading it, all zeros and
* to be written; ns_c with C=1: not zeroed (the caller fills it all). Out
* as getsec.
newsec  clc
ns_c    ror fs_nz
        ldx #NBUF-1
ns1     lda bf_drv,x
        cmp fs_drv
        bne ns2
        lda bf_seclo,x
        cmp fs_sec
        bne ns2
        lda bf_sechi,x
        cmp fs_sec+1
        beq ns3
ns2     dex
        bpl ns1
        jsr victim
        bcs ns_ret
        lda fs_drv
        sta bf_drv,x
        lda fs_sec
        sta bf_seclo,x
        lda fs_sec+1
        sta bf_sechi,x
ns3     lda #$FF
        sta bf_dirty,x
        jsr touch
        lda bf_lo,x
        sta zp_p
        lda bf_hi,x
        sta zp_p+1
        bit fs_nz
        bmi ns5
        stx fs_x
        ldy fs_drv             ; the sector's pages (128 bytes: one)
        ldx dv_szhi,y
        bne ns3a
        inx
ns3a    ldy #0
        lda #0
ns4     sta (zp_p),y
        iny
        bne ns4
        inc zp_p+1
        dex
        bne ns4
        ldx fs_x
        lda bf_hi,x
        sta zp_p+1
ns5     clc
ns_ret  rts

* ---- the sector bitmap ------------------------------------------------------

* alloc: a free sector of drive fs_drv to al_s, taken from the bitmap
* (search from the header's hint). C=1, A = status (162 disk full).
alloc   ldx fs_drv
        lda dv_freelo,x
        ora dv_freehi,x
        jeq al_full
        lda dv_hintlo,x
        sta al_s
        lda dv_hinthi,x
        sta al_s+1
        lda dv_totlo,x
        sta al_n
        lda dv_tothi,x
        sta al_n+1
al1     jsr al_wrap
        jsr bitpos
        bcs al_ret
        lda (zp_t),y
        bne al2
        lda al_s               ; a byte of used sectors: skip to its end
        ora #7
        sta al_s
        bne al3
al2     and al_mask
        bne al_take
al3     inc al_s
        bne al4
        inc al_s+1
al4     lda al_n
        bne al5
        dec al_n+1
        bmi al_full
al5     dec al_n
        jmp al1
al_take lda (zp_t),y
        eor al_mask
        sta (zp_t),y
        lda #$FF
        sta bf_dirty,x
        ldx fs_drv
        lda dv_freelo,x
        bne al6
        dec dv_freehi,x
al6     dec dv_freelo,x
        clc
        lda al_s
        adc #1
        sta dv_hintlo,x
        lda al_s+1
        adc #0
        sta dv_hinthi,x
        lda dv_hdirty,x        ; (bit 7: free count, hint; bit 6 is the
        ora #$80               ; dirty flag's)
        sta dv_hdirty,x
        clc
al_ret  rts
al_full lda #E_FULL
        sec
        rts

* al_wrap: al_s back to 1 past the last sector that has a bit
al_wrap ldx fs_drv
        lda al_s
        ora al_s+1
        beq aw1
        lda dv_totlo,x
        cmp al_s
        lda dv_tothi,x
        sbc al_s+1
        bcc aw1
        lda al_s               ; the last bitmap bit is sector nbits-1
        cmp dv_bitslo,x
        lda al_s+1
        sbc dv_bitshi,x
        bcc aw_ret
aw1     lda #1
        sta al_s
        lda #0
        sta al_s+1
aw_ret  rts

* free_sec: sector al_s becomes free again
free_sec jsr bitpos
        bcs fs_ret
        lda (zp_t),y
        ora al_mask
        sta (zp_t),y
        lda #$FF
        sta bf_dirty,x
        ldx fs_drv
        inc dv_freelo,x
        bne fs1
        inc dv_freehi,x
fs1     lda dv_hdirty,x
        ora #$80
        sta dv_hdirty,x
        clc
fs_ret  rts

* bitpos: the bitmap byte of sector al_s at (zp_t),Y (Y=0), its bit in
* al_mask; X = its buffer. C=1, A = status on error.
bitpos  lda al_s+1             ; byte index = al_s / 8
        sta fs_t+1
        lda al_s
        lsr fs_t+1
        ror @
        lsr fs_t+1
        ror @
        lsr fs_t+1
        ror @
        sta fs_t
        ldx fs_drv             ; bitmap sector = byte index >> shift,
        lda dv_shf,x           ; offset = the rest
        tax
        lda fs_t
        sta bp_off
        lda fs_t+1
        sta bp_off+1
bp1     lsr fs_t+1
        ror fs_t
        dex
        bne bp1
        ldx fs_drv
        ldy dv_shf,x
        lda bp_mlo-7,y
        and bp_off
        sta bp_off
        lda bp_mhi-7,y
        and bp_off+1
        sta bp_off+1
        clc
        lda dv_bmaplo,x
        adc fs_t
        sta fs_sec
        lda dv_bmaphi,x
        adc fs_t+1
        sta fs_sec+1
        jsr getsec
        bcs bp_ret
        clc
        lda zp_p
        adc bp_off
        sta zp_t
        lda zp_p+1
        adc bp_off+1
        sta zp_t+1
        lda al_s
        and #7
        tay
        lda bp_bits,y
        sta al_mask
        ldy #0
        clc
bp_ret  rts
bp_mlo  dta b($7F,$FF,$FF)       ; offset masks for shift 7, 8, 9
bp_mhi  dta b(0,0,1)
bp_bits dta b($80,$40,$20,$10,$08,$04,$02,$01)

* free_chain: free a file's sectors: every data sector and sector map of the
* chain starting at map tr_m
free_chain jsr is_x            ; EOSFS: extents (dos2x.icl)
        bne fc_sd
        jsr farcall
        dta b(BK_DOS2),a(CARTLO+3)
        rts
fc_sd   lda tr_m
        ora tr_m+1
        bne fc0
        clc
        rts
fc0     lda #0
        sta tr_i
fc1     jsr tr_ent             ; entry tr_i of map tr_m
        bcs fc_err
        ldy #0
        lda (zp_t),y
        sta al_s
        iny
        lda (zp_t),y
        sta al_s+1
        ora al_s
        beq fc2
        jsr free_sec
        bcs fc_err
fc2     inc tr_i
        lda tr_i
        ldy fs_drv
        cmp dv_ments,y
        bcc fc1
        lda tr_m               ; the map itself, then the next one
        sta fs_sec
        lda tr_m+1
        sta fs_sec+1
        jsr getsec
        bcs fc_err
        lda tr_m
        sta al_s
        lda tr_m+1
        sta al_s+1
        ldy #0
        lda (zp_p),y
        sta tr_m
        iny
        lda (zp_p),y
        sta tr_m+1
        jsr free_sec
        bcs fc_err
        jmp free_chain
fc_err  rts

* tr_ent: zp_t = entry tr_i of map sector tr_m (map + 4 + 2 * tr_i)
tr_ent  lda tr_m
        sta fs_sec
        lda tr_m+1
        sta fs_sec+1
        jsr getsec
        bcs te_ret
        lda tr_i
        asl @
        sta zp_t
        lda #0
        rol @
        sta zp_t+1
        clc
        lda zp_t
        adc #4
        bcc te1
        inc zp_t+1
        clc
te1     adc zp_p
        sta zp_t
        lda zp_t+1
        adc zp_p+1
        sta zp_t+1
        clc
te_ret  rts

* trim: free the sectors of FCB fs_fcb that lie past its length: data
* sectors from index ceil(length / sector size) on, and the maps that then
* hold none. C=1, A = status.
trim    stx fs_fcb
        ldy fs_drv             ; tr_need = number of data sectors needed
        lda fc_len0,x
        sta tr_need
        lda fc_len1,x
        sta tr_need+1
        lda fc_len2,x
        sta fs_l
        lda dv_szlo,y          ; round up: + sector size - 1
        sec
        sbc #1
        sta fs_t
        lda dv_szhi,y
        sbc #0
        sta fs_t+1
        clc
        lda tr_need
        adc fs_t
        sta tr_need
        lda tr_need+1
        adc fs_t+1
        sta tr_need+1
        bcc tm0
        inc fs_l
tm0     ldx dv_shf,y           ; then shift
tm1     lsr fs_l
        ror tr_need+1
        ror tr_need
        dex
        bne tm1
        jsr is_x               ; EOSFS: extents (dos2x.icl)
        bne tm1a
        jsr farcall
        dta b(BK_DOS2),a(CARTLO+6)
        jcs tm_ret
        jmp tm_done
tm1a
        ldx fs_fcb
        lda fc_maplo,x
        sta tr_m
        lda fc_maphi,x
        sta tr_m+1
        lda tr_need
        ora tr_need+1
        bne tm2
        jsr free_chain         ; no data at all: no map either
        jcs tm_ret
        ldx fs_fcb
        lda #0
        sta fc_maplo,x
        sta fc_maphi,x
        jmp tm_done
tm2     lda tr_m               ; walk to the map with the last needed entry
        ora tr_m+1
        jeq tm_done
        ldy fs_drv
        lda tr_need+1
        bne tm3
        lda tr_need
        cmp dv_ments,y
        bcc tm4
        beq tm4
tm3     sec                    ; not in this map: on to the next
        lda tr_need
        sbc dv_ments,y
        sta tr_need
        bcs tm3a
        dec tr_need+1
tm3a    lda tr_m
        sta fs_sec
        lda tr_m+1
        sta fs_sec+1
        jsr getsec
        jcs tm_ret
        ldy #0
        lda (zp_p),y
        sta tr_m
        iny
        lda (zp_p),y
        sta tr_m+1
        jmp tm2
tm4     lda tr_need            ; this map keeps entries 0 .. tr_need-1
        sta tr_i
tm5     ldy fs_drv
        lda tr_i
        cmp dv_ments,y
        bcs tm6
        jsr tr_ent
        bcs tm_ret
        ldy #0
        lda (zp_t),y
        sta al_s
        iny
        lda (zp_t),y
        sta al_s+1
        ora al_s
        beq tm5a
        lda #0                 ; out of the map, then free
        sta (zp_t),y
        dey
        sta (zp_t),y
        lda #$FF
        sta bf_dirty,x
        jsr free_sec
        bcs tm_ret
tm5a    inc tr_i
        jmp tm5
tm6     lda tr_m               ; and the maps after it
        sta fs_sec
        lda tr_m+1
        sta fs_sec+1
        jsr getsec
        bcs tm_ret
        ldy #0
        lda (zp_p),y
        pha
        lda #0
        sta (zp_p),y
        iny
        lda (zp_p),y
        sta tr_m+1
        lda #0
        sta (zp_p),y
        lda #$FF
        sta bf_dirty,x
        pla
        sta tr_m
        jsr free_chain
        bcs tm_ret
tm_done ldx fs_fcb             ; the position may lie past the end now
        lda #0
        sta fc_cmlo,x
        sta fc_cmhi,x
        clc
tm_ret  rts

* trunc: length and position 0, the sectors freed but the first map kept
trunc   ldx fs_fcb
        lda #0
        sta fc_len0,x
        sta fc_len1,x
        sta fc_len2,x
        jsr fcb_rewind
        jmp trim

* flush_drv: the volume header (free count, hint) and every changed sector
* of drive fs_drv to the disk
flush_drv ldx fs_drv
        lda dv_hdirty,x
        beq fl1
        and #$40               ; (EOSFS: the dirty flag stays on until the
        sta dv_hdirty,x        ; header goes, last)
        lda #1
        sta fs_sec
        lda #0
        sta fs_sec+1
        jsr getsec
        bcs fl_ret
        ldy fs_drv
        lda dv_freelo,y
        ldy #13
        sta (zp_p),y
        ldy fs_drv
        lda dv_freehi,y
        ldy #14
        sta (zp_p),y
        ldy fs_drv
        lda dv_hintlo,y
        ldy #18
        sta (zp_p),y
        ldy fs_drv
        lda dv_hinthi,y
        ldy #19
        sta (zp_p),y
        ldy #38                ; the sequence number counts header writes
        lda (zp_p),y           ; (as SDX's), kept so it is the same disk
        clc
        adc #1
        sta (zp_p),y
        ldy fs_drv
        sta dv_seq,y
        lda #$FF
        sta bf_dirty,x
fl1     lda #0                 ; every changed sector but the header, then
        sta fl_p               ; the header (EOSFS: its dirty flag off once
fl1a    ldx #NBUF-1            ; the rest is on the disk)
fl2     lda bf_drv,x
        cmp fs_drv
        bne fl3
        lda bf_dirty,x
        beq fl3
        lda bf_sechi,x
        bne fl2a
        lda bf_seclo,x
        cmp #1
        bne fl2a
        bit fl_p
        bpl fl3
fl2a    jsr wr_buf
        bcs fl_ret
fl3     dex
        bpl fl2
        lda fl_p
        bmi fl4
        dec fl_p
        bmi fl1a
fl4     ldx fs_drv
        lda dv_hdirty,x
        and #$BF
        sta dv_hdirty,x
        clc
fl_ret  pha                    ; (keeps A and C)
        lda #0
        sta fl_p
        pla
        rts

* wr_buf: buffer X to its disk; keeps X
wr_buf  stx fs_x
        jsr farcall            ; EOSFS: the header's dirty flag first
        dta b(BK_DOS2),a(CARTLO+$2A)
        ldx fs_x
        lda k_wrtcmd           ; P, or W to verify (the VERIFY command)
        jsr sio_io
        bcs wb_ret
        lda #0
        sta bf_dirty,x
wb_ret  rts
