# Plan: EOS (Extendable Operating System)

EOS, EOS for short, is a drop-in replacement for the
SpartaDOS X 4.5 cartridge. Programs, drivers, batch files and disks written
for SDX work unchanged.

## Scope (user decision, 2026-11-03)

EOS has to work within itself. What it must do:

- run SDX programs and drivers, and use SDX (SDFS) disks;
- run BW-DOS programs, and use BW-DOS disks;
- read and write Atari DOS 2 and 2.5 disks.

SDX and BW-DOS are references for how things should behave, not test
targets: new tests check EOS on its own, with the expected result in the
test. Existing oracle tests keep their recorded SDX results
(build/sdx-cache, tests/carref); SDX-only quirks are not copied.

## Name and system files

EOS uses its own names for its system files, so a disk can carry settings
for EOS and SDX side by side:

| Purpose | EOS | SDX name, read when the EOS file is missing |
|---|---|---|
| System configuration (USE, DEVICE ...) | `EOSSYS.SYS` | `CONFIG.SYS` |
| Startup batch | `EOSAUTO.BAT` | `AUTOEXEC.BAT` |

- `EOSSYS.SYS` takes the same syntax as CONFIG.SYS, so an SDX file can be
  copied over unchanged.
- The fallback keeps existing SDX boot disks working as they are.
- `AUTORUN.SYS` is not used. On Atari disks it is a DOS 2 auto-run program,
  and SDX ignores it on purpose (User Guide, Appendix E.2). EOS does the
  same.
- Some names stay the same, because SDX programs and config files refer to
  them:
  - the `CAR:` device;
  - driver names in DEVICE lines (SPARTA, SIO, RAMDISK, ATARIDOS ...);
  - environment variables such as `$PATH`;
  - the version information programs check to detect SDX.
- The banner, the cart image (`EOS.car`) and the make targets use the
  EOS name.

## What "drop-in" covers

SDX is not a bigger SpartaDOS 3. It is a different architecture:

| | BW-DOS 1.5 (today) | SDX 4.5 |
|---|---|---|
| Where the kernel lives | about 7 KB of RAM from $0700 | banked cartridge ROM at $A000, plus RAM under the OS ROM |
| Program format | plain Atari DOS binaries ($FFFF) | also relocatable binaries ($FFFA/FFFE/FFFD/FFFB/FFFC) linked against a symbol table |
| Program interface | the COMTAB layout of SpartaDOS 3.2 | about 160 named kernel symbols (PRINTF, FOPEN, U_GETPAR, MALLOC ...) |
| Commands | separate .COM files on disk | built into COMMAND.COM, plus a CAR: device of about 70 commands |
| Drivers | none | CONFIG.SYS (EOS: EOSSYS.SYS) with DEVICE lines, the SIO driver interface, and file system drivers (ATARIDOS, FATFS ...) |
| Memory | main RAM only | memory indices: main, system extended, program extended (banked), 65816 high RAM |

So the BW-DOS kernel can't simply grow into SDX. The parts worth reusing are
the SDFS file system code (FMS), the command implementations in COM/, and the
build and test setup. The kernel structure (cart-resident, symbol table,
relocating loader) is new code.

## The compatibility surface, measured

I scanned the relocatable binaries on the SDX Toolkit disk (`toolkit.atr`,
358 archive members, 122 binaries) and the SDX 4.5 cartridge image for the
symbols they import ($FFFB records). The list is in `build/survey/symbols.txt`.

- 157 distinct symbols are imported. 121 of them are documented in the SDX 4.5
  Programming Guide.
- The 15 most used, in order, are PRINTF, COMTAB, U_FAIL, INSTALL, U_GETPAR,
  U_SLASH, FCLOSE, U_GETNUM, FOPEN, FILE_P, U_GEFINA, COMTAB2, U_XFAIL,
  FREAD and U_SFAIL. Most programs need only these.
- The 36 undocumented symbols are what the system's own pieces use:
  - FATFS.SYS and CPMFS.SYS use DISK, FILE, REQUEST, ERROR, ABORTB, FLUSHB
    and UPDTSEC, which make up the file system driver interface.
  - CON.SYS, SC (SpartaCommander) and EDX use _RAWCON.
  - TSR.SYS and the 65816 drivers use _LIBVEC, _EXCVEC and _ESAVE.
  - ARCLOCK.SYS uses ERRNO and VALIDATE.

  Running these drivers means learning these interfaces from how the drivers
  use them.

## Decisions (2026-11-02)

- Name: EOS (Extendable Operating System). System files are `EOSSYS.SYS` and
  `EOSAUTO.BAT`, falling back to SDX's CONFIG.SYS / AUTOEXEC.BAT.

- Target hardware: AtariMax 1 MB (the same as `SDX450_maxflash8.car`).
- Undocumented interfaces are learned by disassembling the Toolkit driver
  binaries and watching real SDX in the Altirra debugger. SDX kernel code is
  not copied.
- 512-byte sectors go in the main kernel, accepting the RAM cost.

### Cartridge layout (2026-11-02, A1)

- Sources live in `eos/`. The RAM kernel (`kernel.asm`, $0700 up to
  MEMLO) is assembled first; `tools/mads2icl.py` turns its label table into
  `build/eos/kernel.icl`, which every bank includes. Each 8K bank is a
  separate MADS assembly at $A000, and `tools/mkcarx.py` joins them into
  `build/EOS.car`. Reason: MADS virtual banks (`lmb`/`nmb`) hide labels
  across banks, and separate assemblies keep each bank's size visible.
- Banks: 0 boot (also holds the kernel image), 1 library (mapped while
  programs run, so symbol addresses can point straight into it), 2 DSK: file
  system, 3 command processor. More banks are added as code grows.
