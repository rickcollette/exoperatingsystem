* ---- EOSFS directory name index (docs/EOSFS.md 3.3; included in dos2.asm,
* called from the FMS bank). A directory whose header has $FF at +22 (its
* time's seconds) has an index: a file (extent list at header +20) with
* one byte per entry slot, the hash of the entry's name (1-255), 0 for a
* free or deleted slot. The FMS keeps the header's +20..22 in ix_m/ix_f at
* open_dir.

IX_USED equ $08                ; directory entry status bits
IX_DEL  equ $10

* ix_find: from entry ix_k on, the first whose index byte is ix_h, up to the
* directory's end (the internal FCB's length): C=0, ix_k = it; C=1 none
ix_find jsr ix_cnt
if1     lda ix_k
        cmp ix_n
        lda ix_k+1
        sbc ix_n+1
        bcs if_no
        jsr ix_byte
        bcs if_no
        cmp ix_h
        beq if_yes
        inc ix_k
        bne if1
        inc ix_k+1
        bne if1
if_no   sec
        rts
if_yes  lda ix_k                ; ix_p: its position, k * 23 (16 + 4 + 2 + 1)
        sta ix_t
        sta ix_p
        lda ix_k+1
        sta ix_t+1
        sta ix_p+1
        jsr ip_add2            ; + 2k
        jsr ip_add2            ; + 4k
        asl ix_t               ; + 16k
        rol ix_t+1
        jsr ip_add2
        clc
        rts
ip_add2 asl ix_t
        rol ix_t+1
        clc
        lda ix_p
        adc ix_t
        sta ix_p
        lda ix_p+1
        adc ix_t+1
        sta ix_p+1
        rts

* ix_cnt: ix_n = the internal FCB's length / 23 (the slots)
ix_cnt  lda fc_len0+NFCB
        sta ix_t
        lda fc_len1+NFCB
        sta ix_t+1
        lda #0
        sta ix_n
        sta ix_n+1
ic1     lda ix_t
        sec
        sbc #23
        tax
        lda ix_t+1
        sbc #0
        bcc ic2
        stx ix_t
        sta ix_t+1
        inc ix_n
        bne ic1
        inc ix_n+1
        bne ic1
ic2     rts

