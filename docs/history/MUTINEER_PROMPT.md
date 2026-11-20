# Autopilot: EOS runs Atari Mutineer BBS everywhere SDX does

You are continuing EOS (Extendable Operating System), the MIT-licensed
replacement for the SpartaDOS X 4.5 cartridge (AtariMax 1 MB, CAR
type 42), in /home/megalith/AtariProjects/BW-DOS/1.5. Work autonomously
until the goal below is met. Do not stop to ask unless a decision is
genuinely the user's (then ask once, briefly, and carry on with other work).

## The goal

`atari-mutineer-v1.4.1-16mb-all-drivers.atr` (repo root, a 16 MB SDFS disk)
boots and runs the Atari Mutineer BBS on EOS **in every Altirra
configuration where it runs on real SDX 4.5**, with every communication
driver on the disk, and a caller can connect, log in and use it.

"Runs" means, for each configuration in the matrix below:
1. Cold boot EOS (build/EOS.car) with the Mutineer disk in D1:.
2. Start the BBS with the disk's own batch file for that driver:
   `START850` (Atari 850: RHND850.COM), `STARTFN` (FujiNet: NHAND.COM),
   `STARTRVF` (full R-Verter: RVRFULL.COM), `STARTRVT` (two-wire R-Verter:
   RVRTWOW.COM). Each loads its resident R: handler, the resident
   REMMS.COM, then `BASIC /I <<D1:AUTOGO`.
3. The BBS reaches its waiting-for-call (WFC) screen, as on SDX.
4. A caller connects through the emulated modem / network device, gets
   the login screen, logs in (create a user the first time), reads a
   menu, reads and posts a message, lists the file base, enters and
   leaves a door (BLKJACK, DUMJIN, ARENA), and logs off; the BBS returns
   to WFC. Data files on the disk change as they do on SDX.
5. RESET at WFC and a COLD restart behave as on SDX (resident drivers
   reinstalled or preserved as SDX does).

Done = every cell of the matrix that works on SDX also works on EOS, all
automated, all recorded in PROGRESS.md, all committed.

## The matrix

Build it from what this Altirra install actually offers (check
`tools/emu.py` for how Altirra is run; read Altirra's help /command line
options and its device list; do not guess device names):
- Machine: 800XL, 130XE, 65XE/800XE, XEGS (and 1200XL if offered).
- Memory: 64K, 128K, 256K RAMBO, 320K RAMBO, 320K COMPY, 576K RAMBO,
  576K COMPY, 1088K (and whatever else Altirra lists).
- OS: AltirraOS (default) and, if a real XL OS ROM is configured, that.
- Video: NTSC and PAL.
- Disk: SIO patch on and off; accurate sector timing on and off.
- Clock: none, R-Time 8 (EOS needs RTIME8.SYS), JIFFY.
- CONFIG: none (EOS defaults incl. the default RAM disk), USE OSRAM,
  USE BANKED, a CONFIG.SYS / EOSSYS.SYS with RAMDISK.
- Communication: Atari 850 + modem (Altirra's modem emulation; connect by
  telnet to the port Altirra listens on), FujiNet (Altirra's NetSIO /
  FujiNet support if present, with the FujiNet-PC / netsio bridge this
  machine has — look for it under ~/AtariProjects, e.g. fujinet-firmware),
  R-Verter full and two-wire (if Altirra emulates them; if it cannot,
  record that and test what it can).
Do not run the full cross product blindly: first find each axis's effect
(one axis at a time from a base of 800XL/320K RAMBO/NTSC/850), then run
the combinations that can differ. Every cell is first run on SDX; a cell
where SDX itself fails is recorded as such and is out of scope.

## How to work (fixed rules; they override anything else)

- **Clean room.** Never copy SDX kernel/library code and never disassemble
  the SDX cart ROM. Real SDX may be observed from outside (Altirra:
  screens, memory dumps, files it writes). Toolkit binaries may be
  disassembled. No SDX binaries in the cart. Mutineer's own files may be
  read and run, and Mutineer may be disassembled to understand what it
  needs from the DOS, but nothing of it goes into EOS.
- **Compatibility is defined by real SDX.** Where SDX does something odd,
  do the same. Measure SDX first (tools/carref.py pattern: run on SDX,
  keep its output as a reference), then make EOS match.
- **Don't break what works.** `make verify`, `make test`, `make interop`,
  `make eostest` and `make cartest` must keep passing. Run the full suite
  before each commit.
- **Fixed addresses**: page 7, LBUFF $0580, COMTAB at $0A3A (DOSVEC),
  WRTCMD COMTAB-2, sio_index COMTAB2+2, MEMLO <= $18FF (lower is better).
- **Names**: EOS banner, build/EOS.car, eos/ sources, EOSSYS.SYS /
  EOSAUTO.BAT with fallback to CONFIG.SYS / AUTOEXEC.BAT. AUTORUN.SYS is
  never a batch file.
