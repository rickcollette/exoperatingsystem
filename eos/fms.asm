* EOS (Extendable Operating System): bank 2, the DSK: kernel device
*
* EOSFS v2 on SIO disks D1: to D15:. Written for
* ROM: no self-modifying code, all state in the RAM described in fmsdata.icl.
* Kernel interface: function code in Y, page 7 parameters, status in A.

        icl 'equ.icl'
        icl 'kernel.icl'

        opt h-f+

zp_p    equ $43                ; sector buffer
zp_q    equ $45                ; caller's buffer
zp_t    equ $47                ; scratch pointer

* status codes
E_OK    equ 1
E_PATHLEN equ 182
E_NOTOPEN equ 133
E_EOF   equ 136
E_NOFUNC equ 146
E_BADFMT equ 148
E_PATH  equ 150
E_DRIVE equ 160
E_TOOMANY equ 161
E_RANGE equ 166
E_NOTFOUND equ 170
E_RDONLY equ 135
E_EXISTS equ 151
E_FULL  equ 162
E_WILD  equ 163
E_BADNAME equ 165
E_NOTEMPTY equ 167

* directory entry status bits
ST_PROT equ $01
ST_HID  equ $02
ST_ARC  equ $04
ST_USED equ $08
ST_DEL  equ $10
ST_DIR  equ $20
ST_LINK equ $40

        org CARTLO
        jmp dsk_entry          ; $A000 kernel device entry
        jmp getsec             ; $A003 for the EOSFS helper bank
        jmp new_fcb            ; $A006
        jmp find_fcb           ; $A009
        jmp flush_drv          ; $A00C
        jmp newsec             ; $A00F
        jmp free_sec           ; $A012 for the EOSFS helper bank
        jmp blk_ctl            ; $A015 jblock_io: Y=2 flush, else drop (DUNIT)
        jmp alloc              ; $A018 for the EOSFS helper bank
        jmp route              ; $A01B for dev.asm fw_wrap
        jmp ns_c               ; $A01E helper: newsec, C=1 not zeroed

* ---- kernel function dispatch ----------------------------------------------
* the cache lies under the OS ROM: it is off while the driver runs
dsk_entry cpy #22
        bcs f_nofunc
        cld
        jsr k_romoff
        lda #0                 ; the caller's buffer in main memory, unless
        sta fs_mx              ; kd_read or kd_write say otherwise
        jsr farcall            ; route, inside the byte window's settling
        dta b(BK_DEV),a(CARTLO+$2D) ; and setting (dev.asm fw_wrap)
        jmp k_romon            ; keeps A and the flags
* route: the resident DSK: driver is EOSFS-only. Foreign filesystems are
* accessed by transient Toolkit programs, not dispatched through the kernel.
route   lda ftab_hi,y
        pha
        lda ftab_lo,y
        pha
        rts
f_nofunc lda #E_NOFUNC
        rts

ftab_lo dta l(f_read-1,f_write-1,f_pos-1,f_gtpos-1,f_gtlen-1,f_nofunc-1,f_next-1)
        dta l(f_close-1,f_initz-1,f_open-1,f_first-1,f_rename-1,f_delete-1)
        dta l(f_setatr-1,f_credir-1,f_deldir-1,f_chdir-1,f_cwd-1,f_boot-1)
        dta l(f_check-1,f_chvol-1,f_lpath-1)
ftab_hi dta h(f_read-1,f_write-1,f_pos-1,f_gtpos-1,f_gtlen-1,f_nofunc-1,f_next-1)
        dta h(f_close-1,f_initz-1,f_open-1,f_first-1,f_rename-1,f_delete-1)
        dta h(f_setatr-1,f_credir-1,f_deldir-1,f_chdir-1,f_cwd-1,f_boot-1)
        dta h(f_check-1,f_chvol-1,f_lpath-1)

* ---- 8 kd_initz: forget all files, buffers and disks ------------------------
f_initz ldx #NFCB
fi1     lda #$FF
        sta fc_drv,x
        dex
        bpl fi1
        sta fw_h               ; no byte window
        ldx #NBUF-1
fi2     lda #$FF
        sta bf_drv,x
        sta bf_age,x
        lda #0
        sta bf_dirty,x
        dex
        bpl fi2
        ldx #NDRV-1
        lda #0
fi3     sta dv_szlo,x
        sta dv_szhi,x
        sta dv_hdirty,x
        sta dv_cwdlo,x
        sta dv_cwdhi,x
        dex
        bpl fi3
        rts

* ---- 9 kd_open --------------------------------------------------------------
f_open  lda #0
        sta fs_kdt
        jsr setdrv
        jcs fo_ret
        jsr resolve
        jcs fo_ret
        lda mode
        and #$10
        jne fo_dir
        lda mode
        and #$0F
        cmp #$04
        beq fo_read
        cmp #$08
        beq fo_w
        cmp #$09
        beq fo_w
        cmp #$0C
        jne fo_nofn
fo_w    jmp fo_write
fo_read
        lda fs_drv             ; its directory, for U_LOAD's path
        sta op_drv
        lda fs_dmap
        sta op_dmap
        lda fs_dmap+1
        sta op_dmap+1
        lda scan
        sta fs_scn
        jsr scan_name
        bcs fo_nf
        jsr new_fcb
        bcs fo_ret
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
        lda #0
        sta fc_flg,x
        jsr fcb_rewind
