* DSK: file system data, uninitialised RAM under the OS ROM ($C200 up): the
* FMS runs with the ROM off (fms.asm f_initz clears it). The SIO buffer is
* in main RAM (fms_sbuf.icl), as SIO runs with the ROM on. Included at the
* end of kernel.asm.

NDRV    equ 15                 ; D1: ... D15:
NFCB    equ 8                  ; files open at once on DSK:
NFCB1   equ NFCB+1             ; + one control block for internal directory reads
NBUF    equ 7                  ; fixed: v2/shell state reaches $C7A7
SECMAX  equ 512

* ---- drives, indexed by unit-1 ----------------------------------------
dv_szlo .ds NDRV               ; sector size, 0 = not mounted
dv_szhi .ds NDRV
dv_shf  .ds NDRV               ; log2 of the sector size: 7, 8 or 9
dv_ments .ds NDRV              ; extents per list sector: 31, 63, 127
dv_mainlo .ds NDRV             ; main directory map
dv_mainhi .ds NDRV
dv_totlo .ds NDRV              ; total sectors
dv_tothi .ds NDRV
dv_freelo .ds NDRV             ; free sectors
dv_freehi .ds NDRV
dv_nbmp .ds NDRV               ; bitmap sectors
dv_bmaplo .ds NDRV             ; first bitmap sector
dv_bmaphi .ds NDRV
dv_seq  .ds NDRV               ; volume sequence number and random id, to see
dv_rnd  .ds NDRV               ; when the disk changed
dv_cwdlo .ds NDRV              ; current directory map
dv_cwdhi .ds NDRV
dv_hintlo .ds NDRV             ; where to look for a free sector
dv_hinthi .ds NDRV
dv_hdirty .ds NDRV             ; not 0: free count or hint not written yet
dv_bitslo .ds NDRV             ; sectors that have a bitmap bit
dv_bitshi .ds NDRV

* ---- file control blocks; FCB NFCB is for internal directory reads ------
fc_drv  .ds NFCB1              ; drive (unit-1), $FF = free
fc_hnd  .ds NFCB1              ; kernel handle (file_id)
fc_flg  .ds NFCB1              ; FL_* below
fc_maplo .ds NFCB1             ; first extent-list sector
fc_maphi .ds NFCB1
fc_len0 .ds NFCB1              ; length
fc_len1 .ds NFCB1
fc_len2 .ds NFCB1
fc_pos0 .ds NFCB1              ; read/write position
fc_pos1 .ds NFCB1
fc_pos2 .ds NFCB1
fc_cmlo .ds NFCB1              ; extent-list sector in use, 0 = none yet
fc_cmhi .ds NFCB1
fc_cblo .ds NFCB1              ; index of its first data sector in the file
fc_cbhi .ds NFCB1
fc_scan .ds NFCB1              ; kd_first: search attributes
fc_dmlo .ds NFCB1              ; written files: the directory with the
fc_dmhi .ds NFCB1              ; entry, and the entry's position in it
fc_eplo .ds NFCB1
fc_ephi .ds NFCB1
fc_pat  .ds NFCB*EOS_NAME_SIZE ; kd_first: NUL-ended name pattern per FCB

FL_DIR  equ $80                ; a directory
FL_SRCH equ $40                ; opened by kd_first
FL_WRITE equ $20               ; open for writing
FL_EDIRTY equ $10              ; the directory entry needs updating
fs_kdt  .ds 1                  ; dateset at the open (fo_write)
FL_KEEPDT equ $08              ; dateset was set at the open: the date stays
FL_UPD  equ $01                ; byte-window update mode

* ---- sector cache --------------------------------------------------------
bf_drv  .ds NBUF               ; drive, $FF = empty
bf_seclo .ds NBUF
bf_sechi .ds NBUF
bf_age  .ds NBUF               ; 0 = most recently used
bf_dirty .ds NBUF
bo_dir  .ds 1                  ; bounce: 1 cache to fs_sbuf
BF_DATA equ $D800              ; 4 buffers of SECMAX bytes under the OS ROM
BF_DAT2 equ $C800              ; and 3 more, after the enlarged v2 state
BW_SAVE equ $CE00              ; BW-DOS programs: EOS's page 7 meanwhile (bw.icl)
BW_IMG  equ $CF00              ; and the BW-DOS page 7

