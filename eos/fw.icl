* ---- the byte window -----------------------------------------------------------
* CIO calls D:'s GET and PUT once for each byte (BASIC's PRINT, INPUT, GET
* and PUT). After the FMS has read or written one byte of a file, fw_set
* leaves its sector's next bytes in the cache to the kernel (kf_io): fw_h
* the handle (+$40 to write), kf_op LDA or STA of the next byte's address,
* fw_n how many. kf_io moves them with no bank changed; at the next call
* to the FMS (fw_wrap), a sector written or dropped (hd_hook, l2_drop) the
* window is settled first (fw_sync): the file's position (and its length,
* the byte in the sector on DOS 2) moves past the bytes it took.

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
        lda #0                 ; (NOTE and POINT: this call only)
        sta d_note
        lda fs_drv             ; the drive used, and when (mt_fresh)
        sta dm_d
        lda RTCLOK+1
        sta dm_t
        lda RTCLOK+2
        sta dm_t+1
        pla
        plp
        rts

* d_ppos: the DOS 2 bank's kd_pos (FCB fs_fcb). CIO's POINT (d_note bit
* 7): sector addpos, byte addpos+2 in it, as Atari DOS 2 has it: the
* sector read, its link taken; another file's sector (DOS 2's file
* number) 164, past its bytes 166.
d_ppos  bit d_note
        bmi pp0
        jmp d_bpos
pp0     lda addpos
        sta fs_sec
        lda addpos+1
        sta fs_sec+1
        jsr farcall
        dta b(BK_FMS),a(CARTLO+$03)
        bcs pp_r
        ldx fs_fcb
        jsr bp_y               ; the link after the data
        lda fc_flg,x           ; 16-bit links (MyDOS): no file number
        and #$04
        bne pp1
        lda (zp_p),y
        lsr @
        lsr @
        cmp fc_eplo,x
        beq pp1
        lda #164
pp_r    rts
pp1     iny
        iny
        lda (zp_p),y
        cmp addpos+2
        jcc bp_rng
        jsr bp_lk
        lda addpos
        sta fc_dmlo,x
        lda addpos+1
        sta fc_dmhi,x
        lda addpos+2
        sta fc_cblo,x
        lda #1                 ; (zp_p is the sector: fw_set)
        sta d_bpok
        lda #0
        sta d_wr
        lda #1
        rts

* d_bpos: kd_pos for FSEEK (d_note clear): from the file's start, along
* its sectors, to byte addpos: each sector's link read, its bytes skipped
* at once. 166 past the end.
d_bpos  ldx fs_fcb
        lda fc_maplo,x
        sta fc_cmlo,x
        lda fc_maphi,x
        sta fc_cmhi,x
        lda #0
        sta fc_pos0,x
        sta fc_pos1,x
        sta fc_pos2,x
        sta fc_cblo,x
        sta d_bpok
        sta d_wr
        lda #$FF
        sta fc_cbhi,x
bp1     ldx fs_fcb             ; d_v = addpos - the position
        sec
        lda addpos
        sbc fc_pos0,x
        sta d_v
        lda addpos+1
        sbc fc_pos1,x
        sta d_v+1
        lda addpos+2
        sbc fc_pos2,x
        ora d_v+1
        sta d_v+1              ; (not 0: 256 or more)
        ora d_v
        jeq bp_ok
        lda fc_cbhi,x          ; the bytes left in the sector in use
        cmp #$FF
        beq bp2
        sec
        sbc fc_cblo,x
        beq bp2
        bcc bp2
        ldy d_v+1              ; at most d_v
        bne bp3
        cmp d_v
        bcc bp3
        lda d_v
bp3     sta d_v
        clc
        adc fc_cblo,x
        sta fc_cblo,x
        clc
        lda fc_pos0,x
        adc d_v
        sta fc_pos0,x
        bcc bp1
        inc fc_pos1,x
        bne bp1
        inc fc_pos2,x
        jmp bp1
bp2     lda fc_cmlo,x          ; the next sector: its link
        ora fc_cmhi,x
        beq bp_rng
        lda fc_cmlo,x
        sta fs_sec
        sta fc_dmlo,x
        lda fc_cmhi,x
        sta fs_sec+1
        sta fc_dmhi,x
        jsr farcall
        dta b(BK_FMS),a(CARTLO+$03)
        bcs bp_r
        ldx fs_fcb
        jsr bp_y
        iny
        iny
        lda (zp_p),y
        jsr bp_lk
        lda #0
        sta fc_cblo,x
        jmp bp1
bp_ok   lda #1
        rts
bp_rng  lda #166
bp_r    rts
* bp_y: Y = the data bytes of a sector of fs_drv (125, 253): the link
bp_y    ldy fs_drv
        lda dv_szhi,y
        beq bpy1
        ldy #253
        rts
bpy1    ldy #125
        rts
* bp_lk: the link at zp_p+Y-2 (Y at its byte count, in A) to FCB X: its
* bytes (fc_cbhi), the next sector (fc_cmlo, hi)
bp_lk   sta fc_cbhi,x
        dey
        lda (zp_p),y
        sta fc_cmlo,x
        dey
        lda fc_flg,x           ; its high byte: all of it (16-bit) or 2 bits
        and #$04
        beq bpl1
        lda #$FF
bpl1    ora #$03
        and (zp_p),y
        sta fc_cmhi,x
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
fy4     ldy fc_drv,x
        lda dv_fs,y
        beq fy5
        cmp #3
        beq fy5
        clc                    ; DOS 2: the next byte in the sector
        lda fc_cblo,x
        adc d_x
        sta fc_cblo,x
        jmp fy_clr
fy5     bit fw_h               ; SDFS written past its end: longer
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
* the rest of the last sector. SDFS and EOSFS: zp_p ($43) is the address
* of the last fs_n bytes done, fs_off their offset (none after a whole
* sector written straight from the caller); the sector's last byte is
* left to the FMS (used_up), and a read stops at the file's end. DOS 2: zp_p is the
* sector (d_bpok), fc_cblo the next byte, fc_cbhi (read) or dbytes
* (written: 125 or 253) the end; not for a file open for update.
fw_set  cmp #$80
        bcs fs_r
        ldx fw_h               ; (a listing's window stays: dev.asm d_get)
        cpx #$FE
        beq fs_r
        lda rt_y               ; (2: POINT, on DOS 2 only, as a read)
        cmp #3
        bcs fs_r
        cmp #2
        beq fs_p
        lda bytbuf             ; (nothing done: none)
        ora bytbuf+1
        beq fs_r
fs_p    ldx fs_fcb
        ldy fs_drv
        lda dv_fs,y
        beq fs_sd0
        cmp #3
        beq fs_sd0
        lda fc_flg,x
        and #FL_UPD
        bne fs_r
        lda d_bpok
        beq fs_r
        lda rt_y               ; (0, 2: read)
        cmp #1
        beq fs_dw
        lda fc_cbhi,x
        jmp fs_d
fs_dw   lda dv_szhi,y          ; data bytes in a sector: 125 or 253
        beq fs_d0
        lda #253
        bne fs_d
fs_d0   lda #125
fs_d    sec
        sbc fc_cblo,x
        beq fs_r
        bcc fs_r
        sta fw_n
        clc
        lda $43
        adc fc_cblo,x
        sta kf_op+1
        lda $44
        adc #0
        sta kf_op+2
        jmp fs_h
fs_r    rts
fs_sd0  lda rt_y               ; (SDFS: not after a POINT)
        cmp #2
        beq fs_r
fs_sd   lda fs_sec             ; (a hole reads as zeros: no sector)
        ora fs_sec+1
        beq fs_r
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

