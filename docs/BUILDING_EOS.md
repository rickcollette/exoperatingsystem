# Building EOS

This document covers building, testing, and maintaining the EOS source tree.
For installing and using a built cartridge, see the [EOS User Manual](USER_MANUAL.md).

## Requirements

Building requires MADS and Python 3:

- `mads` on `PATH`, or set `MADS=/path/to/mads`.
- `python3` on `PATH`, or set `PYTHON=/path/to/python3`.

The Altirra tests run under Wine with Xvfb. They require Wine,
`xvfb-run`, `xdotool`, ImageMagick's `import`, an Altirra executable, and an
SDX 4.50 cartridge image. Set `ALTIRRA_EXE` and `SDX_CART` as needed; defaults
are defined in `tools/emu.py`. Some tests need local disk images and vendor
files that are not in git: they go in `media/` (the list is in README.md,
"Test media"), the SDX Toolkit disk `media/toolkit.atr` among them.

## Build

From the repository root:

```sh
make
```

This builds the AtariMax cartridge at `build/EOS.car`, the raw 320 KiB U1MB
SDX-slot image at `build/EOS_U1MB.rom`, the SIC! images, the SIDE, SIDE2,
MyIDE II and SIDE3 flash images (`build/EOS_SIDE.rom` ...), EOS test programs,
the EOS Toolkit disk at `build/EOSTK.atr` and the maintenance disk
`build/EOSMAINT.atr`.

Common targets:

```sh
make eos        # AtariMax cartridge (build/EOS.car) and EOS test programs
make u1mb       # U1MB SDX-slot image (build/EOS_U1MB.rom)
make sic        # SIC! and SIC!+ images (build/EOS_SIC.car, EOS_SICP.car)
make flash      # SIDE, SIDE2, MyIDE II, SIDE3 flash images (build/EOS_*.rom)
make sidetest   # those four booted in Altirra, their CF/SD cards' partitions
make u1mbtest   # U1MB image layout and bank-select checks (host)
make apttest    # tools/apt.py, the host-side APT reference (host)
make u1mbemu    # U1MB slot boot; U1MBFLSH writes, refuses, write protection
make carttest   # boot EOS.car, EOS_SIC.car, EOS_SICP.car in Altirra
make maint      # build/EOSMAINT.atr, the EOS maintenance disk (tools/mkmaint.py)
make eosfsboot  # native EOSFS disk loader (build/EOSFSBOOT.bin)
make eosfsboottest # build/marker/extent/XEX checks for that loader
make release    # clean build, DISTRIBUTE/, tag and GitHub release
make mainttest  # EOS started from it, every program on it run (tools/maint_test.py)
make handbook   # docs/EOS_HANDBOOK.md: WHY, USER_MANUAL, EOS_COMPATABILITY,
                # HARDWARE_TEST, EOSFS, BENCHMARKS in one book (tools/mkhandbook.py)
make handbook-pdf # and build/EOS_HANDBOOK.pdf (pandoc, pdflatex)
make ideplusemu # Altirra start and warm reset with an erased IDE2.0PLUS
make ideplustest # IDE2.0PLUS: BIOS 2.1 flash/export, partitions, APT, partitioning
make helpemu    # MAN U1MB, MAN IDEPLUS, MAN APT on screen
make atari800test # Atari800: XL, 130XE, PAL, Rambo runtime cases
make toolkit    # Toolkit programs and build/EOSTK.atr
make tkx        # unpack the local SDX Toolkit test disk into build/
make clean      # remove generated build files
```

Bootable EOSFS image:

```sh
python3 tools/eosfs.py build build/MYBOOT.atr 720 256 tree EOS --boot DOS/EOS.SYS
```

`DOS/EOS.SYS` is relative to `tree`. The builder writes `EOSFSBOOT.bin` to
sectors 1-3 and records the file's first extent list in the boot field. Boot
images may use 128 or 256 byte sectors. The stock OS cannot boot 512 byte
sectors.

### Release

Every build gets the EOS version from the repository's `VERSION` file.
`make release` accepts a clean commit on `main`. It checks the Git author,
committer and GitHub login, rebuilds everything, replaces `DISTRIBUTE/`, writes
SHA-256 checksums, pushes `main` and the matching `vX.Y` tag, then creates the
release at `rickcollette/exoperatingsystem`. Git must use
`rickcollette <rcollet@gmail.com>` and `gh` must be logged in as
`rickcollette`.

After the release succeeds, the command advances `VERSION` and commits it for
the next build. The minor version runs through 99 before rolling over: `0.98`
to `0.99`, `0.99` to `1.0`, and `1.99` to `2.0`.

`python3 tools/combo_test.py` runs the U1MB + IDE2.0PLUS machine (EOS from
the U1MB slot, U1MB clock and RAM disk, IDE storage); it needs
`build/ideplus/ide-main.rom` from `make ideplustest` first.

### Bank register variants

The cartridge banks are assembled once per image format. Only `setbank` in
`eos/kernel.asm` and the bank tail in `eos/tail.icl` differ: the AtariMax
image writes to `$D500+n`; `-D:U1MB=1` and `-D:SIC=1` define `BANKLATCH`
(`$D5E0`, `$D500`) and write the bank number to it, with `CARTOFF` the value
that switches the cartridge off (`$80`, `$40`). `tools/mku1mb.py` packs a raw
320 KiB slot image; `tools/mksic.py` puts EOS bank n in the upper half of
16 KiB SIC! bank n. A new data-latch target needs its latch and off value in
`eos/equ.icl`, a packer and a case in `tools/carts_test.py`.