* ---- working variables -----------------------------------------------------
fs_drv  .ds 1                  ; drive of the current operation
fs_fcb  .ds 1                  ; FCB of the current operation
fs_sec  .ds 2                  ; sector number
fs_off  .ds 2                  ; byte offset in that sector
fs_idx  .ds 2                  ; data sector index in the file
fs_cnt  .ds 2                  ; bytes still to transfer
fs_done .ds 2                  ; bytes transferred
fs_n    .ds 2                  ; bytes in this step
fs_dmap .ds 2                  ; directory map while resolving a path
fs_ent  .ds EOS_DIRENT_SIZE    ; directory entry being looked at
fs_scn  .ds 1                  ; search attributes for match
fs_pat  .ds EOS_NAME_SIZE      ; NUL-ended name pattern for match
fs_rel  .ds 1                  ; extent index within an extent-list sector
fs_t    .ds 2
fs_x    .ds 1
fs_keep .ds 1                  ; drop_but's buffer
fs_osz  .ds 1                  ; mount: the sector size before
fs_ub   .ds 1                  ; used_up: the data sector's buffer
fs_nz   .ds 1                  ; newsec: bit 7 not zeroed
fs_lim  .ds 1                  ; end of the name or extension field
d_x     .ds 1                  ; byte-window / header-hook scratch
d_y     .ds 1
d_t     .ds 2
d_v     .ds 3
d_n     .ds 3
d_k     .ds 1
d_wr    .ds 1                  ; getbyte: bit 7 stores d_c (update)
rt_y    .ds 1                  ; byte-window wrapper: kernel function
fs_mx   .ds 1                  ; PORTB for the caller's buffer, 0 main
fs_mxp  .ds 1
fs_mxx  .ds 1
fs_csep .ds 1                  ; kd_cwd's separator
op_drv  .ds 1                  ; the directory of the file opened last
op_dmap .ds 2
fs_cwp  .ds 1                  ; kd_cwd: where the path starts in path
fs_cwn  .ds 1
fs_cname .ds EOS_NAME_SIZE     ; path component, NUL ended
fs_ent2 .ds EOS_DIRENT_SIZE
fs_epos .ds 2                  ; position of an entry in its directory
fs_pmap .ds 2                  ; find_dir: the parent directory
fs_dlen .ds 2                  ; directory length before a new entry
fs_l    .ds 3
cl_map  .ds 2
cd_map  .ds 2                  ; kd_credir: the new directory's map
fs_cfcb .ds 1
fs_st   .ds 1
xs_j    .ds 1                  ; EOSFS (fmsx.icl): an extent's number
xs_lj   .ds 1                  ; the last one's
xs_b    .ds 2                  ; the file's sector index where it starts
xs_s    .ds 2                  ; its start
xs_c    .ds 2                  ; its count
xs_t    .ds 2                  ; EOSFS scratch (fs_t belongs to rd_core)
fs_hits .ds 1
fs_alloc .ds 1                 ; locate: not 0 allocates missing sectors
fs_new  .ds 1                  ; locate: $FF the data sector is new
fs_buf  .ds 1                  ; rd_map: the map's buffer
al_s    .ds 2                  ; alloc, free_sec: the sector
al_n    .ds 2
al_mask .ds 1
bp_off  .ds 2
tr_m    .ds 2                  ; free_chain
tr_i    .ds 1
tr_need .ds 2                  ; trim: data sectors the file needs
rn_dm   .ds 2                  ; rename: the parent directory and the entry
rn_ep   .ds 2                  ; while a directory's header is renamed
fl_p    .ds 1                  ; flush_drv: $FF its last pass (the header)
l2_x    .ds 1                  ; the second-level cache (dev bank l2.icl):
l2_y    .ds 1                  ; a buffer, a slot, the copy's direction,
l2_dir  .ds 1                  ; an age or a page count
l2_age  .ds 1
d_hint  .ds 1                  ; EOSFS helper-bank cache-buffer hint
                               ; (dev.asm d_spec; cleared after each call)
dm_d    .ds 1                  ; the drive the FMS used last ($FF none) and
dm_t    .ds 2                  ; when (RTCLOK+1, +2): mount (dev.asm mt_fresh)
fw_s    .ds 1                  ; the byte window (kernel kf_io, dev.asm fw.icl):
                               ; its first byte's address (low)
