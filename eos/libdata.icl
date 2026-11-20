* library working variables, uninitialised RAM after the kernel image.
* Included at the end of kernel.asm.

ge_end  .ds 1                  ; U_GEFINA
ge_ns   .ds 1
ge_lim  .ds 1
ge_n    .ds 1
ge_dv   .ds 1
ge_u    .ds 1
ge_rawp .ds 65                 ; U_GEPATH: the path as given
ge_stop .ds 1                  ; where the specification ended
fs_fn   .ds 1
fg_y    .ds 1                  ; FGETC
fg_b    .ds 1
fg_st   .ds 1
pc_a    .ds 1                  ; PUTC
pc_x    .ds 1
pc_y    .ds 1
pc_fid  .ds 1
pc_st   .ds 1
pc_save .ds 5
NIZ     equ 5                  ; S_ADDIZ: reset routines
iz_n    .ds 1
os_vs   .ds 6                  ; the OS's serial interrupt vectors (cold start)
kv_vs   .ds 6                  ; k_siov: a program's meanwhile, its POKMSK, SSKCTL
kv_pm   .ds 1
kv_sk   .ds 1
fd_nf   .ds 1                  ; FDOPEN: bit 7 errors returned (D: mode 6)
dn_dir  .ds 1                  ; D: open: BW-DOS's 4+32 (a directory, raw)
bw_on   .ds 1                  ; bit 7: a BW-DOS program runs (bw.icl)
bw_y    .ds 1                  ; k_bwdh: the entry
bw_a    .ds 1
bw_tdt  .ds 6
bw_bl   .ds 1                  ; k_bwdh: a name's address in page 7
bw_bh   .ds 1
bw_buf  .ds 64                 ; and its copy                  ; GETTD, SETTD: the date and time
res_ml  .ds 2                  ; MEMLO at the prompt: put back at a reset
iz_lo   .ds NIZ
iz_hi   .ds NIZ
iz_lv   .ds NIZ
sn_p    .ds 2                  ; S_NEXT: the next record
sn_rom  .ds 1                  ; $FF: in the system's table
ev_n    .ds 1                  ; GETENV, NUMENV, PUTENV
ev_s    .ds 2                  ; the environment (lib2 env.icl): offsets
ev_e    .ds 2
ev_o    .ds 2
ev_v    .ds 2
ev_t    .ds 2
ev_a    .ds 1
ev_dirf .ds 1
ev_x2   .ds 1
vs_sp   .ds 1                  ; V_setme stack
vs_x    .ds 1
vs_stk  .ds 16
ma_t    .ds 2                  ; MALLOC
dv_on   .ds 2                  ; DIVIO: output, input redirected
dv_sv   .ds 2                  ; the handles before
dv_t    .ds 1
fd_mode .ds 1                  ; FDOPEN: the format
fd_st   .ds 1                  ; 0 header, 1 entries, 2 free, 3 end
fd_pos  .ds 1                  ; the line in LBUF: next byte, length
fd_len  .ds 1
fd_have .ds 1                  ; not 0: dentry holds the next entry
fd_hnd  .ds 1                  ; the directory's handle
fd_dev  .ds 1
fd_shf  .ds 1                  ; log2 of the sector size
fd_vol  .ds 8                  ; the volume name
fd_v    .ds 4                  ; a number to print
fd_w    .ds 1
fd_dig  .ds 10
fd_t    .ds 1
xb_n    .ds 1                  ; extended memory banks (kept over a reset)
xb_cur  .ds 1                  ; MALLOC $04: the bank in use (index), the
xb_ptr  .ds 2                  ; first free byte in it
bk_x    .ds 1
bk_c    .ds 1                  ; banks: the byte at $C000 under the ROM
f_level .ds 16                 ; SYSLEVEL at each file's open (FCLOSEAL)
fs_len  .ds 1                  ; FGETS, FPUTS
fs_fid  .ds 1
fs_y    .ds 1
gk_a    .ds 1                  ; U_GETKEY
xr_a    .ds 1                  ; XRWMEM
xr_x    .ds 1
md_a    .ds 4                  ; MUL_32, DIV_32 (little endian)
md_b    .ds 4
md_r    .ds 4
md_t    .ds 4
pf_vfid .ds 1                  ; VPRINTF: file_id to restore
pf_a    .ds 1                  ; PRINTF
pf_x    .ds 1
pf_y    .ds 1
pf_file .ds 1
pf_inv  .ds 1
pf_ptr  .ds 2
pf_arg  .ds 2
pf_sp   .ds 2
pf_zero .ds 1
pf_w    .ds 1
pf_n    .ds 1
pf_v    .ds 4
pf_dig  .ds 10
pf_bn   .ds 1                  ; PRINTF's output: pf_bn characters in pf_buf
pf_sx   .ds 1
pf_x2   .ds 1
pf_y2   .ds 1
pf_buf  .ds 16
dv_n    .ds 1                  ; drvname: the drive, its name
dv_nm   .ds 5
gn_off  .ds 1                  ; U_GETNUM, U_GETADR
ga_idx  .ds 1
ga_hasi .ds 1
ga_y    .ds 1
ga_op   .ds 1
ga_sym  .ds 1                  ; bit 7: the last U_GETADR was a symbol alone
ga_prev .ds 1                  ; (and before this one)
ga_n    .ds 2
gn_d    .ds 1
gn_t    .ds 4
sl_n    .ds 1                  ; U_SLASH
uf_err  .ds 1                  ; U_FAIL
uf_sp   .ds 1
uf_x    .ds 1
uf_t    .ds 1                  ; the trap that catches the error
uf_buf  .ds 40                 ; ERR_GMSG
NTRAP   equ 10                 ; U_SFAIL traps
tr_n    .ds 1
tr_lo   .ds NTRAP
tr_hi   .ds NTRAP
tr_sp   .ds NTRAP
tr_bank .ds NTRAP
ga_sign .ds 1                  ; U_GETATR
ga_set  .ds 1