fo_ent  ldx #EOS_DIRENT_SIZE-1 ; the entry of the opened file, as on SDX
fo_e1   lda fs_ent,x           ; (SYMLINK.SYS looks at its status)
        sta dentry,x
        dex
        bpl fo_e1
        lda mode               ; read: its date and time to date/time, as on
        and #$08               ; SDX; written: the date it will get (FCB)
        bne fo_e3
        ldx #5
fo_e2   lda fs_ent+38,x
        sta date,x
        dex
        bpl fo_e2
        bmi fo_ok
fo_e3   lda fs_kdt
        beq fo_ok
        ldx fs_fcb
        lda fc_flg,x
        ora #FL_KEEPDT
        sta fc_flg,x
fo_ok   lda #E_OK
fo_ret  rts
fo_nf   cmp #E_EOF
        bne fo_ret
        lda #E_NOTFOUND
        rts
fo_nofn lda #E_NOFUNC
        rts
* direct directory access: the directory named by path (and name, if given)
fo_dir  lda mode                ; directories: as files to read ($14), or
        and #$0F               ; to read and write in place ($1C, entries
        cmp #$04               ; changed by programs such as FIXLINK.COM)
        beq fo_d0
        cmp #$0C               ; the directory is the path's: the name is
        bne fo_nofn            ; not looked at (as on SDX)
fo_d0   jsr new_fcb
        bcs fo_ret
        jsr open_dir
        bcs fo_ret
        lda mode
        and #$08               ; $0C: FL_WRITE
        asl @
        asl @
        ora #FL_DIR            ; kd_next returns every entry
        sta fc_flg,x
        lda #0
        sta fc_scan,x
        jsr pat_adr
        ldy #0
        lda #'*'
        sta (zp_t),y
        iny
        lda #0
        sta (zp_t),y
        ldx #EOS_DIRENT_SIZE-1
fo_d2   lda fs_ent,x
        sta dentry,x
        dex
        bpl fo_d2
        bmi fo_ok

* ---- 10 kd_first ------------------------------------------------------------
f_first jsr setdrv
        bcs ff_ret
        jsr resolve
        bcs ff_ret
        jsr new_fcb
        bcs ff_ret
        jsr open_dir
        bcs ff_ret
        ldy #0                 ; the directory's own name (FDOPEN shows it)
ff_dn   cpy fs_ent+6
        bcs ff_de
        lda fs_ent+7,y
        sta dir_name,y
        iny
        bne ff_dn
ff_de   lda #0
        sta dir_name,y
        ldx fs_fcb
        lda scan
        sta fc_scan,x
        lda #FL_DIR|FL_SRCH
        sta fc_flg,x
        jsr pat_adr            ; a blank name matches all, as on SDX
        ldy #0
        lda name
        bne ff2
        lda #'*'
        sta (zp_t),y
        iny
        lda #0
        sta (zp_t),y
        beq ff3
ff2     lda name,y
        sta (zp_t),y
        beq ff3
        iny
        cpy #EOS_NAME_SIZE
        bcc ff2
ff3     jsr f_next
        cmp #E_EOF             ; nothing found: the directory stays open
        beq ff_ret             ; (the caller closes it, as on SDX)
        cmp #$80
        bcc ff_ret
        pha                    ; another error: the handle is not kept
        ldx fs_fcb
        lda #$FF
        sta fc_drv,x
        pla
ff_ret  rts

* ---- 6 kd_next --------------------------------------------------------------
f_next  jsr find_fcb
        bcs fn_ret
        lda fc_flg,x
        bpl fn_nofn
        lda fc_scan,x
        sta fs_scn
        jsr pat_adr
        ldy #EOS_NAME_SIZE-1
fn0     lda (zp_t),y
        sta fs_pat,y
        dey
        bpl fn0
fn1     jsr dir_next
        bcs fn_ret
        jsr match
        bcs fn1
        ldx #EOS_DIRENT_SIZE-1
fn2     lda fs_ent,x
        sta dentry,x
        dex
        bpl fn2
        lda #E_OK
fn_ret  rts
fn_nofn lda #E_NOFUNC
        rts

* ---- 0 kd_read --------------------------------------------------------------
f_read  jsr find_fcb
        bcs fr_ret
        jsr set_mx
        lda addpos
        sta zp_q
        lda addpos+1
        sta zp_q+1
        lda bytbuf
        sta fs_cnt
        lda bytbuf+1
        sta fs_cnt+1
        jsr rd_core
        pha
        lda fs_done
        sta bytbuf
        lda fs_done+1
        sta bytbuf+1
        pla
fr_ret  rts

* ---- 7 kd_close -------------------------------------------------------------
f_close jsr find_fcb
        bcs fcl_ret
        stx fs_cfcb            ; cl_write uses the internal FCB
        lda fc_flg,x
        and #FL_WRITE
        beq fcl1
        jsr cl_write
        bcs fcl_ret
fcl1    ldx fs_cfcb
        lda #$FF
        sta fc_drv,x
        lda #E_OK
fcl_ret rts