* ix_byte: A = index byte ix_k (0 past the index's sectors); C=1 error
ix_byte jsr ix_sec
        bcs ib_ret
        lda ix_cs
        ora ix_cs+1
        beq ib_0
        lda ix_cs
        sta fs_sec
        lda ix_cs+1
        sta fs_sec+1
        jsr getsec
        bcs ib_ret
        jsr ix_off
        lda (zp_t),y
        clc
ib_ret  rts
ib_0    lda #0
        clc
        rts

* ix_off: zp_t = zp_p + the byte's offset in its sector (high part), Y = the
* low part
ix_off  ldy fs_drv             ; offset = ix_k mod sector size
        lda dv_shf,y
        tax
        lda zp_p
        sta zp_t
        lda zp_p+1
        sta zp_t+1
        lda ix_k+1             ; 512 bytes: bit 0 of the high byte too
        cpx #9
        bne io1
        and #1
        clc
        adc zp_t+1
        sta zp_t+1
io1     ldy ix_k
        cpx #7                 ; 128 bytes: the low 7 bits
        bne io2
        tya
        and #$7F
        tay
io2     rts

* ix_sec: ix_cs = the sector holding index byte ix_k (0: past the list or a
* gap); the last one found is kept (ix_csi). C=1 error
ix_sec  jsr ix_si              ; ix_t = the sector index
        lda ix_t
        cmp ix_csi
        bne is0
        lda ix_t+1
        cmp ix_csi+1
        bne is0
        clc
        rts
is0     lda ix_t
        sta ix_csi
        lda ix_t+1
        sta ix_csi+1
        lda #0
        sta ix_cs
        sta ix_cs+1
        lda ix_m               ; the list from its first sector
        sta ix_l
        lda ix_m+1
        sta ix_l+1
is1     lda ix_l
        ora ix_l+1
        jeq is_ok              ; past the list: 0
        lda ix_l
        sta fs_sec
        lda ix_l+1
        sta fs_sec+1
        jsr getsec
        jcs is_ret
        lda #0
        sta xs_j
is2     jsr x_ent              ; zp_t: extent xs_j
        jsr ix_xmax
        bcs is_nxt
        ldy #2                 ; its count: 0 ends the list
        lda (zp_t),y
        iny
        ora (zp_t),y
        jeq is_ok
        ldy #3                 ; ix_t < count: in this one
        lda ix_t+1
        cmp (zp_t),y
        bcc is_in
        bne is3
        dey
        lda ix_t
        cmp (zp_t),y
        bcc is_in
is3     ldy #2                 ; ix_t -= count
        sec
        lda ix_t
        sbc (zp_t),y
        sta ix_t
        iny
        lda ix_t+1
        sbc (zp_t),y
        sta ix_t+1
        inc xs_j
        jmp is2
is_nxt  ldy #0                 ; the next list sector
        lda (zp_p),y
        sta ix_l
        iny
        lda (zp_p),y
        sta ix_l+1
        jmp is1
is_in   ldy #0                 ; start + ix_t (a gap: 0)
        lda (zp_t),y
        iny
        ora (zp_t),y
        jeq is_ok
        dey
        clc
        lda (zp_t),y
        adc ix_t
        sta ix_cs
        iny
        lda (zp_t),y
        adc ix_t+1
        sta ix_cs+1
is_ok   clc
is_ret  rts

* ix_xmax: C=1 when xs_j is past the extents a list sector holds
* ((size - 4) / 4: 31, 63, 127)
ix_xmax ldy fs_drv
        lda dv_shf,y
        tay
        lda #31
        cpy #7
        beq ix1
        lda #63
        cpy #8
        beq ix1
        lda #127
ix1     cmp xs_j
        beq ix2
        bcs ix3
ix2     sec
        rts
ix3     clc
        rts

* ix_si: ix_t = ix_k / the sector size
ix_si   lda ix_k
        sta ix_t
        lda ix_k+1
        sta ix_t+1
        ldy fs_drv
        lda dv_shf,y
        tax
isi1    lsr ix_t+1
        ror ix_t
        dex
        bne isi1
        rts

* ix_set: the index byte of the entry at ix_p (a position: / 23 is the
* slot) for the entry fs_ent2 (its hash, or 0 when it is not in use);
* sectors added to the index as the directory grows. Only on EOSFS, in a
* directory with an index, not for the header (ix_p 0). C=1, A = status.
ix_set  jsr ix_here
        bne iss_no
        lda ix_p
        ora ix_p+1
        beq iss_no
        jsr ix_div             ; ix_k = ix_p / 23
        lda fs_ent2
        and #IX_USED|IX_DEL
        cmp #IX_USED
        beq iss1
        lda #0
        beq iss2
iss1    ldx #0                 ; the hash of fs_ent2+6..16
        jsr ix_hash
iss2    sta ix_v
        lda #$FF               ; (the sector index found anew)
        sta ix_csi
        sta ix_csi+1
        jsr ix_sec
        bcs iss_ret
        lda ix_cs
        ora ix_cs+1
        bne iss3
        jsr ix_grow            ; not there yet: a sector more
        bcs iss_ret
iss3    lda ix_cs
        sta fs_sec
        lda ix_cs+1
        sta fs_sec+1
        jsr getsec
        bcs iss_ret
        stx ix_b               ; (its buffer: ix_off uses X)
        jsr ix_off
        lda ix_v
        sta (zp_t),y
        ldx ix_b
        jsr dirty
iss_no  clc
iss_ret rts

* ix_here: Z=1 when drive fs_drv is EOSFS and the directory open_dir read
* has an index
ix_here ldy fs_drv
        lda dv_fs,y
        cmp #3
        bne ih_r
        lda ix_f
        cmp #$FF
ih_r    rts

* ix_div: ix_k = ix_p / 23
ix_div  lda ix_p
        sta ix_t
        lda ix_p+1
        sta ix_t+1
        lda #0
        sta ix_k
        sta ix_k+1
id1     lda ix_t
        sec
        sbc #23
        tax
        lda ix_t+1
        sbc #0
        bcc id2
        stx ix_t
        sta ix_t+1
        inc ix_k
        bne id1
        inc ix_k+1
        bne id1
id2     rts

* ix_hash: A = the hash of the 11 name bytes at fs_ent2+6 (X=0) or fs_pat
* (X=1): rotate left, exclusive or; 0 becomes 1
ix_hash ldy #0
        sty ix_t
ih1     lda ix_t
        asl @
        adc #0                 ; (the bit out goes in at the right)
        sta ix_t
        txa
        beq ih2
        lda fs_pat,y
        jmp ih3
ih2     lda fs_ent2+6,y
ih3     eor ix_t
        sta ix_t
        iny
        cpy #11
        bcc ih1
        lda ix_t
        bne ih4
        lda #1
ih4     rts
ix_hpat ldx #1                 ; (the pattern's, for ix_find)
        jsr ix_hash
        sta ix_h
        rts

* ix_grow: a new, zeroed sector at the index's end (the last extent grows
* when the sector after it is free, else a new extent in the last list
* sector): ix_cs = it. C=1, A = status (a full list: 162).
ix_grow lda ix_m               ; the last list sector
        sta ix_l
        lda ix_m+1
        sta ix_l+1
ig1     lda ix_l
        sta fs_sec
        lda ix_l+1
        sta fs_sec+1
        jsr getsec
        jcs ig_ret
        ldy #0
        lda (zp_p),y
        iny
        ora (zp_p),y
        beq ig2
        dey
        lda (zp_p),y
        tax
        iny
        lda (zp_p),y
        sta ix_l+1
        stx ix_l
        jmp ig1