- Every bank starts with a jump table at $A000 and ends with the same 16-byte
  tail at $BFF0 (`tail.icl`): the cartridge trailer and a run entry that
  selects bank 0 and jumps to $A000. The OS may find any bank selected at a
  reset, so all 128 banks carry the tail, including unused ones. Trailer
  flags are $04 (run the cartridge, no disk boot), as on SDX.
- Code in one bank reaches another only through the RAM routine `farcall`
  (`jsr farcall` / `dta b(bank),a(address)`), which passes A, X, Y and the
  flags both ways and reselects the caller's bank. `curbank` in RAM shadows
  the write-only bank register.
- The DSK: file system is new code (`eos/fms.asm`), not a port of
  `XBWFMS.ICL`. Reason: the BW-DOS FMS is size-optimised self-modifying code
  driven by an inline move/call bytecode (`MOV_CAL`) and cannot run from ROM;
  BW-DOS sources and `tools/sdfs.py` serve as the format reference. All its
  state is in RAM after the kernel image (`fmsdata.icl`): 15 drives, 8 open
  files plus one block for internal directory reads, and a 4 x 512-byte
  sector cache (LRU). Every path operation re-reads the volume header, so a
  changed disk is noticed (sequence number / random id) and no stale sectors
  are used. Zero page: $43-$48 (the OS's FMS area).
- Kernel (`jkernel`, RAM): functions 0-7 go to the device of the open file
  (`dev_index`), the rest to `device`; from 11 on `file_id` is $FF. The
  kernel records the device in `dev_index` after a successful kd_open /
  kd_first and frees it after kd_close. Devices: DSK CLK CAR CON PRN NUL, in
  that order, as on SDX (DEVNAME probe). CON/NUL/PRN live in bank 4.
- U_GEFINA follows what real SDX does (`tools/probe/gefina.asm`, run with
  `tools/probe/show_gefina.py`): single letters A-O are drives 1-15 (so `D:`
  is drive 4, not the current drive), `Dn` is DSK unit n, a 3-letter name is
  looked up in DEVNAME with an optional unit; `path` keeps the directory part
  as typed and ends in $00 where the name begins; the name is 8+3 with `*`
  filled with `?` and a second dot ending it.
- `tools/hostsim.py` runs the cartridge on the host: a small 6502
  (`tools/m6502.py`), 64K RAM, AtariMax banking, and Python stand-ins for
  CIOV (screen editor on IOCB 0) and SIOV (ATR images). A command takes well
  under a second, so code is debugged there and then checked in Altirra.
- A minimal startup batch runs from Phase A on, because typing in the
  emulator mangles `>` and `:`: on a cold start the CP runs D1:EOSAUTO.BAT,
  else D1:AUTOEXEC.BAT, without echo (SDX's default is ECHO OFF). Oracle
  tests run the same batch on SDX (ending in SDXPROBE) and on EOS
  (dumped at the next prompt) and compare the screen lines.
- The loader (`eos/ld.asm`, bank 5) holds the ROM symbol table, built by
  `tools/mksymtab.py` from `eos/symbols.txt` and the label tables of the
  kernel and the library. Program symbols ($FFFC) are 13-byte records (link,
  name, level, address) allocated at MEMLO and linked from `SYMBOL`; lookup
  walks that list first, so a program's symbol overrides the system's.
  The base of a relocatable block is its load address minus its offset field,
  for fix-ups and definitions alike. Each program level saves MEMLO and the
  symbol list head; when the program returns (or the command processor is
  re-entered after JMP (DOSVEC) or U_FAIL) the level is undone unless the
  program decremented INSTALL. Programs (and INIT routines) run through
  `k_exec`, which selects the library bank: programs call symbols in it
  directly.
- Writing (`eos/fmsw.icl`): free sectors come from the bitmap, searched
  from the header's hint (bytes 18-19); free count and hint are kept in RAM
  and written to sector 1 when the drive is flushed. Sector maps and data
  sectors are allocated as a file grows (new sectors are not read, they start
  as zeros). Changed sectors stay in the cache until they are evicted, the
  file is closed, or a directory operation ends; then the drive is flushed.
  While files are open on a drive its header is not re-read. A written
  file's entry (map, length, date and time from page 7) is updated at close.
  Directory entries are read and written through the internal FCB like any
  file, so a directory grows on its own; its header length is updated when
  it does. New directories get length 23 in their parent's entry, as SDX
  writes. Deleted entries get status $10 and their slots are reused. The
  `fsw` oracle test compares the resulting disk with SDX's (paths,
  attributes, contents) and requires `sdfs.py check` to pass.
- 512-byte sectors: mount reads sector 1 as 128 bytes; when that fails (and
  the drive answers) it reads it again as 512 bytes. All sizes share the code
  (shift 7/8/9, 62/126/254 map entries, 512-byte cache buffers).
- A8's test is the `dd512` interop case with EOS doing step 2
  (`interop_test.py --eos`, run by `make interop` after the BW-DOS 1.5
  cases): `tests/eos/IOP.asm` does through the library what BW-DOS does
  with its shell commands (compare, type, MD, copy, overwrite, DEL, REN, RD).
  Reason: BW-DOS 1.5 itself stays byte-identical (`make verify`), so its own
  dd512 case remains XFAIL; EOS gets no XFAIL. All four geometries pass.
- `tools/sdfs.py build` writes SDFS 2.1 images of any geometry (mkatr makes
  no 512-byte sectors). SDX ignores AUTOEXEC.BAT on a disk whose boot loader
  header (bytes 0-8) and byte 37 are zero, so the builder writes them as SDX
  FORMAT does; byte 30 is tracks with $80 for two sides.
- A file gets its first sector map when it is created, before its entry,
  so creating on a full disk fails with 162 and leaves no entry (as on SDX),
  and empty files have an empty map (as SDX and BW-DOS write them).
  Truncating (open for writing) keeps that map. At close, sectors past the
  length are freed (`trim`): after a disk full the last map may hold no data
  sector. The `full` and `full-map` oracle tests (the second fills the disk
  right after a new map) match SDX in lengths, files and free count.
- The sector cache lives at $D800-$DFFF under the OS ROM (as SDX's data in
  USE OSRAM). The DSK: driver turns the ROM off on entry and on at exit; SIO
  still uses the OS SIOV, so transfers go through a 512-byte buffer in main
  RAM. NMI/IRQ vectors under the ROM point to kernel stubs that turn the ROM
  on, run the OS handler with their own return frame (status pushed with B
  clear) and turn it off again.
- Symbolic links come from SDX's own Toolkit driver: SYMLINK.SYS loads and
  runs unchanged on EOS (it hooks `jkernel` at $0704 and uses misc_gefina
  through `jmisc` $0709). The kernel side it relies on: after a successful
  open `dentry` holds the file's directory entry (it tests bit 6 there);
  creating with attr bit 6 sets the link bit in the status ($48), and doing
  so over an existing regular file fails with 151, as on SDX. Without
  SYMLINK.SYS links read as ordinary files, also as on SDX. Reason: matching
  SDX exactly, including DEVICE SYMLINK being optional, without a second
  implementation in the kernel.
- U_FAIL honours traps (U_SFAIL/U_XFAIL, up to 10): the stack pointer and
  bank saved by U_SFAIL are restored and the handler gets the error in A
  with N=1 (through `k_trap` in RAM, since the bank changes). A program's
  traps go when its level ends.
- Standard output and input are kernel handles in COMTAB+6 and COMTAB+7 (WC
  reads COMTAB+7 when given no file). At boot CON: is opened twice, giving
  handles 0 and 1 as on SDX. PUTC/PRINTF write through the kernel to
  COMTAB+6 and keep the page 7 I/O parameters.
- PRINTF follows real SDX (`tests/eos/PRINTF.asm`, run on both): `%x`
  shows 6 digits by default and `%nx` the last n; a decimal field shows the
  last n digits, padded with spaces or zeros, at most 10; `%ns` cuts or pads
  on the right; `%t` takes its number as the entry index; an unknown type
  after `%` disappears without using an argument; an unknown backslash
  sequence prints as it is.
- Current drive (B0b): a command line that is a device alone (ends in
  `:`) goes through U_GEFINA and sets CURDEV; names without a device then
  use it through U_GEFINA, programs included. The prompt is built in RAM
  (`cp_prm`) as SDX's default `$PROMPT` `D$N` shows it: drives 1-9 as a
  digit, 10-15 as a letter (`DJ:`), other devices as name and unit
  (`DCAR1:`). U_GEFINA's drive forms are SDX's: `A:`-`O:`, `1:`-`9:`, `D`
  and one digit or letter; `D15:` is error 130 on SDX too. Reason: the user
  request, matched to what real SDX shows. $PROMPT itself comes with the
  environment (B7/C1).
- COMTAB2 (B0c) is a kernel RAM table with SDX's 64K values: -5 _SEGBEG,
  -4 _SEGCNT, -3 _EXTBNK, -2 _EXTTYP (all 0), -1 micro-buffer bits ($05),
  +0 _816FLG 0, +1 $01, +2 sio_index 1-15. COMTAB+$FF ... +$10A is kept
  free for MUL_32/DIV_32 (it used to hold DEVSPEC). _EXTBNK gets the bank
  count with extended memory (B6).
- Where SDX's library differs from the Programming Guide, EOS does what
  SDX does (oracle tests `conio`, `env`, `dirs*`, `parse`, 2026-11-02):
  - MUL_32 leaves the first operand 0 and returns C=0 even on overflow;
    DIV_32 leaves remainder and divisor shifted left until the divisor's
    bit 31 is set, and returns C=1 (result 0) only for a divisor 0.
  - FGETS with a line longer than the buffer stores length-1 bytes and an
    EOL, skips the rest of the line, returns A=$FF, Y=length, N=0.
  - PUTENV returns A = the first character of its argument.
  - U_TOKEN without a match returns A = the number of keywords.
  - U_GETADR: `+` after a symbol is an error (parameter kept), `-n` works;
    an unknown symbol uses the parameter up.
  - U_PATH writes the device as one letter: A:-O: for drives, the first
    letter of the name otherwise (C: for CAR:).
  - GETCWD gives each directory after a backslash (`\SUB\DEEP.D`), empty
    for the main directory.
  - U_GETPAR with no parameter left stores an EOL in COMFNAM (SL.COM
    lists all symbols on SDX that way).
  - Error messages print the code without leading zeros ("1 System
    error").
- The environment lives at $C000-$C0FF under the OS ROM (ENV_P = $C000,
  index 2; SDX has it at $D800, where EOS keeps its sector cache), in SDX's
  format: NAME=VALUE records ending in EOL, then a 0. A cold start sets
  SDX's defaults (PATH=CAR:, PROMPT=D$N, SYSERR=CAR:SYSERR.MSG, MAXDRV=O:,
  MANPATH=CAR:, BOOT=A:>). NUMENV returns the whole NAME=VALUE.
- Symbols: SYMBOL is SDX's 14-byte structure (list head, then name, level,
  address for S_LOOKUP/S_ADD/S_NEXT). S_LOOKUP, S_ADD and S_NEXT live in
  the loader bank; jfsymbol ($07EB) is in kernel RAM. S_NEXT gives the RAM
  list, then the system table (level 0).
