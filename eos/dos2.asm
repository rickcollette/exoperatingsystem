* EOS (Extendable Operating System): bank 7, the Atari DOS 2 file system
*
* Disks written by Atari DOS 2.0S / 2.5 and MyDOS on DSK:, recognised by
* the FMS (d2_det, called from mount) when sector 1 is not SDFS. The FMS routes every
* call for such a drive here (route), with the ROM off, fs_drv set and the
* drive mounted; sectors come from its cache (getsec). The disk format is
* the documented Atari DOS 2 one: VTOC at sector 360, directory at 361-368
* (8 entries of 16 bytes per sector), data sectors ending in a link (file
* number, next sector, byte count). As SDX's ATARIDOS.SYS shows them
* (PROGRESS.md B9): a file's length is its sector count times the data
* bytes per sector, entries have no date, the volume is "DOS 2.0".
*
* Reading and writing (SDX's ATARIDOS.SYS only reads: what EOS writes is
* checked with tools/dos2.py and read back by SDX). DOS 2.5's enhanced
* density VTOC2 (sector 1024: bitmap of sectors 48-1023, free count of
* those above 719 at 122) is kept as DOS 2.5 keeps it.

        icl 'equ.icl'
        icl 'kernel.icl'

        opt h-f+

zp_p    equ $43                ; as in fms.asm: sector buffer
zp_q    equ $45                ; caller's buffer
zp_t    equ $47

E_OK    equ 1
E_NOTOPEN equ 133
E_EOF   equ 136
E_NOFUNC equ 146
E_RANGE equ 166
E_NOTFOUND equ 170
E_RDONLY equ 135
E_EXISTS equ 151
E_FULL  equ 162
E_WILD  equ 163
E_DIRFULL equ 169
E_PATH  equ 150
E_NOTEMPTY equ 167

