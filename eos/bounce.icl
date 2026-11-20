* The FMS's bounce (included in dev.asm; it was in the DOS 2 bank)

zp_q    equ $45                ; as in fms.asm: the caller's buffer

* xbounce: the FMS's bounce, DBYT bytes between the cache buffer fs_x and
* fs_sbuf; C=1 cache to fs_sbuf, C=0 the other way
xbounce lda #0                 ; the direction
        rol @
        sta bo_dir
        ldx #3                 ; the callers' pointers stay as they are
xbo0     lda zp_q,x
        pha
        dex
        bpl xbo0
        ldx fs_x
        lda xbf_lo,x
        sta zp_t
        lda xbf_hi,x
        sta zp_t+1
        lda #<fs_sbuf
        sta zp_q
        lda #>fs_sbuf
        sta zp_q+1
        ldx DBYTHI             ; 128 bytes (DBYTHI 0), or whole pages
        bne xbo_pg
        ldy #127
        lda bo_dir
        beq xbo_i1
xbo_o1  lda (zp_t),y
        sta fs_sbuf,y
        dey
        bpl xbo_o1
        bmi xbo_ret
xbo_i1  lda fs_sbuf,y
        sta (zp_t),y
        dey
        bpl xbo_i1
        bmi xbo_ret
xbo_pg  ldy #0
        lda bo_dir
        beq xbo_i2
xbo_o2  lda (zp_t),y
        sta (zp_q),y
        iny
        bne xbo_o2
        inc zp_t+1
        inc zp_q+1
        dex
        bne xbo_o2
        beq xbo_ret
xbo_i2  lda (zp_q),y
        sta (zp_t),y
        iny
        bne xbo_i2
        inc zp_t+1
        inc zp_q+1
        dex
        bne xbo_i2
xbo_ret  ldx #0
xbo1     pla
        sta zp_q,x
        inx
        cpx #4
        bcc xbo1
        rts