### Hardware emulator tests

- `tools/ideplus_test.py`: `flash` runs `media/IDE2.0PLUS/BIOS21.COM` under EOS on an
  erased device, answering each question from a breakpoint on the updater's
  key input, then saves the flash through Altirra's `.autotest_cmd
  System.SaveFirmwareIDEMain` (Altirra started with `/autotest`; the save
  dialog is filled with xdotool). `storage` and `apt` boot that image with a
  disposable APT disk made by `tools/apt.py` and use `tests/eos/IDET.asm`.
- `tools/u1mb_test.py`: composes the 512 KiB U1MB flash from
  `EOS_U1MB.rom`, `tests/u1mb/boot.asm` (a stub, not the U1MB BIOS) and
  AltirraOS, assembled with MADS from `ALTIRRA_SRC` (default
  `../ALTIRRA_ORIGINAL`).
- `tools/emu.py` `Session` options: `firmware={'kmkjzide2'|'u1mb': path}`
  writes Altirra firmware entries and defaults into the profile;
  `ultimate1mb=True` also selects Altirra's global profile (the stock XL/XE
  profile would hide the U1MB setting); `fastboot=False` is needed for PBI
  hard disks (fast boot answers empty drive slots before the OS polls PBI
  devices); `extra_args` passes switches such as `/autotest`.
- Check device state with Altirra's debugger (`.ultimate`, `.kmkjzide`)
  rather than trusting profile keys.

## Test suites

`make quick` runs a small smoke set. The larger suites are:

- `make eostest`: EOS filesystem, loader, command processor, devices, and
  kernel behavior on EOS.
- `make eostest-eosfs`: the EOS tests with EOSFS volumes.
- `make cartest`: command and device probes compared with SDX reference output.
- `make fmttest`: formatter geometry and filesystem cases.
- `make eosall`: EOS within itself across memory, SIO, and disk configurations.
- `make mutineer`: Mutineer BBS compatibility matrix.
- `make xbtest`: exBASIC examples in `tests/exbasic/`; needs the exBASIC
  compiler (`EXBASIC=/path/to/exbasic`).
- `make tktest`: EOS Toolkit utilities compared with SDX Toolkit equivalents;
  run `make tkx` first and provide `media/toolkit.atr`.

The first emulator run creates the Wine prefix at `build/wine`. Parallel test
workers copy it; run a test once on its own before increasing `JOBS` if the
prefix has not yet been initialized. Set `JOBS=n` to choose parallel workers.
SDX reference output is cached in `build/sdx-cache`; `EOS_FRESH=1` reruns SDX
to refresh the oracle.

## Source tree

- `eos/`: cartridge banks, kernel, filesystem, command processor, CAR:
  commands, drivers, and shipped files.
- `eos/symbols.txt`: exported program symbols and their implementation module.
- `eos/carfiles/man/`: source text for EOS command help; packed CAR: copies
  are in `eos/carfiles/*.MAN`.
- `toolkit/`: EOS Toolkit assembly programs and `toolkit/man/` reference pages.
- `tests/eos/`: relocatable binaries used by emulator tests.
- `tests/exbasic/`: exBASIC integration examples.
- `tests/u1mb/boot.asm`: the U1MB boot stub used by `tools/u1mb_test.py`.
- `tests/carref/`: recorded SDX command output used by CAR: comparisons.
- `tools/`: assemblers/helpers, filesystem image utilities, and test runners.
- `docs/`: user, programming, filesystem, compatibility, and benchmark guides;
  `EOS_HANDBOOK.md` is generated from them (`make handbook`): edit the sources.
  The User Manual's command pages are copies of the MAN sources; `make
  handbook` warns when they differ.

## Cartridge build flow

The kernel is assembled first. Its labels are translated into an include used
by the separate cartridge-bank assemblies. The bank binaries and CAR: files
are then packed into `build/EOS.car` by the Python build tools. The Makefile
contains the authoritative dependencies and bank list. Edit the relevant
source and use `make` to rebuild; avoid editing generated files under
`build/`.

The Toolkit is assembled as relocatable SDX-style programs and packed with
its manual pages into `build/EOSTK.atr`. Command help source text is kept in
the corresponding `man/` directories. Update the source documentation and
the generated CAR: resource if the build flow for that resource requires it.
New EOS-authored hardware image validation or flashing utilities belong in
`toolkit/` with a matching `toolkit/man/` page; the existing Makefile pattern
automatically includes them on the Toolkit ATR. `U1MBCHK` validates the raw
U1MB image size and shared bank reset tail; `U1MBFLSH` writes it into the
U1MB SDX area (tests: `tools/u1mb_test.py` flash-A29040, flash-SST39SF040,
refuse, protected). Relocatable programs must not use `#<label`/`#>label`
for their own labels (the loader does not fix such bytes): keep the address
in a `dta a(label)` word and load it from there. The `APT` command is `eos/carcmd/APT.asm` (on `CAR:`); its
host-side counterpart `tools/apt.py` makes test disks and is the reference
its output is compared with. The local `media/IDE2.0PLUS/` directory holds the
KMK/DLT BIOS 2.1 updater and the device's protocol notes (device `$20`,
XDCB, DISKINFO) that `APT` and `IDET` follow.

## Programming and example workflow

The [Programming for EOS](USER_MANUAL.md#11-programming-for-eos) section
documents application formats, library entry points, and small examples.
For program changes, add a focused example or test under `tests/eos/` or
`tests/exbasic/`, then run the matching suite. Use the host simulation and
Altirra workflows exposed by the Makefile and `tools/`; the test runner is
documented in the repository README.
