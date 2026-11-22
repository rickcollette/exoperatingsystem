* ---- the byte window -----------------------------------------------------------
* CIO calls D:'s GET and PUT once for each byte (BASIC's PRINT, INPUT, GET
* and PUT). After the FMS has read or written one byte of a file, fw_set
* leaves its sector's next bytes in the cache to the kernel (kf_io): fw_h
* the handle (+$40 to write), kf_op LDA or STA of the next byte's address,
* fw_n how many. kf_io moves them with no bank changed; at the next call
* to the FMS (fw_wrap), a sector written or dropped (hd_hook, l2_drop) the
* window is settled first (fw_sync): the file's position and, for a write,
* its length move past the bytes it took.

* fw_wrap (the FMS's dsk_entry, ROM off): route (Y the function) between
* fw_sync and fw_set; A, X, Y and the flags come back from route
fw_wrap sty rt_y
        jsr fw_sync
        ldy rt_y
        jsr farcall
        dta b(BK_FMS),a(CARTLO+$1B)
        php
        pha
        jsr fw_set
        lda fs_drv             ; the drive used, and when (mt_fresh)
        sta dm_d
        lda RTCLOK+1
        sta dm_t
        lda RTCLOK+2
        sta dm_t+1
        pla
        plp
        rts

* mt_fresh: (the FMS's mount) drive fs_drv mounted and used less than a
* second ago (fw_wrap; nothing dropped since: l2_drop): C=0, no disk can
* have been changed in it meanwhile; else C=1, the disk is looked at again
mt_fresh ldx fs_drv
        cpx dm_d
        bne mf_no
        lda dv_szlo,x
        ora dv_szhi,x
        beq mf_no
        sec
        lda RTCLOK+2
        sbc dm_t+1
        tay
        lda RTCLOK+1
        sbc dm_t
        bne mf_no
        cpy #60                ; (C=0 below 60 frames)
        rts
mf_no   sec
        rts

* fw_keep: fw_sync keeping A, X, Y
fw_keep bit fw_h
        bmi fk_r
        pha
        txa
        pha
        tya
        pha
        jsr fw_sync
        pla
        tay
        pla
        tax
        pla
fk_r    rts

* fw_sync: the window's bytes to its file, then no window
fw_sync lda fw_h
        jmi fy_r
        and #$0F
        sta d_x
        ldx #NFCB-1
fy1     lda fc_drv,x
        bmi fy2
        lda fc_hnd,x
        cmp d_x
        beq fy3
fy2     dex
        bpl fy1
        bmi fy_clr
fy3     sec                    ; the bytes taken
        lda kf_op+1
        sbc fw_s
        sta d_x
        clc
        adc fc_pos0,x
        sta fc_pos0,x
        bcc fy4
        inc fc_pos1,x
        bne fy4
        inc fc_pos2,x
fy4     bit fw_h               ; EOSFS written past its end: longer
        bvc fy_clr
        lda fc_len0,x
        cmp fc_pos0,x
        lda fc_len1,x
        sbc fc_pos1,x
        lda fc_len2,x
        sbc fc_pos2,x
        bcs fy_clr
        lda fc_pos0,x
        sta fc_len0,x
        lda fc_pos1,x
        sta fc_len1,x
        lda fc_pos2,x
        sta fc_len2,x
fy_clr  lda #$FF
        sta fw_h
        lda #0
        sta fw_n
fy_r    rts

* fw_set: after a read or write (rt_y 0, 1), status A: the window over
* the rest of the last EOSFS sector. zp_p ($43) is the address
* of the last fs_n bytes done, fs_off their offset (none after a whole
* sector written straight from the caller); the sector's last byte is
* left to the FMS (used_up), and a read stops at the file's end.
fw_set  cmp #$80
        jcs fs_r
        ldx fw_h               ; (a listing's window stays: dev.asm d_get)
        cpx #$FE
        jeq fs_r
        lda rt_y
        cmp #3
        jcs fs_r
        cmp #2
        beq fs_p
        lda bytbuf             ; (nothing done: none)
        ora bytbuf+1
        jeq fs_r
fs_p    ldx fs_fcb
        ldy fs_drv
        lda rt_y               ; no byte window after POINT
        cmp #2
        jeq fs_r
        lda fs_sec             ; (a hole reads as zeros: no sector)
        ora fs_sec+1
        jeq fs_r
        sec                    ; the bytes after the last fs_n done (at
        lda dv_szlo,y          ; fs_off) but the sector's last one
        sbc fs_off
        sta d_t
        lda dv_szhi,y
        sbc fs_off+1
        sta d_t+1
        sec
        lda d_t
        sbc fs_n
        sta d_t
        lda d_t+1
        sbc fs_n+1
        sta d_t+1
        lda d_t
        sbc #1                 ; (C=1 unless negative: then bmi below)
        sta d_t
        bcs fs_s1
        dec d_t+1
fs_s1   lda d_t+1
        bmi fs_r
        beq fs_s2
        lda #$FF
        sta d_t
fs_s2   lda d_t
        beq fs_r
        lda rt_y               ; read: not past the end
        bne fs_s3
        sec
        lda fc_len0,x
        sbc fc_pos0,x
        sta d_t+1
        lda fc_len1,x
        sbc fc_pos1,x
        bne fs_s3
        lda fc_len2,x
        sbc fc_pos2,x
        bne fs_s3
        lda d_t+1
        beq fs_r
        cmp d_t
        bcs fs_s3
        sta d_t
fs_s3   lda d_t
        sta fw_n
        clc
        lda $43
        adc fs_n
        sta kf_op+1
        lda $44
        adc fs_n+1
        sta kf_op+2
fs_h    lda kf_op+1
        sta fw_s
        lda fc_hnd,x
        ldy rt_y               ; (0, 2: read)
        cpy #1
        bne fs_h2
        ora #$40               ; written: STA abs
        ldy #$8D
        bne fs_h3
fs_h2   ldy #$AD               ; read: LDA abs
fs_h3   sty kf_op
        sta fw_h
        rts
fs_r    rts

