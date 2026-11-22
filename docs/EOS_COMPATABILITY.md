# EOS Compatibility

EOS is a new, small Linux-like operating environment for Atari 8-bit
computers. It retains selected documented SDX and BW-DOS program interfaces,
but it is not a drop-in shell or filesystem replacement. Compatibility here
means a named program ABI or transient interchange tool; it never implies a
hidden case-folding, 8.3, SDFS, or DOS2 mount fallback.

## A ground-up implementation

EOS is a complete rewrite from the ground up. Its kernel, loader, command
processor, device interfaces, and disk file system were implemented as new
EOS code. EOS is not a patched SpartaDOS X cartridge, and it is not an
expanded BW-DOS kernel. It adopts established interfaces and disk layouts
where that is needed to run existing software and read existing media, while
keeping the implementation independent. A few optional components retain
their own upstream code and notices; for example, the XEP80 handler identifies
its Altirra source separately in `eos/xep80/`.

The rewrite gives EOS room to make different engineering choices: banked
cartridge code, a shared library and loader, a new filesystem implementation,
and a larger cache with measured write and lookup paths. Development uses
modern host tools alongside Atari 8-bit assembly: MADS builds the cartridge,
Python tools build and inspect disk images, a host-side 6502 simulator speeds
up iteration, and Altirra runs integration tests against EOS and SpartaDOS X
reference behavior. Automated disk checks and benchmarks help catch mistakes
and show where time is spent. The target still runs on the Atari's 6502-family
hardware; the host tools make it practical to tune and verify that small,
constrained implementation. Those tools help select and measure efficient
algorithms; they do not add host-side runtime requirements to the cartridge.

See [Why EOS?](WHY.md) for the project's motivation and
[benchmarks](BENCHMARKS.md) for measured workloads and their test conditions.

## Program compatibility

| Program or environment | Support |
| --- | --- |
| SpartaDOS X 4.5 relocatable programs | Supported through the SDX loader and documented library/kernel interfaces. |
| SpartaDOS X commands and drivers | Programs using documented imports often run; foreign filesystem drivers and undocumented internals are not resident compatibility targets. |
| BW-DOS programs | Supported through EOS's bounded BW-DOS program environment. |
| Atari DOS 2/2.5 and MyDOS Atari binaries | Supported when the program uses compatible Atari binary and OS conventions. |
| EOS programs | Native EOS commands, drivers, and utilities run directly. |

The SDX compatibility layer preserves the interfaces many programs import,
including COMTAB, the system symbol table, library entry points, file
operations, and device calls. EOS runs BW-DOS programs using a BW-DOS-style
COMTAB while those programs execute. Compatibility is strongest for ordinary
DOS programs; software that depends on undocumented internals, a particular
serial device, memory expansion, video hardware, or exact timing may need
machine-specific testing.

## Disk and file-system compatibility

| Disk format | Read/write | Boot notes |
| --- | --- | --- |
| EOSFS v2 | Resident read/write | The only resident mounted filesystem; bootable with 128/256-byte sectors. |
| SDFS 2.0/2.1 | Transient inspect/check/import/export/create | Accessed by Toolkit raw-sector commands, never mounted. |
| Atari DOS 2.0S/2.5 and MyDOS | Transient inspect/check/import/export/create | Accessed by Toolkit raw-sector commands, never mounted. |
| EOSFS v1 and BW-DOS disk formats | Not mounted | Convert with an appropriate external/host tool; there is no legacy fallback. |

EOS itself starts from its AtariMax cartridge. Its configuration and startup
batch are `EOSSYS.SYS` and `EOSAUTO.BAT`, with fallback to SDX's
`CONFIG.SYS` and `AUTOEXEC.BAT`. Atari DOS `AUTORUN.SYS` behavior is separate
and is not used as EOS startup configuration. For EOS's boot marker and
filesystem details, see the [User Manual](USER_MANUAL.md).

Atari DOS, MyDOS and SDFS volumes retain their own naming, directory and
capacity constraints. `fsinfo` reads/checks/imports them, `fsexport` writes an
explicit mapped 8.3 root file, and `fscreate` creates the bounded 720x128
profiles. EOSFS uses clean/dirty revisions `$47`/`$48`; foreign systems must
not interpret its extent lists as SDFS sector maps.