* ---- 2 kd_pos, 3 kd_gtpos, 4 kd_gtlen ---------------------------------------
f_pos   jsr find_fcb
        bcs fp_ret
        lda fc_flg,x           ; open for writing: anywhere, past the end too
        and #FL_WRITE          ; (a sparse file, as SDX)
        bne fp_set
        lda fc_len0,x          ; read only: at most the length
        cmp addpos
        lda fc_len1,x
        sbc addpos+1
        lda fc_len2,x
        sbc addpos+2
        bcc fp_rng
fp_set  lda addpos
        sta fc_pos0,x
        lda addpos+1
        sta fc_pos1,x
        lda addpos+2
        sta fc_pos2,x
        lda #E_OK
fp_ret  rts
fp_rng  lda #E_RANGE
        rts

f_gtpos jsr find_fcb
        bcs fp_ret
        lda fc_pos0,x
        sta addpos
        lda fc_pos1,x
        sta addpos+1
        lda fc_pos2,x
        sta addpos+2
        lda #E_OK
        rts

f_gtlen jsr find_fcb
        bcs fp_ret
        lda fc_len0,x
        sta addpos
        lda fc_len1,x
        sta addpos+1
        lda fc_len2,x
        sta addpos+2
        lda #E_OK
        rts

* ---- 16 kd_chdir ------------------------------------------------------------
f_chdir jsr setdrv
        bcs fd_ret
        jsr resolve
        bcs fd_ret
        jsr name_dir
        bcs fd_ret
        ldx fs_drv
        lda fs_dmap
        sta dv_cwdlo,x
        lda fs_dmap+1
        sta dv_cwdhi,x
        lda #E_OK
fd_ret  rts

* ---- 17 kd_cwd: the current directory's path from the main one to path ----
* Each name (with its extension) after a CWD_SEP, $00 at the end; empty
* for the main directory (as on SDX: SUB, then DEEP.D, each after a
* backslash). Built from the end of path backwards, following
* each directory header's parent.
f_cwd   jsr setdrv
        jcs kc_ret
        jsr mount
        jcs kc_ret
        ldx fs_drv
        lda dv_cwdlo,x
        sta fs_dmap
        lda dv_cwdhi,x
        sta fs_dmap+1
        lda #'/'
cwd_bld sta fs_csep            ; fs_dmap's path with separator A to path
        lda #128
        sta fs_cwp
kc1     lda #NFCB
        sta fs_fcb
        jsr open_dir
        jcs kc_ret
        lda fs_ent+1           ; the main directory: done
        ora fs_ent+2
        beq kc_done
        ldx #0                 ; NAME.EXT of this directory to fs_cname
        ldy #0
kc2     cpy fs_ent+6
        bcs kc5
        lda fs_ent+7,y
        sta fs_cname,x
        inx
        iny
        bne kc2
kc5     txa
        sta fs_cwn
        lda fs_cwp
        sec
        sbc fs_cwn
        jcc kc_long
        sta fs_cwp
        tay
        ldx #0
kc7     lda fs_cname,x
        sta path,y
        iny
        inx
        cpx fs_cwn
        bcc kc7
        ldy fs_cwp             ; a separator before it
        dey
        bmi kc_long
        sty fs_cwp
        lda fs_csep
        sta path,y
        lda fs_ent+1           ; on to the parent
        sta fs_dmap
        lda fs_ent+2
        sta fs_dmap+1
        jmp kc1
kc_done ldx fs_cwp             ; move it to the start
        ldy #0
kc8     cpx #128
        bcs kc9
        lda path,x
        sta path,y
        inx
        iny
        bne kc8
kc9     lda #0
        sta path,y
        lda #E_OK
kc_ret  rts

* ---- 21 (EOS only) f_lpath: the directory of the file opened last to path,
* as U_LOAD leaves it on SDX: >SUB>DEEP.X> (> for the main directory)
f_lpath lda op_drv
        sta fs_drv
        jsr mount
        bcs lp_ret
        lda op_dmap
        sta fs_dmap
        lda op_dmap+1
        sta fs_dmap+1
        lda #'/'
        jsr cwd_bld
        bmi lp_ret
        ldy #0                 ; a > at its end
lp1     lda path,y
        beq lp2
        iny
        bne lp1
lp2     cpy #127
        bcs lp_ret
        lda #'/'
        sta path,y
        lda #0
        sta path+1,y
        lda #E_OK
lp_ret  rts
kc_long lda #E_PATHLEN
        rts

* ---- 19 kd_check: the disk's information to path, as GETDFREE returns it ----
* +0 EOSFS revision ($47/$48), +1 sector size code, +2 total sectors,
* +4 free sectors, +6 volume name, +$0E sequence number, +$0F random id
f_check jsr setdrv
        bcs ck_ret
        jsr mount
        bcs ck_ret
        lda #1
        sta fs_sec
        lda #0
        sta fs_sec+1
        jsr getsec
        bcs ck_ret
        ldy #32
        lda (zp_p),y
        sta path
        ldy #31
        lda (zp_p),y
        sta path+1
        ldx fs_drv
        lda dv_totlo,x
        sta path+2
        lda dv_tothi,x
        sta path+3
        lda dv_freelo,x
        sta path+4
        lda dv_freehi,x
        sta path+5
        ldy #22
ck1     lda (zp_p),y
        sta path+6-22,y
        iny
        cpy #30
        bcc ck1
        ldy #38
        lda (zp_p),y
        sta path+$0E
        iny
        lda (zp_p),y
        sta path+$0F
        lda #0
        sta path+$10
        lda #E_OK
