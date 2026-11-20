# EOS User Manual

EOS (Extendable Operating System) is a DOS for Atari 8-bit computers. It is
designed as a SpartaDOS X 4.5 cartridge replacement and runs many SDX and
BW-DOS programs and drivers. EOS also reads and writes Atari DOS 2/2.5 disks
and has its own optional EOSFS disk format.

This manual covers getting started, configuring and operating EOS, using the
full command set, and programming for EOS. Build and code maintenance
instructions are in [Building EOS](BUILDING_EOS.md). The command pages
are also available on the machine with `MAN command`.

## 1. What you need

### To run EOS

- An Atari 8-bit XL/XE computer, or a compatible emulator.
- One of the EOS images in a cartridge or flash slot: `EOS.car` in an
  AtariMax/Maxflash 8 Mbit (1 MiB) cartridge, `EOS_U1MB.rom` in an Ultimate
  1MB's SDX slot, or `EOS_SIC.car`/`EOS_SICP.car` in a SIC!/SIC!+ cartridge
  (see [Hardware compatibility status](#hardware-compatibility-status)).
- A disk device or image for files and configuration. EOS can start without a
  DOS disk because its command processor and core drivers are in the cartridge.

The standard image uses the AtariMax 1 MiB format of the SDX 4.5 cartridge. Hardware
and installed memory affect which optional drivers and memory modes are useful.

## 2. First boot

1. Attach or mount the EOS cartridge and power on or reset the Atari.
2. EOS initializes its drivers and command processor. The default command
   search path and manual path are `CAR:`; built-in commands work even if no
   disk is mounted.
3. Insert or mount a data disk, then inspect it with `DIR D1:` or
   `CHKDSK D1:`. Substitute the actual drive number for `1`.
4. For a quick orientation, try:

   ```text
   VER
   DEV
   MEM
   DIR D1:
   MAN COPY
   ```

At a prompt, a drive letter is a drive number: `A:` is D1, `B:` is D2, and so
on through `O:` for D15, except for a letter that names a CIO device. When a
handler for the letter is installed (the OS has C: E: K: P: S:, others come
with drivers: R:, H:, N: ...), the letter is that device, never a drive:

- `D:` is always D1:, as in programs that open `D:` through CIO (`DIR D:`,
  `TYPE D:FILE.TXT`), whatever the current drive.
- `E:` is the screen (CON:), `P:` the printer (PRN:).
- Other CIO letters (`C:`, `K:`, `S:`, `R:` ...) answer 130 (Nonexistent
  device): EOS's commands reach only its own devices.

A drive whose letter is a CIO device's is written `D` and its number, or its
letter from drive 10 on: `D3:`, `D4:`, `D5:`, `DK:` (drive 11). EOS shows
those drives so wherever it names a drive (DF, PWD, FIND, MAP, the prompt's
`$L`, the RAM disk's `$RAMDISK`). `D1:` ... `D9:` and `DA:` ... `DO:` always
name drives. A device name such as `CAR:` selects the cartridge file
system. (SDX reads `A:` ... `O:` as drives whatever CIO has: its `D:` is
D4:, its `E:` drive 5.)

## 3. Command line and paths

EOS accepts SpartaDOS-style command lines. Commands are either built into the
command processor, supplied by the cartridge, or loaded as program files from
the search path/current directory. Enter a command name followed by its
parameters; for example:

```text
DIR D1:>GAMES>
COPY D1:>NOTES.TXT D2:
```

Command names and options are case-insensitive. In command syntax, square
brackets mean optional text, `|` separates alternatives, and a word in
lowercase such as `file` or `unit` stands for a value you supply. The options
available depend on the command; a slash option is not universal. Most
commands accept several option letters together only where their own help
page says so.

The command processor supports file input/output redirection and pipelines.
`<<file` supplies a file as standard input, and `>>file` writes standard
output to a new file (replacing a file with that name if it exists). The same
redirection markers can be placed on a command line; the first input and
output redirection is used. `A | B` connects A's output to B's input through
temporary files. For example:

```text
CAT D1:>DOCS>*.TXT | LESS
MAN COPY | LESS
DIR >>D1:FILES.TXT
```

Redirections are processed by the command processor before it invokes a
program. A program that uses the DOS standard stream APIs can therefore work
with the keyboard, screen, files, devices, and pipes. Some programs open the
screen or keyboard directly and may not honor redirection.

Paths use `>` between directories. Backslash is also accepted by many path
commands. A directory path ends with `>` (or `\`) when the command needs to
list or address its contents. `..` means the parent directory. If a drive or
directory is omitted, EOS uses the current drive or current directory.

```text
CD                 ; show current directory
CD D1:>GAMES>       ; change directory on D1
PWD                ; print current directory
DIR *.COM          ; list matching files
```

Names follow the 8.3 convention on SDFS and Atari DOS volumes. Wildcards
include `*` and `?`. A semicolon separates entries in `$PATH` and `$MANPATH`.
Commands can be redirected or piped where supported by the command processor;
for example, `MAN DIR | LESS` views a manual page a screen at a time.

## 4. Startup files and configuration

At startup EOS checks drive D1: for `EOSSYS.SYS`. If it is absent, EOS tries
`CONFIG.SYS`, allowing existing SDX startup disks to be reused. The syntax is
the same for both names. EOS then runs `EOSAUTO.BAT` when present, falling back
to `AUTOEXEC.BAT`. It does not run `AUTORUN.SYS`. Hold OPTION during startup
to bypass the configuration file.

EOS includes the disk, SIO, and Atari DOS 2 drivers, so a basic setup does not
need `DEVICE` lines. Configuration commands include:

```text
; Example EOSSYS.SYS
SET PATH=CAR:;D1:>UTILS
SET MANPATH=CAR:;D1:>MAN
SET PROMPT=$D$N
DEVICE RAMDISK 1
```

Lines beginning with `;` are comments. A `?` prefix is accepted before a
configuration line; EOS executes that line without an interactive question.
Supported configuration directives
include:

- `SET name=value` to define an environment variable.
- `DEVICE driver [parameters]` to install a driver from the available files.
- `USE NONE`, `USE OSRAM`, or `USE BANKED` to select memory use.
- `ECHO text` to display startup text.
- `MERGE file` to switch configuration input to another file (default
  extension `.CFG`). The rest of the current file is not read afterward.

EOS initializes `$PATH=CAR:`, `$PROMPT=D$N`, `$SYSERR=CAR:SYSERR.MSG`,
`$MAXDRV=O:`, and `$MANPATH=CAR:` by default. Use `SET` to inspect variables;
`SET NAME=value` changes one, and `SET NAME` removes it. `PATH` is a helper
for changing the command search path. Keep `CAR:` in the path so built-in
cartridge commands remain easy to find.

### Environment variables used by EOS

The command pages mention variables at the point where they apply. This
summary covers variables consumed by EOS's command processor and supplied
commands; applications and third-party drivers may define more.

| Variable | Purpose |
| --- | --- |
| `PATH` | Program search order. The current directory is also searched. |
| `PROMPT` | Prompt template; `PROMPT` expands `$L`, `$N`, `$P`, `$D`, `$T`, and `$R`. |
| `MANPATH` | Directories and devices searched by `MAN`. Default: `CAR:`. |
| `PAGER` | Program used by `MAN` to page a help file. |
| `SYSERR` | File containing messages for system error codes. Default: `CAR:SYSERR.MSG`. |
| `MAXDRV` | Highest drive shown by commands that enumerate drives. Default: `O:`. |
| `DAYTIME` | Date order: `1` means month first; otherwise day first. |
| `TEMP` | Directory for temporary files used by commands such as `MAN` and pipelines. |
| `BASIC` | File used to save and restore built-in BASIC memory. A RAM disk supplies a default if unset. |
| `CAR` | File used to save and restore the plugged-in cartridge's memory. A RAM disk supplies a default if unset. |
| `RAMDISK` | Default drive/path for Toolkit RAM-disk restore tools. Set by RAMDISK installation if unset. |
| `COMSPEC` | Command shell run in place of the prompt; used by shell integrations such as SpartaCommander. |
| `BATCH` | Batch file to run before the next prompt; EOS clears the variable as it consumes it. |
| `COPY` | Alternate program for the `COPY` command. |
| `ED` | Number of visible text-editor lines (1–22; default 10). |
| `SCRDEF` | Screen defaults reapplied by `CLS /F`. |
| `_01`–`_91` | Batch name and parameters 1–9, available while the batch file runs. |

Environment variables are substituted in command and batch lines as `$NAME`;
write `$NAME$` when the variable name must end before the following text.
Escape a dollar sign with `\$` in a batch line. See `MAN SET`, `MAN PROMPT`,
and `MAN BASIC` for command-specific details.

The startup batch file is a good place for commands such as `SETPATHS`,
`KEY ON`, or application setup. Read `MAN SET`, `MAN PATH`, and
`MAN SETPATHS` for details.

Configuration errors and unrecognized lines do not stop later configuration
lines from running. EOS's built-in configuration file in `CAR:` shows the
default setup and documents the supported directive syntax.

Batch files are text files with one command per line. A line beginning with
`;` (leading spaces are allowed) is a comment. `ECHO ON` displays lines as
they run; echo is off by default. Calling `-NAME` runs `NAME.BAT`; parameter
variables are named `_01` for the batch name and `_11` through `_91` for
parameters 1 through 9, so a line can refer to the first argument as `$_11`.
Within a batch line, `%0` through `%9` expand to the same batch name and
parameters. `$NAME` substitutes an environment variable and `$NAME$` ends the
variable name where it touches other text; `\$` leaves a literal dollar sign.
Errors from a command processor built-in that indicate bad parameters or a
missing device stop the batch; `ERROR ON` makes any command error stop it.
`$BATCH` can name a batch file to run before the next prompt; EOS deletes the
variable as it consumes it.

## 5. Files and directories

Common file tasks:

```text
DIR D1:                 ; list drive contents
DIR /W                  ; names in columns
TYPE README.TXT /P      ; display text, pause each screen
COPY *.TXT D2:          ; copy matching files
COPY /R D1:>SRC D2:>    ; recursively copy a directory tree
RENAME OLD.TXT NEW.TXT
DEL *.BAK
MKDIR D1:>DOCS>
CD D1:>DOCS>
```

`DIR` displays names, sizes, dates, and times. `DIRS` gives a compact Atari
DOS-style listing. Attribute filters can include archived, hidden, protected,
and directory entries; `DIR +` includes all attributes. `TYPE` writes a text
file to the screen, while `LESS` and `MORE` provide paged viewing. `COPY`
supports overwrite prompts, quiet mode, move mode, recursive copies, and
verification; see `MAN COPY` for its switches.

`DEL`/`ERASE` removes files; `DELTREE` removes a directory tree. `UNERASE` may
restore deleted entries while their directory slots and data have not been
reused. `RENAME` changes file names, `CHDIR`/`CD` changes a current directory,
and `RMDIR` removes an empty directory. Check exact syntax with `MAN`.

To run a program, enter its name. EOS searches `$PATH` and then the current
directory. For a program in a specific location, give its path. `LOAD`
loads without running; `X` provides additional load/run modes. Programs can
be run from SDFS, EOSFS, BW-DOS, and Atari DOS disks subject to their binary
format and memory needs.

## 6. Disks and filesystems

EOS recognizes SDFS (SpartaDOS 2.0/2.1), EOSFS, BW-DOS, and Atari DOS 2/2.5
volumes, and reads/writes compatible MyDOS data volumes. MyDOS disks are not
bootable by EOS. Atari DOS and MyDOS use their own directory and space limits;
some SpartaDOS features, such as hierarchical paths, are not present there.

On Atari DOS 2/2.5 and MyDOS disks, `NOTE` and `POINT` (CIO's XIO 38 and
37, as BASIC uses them) give and take the sector and the byte in it, as those
DOSes do, so BASIC programs that keep or compute such positions work as they
do there. The kernel's `FSEEK` and `FTELL` keep byte positions from the
file's start on every disk.

EOS looks at a disk again (for another disk in the drive) when a drive is
used after more than a second without use; within a second of the last
access the disk cannot have been changed, and EOS keeps what it has read.
A program that writes a disk's sectors itself through SIO, past EOS, should
close its files on that drive first, as with any DOS that caches.

Use these commands before changing media:

```text
CHKDSK D1:     ; filesystem, sector size, free and total space
DF D1:         ; free-space summary
MAP            ; device/drive map
```

### Formatting

`FORMAT` destroys data on the selected disk. Before formatting, confirm the
drive and copy any files you need elsewhere. Run `FORMAT` without parameters
for the interactive menu. It can choose unit, volume name, density, geometry,
SIO speed, and filesystem mode. The menu's modes include Sparta (SDFS), Atari
(DOS 2), and EOS (EOSFS) where supported by the selected geometry/device.

Examples:

```text
FORMAT                 ; interactive menu
FORMAT /Q D2: WORK     ; quick SDFS initialization after confirmation
FORMAT /QQ D2: WORK    ; quick SDFS initialization without confirmation
```

Quick format rebuilds an empty SpartaDOS filesystem; it is not a secure erase.
Use the interactive menu to choose DOS 2 or EOSFS. `FORMAT` also has a
directory-only operation for suitable RAM disks and hard disks. Read
`MAN FORMAT` before formatting unfamiliar media. A disk using 512-byte sectors
cannot be booted by the stock Atari OS.

### EOSFS

EOSFS is an optional EOS-native format selected during formatting. Its
directory entries and general layout remain SDFS-compatible, while files use
extent lists to keep contiguous data runs together and reduce map-sector
overhead. EOS reads and writes both EOSFS and SDFS; use SDFS when the disk must
also be writable by SDX. SDX does not recognize EOSFS revision `$45`, so do
not expect SDX to access an EOSFS volume. See [EOSFS design](EOSFS.md) for the
on-disk specification and version 1 limits.

### Bootable disks

FORMAT writes the SDFS or EOSFS loader. `BOOT file` records
the file's first map or extent list in sector 1; it does not copy the file or
replace the loader. Erasing or replacing the file clears the boot mark.

SDFS and EOSFS images with 128 or 256 byte sectors are bootable. The stock OS
cannot boot 512 byte sectors. See Building EOS for the host image command.

## 7. Devices, drivers, and memory

`DEV` lists installed kernel devices; `MEM` reports memory use and selected
memory mode. Core DSK, SIO, and DOS 2 support is built into EOS. Additional
drivers and utilities are supplied in the cartridge or can be loaded from
disk with `DEVICE` in `EOSSYS.SYS` / `CONFIG.SYS`.

### Driver installation and parameters

`DEVICE name [parameters]` loads a `name.SYS` file from the normal program
search locations, or activates an EOS built-in driver. The following list
covers the EOS-supplied drivers and their parameters. Drivers not listed here
may have their own documentation. Core disk drivers `SPARTA`, `SIO`,
`ATARIDOS`, and `INDUS` are already in the cartridge; their `DEVICE` lines are
accepted for SDX configuration compatibility and do not load another driver.

| Driver | Syntax | Behavior and options |
| --- | --- | --- |
| `RAMDISK` | `RAMDISK [drive[,nbanks]] [/S]` | Installs one RAM disk, defaulting to O: and all available extended-memory banks except four reserved for programs. `nbanks` selects the number of banks. The disk has 256-byte sectors and is initialized as SDFS unless a same-size disk is already present. A RAM disk requires extended memory. EOS accepts `/S`; it has no additional effect in the current implementation. It sets default `RAMDISK`, `BASIC`, `CAR`, and `TEMP` variables if they were unset. |
| `ENV` | `DEVICE ENV` | Moves the environment into an extended-memory bank, providing up to 16 KiB instead of the small default area. Without extended memory, the environment stays in its original location. |
| `DOSKEY` | `DOSKEY [aliases-file] [/X]` | Installs command-line editing, a 16-line history, aliases, `&` command chaining, and TAB filename completion. Up/Down, Ctrl-P/Ctrl-N, or F1/F2 select history; Left/Right edit at the cursor; Shift-Clear clears the screen; BREAK cancels the line. Alias files contain `NAME=COMMAND` lines. `/X` runs `DIR` on an empty command line. |
| `RUNEXT` | `RUNEXT [association-file]` | Loads file-extension associations; defaults to `CAR:RUNEXT.CFG`. `RUNEXT` at the prompt lists the active rules. A rule has `[!^]EXT[:EXT...],PROGRAM[,PARMS]`; `!` requires Shift, `^` requires Ctrl, and `%` in parameters is replaced by the selected filename (otherwise the filename is appended). Rules are checked in file order. Lines beginning with `;` or `*` are comments. Prefix a command with `+` to skip associations. |
| `COMEXE` | `DEVICE COMEXE` | Makes `NAME.EXE` (or `NAME` when `NAME.COM` is absent) run through `X`, with cartridges disabled. Prefix the command with `+` to bypass this behavior. |
| `RTIME8` | `DEVICE RTIME8` | Enables the hardware clock: the R-Time 8 cartridge if it answers, otherwise the Ultimate 1MB's clock (DS1305) when a U1MB is detected. With neither, EOS prints `R-Time 8 not present` and runs its software clock. `DATE` and `TIME` set the U1MB clock as well (24-hour mode). This is also EOS's default without a configuration file. |
| `JIFFY` | `DEVICE JIFFY` | Enables the software clock, which advances from the last set time using the Atari frame clock. |
| `Z` | `DEVICE Z [/I|/S]` | Installs the `Z:` clock device. `/I` ignores unsupported XIO status requests; `/S` allows setting the clock. XIO 33 reads time, 35 reads date, 36 sets time, and 37 sets date. Each uses three byte operations. Other date/time formatting XIOs require `TD.COM`. |
| `XEP80` | `DEVICE XEP80.SYS [/P] [/U] [/V] [/1]` | Installs an 80-column XEP80 screen handler. `/P` selects 50 Hz, `/U` enables supported 31.5 kHz Ultra speed, `/V` selects VHOLD timing, and `/1` selects joystick port 1 (default port 2). The handler is based on Altirra's XEP80 driver and retains its own notices. |
| `CON64` | `DEVICE CON64` | Installs the software 64-column display; it needs extended memory. Use `CON 64` to select it and `CON 40` to return. Load it before `RAMDISK`. |
| `CON` | `DEVICE CON` | Loads the optional 80-column console handler when `CON.SYS` is available. `CON 80` selects it; the `CON` command page lists the widths. |
| `QUICKED` | `DEVICE QUICKED` | Compatibility placeholder for SDX's screen accelerator; EOS leaves the console handlers unchanged. |

`SIOSET` configures transfer speed and protocol for individual drives; `MAP`
maps physical units and changes their SIO selection. Their complete switches
are in the command reference below. Clock features depend on the installed
hardware or a manually set time. FATFS/CPMFS and other D3 filesystem-driver
interfaces are outside EOS's supported configuration.

Memory modes:

- `USE NONE`: do not reserve OS RAM for EOS use.
- `USE OSRAM`: use suitable RAM beneath the operating system ROM.
- `USE BANKED`: use supported banked extended memory.
- With more than 128K (more than four extended banks), EOS also keeps one
  16 KB bank as a second disk cache: sectors its cache has to drop are kept
  there, and reading them again costs a memory copy instead of a disk read.
  MEM shows that bank as not free.

Choose modes only when the machine and installed expansions support them.
`MEM` shows the active mode and available memory. Driver names and parameters
are specific to each driver; use the relevant man page and the configuration
examples shipped in the cartridge files.

## 8. Help and command groups

Use `MAN` for the machine-readable reference:

```text
MAN             ; list available pages
MAN COPY        ; show COPY help
MAN COPY | LESS ; page through help
```

Other useful commands include:

- System: `VER`, `MEM`, `DEV`, `MAP`, `CHKDSK`, `DF`.
- Navigation: `CD`/`CHDIR`, `PWD`, `SETPATHS`.
- Files: `DIR`, `DIRS`, `TYPE`, `COPY`, `RENAME`, `DEL`, `DELTREE`,
  `MKDIR`, `RMDIR`, `UNERASE`.
- Disk operations: `FORMAT`, `BOOT`, `CHVOL`, `SIOSET`.
- Screen and inspection: `CLS`, `ECHO`, `LESS`, `MORE`, `FIND`, `DUMP`,
  `PEEK`, `POKE`, `MDUMP`.
- Date and time: `DATE`, `TIME`, `TD`, `CHTD`.

The EOS Toolkit is a separate collection of disk utilities distributed on
`EOSTK.atr`, with programs and manual pages under `MAN>`. It includes `LS`,
`DU`, `CAT`, `HEAD`, `TAIL`, `CRC32`, `MD5`, `WHICH`, and `SEQ`. Toolkit
commands are separate `.COM` programs. After mounting the Toolkit disk as D1,
for example, add its root to `$PATH` and its manual directory to `$MANPATH`:

```text
PATH CAR:;D1:
SET MANPATH=CAR:;D1:>MAN
LS
MAN LS
```

## 9. Compatibility notes

EOS is intended as a drop-in for SDX 4.5: it runs many SDX relocatable
programs and drivers, uses SDX-compatible kernel entry points, and supports
SDFS disks. It also supports BW-DOS program execution and BW-DOS disks, plus
Atari DOS 2/2.5 disks. Compatibility does not mean every program's hardware
assumptions or every third-party driver works on every Atari configuration.

System filenames are `EOSSYS.SYS` and `EOSAUTO.BAT`; EOS falls back to
`CONFIG.SYS` and `AUTOEXEC.BAT`. This allows EOS-specific setup alongside
existing SDX files. See [EOS compatibility](EOS_COMPATABILITY.md) for the
project's compatibility summary.

## 10. Troubleshooting

**EOS starts but a disk or command is missing**

- Check the connection, mounted image, and drive number with `MAP` and
  `CHKDSK D1:`.
- List the directory with `DIR D1:` and check the current directory with
  `PWD`.
- Check `PATH` using `PATH` or `SET PATH`; cartridge commands are found on
  `CAR:` by default.

**A command is not found**

- Check spelling and the current directory.
- Use a full drive/path or add the directory to `PATH`.
- Use `MAN command` to check whether it is built into the cartridge or part
  of the separate Toolkit.

**A program reports insufficient memory or fails to load**

- Run `MEM` to inspect the current memory mode and free memory.
- Remove held programs with `LOAD` (with no filename), where appropriate.
- Confirm that the program format and required hardware/memory are supported.

**A disk has errors or unexpected free space**

- Run `CHKDSK` and avoid writing further if data appears damaged.
- Back up readable files before using repair or formatting operations.
- Formatting erases the selected volume; verify the drive before confirming.

**Date or time is incorrect**

- Check `DATE /T` and `TIME /T`.
- Correct it with `DATE` and `TIME`; accurate startup time depends on a clock
  driver or setting it manually.

## 11. Programming for EOS

EOS is designed to run Atari binaries and SpartaDOS X programs. There are
three common ways to program for it:

1. Atari BASIC or exBASIC for interpreted or compiled BASIC applications.
2. Atari binary files for programs that need no DOS library.
3. SDX relocatable binaries for programs that use EOS/SDX library symbols.

### 11.1 Choose a target format

Use a plain Atari binary when the program is self-contained and can use the
Atari OS directly. The standard binary record begins with `$FFFF`, followed
by inclusive start and end addresses and that memory range's bytes. Additional
segments repeat start, end, and data. A run vector may specify where execution
starts. These files are commonly named `.COM` but the extension does not
determine the format.

Use an SDX relocatable binary when the program should run at an available
address, import EOS/SDX library routines, or use the DOS file and command
services. EOS implements the SDX relocatable loader and symbol interface.
MADS source commonly declares imports with `smb 'NAME'`, starts a relocatable
main block with `blk reloc main`, and writes address/symbol fixups with
`blk update address` and `blk update symbols`. See `tests/eos/*.asm` and
`toolkit/*.asm` for working EOS examples and the assembler syntax used by this
project.

EOS supports BW-DOS binaries as a compatibility target. While such a program
runs, EOS presents the BW-DOS COMTAB environment and dispatches supported
calls. This is primarily useful for existing BW-DOS software; new DOS-aware
programs should generally use SDX relocatable format.

### 11.2 A minimal relocatable assembly program

This example prints a message through the EOS/SDX `PUTC` library routine and
returns to the command processor. It follows the same style as
`tests/eos/HELLO.asm`:

```asm
PUTC     smb 'PUTC'

        blk reloc main
start   ldx #0
next    lda message,x
        beq done
        jsr PUTC
        inx
        bne next
done    rts
message dta c'Hello from EOS',$9B,0

        blk update address
        blk update symbols
```

Assemble the source in relocatable mode using your MADS setup, then place the
resulting binary on a disk or in a Toolkit directory. At the EOS prompt, run
it by name. The `smb` import requests the system symbol by name; the loader
resolves it when loading. `RTS` returns through the DOS loader. Use the
assembler's standard binary mode instead when producing an absolute Atari
binary.

### 11.3 Calling convention and system symbols

The EOS library keeps selected SDX-compatible calling conventions for the
symbols it exports. Library entry points are callable symbols resolved by the loader;
many receive parameters in A/X/Y or through shared work areas, and report
status through processor flags and/or shared variables. EOS's implementation
and tests are the source of truth for EOS behavior. Do not infer an undocumented
call convention from a routine's name.

The exported symbol names are in `eos/symbols.txt`. Important groups include:

- Command parsing and text: `U_GETPAR`, `U_GETNUM`, `U_GETADR`, `U_GEFINA`,
  `U_FAIL`, `PRINTF`, `FPRINTF`, `PUTC`, `GETS`, `PUTS`.
- File streams: `FOPEN`, `FCLOSE`, `FREAD`, `FWRITE`, `FGETC`, `FPUTC`,
  `FGETS`, `FPUTS`, `FSEEK`, `FTELL`, `FILELENG`, `REMOVE`, `RENAME`.
- Directories and metadata: `FFIRST`, `FNEXT`, `GETCWD`, `GETDFREE`,
  `MKDIR`, `RMDIR`, `RENDIR`, `CHDIR`, `CHMOD`, `CHVOL`.
- Environment and memory: `GETENV`, `PUTENV`, `NUMENV`, `MALLOC`, `XRWMEM`.
- Loader and symbols: `U_LOAD`, `U_UNLOAD`, `INSTALL`, `S_LOOKUP`, `S_ADD`,
  `S_NEXT`, `S_ADDIZ`.

`COMTAB` exposes the command processor's shared parameter buffer and work
area. Its layout is part of the EOS program interface; avoid hard-coded
offsets unless this manual or a known EOS example defines them.
`U_GETPAR` parses successive command parameters into the COMTAB parameter
area. It skips leading spaces, treats spaces and commas as separators,
uppercases the returned parameter, and leaves the original command line
unchanged. Commas can represent an empty field (`A,,B`). The sample below
reads parameters until there are no more:

```asm
U_GETPAR smb 'U_GETPAR'
COMTAB   smb 'COMTAB'
PUTC     smb 'PUTC'

        blk reloc main
nextpar jsr U_GETPAR
        beq done
        ldx #$21              ; COMTAB parameter string in this example
nextch  lda COMTAB,x
        jsr PUTC
        inx
        cmp #$9B
        bne nextch
        lda #$9B
        jsr PUTC
        jmp nextpar
done    rts
        blk update address
        blk update symbols
```

The `$21` offset is shown to explain the existing sample, not as a substitute
for the COMTAB definition. See `tests/eos/HELLO.asm` and EOS Toolkit sources
for parameter parsing patterns.

### 11.4 Formatted output with PRINTF

`PRINTF` is commonly called with its format string and arguments stored
inline after the call. It consumes that data and returns to the instruction
after the last argument. The string ends with a zero byte. A few useful
format types are `%c` (one byte character), `%s` (string pointer), `%x`
(hexadecimal value), and `%b`, `%d`, `%e`, `%l` (unsigned 1-, 2-, 3-, and
4-byte decimal values). A width can precede the type; `%05d` pads a value to
five digits with zeroes. `%%` prints a percent sign. `FPRINTF` uses the same
format rules but writes to the currently open file.

```asm
PRINTF smb 'PRINTF'

        blk reloc main
start   jsr PRINTF
        dta c'File length: %d bytes',$9B,0
        dta a(length)
        rts
length  dta a(1234)
        blk update address
        blk update symbols
```

### 11.5 File I/O and redirection

For DOS-independent applications, use the Atari OS CIO interface that EOS
supports. EOS also provides the SDX-compatible file-stream library
(`FOPEN`, `FREAD`, `FWRITE`, `FCLOSE`,
and related symbols) for relocatable programs. This lets a program use the
same file calls on DSK:, CAR:, and supported devices without implementing
filesystem structures itself. Programs should check each open/read/write
result, close successful opens on every exit path, and use `FCLOSEAL` when
appropriate for cleanup.

The command processor can connect standard input and output to devices, files,
and pipes. A program intended for pipelines should use `GETC`/`GETS` for
standard input and `PUTC`/`PUTS` for standard output, rather than assuming the
screen or keyboard. The Toolkit examples `CAT`, `HEAD`, `TAIL`, `WC`, and `FT`
are useful EOS models for stream filters.

For programs using EOS's relocatable file-stream API, `FILE_P` points to an EOL- or
zero-terminated file specification. The standard parameter area includes
`file_id` at `$0760`, `mode` at `$0778`, `scan` at `$0779`, and `attr` at
`$077A`. The `tests/eos/FSW.asm` test demonstrates `FOPEN` modes 4 (read), 8
(create/write), 9 (append), and 12 (read/write update). It sets `scan` and
`attr` to zero for ordinary file opens.

`FREAD` and `FWRITE` use the shared transfer fields `addpos` (buffer address,
three bytes), `bytbuf` (requested byte count, two bytes), and `memreix`
(memory index). Memory index 0 is main RAM; extended-memory indexes are
platform-specific. On `FREAD`, X is 0 with N clear on success; at end of file
X is `$FF` and N is set. `FWRITE` returns X=0 on success; an error follows the
standard `U_FAIL` path. `FSEEK`, `FTELL`, and `FILELENG` use the three-byte
`addpos` field. These are EOS call contracts: `FREAD` and `FWRITE` return
X=0 with N clear after success, and `FREAD` returns X=`$FF` with N set at end
of file. Other file-service errors go through `U_FAIL`; the exported routine
contracts below define the remaining transfer and stream rules.

### 11.6 Running and debugging programs

- `FSTRUCT file` (Toolkit) inspects Atari segments, run/init addresses,
  relocatable blocks, fixups, and symbol records.
- `SL [prefix]` lists loaded/system symbols; `SL NAME address` adds a
  temporary symbol for debugging.
- `PEEK`, `POKE`, `MDUMP`, and `DPOKE` inspect or modify memory. Writes can
  crash EOS or corrupt files; use only with known addresses and values.
- `X file` runs with cartridges switched off for programs that need the RAM
  under the cartridge; library calls and normal redirection are unavailable
  in that mode.
- `MEM` shows available memory and memory mode. `LOAD` can keep a program
  resident; `INSTALL` keeps one resident until reset.
- `COMP`, `CRC32`, and `MD5` help verify program files and test results.

For BASIC applications, `BASIC` enters the built-in XL/XE BASIC. `BASIC file`
enables BASIC and loads/runs a binary with BASIC available. Compiled exBASIC
programs can use Atari BASIC conventions plus tested EOS CIO behavior; see
`tests/exbasic/` for examples covering file I/O, directories, XIO, RUN/COMMON,
and graphics.

### 11.7 Compatibility and portability

Use the EOS documented symbols and compatible interfaces when a program
should run on both EOS and SDX. Avoid relying on EOS-private symbols prefixed
with `_` or undocumented kernel internals. Avoid writing directly to SDFS or EOSFS
structures; use file and directory APIs. Do not assume every driver, banked
memory type, or hardware device is present. For source examples, use the
smallest interface needed and check return status before using returned data.

### 11.8 Exported symbol contracts

The following entries define every name in `eos/symbols.txt`. Callable entries
are subroutines unless marked as data. EOL means `$9B`; EOS file-service errors
usually enter `U_FAIL`. Hardware or filesystem drivers can provide additional
device-specific error codes.

#### Data and kernel exports

| Symbol | Contract |
| --- | --- |
| `COMTAB` | Base of command parameter/work memory. Shared with EOS; use only documented fields. |
| `FILE_P` | Pointer to current file specification, EOL- or zero-terminated. |
| `FLAG` | One-byte loader mode: bit 7 means load only; bit 6 means use only an explicit RUN vector (do not fall back to the first segment if none exists). `$C0` therefore runs INIT but does not run the program. Set before `U_LOAD`. `U_GETFLG` is a separate helper that uses this byte as its default/result. |
| `CURDEV`, `SYSLEVEL` | Read-only current-device and command-nesting state. |
| `INSTALL` | One-byte loader flag; set bit 7 for the current program to keep its memory resident when it returns. |
| `EXTENDED`, `SYMBOL`, `T_` | System-managed memory, symbol, and translation data. No application mutation contract; use `MALLOC`/`XRWMEM` and symbol routines. |
| `DEVNAME`, `DEVSPEC` | Read-only device name/specification tables used by EOS path translation. |
| `PUT_V` | Standard output vector used by the library. Replacement must implement the EOS output-vector convention. |
| `COMTAB2` | Secondary command processor work area; private layout is not an application API. |
| `ENV_P` | Three-byte active environment-store pointer. Use `GETENV`/`NUMENV`/`PUTENV`, not direct edits. |
| `STATUS` | Child exit status written for the parent by `U_LOAD`. |
| `ERRNO` | Last error number stored by `U_FAIL` for errors below 128. Check the routine's own status as well. |
| `_CURBANK` | EOS-private current cartridge-bank state; diagnostic/internal use only. |
| `_SETBANK` | EOS-private bank selector: A selects bank; A=`$80` disables cartridge. Switching can invalidate code/data pointers. |
| `_HSDRV` | EOS-private hard-disk driver vector; no application ABI is promised. |
| `_EOSDRV` | EOS-private driver dispatcher: A=0 COMEXE, 1 RUNEXT, 2 DOSKEY, 3 RAMDISK, 4 RTIME8, 5 JIFFY, 6 ENV. Internal driver ABI. |

#### Parameter, text, error, and numeric routines

| Symbol | Inputs and result |
| --- | --- |
| `U_GETPAR` | Reads next LBUF argument at `BUFOFF`; skips leading spaces, consumes the following separator, uppercases into `COMFNAM`, sets `FILLEN`, returns length A/X; Z=1 if none. Commas can yield an empty argument. |
| `U_GEFINA` | `FILE_P` file spec in; parses device to `device`, directory to `path`, and filename to the internal padded 8+3 `name`; accepts EOL/zero termination. Invalid device/spec uses `U_FAIL`. |
| `U_GETNUM` | Parses next decimal or `$` hexadecimal parameter. Success: A/X low 16 bits and 32-bit value in `COMTAB-6..-3`; consumes parameter. Z=1 if absent/invalid and leaves `BUFOFF`. |
| `U_GETADR` | Parses `[index:]number|symbol[+n|-n]`. Success C=0: address A/X, memory index Y. C=1: 24-bit value low word A/X, high byte Y. Z=1 if absent/invalid. |
| `U_GETFLG` | A default in; parses numeric or S/A/I/N and returns A=FLAG (values 0/`$40`/`$C0`/`$80`). Invalid input raises error 4; absent input retains default. |
| `U_GONOFF` | Parses ON/OFF; C=1 ON, C=0 OFF. Other/missing input raises error 156. |
| `U_PARAM` | Copies next typed parameter to `COMTAB+$BF`, EOL-terminated; empty if none; advances over spaces/commas; Z=0. |
| `U_TOKEN` | A/X keyword table (high bit marks each keyword's final character, `$00` ends table). Match returns C=1, A=zero-based token index; miss returns C=0, A=keyword count. |
| `U_SLASH` | A/X flag-character pair table, Y byte length; initializes flags and parses current slash options; unknown option raises error 156. |
| `TOUPPER` | A character in; uppercase equivalent in A, other bytes unchanged. |
| `U_FSPEC` | Uses `COMFNAM`/`FILLEN`; appends `*.*` when a parameter ends in a path separator and updates length. |
| `U_PATH` | A/X output buffer, Y initial offset; appends device/path (device omitted for `$FF`), EOL-terminates, returns Y at EOL. |
| `U_GEPATH` | `FILE_P` spec in; sets parsed device and `path` to the full supplied path (filename included), zero-terminated. |
| `U_EXPAND` | A/X destination, Y initial offset; expands internal 8+3 `name` to printable filename, collapses trailing `?` groups to `*`, returns Y at EOL. |
| `U_GETATR` | A default scan mask; parses attribute selectors and next filename; returns `scan`, Z=1 if no name. |
| `PRO_NAME` | `(bufadr)` and Y+1 input offset; builds 8+3 `name`, maps `*` to `?`, stops at EOL/space/comma/path separator; terminator in A and offset Y, Z=1 for blank. |
| `_CRUNCH` | EOS-private drive parser; reads next parameter into `COMFNAM` as `Dd:rest`, resolves drive aliases/current drive, sets `FILLEN`; Z=1 if only device/current drive. |
| `CKSPEC` | A character in; Z=1 for path separator `:`, `>`, `\\`, `<`, else Z=0. |
| `U_GETKEY` | Waits for key; A=key, X bit 7 Control and bit 6 Shift. Break gives A=128/N=1; ordinary key N=0/Z=0. |
| `U_PERROR` | A/X destination, Y error code; writes EOL-terminated error text. |
| `ERR_GMSG` | A error code; X/Y points to zero-terminated error number/message. |
| `ERR_DMSG` | A error code; writes decimal code and message without adding EOL. |
| `U_ERROR` | A error code; prints EOL, error number/message, EOL. |
| `U_FAIL` | A error code; unwinds to latest `U_SFAIL` trap if set, else records errors >=2 in `ERRNO`, returns codes below 128 to parent, and displays/returns DOS errors >=128. May not return normally. |
| `U_SFAIL` | A/X handler address; pushes error trap (maximum ten), saving execution state for unwind. |
| `U_XFAIL` | Pops most recent error trap; preserves A/X/Y and flags. |
| `VALIDATE` | Date/time bytes at `$077B`: day, month, year, hour, minute, second. A bit 0 validates date, bit 1 time; C=1 invalid. |
| `XCOMLI` | Executes command line in LBUF as if at prompt. Success A=Y=1; error A=code/N=1; errors >=128 are displayed. |

#### Files, directories, and streams

| Symbol | Inputs and result |
| --- | --- |
| `FOPEN` | `FILE_P`; mode `$0778`, scan `$0779`, attr `$077A`; opens `file_id`. Low-nibble modes: `$04` read, `$08` create/write, `$09` append, `$0C` read/write update. Add `$10` for direct directory access: `$14` read entries, `$1C` read/write directory entries. `scan` low bits 0-3 require P/H/A/D attributes; corresponding high bits 4-7 exclude them. For create, `attr` sets P/H/A and bit `$40` requests a symbolic link. Failure uses `U_FAIL`. |
| `FCLOSE` | Closes current `file_id`; failure uses `U_FAIL`. |
| `FCLOSEAL` | Closes files owned at current `SYSLEVEL` or deeper; returns X=0. |
| `FCLEVEL` | A is the ownership level to assign to current `file_id`; `$FF` exempts it from `FCLOSEAL`. |
| `FREAD` | `addpos` 3-byte buffer address, `bytbuf` 2-byte count, `memreix` memory index. X=0/N clear success; X=`$FF`/N set EOF; other errors use `U_FAIL`. |
| `FWRITE` | Same transfer fields as `FREAD`; X=0 on success, otherwise `U_FAIL`. |
| `FGETC` | Reads one byte from `file_id`; A=byte, EOF A=EOL/X=`$FF`/N=1; preserves Y. |
| `FPUTC` | Writes A to `file_id`; preserves A/X/Y on success; errors use `U_FAIL`. |
| `FGETS` | A/X destination, Y capacity; reads through EOL. Success A=0/N clear, Y bytes including EOL; EOF A=0/N set. Overlong line returns capacity-1 bytes plus EOL, discards remainder, A=`$FF`/Y=capacity. |
| `FPUTS` | A/X EOL string, Y maximum length; writes through EOL or until Y bytes. |
| `FSEEK` | Requested position in `addpos`; seeks current `file_id`; failure uses `U_FAIL`. |
| `FTELL` | Current position returned in three-byte `addpos`; failure uses `U_FAIL`. |
| `FILELENG` | Current file length returned in three-byte `addpos`; failure uses `U_FAIL`. |
| `REMOVE` | `FILE_P` file spec; removes file; failure uses `U_FAIL`. |
| `RENAME` | `FILE_P` contains old and new names separated by space/comma; renames file; failure uses `U_FAIL`. |
| `RENDIR` | Same as `RENAME`, for a directory. |
| `MKDIR`, `RMDIR` | `FILE_P` directory spec; create/remove directory; failure uses `U_FAIL`. |
| `CHMOD` | `FILE_P` spec and `scan` attribute mask; changes attributes; failure uses `U_FAIL`. |
| `CHDIR` | `FILE_P` directory spec; changes current directory; failure uses `U_FAIL`. |
| `CHVOL` | Volume name in the name portion of `FILE_P`; changes volume label; failure uses `U_FAIL`. |
| `SETBOOT` | `FILE_P` identifies disk boot file; failure uses `U_FAIL`. |
| `FFIRST` | `FILE_P` search spec and `scan`; first result to `dentry`, open search in `file_id`; failure uses `U_FAIL`. |
| `FNEXT` | Advances open search; next entry to `dentry`; N=1 at end; other errors use `U_FAIL`. |
| `GETCWD` | Writes current path from root to `path`, zero-terminated; failure uses `U_FAIL`. |
| `GETDFREE` | Writes selected drive's information to `path`; failure uses `U_FAIL`. Record layout depends on file manager and is not a fixed cross-device structure. |
| `DIVIO` | `FILE_P` target; Y=0 redirects output anew, Y=2 appends output, Y=1 redirects input. Changes standard stream routing; failure uses `U_FAIL`. |
| `XDIVIO` | Y=0 closes/restores output; Y=1 closes/restores input. |
| `GETC` | Reads standard input. Redirected-file EOF restores the console stream and returns A=EOL/X=`$FF`/N=1. |
| `GETS` | A/X buffer, Y capacity; standard-input line read with `FGETS` length/EOF results. |
| `PUTC` | A byte to standard output through `PUT_V`; preserves A/X/Y and page-7 parameters. |
| `PUTS` | A/X EOL string, Y length; writes standard output and preserves Y. |
| `FORMAT` | No arguments: starts EOS formatter menu as a child program. |
| `BUILDDIR` | A/X label (up to 8 characters); soft-formats drive in DUNIT as a child program. |

#### Memory, loader, environment, and formatted output

| Symbol | Inputs and result |
| --- | --- |
| `MALLOC` | `bytbuf` size; X=0 main RAM, 2 system extended, 4 program extended; add `$40` for page alignment. Success N=0, address in `addpos`, granted class in X. Failure N=1/X=0/A=158. Nonresident allocations are released at program exit. |
| `XRWMEM` | `addpos`+Y address, X memory index (0 main, 2 under OS ROM, >=4 bank). C=0 read byte to A; C=1 write A. C=1 for absent memory; preserves X/Y and A on write. |
| `U_LOAD` | `FILE_P` program and `FLAG` mode; loads/resolves and runs as a child. FLAG `$80` loads only, `$40` requires an explicit RUN vector, `$C0` runs INIT only. Child status is in `STATUS`; load/execute errors use DOS error handling. |
| `U_UNLOAD` | Releases current program's loader-managed allocations/symbols during termination; not an arbitrary-address free routine. |
| `S_LOOKUP` | Eight-byte padded name at `SYMBOL+2`; on hit Z=0, address at `SYMBOL+$0B`..`+$0C`, memory index at `SYMBOL+$0D` (0 for resident/main memory); miss Z=1. |
| `S_ADD` | Eight-byte name at `SYMBOL+2`, address at `SYMBOL+$0B`..`+$0C`, memory index at `SYMBOL+$0D`; adds a RAM symbol record at MEMLO. C=1 if there is insufficient memory. |
| `S_NEXT` | Starts at first symbol when `SYMBOL+2` is zero; otherwise advances. Copies each name/address/index to `SYMBOL+2`/`+$0B`/`+$0D`, enumerating RAM symbols then system table; Z=1 at end. |
| `S_CLEAR` | Clears RAM symbols for levels above the caller's current loader level; used during unload. |
| `S_ADDIZ` | A/X routine address to queue after RESET; C=1 if five-entry queue is full. |
| `GETENV` | A/X EOL name; match A=0/N clear and value in LBUFF; missing A=`$FF`/N set. |
| `NUMENV` | A zero-based record index; A=0/N clear and `NAME=VALUE` in LBUFF; missing A=`$FF`/N set. |
| `PUTENV` | A/X EOL `NAME=VALUE` inserts/replaces; `NAME` deletes. Returns first character/N clear; no capacity A=`$FF`/N set. |
| `MUL_32` | Operands at `COMTAB+$FF` and `+$103`, MSB first; low 32-bit product at `+$107`, C=0. Operand work fields are shifted/modified. |
| `DIV_32` | Same operand/result fields; quotient at `+$107`; C=1 on divide by zero. Work fields modified. |
| `PRINTF` | Inline zero-terminated format/arguments after JSR; consumes inline data and resumes after it; writes standard output. See §11.4 for format codes/argument widths. |
| `FPRINTF` | Same inline format/argument ABI as `PRINTF`, writes current `file_id`. |
| `VPRINTF` | Same formatting ABI; outputs through `PUT_V` using handle 100 and restores `file_id`. |
| `FDOPEN` | EOS lib2 directory-listing helper; uses `FILE_P`, `mode`, and `scan` to open a directory search and prepare formatted listing text. Mode 0 selects `$0B`; mode `$80` selects `$A8`. The active search state is private lib2 data. |
| `FDGETC` | Returns the next character of the formatted listing in A/N clear; end returns A=136 (`E_EOF`), X=`$FF`, N=1. Uses private lib2 search state. |
| `FDCLOSE` | Closes the directory search opened by `FDOPEN`; uses private lib2 search state. |

#### Contract gaps called out directly

The symbol list contains internal exports as well as application routines.
`COMTAB` is shared system state, but this manual documents only the fields
used by the programming chapter and EOS examples; it does not yet provide a
complete byte-by-byte map of the entire command table. `COMTAB2` likewise has
some EOS-defined fields, but its full layout is not a supported application
contract.
`_HSDRV`, `_EOSDRV`, `_CURBANK`, `_SETBANK`, `EXTENDED`, `SYMBOL`, `T_`,
`COMTAB2`, and loader cursor helpers are implementation interfaces; EOS does
not promise their layout/behavior as a stable application ABI. `FDOPEN`,
`FDGETC`, and `FDCLOSE` use private lib2 directory-listing work fields, so the
search state is not documented as a public ABI; use the primary file-stream
calls for application file I/O. `GETDFREE`'s returned record is interpreted by the
active file manager, so a single fixed cross-device structure cannot be
promised. These are known EOS gaps, not omissions to be filled by consulting
another project's documentation. Promoting any of them requires EOS to define
and test a stable contract first.

## 12. Complete command reference

The reference below reproduces the command help shipped with EOS and the EOS
Toolkit, including syntax, options, aliases, and examples. Built-in/cartridge
commands are available through `MAN`; Toolkit entries require their `.COM`
programs to be installed on a disk in `$PATH`.

### 12.1 EOS built-in and cartridge commands

The reference pages below include all 65 source help pages. A few command
processor built-ins have no separate page; their complete syntax is listed
here:

| Command | Syntax and behavior |
| --- | --- |
| `ERROR` | `ERROR ON` or `ERROR OFF`; controls whether a command error is reported again as the command processor unwinds a batch. |
| `FI` | No parameters; closes the active conditional batch block and resumes processing after it. |
| `REPORT` | `REPORT [code]`; reports the supplied error code, or the current `ERRNO` if omitted. Codes 1–127 are printed as exit codes; 128 and above use the system error message. |
| `RUNEXT` | No parameters; displays the file associations read by `RUNEXT.SYS`. |
| `SETERRNO` | `SETERRNO code`; sets the current error number for a batch or program to inspect/report. |

Command aliases are documented with their primary command page (for example,
`DEL`, `DELETE`, and `ERASE`; `CD`, `CHDIR`, and `CWD`). Configuration
directives such as `USE`, `DEVICE`, `MERGE`, and `ECHO` are covered in
[Startup files and configuration](#4-startup-files-and-configuration).


#### EOS built-in and cartridge commands: alphabetical reference

Commands in this section are listed alphabetically. Use the on-machine `MAN` command for the version installed on your cartridge or Toolkit disk.

##### APPEND

```text
APPEND - extend the search path

Syntax:
 APPEND d: | path | device

Adds one drive, directory or device to the end of the $PATH variable. Handy for a temporary change: the entries already in $PATH stay as they are, nothing has to be typed again.

Example:
 PATH
 CAR:
 APPEND D2:
 PATH
 CAR:;D2:

See also: PATH, SET
```

##### APT

```text
APT - Atari Partition Table (FDISK)

Syntax:
 APT [/n]
 APT [/n] INIT [/F]
 APT [/n] NEW size[K|M]
 APT [/n] DEL p
 APT [/n] MAP d p
 APT [/n] UNMAP d
 APT [/n] BOOT d
 APT [/n] AUTO p ON|OFF
 APT [/n] WP p ON|OFF

APT partitions a hard disk attached through a PBI BIOS that provides the physical disk device ($20), such as the IDE2.0PLUS BIOS 2.1, and edits its APT partition table. /1 is the master disk (the default), /2 the slave.

Without a command APT lists the table: where it is, its revision, the boot drive, the drives mapped to partitions, and each partition's type, start, size (512-byte disk sectors), sector size and flags (A automount, W write protected). Reserved entries are listed but never changed.

 INIT    a new, empty table at sector 0. A disk whose sector 0 is in use (an APT table, a PC partition table, any data) needs /F
 NEW     a partition after the last one: size in 512-byte sectors, or K or M (16 to 65535 sectors; 32M gives the largest, 65535); automount on
 DEL     remove partition p; the ones after it move up one number. A mapped partition must be unmapped first
 MAP     map drive d (1-15, A-O or Dn:) to partition p
 UNMAP   remove drive d's mapping
 BOOT    set the boot drive (0: none)
 AUTO    set or clear automount for partition p
 WP      set or clear write protection

Each change is shown first and written only after Y (and Return) at the question; anything else leaves the disk unchanged. The table sector is written and read back. Restart the computer: the BIOS reads the table when it starts.

A new disk: APT INIT, APT NEW for each partition, APT MAP for each drive, restart, then FORMAT each drive (FORMAT /QQ D2: NAME).

APT reads the table at sector 0, or where a PC MBR partition of type $7F points. It changes only the first table sector of a revision 0 table and keeps every other byte; NEW refuses when the place of the new entry holds other data. Partitions use 512-byte sectors. Partitions are not resized.

Verified in Altirra with the IDE2.0PLUS BIOS 2.1. Other hard disk BIOSes are not verified.

Example:
 APT NEW 16M
 APT MAP D2: 1

See also: IDEPLUS, U1MB, FORMAT
```

##### ARC

```text
ARC - file archiver

Syntax:
 ARC cmd[opts] [d:][path]arc[.ext]
     [files...]

Packs files into one compressed archive (default extension .ARC) and works on existing archives. Compatible with SEA ARC; reads ALF archives. ARC alone prints a short help. The file list may hold several names, each with drive and path, and wildcards. No list means *.*.

Commands:
 A    add files
 M    move files in (deletes the originals)
 U    update: replace older entries and add new files
 F    freshen: replace older entries only
 D    delete entries
 X,E  extract files (a drive/path in the list is the destination); asks before overwriting (Y/N/A)
 P    print entries to the screen (can be redirected)
 L    list name, size, date and time
 V    verbose list: method, saving and packed size

Options (after the command):
 S    store without compression
 B    keep the old archive as .BAK
 W    no warning messages
 N    no notes or progress output
 H    screen off while working (faster)
 G    encrypt/decrypt; must be last and is followed by the password

Entries are kept in alphabetical order without paths. Methods used: stored, packed, squeezed, crunched; the best one is picked for each file.

Examples:
 ARC A DOCS *.DOC D2:*.TXT
 ARC L DOCS
 ARC XH DOCS D3:>OUT>*.*
 ARC AGSECRET SAFE NOTES.TXT
```

##### ATR

```text
ATR - set or clear attributes

Syntax:
 ATR [+|-][A|H|P] [d:][path]name[.ext]

Alias: ATTRIB

Sets (+) or clears (-) attributes of every file and directory matching the name.

Attributes:
 A  archived: set by backups and COPY /B; cleared when a file is written
 H  hidden: not shown by DIR, skipped by most commands; may still be run
 P  protected: cannot be erased, overwritten or changed

The S (subdirectory) bit cannot be changed with ATR.

Example:
 ATR +A -P *.COM

See also: DIR
```

##### BASIC

```text
BASIC - enter the built-in BASIC

Syntax:
 BASIC [/I|N] [d:][path][file]
       [params]

Switches the XL/XE built-in BASIC on and enters it. With a file name, BASIC is enabled and the binary file is loaded and run with the given parameters.

Options:
 /N  return to BASIC instead of DOS when the program ends
 /I  start BASIC cold, skipping the memory-save file

Memory save: when $BASIC names a file, the BASIC memory (and page 0 from $80, pages 4-6) is saved there when you leave BASIC with DOS, and loaded again when you enter it. Without $BASIC the feature is off. If the saved MEMLO does not match, you are asked: ESC goes back, RETURN starts cold.

BASIC and CAR are the same program (CAR.COM), which stays in memory while BASIC runs.

Examples:
 SET BASIC=D8:BASIC.SAV
 BASIC
 BASIC /N GAME.COM

See also: CAR, SET
```

##### BLOAD

```text
BLOAD - load a raw file to memory

Syntax:
 BLOAD [d:][path]file[.ext]
       [[$]bank:][$]address

Reads the whole file, unchanged, into memory from the given address, then returns to DOS. A bank index before the colon loads into extended memory. Nothing is checked: the file may overwrite anything.

Numbers are decimal; a leading $ means hex.

Example:
 BLOAD FONT.FNT $9C00

See also: LOAD, SAVE, MDUMP
```

##### BOOT

```text
BOOT - choose the file a disk boots

Syntax:
 BOOT [d:][path]file[.ext]

Marks a file on an SDFS or EOSFS disk as the program loaded by the boot sectors. The file may be in any directory.

FORMAT writes the SDFS or EOSFS loader. BOOT only records the file's first map or extent list in sector 1. Erasing or replacing the file clears the mark. The stock OS cannot boot 512 byte sectors.

Example:
 BOOT >DOS>DOS.SYS

See also: COLD, FORMAT
```

##### CAR

```text
CAR - enter the plugged-in cartridge

Syntax:
 CAR [/F|N|I] [/L mode] [d:][path]
     [file] [params]

Starts the cartridge plugged in on top of the DOS cartridge. With a file name the file is loaded and run with that cartridge enabled (e.g. compiled ACTION! programs).

Options:
 /N  return to the cartridge, not to DOS, after the program
 /I  start cold, skipping the memory-save file
 /F  run the file even when no ROM is seen at $A000
 /L  loading mode: S (0, SDX), A (64, Atari DOS, the default), N (128, no run), I (192, init only) or a number

Memory save: when $CAR names a file, the cartridge's memory is saved there on leaving with DOS and loaded again on entry, as BASIC does with $BASIC.

Examples:
 SET CAR=D8:CAR.SAV
 CAR
 CAR /N PROG.COM

See also: BASIC, LOAD, SET
```

##### CHDIR

```text
CHDIR - change the current directory

Syntax:
 CHDIR [d:][path]

Aliases: CD, CWD

Makes the given directory the current one on that drive (the current drive if none is given). Files named without a path are looked for there. With no parameter the current directory of the current drive is shown.

When the disk is changed, the current directory goes back to MAIN.

Examples:
 CD >GAMES>ARCADE
 CD ..
 CD D2:>

See also: MKDIR, RMDIR, PWD, PATH
```

##### CHKDSK

```text
CHKDSK - disk information

Syntax:
 CHKDSK [d:] [/X]

Shows the volume name, the sector size and the total and free space of a drive. Atari DOS 2 disks show the volume "DOS 2.0". The two numbers after the volume name help to detect a disk change: a write count and a random number set when the disk was formatted.

Options:
 /X  more detail about the file system, with the format date if known

Example:
 CHKDSK D2:

See also: DF, FORMAT, MEM
```

##### CHTD

```text
CHTD - set a file's time stamp to now

Syntax:
 CHTD [/Q] [+|-][A|H|P|S]
      [d:][path]file[.ext]

Gives every matching file and directory the current date and time (or the one set by a program). A file name must be given; *.* is not assumed. Hidden and protected files are skipped unless attributes say otherwise; protected files keep their protection.

Options:
 /Q  do not report each file

Example:
 CHTD *.DAT
 Changing TD in TEST.DAT

See also: DATE, TIME, ATR
```

##### CHVOL

```text
CHVOL - change the volume name

Syntax:
 CHVOL [d:]name

Renames the volume of a SpartaDOS disk. Up to 8 characters; spaces and inverse characters are allowed but not as the first character. Atari DOS 2 disks have no volume name.

Example:
 CHVOL D2:WORK
 Volume Name changed to WORK

See also: CHKDSK, FORMAT, DIR
```

##### CLR

```text
CLR - remove left-over variables

Syntax:
 CLR

Deletes the internal environment variables a batch file creates for itself. They stay behind only when a batch file was stopped with RESET; CLR cleans them up.

See also: SET
```

##### CLS

```text
CLS - clear the screen

Syntax:
 CLS [/F]

Clears the screen.

Options:
 /F  reopen the screen (GRAPHICS 0) instead of only clearing it; the $SCRDEF settings are applied again

Example:
 CLS
```

##### COLD

```text
COLD - restart the computer

Syntax:
 COLD [/C|N]

Restarts the system as at power on (a jump through $E477), but extended memory keeps its contents, so RAM disks survive.

Options:
 /C  restart with the DOS cartridge off and the cartridge plugged into it on
 /N  restart as if no cartridges were present

Hold OPTION while pressing RETURN to restart without BASIC.

Example:
 COLD

See also: BOOT, CAR
```

##### COMMAND

```text
COMMAND - the command processor

Syntax:
 COMMAND

COMMAND.COM reads command lines and runs them. It is started by DOS itself; you do not type it.

Internal commands are done by COMMAND itself. Other commands are programs: they are searched along $PATH (default CAR:) and then in the current directory. While a program runs COMMAND is removed from memory and loaded again afterwards. LOAD COMMAND.COM keeps it in memory.

A device other than a disk (e.g. CAR:) may be the current drive.

Example:
 LOAD COMMAND.COM

See also: PATH, PROMPT, LOAD
```

##### COMP

```text
COMP - compare two files

Syntax:
 COMP [d:][path]file1 [d:][path]file2
      [offset1 [offset2]]

Compares two files byte by byte and reports the positions and values that differ, and which file ends first. The optional offsets (from 0, up to 24 bits) are where the comparison starts in each file; default 0.

Example:
 COMP A.DAT B.DAT
 ?dif at 00000A:0A & 00000A:9B
 B.DAT EOF
```

##### CON

```text
CON - choose the console width

Syntax:
 CON 40|64|80

Switches the console between 40, 64 and 80 columns. 64 columns needs the CON64.SYS driver, 80 columns the CON.SYS driver; both may be loaded together. If the driver for the chosen width is not loaded, the screen goes back to 40 columns.

Example:
 CON 64

See also: CON64
```

##### CON64

```text
CON64 - 64-column screen driver

Syntax:
 DEVICE CON64          (CONFIG.SYS)

CON64.SYS installs a console with 64 columns and 24 lines, drawn in software on the 320x192 graphics screen. It needs extended memory (Port B or Axlon). After loading the screen still has 40 columns; type CON 64 to switch over and CON 40 to switch back.

The screen takes nearly 8K of main memory, and some programs do not work with it. In BASIC: GRAPHICS 0 is the 64x24 text mode, GRAPHICS 8 and 24 are bitmap modes; there is no text window.

In CONFIG.SYS, load CON64 before RAMDISK.

See also: CON
```

##### COPY

```text
COPY - copy files

Syntax:
 COPY [/switches] [+|-][A|H|P]
      [source] [dest][/A]

Copies files between drives, directories and devices, optionally under new names. No source means *.* in the current directory; no destination name keeps the names. Wildcards work as in RENAME: wild positions keep the source characters. Commas may stand for missing parameters.

/A right after the destination appends to that file. A copy from a character device (CON:, NUL:...) copies one file; CTRL-3 ends input from CON:.

Switches:
 /B  backup: copy only files without the A attribute, then set it
 /C  ask before each file
 /D  give copies the current date and time
 /I  ask before overwriting
 /K  copy all, then set A on the originals
 /M  move: delete the source after copying (same disk: just move the entry)
 /N  skip files that already exist
 /Q  quiet: only errors are shown
 /R  copy directories with everything in them
 /S  screen off while copying
 /V  show a summary at the end

Attributes are not copied. Existing files are overwritten unless they are hidden or protected. $COPY may name another program to run for COPY.

Examples:
 COPY *.TXT D2:
 COPY /R D1:>SRC D2:>
 COPY README.DOC PRN:
 COPY NUL: EMPTY.DAT

See also: RENAME, TYPE, MENU
```

##### DATE

```text
DATE - show or set the date

Syntax:
 DATE [/T | date]

Shows the date and asks for a new one; RETURN keeps it. Day, day-month or day-month-year may be typed (space also separates). The order is day-month-year, or month-day-year when $DAYTIME is 1 (2 means day first).

Options:
 /T  show the date only, do not ask

A date on the command line is set at once. Needs a clock driver for correct results.

Examples:
 DATE
 DATE 28-01-21
 DATE /T

See also: TIME, TD, CHTD
```

##### DELTREE

```text
DELTREE - delete a directory tree

Syntax:
 DELTREE [/Y] [/V] [d:]path

Deletes a directory with all its files and subdirectories, after asking for confirmation.

Options:
 /Y  do not ask
 /V  show each directory and file as it is deleted

If error 167 appears on a directory that looks empty, look for hidden entries with DIR +. A file that was never closed after a crash can also keep a directory from being removed; a disk checker can fix that.

Example:
 DELTREE /V D2:>OLD

See also: RMDIR, ERASE
```

##### DEV

```text
DEV - list the kernel devices

Syntax:
 DEV

Lists the installed DOS devices: number, name, driver address, and whether the DOS buffers its I/O. The number of free slots is shown last.

Example:
 DEV
 Id Name Addr  uBufs
  0 DSK: $0DCE On
  2 CAR: $0B95 On

See also: CHKDSK
```

##### DF

```text
DF - free space on all drives

Syntax:
 DF [/A]

Lists every drive that can be read with its total and free space in KiB, the percentage free and the volume name, and a total line at the end.

Options:
 /A  list all drives A: to O:, with the error for drives that cannot be read

Example:
 DF /A

See also: CHKDSK
```

##### DIR

```text
DIR - list a directory

Syntax:
 DIR [+|-][A|H|P|S] [d:][path][name]
     [/A|C|L|P|W]
 DIRS [+|-][A|H|P|S] [d:][path][name]
     [/A|C|P]

DIR shows name, extension, size in bytes (k for KiB above 999999), date and time; <DIR> marks a directory. The volume and directory names come first, free sectors last. No name means *.*. A directory name must end in > or \ to list its contents.

DIRS gives the short Atari DOS style list: sizes in sectors, * before protected entries.

Attributes select what is listed: A archived, H hidden, P protected, S directory. The default is -H; DIR + lists everything.

Switches:
 /A  show the attributes
 /C  count the entries
 /L  show symlink targets
 /P  wait for a key every screen
 /W  names only, in columns

Examples:
 DIR *.COM
 DIR + /A
 DIRS D2:>GAMES>

See also: ATR, FIND
```

##### DUMP

```text
DUMP - show a file in hex

Syntax:
 DUMP [d:][path]file[.ext]
      [[$]start] [[$]length] [/A]

Shows the file 8 bytes to a line: offset, hex bytes and the characters. Start and length (decimal, or hex with $) select a part of the file.

Options:
 /A  show special ATASCII characters as dots (for printers)

Without a file name, DUMP reads from the keyboard; CTRL-3 ends.

Example:
 DUMP CAR:POKE.COM 0 $20

See also: MDUMP, TYPE
```

##### ECHO

```text
ECHO - show text, echo batch lines

Syntax:
 ECHO ON|OFF
 ECHO [/N] text

ECHO ON makes the command processor show each command line it runs, also from batch files; ECHO OFF (the default) stops it.

ECHO text writes the text; variables like $PATH are replaced by their values. Output can be redirected.

Options:
 /N  no end of line after the text

Examples:
 ECHO Hello
 ECHO $PATH
 ECHO TEXT >>D1:FILE.TXT
```

##### ED

```text
ED - text editor

Syntax:
 ED [d:][path][file.ext]

A small full-screen editor for configuration and other text files, best up to about 8K. Lines are at most 128 characters; longer lines are split. Typing inserts. The window height is 10 lines or the value of $ED (1-22).

Keys:
 ESC        cancel / quit
 CTRL-L     load a file
 CTRL-S     save to a file
 CTRL-U/D   move window bottom up/down
 CTRL-V     show EOL characters
 CTRL-arrow or F1-F4 move the cursor
 SHIFT-CTRL-up/down page up/down
 CTRL-B/E   start/end of the text
 CTRL-A/Z   start/end of the line
 CTRL-T     tag the current line
 CTRL-G     go to the tagged line
 CTRL-Q     type the next key as a character
 CTRL-INS   insert a space
 CTRL-DEL   delete under the cursor
 SHIFT-INS  copy this line before the tagged one
 SHIFT-DEL  delete the line
 SHIFT-CTRL-E clear the buffer

Example:
 ED CONFIG.SYS
```

##### ERASE

```text
ERASE - delete files

Syntax:
 ERASE [d:][path]file[.ext]

Aliases: DEL, DELETE

Deletes the matching files from the given directory (the current one when no path is given). Wildcards may be used; usually there is no warning, but *.* asks "Erase ALL: Are you sure?". Protected files are not deleted.

Examples:
 DEL OLD.TXT
 ERASE D2:>TMP>*.BAK

See also: UNERASE, DELTREE, MENU
```

##### FIND

```text
FIND - search for files

Syntax:
 FIND [d: | device][path]name[.ext]

Looks for files matching the name (wildcards allowed) in all directories of all drives, or only on the given drive, device (e.g. CAR:) or directory. Each match is shown with its full path; hidden files are found too. The number of matches comes last.

Example:
 FIND *.DAT
 A:>SUPER.DAT
 B:>TESTS>TEST.DAT
 2 matches found

See also: DIR
```

##### FMT

```text
FMT - format text

Syntax:
 FMT [/S] [/J] [<<][path]file[.ext]
     [ncol]

A simple filter for text. For each line, leading spaces are removed and lines longer than ncol are folded.

Options:
 /S  runs of spaces become one space
 /J  folded lines are justified to both margins

ncol is 32 to 127; the default is the screen width. Works best when each paragraph is one long line. Use - for the file to read from a pipe; without a file FMT reads the keyboard (CTRL-3 ends).

Example:
 MAN DIR /P | FMT /S /J - 80 >>PRN:

See also: MAN, LESS, MORE
```

##### FORMAT

```text
FORMAT - format a disk

Syntax:
 FORMAT
 FORMAT /Q|QQ [d:] [volname]

Without parameters FORMAT opens the formatter menu. ESC leaves it before formatting starts.

/Q quickly rebuilds an empty SpartaDOS file system on the drive (any readable disk), with the given volume name, after asking; /QQ does not ask.

Menu choices:
 U  unit (1-9, A-O); the drive is read to find its type
 O  optimize: use the last sector too
 S  skew: Standard, High Speed (an XF551: its own fast order), or Ultra Speed (a US Doubler: an order for its Ultra Speed)
 M  mode: Sparta, Atari (DOS 2), or EOS (EOSFS)
 V  volume name, up to 8 chars
 D  density: single, medium, double, DD 512, high
 T  tracks: 40/77/80, SS or DS
 F  format the disk (destroys all data)
 B  build directory only (RAM disks, hard disks)

Example:
 FORMAT /Q D2: WORK

The skews need the drive to have them: another drive answers with an error. The Ultra Speed order is sent to the drive; Altirra formats with its own and ignores it, so its gain shows on a real US Doubler only.

See also: CHVOL, BOOT, CHKDSK
```

##### IDEPLUS

```text
IDEPLUS - IDE2.0PLUS support

The IDE2.0PLUS (IDE Plus 2.0) is a PBI hard disk interface. Its BIOS maps APT partitions to drives D1:-D15:; EOS reaches them through the OS's SIO like any other drive.

Verified in Altirra:
- EOS starts and warm-resets with the device.
- BIOS21.COM, the BIOS 2.1 updater, runs under EOS and flashes the device.
- With BIOS 2.1, EOS reads the physical disk (device $20, also by XDCB), uses a mapped partition (status, PERCOM, DISKINFO, DIR, TYPE, COPY) and reads it again after a warm reset.
- APT lists and changes the partition table; the BIOS uses the new mapping after a restart.

Setup: map partitions with APT, restart, then FORMAT the drive. To update the BIOS, run BIOS21.COM from the KMK/DLT distribution and answer its questions.

Not verified: real hardware, the slave disk, the BIOS's ATR mounting and SDX cartridge switching.

See also: APT, FORMAT
```

##### KEY

```text
KEY - keyboard buffer

Syntax:
 KEY [ON|OFF]

The first KEY installs a 32-key type-ahead buffer with faster key repeat and adds a resident KEY command (symbol @KEY). After that KEY ON and KEY OFF switch the buffer, and KEY shows its state. Auto-repeated keys are not buffered.

Example:
 KEY
 KEY is ON

Turn KEY OFF if a program has trouble with it.
```

##### LESS

```text
LESS - page through text

Syntax:
 LESS [/C] [<<][path]file[.ext]
      [>>[path]file[.ext]]

Shows a text file, folding long lines to the screen width. A file that fits on one screen is simply shown; a longer one can be paged through:

 Down,F2,RETURN,=  line down
 Up,F1,-           line up
 Right,F4,F,SPACE,* page down
 Left,F3,B,+       page up
 D / U             half page down/up
 G                 go to line number
 < / >             top / end
 Q, ESC            quit

Options:
 /C  clear the screen first

LESS also works as a filter at the end of a pipe. PC and Unix line ends and TAB are converted to ATASCII; with output redirected to a file LESS only converts. The file must fit in free memory.

Examples:
 LESS README.TXT
 DIR | LESS
 LESS PC.TXT >>ATARI.TXT

See also: MORE, TYPE, MAN, FMT
```

##### LOAD

```text
LOAD - load or unload a program

Syntax:
 LOAD [/X] [/L mode] [d:][path]
      [file[.ext]] [params]

Loads a file into memory without running it, or keeps a command resident (e.g. COMMAND.COM, X.COM). LOAD with no file removes all programs that are held in memory but not installed.

Options:
 /X  load under X.COM (as X file)
 /L  loading mode: S (0, SDX), A (64, Atari DOS), N (128, no run; the default), I (192, init only) or a number

Examples:
 LOAD COMMAND.COM
 LOAD

See also: MEM, SAVE, X
```

##### MAN

```text
MAN - show manual pages

Syntax:
 MAN [name] [/P|?]

Shows the help file name.MAN, .HLP, .DOC or .TXT found in the directories of $MANPATH (default CAR:). Files packed with ARC are unpacked on the fly (using $TEMP). If several match, MAN asks which one. MAN alone lists all pages.

Options:
 /?  only tell whether the page exists
 /P  do not use $PAGER

Without $PAGER the text is shown like TYPE, without stopping. $PAGER names a viewer to use instead; in it % marks where the file name goes and ; stands for a space.

Examples:
 MAN DIR
 MAN COPY | LESS
 SET MANPATH=CAR:;D1:>DOC
 SET PAGER=LESS;/C;%

See also: LESS, MORE, TYPE, FMT
```

##### MAP

```text
MAP - map drives

Syntax:
 MAP [unit] [SIO|OS|NORMAL|OFF] [d:]
 MAP [d:][path]file[.ext]

Assigns a physical drive number (unit) to a logical drive d: and chooses how requests for it go:

 NORMAL  PBI devices first, then SIO
 SIO     SIO only (skip PBI devices)
 OS      not available (EOS has no OS mode)
 OFF     drive disabled (138)

MAP keeps its own table, apart from SWAP's; it stays over RESET. A mode given alone changes only the mode. MAP with a file name reads one set of parameters per line from that file. MAP alone shows help and the table. The transfer speed is set by SIOSET.

Examples:
 MAP 1 SIO B:
 MAP 3 DK:     (drive 11; K: is the keyboard)

See also: SWAP, SIOSET
```

##### MDUMP

```text
MDUMP - show memory in hex

Syntax:
 MDUMP symbol | [[$]bank:][$]addr
       [[$]len] [/R]

Shows memory 8 bytes to a line, in hex and as characters. Bank index: 00 main memory, 02 system extended memory, 04 and up extended memory banks. Addresses of 6 hex digits reach 65C816 high memory. Numbers are decimal; $ means hex.

Options:
 /R  show offsets from the start instead of addresses

Examples:
 MDUMP $D300 8
 MDUMP 02:$08 8

See also: DUMP, PEEK
```

##### MEM

```text
MEM - show memory use

Syntax:
 MEM [/X]

Shows the low memory limits of main and extended memory, the memory mode (USE NONE, OSRAM or BANKED) and the free extended banks. Each limit has two values: the top of installed drivers and the top of programs held in memory (MEMLO). They differ only while programs are LOADed.

Options:
 /X  also the top of overlays, the bank type, the memory tops, free bytes and the total extended memory

Example:
 MEM
 Main: $12A9,$21A4
 Ext:  $7822,$7E1E
 Use:  BANKED
 2 Ext banks free

See also: LOAD, CHKDSK
```

##### MENU

```text
MENU - file manager

Syntax:
 MENU   (or just * at the prompt)

A full-screen program to copy, delete, rename, view and print files, also many at once (tagged), and on a single drive with disk swaps. Windows: directory tree, totals, files. RETURN switches between file and directory commands, ESC goes to the extra commands. ^ means hold CTRL.

File commands:
 C/^C copy file/tagged files
 D/^D delete file/tagged files
 E    run the file
 F    file mask
 L    log another drive/path
 P/^P print file/tagged files
 R    rename
 S    shell command
 T/^T tag file/all
 U/^U untag file/all
 V    view

Dir commands: A free space, D delete directory, F mask, L log, M make directory, P print, T/^T tag, U/^U untag.

Extra commands: D display mode, S sort, ^S shell command, Q quit.

Leave with ESC then Q, never with RESET.

See also: COPY, ERASE, RENAME
```

##### MKDIR

```text
MKDIR - make a directory

Syntax:
 MKDIR [d:]path

Aliases: MD, CREDIR

Creates a new directory. The last name in the path is the one created; the directories before it must exist. Without a drive the current drive is used.

Examples:
 MD TEST
 MKDIR D3:>MODEM>TEST

See also: CHDIR, RMDIR, RENDIR
```

##### MORE

```text
MORE - show text a screen at a time

Syntax:
 MORE [<<][path]file[.ext]

Same as TYPE file /P: shows the file and waits for a key after every 23 lines. Mostly used at the end of a pipe. Without a file it reads from the keyboard; CTRL-3 ends.

Examples:
 MORE README.TXT
 ARC | MORE

See also: LESS, TYPE, MAN
```

##### PATH

```text
PATH - set the command search path

Syntax:
 PATH [dir;dir;...]

Sets the list of drives, directories and devices, separated by ;, that are searched in order for a command before the current directory. PATH alone shows the list. PATH x is the same as SET PATH=x; SET PATH clears it. The default is CAR:.

A lone : or an empty entry means the current directory. The current directory is always searched last as well. Keep CAR: first for speed.

Examples:
 PATH
 PATH CAR:;A:>;D2:>DOS
 PATH ;CAR:

See also: APPEND, SET
```

##### PAUSE

```text
PAUSE - wait for a key

Syntax:
 PAUSE [seconds]

Stops a batch file with a message until RETURN is pressed, e.g. to change a disk. With a number (0-65535) it waits that many seconds instead.

Do not change the disk the batch file runs from.

Example:
 PAUSE
 PAUSE 5
```

##### PEEK

```text
PEEK - show a memory location

Syntax:
 PEEK symbol | [[$]bank:][$]address

Shows the byte at the address and the next one, in decimal and hex, the word they form, and the character of the first. Handy as a decimal/hex converter. With a symbol name, its address and bank are shown and used.

Bank index: 00 main, 02 system extended memory, 04 and up extended banks. Numbers are decimal; $ means hex. PEEK alone does nothing.

Examples:
 PEEK 710
 PEEK $2E7
 PEEK PRINTF

See also: POKE, MDUMP
```

##### POKE

```text
POKE - change a memory location

Syntax:
 POKE symbol | [[$]bank:][$]address
      [$]value

Writes a byte to memory. Bank index and numbers as for PEEK. A wrong value can crash the system: PEEK the old value first. POKE alone does nothing.

Useful locations:
 65   0 = SIO sound off, 1 = on
 82   left margin (0-39)
 559  0 = screen off, 34 = on
 710  background colour
 752  1 = cursor off, 0 = on

Example:
 POKE 710 0

See also: PEEK
```

##### PROMPT

```text
PROMPT - set the prompt

Syntax:
 PROMPT [text]

Sets the command prompt; PROMPT alone shows it. These codes in the text are replaced:
 $L  drive letter and colon (A:)
 $N  drive number and colon (1:)
 $P  path of the current directory
 $D  date
 $T  time
 $R  new line
An _ shows as a space.

PROMPT x is the same as SET PROMPT=x. The default is D$N. With no $PROMPT at all the prompt is >. $P reads the disk each time the prompt is shown.

Examples:
 PROMPT $L$P\
 PROMPT $D_$L

See also: SET, PATH
```

##### PWD

```text
PWD - show the current directories

Syntax:
 PWD

Lists the current directory of every drive that can be read.

Example:
 PWD
 A:\DRIVERS>
 C:>

See also: CHDIR, SETPATHS
```

##### RENAME

```text
RENAME - rename files

Syntax:
 RENAME [d:][path]old[.ext] new[.ext]

Alias: REN

Renames the matching files. Drive and path go with the old name only; both names are needed. Wildcards in the new name keep the characters of the old one. If the new name exists, error 151 is shown and nothing is renamed.

Examples:
 REN *.BAK *.DOC
 RENAME D2:AC*.* *.XX

See also: RENDIR, COPY
```

##### RENDIR

```text
RENDIR - rename a directory

Syntax:
 RENDIR [d:][path]old new

Renames a directory, with the same rules as RENAME for files.

Example:
 RENDIR SD_TK SDX_TK

See also: RENAME, MKDIR, RMDIR
```

##### RMDIR

```text
RMDIR - remove a directory

Syntax:
 RMDIR [d:]path

Aliases: RD, DELDIR

Removes an empty directory (the last name in the path). If it still holds files, error 167 is shown. A file left open by a crash can keep a directory from being removed; a disk checker fixes this.

Examples:
 RD TEST
 DELDIR D3:>MODEM>TEST

See also: DELTREE, MKDIR, CHDIR
```

##### RS232

```text
RS232 - load the R: serial driver

Syntax:
 RS232 [/R|F|E]

Loads the R: handler from an Atari 850 or P:R: Connection interface; a beep tells it has loaded. Use it before a program that does not load the handler itself, and only once (each load raises MEMLO). The 850 sends it only once after power on. Also gives the COM: device.

Options:
 /R  also reset the 850's poll, so it can load again after a restart
 /F  load even if R: is already there
 /E  use the R: already installed (for COM: only)

Example:
 RS232
 TYPE COM:
```

##### SAVE

```text
SAVE - save memory to a file

Syntax:
 SAVE [d:][path]file[.ext]
      [$]start [$]end

Writes the memory from start to end (both included) to a binary load file. With LOAD, it turns a file with many segments into one, or saves a memory snapshot. Numbers are decimal; $ means hex.

Example:
 SAVE TEST.DAT $4000 $4007

See also: LOAD, BLOAD
```

##### SET

```text
SET - environment variables

Syntax:
 SET [name[=value]]

SET alone lists all variables. SET name=value sets one; SET name removes it. Usable in CONFIG.SYS, batch files and at the prompt. A variable is used as $name; $name$ ends the name inside a longer word.

Some variables:
 PATH     command search path
 PROMPT   the prompt
 MANPATH  where MAN looks
 PAGER    viewer for MAN
 SYSERR   file with error texts
 BASIC    BASIC memory-save file
 CAR      cartridge memory-save file
 DAYTIME  date order (1 US, 2 EU)
 TEMP     place for temporary files

Examples:
 SET
 SET CAR=A:CAR.SAV
 SET CAR

See also: PATH, PROMPT, ECHO
```

##### SETPATHS

```text
SETPATHS - set current directories

Syntax:
 SETPATHS [d:][path] | file[.ext]

Makes the given directory the current one on its drive. With a file name it reads one directory per line from that file and sets each. Meant for the startup batch file.

Example file:
 A:>DOS>
 B:\UTILS\

Example:
 SETPATHS PATHS.TXT

See also: CHDIR, PWD
```

##### SIDE

```text
SIDE - SIDE, SIDE2, SIDE3 and MyIDE II support

These cartridges hold EOS in their flash and have a CompactFlash card (SIDE, SIDE2, MyIDE II) or an SD card (SIDE3) but no PBI BIOS, so EOS drives the card itself. At every start and reset it reads the card's APT table (LBA 0) and serves its mapped partitions as drives: up to 4, with 512-byte sectors.

Images, written with the cartridge's own flasher:
 EOS_SIDE.ROM    SIDE, 512K, from bank 0
 EOS_SIDE2.ROM   SIDE2 (and AVGCART as SIDE2), 512K
 EOS_MYIDE2.ROM  MyIDE II, 512K
 EOS_SIDE3.ROM   SIDE3, 8M: EOS at $780000, started with the SDX switch on

Verified in Altirra:
- each starts EOS from its flash with no cartridge in the slot, runs a batch, reads CAR:, enters and leaves BASIC, and survives a warm reset;
- a mapped partition: DIR, TYPE, COPY to it and read back;
- APT lists the table and APT NEW adds a partition (the card's size from its IDENTIFY or CSD).

Setup: APT INIT on a new card, APT NEW for each partition, APT MAP d p, restart, then FORMAT the drive.

Not verified: real hardware. Not used: the SIDE clock, the SIDE3's DMA, RAM and cartridge emulation, the MyIDE II's RAM. A table kept in the even bytes only is not read.

See also: APT, FORMAT, IDEPLUS
```

##### SIOSET

```text
SIOSET - SIO speed settings

Syntax:
 SIOSET [unit] [type [usindex]]
 SIOSET REFRESH [0|128]
 SIOSET WAITACK [[$]value]

Shows or changes how the SIO driver talks to each drive. Settings are normally found on the first access: a drive that answers the Ultra Speed question is used at its speed (US), else one that takes the XF551's high speed commands is used with them (XF), else the standard speed. SIOSET alone lists all drives; SIOSET n shows drive n. Unit 0 means all drives.

Types:
 RESET   forget; detect on next use
 NORMAL  standard speed
 XF      XF551 protocol
 INDUS   Indus GT protocol
 US      Ultra Speed; finds the speed, or uses usindex if given

REFRESH 128 makes the driver ask a drive again on its next use after a transfer failed; 0 (the default) does not.

WAITACK sets the time to wait for a drive's answer (EOS waits WAITACK x 2 frames): 2 is the OS value, 16 is needed for SIO2BT. REFRESH and WAITACK keep their values until the computer is switched off.

After DEVICE SIO /A or /C in CONFIG.SYS only the OS's SIO is used and SIOSET answers 154.

In Altirra the standard emulated drive takes the XF551's commands, so drives show XF; the SIO patch is faster than any real speed there: SIOSET n NORMAL for a drive, or DEVICE SIO /A for all, keeps it in use.

Examples:
 SIOSET
 SIOSET 8 US
 SIOSET WAITACK 16

See also: MAP, DF
```

##### SORTDIR

```text
SORTDIR - sort a directory

Syntax:
 SORTDIR d:[path] /N|T|S|D [/X]

Sorts the entries of a directory on disk (the current one when no path is given) and writes it back. At least one order is needed:
 /N  by name, then type
 /T  by type, then name
 /S  by size, then name and type
 /D  by date and time
 /X  descending
Digits come before letters. Atari DOS 2 disks are refused. SORTDIR alone shows help.

Example:
 SORTDIR D2:>GAMES> /N
```

##### SWAP

```text
SWAP - swap drive numbers

Syntax:
 SWAP [d d]

Exchanges two logical drives, given by number or letter without a colon, in either order. SWAP alone lists which physical drive each of A: to O: uses (A: = 1 ... by default). The change lasts until the next cold start.

Example:
 SWAP 2 O
 SWAP

See also: MAP
```

##### TD

```text
TD - time and date line

Syntax:
 TD [ON|OFF]

Installs a line at the top of the screen that shows the date and time. The first TD installs it; TD ON and TD OFF switch the line. The format follows $DAYTIME. An X in the line shows the caps/inverse key state. Needs a clock driver.

If a program misbehaves, use TD OFF.

Example:
 TD ON

See also: DATE, TIME, KEY
```

##### TIME

```text
TIME - show or set the time

Syntax:
 TIME [/T | hh[:mm[:ss]]]

Shows the time (24-hour) and asks for a new one; RETURN keeps it. Hours, hours:minutes or all three may be typed. A time on the command line is set at once.

Options:
 /T  show the time only, do not ask

Needs a clock driver for correct results.

Examples:
 TIME
 TIME 16:42
 TIME /T

See also: DATE, TD
```

##### TYPE

```text
TYPE - show a file

Syntax:
 TYPE [+|-][A|H|P|S] [d:][path]file
      [/P]

Writes the file to the screen (or to a redirected output). Any line length is fine. CTRL-1 stops and restarts the output. Attributes select files as in DIR; the default is -HS.

Options:
 /P  wait for a key after each 23 lines

Examples:
 TYPE README.TXT /P
 TYPE NOTES.TXT >>PRN:

See also: MORE, LESS, DUMP, COPY
```

##### U1MB

```text
U1MB - EOS image for the U1MB SDX slot

EOS_U1MB.rom is a separate 320 KiB EOS build for the SDX slot of the Ultimate 1MB. It selects its banks with the U1MB SDX bank register. It is a raw image without a cartridge header and it does not contain or replace the U1MB firmware.

Setup, no SDX needed: in the U1MB setup set SDX off and allow flash writes, start EOS from the EOS.car cartridge with the maintenance disk (EOSMAINT.atr) in D1:, and run U1MBFLSH EOS_U1MB.ROM: it checks the image, writes the SDX area only and restarts into it. Then remove the cartridge and set SDX on (320 KiB, GOS off). U1MBCHK checks the file alone. Give the U1MB PBI BIOS and any other PBI device (IDE2.0PLUS) different IDs, or turn the U1MB PBI BIOS off.

Clock: DEVICE RTIME8 (EOS's default) uses the U1MB clock when there is no R-Time 8; DATE and TIME read and set it.

RAM disk: the default RAM disk O: is in the extended memory EOS finds.

Verified in Altirra, with a boot stub in place of the U1MB BIOS: U1MBFLSH writes the slot (two flash chip types), EOS starts from it, survives a warm reset, reads the clock, uses the RAM disk, and works with an IDE2.0PLUS and APT. Not verified on real hardware.

See also: APT, IDEPLUS
```

##### UNERASE

```text
UNERASE - recover erased files

Syntax:
 UNERASE [d:][path]file[.ext]

Looks for erased files matching the name (wildcards allowed) and asks for each one whether to restore it. A file cannot be found or restored once its directory entry or one of its sectors has been reused by another file.

Example:
 UNERASE *.BAS
 Restore TEST.BAS? Y

See also: ERASE
```

##### VER

```text
VER - show the DOS version

Syntax:
 VER

Shows the version, date and copyright line of the DOS, as at start up.

Example:
 VER
```

##### VERIFY

```text
VERIFY - check disk writes

Syntax:
 VERIFY [ON|OFF]

With VERIFY ON each disk write is read back to make sure it can be read. This is slower, mostly on floppy drives. The default is OFF. VERIFY shows the state, also after a change.

Example:
 VERIFY ON
 VERIFY is ON
```

##### X

```text
X - run without cartridges

Syntax:
 X [/C] [/L mode] [d:][path]file[.ext]
   [params]

Runs a program with all cartridges switched off, including the DOS cartridge, for programs that need the RAM there (e.g. Turbo BASIC XL). The DOS library is then not available: only plain binary files run, single-byte I/O is slow and redirection is limited. Rule: if a program fails with a cartridge present, run it with X.

Options:
 /C  clear $80-$FF, $400-$6FF and MEMLO to MEMTOP before loading
 /L  loading mode as for LOAD

Example:
 X TURBO.COM

See also: LOAD, CAR, BASIC
```

##### XEP80

```text
XEP80.SYS - 80-column screen on an XEP80

Syntax:
 XEP80.SYS [/P] [/U] [/V] [/1]

Loads a resident E: and S: handler for
the Atari XEP80 interface: from then on
the screen editor shows 80 columns on
the XEP80's monitor. The handler stays
after RESET.

Options:
 /P  50 Hz (PAL) display
 /U  Ultra speed: 31.5 kHz both ways
     (needs an XEP80 that has it)
 /V  VHOLD timing for monitors that
     roll with the standard timing
 /1  XEP80 on joystick port 1 (the
     default is port 2)

The handler is Altirra's XEP80 handler
by Avery Lee, built for EOS.

Examples:
 XEP80.SYS
 XEP80.SYS /P

See also: CON
```


### 12.2 EOS Toolkit command reference

The Toolkit has 47 standalone programs. Their manual pages are packaged on
the Toolkit disk under `MAN>` and repeated here alphabetically.

#### Alphabetical reference

Commands in this section are listed alphabetically. Use the on-machine `MAN` command for the version installed on your cartridge or Toolkit disk.

##### APETIME

```text
APETIME - the date and time from the
PC

Syntax:
 APETIME [/Q]
 DEVICE APETIME [/Q] (in EOSSYS.SYS)

Asks the PC program on the SIO bus
(APE, AspeQt, RespeQt) for the date
and time, shows them and sets the
system's clock to them. With JIFFY
the clock then keeps going, so this
stands in for a clock cartridge.

/Q does not show the date and time.
When the PC does not answer,
APETIME says so.

APETIME.COM and APETIME.SYS are the
same program.
```

##### BASENAME

```text
BASENAME - the name part of a path

Syntax:
 BASENAME path [suffix]

Shows what follows the last separator
(: > < or \) of the path. A > or \ at
its end is dropped first, so a
directory gives its own name. With a
suffix, it is taken off the end of
the name when the name is longer.
A device or the main directory alone
(D1:, D1:>) gives an empty line.

Examples:
 BASENAME D1:>DOS>X.COM    X.COM
 BASENAME D1:>DOS>         DOS
 BASENAME D1:X.COM .COM    X
```

##### BSAVE

```text
BSAVE - save memory to a file

Syntax:
 BSAVE file address length

Writes length bytes of memory, from
address on, to a new file, as they
are. Numbers are decimal or $hex.
The address may also be a symbol, be
given with a memory index (1:$4000),
and have +n or -n after it.

Examples:
 BSAVE SCREEN.DAT $BC40 960
 BSAVE PAGE6.DAT $600 256
```

##### CAT

```text
CAT - files to standard output

Syntax:
 CAT [-n] [filename ...]

Copies the files, one after another,
to standard output. A name may have
the wildcards * and ?: the files that
match, in directory order. Without a
name standard input is read, so CAT
works with << and >>.

 -n  number the lines, from 1 over
     all the files

A file that is not there ends CAT
with the error.

Examples:
 CAT README.TXT
 CAT -n *.TXT
 CAT A.TXT B.TXT >>AB.TXT
 CAT <<IN.TXT
```

##### CDD

```text
CDD - change drive and directory

Syntax:
 CDD [d:path]

Works like CD, but the drive given
also becomes the current drive.
Without a parameter nothing happens.

Examples:
 CDD D2:>GAMES
 CDD C:
```

##### CIODEV

```text
CIODEV - the OS's CIO devices

Syntax:
 CIODEV [dev]

Without a parameter, lists the
devices in the OS handler table: the
name, the id (its place in the table)
in decimal and hex, and the address
of the device's handler table. Then
the number of free entries.

With a device name, shows the six
vectors of its handler table: OPEN,
CLOSE, GET, PUT, STATUS and SPECIAL.

These are the OS's devices, not the
ones the command line uses.

Examples:
 CIODEV
 CIODEV E:
```

##### CRC32

```text
CRC32 - CRC-32 checksums of files

Syntax:
 CRC32 [/H] file [file ...]

For each file prints its CRC-32, its
size in bytes and its name. The CRC
is the one zlib, PKZIP and "cksum -o
3" use. It is shown in decimal, or in
hex with /H. A parameter starting
with / ends the list.

Examples:
 CRC32 GAME.COM
 CRC32 /H D2:*.DAT >>SUMS.TXT
```

##### DATA

```text
DATA - a file as BASIC DATA lines

Syntax:
 DATA [file [start [count]]]
      [/H$CNLS [line step] [size]]

Prints the bytes of the file, from
offset start on, as Atari BASIC DATA
lines with numbers 10, 11, 12 ... A
count of 0 prints nothing; any other
count prints to the end of the file.
Without a file name, standard input
is read.

Options:
 /H  numbers in hex
 /$  hex numbers start with $
 /C  hex with no commas (10 a line)
 /N  no line numbers
 /L  first line number and step
     follow
 /S  numbers per line follows
     (default 7)
The numbers of /L come before the
one of /S.

Examples:
 DATA SPRITE.DAT /L 1000 10
 DATA FONT.FNT 0 /HC >>FONT.LST
```

##### DD

```text
DD - copy bytes of standard input

Syntax:
 DD [skip [count]]

Copies standard input to standard
output, leaving out the first skip
bytes. With count only that many
bytes are copied; when the input
ends first, error 136. Numbers may be
decimal or $hex.

Examples:
 DD 128 <<DISK.ATR >>DISK.RAW
 DD 6 20 <<SONG.NEO
 DD 0 256 <<DATA.BIN >>HEAD.BIN
```

##### DELDUP

```text
DELDUP - find files kept twice

Syntax:
 DELDUP [d:]path1> [d:]path2> [/RV]

Compares every file of path2 with
the files of path1 that have the
same size. A file of path1 with the
same contents is shown after
"** Dup: ", whatever its name.

 /R  delete those files from path1
     ("** Del: ")
 /V  show both names before each
     comparison

Subdirectories are not searched.
Directories, hidden and protected
files are left alone. At the end the
number of copies found.

Example:
 DELDUP NEW> GAMES> /R
deletes from NEW> what GAMES> has.
```

##### DIRNAME

```text
DIRNAME - the directory part of a path

Syntax:
 DIRNAME path

Shows the device and directory part
of the path: up to its last separator
(: > < or \), without a > or \ at the
end. The : of a device and the > of
the main directory stay. A name alone
gives an empty line (the current
directory).

Examples:
 DIRNAME D1:>DOS>X.COM   D1:>DOS
 DIRNAME D1:>X.COM       D1:>
 DIRNAME D2:X.COM        D2:
 DIRNAME D1:>DOS>        D1:>
```

##### DPOKE

```text
DPOKE - write a word to memory

Syntax:
 DPOKE [[$]index:][$]location
       [$]value [amount]

Writes the value low byte first. The
amount is the number of bytes, 1 to
4 (default 2; 0 writes one byte).
The location may be a symbol; an
index before the colon selects a
bank of extended memory.

Examples:
 DPOKE $2E7 $2000
 DPOKE $600 $12345678 4
```

##### DU

```text
DU - space used by a directory tree

Syntax:
 DU [/Q] [+|-AHPS] [d:path]

Counts every file and directory
below the directory given (the
current one when none) and shows the
total bytes, with kilobytes rounded,
of the directories, of the files and
of both.

Each entry is shown as it is counted.
/Q shows only the directories, /QQ
nothing but the totals.

A name or wildcard after the path
chooses the files counted; all
directories are entered. Attributes
choose among the entries of the
first directory only.

Examples:
 DU
 DU /Q D2:GAMES>
 DU /QQ *.COM
```

##### FSTRUCT

```text
FSTRUCT - the structure of a binary

Syntax:
 FSTRUCT file

Lists the blocks of a binary file in
order: Atari DOS segments with their
addresses and lengths, run and init
addresses, and the SpartaDOS X
relocatable blocks, fixups and
symbols. On a screen of 64 columns
or more each line also shows its
offset in the file. A file that does
not start with a header gives error
152.

Example:
 FSTRUCT GAME.COM
```

##### FT

```text
FT - find text in files

Syntax:
 FT [d:][path][name] [/C][/I][/V]
    [pattern]

Searches the files for the pattern,
which is the rest of the line,
blanks too, or is asked for. Each
line that has it is shown as
 NAME,line:text
lines counted from 0. For one file
given without wildcards the name is
left out.

 /C  the number of lines found in
     each file instead
 /I  upper and lower case alike
 /V  each file's name first

In the pattern:
 \?   any character
 \s   blank (a blank also matches
      a tab or the end of the line)
 \n   EOL       \t  tab
 \e   escape    \a  bell ($FD)
 \b   $7E       \0  \z  zero
 \xHH the code HH
 \cX  X's low 5 bits
 \\   backslash

Lines longer than 255 characters end
the search in that file.

Examples:
 FT *.TXT /I hello
 FT D2:SRC>*.ASM jsr\sPRINTF
```

##### HEAD

```text
HEAD - the first lines of a file

Syntax:
 HEAD [-n count | -count] [filename]

Copies the first count lines (10 when
none is given) to standard output. A
file with fewer lines is copied
whole. Without a name standard input
is read, so HEAD works with << and >>.

 -n count  the number of lines, 0 to
           65535 (also -ncount and
           -count)

Examples:
 HEAD README.TXT
 HEAD -n 5 LOG.TXT
 HEAD -3 <<LIST.TXT >>TOP.TXT
```

##### HEXDEC

```text
HEXDEC - 32-bit hex and decimal converter

Syntax:
 HEXDEC number

Prints the number in decimal and in
hex. A hex number starts with $. The
range is 0 to 4294967295 ($FFFFFFFF);
larger numbers wrap around.

Examples:
 HEXDEC 255
 HEXDEC $1A2B3C
```

##### INSTALL

```text
INSTALL - keep programs in memory

Syntax:
 INSTALL [d:][path]file [...]

Loads each file into memory without
running it, as LOAD does, but for
good: an unload (LOAD alone) does
not free it. Useful for commands
that are run often, such as a batch
file's.

Give the full file name with its
extension. Several files can follow
one another.

Example:
 INSTALL X.COM
```

##### INVERSE

```text
INVERSE - inverse video filter

Syntax:
 INVERSE

Copies standard input to standard
output with every character in
inverse video. Without redirected
input it reads the keyboard until
CTRL-3.

Examples:
 INVERSE <<README.TXT
 INVERSE <<A.TXT >>B.TXT
```

##### LS

```text
LS - list the files of a directory

Syntax:
 LS [-clwa] [+|-AHPS] [d:][path][name]

Without switches each file is shown
on a line of its own with its device
and path (no device for the current
drive), for programs that read a list
of files. Hidden files and
directories are left out unless -a
or attributes are given. A directory
ends with >.

Switches come first. Each can be
written -x or /X, several letters
after one sign: -la, /L/A. A - group
of other letters is attributes (-H,
-S, -AH).

 -c  Atari DOS names: D: or Dn:
     before each name
 -a  all entries, hidden ones and
     directories too
 -l  long list, one line each: name,
     size, date, time, attributes
 -w  names only, in columns

The long list:
 NAME.EXT      size dd-mm-yy hh:mm HPA
size is in bytes, in K from 100000
bytes, in M from 10000K; <DIR> for a
directory. H hidden, P protected, A
archived, - when not set.

-l wins over -w. -c counts only for
the plain list. The order is the
directory's.

Examples:
 LS /C
 LS -la SUB>
 LS -w *.COM
```

##### MACH

```text
MACH - the machine's hardware

Syntax:
 MACH

Shows what the system found when it
started:

- the computer: 400/800 or XL/XE
- the CPU: 6502, 65C02 or 65C816
- the address space: 64 KB, or 16 MB
  with a 65C816
- the clock speed in percent (100 is
  the standard speed)
- the memory: main, extended (with
  its type) and the 65C816's high
  memory, with its first address

MACH tests nothing itself.

Example:
 MACH
```

##### MD5

```text
MD5 - MD5 hashes of files

Syntax:
 MD5 [/H] file [file ...]
 MD5 [/H] /C hashfile

Prints a line for each file:
 MD5 (NAME) = hash
with the 128-bit hash in hex. Save
the lines to a file with >>NAME.

/C reads a file of such lines, or of
lines as md5sum writes them ("hash
name" or "hash *name"). Each file
named is hashed again and shown with
OK when its hash matches or BAD when
it does not. Other lines are passed
over. Lines may end with EOL, LF or
CR LF.

/H turns the screen off while
hashing, which is somewhat faster.

Examples:
 MD5 DATA.BIN >>DATA.MD5
 MD5 /C DATA.MD5
```

##### MEMINFO

```text
MEMINFO - the extended memory banks

Syntax:
 MEMINFO

Shows the type of the extended
memory (PORTB or Axlon), how many
banks there are and how many are
free. Then lists the free banks and
the ones in use, each as its memory
index and the value written to the
bank register to select it.

Use the list to pick banks for
programs that let you choose their
banks, so that they do not take one
the system uses.

Example:
 MEMINFO
```

##### MKPATH

```text
MKPATH - make several directories

Syntax:
 MKPATH [/FV] [d:][path]

Makes each directory along the path
that is not there yet. MKPATH A>B>C
makes A, A>B and A>B>C; A>..>B makes
A and B side by side.

/F  go on past directories that are
    already there
/V  show the path being made
/VV show each directory as it is
    made

Example:
 MKPATH /V D2:>SRC>LIB>OLD
```

##### NVPEEK

```text
NVPEEK - read or write a clock's
NV-RAM

Syntax:
 NVPEEK address [value]

Shows the byte at the address in the
NV-RAM of a real-time clock, in
decimal, in hex and as a character.
With a value, writes it there first.

It needs a clock with NV-RAM and its
driver loaded (one that offers the
symbol I_NVRAM); without one NVPEEK
does not load.

The NV-RAM often holds the settings
of the board the clock is on:
writing to it can lose them.

Examples:
 NVPEEK 16
 NVPEEK 16 $41

See also: NVWGL
```

##### NVWGL

```text
NVWGL - a clock's NV-RAM on the
screen

Syntax:
 NVWGL

Shows the 256 bytes of a real-time
clock's NV-RAM as hex, kept up to
date, "--" where a byte cannot be
read. Under them are 32 bytes from
the cursor as characters, and the
cursor's address in hex and decimal.

Keys:
 arrows  move the cursor
 0-9 A-F two digits write a byte at
         the cursor and move on
 space   ends

It needs a clock with NV-RAM and its
driver loaded (one that offers the
symbol I_NVRAM). The NV-RAM often
holds the settings of the board the
clock is on: writing to it can lose
them.

See also: NVPEEK
```

##### PATHSPL

```text
PATHSPL - split a file specification

Syntax:
 PATHSPL [d:][path]name.ext
         [d],[p],[f],[b],[x]

Puts the parts of a file name into
environment variables, for batch
files:
 d  device       C:
 p  path         >FOO>
 f  file name    BAR.EXE
 b  base name    BAR
 x  extension    EXE
Leave a field empty to skip that
variable; keep the commas.

Examples:
 PATHSPL C:>FOO>BAR.EXE D,P,F,B,X
 PATHSPL %1,,,,,EXT
```

##### PERCONF

```text
PERCONF - set a drive's geometry

Syntax:
 PERCONF d: [SIDES n] [TRK n] [SPT n]
            [BPS n] [STEP n] [FLG n]

Shows the drive's status and its
configuration (the PERCOM block):
sides, tracks, sectors a track,
bytes a sector, step rate and flags,
with the disk's size worked out from
them.

A drive that takes a configuration
can then be set up: press C and
answer the questions (Return keeps
the value shown, a word that is no
number starts again). The new block
is sent and the drive's status for
it shown (1 is good), then the block
is read back. R reads it all again,
Q or Esc ends.

With keywords PERCONF works alone:
it changes only the values given,
sends the block, reads it back and
shows it. The values are not
checked. The keywords:

 SIDES n  sides, 1 or 2
 TRK n    tracks: 35, 40, 77, 80
 SPT n    sectors a track: 18, 26
 BPS n    bytes a sector: 128, 256,
          512
 STEP n   step rate, 0 to 3
 FLG n    flags: 0, or 4 (MFM)

Numbers are decimal, or hex after $.

Examples:
 PERCONF D2:
 PERCONF D2: SPT 26 BPS 128 FLG 4

See also: XFCONF
```

##### PHD

```text
PHD - save the directory, change it

Syntax:
 PHD [d:path]

Saves the current drive and
directory in the variable _OLDWD,
then changes drive and directory as
CDD does. PLD goes back. Only one
directory is kept: a second PHD
replaces it.

Example:
 PHD D2:>WORK
 ...
 PLD
```

##### PLD

```text
PLD - back to the saved directory

Syntax:
 PLD

Changes to the drive and directory
that PHD saved, and forgets them.
If nothing was saved, PLD does
nothing.
```

##### RDDUMP

```text
RDDUMP - save a RAM disk to a file

Syntax:
 RDDUMP d: [d:][path]file

Writes every sector of the RAM disk
in drive d: to the file, so that
RDLOAD can put them back after the
computer was switched off.

The drive must be a RAM disk: one
that reports one track of 256-byte
sectors, a multiple of 64 of them.
Else RDDUMP says it is not one.

RDDUMP needs 16K of free memory.

Example:
 RDDUMP O: C:>SYS>RAMDISK.DMP

See also: RDLOAD
```

##### RDLOAD

```text
RDLOAD - a RAM disk back from a file

Syntax:
 RDLOAD [d:][path]file [d:]

Puts the sectors RDDUMP saved back on
the RAM disk in drive d:. Without a
drive, the one in the variable
RAMDISK (set when the RAM disk is
installed).

The drive must be a RAM disk of the
same size as the dump. Only the
sectors in use on the dumped disk
are written, which is quick when the
disk was not full.

To restore it at each start, put in
AUTOEXEC.BAT:

 IF RAMDISK
   IF NOT EXISTS $RAMDISK>*.*
     RDLOAD C:>SYS>RAMDISK.DMP
   FI
 FI

See also: RDDUMP
```

##### RPM

```text
RPM - a floppy drive's speed

Syntax:
 RPM [d:]

Shows how many times a minute the
disk in the drive turns, until a key
is pressed. Most Atari drives turn
at 288, the XF551 and PC drives at
300.

RPM reads one sector over and over:
on a drive that keeps whole tracks
in memory, a hard disk or a RAM disk
the number only tells how fast the
reads are.
```

##### RUN

```text
RUN - call machine code

Syntax:
 RUN symbol
 RUN [[$]index:][$]address

Asks "Jump to $ii:$aaaa (i:a)?" and
on Y calls the address with JSR; the
code ends with RTS. Any other key
cancels. A symbol stands for its
address; an index selects a bank of
extended memory. Addresses above
$FFFF need a 65816 (error 184).

Examples:
 RUN $600
 RUN 4:$4000
```

##### SEQ

```text
SEQ - a sequence of numbers

Syntax:
 SEQ [first [step]] last

Shows the numbers from first (1 when
not given) to last, step (1 when not
given) apart, one per line. Numbers
are 0 to 4294967295, decimal or $hex.
With first above last SEQ counts
down; with last alone and last 0 it
shows nothing. The last number shown
is the last one not past last.

Examples:
 SEQ 10
 SEQ 0 5 100
 SEQ 10 1 >>COUNT.TXT
```

##### SHUFFLE

```text
SHUFFLE - random directory order

Syntax:
 SHUFFLE d:[path]

The opposite of SORTDIR: puts the
entries of a directory in random
order. DOS 2 disks are refused,
since DOS 2 itself would no longer
find the files.

Examples:
 SHUFFLE D1:
 SHUFFLE D2:>GAMES>
```

##### SL

```text
SL - list or add system symbols

Syntax:
 SL [name [[$]address]]

Without a parameter, lists every
symbol: its name, its address and
its level. The symbols added in
memory come first, then the system's
own.

With a name, lists only the symbols
whose names start with it.

With a name and an address, adds the
symbol first. The address is 0 to
65535. SL then stays in memory, so
that the symbol is kept.

Adding symbols with wrong addresses
can make programs that use them
crash: use it for testing.

Examples:
 SL
 SL U_
 SL COVOX $D600
```

##### STAT

```text
STAT - all about one directory entry

Syntax:
 STAT [+AHP] [d:][path]name

Shows for a file, directory or link:
 Name  in 8.3 form
 Type  regular file, directory or
       symbolic link
 Attr  L link, S directory,
       A archived, H hidden,
       P protected, - when not set
 Node  the first sector, in hex and
       decimal, and the device
 Size  in bytes and in sectors
 Date  and time of the last change
A link also shows where it leads.

Wildcards show the first entry that
matches. Attributes choose which.

Example:
 STAT SUB>README.TXT
```

##### STRINGS

```text
STRINGS - the text in a binary file

Syntax:
 STRINGS [-n length | -length]
         [filename]

Shows every run of at least length
printable characters in the file as
a line. Printable are $20 to $7C
($7D and $7E would clear the screen
and delete). Without a name standard
input is read, so STRINGS works with
<< and >>.

 -n length  the shortest run shown,
            1 to 255 (4 when none
            is given; also -nlength
            and -length)

Examples:
 STRINGS GAME.COM
 STRINGS -n 8 DATA.BIN >>TEXT.TXT
```

##### TAIL

```text
TAIL - the last lines of a file

Syntax:
 TAIL [-n count | -count] [filename]

Copies the last count lines (10 when
none is given) to standard output.
Without a name standard input is
read, so TAIL works with << and >>.

 -n count  the number of lines, 0 to
           65535 (also -ncount and
           -count)

The input is kept in the free memory.
When it is full, only the last count
lines are kept; when these alone fill
it, the lines in its first half go,
so fewer lines are shown.

Examples:
 TAIL LOG.TXT
 TAIL -n 3 <<LIST.TXT >>END.TXT
```

##### TOUCH

```text
TOUCH - new empty file, or new date

Syntax:
 TOUCH [/C|/H] [d:][path]name

A file that is not there is made,
empty. One that is there gets the
date and time of now.

 /C  do not make a missing file
 /H  a link itself, not the file it
     leads to

Examples:
 TOUCH NEW.TXT
 TOUCH /C OLD.DAT
```

##### U1MBCHK

```text
U1MBCHK - validate the raw EOS U1MB slot image

Syntax:
 U1MBCHK [d:][path]EOS_U1MB.ROM

Checks that the file is exactly 320 KiB and that all forty 8 KiB banks have
the common reset tail required by the EOS U1MB build. The input is read only.
U1MBCHK does not program or erase flash.
```

##### U1MBFLSH

```text
U1MBFLSH - write EOS into the Ultimate 1MB SDX area

Syntax:
 U1MBFLSH [d:][path]EOS_U1MB.ROM

Writes a 320 KiB EOS U1MB slot image (make u1mb) into the first 320 KiB of the U1MB flash, the SDX area, and restarts the computer into it.

The EOS maintenance disk (EOSMAINT.atr) has the image, this program and EOS startup files without a RAM disk. For the first installation start EOS from the EOS.car cartridge with the U1MB's SDX off; later from the slot's EOS.

Before anything is written it checks that an Ultimate 1MB is present, that the file is exactly 320 KiB with one reset tail in all forty banks (as U1MBCHK), and that 20 extended memory banks are free, and reads the whole image into them. Start the DOS without a RAM disk for this (an EOSSYS.SYS or CONFIG.SYS without DEVICE RAMDISK). It then asks; only Y writes.

Writing: the OS ROM is switched out, interrupts are off. U1MBFLSH reads the flash chip's ID (29F040 types from AMD, AMIC, Bright, Hynix, Macronix; SST 39SF040), erases only the sectors of $00000-$4FFFF, writes and compares every bank, then cold starts. The U1MB BIOS, BASIC and OS ($50000-$7FFFF) are never addressed.

If the chip does not answer (flash writes protected in the U1MB setup, SDX off, an unknown chip) nothing is erased. If erasing or writing fails, the screen says so; the U1MB BIOS is unchanged, so after RESET its setup starts and the SDX area can be written again. Do not reset or switch off while it writes.

Verified in Altirra's U1MB emulation running under EOS (AMIC A29040 and SST 39SF040 chips; also from EOS.car with SDX off into an empty SDX area). Under SDX 4.50 it loads and makes its checks; writing from SDX in the U1MB slot has not been tested. Not yet tested on real hardware.

See also: U1MBCHK
```

##### WC

```text
WC - count words, lines and bytes

Syntax:
 WC [/W][/L][/C] [d:][path]name

Counts the words, lines (EOLs) and
bytes of a file, or of standard
input when no name is given, and
shows them with the name. Words are
split by blanks and EOLs.

 /W  words only
 /L  lines only
 /C  bytes only
Options together choose several.

Examples:
 WC README.TXT
 WC /L LIST.TXT
```

##### WHICH

```text
WHICH - where a command is found

Syntax:
 WHICH command ...

Looks for each command as the command
processor does: a built-in command,
else the program NAME.COM (.COM
unless the name has an extension).
With a device or directory in the
name only there is looked; else the
current directory and then each entry
of $PATH, in order.

Shows NAME: built-in, the file as it
is found (X.COM in the current
directory, CAR:DIR.COM), or
NAME: not found. Programs run through
COMEXE or RUNEXT are not looked for.

Examples:
 WHICH DIR
 WHICH TYPE COPY MYPROG
```

##### XFCONF

```text
XFCONF - set a floppy drive's density

Syntax:
 XFCONF [d: [/n]]

For drives that do not find the
density of a disk themselves, such
as the XF551: the density is sent to
the drive as a PERCOM block, read
back and checked.

Without a parameter, XFCONF asks for
the drive (1-4) and the density.
With a drive alone it tells whether
the drive can be set. With a drive
and /n it sets density n:

 /1 single, 40 tracks, 90K
 /2 enhanced, 40 tracks, 130K
 /3 double, 40 tracks, 180K
 /4 double, two sides, 360K
 /5 double, two sides, 80 tracks,
    720K

The messages:

Drive not configurable - a drive
 without PERCOM (a stock 810 or
 1050).
Drive is not a floppy - a hard disk
 or a RAM disk.
Drive rejected the config - the
 drive refused it.
Drive cannot do this density - the
 drive took it but set another.

Example:
 XFCONF D2: /3

See also: PERCONF
```

##### XT

```text
XT - time a command

Syntax:
 XT command [parameters]

Runs the command line and prints how
long it took:
 Time: h:mm:ss.hh
The time is counted in video frames,
so it includes loading a program,
and is wrong for a command that
stops the frame counter.

Examples:
 XT COPY *.* D2:
 XT ECHO
```

##### XVER

```text
XVER - DOS version and build

Syntax:
 XVER

Shows the EOS version, the SpartaDOS
X version it stands in for, the date
and time the cartridge was built,
the cartridge's name and whether it
passes another cartridge through.
With DAYTIME=1 the date is shown
month first.
```

## Hardware compatibility status

EOS is built in several image formats from the same source. Each image below
has been booted in an emulator as described; none has yet been tested on
real hardware. The per-target table and the reasons for each gap are in
[EOS Compatibility](EOS_COMPATABILITY.md).

| Image | Hardware | Build |
| --- | --- | --- |
| `build/EOS.car` | AtariMax/Maxflash 8 Mbit (1 MiB) cartridge, CAR type 42 | `make eos` |
| `build/EOS_U1MB.rom` | Ultimate 1MB SDX slot, raw 320 KiB | `make u1mb` |
| `build/EOS_SIC.car` | SIC! 512 KiB, CAR type 56 | `make sic` |
| `build/EOS_SICP.car` | SIC!+ 1024 KiB, CAR type 83 | `make sic` |

### Ultimate 1MB with an IDE2.0PLUS

This is the configuration EOS's emulator tests model most completely: EOS
starting from the U1MB's SDX slot, the U1MB's extended memory for the RAM
disk, its clock for the date and time, and an IDE2.0PLUS for the hard disk.

1. **Write EOS into the U1MB SDX slot.** `EOS_U1MB.rom` is a raw 320 KiB image
   for the U1MB SDX flash area (the first 320 KiB of the U1MB flash; select
   the 320 KiB SDX size, which leaves no room for GOS). It contains no U1MB
   firmware and replaces none. Everything for this is on the EOS
   maintenance disk, `EOSMAINT.atr` (`make maint`): the image, `U1MBFLSH`,
   `U1MBCHK`, `APT`, `FORMAT`, their help pages, and EOS startup files that
   install no RAM disk (`U1MBFLSH` needs 20 free extended banks for the
   image). No SDX is needed: for the first installation set SDX off in the
   U1MB setup (the cartridge port is used) and allow flash writes, start
   EOS from `EOS.car` on a Maxflash cartridge with the maintenance disk in
   D1:, and run `U1MBFLSH EOS_U1MB.ROM`. It checks the image, asks, erases
   and writes only the SDX area (`$00000-$4FFFF`), compares every bank and
   restarts the computer into the slot's EOS. Then remove the cartridge and
   set SDX on (320 KiB, GOS off) in the U1MB setup. Later updates run the
   same way from the slot's EOS. The U1MB BIOS, BASIC and OS are never
   touched, so if writing fails, the U1MB setup still starts after RESET
   and you can write again. [EOS Hardware Test](HARDWARE_TEST.md) lists
   every step.
2. **Keep the PBI devices apart.** The IDE2.0PLUS and the U1MB's own PBI BIOS
   must not use the same PBI device ID; if you use the IDE2.0PLUS for the
   hard disk, turn the U1MB's PBI BIOS off or give it another ID. Switch the
   IDE2.0PLUS's own SDX cartridge off (its setup's `SDX cartridge` option or
   switch), so that EOS in the U1MB slot is the only DOS cartridge.
3. **Update the IDE2.0PLUS BIOS if needed.** `BIOS21.COM` (KMK/DLT BIOS 2.1)
   runs under EOS: answer `Y` to its questions, then power the computer off
   for ten seconds. In the emulator EOS ran it on an erased device and the
   result booted and served partitions.
4. **Partitions.** The BIOS maps APT partitions to drives. On a new card:
   `APT INIT` (a card that held anything, such as a PC FAT partition, needs
   `APT INIT /F`), then `APT NEW 32M` (or a smaller size) for each
   partition, `APT MAP D2: 1` and so on for each drive, restart the
   computer so the BIOS reads the table, and `FORMAT /QQ D2: NAME` for each
   drive. `APT` alone shows the table; `APT DEL`, `APT BOOT`, `APT AUTO` and
   `APT WP` remove a partition or change the boot drive and flags. Every
   change is shown first and written only after `Y`. A partition holds at
   most 65535 sectors of 512 bytes (32 MiB), the most EOS's file system
   addresses; a larger card simply gets more partitions.
5. **Clock and RAM disk.** Without a configuration file EOS turns on its
   clock driver (`DEVICE RTIME8`); with no R-Time 8 it uses the U1MB clock,
   so `DATE`, `TIME` and new files carry the U1MB's date and time. The
   default RAM disk is `O:` in the extended memory EOS finds. With your own
   `EOSSYS.SYS`/`CONFIG.SYS`, add `DEVICE RTIME8` and `DEVICE RAMDISK` lines.

What the emulator test of this setup (`tools/combo_test.py`) checks: EOS
boots from the U1MB SDX slot with the IDE2.0PLUS at BIOS 2.1; `DATE` and
`TIME` read the U1MB clock; a file goes from D1: to the RAM disk `O:` and from
there to the IDE partition D2:; `APT` lists the table; after a warm reset
both `O:` and D2: are read again, and the host finds the file on the
partition. Not checked there: setting the U1MB clock (the emulator's clock
always reads the host's time), the U1MB BIOS itself (the test uses a minimal
boot stub in its place, set to 1088K memory; the RAM disk then has about 3770
free sectors).

Testing this setup on your own machine: follow
[EOS Hardware Test](HARDWARE_TEST.md), which lists each step and what the
emulator showed.

### Other targets

- **AtariMax/Maxflash 8 Mbit:** the standard `EOS.car`; all emulator suites
  run on it.
- **SIC! and SIC!+:** `EOS_SIC.car`/`EOS_SICP.car` boot, run a batch, read
  `CAR:` and survive a warm reset in Altirra (`make carttest`). EOS has no
  SIC! flasher yet: the SIC!'s flash write enable (register bit 7) and its
  chips have not been exercised in an emulator test.
- **Atari800:** `EOS.car` boots on XL, 130XE, PAL and 320K (Rambo) machines,
  runs programs, reads and writes files and directories, reads `CAR:` and
  survives a warm reset (`make atari800test`).
- The remaining targets (Incognito and its Colleen mode, Turbo Freezer 2011,
  SIDE, SIDE2/AVGCART, SIDE3, Maxflash 1 Mbit, MyIDE II, SuperCart,
  intSDX128) have no EOS image yet; the compatibility guide says why for
  each.
