# EOS: Extendable Operating System

EOS is an MIT-licensed DOS for the Atari 8-bit on an AtariMax cartridge,
a drop-in for SpartaDOS X 4.5. It runs SpartaDOS X and BW-DOS programs and
disks, reads and writes Atari DOS 2.0S/2.5 disks, and has a native file
system of its own (EOSFS, `docs/EOSFS.md`). See `docs/WHY.md`,
`docs/EOS_COMPATABILITY.md`, and `docs/BENCHMARKS.md` for how it compares
with SpartaDOS X.

For installation, first boot, configuration, disk operations, and day-to-day
use, see the [EOS User Manual](docs/USER_MANUAL.md). Application developers
can start with its programming section; source builds and maintenance are in
[Building EOS](docs/BUILDING_EOS.md). All documents in one book, for PDF:
[EOS Handbook](docs/EOS_HANDBOOK.md) (`make handbook-pdf`).

## Building

You need MADS (`mads` on the path, or `MADS=...`) and Python 3.

    make            # every image, the test programs, the EOS Toolkit, the
                    # maintenance disk
    make u1mb       # build/EOS_U1MB.rom (raw 320 KiB U1MB SDX-slot image)
    make sic        # build/EOS_SIC.car, EOS_SICP.car (SIC! 512K, SIC!+ 1024K)
    make flash      # build/EOS_SIDE.rom, EOS_SIDE2.rom, EOS_MYIDE2.rom (512 KiB)
                    # and EOS_SIDE3.rom (8 MiB): raw flash images
    make maint      # build/EOSMAINT.atr, the SDX-free maintenance disk
    make eosfsboot  # build/EOSFSBOOT.bin, the native EOSFS disk boot loader
    make release    # clean build and GitHub release for VERSION
    make handbook-pdf # docs/EOS_HANDBOOK.md and build/EOS_HANDBOOK.pdf

Bootable EOSFS image from a directory tree:

    python3 tools/eosfs.py build build/MYBOOT.atr 720 256 tree EOS --boot DOS/EOS.SYS

The `--boot` path is relative to `tree`. Boot images may use 128 or 256 byte
sectors; the stock OS cannot boot 512 byte sectors.

Every build reads its EOS version from `VERSION`. `make release` requires a
clean commit on `main`, the
`rickcollette/exoperatingsystem` origin, Git identity
`rickcollette <rcollet@gmail.com>`, and a `gh` login for `rickcollette`. It
rebuilds everything, replaces `DISTRIBUTE/`, writes `SHA256SUMS.txt`, pushes
`main` and the matching `vX.Y` tag, and creates the GitHub release. After the
release succeeds it advances `VERSION` for the next build and commits that
change. Versions run from `0.0` through `0.99`, then `1.0` through `1.99`,
and so on.

## Testing

    make eostest    # EOS against SDX in Altirra (EOS_EOSFS=1: on EOSFS)
    make cartest    # the CAR: commands against SDX's recorded output
    make fmttest    # FORMAT: every size, EOSFS, the skews
    make tktest     # the EOS Toolkit against the SDX Toolkit
    make sidetest   # SIDE, SIDE2, MyIDE II, SIDE3 and their CF/SD cards
    make carttest   # EOS.car and the SIC! images
    make u1mbemu    # EOS_U1MB.rom from the U1MB SDX slot; U1MBFLSH writing it
    make ideplustest # IDE2.0PLUS BIOS 2.1 flash/export, partitions, APT
    make mainttest  # the maintenance disk
    make atari800test # Atari800: XL, 130XE, PAL, Rambo runtime cases
    make u1mbtest apttest # host-side checks
    make xbtest     # exBASIC programs (needs EXBASIC=path/to/exbasic)
    make eosall     # every configuration: 320K, no SIO patch, SD/ED/QD
    python3 tools/bench.py    # the benchmarks (docs/BENCHMARKS.md: tools/benchmd.py)

The first emulator run creates the Wine prefix `build/wine`. Parallel workers
(`JOBS=n`) copy it, so run one test on its own first. `build/` holds only what
the build and the tests make: deleting it loses nothing but SDX's recorded
results (`build/sdx-cache`, which saves rerunning SDX).

The Atari800 tests use Atari800, `xvfb-run`, ImageMagick, and Tesseract.
What the hardware emulator tests verify is in
[EOS Compatibility](docs/EOS_COMPATABILITY.md). No image has been tested on
real hardware yet ([Hardware Test](docs/HARDWARE_TEST.md)).

## License

EOS is released under the [MIT License](LICENSE).

## Contributing

Do what you like with it. If you have an idea or make a useful change, send
it back if you can. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Test media

Disk images and vendor files the tests use live in `media/`, which is not in
git (`.gitignore`); put them there yourself:

| File | Used by | What it is |
| --- | --- | --- |
| `toolkit.atr` | `make tkx`, `tktest`, `cartest` | the SpartaDOS X Toolkit disk: EOS runs its programs to show it runs SDX software |
| `dossrc-w.atr`, `dossrc_a-w.atr` | `eostest` (dos2-*) | Atari DOS 2 disks (double, single density) |
| `b1440_512.atr` | `fmttest` (f-user720k) | an SDFS 1440 x 512 disk to format again |
| `atari-mutineer-v1.4.1-16mb-all-drivers.atr` | `make mutineer` | the Atari Mutineer BBS |
| `Hacker_1985_Activision.atr`, the two Montezuma's Revenge disks, `Fart_19xx_Starace_Thomas_J._US_PD_BASIC.atr` | `tools/game_test.py` | boot disks and a BASIC game |
| `DOS25.ATR`, `MYDOS453.ATR` | the BASIC benchmark | Atari DOS 2.5 (Page 6 public-domain library) and MyDOS 4.53/4 (tuxpaint.org/ftp/atari/starters) boot disks |
| `IDE2.0PLUS/` | `ideplustest`, `make maint` | the KMK/DLT IDE2.0PLUS files: `BIOS21.COM` and its utilities |

A test whose media is missing fails with the file's name.

## Layout

- `eos/`: the cartridge banks (`kernel.asm`, `fms.asm`, `cp.asm`, ...), the
  CAR: commands (`carcmd/`), drivers (`carsys/`), overlays (`carovl/`) and
  files (`carfiles/`); the CF and SD drivers (`ide.icl`, `sd.icl`) and the
  second-level cache (`l2.icl`).
- `eos/xep80/`: Altirra's XEP80 handler by Avery Lee, with its own
  all-permissive notices (see its README).
- `toolkit/`: the EOS Toolkit, EOS's own utilities. These are SpartaDOS X
  Toolkit programs written anew (LS, DU, CRC32, MD5, XT, ...) and small
  Unix-like tools (CAT, HEAD, TAIL, STRINGS, SEQ, WHICH, BASENAME, DIRNAME).
  `toolkit/man/` has their man pages, and `make tktest` checks each one
  against the SDX program it replaces.
- `tests/eos/`: test programs; `tests/exbasic/`: exBASIC programs (make
  xbtest); `tests/carref/`: SDX's output for the CAR: command probes;
  `tests/u1mb/`: the U1MB boot stub.
- `tools/`: build tools, the emulator test suites, and host tools
  (`sdfs.py`, `eosfs.py`, `dos2.py`, `apt.py`: disk images on the PC;
  `dis6502.py`, `basic_list.py`: an SDX binary's disassembly, a BASIC
  program's listing).
- `docs/`: the user's documents (the handbook is made from them).
- `PROGRESS.md`: the record of the work; `docs/history/`: the original plan
  (`EOS_PLAN.md`) and the task prompts it was built from.