ck_ret  rts

* ===========================================================================
* drives

* setdrv: fs_drv from the unit in device; C=1, A=status for a bad unit
setdrv  lda device
        and #$0F
        beq sd_err
        sec
        sbc #1
        cmp #NDRV
        bcs sd_err
        sta fs_drv
        clc
        rts
sd_err  lda #E_DRIVE
        sec
        rts

* mount: read the volume header of drive fs_drv. Every path operation does
* this, so a changed disk is noticed: its sequence number (counting header
* writes) or random id differ, the current directory goes back to the main
* one and the drive's cached sectors are forgotten. The same disk keeps
* them: only sector 1 is read again.
mount   ldx #NFCB-1            ; files open on the drive: the same disk
mt0     lda fc_drv,x
        cmp fs_drv
        jeq mt_keep
        dex
        bpl mt0
mt_do   jsr farcall            ; used less than a second ago: the same
        dta b(BK_DEV),a(CARTLO+$48) ; disk (dev.asm fw.icl mt_fresh)
        jcc mt_keep
        jsr flush_drv
        jcs mt_ret0
        ldx fs_drv             ; never mounted (or it failed): nothing kept
        lda dv_szlo,x
        ora dv_szhi,x
        bne mt_s1
        jsr drop_drv
mt_s1   lda #1                 ; sector 1 from the disk, not the cache
        sta fs_sec
        lda #0
        sta fs_sec+1
        jsr farcall            ; EOSFS helper-bank xd_drop
        dta b(BK_EOSX),a(CARTLO+$2D)
        ldx fs_drv
        lda dv_szhi,x          ; (the size it had: changed, nothing kept)
        sta fs_osz
        lda #128
        sta dv_szlo,x
        lda #0
        sta dv_szhi,x
        jsr getsec
        bcc mn_hdr
        cmp #138               ; no drive: no point in trying again
        beq mn_fail
        jsr drop_drv           ; not as 128 bytes: a 512-byte sector disk?
        ldx fs_drv
        lda #0
        sta dv_szlo,x
        lda #2
        sta dv_szhi,x
        jsr getsec
        bcs mn_fail
mn_hdr  ldy #32
        lda (zp_p),y
        cmp #$47               ; EOSFS v2, clean
        beq mn_ok
        cmp #$48               ; EOSFS v2, interrupted write
        beq mn_ok
        txa                    ; EOSFS-only resident driver
        jsr drop_but           ; keep no foreign filesystem state
        ldx fs_drv
        lda #0
        sta dv_szlo,x
        jsr drop_drv
        lda #E_BADFMT
        sec
mn_ret  rts
mn_fail pha                    ; (not mounted: dropped next time)
        ldx fs_drv
        lda #0
        sta dv_szlo,x
        sta dv_szhi,x
        pla
        sec
        rts
mn_ok   jsr farcall            ; helper-bank mn_rest: the file
        dta b(BK_EOSX),a(CARTLO+$1E) ; system, sizes, an EOSFS dirty flag's
                                     ; check) and another disk? C=1
        bcc mn_same
        jsr drop_drv           ; another disk: nothing kept
mn_same clc                    ; (sector 1 as 128 bytes is what reading it
        rts                    ; later gives on 128 and 256-byte disks)

mt_keep ldx fs_drv
        lda dv_szlo,x
        ora dv_szhi,x
        jeq mt_do              ; never mounted
        clc
mt_ret0 rts


* ===========================================================================
* sector cache

* getsec: sector fs_sec of drive fs_drv into the cache
* out: C=0, X = buffer, zp_p = its data; C=1, A = status on error
getsec  ldx #NBUF-1
gs1     lda bf_drv,x
        cmp fs_drv
        bne gs2
        lda bf_seclo,x
        cmp fs_sec
        bne gs2
        lda bf_sechi,x
        cmp fs_sec+1
        beq gs_hit
gs2     dex
        bpl gs1
        jsr victim
        bcc gs3
        rts
gs3     lda fs_drv
        sta bf_drv,x
        lda fs_sec
        sta bf_seclo,x
        lda fs_sec+1
        sta bf_sechi,x
        lda #0
        sta bf_dirty,x
        jsr farcall            ; the second-level cache first (E1)
        dta b(BK_DEV),a(CARTLO+$36)
        bcc gs_hit
        lda #'R'
        jsr sio_io
        bcc gs_hit
        pha
        lda #$FF
        sta bf_drv,x
        pla
        rts
gs_hit  jsr touch
        lda bf_lo,x
        sta zp_p
        lda bf_hi,x
        sta zp_p+1
        clc
        rts

* used_up: a file's data sector (buffer fs_ub) read or written to its end
* is the first to go (the drive's maps, bitmap and directories stay while
* a file streams through the cache)
used_up ldy fs_drv
        clc                    ; (eor keeps the carry)
        lda fs_off
        adc fs_n
        eor dv_szlo,y
        tax
        lda fs_off+1
        adc fs_n+1
        eor dv_szhi,y
        bne uu_ret
        txa
        bne uu_ret
        ldx fs_ub
        lda #$FF
        sta bf_age,x
uu_ret  rts

* touch: buffer X becomes the most recently used
touch   ldy #NBUF-1
tc1     lda bf_age,y
        cmp #$FF
        beq tc2
        adc #1                 ; C=0 here
        sta bf_age,y
