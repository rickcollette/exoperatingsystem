* E1: the second-level sector cache (included in dev.asm), one 16K
* extended bank on machines with more than 4 banks (boot.asm applyuse
* takes the top free one: l2_pb, its PORTB value with the OS ROM off; 0
* none). A sector the FMS's cache drops (victim, written first when it was
* changed) is kept here; a sector the FMS's cache misses is looked for
* here before the disk (getsec). Exclusive: a sector found here leaves it
* for the FMS's cache, so it is in one place only. A drive dropped (another
* disk, jblock_io) is dropped here too; a sector written past the cache
* (xdirect) as well.
*
* In the bank: $4000 the drives ($FF free), $4020 and $4040 the sectors,
* $4060 the stamps, $40FF the stamp counter; slot n at $4200 + n * 512.
* The PORTB switch is made with the interrupts off, as the RAM disk's.

zp_p    equ $43                ; as in fms.asm: the FMS's sector buffer
zp_t    equ $47

L2_N    equ 31
L2_D    equ $4000
L2_SL   equ $4020
L2_SH   equ $4040
L2_ST   equ $4060
L2_CT   equ $40FF

* L2_IN, L2_OUT: the bank in (the caller's P and PORTB on the stack, the
* interrupts off) and out again
.macro L2_IN
        php
        sei
        lda PORTB
        pha
        lda l2_pb
        sta PORTB
.endm
.macro L2_OUT
        pla
        sta PORTB
        plp
.endm

* l2_get: the sector of buffer X (bf_drv, bf_sec: getsec set them) from
* here into it: C=0; C=1 not here. Keeps X.
l2_get  lda l2_pb
        bne lg0
lg_no   sec
        rts
lg0     stx l2_x
        jsr l2_find
        bcs lg_no
        sty l2_y
        lda #0                 ; from the slot
        sta l2_dir
        jsr l2_cpy
        L2_IN              ; it leaves
        ldy l2_y
        lda #$FF
        sta L2_D,y
        L2_OUT
        ldx l2_x
        clc
        rts

* l2_find: Y = the slot of buffer X's sector, C=0; C=1 none. Keeps X.
l2_find L2_IN
        ldy #L2_N-1
lf1     lda L2_D,y
        cmp bf_drv,x
        bne lf2
        lda L2_SL,y
        cmp bf_seclo,x
        bne lf2
        lda L2_SH,y
        cmp bf_sechi,x
        beq lf3
lf2     dey
        bpl lf1
        L2_OUT
        sec
        rts
lf3     L2_OUT
        clc
        rts

* l2_put: buffer X's sector here (the FMS's victim), unless the FMS marked
* it used up (age $FF); keeps X. Its old copy
* here, if any, is the slot; else a free one; else the oldest.
l2_put  lda l2_pb
        jeq lp_r
        lda bf_drv,x
        jmi lp_r
        lda bf_age,x           ; a data sector read or written to its end
        cmp #$FF               ; (the FMS's used_up: a file streaming
        jeq lp_r               ; through) is not kept: it would only cost
        stx l2_x
        jsr l2_find
        bcc lp3
        L2_IN
        lda #0                 ; the oldest so far: its age, its slot
        sta l2_age
        sta l2_y
        ldy #L2_N-1
lp1     lda L2_D,y
        bmi lp_free
        sec
        lda L2_CT
        sbc L2_ST,y
        cmp l2_age
        bcc lp2
        sta l2_age
        sty l2_y
lp2     dey
        bpl lp1
        bmi lp4
lp_free sty l2_y
lp4     L2_OUT
        ldy l2_y
lp3     sty l2_y
        L2_IN
        ldx l2_x
        ldy l2_y
        lda bf_drv,x
        sta L2_D,y
        lda bf_seclo,x
        sta L2_SL,y
        lda bf_sechi,x
        sta L2_SH,y
        inc L2_CT
        lda L2_CT
        sta L2_ST,y
        L2_OUT
        lda #1                 ; to the slot
        sta l2_dir
        jsr l2_cpy
        ldx l2_x
lp_r    rts

* l2_drop: drive fs_drv's sectors leave (keeps A: drop_but's); l2_drop1:
* sector fs_sec of it only
l2_drop jsr fw_keep           ; sectors dropped: the byte window first
        pha
        lda #$FF               ; (and mount looks at the disk again: mt_fresh)
        sta dm_d
        lda #0
        beq ld0
l2_drop1 pha
        lda #1
ld0     sta l2_dir
        lda l2_pb
        beq ld_r
        L2_IN
        ldy #L2_N-1
ld1     lda L2_D,y
        cmp fs_drv
        bne ld2
        lda l2_dir
        beq ld1a
        lda L2_SL,y
        cmp fs_sec
        bne ld2
        lda L2_SH,y
        cmp fs_sec+1
        bne ld2
ld1a    lda #$FF
        sta L2_D,y
ld2     dey
        bpl ld1
        L2_OUT
ld_r    pla
        rts

* l2_init: nothing kept (boot.asm, when it takes the bank)
l2_init lda l2_pb
        beq li_r
        L2_IN
        ldy #L2_N-1
        lda #$FF
li1     sta L2_D,y
        dey
        bpl li1
        lda #0
        sta L2_CT
        L2_OUT
li_r    rts

* l2_cpy: buffer X's bytes (its drive's sector size, 256 for 128) between
* it and slot l2_y: l2_dir 1 to the slot, 0 from it. Keeps X.
l2_cpy  lda zp_p
        pha
        lda zp_p+1
        pha
        lda zp_t
        pha
        lda zp_t+1
        pha
        lda xbf_lo,x
        sta zp_p
        lda xbf_hi,x
        sta zp_p+1
        lda #0
        sta zp_t
        lda l2_y
        asl @
        clc
        adc #>$4200
        sta zp_t+1
        ldy bf_drv,x           ; pages: 2 for 512-byte sectors, else 1
        lda dv_szhi,y
        lsr @
        clc
        adc #1
        sta l2_age
        stx l2_x
        L2_IN
        ldy #0
lc1     lda l2_dir
        bne lc2
        lda (zp_t),y
        sta (zp_p),y
        jmp lc3
lc2     lda (zp_p),y
        sta (zp_t),y
lc3     iny
        bne lc1
        inc zp_p+1
        inc zp_t+1
        dec l2_age
        bne lc1
        L2_OUT
        ldx l2_x
        pla
        sta zp_t+1
        pla
        sta zp_t
        pla
        sta zp_p+1
        pla
        sta zp_p
        rts
