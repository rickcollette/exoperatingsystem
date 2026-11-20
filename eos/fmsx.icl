* EOSFS (docs/EOSFS.md): files as extents. An EOSFS disk is an SDFS disk
* whose sector maps are extent lists: a list sector holds the next and the
* previous list sector (as a map does), then extents of four bytes, a start
* sector and a count (a count of 0 ends the list; a start of 0 is a gap,
* read as zeros). The FMS's other code (directories, paths, names) is the
* SDFS one; locate, free_chain and trim come here for dv_fs 3.
* Included in fms.asm.

* is_x: Z=1 when drive fs_drv is EOSFS; keeps X
is_x    ldy fs_drv
        lda dv_fs,y
        cmp #3
        rts

* x_ent: zp_t = extent xs_j of the list sector at zp_p (zp_p + 4 + 4 * j)
x_ent   lda xs_j
        asl @
        asl @
        sta zp_t
        lda #0
        rol @
        sta zp_t+1
        clc
        lda zp_t
        adc #4
        bcc xe1
        inc zp_t+1
        clc
xe1     adc zp_p
        sta zp_t
        lda zp_t+1
        adc zp_p+1
        sta zp_t+1
        rts

* locate_x: fs_idx to fs_sec for FCB fs_fcb (fs_new $FF: a sector just
* taken, not to be read). Writing (fs_alloc) past the sectors the file has:
* the sectors skipped become a gap extent, the next one grows the last
* extent when the sector after it is free, else starts a new one. C=1,
* A = status.
locate_x ldx fs_fcb
        lda #0
        sta fs_new
        lda fc_maplo,x         ; no list yet
        ora fc_maphi,x
        bne lx1
        lda fs_alloc
        bne lx0
        jmp lc_none
lx0     jsr alloc              ; writing: its first list sector, empty
        jcs lx_r
        lda al_s
        sta fs_sec
        lda al_s+1
        sta fs_sec+1
        jsr newsec
        jcs lx_r
        ldx fs_fcb
        lda al_s
        sta fc_maplo,x
        lda al_s+1
        sta fc_maphi,x
        lda fc_flg,x
        ora #FL_EDIRTY
        sta fc_flg,x
        lda #0
        sta fc_cmlo,x
        sta fc_cmhi,x
lx1     lda fc_cmlo,x          ; from the list sector in use when fs_idx
        ora fc_cmhi,x          ; lies past its base, else from the first
        beq lx2
        lda fs_idx
        cmp fc_cblo,x
        lda fs_idx+1
        sbc fc_cbhi,x
        bcs lx3
lx2     lda fc_maplo,x
        sta fc_cmlo,x
        lda fc_maphi,x
        sta fc_cmhi,x
        lda #0
        sta fc_cblo,x
        sta fc_cbhi,x
lx3     lda fc_cblo,x
        sta xs_b
        lda fc_cbhi,x
        sta xs_b+1
lx4     jsr rd_map             ; zp_p = list sector fc_cm
        jcs lx_r
        lda #0
        sta xs_j
lx5     jsr x_ent
        ldy #2                 ; its count; 0: the end of the extents
        lda (zp_t),y
        sta xs_c
        iny
        lda (zp_t),y
        sta xs_c+1
        ora xs_c
        jeq lx_end
        sec                    ; fs_idx - base < count: in this extent
        lda fs_idx
        sbc xs_b
        sta xs_t
        lda fs_idx+1
        sbc xs_b+1
        sta xs_t+1
        lda xs_t
        cmp xs_c
        lda xs_t+1
        sbc xs_c+1
        bcc lx_in
        clc                    ; past it
        lda xs_b
        adc xs_c
        sta xs_b
        lda xs_b+1
        adc xs_c+1
        sta xs_b+1
        inc xs_j
        lda xs_j
        ldy fs_drv
        cmp dv_ments,y
        bcc lx5
        ldy #0                 ; the next list sector, if any
        lda (zp_p),y
        sta xs_t
        iny
        lda (zp_p),y
        sta xs_t+1
        ora xs_t
        beq lx_full
        ldx fs_fcb
        lda xs_t
        sta fc_cmlo,x
        lda xs_t+1
        sta fc_cmhi,x
        lda xs_b
        sta fc_cblo,x
        lda xs_b+1
        sta fc_cbhi,x
        jmp lx4
lx_r    rts
lx_in   ldy #0                 ; sector = start + (fs_idx - base)
        lda (zp_t),y
        sta xs_s
        iny
        lda (zp_t),y
        sta xs_s+1
        ora xs_s
        beq lx_gap
        clc
        lda xs_s
        adc xs_t
        sta fs_sec
        lda xs_s+1
        adc xs_t+1
        sta fs_sec+1
        clc
        rts
lx_gap  lda fs_alloc           ; in a gap: zeros to read; writing into one
        bne lx_rng             ; is not done (EOSFS 1)
        jmp lc_none
lx_rng  lda #E_RANGE
        sec
        rts
lx_full lda #$FF               ; the last list sector is full
        sta xs_j
lx_end  lda fs_alloc           ; past the sectors the file has
        bne lx_e0
        jmp lc_none
lx_e0   sec                    ; a gap first, when sectors are skipped
        lda fs_idx
        sbc xs_b
        sta xs_c
        lda fs_idx+1
        sbc xs_b+1
        sta xs_c+1
        ora xs_c
        beq lx_e1
        lda #0
        sta xs_s
        sta xs_s+1
        jsr x_add
        bcs lx_r
        clc
        lda xs_b
        adc xs_c
        sta xs_b
        lda xs_b+1
        adc xs_c+1
        sta xs_b+1