cp_fid  .ds 1                  ; command processor: TYPE's file
cp_bat  .ds 1                  ; handle of the running batch file, $FF none
cp_cold .ds 1                  ; not 0: run the startup batch file
cp_i    .ds 1
cp_fail .ds 1                  ; U_FAIL: the error that ended the last command
cp_inb  .ds 1                  ; not 0: the command processor's own command runs
cp_echo .ds 1                  ; bit 7: ECHO ON
cp_erron .ds 1                 ; bit 7: ERROR ON
cp_pct  .ds 1                  ; bit 7: % parameters are replaced (batch line)
cp_x    .ds 1
cp_y    .ds 1
cp_d    .ds 1
cp_fl   .ds 1
cp_lim  .ds 1
cp_ro   .ds 1                  ; redir: >> seen
cp_ri   .ds 1                  ; redir: << seen
cp_xone .ds 1                  ; bit 7: XCOMLI's one line runs
cp_osp  .ds 1                  ; its caller's stack pointer
cp_olv  .ds 1                  ; and SYSLEVEL
NRD     equ 3                  ; RAM disks at once, as SDX
rd_unit .ds NRD                ; each RAM disk's drive (1-15), 0 none (kept over a reset)
rd_first .ds NRD               ; its first bank (memory index)
rd_n    .ds NRD                ; and its banks
rd_cx   .ds 1                  ; k_rdfind: the one found; RAMDISK: the entry taken
cfg_use .ds 1                  ; USE: 0 none, 1 OSRAM, 2 BANKED (kept over a reset)
sx_ptr  .ds 2                  ; MALLOC $02: the next free byte, high 0 = main memory
ma_lim  .ds 2                  ; ma_take's limit
sx_lim  .ds 1                  ; and the last page it may use
cp_cfg  .ds 1                  ; bit 7: EOSSYS.SYS is being read
dm_x    .ds 1
cp_lflag .ds 1                 ; the loader's FLAG for the next program (LOAD: $80)
ue_st   .ds 1                  ; U_EXPAND: the field
ue_end  .ds 1
ue_q    .ds 1                  ; where its trailing ?s start
bk_fn   .ds 1
dk_on   .ds 1                  ; $80: DOSKEY.SYS loaded
dk_x    .ds 1                  ; $80: /X
dk_na   .ds 1                  ; $80: an aliases file given
dk_h    .ds 2                  ; the history
dk_hn   .ds 1                  ; its next line
dk_hw   .ds 1                  ; its oldest
dk_hi   .ds 1                  ; the line shown
dk_a    .ds 2                  ; the aliases
dk_al   .ds 2
dk_len  .ds 1
dk_cur  .ds 1
dk_t    .ds 1
dk_pend .ds 1                  ; $80: & parts left in dk_rest
dk_rp   .ds 1
rx_on   .ds 1                  ; $80: RUNEXT.SYS loaded
rx_buf  .ds 2                  ; its configuration
rx_q    .ds 2
cx_on   .ds 1                  ; $80: COMEXE.SYS loaded
cx_add  .ds 1                  ; COMEXE: $80 .EXE to add
cs_try  .ds 1                  ; $80: a $COMSPEC shell is being run
cp_scan .ds 1                  ; TYPE: the attributes
cp_pg   .ds 1                  ; TYPE: bit 7 /P
cp_n    .ds 2
cp_lz   .ds 1
cp_col  .ds 1                  ; TYPE: characters in the screen line
cp_con  .ds 1                  ; TYPE: bit 7 the output is the screen
rd_u    .ds 1                  ; RAMDISK: the drive asked for
rd_cf   .ds 1                  ; the new one's first bank
rd_cn   .ds 1                  ; and its banks
rd_q    .ds 1                  ; bit 7: no messages (the default RAM disk)
rd_want .ds 1                  ; and banks (0: the default)
rd_tot  .ds 2                  ; its sectors
rd_bm   .ds 1                  ; bitmap sectors
rd_dm   .ds 1                  ; the main directory's map
rd_k    .ds 2                  ; a sector
cp_front .ds 1
* CAR: (car.asm): its open files and directory searches
NCAR    equ 4
cr_hnd  .ds NCAR               ; kernel handle, $FF free
cr_bk   .ds NCAR               ; the next byte: bank, offset in it
cr_offl .ds NCAR
cr_offh .ds NCAR
cr_sbk  .ds NCAR               ; the file's first byte
cr_soffl .ds NCAR
cr_soffh .ds NCAR
cr_len0 .ds NCAR
cr_len1 .ds NCAR
cr_len2 .ds NCAR
cr_pos0 .ds NCAR               ; searches: the next file
cr_pos1 .ds NCAR
cr_pos2 .ds NCAR
cr_ent  .ds 24
cr_pat  .ds 11
cr_spat .ds 11
cr_i    .ds 2
cr_cnt  .ds 2
cr_t    .ds 3
cr_x    .ds 1
cr_n    .ds 1
cr_want .ds 2                 ; bit 7: _01 still first (startup batch file)
cp_nm   .ds 10                 ; a variable's name, EOL ended

