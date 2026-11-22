x_gapwrite
        lda xs_t               ; left gap length
        sta xs_b
        lda xs_t+1
        sta xs_b+1
        sec                    ; right = whole gap - left - 1
        lda xs_c
        sbc xs_t
        sta tr_need
        lda xs_c+1
        sbc xs_t+1
        sta tr_need+1
        lda tr_need
        bne xgw_dec
        dec tr_need+1
xgw_dec dec tr_need
        lda #0
        sta fs_n               ; extra slots beyond the replacement extent
        lda xs_b
        ora xs_b+1
        beq xgw_nl
        inc fs_n
xgw_nl  lda tr_need
        ora tr_need+1
        beq xgw_nr
        inc fs_n
xgw_nr  lda xs_j
        sta xs_lj              ; original gap slot
        jsr xalloc
        jcs xgw_ret
        lda al_s
        sta rn_dm
        lda al_s+1
        sta rn_dm+1
        jsr gap_rdmap             ; alloc may have changed the cache selection
        jcs xgw_ret
        lda xs_lj              ; find the existing zero terminator
        sta fs_rel
xgw_f   lda fs_rel
        sta xs_j
        jsr x_ent
        ldy #2
        lda (zp_t),y
        iny
        ora (zp_t),y
        beq xgw_room
        inc fs_rel
        ldy fs_drv
        lda fs_rel
        cmp dv_ments,y
        bcc xgw_f
xgw_full lda #E_DIRFULL
        sec
        rts
xgw_room lda fs_rel            ; terminator's destination must still fit
        clc
        adc fs_n
        ldy fs_drv
        cmp dv_ments,y
        bcs xgw_full
* Move the terminator and all extents after the gap from the end backward.
xgw_mv  lda fs_rel
        cmp xs_lj
        beq xgw_write
        sta xs_j
        jsr x_ent
        ldy #0
        lda (zp_t),y
        sta d_v
        iny
        lda (zp_t),y
        sta d_v+1
        iny
        lda (zp_t),y
        sta d_v+2
        iny
        lda (zp_t),y
        sta d_x
        lda fs_rel
        clc
        adc fs_n
        sta xs_j
        jsr x_ent
        ldy #0
        lda d_v
        sta (zp_t),y
        iny
        lda d_v+1
        sta (zp_t),y
        iny
        lda d_v+2
        sta (zp_t),y
        iny
        lda d_x
        sta (zp_t),y
        dec fs_rel
        jmp xgw_mv
xgw_write lda xs_lj
        sta xs_j
        lda xs_b               ; optional left gap
        ora xs_b+1
        beq xgw_alloc
        lda #0
        sta xs_s
        sta xs_s+1
        lda xs_b
        sta xs_c
        lda xs_b+1
        sta xs_c+1
        jsr xgw_put
        inc xs_j
xgw_alloc lda rn_dm
        sta xs_s
        lda rn_dm+1
        sta xs_s+1
        lda #1
        sta xs_c
        lda #0
        sta xs_c+1
        jsr xgw_put
        inc xs_j
        lda tr_need            ; optional right gap
        ora tr_need+1
        beq xgw_done
        lda #0
        sta xs_s
        sta xs_s+1
        lda tr_need
        sta xs_c
        lda tr_need+1
        sta xs_c+1
        jsr xgw_put
xgw_done jsr x_dirty
        lda rn_dm
        sta fs_sec
        lda rn_dm+1
        sta fs_sec+1
        lda #$FF
        sta fs_new
        clc
xgw_ret rts
xgw_put jsr x_ent
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
        rts