- S_ADDIZ keeps up to 5 reset routines with their level; a level's entries
  go when it ends without INSTALL. A warm start still rebuilds the kernel
  and resets MEMLO, so they are not run yet: resident programs surviving
  RESET is D1.
- kd_cwd (17) and kd_check (19) are in the FMS. kd_check writes GETDFREE's
  17-byte format directly (file system code from header byte 32, sector
  size code from byte 31, total and free from the drive table, name,
  sequence, random id); SDX 4.4x's own kd_check format is undocumented,
  so a file system driver with its own kd_check (D3) needs a conversion.
- FCLOSEAL: the kernel records SYSLEVEL with each handle when it is opened
  (`f_level`); FCLEVEL changes it.
- More of what SDX does, found by the Toolkit survey (2026-11-02):
  - U_LOAD prints `File NAME.EXT` (the spec as given) before error 170,
    and `Symbol NAME` before error 154 (strong symbol not defined).
  - U_FAIL with a code below 128 ends the program without a message.
  - Standard output is handle 0 and standard input handle 1 (COMTAB+6,
    COMTAB+7); CLX20/21 word-wrap only when output is handle 0.
  - FFIRST that finds nothing leaves the directory open (programs call
    FCLOSE in any case); kd_first with a blank name matches every entry.
  - COMTAB2-6 is the CPU clock in units of 100% (1); OSRMFLG (COMTAB+$1F)
    is $FE with USE OSRAM, not $FF as the User Guide says.
  - FCLOSEAL returns X=0.