* binary loader (ld.asm)
NLEVEL  equ 4                  ; programs loaded inside programs
NBLK    equ 16                 ; relocatable blocks per program
ld_fid  .ds 1                  ; the file being loaded
ld_buf  .ds 128                ; read buffer
ld_bpos .ds 1
ld_blen .ds 1
ld_eof  .ds 1
ld_sig  .ds 2
ld_beg  .ds 2                  ; segment or block start
ld_end  .ds 2
ld_len  .ds 2
ld_num  .ds 1
ld_ctl  .ds 1
ld_mx   .ds NBLK               ; memory index of each block (0 main)
ld_rx   .ds NLEVEL             ; each level's EXTENDED while it runs
ld_xnew .ds 1                  ; not 0: a block went to a bank already
ld_off  .ds 2
ld_val  .ds 2                  ; fix-up value, symbol address
ld_name .ds 8                  ; symbol name
ld_cnt  .ds 2                  ; fix-up bytes left, 0 = up to $FC
ld_pos  .ds 2                  ; fix-up position
ld_first .ds 2                 ; start of the first segment or block
ld_run  .ds 1                  ; $FF once ld_first is set
ld_err  .ds 1
ld_cflag .ds 1                 ; fix-ups: not 0 when counted
gb_x    .ds 1
ld_ldlo .ds NBLK               ; load address of each block
ld_ldhi .ds NBLK
ld_bslo .ds NBLK               ; base (load address - offset field)
ld_bshi .ds NBLK
ld_xbn  .ds NLEVEL             ; NBANKS and MALLOC $04's state of each level
ld_xbc  .ds NLEVEL
ld_xbl  .ds NLEVEL
ld_xbh  .ds NLEVEL
ld_sxl  .ds NLEVEL             ; sx_ptr (MALLOC $02) of each level
ld_sxh  .ds NLEVEL
ld_owl  .ds NLEVEL             ; MEMLO as EOS set it for each level (k_ownml)
ld_owh  .ds NLEVEL
ld_mlo  .ds NLEVEL             ; MEMLO, SYMBOL and INSTALL of each level,
ld_mhi  .ds NLEVEL             ; restored when the level ends
ld_slo  .ds NLEVEL
ld_shi  .ds NLEVEL
ld_trap .ds NLEVEL             ; traps set when the level began

* CIO D: handler (dev.asm)
dc_x    .ds 1
dc_b    .ds 1
dir_name .ds 11                ; kd_first: the directory's name (FMS, CAR:)
ke_sa   .ds 1                  ; e_wrap's saved registers
ke_sx   .ds 1
ke_sy   .ds 1
clk_on  .ds 1                  ; the clock: bit 0 R-Time 8, bit 1 soft clock, bit 2 U1MB
sc_d    .ds 3                  ; the soft clock: date, time, jiffies at them
sc_t    .ds 3
sc_j    .ds 3
ck_j    .ds 3
ck_e    .ds 3
ck_r    .ds 1
ck_hz   .ds 1
ck_x    .ds 1
ck_v    .ds 6
dc_dir  .ds 1
dc_st   .ds 1
zs_v    .ds 8                  ; the caller's page 0 (dev.asm zsave)
dc_name .ds 68                 ; Dn: and the name given to CIO
l2_pb   .ds 1                  ; the second-level cache's bank (PORTB, ROM off; 0 none)
.ifdef IDE
ide_ok  .ds 1                  ; $FF: the CompactFlash card answered (ide.icl)
ide_u   .ds 4                  ; mapped drives: the unit (0 none), the
ide_l0  .ds 4                  ; partition's start (LBA, 24 bits) and size
ide_l1  .ds 4
ide_l2  .ds 4
ide_sl  .ds 4
ide_sh  .ds 4
.endif