tc2     dey
        bpl tc1
        lda #0
        sta bf_age,x
        rts

* victim: X = an empty buffer, or the least recently used one
victim  ldx #NBUF-1
vc1     lda bf_drv,x
        bmi vc_ret
        dex
        bpl vc1
        ldx #0
        ldy #NBUF-1
vc2     lda bf_age,y
        cmp bf_age,x
        bcc vc3
        tya
        tax
vc3     dey
        bne vc2
        lda bf_dirty,x         ; changed: to the disk first, and the changed
        beq vc_ret             ; sectors right after it with it (one for
        stx fs_keep            ; each read, they would cost a turn each)
vd1     jsr wr_buf
        bcs vd_ret
        ldy #NBUF-1
vd2     lda bf_dirty,y
        beq vd3
        lda bf_drv,y
        cmp bf_drv,x
        bne vd3
        lda bf_seclo,y         ; sector X + 1?
        clc
        sbc bf_seclo,x
        bne vd3
        lda bf_sechi,y
        sbc bf_sechi,x
        bne vd3
        tya
        tax
        bpl vd1                ; (always: a buffer number)
vd3     dey
        bpl vd2
        ldx fs_keep
vc_ret  jsr farcall            ; the sector it held to the second-level
        dta b(BK_DEV),a(CARTLO+$39) ; cache (E1)
        clc
vd_ret  rts

* blk_ctl: jblock_io's cache control for drive DUNIT: Y=2 its changed
* sectors to the disk (bm_flush), else its cached ones forgotten
* (bm_abort; bm_fread and bm_write around their transfers). A = status.
blk_ctl cld
        jsr k_romoff
        ldx DUNIT
        dex
        stx fs_drv
        cpy #2
        bne bc_drop
        jsr flush_drv
        bcs bc_x
        bcc bc_ok
bc_drop jsr drop_drv
bc_ok   lda #1
bc_x    jmp k_romon

* drop_drv: forget the cached sectors of drive fs_drv; drop_but: but
* buffer A
drop_drv lda #$FF
drop_but sta fs_keep
        jsr farcall            ; (the second-level cache forgets it too)
        dta b(BK_DEV),a(CARTLO+$3C)
        ldx #NBUF-1
dd1     cpx fs_keep
        beq dd2
        lda bf_drv,x
        cmp fs_drv
        bne dd2
        lda #$FF
        sta bf_drv,x
        sta bf_age,x
dd2     dex
        bpl dd1
        rts

* sio_io: A = SIO command, X = buffer (its drive and sector); keeps X
* C=1, A = status on error
sio_io  sta DCOMND
        stx fs_x
        lda #$31
        sta DDEVIC
        ldy bf_drv,x
        iny
        sty DUNIT
        dey
        lda #<fs_sbuf          ; SIO uses the OS, so a buffer in main RAM
        sta DBUFLO
        lda #>fs_sbuf
        sta DBUFHI
        lda bf_seclo,x
        sta DAUX1
        lda bf_sechi,x
        sta DAUX2
        lda dv_szlo,y
        sta DBYTLO
        lda dv_szhi,y
        sta DBYTHI
        cmp #1                 ; 256-byte sectors: 1 to 3 have 128 bytes
        bne sio2
        lda DAUX2
        bne sio2
        lda DAUX1
        cmp #4
        bcs sio2
        lda #128
        sta DBYTLO
        lda #0
        sta DBYTHI
sio2    lda #$40
        ldx DCOMND
        cpx #'R'
        beq sio3
        asl @
sio3    sta DSTATS
        lda #7
        sta DTIMLO
        lda hs_tab+1,y         ; the unit has an Ultra Speed rate and no
        beq sio_b              ; driver comes before _HSDRV: it reaches the
        bmi sio_b              ; cache under the OS ROM itself (no copy)
        lda sio_vector+1
        ora sio_vector+3
        ora sio_vector+5
        bne sio_b
        ldx fs_x
        lda bf_lo,x
        sta DBUFLO
        lda bf_hi,x
        sta DBUFHI
        bne sio4               ; (always)
sio_b   lda DSTATS
        cmp #$40
        beq sio4
        sec                    ; writing: from the cache first
        jsr bounce
sio4    jsr k_lsio             ; jsector_io: installed drivers, the RAM disk, SIO
sio4a   ldx fs_x
        tya
        bmi sio5
        lda DBUFHI             ; (straight to the cache)
        cmp #>fs_sbuf
        bne sio5a
        lda DCOMND             ; reading: to the cache
        cmp #'R'
        bne sio5a
        clc
        jsr bounce
sio5a   ldx fs_x
        lda #1
sio5    cmp #$80
        rts

* bounce: DBYT bytes between the cache buffer fs_x and fs_sbuf; C=1 cache
* to fs_sbuf, C=0 the other way (dev bank bounce.icl)
bounce  jsr farcall
        dta b(BK_DEV),a(CARTLO+$45)
        rts

* the cache is in the RAM under the OS ROM, as SDX keeps its data there
bf_lo   dta l(BF_DATA,BF_DATA+SECMAX,BF_DATA+2*SECMAX,BF_DATA+3*SECMAX)
        dta l(BF_DAT2,BF_DAT2+SECMAX,BF_DAT2+2*SECMAX)