FMS_GETSEC equ CARTLO+$03
FMS_NEWFCB equ CARTLO+$06
FMS_FINDFCB equ CARTLO+$09
FMS_FLUSH equ CARTLO+$0C
FMS_NEWSEC equ CARTLO+$0F
FMS_FREESEC equ CARTLO+$12
FMS_ALLOC equ CARTLO+$18

        org CARTLO
        jmp d2_entry           ; $A000 from the FMS (route)
        jmp free_x             ; $A003 EOSFS: free a file's extents (dos2x.icl)
        jmp trim_x             ; $A006 EOSFS: trim a written file
        jmp d2_det             ; $A009 mount: an Atari DOS 2 disk?
        jmp ix_look            ; $A00C EOSFS directory index (dos2i.icl)
        jmp ix_cont            ; $A00F
        jmp ix_set             ; $A012
        jmp ix_new             ; $A015
        jmp ix_free            ; $A018
        jmp ix_drop            ; $A01B
        jmp mn_rest            ; $A01E the FMS's mount: the volume header's fields
        rts                    ; $A021 (the FMS's bounce: dev.asm xbounce)
        dta b(0,0)
        jmp xdirect            ; $A024 the FMS's whole new sector, no cache
        jmp xcopyw             ; $A027 the FMS's copy_w
        jmp hd_hook            ; $A02A the FMS's wr_buf: EOSFS's dirty flag
        jmp xd_drop            ; $A02D the FMS's mount: sector fs_sec dropped

d2_entry lda d2_hi,y
        pha
        lda d2_lo,y
        pha
        rts
d2_nofn lda #E_NOFUNC
        rts
d2_ro   lda #E_RDONLY          ; directories on an Atari DOS 2 disk
        rts
* 0 read 1 write 2 pos 3 gtpos 4 gtlen 5 - 6 next 7 close 8 initz 9 open
* 10 first 11 rename 12 delete 13 setatr 14 credir 15 deldir 16 chdir
* 17 cwd 18 boot 19 check 20 chvol
d2_lo   dta l(d_read-1,d_write-1,d_pos-1,d_gtpos-1,d_gtlen-1,d2_nofn-1,d_next-1)
        dta l(d_close-1,d2_nofn-1,d_open-1,d_first-1,d_rename-1,d_delete-1)
        dta l(d_setatr-1,d_credir-1,d_deldir-1,d_chdir-1,d_cwd-1,d2_ro-1)
        dta l(d_check-1,d2_ro-1)
d2_hi   dta h(d_read-1,d_write-1,d_pos-1,d_gtpos-1,d_gtlen-1,d2_nofn-1,d_next-1)
        dta h(d_close-1,d2_nofn-1,d_open-1,d_first-1,d_rename-1,d_delete-1)
        dta h(d_setatr-1,d_credir-1,d_deldir-1,d_chdir-1,d_cwd-1,d2_ro-1)
        dta h(d_check-1,d2_ro-1)

* ---- the FMS's helpers ---------------------------------------------------------
* d2_det: an Atari DOS 2 / 2.5 / MyDOS disk in drive fs_drv? Its VTOC
* (sector 360, read as 128 bytes, else 256) starts with 2-9. C=0: dv_fs 1,
* sector size, total and free sectors set; C=1 not one
d2_det  ldx fs_drv
        lda #$80
        sta dv_szlo,x
        lda #0
        sta dv_szhi,x
        lda #<360
        sta fs_sec
        lda #>360
        sta fs_sec+1
        jsr getsec
        bcc d2c
        cmp #138               ; no drive
        beq d2_no
        ldx fs_drv
        lda #0
        sta dv_szlo,x
        lda #1
        sta dv_szhi,x
        jsr getsec
        bcs d2_no
d2c     ldy #0
        lda (zp_p),y
        cmp #2
        bcc d2_no
        cmp #10
        bcs d2_no
        ldx fs_drv
        cmp #3                 ; code 3 and up: MyDOS (2), else DOS 2 (1)
        lda #1
        adc #0
        sta dv_fs,x
        lda #7                 ; 128 or 256 bytes
        ldy dv_szhi,x
        beq d2c1
        lda #8
d2c1    sta dv_shf,x
        ldy #1
        lda (zp_p),y
        sta dv_totlo,x
        iny
        lda (zp_p),y
        sta dv_tothi,x
        iny
        lda (zp_p),y
        sta dv_freelo,x
        iny
        lda (zp_p),y
        sta dv_freehi,x
        lda #0
        sta dv_hdirty,x
        clc
        rts
d2_no   sec
        rts

getsec  ldx d_hint             ; sector fs_sec of fs_drv: zp_p, X; C=1
        cpx #NBUF              ; error. The one asked for last (the VTOC)
        bcs gs_far             ; again: no call to the FMS
        lda bf_drv,x
        cmp fs_drv
        bne gs_far
        lda bf_seclo,x
        cmp fs_sec
        bne gs_far
        lda bf_sechi,x
        cmp fs_sec+1
        bne gs_far
        lda xbf_lo,x
        sta zp_p
        lda xbf_hi,x
        sta zp_p+1
        clc
        rts
gs_far  jsr farcall
        dta b(BK_FMS),a(FMS_GETSEC)
        bcs gs_r
        stx d_hint
gs_r    rts
new_fcb jsr farcall
        dta b(BK_FMS),a(FMS_NEWFCB)
        rts
find_fcb jsr farcall
        dta b(BK_FMS),a(FMS_FINDFCB)
        rts
flush   jsr farcall            ; the drive's changed sectors to the disk
        dta b(BK_FMS),a(FMS_FLUSH)
        rts
newsec  jsr farcall            ; sector fs_sec, zeros, to be written
        dta b(BK_FMS),a(FMS_NEWSEC)
        rts
newsecn sec                    ; the same, not zeroed (all of it is written:
        jsr farcall            ; a file's data sector)
        dta b(BK_FMS),a(CARTLO+$1E)
        rts
xalloc  jsr farcall            ; (EOSFS) a free sector to al_s
        dta b(BK_FMS),a(FMS_ALLOC)
        rts
* dirty: the cache buffer X is to be written
dirty   lda #$FF
        sta bf_dirty,x
        rts

* dbytes: A = data bytes per sector of fs_drv (125 or 253); keeps X, Y
dbytes  stx d_x
        ldx fs_drv
        lda dv_szhi,x
        ldx d_x
        cmp #0
        beq db1
        lda #253
        rts
db1     lda #125
        rts

* ---- the directory -------------------------------------------------------------
* direntry: entry d_ent (0-63) of the directory: C=0, zp_p+Y its 16 bytes;
* C=1 error
direntry lda d_ent             ; (the directory starts at d_base)
        lsr @
        lsr @
        lsr @
        clc
        adc d_base
        sta fs_sec
        lda d_base+1
        adc #0
        sta fs_sec+1
        jsr getsec
        bcs de_ret
        stx d_buf              ; (to mark it changed)
        lda d_ent
        and #7
        asl @
        asl @
        asl @
        asl @
        tay
        clc
de_ret  rts

* d_match: entry at zp_p+Y in use and matching the pattern at d_pat with
* attributes scan? C=0 yes, dentry filled. Keeps Y.
d_match lda (zp_p),y
        bmi dm_no              ; deleted
        sta d_raw
        and #$10               ; a MyDOS directory ($10, as MyDOS writes
        beq dm_f               ; it): not on a DOS 2 disk
        jsr is_my
        beq dm_no
        bne dm0
dm_f    lda d_raw
        and #$40
        beq dm_no              ; not in use
dm0     sty d_y
        tya                    ; its name, from the start (? matches any
        ora #5                 ; character): in the sector, no copy
        tay
        ldx #0
dm2     lda d_pat,x
        cmp #'?'
        beq dm3
        cmp (zp_p),y
        bne dm_nr
dm3     iny
        inx
        cpx #11
        bcc dm2
        ldy d_y
        jsr mkdent
        lda dentry
        jsr attrok
        ldy d_y
        rts
dm_nr   ldy d_y
dm_no   sec
        rts

* mkdent: dentry from the entry at zp_p+Y: status ($08 in use, $01
* protected when locked), first sector as map, length = sectors x data
* bytes, name, no date
mkdent  lda (zp_p),y
        and #$20               ; locked
        lsr @
        lsr @
        lsr @
        lsr @
        lsr @
        ora #$08
        sta dentry
        lda d_raw              ; a MyDOS directory
        and #$10
        asl @
        ora dentry
        sta dentry
        iny                    ; sector count
        lda (zp_p),y
        sta d_v
        iny
        lda (zp_p),y
        sta d_v+1
        iny                    ; first sector
        lda (zp_p),y
        sta dentry+1
        iny
        lda (zp_p),y
        sta dentry+2
        ldx #0
md1     iny
        lda (zp_p),y
        sta dentry+6,x
        inx
        cpx #11
        bcc md1
        lda #0
        ldx #5
md2     sta dentry+17,x
        dex
        bpl md2
        jsr dbytes             ; length = count x data bytes
        sta d_m
        lda #0
        sta d_v+2
        sta dentry+3
        sta dentry+4
        sta dentry+5
        ldx #8
md3     lsr d_m
        bcc md4
        clc
        lda dentry+3
        adc d_v
        sta dentry+3
        lda dentry+4
        adc d_v+1
        sta dentry+4
        lda dentry+5
        adc d_v+2
        sta dentry+5
md4     asl d_v
        rol d_v+1
        rol d_v+2
        dex
        bne md3
        rts

* attrok: status A against scan: C=0 when it may be used
attrok  sta d_t
        lda scan
        and #$01               ; protected only
        beq ao1
        lda d_t
        and #$01
        beq ao_no
ao1     lda scan
        and #$10               ; unprotected only
        beq ao2
        lda d_t
        and #$01
        bne ao_no
ao2     lda scan
        and #$08               ; directories only
        beq ao3
        lda d_t
        and #$20
        beq ao_no
ao3     lda scan
        and #$80               ; no directories
        beq ao4
        lda d_t
        and #$20
        bne ao_no
ao4     clc
        rts
ao_no   sec
        rts

* setpat: d_pat = name (from U_GEFINA); a blank name matches all
setpat  ldx #10
        ldy #0
sp1     lda name,x
        sta d_pat,x
        cmp #' '
        beq sp2
        iny
sp2     dex
        bpl sp1
        tya
        bne sp4
        ldx #10                ; blank: all
        lda #'?'
sp3     sta d_pat,x
        dex
        bpl sp3
sp4     rts

* ---- 9 kd_open: reading ($04), writing ($08), appending ($09), update
* ($0C: bytes read and written in place; the file does not grow, as on
* Atari DOS 2: writing past its end is 136) ---------------------------------
d_open  lda mode
        and #$1F
        ldx #0                 ; d_op: 0 read, FL_UPD update
        cmp #$04
        beq do0
        ldx #FL_UPD
        cmp #$0C
        beq do0
        cmp #$08
        jeq dw_new
        cmp #$09
        jeq dw_app
        jmp d2_nofn
do0     stx d_op
        jsr d_path
        jcs do_ret0
        jsr setpat
        lda #0
        sta d_ent
        jsr findfile
        bcc do3
        rts
do3     lda d_op               ; update: not a locked file
        beq do4
        lda d_raw
        and #$20
        jne dw_lock
do4     lda dentry+1           ; found: a file control block
        sta d_v
        lda dentry+2
        sta d_v+1
        jsr new_fcb
        bcs do_ret
        lda fs_drv
        sta fc_drv,x
        lda d_raw              ; $04: 16-bit links (MyDOS)
        and #$04
        ora d_op
        sta fc_flg,x
        lda d_ent              ; (POINT checks its sectors' file number)
        sta fc_eplo,x
        lda d_v                ; first sector, which is the next one to read
        sta fc_maplo,x
        sta fc_cmlo,x
        lda d_v+1
        sta fc_maphi,x
        sta fc_cmhi,x
        lda dentry+3
        sta fc_len0,x
        lda dentry+4
        sta fc_len1,x
        lda dentry+5
        sta fc_len2,x
        lda #0
        sta fc_pos0,x
        sta fc_pos1,x
        sta fc_pos2,x
        sta fc_cblo,x
        lda #$FF               ; no sector in use yet
        sta fc_cbhi,x
        lda #E_OK
do_ret  rts
do_ret0 rts

* ---- 0 kd_read: bytbuf bytes to addpos -----------------------------------------
d_read  jsr find_fcb
        jcs dr_ret
        lda #0
        sta d_bpok
        sta d_wr
        lda addpos
        sta zp_q
        lda addpos+1
        sta zp_q+1
        lda bytbuf
        sta d_n
        lda bytbuf+1
        sta d_n+1
        lda #0
        sta bytbuf
        sta bytbuf+1
dr1     lda d_n
        ora d_n+1
        jeq dr_ok
        lda d_bpok             ; the sector in use (getbyte in this call):
        beq dr_b               ; the rest of it, at most d_n, at once
        ldx fs_fcb
        lda fc_cbhi,x
        cmp #$FF
        beq dr_b
        sec
        sbc fc_cblo,x
        beq dr_b
        bcc dr_b
        ldy d_n+1
        bne dr_k
        cmp d_n
        bcc dr_k
        lda d_n
dr_k    sta d_v
        jsr run_p
        jsr mx_on
        ldy #0
dr_c    lda (zp_t),y
        sta (zp_q),y
        iny
        cpy d_v
        bne dr_c
        jsr mx_off
        lda d_v
        bne dr_a               ; (always)
dr_b    jsr dr_dir             ; the next sector whole, straight to the
        bcc dr_a               ; caller: A its bytes
        tax
        jne dr_ret             ; (an error)
        jsr getbyte            ; one byte: the next sector, the end
        bcs dr_end
        jsr mx_on
        ldy #0
        sta (zp_q),y
        jsr mx_off
        lda #1
dr_a    sta d_v                ; d_v bytes done
        clc
        adc zp_q
        sta zp_q
        bcc dr2
        inc zp_q+1
dr2     clc
        lda bytbuf
        adc d_v
        sta bytbuf
        bcc dr3
        inc bytbuf+1
dr3     sec
        lda d_n
        sbc d_v
        sta d_n
        jcs dr1
        dec d_n+1
        jmp dr1
dr_ok   lda #E_OK
dr_ret  rts
dr_end  cmp #E_EOF
        bne dr_ret
        lda bytbuf             ; nothing read: the end
        ora bytbuf+1
        beq dr_eof
        lda #E_OK              ; part of it: the end comes next time
        rts
dr_eof  lda #E_EOF
        rts

* dr_dir: d_read, the sector in use done: the next one read by SIO straight
* to zp_q, as Atari DOS 2 does it, when all its data bytes are wanted (d_n),
* zp_q is in main memory below $9E00 and the cache does not have it. The
* 3 bytes after the data there (where the link lands) are put back. C=0:
* done, A its bytes (FCB, position as getbyte leaves them); C=1: A=0 not
* done, else the status.
qdd_no  lda #0                 ; (not done)
        sec
        rts
dr_dir  lda fs_mx
        cmp #2
        jcs qdd_no
        lda zp_q+1
        cmp #$9E
        jcs qdd_no
        ldx fs_fcb
        lda fc_cbhi,x          ; bytes left in the sector in use: no
        cmp #$FF
        beq qdd1
        cmp fc_cblo,x
        beq qdd1
        jcs qdd_no
qdd1    lda fc_cmlo,x          ; no next sector: the end (getbyte)
        sta fs_sec
        ora fc_cmhi,x
        jeq qdd_no
        lda fc_cmhi,x
        sta fs_sec+1
        jsr dbytes
        sta d_db
        lda d_n+1
        bne qdd2
        lda d_n
        cmp d_db
        jcc qdd_no
qdd2    ldx #NBUF-1            ; in the cache: from there (it may be newer)
qdd3    lda bf_drv,x
        cmp fs_drv
        bne qdd4
        lda bf_seclo,x
        cmp fs_sec
        bne qdd4
        lda bf_sechi,x
        cmp fs_sec+1
        jeq qdd_no
qdd4    dex
        bpl qdd3
        jsr qdd_keep
        lda #'R'
        jsr xd_sio0
        jmi qdd_err
        ldx fs_fcb
        ldy d_db
        lda fc_flg,x           ; 16-bit links (MyDOS): no file number
        and #$04
        bne qdd5
        lda (zp_q),y
        lsr @
        lsr @
        cmp fc_eplo,x
        jne qdd_164
qdd5    iny
        iny
        lda (zp_q),y           ; its bytes
        cmp d_db
        beq qdd6
        jcs qdd_164
qdd6    sta fc_cbhi,x
        sta fc_cblo,x
        dey
        lda (zp_q),y
        sta fc_cmlo,x          ; the next sector
        dey
        lda fc_flg,x
        and #$04
        beq qdd7
        lda #$FF
qdd7    ora #$03
        and (zp_q),y
        sta fc_cmhi,x
        lda fs_sec
        sta fc_dmlo,x
        lda fs_sec+1
        sta fc_dmhi,x
        jsr qdd_back
        lda #0                 ; (zp_p is not this sector)
        sta d_bpok
        clc
        lda fc_pos0,x
        adc fc_cbhi,x
        sta fc_pos0,x
        bcc qdd8
        inc fc_pos1,x
        bne qdd8
        inc fc_pos2,x
qdd8    lda fc_cbhi,x
        clc
        rts
qdd_164 lda #164               ; another file's sector
qdd_err pha
        jsr qdd_back
        pla
        sec
        rts
* qdd_keep, qdd_back: the 3 bytes at zp_q+d_db kept in d_sv and put back
* (keep X)
qdd_keep ldy d_db
        lda (zp_q),y
        sta d_sv
        iny
        lda (zp_q),y
        sta d_sv+1
        iny
        lda (zp_q),y
        sta d_sv+2
        rts
qdd_back ldy d_db
        lda d_sv
        sta (zp_q),y
        iny
        lda d_sv+1
        sta (zp_q),y
        iny
        lda d_sv+2
        sta (zp_q),y
        rts

* dw_dir: d_write, the sector in use (fc_dmlo) still empty (or full: a
* new one after it, pb_next) and more than its data bytes to write: it is written by SIO straight from zp_q (main
* memory below $9E00), with the link to a new sector after it, which is
* then the one in use, as Atari DOS 2 does it. C=0 done; C=1: A=0 not
* done, else the status.
dw_dir  lda fs_mx
        cmp #2
        jcs qdd_no
        lda zp_q+1
        cmp #$9E
        jcs qdd_no
        jsr dbytes
        sta d_db
        lda d_m2+1             ; more than a sector's data bytes left
        bne qdw0
        lda d_db
        cmp d_m2
        jcs qdd_no
qdw0    ldx fs_fcb
        lda fc_cblo,x          ; the one in use empty: it
        beq qdw1
        cmp d_db               ; full: a new one after it (not cached)
        jne qdd_no
        sec
        jsr pb_next
        bcc qdw1
        rts
qdw1    jsr alloc              ; the next one: d_s
        bcc qdw2
        rts                    ; (C=1, A the status)
qdw2    ldx fs_fcb             ; this one, whole
        lda fc_dmlo,x
        sta fs_sec
        lda fc_dmhi,x
        sta fs_sec+1
        jsr xd_drop
        jsr qdd_keep
        ldx fs_fcb
        ldy d_db
        lda fc_flg,x           ; the link: 16-bit, or file number << 2
        and #$04
        beq qdw3
        lda d_s+1
        jmp qdw4
qdw3    lda fc_eplo,x
        asl @
        asl @
        ora d_s+1
qdw4    sta (zp_q),y
        iny
        lda d_s
        sta (zp_q),y
        iny
        lda d_db
        sta (zp_q),y
        lda k_wrtcmd
        jsr xd_sio0
        php
        pha
        jsr qdd_back
        pla
        plp
        jmi qdd_err1
        ldx fs_fcb             ; the next one in use, new: in the cache
        lda d_s                ; when a byte goes in it (dm_get)
        sta fc_dmlo,x
        lda d_s+1
        sta fc_dmhi,x
        lda fc_flg,x
        ora #FL_NEW
        sta fc_flg,x
        inc fc_len0,x          ; one more sector
        bne qdw5
        inc fc_len1,x
qdw5    lda #0
        sta d_bpok
        clc
        lda fc_pos0,x
        adc d_db
        sta fc_pos0,x
        bcc qdw6
        inc fc_pos1,x
        bne qdw6
        inc fc_pos2,x
qdw6    clc
        lda zp_q
        adc d_db
        sta zp_q
        bcc qdw7
        inc zp_q+1
qdw7    sec
        lda d_m2
        sbc d_db
        sta d_m2
        bcs qdw8
        dec d_m2+1
qdw8    clc
        rts
qdd_err1 sec
        rts

* run_p: d_v (1-255) bytes of the sector in use (zp_p) from fc_cblo of FCB
* X: zp_t their address; fc_cblo and the position move past them
run_p   clc
        lda zp_p
        adc fc_cblo,x
        sta zp_t
        lda zp_p+1
        adc #0
        sta zp_t+1
        clc
        lda fc_cblo,x
        adc d_v
        sta fc_cblo,x
        clc
        lda fc_pos0,x
        adc d_v
        sta fc_pos0,x
        bcc rp1
        inc fc_pos1,x
        bne rp1
        inc fc_pos2,x
rp1     rts

* getbyte: the next byte of FCB fs_fcb in A; C=1, A = status at the end.
* fc_cmlo/hi: the next sector (0: none), fc_dmlo/hi: the one in use,
* fc_cblo: the next byte in it, fc_cbhi: its byte count ($FF: none yet).
* d_bpok: zp_p still points at the sector in use (within one call), d_buf
* its buffer. d_wr bit 7: d_c is stored in place of the byte (update).
getbyte ldx fs_fcb
        lda fc_cbhi,x
        cmp #$FF
        beq gb_new
        cmp fc_cblo,x          ; used up: the next sector
        beq gb_new
        bcc gb_new
        lda d_bpok
        bne gb_get
        lda fc_dmlo,x          ; the sector in use, again
        sta fs_sec
        lda fc_dmhi,x
        sta fs_sec+1
        jsr getsec
        bcs gb_ret
        stx d_buf
        inc d_bpok
gb_get  ldx fs_fcb
        ldy fc_cblo,x
        bit d_wr
        bpl gb_rd
        lda d_c
        sta (zp_p),y
        ldx d_buf
        jsr dirty
        ldx fs_fcb
gb_rd   lda (zp_p),y
        inc fc_cblo,x
        inc fc_pos0,x
        bne gb3
        inc fc_pos1,x
        bne gb3
        inc fc_pos2,x
gb3     clc
gb_ret  rts
gb_new  lda fc_cmlo,x          ; no next sector: the end
        ora fc_cmhi,x
        beq gb_eof
        lda fc_cmlo,x
        sta fc_dmlo,x
        sta fs_sec
        lda fc_cmhi,x
        sta fc_dmhi,x
        sta fs_sec+1
        jsr getsec
        bcs gb_ret
        stx d_buf
        lda #1
        sta d_bpok
        jsr dbytes             ; the link after the data
        tay
        ldx fs_fcb
        iny
        iny
        lda (zp_p),y
        sta fc_cbhi,x          ; bytes in this sector
        dey
        lda (zp_p),y
        sta fc_cmlo,x          ; the next sector
        dey
        lda fc_flg,x           ; its high byte: all of it (16-bit) or 2 bits
        and #$04
        beq gb_10
        lda #$FF
gb_10   ora #$03
        and (zp_p),y
        sta fc_cmhi,x
        lda #0
        sta fc_cblo,x
        jmp getbyte
gb_eof  lda #E_EOF
        sec
        rts

* ---- 7 kd_close ------------------------------------------------------------------
d_close jsr find_fcb
        bcs dc_ret
        lda fc_flg,x
        and #FL_WRITE
        beq dc0
        jsr wclose
        bcs dc_ret
        ldx fs_fcb
dc0     lda fc_flg,x           ; update: the changed sectors to the disk
        and #FL_UPD
        beq dc1
        jsr flush
        bcs dc_ret
        ldx fs_fcb
dc1     lda #$FF
        sta fc_drv,x
        lda #E_OK
dc_ret  rts

* ---- 3 kd_gtpos, 4 kd_gtlen, 2 kd_pos ---------------------------------------
* NOTE and POINT as Atari DOS 2 and MyDOS have them: the sector (ICAX3-4)
* and the byte in it (ICAX5) of the next byte
d_gtpos jsr find_fcb
        bcs dc_ret
        bit d_note             ; FTELL: the byte position
        bmi dg0
        lda fc_pos0,x
        sta addpos
        lda fc_pos1,x
        sta addpos+1
        lda fc_pos2,x
        jmp dg2
dg0     lda fc_flg,x           ; written: the sector being written
        and #FL_WRITE
        bne dg1
        lda fc_cbhi,x          ; nothing read yet: the first sector's byte 0
        cmp #$FF
        bne dg1
        lda fc_cmlo,x
        sta addpos
        lda fc_cmhi,x
        sta addpos+1
        lda #0
        beq dg2
dg1     lda fc_dmlo,x
        sta addpos
        lda fc_dmhi,x
        sta addpos+1
        lda fc_cblo,x
dg2     sta addpos+2
        lda #E_OK
        rts
d_gtlen jsr find_fcb
        bcs dc_ret
        lda fc_len0,x
        sta addpos
        lda fc_len1,x
        sta addpos+1
        lda fc_len2,x
        sta addpos+2
        lda #E_OK
        rts
* kd_pos: sector addpos, byte addpos+2 in it (d_gtpos): its link read, a
* sector of another file (DOS 2's file number) 164, past its bytes 166
d_pos   jsr find_fcb
        bcs dp_ret
        jsr farcall            ; (dev.asm fw.icl d_ppos: POINT's sector
        dta b(BK_DEV),a(CARTLO+$4B) ; and byte, FSEEK's byte position)
dp_ret  rts

* ---- 10 kd_first, 6 kd_next ------------------------------------------------------
d_first jsr d_path
        bcs df_ret
        jsr setpat
        jsr new_fcb
        bcs df_ret
        lda fs_drv
        sta fc_drv,x
        lda #$C0               ; a directory search
        sta fc_flg,x
        lda scan
        sta fc_scan,x
        lda #0
        sta fc_pos0,x          ; the next entry
        lda d_base             ; in this directory
        sta fc_dmlo,x
        lda d_base+1
        sta fc_dmhi,x
        ldy #10                ; the pattern, kept for kd_next
df1     lda d_pat,y
        sta d_pats,y
        dey
        bpl df1
        jsr dn_scan
        bcc df_ret
        cmp #E_EOF             ; nothing: the directory stays open
df_ret  rts
d_next  jsr find_fcb
        bcs df_ret
        lda fc_flg,x
        bmi dn1
        lda #E_NOFUNC
        rts
dn1     lda fc_scan,x
        sta scan
        ldy #10
dn2     lda d_pats,y
        sta d_pat,y
        dey
        bpl dn2
* dn_scan: the next matching entry from fc_pos0 on to dentry; A = status
dn_scan ldx fs_fcb
        lda fc_dmlo,x
        sta d_base
        lda fc_dmhi,x
        sta d_base+1
        lda fc_pos0,x
        sta d_ent
dn3     lda d_ent
        cmp #64
        bcs dn_eof
        jsr direntry
        bcs dn_ret
        lda (zp_p),y           ; an unused entry ends the directory
        beq dn_eof
        jsr d_match
        inc d_ent
        bcs dn3
        ldx fs_fcb
        lda d_ent
        sta fc_pos0,x
        lda #E_OK
        clc
        rts
dn_eof  ldx fs_fcb
        lda #64
        sta fc_pos0,x
        lda #E_EOF
        sec
dn_ret  rts

* ---- 16 kd_chdir, 17 kd_cwd: one directory -------------------------------------
d_chdir lda name               ; only the root
        cmp #' '
        beq dch_ok
        lda #E_NOTFOUND
        rts
dch_ok  lda #E_OK
        rts
d_cwd   lda #0
        sta path
        lda #E_OK
        rts

* ---- 19 kd_check: the disk's information, as GETDFREE returns it -------------
d_check ldx fs_drv
        lda #$02               ; Atari DOS 2, MyDOS $FF
        jsr is_my
        beq dk0
        lda #$FF
dk0     sta path
        lda dv_szhi,x          ; $80 128 bytes, $00 256
        bne dk1
        lda #$80
        dta b($2C)
dk1     lda #$00
        sta path+1
        lda dv_totlo,x
        sta path+2
        lda dv_tothi,x
        sta path+3
        lda dv_freelo,x
        sta path+4
        lda dv_freehi,x
        sta path+5
        ldx #7
        jsr is_my
        bne dk3
dk2     lda d_vol,x
        sta path+6,x
        dex
        bpl dk2
        bmi dk4
dk3     lda d_voly,x
        sta path+6,x
        dex
        bpl dk3
dk4
        lda #0
        sta path+$0E
        sta path+$0F
        sta path+$10
        lda #E_OK
        rts

* ===========================================================================
* writing

* is_my: Z=0 for a MyDOS disk (VTOC code 3 and up); keeps X, Y
is_my   stx d_x
        ldx fs_drv
        lda dv_fs,x
        ldx d_x
        cmp #2
        beq im_y
        lda #0
        rts
im_y    lda #1
        rts

* d_path: d_base = the directory path (page 7, $00 at its end) names:
* the main one (361) from the start or after > or backslash, then MyDOS
* subdirectories ($10 entries); dir_name its name (Root for the main one).
* C=1, A = 150 for a path that is not there (any on a DOS 2 disk)
d_path  lda #<361
        sta d_base
        lda #>361
        sta d_base+1
        ldx #10
dpt0    lda d_root,x
        sta dir_name,x
        dex
        bpl dpt0
        ldy #0
dpt1    sty d_y                ; the next component
        lda path,y
        jeq dpt_ok
        cmp #EOL
        jeq dpt_ok
        cmp #'>'
        jeq dpt_sk
        cmp #BSLASH
        jeq dpt_sk
        jsr is_my
        jeq dpt_no
        ldx #10                ; to d_nm, 8+3 space padded
        lda #' '
dpt2    sta d_nm,x
        dex
        bpl dpt2
        ldx #0
dpt3    lda path,y
        beq dpt5
        cmp #EOL
        beq dpt5
        cmp #'>'
        beq dpt5
        cmp #BSLASH
        beq dpt5
        cmp #'<'
        beq dpt_no
        iny
        cmp #'.'
        bne dpt4
        ldx #8
        bne dpt3
dpt4    cpx #11
        bcs dpt3
        sta d_nm,x
        inx
        bne dpt3
dpt5    sty d_y
        lda d_nm               ; . alone: stays
        cmp #' '
        beq dpt_no
        lda #0                 ; the subdirectory in this one
        sta d_ent
dpt6    jsr direntry
        bcs dpt_er
        lda (zp_p),y
        beq dpt_no
        and #$90               ; a directory, not deleted
        cmp #$10
        bne dpt8
        tya
        clc
        adc #5
        tay
        ldx #0
dpt7    lda (zp_p),y
        cmp d_nm,x
        bne dpt8
        iny
        inx
        cpx #11
        bcc dpt7
        tya                    ; found: its first sector (entry + 3)
        sec
        sbc #13
        tay
        lda (zp_p),y
        sta d_t
        iny
        lda (zp_p),y
        sta d_base+1
        lda d_t
        sta d_base
        ldx #10
dpt7a   lda d_nm,x
        sta dir_name,x
        dex
        bpl dpt7a
        ldy d_y
        jmp dpt1
dpt8    inc d_ent
        lda d_ent
        cmp #64
        bcc dpt6
dpt_no  lda #150
        sec
        rts
dpt_sk  ldy d_y                ; a separator
        iny
        jmp dpt1
dpt_ok  clc
dpt_er  rts

* is_ed: Z=0 for a DOS 2.5 enhanced density disk (128-byte sectors, 1010
* in the VTOC's total); keeps X, Y
is_ed   stx d_x
        ldx fs_drv
        lda dv_szhi,x
        bne ie_no
        lda dv_tothi,x
        cmp #>1010
        bne ie_no
        lda dv_totlo,x
        cmp #<1010
        bne ie_no
        ldx d_x
        lda #1
        rts
ie_no   ldx d_x
        lda #0
        rts

* vtoc, vtoc2: the VTOC (360) or VTOC2 (1024) in the cache: zp_p, X
vtoc    lda #<360
        ldx #>360
        bne vt1
vtoc2   lda #<1024
        ldx #>1024
vt1     sta fs_sec
        stx fs_sec+1
        jmp getsec

* bitpos: sector d_s's bit: Y = byte in the bitmap (base d_b), A = mask
bitpos  lda d_s+1              ; byte = (s - base) / 8 + offset
        sta d_t
        lda d_s
        sec
        sbc d_b
        pha
        lda d_t
        sbc #0
        sta d_t
        pla
        lsr d_t
        ror @
        lsr d_t
        ror @
        lsr d_t
        ror @
        clc
        adc d_bo
        tay
        lda d_s
        sec
        sbc d_b
        and #7
        tax
        lda #$80
bp1     dex
        bmi bp2
        lsr @
        bne bp1
bp2     rts

* setbit: sector d_s free (C=1) or used (C=0) in the VTOC and, on an
* enhanced density disk, VTOC2; the free counts follow
setbit  ror d_fr               ; bit 7: free
        jsr is_ed              ; enhanced density: the VTOC up to 719 only
        beq sb1
        lda d_s+1
        cmp #>720
        bcc sb1
        jne sb2
        lda d_s
        cmp #<720
        jcs sb2
sb1     jsr vpos
        jcs sb_ret
        jsr flip
        ldx d_buf
        jsr dirty
        jsr vtoc               ; the free count, in 360
        bcs sb_ret
        stx d_buf
        ldy #3
        jsr count
        ldx d_buf
        jsr dirty
        ldx fs_drv             ; the drive's copy
        lda (zp_p),y
        sta dv_freehi,x
        dey
        lda (zp_p),y
        sta dv_freelo,x
sb2     jsr is_ed              ; enhanced density: VTOC2 from sector 48
        beq sb_ok
        lda d_s+1
        bne sb3
        lda d_s
        cmp #48
        bcc sb_ok
sb3     jsr vtoc2
        bcs sb_ret
        stx d_buf
        lda #48
        sta d_b
        lda #0
        sta d_bo
        jsr bitpos
        jsr flip
        lda d_s+1              ; above 719: its free count at 122
        cmp #>720
        bcc sb4
        bne sb5
        lda d_s
        cmp #<720
        bcc sb4
sb5     ldy #122
        jsr count
sb4     ldx d_buf
        jsr dirty
sb_ok   clc
sb_ret  rts
* vpos: sector d_s's bit in the VTOC (360, MyDOS: 359, 358 ... on; not
* VTOC2): C=0, zp_p+Y its byte, A its mask, d_buf the buffer, d_t+1 the
* VTOC sector (0 = 360); C=1 error
vpos    lda d_s                ; bitmap byte b = 10 + s / 8: in sector
        sta d_t                ; 360 - b / sector size (MyDOS: 359, 358
        lda d_s+1              ; ... go on), at b mod sector size
        lsr @
        ror d_t
        lsr @
        ror d_t
        lsr @
        ror d_t
        sta d_t+1
        clc
        lda d_t
        adc #10
        sta d_t
        bcc vp1
        inc d_t+1
vp1     ldx fs_drv
        lda dv_szhi,x          ; 0: 128 bytes, else 256
        bne vp2
        lda d_t                ; 128: b / 128, b mod 128
        asl @
        rol d_t+1
        lda d_t
        and #$7F
        jmp vp3
vp2     lda d_t                ; 256: high byte, low byte
vp3     sta d_bo               ; the byte in the sector
        lda #<360
        sec
        sbc d_t+1
        sta fs_sec
        lda #>360
        sbc #0
        sta fs_sec+1
        jsr getsec
        jcs vp_ret
        stx d_buf
        ldy d_bo
        lda d_s
        and #7
        tax
        lda #$80
vp4     dex
        bmi vp5
        lsr @
        bne vp4
vp5     clc
vp_ret  rts

* vcount: A = the VTOC's sectors (1, or MyDOS code - 2 pages of 256 bytes;
* 128-byte sectors count them in pairs); C=1 error
vcount  jsr vtoc
        bcs vc_ret
        ldy #0
        lda (zp_p),y
        sec
        sbc #2
        bcc vc1
        bne vc2
vc1     lda #1
        clc
        rts
vc2     ldx fs_drv
        ldy dv_szhi,x
        bne vc3
        asl @
vc3     clc
vc_ret  rts

* flip: the bit A at zp_p+Y set (d_fr bit 7) or cleared
flip    bit d_fr
        bpl fl0
        ora (zp_p),y
        sta (zp_p),y
        rts
fl0     eor #$FF
        and (zp_p),y
        sta (zp_p),y
        rts
* count: the word at zp_p+Y one up (freed) or down; Y+1 on return
count   bit d_fr
        bpl cn_dn
        lda (zp_p),y
        clc
        adc #1
        sta (zp_p),y
        iny
        lda (zp_p),y
        adc #0
        sta (zp_p),y
        rts
cn_dn   lda (zp_p),y
        sec
        sbc #1
        sta (zp_p),y
        iny
        lda (zp_p),y
        sbc #0
        sta (zp_p),y
        rts

* alloc: the lowest free sector (VTOC, then VTOC2 above 719) to d_s, used
* now; C=1 A = E_FULL when there is none
alloc   jsr is_ed
        jeq al_my
        jsr vtoc
        bcs al_ret
        ldy #10
al1     lda (zp_p),y
        jne al_got
        iny
        cpy #100
        bcc al1
        jsr vtoc2
        bcs al_ret
        ldy #84
al2     lda (zp_p),y
        jne al_got2
        iny
        cpy #122
        bcc al2
al_full lda #E_FULL
        sec
al_ret  rts

* al_my: DOS 2 and MyDOS: the VTOC's sectors (1, or MyDOS code - 2 pages
* of 256 bytes) from byte 10 on
al_my   jsr vcount
        bcs al_ret
        sta d_m                ; sectors to look at
        lda #0
        sta d_k                ; this one: 360 - d_k
        lda #10                ; from byte 10 in the first one
        sta d_y
am3     lda #<360
        sec
        sbc d_k
        sta fs_sec
        lda #>360
        sbc #0
        sta fs_sec+1
        jsr getsec
        bcs al_ret
        ldy d_y
am4     lda (zp_p),y
        bne am_got
        iny
        ldx fs_drv
        lda dv_szhi,x
        bne am5
        cpy #128
        bcc am4
        bcs am6
am5     cpy #0                 ; 256: until Y wraps
        bne am4
am6     inc d_k
        lda #0
        sta d_y
        lda d_k
        cmp d_m
        bcc am3
        jmp al_full
am_got  sta d_t                ; byte k * size + Y: sector (that - 10) * 8
        sty d_s
        lda #0
        sta d_s+1
        lda d_k
        ldx fs_drv
        ldy dv_szhi,x
        bne am7
        lsr @                  ; 128: k * 128: k / 2 high, k odd: + $80
        sta d_s+1
        bcc am7a
        lda d_s
        ora #$80
        sta d_s
        bcs am7a
am7     sta d_s+1              ; 256: k high
am7a    lda d_s
        sec
        sbc #10
        sta d_s
        bcs am8
        dec d_s+1
am8     asl d_s
        rol d_s+1
        asl d_s
        rol d_s+1
        asl d_s
        rol d_s+1
        lda d_t
        jmp al_b1
al_got  sta d_t                ; VTOC byte Y: sector (Y-10)*8 + bit
        tya
        sec
        sbc #10
        ldx #0
        beq al_mul
al_got2 sta d_t                ; VTOC2 byte Y: 48 + Y*8 + bit
        tya
        ldx #48
al_mul  sta d_s
        lda #0
        sta d_s+1
        asl d_s
        rol d_s+1
        asl d_s
        rol d_s+1
        asl d_s
        rol d_s+1
        txa
        clc
        adc d_s
        sta d_s
        bcc al_bit
        inc d_s+1
al_bit  lda d_t                ; the highest set bit: the lowest sector
al_b1   asl @
        bcs al_b2
        inc d_s
        bne al_b1
        inc d_s+1
        bne al_b1
al_b2   clc                    ; used now
        jsr setbit
        jcs al_ret
        clc
        rts

* free_chain: the sectors of the file starting at d_s go back to free
free_chain lda d_s
        ora d_s+1
        beq fc_ok
        lda d_s
        sta fs_sec
        lda d_s+1
        sta fs_sec+1
        jsr getsec
        bcs fc_ret
        jsr dbytes
        tay
        lda d_raw              ; the next one (16-bit or 10-bit)
        and #$04
        beq fr_10
        lda #$FF
fr_10   ora #$03
        and (zp_p),y
        pha
        iny
        lda (zp_p),y
        pha
        sec
        jsr setbit
        pla
        sta d_s
        pla
        sta d_s+1
        bcc free_chain
fc_ret  rts
fc_ok   clc
        rts

* findfile: the first entry matching d_pat (from d_ent on) in use; C=0
* d_ent, zp_p+Y; C=1 none
findfile lda d_ent
        cmp #64
        bcs ff_no
ff0     jsr direntry           ; (each sector once, its entries in turn)
        bcs ff_ret
ff1     lda (zp_p),y
        beq ff_no              ; never used: the end
        bmi ff2                ; deleted
        jsr d_match            ; (keeps Y, zp_p)
        bcc ff_ret
ff2     inc d_ent
        lda d_ent
        cmp #64
        bcs ff_no
        and #7
        beq ff0
        tya
        adc #16                ; (C=0)
        tay
        bne ff1                ; (always)
ff_no   lda #E_NOTFOUND
        sec
ff_ret  rts

* freeent: d_ent = a free entry (unused or deleted); C=1, A = status when
* there is none
freeent lda #0
        sta d_ent
fe0     jsr direntry           ; (each sector once, its entries in turn)
        bcs fe_ret
fe1     lda (zp_p),y
        beq fe_ok
        bmi fe_ok
        inc d_ent
        lda d_ent
        cmp #64
        bcs fe_full
        and #7
        beq fe0
        tya
        adc #16                ; (C=0)
        tay
        bne fe1                ; (always)
fe_full lda #E_DIRFULL
        sec
fe_ret  rts
fe_ok   clc
        rts

* ---- opening for writing --------------------------------------------------------
* dw_new ($08): a new file; one there (not locked) is replaced, its entry
* kept. dw_app ($09): the file's last sector is written on.
dw_new  jsr d_path
        jcs dw_ret
        jsr setpat
        ldx #10                ; no wild cards
wn0     lda d_pat,x
        cmp #'?'
        jeq dw_wild
        dex
        bpl wn0
        lda #0
        sta scan
        sta d_ent
        jsr findfile
        jcs dn_free
        lda (zp_p),y           ; there: locked stays
        and #$20
        jne dw_lock
        iny                    ; its sectors go
        iny
        iny
        lda (zp_p),y
        sta d_s
        iny
        lda (zp_p),y
        sta d_s+1
        jsr free_chain
        jcs dw_ret
        jmp dn_ent
dn_free jsr freeent
        jcs dw_ret
dn_ent  jsr alloc              ; the first sector
        jcs dw_ret
        lda d_s
        sta fs_sec
        lda d_s+1
        sta fs_sec+1
        jsr newsecn
        jcs dw_ret
        jsr dirty
        jsr direntry           ; the entry: open for output ($43, MyDOS $47
        jcs dw_ret             ; with 16-bit links)
        jsr is_my
        beq wn3
        lda #$04
wn3     sta d_raw
        ora #$43
        sta (zp_p),y
        iny
        lda #1
        sta (zp_p),y
        iny
        lda #0
        sta (zp_p),y
        iny
        lda d_s
        sta (zp_p),y
        iny
        lda d_s+1
        sta (zp_p),y
        ldx #0
wn2     iny
        lda d_pat,x
        sta (zp_p),y
        inx
        cpx #11
        bcc wn2
        ldx d_buf
        jsr dirty
        lda #0                 ; nothing in the sector yet
        sta d_n
        lda #1
        sta d_n+1
        lda #0
        sta d_n+2
        jmp dw_fcb
dw_wild lda #E_WILD
        rts
dw_lock lda #E_NOTFOUND        ; as for a protected SDFS file
dw_ret  rts

dw_app  jsr d_path
        jcs dw_ret
        jsr setpat
        lda #0
        sta scan
        sta d_ent
        jsr findfile
        bcc da0
        lda #E_NOTFOUND
        rts
da0     lda (zp_p),y
        sta d_raw
        and #$20
        bne dw_lock
        lda (zp_p),y
        ora #$01               ; open for output
        sta (zp_p),y
        ldx d_buf
        jsr dirty
        iny
        iny
        iny
        lda (zp_p),y
        sta d_s
        iny
        lda (zp_p),y
        sta d_s+1
        lda d_s                ; the start, kept for the entry
        sta d_v
        lda d_s+1
        sta d_v+1
        lda #0                 ; to the last sector, counting them
        sta d_n+1
        sta d_n+2
da1     inc d_n+1
        bne da2
        inc d_n+2
da2     lda d_s
        sta fs_sec
        lda d_s+1
        sta fs_sec+1
        jsr getsec
        bcs dw_ret
        jsr dbytes
        tay
        lda d_raw              ; the high byte: all (16-bit) or 2 bits
        and #$04
        beq da2a
        lda #$FF
da2a    ora #$03
        and (zp_p),y
        sta d_t
        iny
        lda (zp_p),y
        iny
        tax
        ora d_t
        beq da3
        stx d_s
        lda d_t
        sta d_s+1
        jmp da1
da3     lda (zp_p),y           ; the last: its byte count
        sta d_n
        lda d_s                ; d_s: the last sector; the start in d_v
        pha
        lda d_s+1
        pha
        lda d_v
        pha
        lda d_v+1
        pha
        jmp dw_fcb2
* dw_fcb: the file control block for writing: d_s the sector being
* written, d_n its byte count, d_n+1/2 the sector count, d_ent the file
dw_fcb  lda d_s
        pha
        lda d_s+1
        pha
        lda d_s                ; the start
        pha
        lda d_s+1
        pha
dw_fcb2 jsr new_fcb
        pla
        sta fc_maphi,x
        pla
        sta fc_maplo,x
        pla
        sta fc_dmhi,x
        pla
        sta fc_dmlo,x
        bcs dw_ret0
        lda fs_drv
        sta fc_drv,x
        lda d_raw              ; $04: 16-bit links
        and #$04
        ora #FL_WRITE
        sta fc_flg,x
        lda d_n
        sta fc_cblo,x
        lda d_n+1
        sta fc_len0,x
        lda d_n+2
        sta fc_len1,x
        lda d_ent
        sta fc_eplo,x
        lda #0
        sta fc_pos0,x
        sta fc_pos1,x
        sta fc_pos2,x
        lda #E_OK
        rts
dw_ret0 rts

* ---- 1 kd_write: bytbuf bytes from addpos --------------------------------------
d_write jsr find_fcb
        bcs dwr_ret
        lda fc_flg,x
        and #FL_WRITE|FL_UPD
        bne dwr0
        lda #E_RDONLY
dwr_ret ldx #0
        stx d_wr
        rts
dwr0    and #FL_UPD            ; update: through getbyte
        lsr @
        ror @
        sta d_wr
        lda addpos
        sta zp_q
        lda addpos+1
        sta zp_q+1
        lda bytbuf
        sta d_m2
        lda bytbuf+1
        sta d_m2+1
        lda #0
        sta d_bpok
dwr1    lda d_m2
        ora d_m2+1
        jeq dwr_ok
        bit d_wr               ; (update: byte by byte)
        bmi dwr_b
        jsr dw_dir             ; a whole sector straight from the caller
        jcc dwr1
        tax
        jne dwr_ret            ; (an error)
        lda d_bpok             ; the sector in use (putbyte in this call):
        beq dwr_b              ; the rest of it, at most d_m2, at once
        ldx fs_fcb
        jsr dbytes
        sec
        sbc fc_cblo,x
        beq dwr_b
        bcc dwr_b
        ldy d_m2+1
        bne dw_k
        cmp d_m2
        bcc dw_k
        lda d_m2
dw_k    sta d_v
        jsr run_p
        jsr mx_on
        ldy #0
dw_c    lda (zp_q),y
        sta (zp_t),y
        iny
        cpy d_v
        bne dw_c
        jsr mx_off
        ldx d_buf
        jsr dirty
        clc
        lda zp_q
        adc d_v
        sta zp_q
        bcc dw_c1
        inc zp_q+1
dw_c1   sec
        lda d_m2
        sbc d_v
        sta d_m2
        bcs dwr1
        dec d_m2+1
        jmp dwr1
dwr_b   jsr mx_on
        ldy #0
        lda (zp_q),y
        jsr mx_off
        bit d_wr
        bmi dwr_u
        jsr putbyte
        jcs dwr_ret
dwr_n   inc zp_q
        bne dwr2
        inc zp_q+1
dwr2    lda d_m2
        bne dwr3
        dec d_m2+1
dwr3    dec d_m2
        jmp dwr1
dwr_u   sta d_c                ; update: in place of the next byte
        jsr getbyte
        jcs dwr_ret
        jmp dwr_n
dwr_ok  lda #E_OK
        jmp dwr_ret

* putbyte: A to the file of FCB fs_fcb; C=1, A = status on an error
putbyte sta d_c
        ldx fs_fcb
        jsr dbytes
        cmp fc_cblo,x
        jne pb_in
        clc                    ; the sector is full: the next one
        jsr pb_next
        jcs pb_ret
        jmp pb_in
* dm_get: the sector in use (fc_dmlo of FCB X) in the cache: zp_p, d_buf;
* one new that dw_dir put nothing in yet (FL_NEW) is made there, not read.
* C=1, A the status on an error.
dm_get  lda fc_dmlo,x
        sta fs_sec
        lda fc_dmhi,x
        sta fs_sec+1
        lda fc_flg,x
        and #FL_NEW
        beq dmg1
        eor fc_flg,x
        sta fc_flg,x
        jsr newsecn
        bcs dmg_r
        jsr dirty
        jmp dmg2
dmg1    jsr getsec
        bcs dmg_r
dmg2    stx d_buf
        clc
dmg_r   rts

* pb_next: a new sector after the full one in use (FCB fs_fcb), linked
* from it, then in use, empty; in the cache (newsecn) unless C=1 (dw_dir
* writes it whole). C=1, A the status on an error.
pb_next ror d_nn
        jsr alloc
        jcs pb_ret
        ldx fs_fcb             ; linked from this one
        lda fc_dmlo,x
        sta fs_sec
        lda fc_dmhi,x
        sta fs_sec+1
        jsr getsec
        jcs pb_ret
        stx d_buf
        jsr dbytes
        tay
        ldx fs_fcb
        lda fc_flg,x           ; 16-bit: the next sector's high byte
        and #$04
        beq pb_fn
        lda d_s+1
        jmp pb_l
pb_fn   lda fc_eplo,x          ; file number << 2, next sector
        asl @
        asl @
        ora d_s+1
pb_l    sta (zp_p),y
        iny
        lda d_s
        sta (zp_p),y
        iny
        jsr dbytes
        sta (zp_p),y
        ldx d_buf
        jsr dirty
        lda d_s                ; the new one, empty
        sta fs_sec
        lda d_s+1
        sta fs_sec+1
        bit d_nn
        bmi pb_nc
        jsr newsecn
        bcs pb_ret
        jsr dirty
pb_nc   ldx fs_fcb
        lda d_s
        sta fc_dmlo,x
        lda d_s+1
        sta fc_dmhi,x
        lda #0
        sta fc_cblo,x
        inc fc_len0,x          ; one more sector
        bne pb0
        inc fc_len1,x
pb0     lda #0
        sta d_bpok
        clc
        rts
pb_in   lda d_bpok             ; the sector being written
        bne pb1
        jsr dm_get
        bcs pb_ret
        inc d_bpok
pb1     ldx fs_fcb
        ldy fc_cblo,x
        lda d_c
        sta (zp_p),y
        inc fc_cblo,x
        inc fc_pos0,x
        bne pb2
        inc fc_pos1,x
        bne pb2
        inc fc_pos2,x
pb2     ldx d_buf
        jsr dirty
        clc
pb_ret  rts

* wclose: a written file closed: the last sector's link (no next, its
* byte count), the entry (not open, the sector count), all to the disk
wclose  jsr dm_get
        bcs wc_ret
        jsr dbytes
        tay
        ldx fs_fcb
        lda fc_flg,x           ; no next: 0 (with the file number)
        and #$04
        bne wc_l
        lda fc_eplo,x
        asl @
        asl @
        dta b($2C)
wc_l    lda #0
        sta (zp_p),y
        iny
        lda #0
        sta (zp_p),y
        iny
        lda fc_cblo,x
        sta (zp_p),y
        ldx d_buf
        jsr dirty
        ldx fs_fcb
        lda fc_eplo,x
        sta d_ent
        jsr direntry
        bcs wc_ret
        lda (zp_p),y
        and #$FE               ; no longer open for output
        sta (zp_p),y
        iny
        ldx fs_fcb
        lda fc_len0,x
        sta (zp_p),y
        iny
        lda fc_len1,x
        sta (zp_p),y
        ldx d_buf
        jsr dirty
        jsr flush
        bcs wc_ret
        clc
wc_ret  rts

* ---- 12 kd_delete, 11 kd_rename, 13 kd_setatr: on every matching file -----
d_delete lda #0
        beq dm_go
d_rename lda #1
        bne dm_go
d_setatr lda #2
dm_go   sta d_op
        jsr d_path
        jcs dm_ret
        jsr setpat
        lda d_op               ; delete: files only (a directory: kd_deldir)
        bne dm_g1
        lda scan
        ora #$80
        sta scan
dm_g1
        lda #0
        sta d_ent
        sta d_hits
dm_l    jsr findfile
        bcs dm_end
        lda d_op
        beq dm_del
        cmp #1
        beq dm_ren
        lda attr               ; lock (P set) or unlock (P cleared)
        and #$01
        beq dm_a1
        lda (zp_p),y
        ora #$20
        sta (zp_p),y
dm_a1   lda attr
        and #$10
        beq dm_mark
        lda (zp_p),y
        and #$DF
        sta (zp_p),y
        jmp dm_mark
dm_del  lda (zp_p),y           ; locked files stay
        and #$20
        bne dm_next
        lda #$80
        sta (zp_p),y
        ldx d_buf
        jsr dirty
        iny
        iny
        iny
        lda (zp_p),y
        sta d_s
        iny
        lda (zp_p),y
        sta d_s+1
        jsr free_chain
        bcs dm_ret
        jmp dm_hit
dm_ren  tya                    ; the new name ('?' keeps a character)
        clc
        adc #5
        tay
        ldx #0
dr_1    lda x_name,x
        cmp #'?'
        beq dr_2
        sta (zp_p),y
dr_2    iny
        inx
        cpx #11
        bcc dr_1
dm_mark ldx d_buf
        jsr dirty
dm_hit  inc d_hits
dm_next inc d_ent
        jmp dm_l
dm_end  lda d_hits
        bne dm_ok
        lda #E_NOTFOUND
        rts
dm_ok   jsr flush
        bcs dm_ret
        lda #E_OK
dm_ret  rts

* ---- 14 kd_credir, 15 kd_deldir: MyDOS subdirectories ------------------
* As MyDOS makes them: 8 free sectors in a row from 369 up, zeroed; the
* entry $10, count 8, the first sector, the name. On an Atari DOS 2 disk
* (no subdirectories) 135.
d_credir jsr is_my
        jeq d2_ro
        jsr d_path
        jcs cr_ret
        jsr setpat
        ldx #10                ; no wild cards (a blank name is all ?)
cr0     lda d_pat,x
        cmp #'?'
        jeq dw_wild
        dex
        bpl cr0
        lda #0                 ; the name may not be there (file or directory)
        sta scan
        sta d_ent
        jsr findfile
        bcs cr1
        lda #E_EXISTS
        rts
cr1     jsr freeent
        jcs cr_ret
        jsr vcount             ; 8 free sectors in a row
        jcs cr_ret
        sta d_m
        lda #<369
        sta d_s
        lda #>369
        sta d_s+1
        lda #0
        sta d_k
cr2     jsr vpos
        jcs cr_ret
        ldx d_t+1              ; past the VTOC: none
        cpx d_m
        jcs al_full
        and (zp_p),y
        beq cr3
        inc d_k
        lda d_k
        cmp #8
        beq cr4
        bne cr5
cr3     lda #0
        sta d_k
cr5     inc d_s
        bne cr2
        inc d_s+1
        jmp cr2
cr4     lda d_s                ; d_s the last: the first is 7 below
        sec
        sbc #7
        sta d_s
        sta d_v
        bcs cr6
        dec d_s+1
cr6     lda d_s+1
        sta d_v+1
        lda #8
        sta d_k
cr7     clc                    ; used, and zeros
        jsr setbit
        jcs cr_ret
        lda d_s
        sta fs_sec
        lda d_s+1
        sta fs_sec+1
        jsr newsec
        jcs cr_ret
        jsr dirty
        inc d_s
        bne cr8
        inc d_s+1
cr8     dec d_k
        bne cr7
        jsr direntry           ; the entry
        jcs cr_ret
        lda #$10
        sta (zp_p),y
        iny
        lda #8
        sta (zp_p),y
        iny
        lda #0
        sta (zp_p),y
        iny
        lda d_v
        sta (zp_p),y
        iny
        lda d_v+1
        sta (zp_p),y
        ldx #0
cr9     iny
        lda d_pat,x
        sta (zp_p),y
        inx
        cpx #11
        bcc cr9
        ldx d_buf
        jsr dirty
        jsr flush
        bcs cr_ret
        lda #E_OK
cr_ret  rts

* kd_deldir: an empty one (nothing but deleted entries); a locked one stays
d_deldir jsr is_my
        jeq d2_ro
        jsr d_path
        jcs dd_ret
        jsr setpat
        lda #$08               ; directories only
        sta scan
        lda #0
        sta d_ent
        jsr findfile
        bcc dd0
        lda #E_NOTFOUND        ; as SDX on SDFS
        rts
dd0     lda (zp_p),y
        and #$20
        jne dw_lock
        lda d_base             ; the parent, for the entry later
        sta d_m2
        lda d_base+1
        sta d_m2+1
        lda d_ent
        sta d_hits
        iny
        iny
        iny
        lda (zp_p),y
        sta d_base
        sta d_s
        iny
        lda (zp_p),y
        sta d_base+1
        sta d_s+1
        lda #0
        sta d_ent
dd1     jsr direntry
        bcs dd_ret
        lda (zp_p),y
        beq dd3                ; the end
        bmi dd2                ; deleted
        lda #E_NOTEMPTY
        rts
dd2     inc d_ent
        lda d_ent
        cmp #64
        bcc dd1
dd3     lda #8                 ; its sectors free
        sta d_k
dd4     sec
        jsr setbit
        bcs dd_ret
        inc d_s
        bne dd5
        inc d_s+1
dd5     dec d_k
        bne dd4
        lda d_m2               ; the entry deleted
        sta d_base
        lda d_m2+1
        sta d_base+1
        lda d_hits
        sta d_ent
        jsr direntry
        bcs dd_ret
        lda #$80
        sta (zp_p),y
        ldx d_buf
        jsr dirty
        jsr flush
        bcs dd_ret
        lda #E_OK
dd_ret  rts

* ---- the caller's memory (memreix) around a byte ---------------------------------
mx_on   pha
        lda fs_mx
        cmp #2                 ; (0 or 1: main memory)
        bcc mo_ret
        lda PORTB
        sta fs_mxp
        lda fs_mx
        sta PORTB
mo_ret  pla
        rts
mx_off  pha
        lda fs_mx
        cmp #2                 ; (0 or 1: main memory)
        bcc mo_ret
        lda fs_mxp
        sta PORTB
        pla
        rts

* the FMS's cache buffers (as fms.asm bf_lo, bf_hi)
xbf_lo  dta l(BF_DATA,BF_DATA+SECMAX,BF_DATA+2*SECMAX,BF_DATA+3*SECMAX)
        dta l(BF_DAT2,BF_DAT2+SECMAX,BF_DAT2+2*SECMAX,BF_DAT2+3*SECMAX)
xbf_hi  dta h(BF_DATA,BF_DATA+SECMAX,BF_DATA+2*SECMAX,BF_DATA+3*SECMAX)
        dta h(BF_DAT2,BF_DAT2+SECMAX,BF_DAT2+2*SECMAX,BF_DAT2+3*SECMAX)

        icl 'dos2x.icl'
        icl 'dos2i.icl'

* xcopyw: the FMS's copy_w, fs_n bytes from (zp_q) to the cache (zp_p);
* zp_q moves past them. From the caller's bank (fs_mx), or, when the caller
* has the OS ROM on (fs_mx 1, set_mx: a read or write call's own buffer,
* never the FMS's data) and the bytes reach $C000, a byte at a time with
* the ROM on to read and off to write (BSAVE of the ROM saves the ROM, as
* on SDX).
xcopyw  lda fs_mx              ; 0 main memory, 1 the same with the
        beq xcw0               ; caller's ROM on, else a bank
        cmp #1
        bne xcw_mx
        clc                    ; (the end's page: $C0 up, or past $FFFF)
        lda zp_q
        adc fs_n
        lda zp_q+1
        adc fs_n+1
        bcs xcw_rom
        cmp #$C0
        bcs xcw_rom
xcw0    ldy #0
        ldx fs_n+1
        beq xcw2
xcw1    lda (zp_q),y
        sta (zp_p),y
        iny
        bne xcw1
        inc zp_p+1
        inc zp_q+1
        dex
        bne xcw1
xcw2    ldx fs_n
        beq xcw4
xcw3    lda (zp_q),y
        sta (zp_p),y
        iny
        dex
        bne xcw3
        tya
        clc
        adc zp_q
        sta zp_q
        bcc xcw4
        inc zp_q+1
xcw4    rts
xcw_mx  lda PORTB              ; the caller's bank in meanwhile
        sta fs_mxp
        lda fs_mx
        sta PORTB
        jsr xcw0
        lda fs_mxp
        sta PORTB
        rts
xcw_rom lda fs_n               ; (counted down in ix_t: the index code's,
        sta ix_t               ; not in use while a file is written)
        lda fs_n+1
        sta ix_t+1
        ldy #0
xcr1    lda ix_t
        ora ix_t+1
        beq xcr3
        php                    ; (no interrupt while the ROM is on)
        sei
        lda PORTB
        ora #$01
        sta PORTB
        lda (zp_q),y
        tax
        lda PORTB
        and #$FE
        sta PORTB
        plp
        txa
        sta (zp_p),y
        inc zp_q
        bne xcr2
        inc zp_q+1
xcr2    inc zp_p
        bne xcr2a
        inc zp_p+1
xcr2a   lda ix_t
        bne xcr2b
        dec ix_t+1
xcr2b   dec ix_t
        jmp xcr1
xcr3    rts

* xdirect: the FMS's wr_core, a whole new sector fs_sec of drive fs_drv
* written straight from the caller's buffer (zp_q, fs_n bytes) when it is in
* main memory below the cartridge: a cached copy of the sector (a deleted
* file's) is dropped, zp_q moves past the bytes. X=0, A = status; X=$FF:
* not here (the FMS goes through the cache).
xdirect lda fs_mx              ; main memory (0, or 1: the caller's ROM on;
        cmp #2                 ; below $9E00 the ROM does not matter)
        bcc xd0
xd_no   ldx #$FF
        rts
xd0     lda zp_q+1             ; (512 bytes at most, below $A000)
        cmp #$9E
        bcs xd_no
        jsr xd_drop
        lda k_wrtcmd
        jsr xd_sio0
        pha
        clc
        lda zp_q
        adc fs_n
        sta zp_q
        lda zp_q+1
        adc fs_n+1
        sta zp_q+1
        pla
        ldx #0
        rts

* xd_drop: sector fs_sec of fs_drv forgotten by the caches (it is
* written whole, not through them)
xd_drop ldx #NBUF-1
xd1     lda bf_drv,x
        cmp fs_drv
        bne xd2
        lda bf_seclo,x
        cmp fs_sec
        bne xd2
        lda bf_sechi,x
        cmp fs_sec+1
        bne xd2
        lda #$FF
        sta bf_drv,x
        sta bf_age,x
        lda #0
        sta bf_dirty,x
xd2     dex
        bpl xd1
        lda l2_pb              ; (and a copy in the second-level cache:
        beq xdd_r              ; dev.asm l2.icl l2_drop1)
        jsr farcall
        dta b(BK_DEV),a(CARTLO+$42)
xdd_r   rts

* xd_sio0: SIO command A for sector fs_sec of fs_drv, its whole size, at
* zp_q (main memory below $9E00); the status in A, N
xd_sio0 sta DCOMND
        ldx #$80
        cmp #'R'
        bne xs1
        ldx #$40
xs1     stx DSTATS
        lda #$31
        sta DDEVIC
        ldy fs_drv
        iny
        sty DUNIT
        dey
        lda #7
        sta DTIMLO
        lda zp_q
        sta DBUFLO
        lda zp_q+1
        sta DBUFHI
        lda dv_szlo,y
        sta DBYTLO
        lda dv_szhi,y
        sta DBYTHI
        lda fs_sec
        sta DAUX1
        lda fs_sec+1
        sta DAUX2
        jsr k_lsio
        ora #0                 ; (N from the status)
        rts


* mn_rest: the FMS's mount, drive X (fs_drv): the main directory, size, free
* count, bitmap and hint from the volume header at zp_p, and the bitmap's
* bits. C=1: another disk (another sector size, sequence number or random
* id, or none before): its sequence number and random id kept, the current
* directory the main one.
* mn_rest: the FMS's mount, sector 1 at zp_p, A its revision byte ($20,
* $21 SDFS; $45 EOSFS, $46 EOSFS left with changes not all written): the
* file system, the sizes, the rest of the header; C=1 another disk. A $46
* volume gets its quick check (mn_chk).
mn_rest ldx fs_drv
        sta d_k
        ldy #0
        cmp #$45               ; EOSFS: an SDFS 2.1 header, files as extents
        beq mr0
        cmp #$46
        bne mn_o0
mr0     ldy #3
        lda #$21
mn_o0   pha                    ; (A: the version, tested next)
        tya
        sta dv_fs,x
        pla
        cmp #$21
        bne mn_v20
        ldy #33
        lda (zp_p),y
        sta dv_szlo,x
        iny
        lda (zp_p),y
        sta dv_szhi,x
        jmp mn_sz
mn_v20  ldy #31
        lda (zp_p),y
        cmp #$80
        beq mn_128
        lda #0
        sta dv_szlo,x
        lda #1
        sta dv_szhi,x
        bne mn_sz
mn_128  sta dv_szlo,x
        lda #0
        sta dv_szhi,x
mn_sz   ldy dv_szhi,x          ; 0, 1, 2: 128, 256, 512 bytes
        lda shf_tab,y
        sta dv_shf,x
        lda ments_tab,y
        sta dv_ments,x
        lda dv_fs,x            ; EOSFS: extents per list sector
        cmp #3
        bne mr1
        lda xments_tab,y
        sta dv_ments,x
mr1     jsr mn_hdr2
        php
        lda d_k
        cmp #$46
        bne mr2
        jsr mn_chk
mr2     plp
        rts
shf_tab dta b(7,8,9)
ments_tab dta b(62,126,254)
xments_tab dta b(31,63,127)    ; EOSFS: extents per list sector

* mn_chk: the quick check of an EOSFS volume whose header says changes
* were not all written (EOS stopped while writing): the free count again
* from the bitmap (its set bits), the header written clean ($45). CHKDSK /F
* is the whole check.
mn_chk  lda #0
        sta d_v
        sta d_v+1
        sta d_t
mc1     ldx fs_drv
        lda d_t
        cmp dv_nbmp,x
        bcs mc6
        clc
        lda dv_bmaplo,x
        adc d_t
        sta fs_sec
        lda dv_bmaphi,x
        adc #0
        sta fs_sec+1
        jsr getsec
        bcs mc_r
        ldx fs_drv
        lda dv_szlo,x
        sta d_n
        lda dv_szhi,x
        sta d_n+1
        lda zp_p
        sta zp_t
        lda zp_p+1
        sta zp_t+1
        ldy #0
mc2     lda (zp_t),y
        beq mc4
mc3     lsr @
        bcc mc3a
        inc d_v
        bne mc3a
        inc d_v+1
mc3a    cmp #0
        bne mc3
mc4     iny
        bne mc5
        inc zp_t+1
mc5     lda d_n
        bne mc5a
        dec d_n+1
mc5a    dec d_n
        lda d_n
        ora d_n+1
        bne mc2
        inc d_t
        jmp mc1
mc6     lda d_v                ; the header: the free count, clean
        sta dv_freelo,x
        lda d_v+1
        sta dv_freehi,x
        lda #1
        sta fs_sec
        lda #0
        sta fs_sec+1
        jsr getsec
        bcs mc_r
        ldy #13
        lda d_v
        sta (zp_p),y
        iny
        lda d_v+1
        sta (zp_p),y
        ldy #32
        lda #$45
        sta (zp_p),y
        jsr dirty
        jsr flush
mc_r    rts

* hd_hook: from the FMS's wr_buf, buffer X about to be written. On an
* EOSFS drive the header's revision byte says $46 while changes are not
* all on the disk: before the first other sector since the header was
* last written clean, sector 1 goes to the disk with $46 (read and written
* through fs_sbuf, the cache left alone); the header itself is written
* with $46, or $45 in flush_drv's last pass (fl_p $FF: all else is on the
* disk). dv_hdirty bit 6: $46 is on the disk.
hd_hook bit fw_h               ; a sector written: the byte window first
        bmi hh0
        jsr farcall            ; (dev.asm fw_keep)
        dta b(BK_DEV),a(CARTLO+$30)
hh0     lda bf_drv,x
        tay
        lda dv_fs,y
        cmp #3
        bne hh_r
        lda bf_sechi,x
        bne hh_d
        lda bf_seclo,x
        cmp #1
        bne hh_d
        lda zp_t               ; the header itself
        pha
        lda zp_t+1
        pha
        lda xbf_lo,x
        sta zp_t
        lda xbf_hi,x
        sta zp_t+1
        lda #$45
        bit fl_p
        bmi hh1
        lda dv_hdirty,y
        ora #$40
        sta dv_hdirty,y
        lda #$46
hh1     ldy #32
        sta (zp_t),y
        pla
        sta zp_t+1
        pla
        sta zp_t
hh_r    rts
hh_d    lda dv_hdirty,y        ; another sector: the flag on the disk first
        and #$40
        bne hh_r
        stx d_x
        sty d_y
        ldx #NBUF-1            ; sector 1 in the cache (mount reads it at
hk1     lda bf_drv,x           ; every path operation): a copy of it, so
        cmp d_y                ; one write does (a read before the write
        bne hk2                ; costs a disk turn)
        lda bf_sechi,x
        bne hk2
        lda bf_seclo,x
        cmp #1
        beq hk3
hk2     dex
        bpl hk1
        lda #'R'               ; not there: read
        jsr hh_sio
        bmi hh_x
        jmp hh_wr
hk3     lda fs_x               ; (wr_buf's buffer, kept)
        pha
        stx fs_x
        jsr hh_len
        sec
        jsr farcall            ; (dev.asm bounce.icl xbounce)
        dta b(BK_DEV),a(CARTLO+$45)
        pla
        sta fs_x
hh_wr   lda #$46
        sta fs_sbuf+32
        lda k_wrtcmd
        jsr hh_sio
        bmi hh_x
        ldy d_y
        lda dv_hdirty,y
        ora #$40
        sta dv_hdirty,y
hh_x    ldx d_x
        rts
* hh_sio: command A for sector 1 of drive d_y through fs_sbuf (256-byte
* disks: 128 bytes); N=1 error
hh_sio  sta DCOMND
        ldy #$40
        cmp #'R'
        beq hs1
        ldy #$80
hs1     sty DSTATS
        lda #$31
        sta DDEVIC
        ldy d_y
        iny
        sty DUNIT
        dey
        lda #<fs_sbuf
        sta DBUFLO
        lda #>fs_sbuf
        sta DBUFHI
        lda #1
        sta DAUX1
        lda #0
        sta DAUX2
        lda #7
        sta DTIMLO
        jsr hh_len
        jmp k_lsio
* hh_len: DBYT = sector 1's size on drive d_y (256-byte disks: 128)
hh_len  ldy d_y
        lda dv_szlo,y
        sta DBYTLO
        lda dv_szhi,y
        sta DBYTHI
        cmp #1
        bne hl1
        lda #128
        sta DBYTLO
        lda #0
        sta DBYTHI
hl1     rts

mn_hdr2
        ldy #9
        lda (zp_p),y
        sta dv_mainlo,x
        iny
        lda (zp_p),y
        sta dv_mainhi,x
        iny
        lda (zp_p),y
        sta dv_totlo,x
        iny
        lda (zp_p),y
        sta dv_tothi,x
        iny
        lda (zp_p),y
        sta dv_freelo,x
        iny
        lda (zp_p),y
        sta dv_freehi,x
        iny
        lda (zp_p),y
        sta dv_nbmp,x
        iny
        lda (zp_p),y
        sta dv_bmaplo,x
        iny
        lda (zp_p),y
        sta dv_bmaphi,x
        iny
        lda (zp_p),y
        sta dv_hintlo,x
        iny
        lda (zp_p),y
        sta dv_hinthi,x
        lda dv_nbmp,x          ; bits in the bitmap: nbmp << (shift + 3),
        sta fs_t               ; at most $FFFF
        lda #0
        sta fs_t+1
        sta fs_l
        ldy dv_shf,x
        iny
        iny
        iny
mn_b1   asl fs_t
        rol fs_t+1
        rol fs_l
        dey
        bne mn_b1
        lda fs_l
        beq mn_b2
        lda #$FF
        sta fs_t
        sta fs_t+1
mn_b2   lda fs_t
        sta dv_bitslo,x
        lda fs_t+1
        sta dv_bitshi,x
        lda #0
        sta dv_hdirty,x
        lda dv_szhi,x          ; another sector size: another disk
        cmp fs_osz
        bne mn_new
        ldy #38
        lda (zp_p),y
        cmp dv_seq,x
        bne mn_new
        iny
        lda (zp_p),y
        cmp dv_rnd,x
        bne mn_new
        lda dv_cwdlo,x
        ora dv_cwdhi,x
        beq mn_new
        clc
        rts
mn_new  ldy #38
        lda (zp_p),y
        sta dv_seq,x
        iny
        lda (zp_p),y
        sta dv_rnd,x
        lda dv_mainlo,x
        sta dv_cwdlo,x
        lda dv_mainhi,x
        sta dv_cwdhi,x
        sec
        rts

d_vol   dta c'DOS 2.0 '
d_voly  dta c'MyDOS   '
d_root  dta c'Root       '

        icl 'tail.icl'
