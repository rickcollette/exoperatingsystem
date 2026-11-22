* ---- EOSFS (fms.asm fmsx.icl): freeing a file's extents and list sectors
* (kd_delete, trimming a written file); here for room in the FMS bank.
* x_ent as in fmsx.icl.
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
x_dirty ldy fs_buf
        lda #$FF
        sta bf_dirty,y
        clc
        rts
free_sec jsr farcall
        dta b(BK_FMS),a(FMS_FREESEC)
        rts

* free_x: free every sector of the extent list tr_m: its extents (not the
* gaps) and the list sectors. C=1, A = status.
free_x  lda tr_m
        ora tr_m+1
        bne fx0
        clc
        rts
fx0     lda #0
        sta xs_j
fx1     ldy fs_drv
        lda xs_j
        cmp dv_ments,y
        bcs fx_next
        lda tr_m
        sta fs_sec
        lda tr_m+1
        sta fs_sec+1
        jsr getsec
        bcs fx_r
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
        ora xs_c
        beq fx_next
        jsr fx_run
        bcs fx_r
        inc xs_j
        bne fx1
fx_next lda tr_m               ; the list sector itself, then the next one
        sta fs_sec
        sta al_s
        lda tr_m+1
        sta fs_sec+1
        sta al_s+1
        jsr getsec
        bcs fx_r
        ldy #0
        lda (zp_p),y
        sta tr_m
        iny
        lda (zp_p),y
        sta tr_m+1
        jsr free_sec
        bcs fx_r
        jmp free_x
fx_r    rts
* fx_run: free xs_c sectors from xs_s (nothing for a gap)
fx_run  lda xs_s
        ora xs_s+1
        beq fr_ok
fr1     lda xs_c
        ora xs_c+1
        beq fr_ok
        lda xs_s
        sta al_s
        lda xs_s+1
        sta al_s+1
        jsr free_sec
        bcs fr_r
        inc xs_s
        bne fr2
        inc xs_s+1
fr2     lda xs_c
        bne fr3
        dec xs_c+1
fr3     dec xs_c
        jmp fr1
fr_ok   clc
fr_r    rts

* trim_x: free what FCB fs_fcb has past tr_need sectors (trim worked that
* out): the extent that holds sector tr_need shrinks to it, the extents and
* list sectors after it go. C=1, A = status.
trim_x  ldx fs_fcb
        lda fc_maplo,x
        sta tr_m
        lda fc_maphi,x
        sta tr_m+1
        lda tr_need
        ora tr_need+1
        bne tx0
        jsr free_x             ; no data: no list either
        jcs tx_r
        ldx fs_fcb
        lda #0
        sta fc_maplo,x
        sta fc_maphi,x
        clc
        rts
tx0     lda #0
        sta xs_b
        sta xs_b+1
tx1     lda tr_m               ; each list sector
        ora tr_m+1
        bne tx1a
        clc
        rts
tx1a    lda #0
        sta xs_j
tx2     ldy fs_drv
        lda xs_j
        cmp dv_ments,y
        jcs tx_nx
        lda tr_m
        sta fs_sec
        lda tr_m+1
        sta fs_sec+1
        jsr getsec
        jcs tx_r
        stx fs_buf
        jsr x_ent
        ldy #2
        lda (zp_t),y
        sta xs_c
        iny
        lda (zp_t),y
        sta xs_c+1
        ora xs_c
        jeq tx_cut             ; the end: nothing past it
        sec                    ; keep = tr_need - base (when < count)
        lda tr_need
        sbc xs_b
        sta xs_t
        lda tr_need+1
        sbc xs_b+1
        sta xs_t+1
        bcc tx_all             ; (all past: from the start of the extent)
        lda xs_t
        cmp xs_c
        lda xs_t+1
        sbc xs_c+1
        bcs tx_keep            ; all kept
        jmp tx_part
tx_all  lda #0
        sta xs_t
        sta xs_t+1
tx_part ldy #0                 ; free start + keep .. the end, count = keep
        lda (zp_t),y
        clc
        adc xs_t
        sta xs_s
        iny
        lda (zp_t),y
        adc xs_t+1
        sta xs_s+1
        dey
        lda (zp_t),y
        iny
        ora (zp_t),y
        bne tx_p1
        sta xs_s               ; (a gap: nothing to free)
        sta xs_s+1
tx_p1   sec
        lda xs_c
        sbc xs_t
        sta xs_c
        lda xs_c+1
        sbc xs_t+1
        sta xs_c+1
        ldy #2                 ; the extent's new count (0 ends the list)
        lda xs_t
        sta (zp_t),y
        iny
        lda xs_t+1
        sta (zp_t),y
        lda xs_t
        ora xs_t+1
        bne tx_p2
        ldy #0
        sta (zp_t),y
        iny
        sta (zp_t),y
tx_p2   jsr x_dirty
        jsr fx_run
        bcs tx_r
tx_keep clc                    ; the next extent
        lda xs_b
        adc xs_c
        sta xs_b
        lda xs_b+1
        adc xs_c+1
        sta xs_b+1
        inc xs_j
        jmp tx2
tx_cut  clc
        rts
tx_nx   lda tr_m               ; the next list sector: past what is kept,
        sta fs_sec             ; it goes (and the link to it)
        lda tr_m+1
        sta fs_sec+1
        jsr getsec
        bcs tx_r
        ldy #0
        lda (zp_p),y
        sta xs_t
        iny
        lda (zp_p),y
        sta xs_t+1
        lda xs_b
        cmp tr_need
        lda xs_b+1
        sbc tr_need+1
        bcc tx_nx2
        lda #0                 ; all kept so far: the rest is freed
        ldy #0
        sta (zp_p),y
        iny
        sta (zp_p),y
        lda #$FF
        sta bf_dirty,x
        lda xs_t
        sta tr_m
        lda xs_t+1
        sta tr_m+1
        jsr free_x
        bcs tx_r
        clc
        rts
tx_nx2  lda xs_t
        sta tr_m
        lda xs_t+1
        sta tr_m+1
        jmp tx1
tx_r    rts