- **MADS 2.1.7**: labels are case-insensitive (watch clashes with
  equ.icl names); no `end`/`rts` labels; no backslash in comments or char
  literals (BSLASH); long branches via jeq/jne/...; in relocatable
  programs `#<label` is not relocated (go through `dta a(label)`).
- **Comments**: describe what the code does; no "(User Guide 4.23)"
  style citations.
- **Emulator**: one Altirra at a time (never two scripts at once), and
  never rebuild build/EOS.car while one runs. Stop strays with
  `WINEPREFIX=$PWD/build/wine wineserver -k`. Our tests normally run with
  the SIO patch on and fast boot: every new feature must also be checked
  with the SIO patch off and accurate timing, and on 320K RAMBO (both
  have hidden real bugs before).
- **Screens**: text comparisons cannot see display corruption; for
  anything that touches the display, PORTB, the OS ROM switch or
  interrupts, also take a screenshot mid-operation and look at it.
- **Agents**: parallel subagents are fine for independent pieces (follow
  scratchpad CAR_BRIEF.md's pattern: own files only, host simulator
  only, no emulator, no build/), coordinate the emulator runs yourself.
- **Records**: each work unit ends with PROGRESS.md updated (ticks, test
  counts), decisions in EOS_PLAN.md "Decisions", and one commit per
  finished item ending with the attribution line given in the session.

## What is known to be missing (start here)

PROGRESS.md "Milestone: Atari Mutineer BBS" lists it; in short:
1. **RAMDISK.SYS**: RAM disk on O: (default without a config, as SDX:
   all banks minus the 4 kept for 130XE programs), `DEVICE RAMDISK
   [drive[,nbanks]]`, "Ramdisk preserved" over COLD, $TEMP/$RAMDISK/
   $BASIC/$CAR defaults. Measure SDX's (CHKDSK O:, SET) first.
2. **BASIC command** (internal BASIC on; /I and the other switches SDX
   has) and **`<<` redirection reaching E:** — BASIC reads the screen
   editor, so redirected input must feed CIO E: reads as SDX's does;
   `$BASIC` memory save if SDX does it.
3. **Resident programs (phase D1)**: INSTALL / raised MEMLO, S_ADDIZ
   reset routines run after RESET, R: handlers in HATABS surviving the
   program's end and RESET as on SDX; DOSINI chain.
4. **SIO driver interface (D2)** as far as the R: handlers and REMMS need
   it (jsector_io, sio vector at $0718, SIOSET state).
5. **Clock**: RTIME8.SYS and JIFFY.SYS filling the CLK: kernel functions
   and I_GETTD/I_SETTD, so files and the BBS get dates.
6. Whatever Mutineer's BASIC programs and its .COM tools (REMMS,
   XM/YM protocols, FILSTORE, MSGNET ...) use: run them, find the first
   difference from SDX, fix, repeat. Disassemble Mutineer's .COM files
   when needed to see which kernel/library calls they make.
7. Open C5 items that may matter: MAP's own table, an FMS stamp call and
   `dateset`, SDX's free-sector count while a file is open for writing,
   running a command line from a program.

## Testing the BBS (build this harness first)

Write `tools/mutineer_test.py`:
- boots a given configuration (machine, memory, OS, video, SIO patch,
  timing, clock, cartridge = EOS or SDX, devices = 850+modem / FujiNet /
  R-Verter), with a fresh copy of the Mutineer disk;
- types the START batch name and waits for WFC (screen text and a
  screenshot);
- acts as the caller: telnet into Altirra's modem port (or the FujiNet
  bridge), drives the login and the menu walk above with expect-style
  steps and timeouts, and records the session transcript;
- compares the caller transcript and the files changed on the disk
  between SDX and EOS for the same configuration (dates aside unless a
  clock is present on both);
- `make mutineer` runs the matrix and writes a table (configuration ×
  driver → PASS / FAIL / SDX-FAILS) to build/mutineer-results/.
Keep each run independent (fresh disk copy) and bounded by timeouts.

## Order of work

1. Run the existing suites; read EOS_PLAN.md, PROGRESS.md (whole),
   AUTOPILOT_PROMPT.md, CAR_BRIEF.md if present, and this file.
2. Build tools/mutineer_test.py; run Mutineer on SDX in the base
   configuration with each driver and keep the reference transcripts.
3. RAMDISK, then BASIC + E: redirection, then resident programs, then
   clocks, then whatever the first failing step of the BBS needs next.
   After each fix: the relevant oracle tests, the full suite, the
   Mutineer base configuration; commit.
4. When the base configuration passes for all drivers, widen the matrix
   axis by axis, fixing what differs.
5. Finish with the full matrix green (or SDX-FAILS), PROGRESS.md and
   EOS_PLAN.md updated, everything committed, and a short summary for
   the user of what works, what SDX itself cannot do, and anything left.
