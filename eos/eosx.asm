* EOS (Extendable Operating System): bank 7, EOSFS support routines that do
* not fit in the primary FMS bank. Foreign filesystems are handled by
* transient Toolkit programs and are never dispatched through this bank.

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
        jmp x_nofunc           ; $A000 old foreign-filesystem dispatcher
        jmp free_x             ; $A003 EOSFS: free a file's extents (eosx.icl)
        jmp trim_x             ; $A006 EOSFS: trim a written file
        jmp x_nofunc           ; $A009 old format detector
        jmp x_nofunc           ; $A00C old directory index
        jmp x_nofunc           ; $A00F
        jmp x_nofunc           ; $A012
        jmp x_nofunc           ; $A015
        jmp x_nofunc           ; $A018
        jmp x_nofunc           ; $A01B
        jmp mn_rest            ; $A01E the FMS's mount: the volume header's fields
        jmp x_noop             ; $A021 reserved
        jmp xdirect            ; $A024 the FMS's whole new sector, no cache
        jmp xcopyw             ; $A027 the FMS's copy_w
        jmp hd_hook            ; $A02A the FMS's wr_buf: EOSFS's dirty flag
        jmp xd_drop            ; $A02D the FMS's mount: sector fs_sec dropped
        jmp x_gapwrite         ; $A030 write inside an EOSFS sparse gap

x_nofunc lda #E_NOFUNC
        sec
x_noop  rts


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


* the FMS's cache buffers (as fms.asm bf_lo, bf_hi)
xbf_lo  dta l(BF_DATA,BF_DATA+SECMAX,BF_DATA+2*SECMAX,BF_DATA+3*SECMAX)
        dta l(BF_DAT2,BF_DAT2+SECMAX,BF_DAT2+2*SECMAX,BF_DAT2+3*SECMAX)
xbf_hi  dta h(BF_DATA,BF_DATA+SECMAX,BF_DATA+2*SECMAX,BF_DATA+3*SECMAX)
        dta h(BF_DAT2,BF_DAT2+SECMAX,BF_DAT2+2*SECMAX,BF_DAT2+3*SECMAX)

        icl 'eosx.icl'

* Load the current FCB's extent-list sector for gapx.icl.
gap_rdmap ldx fs_fcb
        lda fc_cmlo,x
        sta fs_sec
        lda fc_cmhi,x
        sta fs_sec+1
        jsr getsec
        bcs grm_ret
        stx fs_buf
grm_ret rts

        icl 'gapx.icl'

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
xcw_rom lda fs_n               ; counted down in EOSFS scratch
        sta xs_t
        lda fs_n+1
        sta xs_t+1
        ldy #0
xcr1    lda xs_t
        ora xs_t+1
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
xcr2a   lda xs_t
        bne xcr2b
        dec xs_t+1
xcr2b   dec xs_t
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
* mn_rest: the FMS's mount, sector 1 at zp_p, A its EOSFS v2 revision byte
* ($47 clean, $48 left with changes not all written): the filesystem size
* and the rest of the header; C=1 another disk. A $48
* volume gets its quick check (mn_chk).
mn_rest ldx fs_drv
        sta d_k
        ldy #33
        lda (zp_p),y
        sta dv_szlo,x
        iny
        lda (zp_p),y
        sta dv_szhi,x
mn_sz   ldy dv_szhi,x          ; 0, 1, 2: 128, 256, 512 bytes
        lda shf_tab,y
        sta dv_shf,x
        lda xments_tab,y
        sta dv_ments,x
mr1     jsr mn_hdr2
        php
        lda d_k
        cmp #$48
        bne mr2
        jsr mn_chk
mr2     plp
        rts
shf_tab dta b(7,8,9)
xments_tab dta b(31,63,127)    ; EOSFS: extents per list sector

* mn_chk: the quick check of an EOSFS volume whose header says changes
* were not all written (EOS stopped while writing): the free count again
* from the bitmap (its set bits), the header written clean ($47). CHKDSK /F
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
        lda #$47
        sta (zp_p),y
        jsr dirty
        jsr flush
mc_r    rts

* hd_hook: from the FMS's wr_buf, buffer X about to be written. On an
* EOSFS drive the header's revision byte says $48 while changes are not
* all on the disk: before the first other sector since the header was
* last written clean, sector 1 goes to the disk with $48 (read and written
* through fs_sbuf, the cache left alone); the header itself is written
* with $48, or $47 in flush_drv's last pass (fl_p $FF: all else is on the
* disk). dv_hdirty bit 6: $48 is on the disk.
hd_hook bit fw_h               ; a sector written: the byte window first
        bmi hh0
        jsr farcall            ; (dev.asm fw_keep)
        dta b(BK_DEV),a(CARTLO+$30)
hh0     lda bf_drv,x
        tay
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
        lda #$47
        bit fl_p
        bmi hh1
        lda dv_hdirty,y
        ora #$40
        sta dv_hdirty,y
        lda #$48
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
hh_wr   lda #$48
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

        icl 'tail.icl'
