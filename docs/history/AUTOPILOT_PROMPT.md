# Autopilot: finish EOS (Extendable Operating System)

You are working in `/home/megalith/AtariProjects/BW-DOS/1.5`. EOS is a public
domain (CC0) cartridge OS that replaces the SpartaDOS X 4.5 cartridge
(AtariMax 1 MB, CAR type 42), so that SDX programs, drivers, batch files and
disks work unchanged, plus EOS's own native file system. Phases A-C are done
(C5 apart from the items below); the RAM disk is done.

**Your job: finish everything.** The user expects a complete, fully working
OS when they return, not a partial one and not a progress report. That
means everything open in PROGRESS.md, everything in MUTINEER_PROMPT.md, and
EOS's native file system, built, tested and committed.

## How to behave (these override any habit of pausing)

- **Never stop to ask questions.** There is no one to answer. Every
  decision is yours: pick the option most compatible with real SDX (or,
  for EOS's own features, the one the plans below describe), record it
  under "Decisions" in EOS_PLAN.md with the reason, and keep going.
  Questions that would once have gone to the user go in PROGRESS.md under
  "Blocked" *with the choice you made*, and you carry on with that choice.
- **Never stop for a small victory.** Finishing an item, a phase or a
  passing test run is not a stopping point: commit and take the next
  item at once. Do not write summaries for the user between items.
- **Never leave work half done.** If an item is hard, break it down and do
  the parts; if one approach fails, try another. "Open", "later" and
  "XFAIL" are only for things that are truly impossible (SDX itself can't
  do it, Altirra can't emulate it, or the clean-room rule forbids it), each
  with the written reason.
- **Stop only when the "Done" list at the end holds**, all of it.

## Start of every session

1. Read `EOS_PLAN.md`, `PROGRESS.md` (whole), this file and
   `MUTINEER_PROMPT.md`.
2. Run `make quick` (30 s), and before each commit `make all verify test
   interop eostest cartest` (eostest and cartest run side by side through
   tools/prun.py), and compare with the last recorded results. Fix any
   regression first.
3. Take the first unfinished item in the order of work below.

## End of every work unit

- PROGRESS.md: tick what is done, note what is half done and the exact next
  step, record the latest test counts.
- EOS_PLAN.md "Decisions": every design choice, with its reason.
- Run the full suite, then commit: one commit per finished item, saying
  what now works, ending with the attribution line the session gives.

## Fixed constraints (don't revisit)

- **Hardware:**
  - Target cart: AtariMax 1 MB (CAR type 42). Same as
    `~/AtariMutineer/Privateer/third_party/SDX450_maxflash8.car`.
  - Machines: stock 6502 XL/XE only, 64K minimum (600XL+64K, 800XL, 1200XL,
    65XE, 130XE).
  - No 65816 support (no H_* symbols, no $FFF9 blocks), no 400/800, no turbo
    boards.
- **Clean room:**
  - Never copy SDX kernel or library code, and never disassemble the SDX
    cartridge ROM.
  - You may disassemble the SDX Toolkit binaries (in `toolkit.atr`) to learn
    the undocumented interfaces they call.
  - You may watch real SDX from outside in the Altirra debugger: memory
    dumps, breakpoints on symbol addresses, register and memory state before
    and after a call.
  - Don't put SDX binaries in our cartridge. Write our own CAR: commands from
    the SDX 4.5 User Guide.
  - Mutineer's files may be read, run and disassembled to learn what it
    needs; nothing of it goes into EOS.
  - The Atari DOS 2.5 sources (`dossrc*.atr`) are Atari's: use them as a
    disk format reference only, copy nothing into EOS.
- **Scope (user decision, 2026-11-03): EOS works within itself.** It must
  run SDX programs and drivers and use SDX disks, run BW-DOS programs and
  use BW-DOS disks, and read and write Atari DOS 2/2.5 disks. SDX and
  BW-DOS are references for behaviour, not test targets: new tests check
  EOS on its own with the expected result in the test; recorded SDX
  results (build/sdx-cache, tests/carref) stay; SDX-only quirks that no
  program depends on are not copied.
- **Behaviour programs depend on follows SDX:**
  - For example, `>>file` redirection creates or replaces the file; it
    does not append.
  - Fixed addresses must match the measured ones in EOS_PLAN.md: the page 7
    variables, LBUFF $0580, the COMTAB offsets, DOSVEC → COMTAB.
  - With default settings MEMLO must be no higher than $18FF, because
    programs count on that much free memory.
  - Symbol addresses may differ.
- **Don't break what works.** `make verify` must keep passing: 69 binaries
  byte-identical to DOS/, plus the ones listed in CHANGES.md. So must
  `make test` (BW-DOS ATR and CAR boot tests) and `make interop` (BW-DOS ⇄ SDX
  disk exchange). Build the new OS as new targets next to the old ones.
- **Names:**
  - The OS is called EOS (Extendable Operating System) in its banner, cart
    image (`build/EOS.car`), make targets (`eos`, `eostest`) and sources
    (`eos/`).
  - System files are `EOSSYS.SYS` (CONFIG.SYS syntax) and `EOSAUTO.BAT`. Fall
    back to `CONFIG.SYS` / `AUTOEXEC.BAT` when they are missing.
  - Never treat `AUTORUN.SYS` as a batch file.
  - Keep SDX's names where programs depend on them: `CAR:`, DEVICE driver
    names, environment variables, and the version information SDX programs
    check.
- **Assembler:** MADS 2.1.7 (`mads`). MADS labels are case-insensitive. Don't
  use `end` or `rts` as labels.
- **License:** EOS is public domain (CC0), see `LICENSE.md` and
  `CONTRIBUTING.md`. Everything written for EOS is CC0 too.
- **User requests (PROGRESS.md):**
  - CIO `D:` stays D1:. A name with no device at all means the current
    drive and its current directory, then $PATH (B0b).
  - EOS reads, writes and runs Atari DOS 2.0S / 2.5 / MyDOS disks, writing
    DOS 2.5's extended sectors too, beyond SDX's read-only support (B9).

## Resources

- **Specs:**
  - `SDX450_Programming_Guide.pdf` and `SDX450_User_Guide.pdf`.
  - Text versions are in `build/pg.txt` and `build/ug.txt`. Regenerate with
    `pdftotext -layout` if they are missing.
  - The Programming Guide is the API spec for every documented symbol.
- **Atari wiki (local copy):** `~/AtariProjects/Info_Gathering/wiki/content/`
  (1.8 GB of Markdown and attachments, from the user). It has DOS manuals
  (MyDOS 4.x user guides in `DOS/MyDOS/`, SpartaDOS, BW-DOS), memory maps,
  XIO codes (`Todos/XIO_Command_Codes_DOS_Handler/`) and 815 ATR images:
  589 single density, 127 enhanced density (1040 sectors, e.g.
  `Companies/Atari/Atari_Personal_Financial_Management_System/attachments/*MD-DOS_2.5.atr`),
  56 double density, and MyDOS disks (`DOS/MyDOS/attachments/720K_MyDOS-2.atr`).
  Use it for test media and format references (search with `grep -ril`);
  the clean-room rules still apply to anything SDX in it.
- **Atari file tools (the user's):** `~/AtariProjects/m65-lister/build/m65`
  lists MAC/65-tokenized sources (the DOS 2.5 `.M65` files: `-c -n`);
  `~/AtariProjects/atari_8bit_utils/` has atr2unix / unix2atr.
- **`tools/emu.py`:** the headless Altirra runner (wine + xvfb).
  - `Session(out, disks, cart=, memsize=, turbo=, debugcmds=)`.
  - `wait(disk, file)` polls an ATR for a marker file.
  - Also `bwdos_disk()`, `mkatr()`, `extract()`, `type_line()` and
    `screenshot()`.
- **`tools/sdxprobe.py`:** boots real SDX and dumps memory.
  - `sdxprobe.py symbols [64K|128K]` resolves all 157 surveyed symbols on
    real SDX (`tools/probe/symdump.asm`, weak imports).
  - Extend it to probe anything you need to match.
- **Other tools:**
  - `tools/sdfs.py check|ls|extract` checks a SpartaDOS file system image on
    the host.
  - `tools/sdxbin.py` parses SDX binaries and `--weak`s their imports.
  - `tools/unarc.py` unpacks Toolkit `.ARC` files. `toolkit.atr` is
    extracted to `build/tk/` (`sdfs.py extract toolkit.atr build/tk`), and
    every archive in it unpacked to `build/tkx/` (unarc.py on each `.ARC`).
- **Survey data:**
  - `build/survey/symbols.txt` gives each symbol's use count and whether the
    SDX cart uses it.
  - `build/sdxprobe/symbols.txt` gives the real addresses.
- **EOS tools (written in Phase A):**
  - `tools/hostsim.py` runs the cart on the host (6502 in `tools/m6502.py`,
    AtariMax banking, Python CIOV for E: on IOCB 0 and SIOV for ATRs): a
    command takes under a second. Debug there first (trace kernel calls,
    SIO, labels from `build/eos/*.lab`), then check in Altirra. It has no
    real CIO for other IOCBs and no OS ROM.
  - `tools/eos_test.py` is the test suite. `oracle(name, files, commands,
    disk=, geo=)` runs the same AUTOEXEC.BAT on SDX (ending in SDXPROBE) and
    on EOS (dumped at the next prompt, `k_getline`), compares screen lines,
    and with `disk=True` also files, attributes and free sector count.
  - `tools/interop_test.py --eos`: EOS does the middle step
    (`tests/eos/IOP.asm`); `make interop` runs both variants.
  - `tools/tk_survey.py`: the Toolkit survey (SDX results cached in
    `build/survey/sdx/`).
  - `tools/sdfs.py build` makes SDFS 2.1 images of any geometry (mkatr has
    no 512-byte sectors). `tools/dis6502.py` disassembles Toolkit binaries
    with their fix-ups and symbol references. `tools/probe/` holds probes of
    real SDX (`show_gefina.py`).
  - Test programs are in `tests/eos/*.asm` (relocatable: MADS `blk reloc`,
    `smb`), built by `make eos`.
- **Existing code:**
  - `SOURCES/` (BW-DOS 1.5) is a reference only: its FMS is self-modifying
    and cannot run from ROM, so EOS has its own (`eos/fms.asm`).
  - `carts/cartldr.asm` boots a DOS from an AtariMax cart.

## How to test

- **Oracle.** Every behaviour test runs the same thing twice: on real SDX (the
  cart above) and on ours. Then compare:
  - the hard-copied output logs;
  - the resulting disks, checked with `sdfs.py check` and diffed per file.
- **Tests.**
  - Put new tests in a new `tools/eos_test.py` (or several), behind make
    targets such as `make eostest`.
  - Each test prints PASS / FAIL / XFAIL.
  - XFAIL is allowed only for an item that is still open in PROGRESS.md.
- **Measure the Toolkit.**
  - Record, per phase, how many of the 106 non-65816 Toolkit binaries load
    and run on our OS with the same output as on SDX (`tools/tk_survey.py`;
    the 106 are the unique names of all binaries in `build/tkx/` without
    $FFF9 blocks or strong `_65816` / `H_*` references).
  - Keep a table of them in PROGRESS.md.
  - That number is the main progress measure for phases B to D.
- **Target machines.** Run the main tests on a 64K 800XL and on a 128K
  130XE. Altirra's `/memsize:128K` gave the same SDX layout as 64K.
- **USE BANKED.** When EOSSYS.SYS / CONFIG.SYS processing exists, probe real SDX with USE
  BANKED on a 130XE and match that layout too.

## Known pitfalls (learned the hard way)

- **Altirra flags and settings:**
  - Run with `/portablealt:<ini> /bootrw /noaccuratedisk /burstio`, with
    `"Turbo mode" = 1` in the ini (`turbo=True`). SDX uses its own SIO code
    and is very slow without turbo.
  - `.car` files need no `/cartmapper`.
  - Altirra reports odd geometry for non-standard 512-byte images; use
    1440×512.
- **Altirra debugger:**
  - Syntax is `/debug /debugcmd "bp $addr \".writemem Z:\\path 0 L10000\""`.
    `bp -c` is invalid. Paths need Windows backslashes (`emu.win()`).
  - Debugger logs aren't flushed when the emulator is killed. Write results
    to files with `.writemem`, or to the ATR, and poll for them.
- **Typing and batch files:**
  - xdotool types `:` as `;` into Altirra. Avoid drive prefixes in typed
    lines; put commands in batch files instead.
  - On SDX, D1:AUTOEXEC.BAT runs at boot.
  - BW-DOS batches stop at the first error.
  - BW-DOS `PRINT file` hard-copies output to a file, and the length is set
    only when the file is closed. If a test times out, type `PRINT` so the
    log gets closed.
- **SDX commands:**
  - `FORMAT /QQ D2: name` soft-formats without prompting.
  - `DIR D2:\BW\` needs the trailing backslash.
  - `>>` replaces the file, so use one log file per command.
- **Cartridge and memory:**
  - The XL OS leaves internal BASIC enabled when a cart is present. A
    cart-booted DOS must set PORTB bit 1 and BASICF=1 when it switches the
    cart out.
  - Altirra restores cart banking only on cold reset.
  - An 8192-sector disk's bitmap has no bit for sector 8192.
- **Running tests:**
  - Run emulator tests side by side only through `tools/prun.py` (each
    worker has its own Wine prefix, X display and modem port, and copies
    the cart, so rebuilding meanwhile is safe). Two scripts started
    directly share build/wine: never run two of those at once, as each
    session ends with `wineserver -k`.
  - To stop stray emulators use
    `WINEPREFIX=$PWD/build/wine wineserver -k`; `pkill -f Altirra` matches
    the shell running it and kills that.
  - SDX ignores AUTOEXEC.BAT on a disk whose boot header (bytes 0-8, 37) is
    zero; `sdfs.py build` writes it as SDX FORMAT does.
- **MADS and SDX binaries:**
  - A backslash in a character literal or a comment breaks MADS; use the
    `BSLASH` equate and write "backslash" in comments.
  - Out-of-range branches: use `jcs`, `jne` ... (MADS picks the short form
    when it fits).
  - Relocatable code cannot split an internal address (`lda #<x` /
    `ldx #>x`); keep addresses in `dta a(x)` words.
  - A bank's code cannot pass the library a pointer into its own bank:
    strings for the library must be in RAM.
- **Hardware details learned:**
  - After SIOV, DSTATS holds the status, not the direction.
  - Under the OS ROM ($D800-$DFFF holds the sector cache) the DSK: driver
    runs with the ROM off; the IRQ/NMI stubs push a status with B clear.
- **Shell safety:** never use `rm -rf` with a glob after `cd`. Make fresh
  directories instead, and delete only explicit paths under `build/`.

- **Learned in Phase C:**
  - Boot must set the NMI/IRQ vectors under the OS ROM before the first
    k_romoff, and copy the ROM font under the ROM (rows drawn while the ROM
    is off show stripes otherwise). Bank counting must stop at a bank that
    aliases main memory (320K RAMBO).
  - Text comparisons can't see display corruption: for anything touching
    the display, PORTB, the ROM switch or interrupts, take a screenshot and
    look at it. Check every new feature with the SIO patch off and accurate
    disk timing, and on 320K RAMBO.
  - The command table is over 256 bytes: walk it with a pointer.
  - Comments describe the code; no "(User Guide 4.23)"-style citations.

## Order of work

All of it is required. Work in this order; within a step, follow
PROGRESS.md's items.

1. **Finish what is running or uncommitted.** If the working tree has
   uncommitted changes (the RAM disk, PROGRESS.md/EOS_PLAN.md updates),
   run the full suite and commit them.
2. **FORMAT (PROGRESS.md "FORMAT", F1-F4).** Fix "144 Write protected or
   bad sector" on 1440 x 512 (`tools/fmt_test.py` f-user720k reproduces it; the lead:
   pformat never checks the status of the PERCOM write 'O'). Hard disks
   and partitions up to 16 MB (IDE 2.0 Plus, SIDE, FujiNet, APE/SIO2PC
   images), the sector count shown before formatting, the standard sizes
   (90K, 127K, 180K, 360K, 720K, 1.44 MB, 16 MB) and an Advanced choice
   (sectors, density, tracks/sides). Test each size by formatting in
   Altirra and checking the result with `tools/sdfs.py check`.
3. **The Mutineer milestone: everything in MUTINEER_PROMPT.md** (its goal,
   matrix, harness `tools/mutineer_test.py` and `make mutineer`): BASIC
   command and `<<` reaching E:, resident programs and R: handlers (D1), the
   SIO driver interface (D2), RTIME8.SYS and JIFFY.SYS, then whatever the
   BBS needs next, until every matrix cell that works on SDX works on EOS.
4. **Phase D (D1-D4)**: whatever step 3 did not already finish, including
   _RAWCON (D4: CON.SYS, SC, EDX). Not the file system driver interface (D3:
   FATFS.SYS, CPMFS.SYS): left out by the user, added only if someone asks.
5. **The rest of C5 and the open notes in PROGRESS.md**: MAP's own table,
   the FMS stamp call and `dateset`, SDX's free counts for empty files and
   files open for writing, CHKDSK /X redirected, running a command line
   from a program, resident programs after RESET, the remaining CAR:
   drivers (COMEXE DOSKEY ENV QUICKED ...), each one working, not a stub.
6. **Phase E: EOS native file system (E1-E4).** E4 first: write the full
   EOSFS specification into `docs/EOSFS.md` (on-disk layout, extents,
   indexed directories, allocation, the dirty flag and mount check, 24-bit
   sectors, boot, how it appears through the kernel). The user has approved
   the plan in PROGRESS.md; do not wait for review, build it. Then E1
   (faster SDFS: cache, read-ahead, write-behind, contiguous allocation),
   E2 (multi-sector / high-speed SIO), E3 (EOSFS in the FMS, FORMAT's Mode
   choice "EOS", CHKDSK and a host tool `tools/eosfs.py build|check|ls|
   extract` like sdfs.py). Tests: every file system test that runs on SDFS
   also runs on EOSFS (a parametrized copy of the oracle tests where EOS's
   output is compared with SDX's on SDFS), plus speed measurements (frames
   to copy and to list a large directory, SDFS vs EOSFS, before vs after
   E1) recorded in PROGRESS.md.
7. **T1: test everything inside EOS.** Boot EOS and run every CAR: command,
   driver (.SYS) and utility with its main options, on each standard disk
   size, SIO patch on and off, 64K and 320K RAMBO, with screenshots for
   anything that draws on the screen. These are EOS tests (expected
   results written from the commands' documented behaviour), not SDX
   comparisons. Fix every failure. Keep them as `make eosall`.
8. **Toolkit table**: every non-65816 Toolkit binary runs the same on EOS
   as on SDX, or has a written reason.

## Done

Stop only when all of this holds:
- every item in PROGRESS.md is ticked (or has a written reason it is
  impossible: SDX can't, Altirra can't emulate it, or clean room forbids);
- MUTINEER_PROMPT.md's goal holds: its full matrix green or SDX-FAILS;
- EOSFS works: formatted, read, written, booted, checked, faster than SDFS
  by the recorded measurements, with its specification in docs/EOSFS.md;
- FORMAT handles every standard size, Advanced, and hard disks to 16 MB;
- `make all verify test interop eostest cartest eosall mutineer` passes on
  800XL/64K, 130XE/128K and 800XL/320K RAMBO;
- every non-65816 Toolkit binary runs as on SDX, or has a written reason;
- EOS_PLAN.md has a final status section and everything is committed.
Then write the user one short summary: what works, what SDX itself can't
do, and anything impossible with its reason.