- Program levels and status (oracle `nest`, matches SDX's SYSLEVEL values):
  k_exec keeps the stack pointer each program starts with (ke_sp, saved
  per call). U_FAIL with a code below 128 and no trap ends the program as
  if it had returned (STATUS = the code); U_LOAD returns STATUS in A and
  zeroes it, and a negative STATUS becomes an error in the caller. Ending
  a level closes the files opened at it (f_level). A trap set at a lower
  level first ends the levels above it (ld_trap). U_UNLOAD ends the level
  of a program loaded with FLAG $80, resident or not.
- ERRNO is set by U_FAIL to codes from 2 up that no trap catches, and never
  cleared (User Guide 4.39.2; trapped errors leave it, as on SDX).
- U_GETPAR leaves BUFOFF past the separator after the parameter, as SDX
  does. U_GETFLG uses up its parameter: a number (C=1), S A I N alone
  ($00 $40 $C0 $80, C=1), anything else $04 (C=0); none keeps A (C=1).
- Bank 6 (`lib2.asm`) holds library functions the library bank has no
  room for; their symbols point to 6-byte farcall stubs in the library.
  First there: FDOPEN/FDGETC/FDCLOSE.
- The formatted directory (oracle tests `fdir`, `fdir-sd`: 14 listings
  byte for byte, measured with `tests/eos/FDT.asm`): $00 means $0B and $80
  $A8. Short: $02 adds a column for `*` (protected) and one for `:`
  (directory); name and extension side by side, $20 a space between them
  ($20+$10 a dot); $40 attributes `pah`; $01 the size in sectors (3 digits,
  rounded up); the last line `999 FREE SECTORS` at most. Long: a header
  (EOL, `Volume:    `+name, `Directory: `+the directory's own name, EOL),
  size ` %6d` or with $01 ` %10d`, `<DIR>` for directories, date
  ` %2d-%02d-%02d`, time ` %2d:%02d` and `:%02d` unless $08; last
  `%8d FREE SECTORS`. $04 (24-hour) changes nothing visible. Hidden files
  are listed. Lines are built in LBUF, as SDX does (programs cannot keep
  their command line across FDGETC). After the last line dentry's status
  is 0. kd_first records the listed directory's name (`dir_name`).
- DIVIO/XDIVIO (oracle `divio`): the old standard handle is kept, the new
  file opened at the caller's level; input reaching its end and the end of
  the level that opened the file undo the redirection.
- Directories opened raw (mode $1x) are the directory of the path; the
  name is not looked at, as on SDX (opening `SUB` gives the current
  directory, `SUB>` gives SUB). The position starts after the header
  (dentry holds it). Mode $1C writes in place; closing such a file only
  flushes the drive (no trim, no entry update). Writing past the end of a
  directory is not handled like SDX (which grows it).
- kd_boot (SETBOOT) stores the file's first map at header byte $28.
- Atari DOS 2 disks (B9, first part: reading). Bank 7 (`dos2.asm`) holds
  the DOS 2 file system. The FMS's mount tries it when sector 1 is not
  SDFS: the VTOC (sector 360, read as 128 bytes, then 256) must start with
  2-9; `dv_fs` records the drive's file system. `route` in `dsk_entry`
  sends every call for such a drive to bank 7 (file calls by the FCB's
  drive, the others by device), with the ROM off; bank 7 uses the FMS's
  cache and FCBs through a jump table ($A003 getsec, new_fcb, find_fcb,
  flush_drv). What programs see follows SDX's ATARIDOS.SYS: entries have
  status $08 (+$01 when locked), the first sector as map, length = sectors
  x data bytes (125 or 253), no date; the directory is `Root`, the volume
  `DOS 2.0 `, GETDFREE code $02 with the VTOC's counts. FDOPEN leaves date
  and time out for an entry without a date (day 0), as SDX does. Oracle
  tests dos2-sd, dos2-dd (SDX gets `CAR:ATARIDOS.SYS` first, `sdx_pre`):
  listings and byte-exact copies (tests/eos/CPY.asm).
- Writing Atari DOS 2 disks (B9), beyond SDX's read-only ATARIDOS.SYS, as
  DOS 2.0S/2.5 do it: a new file takes the first free (or deleted) entry
  and the lowest free sector, status $43 while open, $42 after; replacing
  a file reuses its entry and frees its sectors first; each data sector's
  link holds the entry number as file number; sectors come from the VTOC
  (sectors up to 719), then on enhanced density disks from VTOC2
  (720-1023), both bitmaps and free counts kept as DOS 2.5 keeps them.
  A locked file is not replaced or deleted (170, as a protected SDFS
  file). Changes reach the disk at close, delete, rename and CHMOD. There
  is no SDX oracle for writing: tests check images with tools/dos2.py and
  let SDX read back what EOS wrote.
- MyDOS (B9; format reference: MyDOS 4.51's TECH.DOC and sources from the
  wiki's Mydos451.zip, nothing copied). A VTOC code of 3 or more makes a
  drive MyDOS (`dv_fs` 2), as SDX's ATARIDOS.SYS decides: the volume is
  `MyDOS   `, GETDFREE's code $FF, and $10 entries are subdirectories (8
  consecutive sectors, entries like the main directory's), reached by
  paths (`SUB>DEEP>FILE`); on code 2 disks they are skipped, as on SDX.
  The working directory stays the main one (SDX cannot change it there
  either). Entries with status $04 have 16-bit links (no file number);
  new files on MyDOS disks get them ($46). The VTOC bitmap goes on in
  sectors 359, 358 ... (code - 2 pages of 256 bytes; single density
  counts them in pairs), the free count stays in 360. tools/dos2.py reads,
  checks and builds MyDOS images; SDX reading the built images is the
  check that the format is right. Tests mydos, mydos-sd (built images:
  listings and copies as SDX), mydos-wiki (a real code 3 disk), mydosw
  (EOS writes; SDX reads back). Deliberate difference: SDX stops reading
  the real disk's AUTORUN.SYS after 100 bytes, EOS reads all of it (as
  tools/dos2.py does). A directory entry is $10 alone, as MyDOS writes
  it (bit $40 is not needed; SDX lists such entries as directories).
- MKDIR and RMDIR on MyDOS disks (B9, beyond SDX), as MyDOS 4.51 does
  them: the new directory takes the first free entry and the first 8
  free sectors in a row from 369 up, zeroed; the entry is $10, count 8.
  RMDIR removes an empty directory (only deleted entries in it, else
  167), frees its 8 sectors and marks the entry deleted. On a DOS 2 disk
  both give 135. Statuses follow SDX on SDFS (151 name taken, 167 not
  empty, 170 not there: SDX's RMDIR of a missing directory is 170, not
  150, and EOS's SDFS RMDIR now does the same). REMOVE leaves
  directories alone (170). Test mydosd.
- Update mode ($0C) on DOS 2 / MyDOS files: bytes are read and written in
  place, and the file does not grow: a write past its last byte is 136,
  as Atari DOS 2.0S/2.5 do (their FMS reads the next sector in update
  mode and reports EOF at the last). A locked file cannot be opened for
  update (170). (SDFS files opened $0C still grow, as on SDX.)
- Programs run from DOS 2 disks (`D2:HEX` in test dos2w, on EOS and SDX).
- The command processor (C1) behaves as SDX's (measured, PROGRESS.md C1):
  batch files with _d1 parameters, $NAME substitution, the errors that
  end a batch (130 and 156 of its own commands; any with ERROR ON), $BATCH
  before every line. Deliberate difference (user request B0b): a command
  is looked for in the current directory first, then along $PATH; SDX
  searches $PATH first. U_FAIL records the failing code for the command
  processor (cp_fail); the program the command processor runs is named
  under the OS ROM (CMDNAME, $C100) for SDX's `File X.COM` line on 170.
- Redirection (C2) as SDX: `>>NAME`/`<<NAME` words only, the first of each
  kind, taken out of LBUF with the blank before; messages from U_FAIL go to
  the screen (the output redirection is taken back first). U_GETPAR
  returns parameters in capitals, as SDX's does.
- EOSSYS.SYS / CONFIG.SYS (C3) as SDX's CONFIG.SYS, read by the command
  processor at a cold start (OPTION held: skipped). SDX's own drivers
  named in DEVICE lines are built into EOS and load nothing (EOS always
  has its console, disks and DOS 2 support: an EOSSYS.SYS without DEVICE
  lines still boots, where SDX loses its drivers). USE OSRAM/BANKED change
  NBANKS, BANKFLG, OSRMFLG, T_ index 2 and MALLOC $02 as on SDX
  (boot.asm applyuse, again after every reset); the areas MALLOC $02 uses
  are EOS's own ($E400-$FFBF, the system bank's $4000-$7FFF).
- The CAR: device (C5): read-only files packed into cartridge banks 9 on
  (tools/mkcarfs.py; bank 8 the driver eos/car.asm), holding EOS's own
  commands (eos/carcmd), man pages and data files. The commands are
  written from the User Guide and checked against SDX's real output
  (`make cartest`, references in tests/carref). Drivers SDX has as files
  that EOS has built in (SPARTA SIO ATARIDOS INDUS RTIME8 JIFFY) are
  stub .SYS files. Where U_FAIL prints "File X" before 170, X is the name
  of the file a library call last failed on (as SDX shows it), else the
  program's.
- ZCRNAME (COMTAB+3, _CRUNCH) is in the library (oracle `crunch`): COMFNAM
  becomes `D` + device + `:` + the rest, the device as SDX writes it: a
  drive as a digit or J-O, PRN and CON as `P1:` / `E1:` (CIO names),
  other devices as name and unit (`DCAR1:`). Z=1 when only a device is
  there; BUFOFF stops at a space after it but passes a comma.
- RENDIR is RENAME with scan $08: kd_rename then renames directories
  only, files only otherwise (oracle `rent`).
- Memory (B6): T_ has SDX's values; V_setme/V_popme keep a 16-deep PORTB
  stack (index 0 $FF, 2 $FE, 4 and up through T_+8, `k_tconv`). MALLOC $00
  from MEMLO, $02 also from main memory (as SDX with USE OSRAM).
  - PORTB banks are counted at a cold start (each candidate in T_ order
    gets its number at $4000, last to first; counted until one reads back
    wrong) and the count kept over warm starts. NBANKS (COMTAB+$1D) and
    _EXTBNK (COMTAB2-3) get it.
  - NBANKS is the number of banks not used yet, as on SDX: a new bank is
    index NBANKS+3, then NBANKS goes down. RC_GR8.SYS relies on it: after
    loading it switches in bank NBANKS+4, the one the loader just took.
  - MALLOC $04 (oracles memt-128K, mem2-128K): in the bank in use while the
    block fits, else a new bank; 16K at most (more: X=$04, N=1); none left:
    X=0, N=1. Freed per program level (NBANKS, the bank in use and its
    pointer are saved with MEMLO).
  - The loader puts $FFFE blocks for index 4 into banks, the program's
    first one in a new bank; data, BSS fill and fix-ups go through
    V_setme; EXTENDED = the bank, EXTENDED+1 the number of blocks,
    EXTENDED+3 each block's index. The program runs with EXTENDED switched
    in (RC_GR8 calls its banked code directly). CON64.SYS and RC_GR8.SYS
    on 128K match SDX (oracles con64-128K, rcgr8-128K).
  - kd_read/kd_write honour memreix: the FMS switches the caller's memory
    in (with the ROM off) around its copies (`fs_mx`).
  - Symbols defined in banked blocks still get memory index 0.
- U_LOAD leaves the program's directory in path, as SDX 4.46 does:
  `>SUB>DEEP.X>`, `>` for the main directory, $00 at the end, no device
  (oracle `pth`; RC_GR8 needs it). The FMS keeps the directory of the last
  file opened for reading; internal function 21 writes it.
- Oracle tests whose output is longer than the screen run in parts, one
  boot each (`multi`). EOS's startup batch gets a blank line where SDX's has
  SDXPROBE, so the files on the two disks have the same lengths. Test
  program names must not be SDX built-in commands (DIRS is one).
- Tests read results from memory: an Altirra breakpoint on a RAM kernel
  address (for the shell: `k_getline`, where the prompt is on screen) writes
  the 64K CPU view to the host and lets the emulator run on. The screen text
  is read from SAVMSC. RAM addresses are used because a breakpoint on $A000-
  $BFFF would fire in every bank.

## SDX 4.5 at runtime, measured

`tools/sdxprobe.py` boots the real cart headless and dumps memory.
`sdxprobe.py symbols` loads `tools/probe/symdump.asm`, which imports all 157
surveyed symbols as weak references, and records what the SDX loader resolved
them to (`build/sdxprobe/symbols.txt`). The setup is CONFIG defaults on a 64K
800XL, which is USE OSRAM.

| | Value / place | Examples |
|---|---|---|
| MEMLO | `$18FF`, so the kernel takes about 4.5 KB of RAM at $0700 | |
| MEMTOP | `$9C1F` | |
| DOSINI | `$0925` | |
| COMTAB (= DOSVEC) | `$0A3A` | |
| Kernel RAM | $0700-$18FF | T_ $090C, ERRNO $0934, _EHAND $0970, XCOMLI $09B2, SYMBOL $0B59, DEVSPEC $0C50, DEVNAME $0C58, _LIBVEC $0C79, PUT_V $0CC2, EXTENDED $0CD5, INSTALL $0CE0, FILE_P $0CE1, CURDEV $0CE4, SYSLEVEL $0CE5, COMTAB2 $0D5F, SIOPARM $1264, I_GETTD/I_SETTD $18AE/$18AB |
| Library (cart bank, mapped at $A000-$BFFF while programs run) | $A017-$BF81 | PRINTF $A878, FOPEN $ACCE, U_LOAD $A298, MALLOC $AFA2, U_GETPAR $B148 |
| File system driver interface (RAM under the OS ROM) | $F5D9-$FC96 | MOVE_MEM, UPDTSEC, FLUSHB, ABORTB, ALLOC, REQUEST, ERROR, DISK, FILE |

Symbol addresses may differ in a replacement, since programs resolve them at
load time. Fixed addresses may not: page 7 variables ($0760 file_id, $0761
device, $0778 mode, $0779 scan, $0782 addpos, $0785 bytbuf, $07A0 path, $07F1
V_setme, $07F4 V_popme), LBUFF $0580, the COMTAB offsets, and MEMLO no higher
than $18FF. That means the BW-DOS FMS (MEMLO $1EEF today) has to move mostly
into the cart and under the ROM.

## Test oracle

The same binary runs on real SDX (the cart under Altirra, which we already
drive headless) and on the replacement. Output and resulting disks must
match. `tools/unarc.py` unpacks the Toolkit archives (methods 2, 3, 4 and 8,
CRC-checked), and `tools/sdxbin.py` parses SDX binaries ($FFF9 65816 blocks
are out of scope). So every Toolkit program becomes a test case. The existing
`interop_test.py` covers disk-level compatibility.

## Phases

**A. Cart kernel skeleton.**
- An AtariMax cart, boot, a D: handler on the SDFS FMS, COMTAB, a symbol
  table and the U_LOAD relocating loader.
- The FMS gets the pending disk work: 512-byte sectors, symlinks (bit 6
  dereference, scan-mode creation), and freeing a file's unused sectors after
  disk full.
- Milestone: a small Toolkit program (WC, HEXDEC) loads and runs.

**B. The documented library**, in order of use: console and printf, command
line parsing, file I/O, errors and traps, directories, memory (MALLOC and
indices), environment, and symbol functions. Milestone: most of the 122
Toolkit binaries run.

**C. The shell.**
- COMMAND.COM behaviour: batch, variables, $PATH, `>>`/`<<` redirection,
  EOSSYS.SYS (falling back to CONFIG.SYS), EOSAUTO.BAT (falling back to
  AUTOEXEC.BAT), DEVICE.
- The CAR: device and our own versions of the built-in and CAR: commands,
  written from the User Guide. SDX's binaries are not copied into the cart.

**D. Drivers.** INSTALL/S_ADDIZ resident programs, the SIO interface
(chapter 22), and then the undocumented _RAWCON interface, so CON.SYS and the rest
load. The file system driver interface (FATFS.SYS, CPMFS.SYS) is left out
(the user's decision): added only if someone asks for it.

Out of scope: 65816 support (the H_* symbols, $FFF9 blocks and the 11
Toolkit binaries that need a 65816), and turbo boards.

## Target machines

Only stock 6502 XL/XE machines with at least 64K: 600XL (expanded to 64K),
800XL, 1200XL, 65XE and 130XE. The 400, the 800 and machines under 64K are out
of scope, so RAM under the OS ROM is always there. SDX changes its memory layout to match each
machine, so each one goes in the test matrix:

- **XL/XE with 64K, and the 130XE:** both default to USE OSRAM and the layout
  measured above. A 128K probe run gave the same MEMLO and the same 157 symbol
  addresses. The 130XE's 4 extra banks serve as program extended memory
  (MALLOC index $04) and the RAMDISK.
- **USE BANKED** (in CONFIG.SYS / EOSSYS.SYS) on a 130XE moves the system into a
  bank. It needs its own probe run on real SDX, with a CONFIG.SYS, once
  config file processing exists.

## Notes

- SDX's `>>file` creates or replaces the file. That is its documented
  redirection (User Guide, `DIR >>PRN:`), so the replacement does the same.
- SDX's slow disk access in the emulator comes from its own SIO timing, not a
  disk problem. The tests run Altirra in turbo mode.
- COMP.COM's 0-byte and 255-byte false mismatch is fixed (CHANGES.md).
- The existing BW-DOS 1.5 ATR and CAR builds, and their tests, stay working.
- RAM disk (2026-11-03): EOS's RAMDISK is its own code in the shell bank
  (rdinst) and the FMS (rdio). It takes the top banks and leaves the 4 kept
  for 130XE programs, as SDX does; with no USE, more than 4 extended banks
  means USE BANKED, as SDX.
- EOS file system (2026-11-03, agreed with the user): first make EOS's SDFS
  code faster with the on-disk format unchanged (cache, read-ahead,
  write-behind, contiguous allocation), then add EOSFS as an optional native
  format (extents, indexed directories, 8.3 names, a dirty flag, 24-bit
  volumes) behind the same kernel interface. This comes after the Mutineer
  milestone. PROGRESS.md Phase E has the plan; a full specification goes to
  the user before any code.
- FORMAT (2026-11-03): the menu's Z picks a standard size (90K 127K 180K
  360K 720K 1.44M 16M) or Advanced (density, tracks, sides, sectors per
  track); one track means a hard disk: no physical format, only the file
  system. Sectors and the free count are shown before formatting. A
  refused PERCOM write stops the format. The volume name keeps its case
  (read from LBUF, as SDX's FORMAT does) and the sequence number starts at
  0. Tests: tools/fmt_test.py (`make fmttest`).
- jsector_io / lsio (2026-11-03): EOS's own fallback after the sio_vector
  drivers is the RAM disk, else the OS's SIOV. It does not apply sio_index:
  EOS maps drives where names are parsed (U_GEFINA), so callers pass the
  drive the map gave.
- Sequence number (2026-11-03): the FMS adds 1 each time it writes the
  volume header, as SDX does; SDX also writes it when a file is created,
  EOS only on close or flush (cartest chkdsk-f masks that byte).
- BASIC and E: (2026-11-03): EOS wraps the OS's E: handler in HATABS (the
  kernel's k_ehand); while standard input is redirected to a file, E: GET
  reads the file and at its end the redirection closes and the keyboard
  takes over (BASIC <<AUTOGO, as SDX). E: PUT is not redirected (not
  measured on SDX yet).
- MEMLO (2026-11-03): a program that sets MEMLO itself keeps it when it
  ends, as SDX (measured: an absolute program writing MEMLO=$3000, then
  MEM). The loader tracks the MEMLO it set for each level (k_ownml) and
  restores only when MEMLO is still that.
- CIO D: (2026-11-03): the kernel handle moved from ICAX4 to ICAX6, since
  POINT/NOTE use ICAX3-5. Burst GET/PUT CHARACTERS for buffers below $A000.
- Clock (2026-11-03): built into EOS as the CLK: kernel device; the R-Time
  8 is used without an EOSSYS.SYS (SDX's standard setup prints "R-Time 8
  not present" without one). Setting the time does not write the R-Time 8
  (Altirra ignores writes; untested on hardware): the soft clock takes it.
- FujiNet tests (2026-11-03): FujiNet-PC and the NetSIO bridge are cloned
  into build/fujinet (upstream), not the user's fujinet-firmware tree.
- FMS data under the OS ROM (2026-11-03): the file system's tables (FCBs,
  drive table, working variables) moved from main RAM to $C200-$C54C
  (under the ROM; the FMS runs with the ROM off). Only the 512-byte SIO
  buffer stays in main RAM. MEMLO went from $185E to $1491. SDX with USE
  BANKED reaches $1002 by putting its data in an extended bank; EOS can go
  further the same way (open item).
- Page 0 across D: (2026-11-03): EOS's D: entries save and restore $15-$16
  and $43-$48 (EOS's own pointers), as SDX leaves them alone.
- Burst I/O (2026-11-03): only when page 0 still holds the IOCB's buffer and
  length (the first byte of a CIO transfer) and the command is 7 or 11:
  BASIC may call a handler's PUT directly with page 0 left from an OPEN.
- EOSFS version 1 (2026-11-03): an SDFS 2.1 disk whose sector maps are
  extent lists (revision byte $45), so EOS's directory, path and kernel code
  is shared and raw directory programs keep working; the separate 32-byte
  entry format and the hash index of the first draft move to a later
  version (docs/EOSFS.md section 5). The speed comes from contiguous files
  without map sectors in between and from E1/E2.
- RESET (2026-11-03, D1): the OS calls cart init, then DOSINI, then the cart
  run address. EOS's re-init happens in k_dosini (DOSINI), so a resident
  program that chained to it (RHND850) puts its own MEMLO and R: back after
  EOS: MEMLO as at the last prompt (res_ml), D: in HATABS, the S_ADDIZ
  routines oldest first. The cart run then enters the command processor
  without copying the kernel image again: symbols, drivers and the reset
  queue stay; program levels end and files close as after a failed program.
- SIO and concurrent mode (2026-11-03): the OS's SIO uses the serial
  interrupt vectors and turns the serial interrupts off when it ends; with
  an R: handler in concurrent mode (Mutineer online) a disk access on the
  real Atari OS hung. EOS's SIOV calls (k_siov) put the OS's own vectors
  (saved at a cold start) in for the transfer, then the program's back
  with its POKMSK/IRQEN and SSKCTL/SKCTL. AltirraOS hid the problem.
- Testing (2026-11-03): emulator tests run side by side (tools/prun.py: a
  Wine prefix, an X server and a modem port per worker; JOBS=3), SDX's
  results are cached by their inputs, `make quick` is a 30 s smoke set.
  eostest went from about 25 to 8 minutes (4 with the cache), cartest
  from about 20 to under 3.
- BW-DOS programs (2026-11-03, S1): a BW-DOS personality instead of a
  second kernel. BW-DOS's COMTAB lives in page 7 ($0700-$07B8), SDX's
  jkernel, device tables and kernel parameters live there too, so the two
  cannot both be present: while a BW-DOS program runs page 7 is BW-DOS's
  (its vectors lead into EOS) and EOS swaps its own in for each call it
  serves (192 bytes each way, under the OS ROM). Recognised by the check
  every BW-DOS command starts with ("S" at $0700, "BW" at $0703); BW-DOS
  programs load at $0400-$06FF, which EOS leaves free.
- D: PUT CHARACTERS burst (2026-11-03): CIO calls the handler with the
  buffer's first byte in A, so that byte is written first and the rest of
  the buffer after it at once.

## Final status (2026-11-03)

What works (all automated, `make all verify test interop eostest cartest
fmttest bwtest eosall mutineer`):
- EOS boots from its AtariMax 1MB cartridge as a drop-in for SDX 4.5: the
  same page 7, COMTAB, library symbols and kernel interfaces, its own
  clean-room code. eostest 100 tests, cartest 170 CAR: command probes
  matching SDX's output (or with a written reason), fmttest 15 FORMAT
  cases (SD to 16 MB, Advanced, EOSFS), bwtest 16 BW-DOS commands.
- SDX programs and disks, BW-DOS programs and disks (a BW-DOS page 7
  while they run), Atari DOS 2/2.5 disks read and written.
- Resident drivers and RESET as on SDX; the SIO driver interface
  (jsector_io with memreix and XDCB, jblock_io); _RAWCON consoles
  (RC_GR8 + CON.SYS, Sparta Commander through $COMSPEC, EDX); CAR:
  drivers RAMDISK (three), Z, COMEXE, RUNEXT, DOSKEY (history, aliases,
  &, TAB completion), ENV (a 16 KiB environment); FORMAT and BUILDDIR in
  the library; Ultra Speed SIO (SIOSET n US); EOSFS v1 (extent lists)
  alongside SDFS.
- The Atari Mutineer BBS: every matrix cell that SDX runs passes on EOS
  (base, real OS ROM, PAL, 256K, 320K Compy, 576K, 1088K, USE BANKED,
  RAM disk); RESET at WFC behaves as SDX's.
- The Toolkit: 84 of 106 non-65816 binaries give SDX's output, 10 wait
  for a key on both; the 12 others have their reasons in PROGRESS.md.
  EOS gets its own Toolkit (toolkit/, the user's decision 2026-11-04):
  the small utilities first, each tested against the SDX one.
- Speed (frames, SIO patch on, 720 KB disk): copying 40 KB: EOS 305
  (SDFS), 312 (EOSFS), SDX 722; listing 60 files: EOS 19, SDX 137; 120
  seeks in a 300 KB file: EOSFS 80, EOS on SDFS 134, SDX 803.

What SDX itself cannot do here (out of scope, recorded): Mutineer on 64K,
128K, the 130XE, 1200XL and XEGS, with USE OSRAM, without a clock, on
576K Compy; a caller through FujiNet-PC or the R-Verter in Altirra.

Left open, with reasons:
- D3, the file system driver interface (FATFS.SYS, CPMFS.SYS): left out
  by the user's decision.
- 65816 interfaces (_LIBVEC/_EXCVEC, the H_ calls): no 65816 machine to
  test on.
- (Done since: XEP80.SYS, Altirra's handler, eos/xep80; SIOSET XF and
  INDUS, the XF551's high speed commands; XCOMLI and VALIDATE, learned
  from the Toolkit's XCOMLI.SYS, XT, SCBATMAN and ARCLOCK.)
- E1/E2/E3's speed work beyond what is done (the cache kept per disk,
  direct whole-sector writes, Ultra Speed found by itself, XF551 and Indus
  high speed commands, EOSFS's name index): read-ahead, multi-sector SIO,
  24-bit sector numbers (left out by the user's decision). EOS is faster
  than SDX in every benchmark (docs/BENCHMARKS.md).