bf_hi   dta h(BF_DATA,BF_DATA+SECMAX,BF_DATA+2*SECMAX,BF_DATA+3*SECMAX)
        dta h(BF_DAT2,BF_DAT2+SECMAX,BF_DAT2+2*SECMAX)
        ert NBUF<>7

* ===========================================================================
* files

* find_fcb: the FCB of handle file_id
* out: C=0, X = fs_fcb, fs_drv set; C=1, A = status
find_fcb ldx #NFCB-1
fb1     lda fc_drv,x
        bmi fb2
        lda fc_hnd,x
        cmp file_id
        beq fb3
fb2     dex
        bpl fb1
        lda #E_NOTOPEN
        sec
        rts
fb3     stx fs_fcb
        lda fc_drv,x
        sta fs_drv
        clc
        rts

* new_fcb: a free FCB and a free kernel handle (file_id)
* out: C=0, X = fs_fcb; C=1, A = status
new_fcb ldx #NFCB-1
nf1     lda fc_drv,x
        bmi nf2
        dex
        bpl nf1
nf_err  lda #E_TOOMANY
        sec
        rts
nf2     ldy #0
nf3     lda dev_index,y
        cmp #$FF
        beq nf4
        iny
        cpy #16
        bcc nf3
        bcs nf_err
nf4     sty file_id
        tya
        sta fc_hnd,x
        stx fs_fcb
        lda fs_drv
        sta fc_drv,x
        clc
        rts

* fcb_rewind: position 0, no sector map looked up yet (X = FCB)
fcb_rewind lda #0
        sta fc_pos0,x
        sta fc_pos1,x
        sta fc_pos2,x
        sta fc_cmlo,x
        sta fc_cmhi,x
        sta fc_cblo,x
        sta fc_cbhi,x
        rts

* pat_adr: zp_t = the 32-byte name pattern of FCB fs_fcb
pat_adr lda fs_fcb
        asl @
        asl @
        asl @
        asl @
        asl @                  ; 32 * FCB
        adc #<fc_pat
        sta zp_t
        lda #>fc_pat
        adc #0
        sta zp_t+1
        rts

* locate: data sector for the position of FCB fs_fcb
* out: fs_sec (0: none, reads as zeros), fs_off; C=1, A = status on error
locate  lda #0
        sta fs_new
        ldx fs_fcb
        ldy fs_drv
        lda fc_pos0,x
        sta fs_off
        lda fc_pos1,x
        sta fs_idx
        lda fc_pos2,x
        sta fs_idx+1
        lda #0
        sta fs_off+1
        lda dv_shf,y
        cmp #8
        beq lc_map
        bcc lc_7
        lsr fs_idx+1           ; 512: index = pos >> 9
        ror fs_idx
        rol fs_off+1
        jmp lc_map
lc_7    lda fs_off             ; 128: index = pos >> 7
        asl @
        rol fs_idx
        rol fs_idx+1
        lda fs_off
        and #$7F
        sta fs_off
lc_map  jsr is_x
        jmp locate_x
lc_none lda #0
        sta fs_sec
        sta fs_sec+1
        clc
        rts

* rd_map: the current sector map of FCB fs_fcb into the cache (zp_p);
* keeps X = fs_fcb
rd_map  ldx fs_fcb
        lda fc_cmlo,x
        sta fs_sec
        lda fc_cmhi,x
        sta fs_sec+1
        jsr getsec
        stx fs_buf
        ldx fs_fcb
        rts

* rd_core: read fs_cnt bytes of FCB fs_fcb to (zp_q)
* out: fs_done bytes read; A = status (E_EOF when the file ended first),
* C=1 unless E_OK
rd_core lda #0
        sta fs_done
        sta fs_done+1
rc_loop lda fs_cnt
        ora fs_cnt+1
        bne rc1
        lda #E_OK
        clc
        rts
rc1     ldx fs_fcb             ; fs_t = bytes left in the file, at most $FFFF
        sec
        lda fc_len0,x
        sbc fc_pos0,x
        sta fs_t
        lda fc_len1,x
        sbc fc_pos1,x
        sta fs_t+1
        lda fc_len2,x
        sbc fc_pos2,x
        bcc rc_eof
        bne rc_big
        lda fs_t
        ora fs_t+1
        bne rc2
rc_eof  lda #E_EOF
        sec
        rts
rc_big  lda #$FF
        sta fs_t
        sta fs_t+1
rc2     jsr locate
        bcc rc2a
        rts
rc2a    ldy fs_drv             ; fs_n = min(bytes left in the sector, fs_cnt, fs_t)
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
        lda fs_t
        ldx fs_t+1
        jsr min_n
        lda fs_sec
        ora fs_sec+1
        beq rc_zero
        jsr getsec
        bcs rc_ret
        stx fs_ub
        clc
        lda zp_p
        adc fs_off
        sta zp_p
        lda zp_p+1
        adc fs_off+1
        sta zp_p+1
        jsr copy_n
        jsr used_up
        jmp rc_adv
rc_zero jsr zero_n
rc_adv  ldx fs_fcb
        clc
        lda fc_pos0,x
        adc fs_n
        sta fc_pos0,x
        lda fc_pos1,x
        adc fs_n+1
        sta fc_pos1,x
        bcc rc3
        inc fc_pos2,x