## Compatibility boundaries

EOS's compatibility goal is deliberately bounded. The current project leaves
the SDX D3 filesystem-driver interface (including FATFS and CPMFS drivers) out
of scope. 65816-specific kernel interfaces are not considered
supported because they have not been verified on 65816 hardware. Optional
drivers also require the hardware, memory, and serial devices they target.

Retain a backup of important media before filesystem changes. Use EOSFS for
native work. Use the explicit Toolkit import/export commands when exchanging
data with SDFS, DOS2 or MyDOS; lossy names are reported before writing.

## Hardware and emulator support

EOS is built from one source in several image formats. Only the bank
register differs: the AtariMax image selects a bank by writing to
`$D500+n`; the U1MB and SIC! images write the bank number to a fixed
register (`$D5E0` and `$D500`). Every result below comes from an emulator
run named in the table; no image has been tested on real hardware yet.

| Image | Format | Build |
| --- | --- | --- |
| `build/EOS.car` | AtariMax/Maxflash 8 Mbit (1 MiB), CAR type 42 | `make eos` |
| `build/EOS_U1MB.rom` | U1MB SDX slot, raw 320 KiB (40 banks of 8 KiB) | `make u1mb` |
| `build/EOS_SIC.car` | SIC! 512 KiB, CAR type 56 | `make sic` |
| `build/EOS_SICP.car` | SIC!+ 1024 KiB, CAR type 83 | `make sic` |

### Verified in emulators

- **Altirra, standard cartridge:** the EOS, CAR:, format, Toolkit and
  exBASIC suites (`make eostest`, `cartest`, `fmttest`, `tktest`, `xbtest`)
  run on `EOS.car`. `make carttest` boots `EOS.car`, `EOS_SIC.car` and
  `EOS_SICP.car`: prompt, startup batch, a file written, a `CAR:` file read
  from the cartridge's banks, and both again after a warm reset.
- **U1MB SDX slot (`make u1mbemu`):** the emulated U1MB flash holds
  `EOS_U1MB.rom` at `$00000`, a boot stub (`tests/u1mb/boot.asm`) at
  `$50000` and AltirraOS (assembled from the Altirra source) at `$70000`.
  EOS starts from the slot, runs its batch, reads `CAR:` and survives a warm
  reset; Altirra reports the SDX cartridge bank enabled.
- **IDE2.0PLUS (`make ideplustest`):** EOS runs `media/IDE2.0PLUS/BIOS21.COM`, the
  BIOS 2.1 updater, on an emulated device whose flash starts erased; the
  updater erases, programs and verifies, and Altirra's
  `System.SaveFirmwareIDEMain` saves the 128 KiB flash
  (`build/ideplus/ide-main.rom`, checked for the PBI ROM signature and the
  2.1 identification). A second session boots that image: the BIOS's
  physical device (`$20`) reads LBA 0, also as an XDCB; D2:, mapped from an
  APT partition, answers status, PERCOM, sector read and DISKINFO (bus 1,
  device 1, partition 1); `DIR`, `TYPE` and `COPY` work on it, and it is read
  again after a warm reset; the host checks the partition's file system.
  `make ideplusemu` also boots EOS with the device present but erased.
- **APT (`make ideplustest`, case `apt`):** EOS's `APT` command lists the
  table, maps and unmaps drives, sets the boot drive and the automount and
  write-protect flags, with a preview and a Y/N question each time; an N
  leaves the disk unchanged. The sector written is byte-for-byte the one the
  host reference `tools/apt.py` produces for the same edits; a reserved
  entry and bytes outside every entry stay as they were; after a restart the
  BIOS serves the new mapping. A table found through a protective MBR
  (type `$7F`) and a table of another revision are shown but not changed.
  On a blank disk (`ideplustest`, case `partition`): `INIT`, two `NEW`
  partitions, a partition too big for the disk refused, `MAP`, `DEL`
  refused while mapped; after a restart the BIOS serves both partitions,
  `FORMAT /QQ` and `COPY` work on them, `INIT` without `/F` is refused on
  the table, `UNMAP` and `DEL` work; the host checks the table and the file
  system.