ig2     jsr xalloc              ; the new sector
        jcs ig_ret
        lda al_s
        sta ix_cs
        sta fs_sec
        lda al_s+1
        sta ix_cs+1
        sta fs_sec+1
        jsr newsec
        jcs ig_ret
        jsr dirty
        lda ix_l               ; the list sector again
        sta fs_sec
        lda ix_l+1
        sta fs_sec+1
        jsr getsec
        jcs ig_ret
        lda #0                 ; its last extent
        sta xs_j
ig3     jsr ix_xmax
        jcs ig_full
        jsr x_ent
        ldy #2
        lda (zp_t),y
        iny
        ora (zp_t),y
        beq ig4
        inc xs_j
        jmp ig3
ig4     lda xs_j               ; extent xs_j is free: grow the one before?
        beq ig_new
        dec xs_j
        jsr x_ent
        ldy #0                 ; start + count = the new sector?
        clc
        lda (zp_t),y
        ldy #2
        adc (zp_t),y
        sta ix_t
        ldy #1
        lda (zp_t),y
        ldy #3
        adc (zp_t),y
        cmp ix_cs+1
        bne ig5
        lda ix_t
        cmp ix_cs
        bne ig5
        ldy #2                 ; yes: one more
        lda (zp_t),y
        clc
        adc #1
        sta (zp_t),y
        iny
        lda (zp_t),y
        adc #0
        sta (zp_t),y
        jmp ig_ok
ig5     inc xs_j
ig_new  jsr ix_xmax            ; a new extent of one sector
        jcs ig_full
        jsr x_ent
        ldy #0
        lda ix_cs
        sta (zp_t),y
        iny
        lda ix_cs+1
        sta (zp_t),y
        iny
        lda #1
        sta (zp_t),y
        iny
        lda #0
        sta (zp_t),y
ig_ok   jsr dirty
        clc
ig_ret  rts
ig_full lda #E_FULL
        sec
        rts

* ix_new: MKDIR on EOSFS: a new, empty index list sector: ix_cs = it (0
* elsewhere). C=1, A = status
ix_new  lda #0
        sta ix_cs
        sta ix_cs+1
        ldy fs_drv
        lda dv_fs,y
        cmp #3
        bne in_no
        jsr xalloc
        jcs in_ret
        lda al_s
        sta fs_sec
        lda al_s+1
        sta fs_sec+1
        jsr newsec
        jcs in_ret
        jsr dirty
        lda al_s
        sta ix_cs
        lda al_s+1
        sta ix_cs+1
in_no   clc
in_ret  rts

* ix_free: RMDIR on EOSFS: the directory's index sectors free (open_dir
* read its header). C=1, A = status
ix_free jsr ix_here
        bne in_no
        lda ix_m
        sta tr_m
        lda ix_m+1
        sta tr_m+1
        jmp free_x

* ix_look: the FMS's lookup through the index (scan_name, find_dir): fs_pat
* and fs_scn, the internal FCB on the directory (open_dir done). C=0 found
* (fs_ent, the FCB past it); C=1, A = status (E_EOF none). V=1: no index
* here, scan as before.
ix_look jsr ix_here            ; an index, and no wildcards?
        bne il_scan
        ldy #10
il0     lda fs_pat,y
        cmp #'?'
        beq il_scan
        dey
        bpl il0
        jsr ix_hpat
        lda #$FF               ; (no index sector known yet)
        sta ix_csi
        sta ix_csi+1
        lda #1
        sta ix_k
        lda #0
        sta ix_k+1
        beq il1
* ix_cont: the one found was not it (a hash shared): on after it
ix_cont inc ix_k
        bne il1
        inc ix_k+1
il1     jsr ix_find
        bcs il_none
        lda ix_p               ; the entry: the FCB there, read, compared
        sta fc_pos0+NFCB
        lda ix_p+1
        sta fc_pos1+NFCB
        lda #0
        sta fc_pos2+NFCB
        clv
        clc
        rts                    ; (C=0, V=0: the FMS reads and checks it)
il_none lda #E_EOF
        clv
        sec
        rts
il_scan bit il_v               ; V=1
        rts
il_v    dta b($40)

* ix_drop: a directory written raw (mode $1C; its FCB X) on EOSFS: its
* index (now out of date) goes: its sectors free, the header's +22 0, so
* lookups scan it. Keeps X. C=1, A = status
ix_drop stx ix_b
        lda fc_drv,x
        sta fs_drv
        tay
        lda dv_fs,y
        cmp #3
        bne id_ok
        lda fc_maplo,x         ; the first extent's start: the header's sector
        sta fs_sec
        lda fc_maphi,x
        sta fs_sec+1
        jsr getsec
        bcs id_ret
        ldy #4
        lda (zp_p),y
        tax
        iny
        lda (zp_p),y
        sta fs_sec+1
        stx fs_sec
        jsr getsec
        bcs id_ret
        ldy #22
        lda (zp_p),y
        cmp #$FF
        bne id_ok
        lda #0                 ; no index from now on
        sta (zp_p),y
        dey
        lda (zp_p),y
        sta tr_m+1
        dey
        lda (zp_p),y
        sta tr_m
        jsr dirty
        jsr free_x
        bcs id_ret
id_ok   clc
id_ret  ldx ix_b
        rts