rc3     sec
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
        jmp rc_loop
rc_ret  rts

* min_n: fs_n = min(fs_n, XA)
min_n   cpx fs_n+1
        bcc mi_set
        bne mi_ret
        cmp fs_n
        bcs mi_ret
mi_set  sta fs_n
        stx fs_n+1
mi_ret  rts

* set_mx: fs_mx = the PORTB value (ROM off) for the caller's buffer in
* memory memreix; main memory: 0, or 1 when the caller has the OS ROM on
* (copy_w then reads the ROM there). Keeps X.
set_mx  lda memreix
        bne sm_bank
        lda k_pbsave
        and #$01
        bpl sm_set             ; (always)
sm_bank stx fs_mxx
        jsr k_tconv
        and #$FE
        ldx fs_mxx
sm_set  sta fs_mx
        rts

* mx_on, mx_off: the caller's memory in and out around a copy (keep A, X, Y)
mx_on   pha
        lda fs_mx              ; (0 or 1: main memory)
        cmp #2
        bcc mo_ret
        lda PORTB
        sta fs_mxp
        lda fs_mx
        sta PORTB
mo_ret  pla
        rts
mx_off  pha
        lda fs_mx
        cmp #2
        bcc mo_ret
        lda fs_mxp
        sta PORTB
        pla
        rts

* copy_n: fs_n bytes from (zp_p) to (zp_q); zp_q moves past them
copy_n  jsr mx_on
        jsr copy_n0
        jmp mx_off
copy_n0 ldy #0
        ldx fs_n+1
        beq cn2
cn1     lda (zp_p),y
        sta (zp_q),y
        iny
        bne cn1
        inc zp_p+1
        inc zp_q+1
        dex
        bne cn1
cn2     ldx fs_n
        beq cn4
cn3     lda (zp_p),y
        sta (zp_q),y
        iny
        dex
        bne cn3
        tya
        clc
        adc zp_q
        sta zp_q
        bcc cn4
        inc zp_q+1
cn4     rts

* zero_n: fs_n zeros to (zp_q); zp_q moves past them
zero_n  ldy #0
        lda #0
        ldx fs_n+1
        beq zn2
zn1     sta (zp_q),y
        iny
        bne zn1
        inc zp_q+1
        dex
        bne zn1
zn2     ldx fs_n
        beq zn4
zn3     sta (zp_q),y
        iny
        dex
        bne zn3
        tya
        clc
        adc zp_q
        sta zp_q
        bcc zn4
        inc zp_q+1
zn4     rts

* ===========================================================================
* directories

* open_dir: FCB fs_fcb reads the directory fs_dmap; its header goes to
* fs_ent and the position to the first entry. C=1, A = status on error.
open_dir ldx fs_fcb
        lda fs_dmap
        sta fc_maplo,x
        lda fs_dmap+1
        sta fc_maphi,x
        lda #$FF
        sta fc_len0,x
        sta fc_len1,x
        sta fc_len2,x
        lda fs_drv
        sta fc_drv,x
        jsr fcb_rewind
        jsr dir_read
        bcs od_ret
        ldx fs_fcb
        lda fs_ent+3
        sta fc_len0,x
        lda fs_ent+4
        sta fc_len1,x
        lda fs_ent+5
        sta fc_len2,x
od_ret  rts

* dir_read: the next fixed-size v2 directory record to fs_ent
dir_read lda #<fs_ent
        sta zp_q
        lda #>fs_ent
        sta zp_q+1
        lda #EOS_DIRENT_SIZE
        sta fs_cnt
        lda #0
        sta fs_cnt+1
        jmp rd_core

* dir_next: the next live entry to fs_ent; C=1 at the end (A = E_EOF)
dir_next jsr dir_read
        bcs dn_ret
        lda fs_ent
        beq dn_end
        and #ST_USED|ST_DEL
        cmp #ST_USED
        bne dir_next
        clc
dn_ret  rts
dn_end  lda #E_EOF
        sec
        rts

* scan_name: find name (page 7) with attributes fs_scn in directory fs_dmap,
* using the internal FCB. Out: fs_ent; C=1, A = status (E_EOF: none).
scan_name lda #NFCB
        sta fs_fcb
        jsr open_dir
        bcs sn_ret
        ldx #EOS_NAME_SIZE-1
sn0     lda name,x
        sta fs_pat,x
        dex
        bpl sn0
sn1     jsr dir_next
        bcs sn_ret
        jsr match
        bcs sn1
sn_ret  rts

* match: does fs_ent match the NUL-ended glob fs_pat? '?' matches one byte
* and '*' matches zero or more bytes. Matching is exact-case and bounded by
* the entry's stored name length. C=0 yes, after checking attributes.
match   ldx #0                 ; pattern offset
        ldy #0                 ; entry-name offset
        lda #$FF
        sta fs_keep            ; no '*' backtrack point yet
mt1     lda fs_pat,x
        beq mt_end
        cmp #'*'
        beq mt_star
        cpy fs_ent+6
        bcs mt_retry
        cmp #'?'
        beq mt_take
        cmp fs_ent+7,y
        bne mt_retry
mt_take inx
        iny
        bne mt1
mt_star inx                    ; remember the pattern after '*' and current
        stx fs_keep            ; name position; retry grows the '*' match
        sty fs_lim
        jmp mt1