lx_e1   jsr x_last             ; the sector after the last extent, if free
        ldx fs_drv
        lda xs_s
        ora xs_s+1
        beq lx_e2
        clc
        lda xs_s
        adc xs_c
        sta dv_hintlo,x
        lda xs_s+1
        adc xs_c+1
        sta dv_hinthi,x
lx_e2   jsr alloc
        jcs lx_r
        lda al_s               ; the new sector, not to be read
        sta fs_sec
        lda al_s+1
        sta fs_sec+1
        lda #$FF
        sta fs_new
        lda xs_s               ; right after the last extent: it grows
        ora xs_s+1
        beq lx_new
        clc
        lda xs_s
        adc xs_c
        tax
        lda xs_s+1
        adc xs_c+1
        cmp al_s+1
        bne lx_new
        cpx al_s
        bne lx_new
        jsr rd_map             ; (alloc may have used the cache)
        jcs lx_r
        lda xs_lj
        sta xs_j
        jsr x_ent
        ldy #2
        lda (zp_t),y
        clc
        adc #1
        sta (zp_t),y
        iny
        lda (zp_t),y
        adc #0
        sta (zp_t),y
        jsr x_dirty
        lda al_s               ; (rd_map set fs_sec to the list sector)
        sta fs_sec
        lda al_s+1
        sta fs_sec+1
        rts
lx_new  lda al_s               ; else a new extent of one sector
        sta xs_s
        lda al_s+1
        sta xs_s+1
        lda #1
        sta xs_c
        lda #0
        sta xs_c+1
        lda fs_sec             ; (x_add may take a list sector)
        pha
        lda fs_sec+1
        pha
        jsr x_add
        pla
        sta fs_sec+1
        pla
        sta fs_sec
        bcs lx_r2
        lda #$FF
        sta fs_new
        clc
lx_r2   rts

* x_last: xs_s, xs_c = the last extent of the list sector in use (fc_cm),
* xs_lj its number; xs_s = 0 when it has none (or it is a gap)
x_last  jsr rd_map
        bcs xl_none
        lda #0
        sta xs_j
        lda #$FF
        sta xs_lj
xl1     ldy fs_drv
        lda xs_j
        cmp dv_ments,y
        bcs xl2
        jsr x_ent
        ldy #2
        lda (zp_t),y
        iny
        ora (zp_t),y
        beq xl2
        lda xs_j
        sta xs_lj
        inc xs_j
        bne xl1
xl2     lda xs_lj
        bmi xl_none
        sta xs_j
        jsr x_ent
        ldy #0
        lda (zp_t),y
        sta xs_s
        iny
        lda (zp_t),y
        sta xs_s+1
        iny
        lda (zp_t),y
        sta xs_c
        iny
        lda (zp_t),y
        sta xs_c+1
        rts
xl_none lda #0
        sta xs_s
        sta xs_s+1
        rts

* x_add: extent xs_s, xs_c after the last one of the list sector in use
* (fc_cm); a full one gets a next list sector (its base: xs_b). C=1, A =
* status.
x_add   lda xs_s               ; (x_last uses xs_s and xs_c)
        pha
        lda xs_s+1
        pha
        lda xs_c
        pha
        lda xs_c+1
        pha
        jsr x_last
        pla
        sta xs_c+1
        pla
        sta xs_c
        pla
        sta xs_s+1
        pla
        sta xs_s
        ldy fs_drv
        ldx xs_lj
        inx
        txa
        cmp dv_ments,y
        jcc xa1
        lda xs_s               ; full: keep the extent, take a list sector
        pha
        lda xs_s+1
        pha
        lda xs_c
        pha
        lda xs_c+1
        pha
        jsr alloc
        jcs xa_err
        lda al_s
        sta fs_sec
        lda al_s+1
        sta fs_sec+1
        jsr newsec             ; back link to the full one
        jcs xa_err
        ldx fs_fcb
        ldy #2
        lda fc_cmlo,x
        sta (zp_p),y
        iny
        lda fc_cmhi,x
        sta (zp_p),y
        jsr rd_map             ; forward link in the full one
        bcs xa_err
        ldy #0
        lda al_s
        sta (zp_p),y
        iny
        lda al_s+1
        sta (zp_p),y
        jsr x_dirty
        ldx fs_fcb
        lda al_s
        sta fc_cmlo,x
        lda al_s+1
        sta fc_cmhi,x
        lda xs_b
        sta fc_cblo,x
        lda xs_b+1
        sta fc_cbhi,x
        pla
        sta xs_c+1
        pla
        sta xs_c
        pla
        sta xs_s+1
        pla
        sta xs_s
        jsr rd_map
        bcs xa_r
        lda #0
xa1     sta xs_j
        jsr rd_map
        bcs xa_r
        jsr x_ent
        ldy #0
        lda xs_s
        sta (zp_t),y
        iny
        lda xs_s+1
        sta (zp_t),y
        iny
        lda xs_c
        sta (zp_t),y
        iny
        lda xs_c+1
        sta (zp_t),y
* x_dirty: the list sector in the cache (fs_buf) is to be written
x_dirty ldy fs_buf
        lda #$FF
        sta bf_dirty,y
        clc
xa_r    rts
xa_err  tax                    ; (the status, with the saved extent dropped)
        pla
        pla
        pla
        pla
        txa
        sec
        rts