- **U1MB with IDE2.0PLUS (`tools/combo_test.py`):** EOS from the U1MB SDX
  slot with the IDE2.0PLUS at BIOS 2.1: `DATE` and `TIME` read the U1MB clock
  (DS1305), the default RAM disk `O:` uses the 1088K memory (60 banks, about
  3770 free sectors), a file goes from D1:
  through `O:` to the IDE partition, `APT` lists the table, and after a warm
  reset `O:` and D2: are read again.
- **Atari800 (`make atari800test`):** `EOS.car` on an 800XL, a 130XE, a PAL
  800XL and a 320K Rambo machine: startup batch, copies, `MKDIR`, `DIR`, a
  relocatable program, `CAR:` and `MEM`; on the 800XL a warm reset and a
  typed command.

Altirra setup notes for these tests: the U1MB is only active when the
profile file selects the global profile (Altirra's stock XL/XE profile would
otherwise override it), and fast boot must be off for PBI hard disks,
because with it on Altirra answers disk requests for empty drive slots
itself before the OS asks the PBI devices. `tools/emu.py` handles both.

The EOS maintenance disk, `EOSMAINT.atr` (`make maint`, tested by `make
mainttest`), holds the U1MB image, `U1MBFLSH`, `U1MBCHK`, `APT`, `FORMAT` and
a few tools with EOS startup files that install no RAM disk; with it and
`EOS.car` the U1MB and the IDE2.0PLUS are set up without SDX.

The checklist for a first real-hardware test of the U1MB + IDE2.0PLUS setup
is [EOS Hardware Test](HARDWARE_TEST.md).

### Status by target