mt_retry lda fs_keep
        cmp #$FF
        beq mt_no
        ldy fs_lim
        cpy fs_ent+6
        bcs mt_no
        iny
        sty fs_lim
        ldx fs_keep
        jmp mt1
mt_end cpy fs_ent+6
        bne mt_retry
        lda fs_ent             ; attributes as P H A D in bits 0-3
        and #ST_PROT|ST_HID|ST_ARC
        sta fs_t
        lda fs_ent
        and #ST_DIR
        beq mt3
        lda #$08
        ora fs_t
        sta fs_t
mt3     lda fs_t               ; every "only" bit (0-3) must be set
        eor #$0F
        and fs_scn
        and #$0F
        bne mt_no
        lda fs_scn             ; no "not" bit (4-7) may be set
        lsr @
        lsr @
        lsr @
        lsr @
        and fs_t
        bne mt_no
        clc
        rts
mt_no   sec
        rts

* name_dir: when name is not blank, fs_dmap becomes its subdirectory
name_dir ldx #EOS_NAME_SIZE-1
nd1     lda name,x
        sta fs_cname,x
        dex
        bpl nd1
        lda fs_cname
        bne find_dir
        clc
        rts

* find_dir: fs_dmap becomes its subdirectory fs_cname; C=1, A = status.
* Also fs_pmap = the directory it was in, fs_epos = its entry there.
find_dir lda fs_dmap
        sta fs_pmap
        lda fs_dmap+1
        sta fs_pmap+1
        lda #NFCB
        sta fs_fcb
        jsr open_dir
        bcs fdr_ret
fdr1    jsr dir_next
        bcs fdr_nf
        lda fs_ent
        and #ST_DIR
        beq fdr1
        ldy #0
fdr2    lda fs_cname,y
        beq fdr2e
        cpy fs_ent+6
        bcs fdr1
        cmp fs_ent+7,y
        bne fdr1
        iny
        bne fdr2
fdr2e   cpy fs_ent+6
        bne fdr1
fdr3    jsr ent_pos
        lda fs_ent+1
        sta fs_dmap
        lda fs_ent+2
        sta fs_dmap+1
        clc
        rts
fdr_nf  cmp #E_EOF
        bne fdr_err
        lda #E_PATH
fdr_err sec
fdr_ret rts

* parent: fs_dmap becomes its parent directory (the main one stays)
parent  lda #NFCB
        sta fs_fcb
        jsr open_dir
        bcs pa_ret
        lda fs_ent+1
        ora fs_ent+2
        beq pa_ret
        lda fs_ent+1
        sta fs_dmap
        lda fs_ent+2
        sta fs_dmap+1
        clc
pa_ret  rts

* resolve: mount drive fs_drv, then walk path (page 7) from the current
* directory, or from the main one after a leading slash. Components are
* separated by slash; .. goes up and . stays. Out: fs_dmap.
resolve jsr mount
        jcs rs_ret
        ldx fs_drv
        lda dv_cwdlo,x
        sta fs_dmap
        lda dv_cwdhi,x
        sta fs_dmap+1
        ldy #0
        lda path
        cmp #'/'
        beq rs_root
        bne rs_loop
rs_root lda dv_mainlo,x
        sta fs_dmap
        lda dv_mainhi,x
        sta fs_dmap+1
        iny
rs_loop lda path,y
        beq rs_ok
        cmp #'/'
        beq rs_sep
        jsr getcomp
        bcs rs_ret
        pha                    ; getcomp's kind while normalizing one slash
        lda path,y
        cmp #'/'
        bne rs_comp
        iny
rs_comp pla
        cmp #1
        beq rs_loop
        cmp #2
        beq rs_up
        tya
        pha
        jsr find_dir
        bcs rs_callerr
        pla
        tay
        jmp rs_loop
rs_up   tya
        pha
        jsr parent
        bcs rs_callerr
        pla
        tay
        jmp rs_loop
rs_callerr sta fs_t
        pla
        lda fs_t
        sec
        rts
rs_sep  iny
        jmp rs_loop
rs_ok   clc
rs_ret  rts

* getcomp: the path component at path+Y in internal form to fs_cname
* out: Y past it; A = 0 a name, 1 ".", 2 ".."
getcomp ldx #EOS_NAME_MAX
        lda #0
gc0     sta fs_cname,x
        dex
        bpl gc0
        lda path,y
        cmp #'.'
        bne gc_name
        lda path+1,y
        jsr is_sep
        bne gc_dd
        iny
        lda #1
        clc
        rts
gc_dd   cmp #'.'
        bne gc_name
        lda path+2,y
        jsr is_sep
        bne gc_name
        iny
        iny
        lda #2
        clc
        rts
gc_name ldx #0
gc1     lda path,y
        jsr is_sep
        beq gc_end
        iny
        cpx #EOS_NAME_MAX
        bcs gc_long
        sta fs_cname,x
        inx
        bne gc1
gc_end  lda #0
        sta fs_cname,x
        clc
        rts
gc_long lda #E_PATHLEN
        sec
        rts

* is_sep: Z=1 for the end of a path component (NUL or slash)
is_sep  cmp #0
        beq is_ret
        cmp #'/'
        beq is_ret
is_ret  rts

        icl 'fmsw.icl'
        icl 'fmsx.icl'

        icl 'tail.icl'