| Target | Required EOS feature | Current EOS status | Gap and reason |
| --- | --- | --- | --- |
| U1MB | MAN, APT FDISK | `EOS_U1MB.rom` boots from the emulated SDX slot; RAM disk and clock work there; `MAN U1MB`; `APT` works with the IDE2.0PLUS BIOS | Real hardware. The real U1MB BIOS is not available to the emulator, so a boot stub stands in for it. `U1MBFLSH` writes the slot (verified in Altirra for AMIC and SST chips). APT through the U1MB's own PBI BIOS is unverified (its BIOS is not available). Setting the clock is implemented but cannot be checked in Altirra, whose DS1305 always reads the host time |
| Altirra | Standard cartridge and runtime | All suites above | None for the standard cartridge |
| IDE2.0PLUS (IDE Plus 2.0) | MAN, APT FDISK | BIOS 2.1 flashed by EOS, exported and booted; partitions, sector I/O, warm reset, `APT`, `MAN IDEPLUS` | Real hardware; the slave disk, the BIOS's ATR mounting and its SDX cartridge are not tested |
| Atari800 | Standard cartridge and runtime | XL, 130XE, PAL, Rambo 320K cases pass | Atari800 has no PBI hard disk model, so storage is tested in Altirra only |
| Incognito | MAN, APT FDISK | No image | Neither emulator models the Incognito, and its flash banking and SDX registers are not documented in this workspace |
| Incognito Colleen mode | MAN, APT FDISK | No image | As Incognito; in addition EOS targets the XL/XE OS, and Colleen mode runs the 400/800 OS |
| Turbo Freezer 2011 | MAN, APT FDISK | No image | No emulator model and no register documentation in this workspace |
| SIDE | MAN, APT FDISK | `EOS_SIDE.rom` (512 KiB flash image) boots from the SIDE's flash in Altirra: batch, `CAR:`, BASIC and back, warm reset; EOS's own CF driver serves the APT partitions as drives (DIR, TYPE, COPY, `APT`, `APT NEW`), `MAN SIDE` | Real hardware; EOS writes no SIDE flash itself (the SIDE's own loader does); up to 4 APT drives of 512-byte sectors; the SIDE's clock is not used |
| SIDE2, AVGCART | MAN, APT FDISK | `EOS_SIDE2.rom`: as SIDE, with the bank register at `$D5E1`; all the same tests pass | Real hardware; AVGCART in its SIDE2 mode (as Altirra runs it) is not tested apart |
| SIDE3 | MAN, APT FDISK | `EOS_SIDE3.rom` (8 MiB, EOS at `$780000` where the SIDE3 starts with its SDX switch on) boots in Altirra; EOS's own SD driver (SPI) serves the APT partitions as drives, with `APT` and `APT NEW` | Real hardware; the SIDE3's DMA, cartridge emulation and RAM are not used; with the SDX switch off the SIDE3 starts from `$000000`, where EOS is not |
| Maxflash 1 Mbit | — | Not possible as is | 128 KiB holds 16 banks; EOS uses 25 (9 code, 16 `CAR:`). It would need a reduced `CAR:` set |
| Maxflash 8 Mbit | MAN | `EOS.car` is this format; all Altirra suites run on it | Real hardware |
| Maxflash MyIDE+Flash | — | Not possible as is | A 128 KiB flash, as Maxflash 1 Mbit |
| MyIDE II RAM | — | Not built | EOS runs from the MyIDE II's flash (below); loading it into the MyIDE II's RAM is not done |
| MyIDE II ROM | MAN, APT FDISK | `EOS_MYIDE2.rom` (512 KiB flash image) boots in Altirra; EOS's own CF driver (`$D500`) serves the APT partitions, `APT` and `APT NEW` work | Real hardware; EOS writes no MyIDE II flash itself |
| SIC! | MAN | `EOS_SIC.car` boots, runs a batch, reads `CAR:`, survives a warm reset in Altirra | `MAN` page for SIC!; real hardware; EOS has no SIC! flasher |
| SIC!+ v2 1024k | MAN | `EOS_SICP.car` (first flash chip) as SIC! | As SIC! |
| SuperCart | MAN | No image | No emulator model and no register documentation in this workspace |
| intSDX128 | — | No image | An internal ROM replacement with its own banking; no emulator model or documentation here |
| intSDX128 flash | — | No image | As intSDX128 |

For targets marked MAN, EOS ships device-specific help: `MAN U1MB`,
`MAN IDEPLUS` and `MAN APT` exist; the other targets get pages with their
images. For targets marked APT, the `APT` command (on `CAR:`) partitions a disk
and edits its APT table through a BIOS that provides the physical disk
device `$20` with 512-byte sectors; it is verified with the IDE2.0PLUS BIOS
2.1 only. `APT INIT` writes a new table at sector 0 (refusing a sector 0 in
use without `/F`), `APT NEW` adds a partition of up to 65535 sectors after
the last one (checked against the disk's size from DEVINFO), `APT DEL`
removes an unmapped one. `APT` changes one table sector of a revision 0
table and keeps every other byte; it refuses tables kept in even bytes only
and mapping slots that continue past the first table sector, because those
layouts have not been tested against a BIOS, and it does not resize
partitions (that would move file system data). `FORMAT` remains
the command that makes the file system. `tools/apt.py` is the host-side
reference used to make test disks and to check `APT`'s output; it is not
part of EOS.

### Flashing

`U1MBFLSH` (EOS Toolkit disk) writes `EOS_U1MB.rom` into the U1MB SDX area.
It runs under EOS or SDX; the image is first read into 20 free extended
memory banks, because the running DOS may be the one being replaced. Then,
with the OS ROM switched out and interrupts off, it reads the flash chip's
ID (29F040 types: AMD, AMIC, Bright, Hynix, Macronix, 64 KiB sectors; SST
39SF040, 4 KiB sectors), erases only the sectors of `$00000-$4FFFF` (never
the whole chip), programs and compares every bank, and cold starts. The U1MB
BIOS, BASIC and OS (`$50000-$7FFFF`) are never addressed, so a failed write
leaves the U1MB setup able to start. Verified in Altirra (`make u1mbemu`):
both chip families written and the machine restarted into the new image,
also as a first installation (EOS from `EOS.car` with the U1MB's SDX off,
the SDX area empty; this assumes a U1MB does not pass its `$D5E0` write on
to the cartridge port) (running under EOS; under SDX 4.50 it loads and makes its checks, but
writing from SDX in the U1MB slot is untested),
the saved flash equal to the image in the SDX area and unchanged above it; a
write-protected flash stops before erasing and the old DOS still boots; too
few free banks are refused. Not verified on real hardware, and only for the
chips listed: an unknown chip ID stops before anything is erased.

The IDE2.0PLUS BIOS is written by its vendor's updater (`BIOS21.COM`), which
runs under EOS. EOS has no SIC! flasher: the SIC!'s flash write enable and
its chips have not been exercised in an emulator test yet.
