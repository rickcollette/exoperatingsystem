# EOS Hardware Test: Ultimate 1MB with an IDE2.0PLUS

This checklist takes the machine from SDX to EOS, with no SDX involved:
EOS in the U1MB SDX slot, the U1MB clock and RAM disk, and an IDE2.0PLUS
for storage. Everything needed is on one EOS disk, `DISTRIBUTE/EOSMAINT.atr`
(the maintenance disk). Each step says what the emulator showed, so a
difference on real hardware stands out. Note the result of every step (OK,
or what appeared instead); a photo of the screen is enough.

You need: the Atari with the U1MB and the IDE2.0PLUS, a Maxflash 8 Mbit
(1 MiB) cartridge holding `DISTRIBUTE/EOS.car` (or another way to start EOS
once), a CF card or disk you can erase, and a disk drive or SIO2PC/FujiNet
for `EOSMAINT.atr`.

Nothing in steps 1-3 writes anything. Step 4 replaces what is in the U1MB's
SDX area (SDX); step 7 erases the CF card.

## The maintenance disk

`EOSMAINT.atr` is an EOS disk: EOS reads its `EOSSYS.SYS` (the clock
driver, no RAM disk, so the flasher has room for the image) and
`EOSAUTO.BAT` (shows `README.TXT`). It holds:

| File | Use |
| --- | --- |
| `EOS_U1MB.ROM`, `EOS_U1MB.MD5` | the U1MB slot image and its MD5 |
| `U1MBFLSH.COM`, `U1MBCHK.COM` | write / check the image |
| `APT.COM`, `FORMAT.COM` | partition the hard disk, make file systems |
| `MD5.COM`, `MEMINFO.COM`, `MACH.COM` | check files, memory, the machine |
| `MAN/*.MAN` | their help pages: `TYPE MAN>APT.MAN` |
| `IDEPLUS/` | the IDE2.0PLUS utilities (BIOS 2.1 updater and more), when they were available at build time |

## 1. Record the machine

- U1MB firmware version (shown in its setup), and its memory size setting.
- U1MB settings for SDX, PBI BIOS (on/off, ID), flash write protection.
- IDE2.0PLUS revision, BIOS version (its setup screen title), PBI ID, and its
  own SDX cartridge setting.

The U1MB PBI BIOS and the IDE2.0PLUS must not share a PBI ID; if they do,
turn the U1MB PBI BIOS off for this test. Turn the IDE2.0PLUS's own SDX
cartridge off.

## 2. Start EOS from the cartridge

In the U1MB setup: SDX off (so the cartridge port is used), memory 1 MB,
flash writes allowed. Insert the Maxflash cartridge with `EOS.car`, put
`EOSMAINT.atr` in D1:, switch on.

Expected: `EOS 0.1 Extendable Operating System`, the README, and the `D1:`
prompt; no `X Disk O` RAM disk (`DIR O:` gives an error).

## 3. Check the image and the flasher (read only)

    U1MBCHK EOS_U1MB.ROM
    MD5 EOS_U1MB.ROM
    TYPE EOS_U1MB.MD5

Expected: `U1MB image: 40 banks, common reset tail OK`, and the two MD5
values equal. Then `U1MBFLSH EOS_U1MB.ROM` and answer `N`: `Not written.`

## 4. Write EOS into the SDX area

    U1MBFLSH EOS_U1MB.ROM

Answer `Y`. The bottom line of the screen shows `reading the flash chip
ID`, `erasing`, then `Writing bank nn of 40`; then the computer restarts,
now from the U1MB's SDX area. In the emulator this whole step, started from
`EOS.car` exactly like this, ended in the slot's EOS. Note the time it took.

If it stops with `Unknown or protected flash: not written`, nothing was
erased: check the U1MB's flash write setting (and whether its SDX module is
enabled), note the message, press RESET. If it stops with `... FAILED`,
note the message and press RESET: the U1MB setup still starts and you can
run step 4 again from the cartridge.

Then switch off, remove the cartridge, set SDX on (320 KiB, GOS off) in the
U1MB setup, and switch on with `EOSMAINT.atr` in D1:. Expected: EOS starts
from the slot. Press RESET once: EOS starts again.

The emulator's U1MB keeps the cartridge working while its SDX register is
written; if on real hardware the cartridge EOS does not start in step 2
with SDX off, note it: the U1MB may pass that register write to the
cartridge.

## 5. Clock and RAM disk

The maintenance disk's `EOSSYS.SYS` starts no RAM disk. Remove the disk
(or use one without `EOSSYS.SYS`) and restart for EOS's defaults:

- `DATE` and `TIME` (press Return at each question): the U1MB's date and
  time; no `R-Time 8 not present` line at start.
- `TIME` and enter a new time; switch off, wait a minute, switch on, `TIME`:
  the set time moved on (this sets the U1MB clock, not checkable in the
  emulator).
- `DIR O:`: `X Disk O` with about 3770 free sectors on a 1 MB U1MB.
- `MEM`: note the output.

## 6. IDE2.0PLUS BIOS (only if it is older than 2.1)

With `EOSMAINT.atr` in D1: `IDEPLUS>BIOS21`, answer `Y` to its questions,
then switch off for ten seconds. In the emulator EOS ran this on an erased
device and the result served partitions.

## 7. Partition the CF card (erases it)

With `EOSMAINT.atr` in D1:

    APT

Expected on a blank card: `No APT table on unit 1`. On a card with data
(a PC FAT card), use `APT INIT /F`.

    APT INIT
    APT NEW 32M
    APT NEW 32M
    APT MAP D2: 1
    APT MAP D3: 2
    APT

Answer `Y` each time; each should end with `Table written and read back`.
The last `APT` lists both partitions and the two mappings. Switch the
computer off and on (the BIOS reads the table when it starts), then:

    FORMAT /QQ D2: DISK1
    FORMAT /QQ D3: DISK2
    DIR D2:
    DIR D3:

Expected: empty directories, `DISK1`/`DISK2`, about 65500 free sectors each.

## 8. Use the drives

    COPY CAR:ALIASES.INI D2:A.TXT
    COPY D2:A.TXT O:B.TXT
    COPY O:B.TXT D3:C.TXT
    TYPE D3:C.TXT
    DIR D2:

(`O:` needs the RAM disk: start without the maintenance disk in D1:.)
Files carry the
U1MB clock's date. Press RESET, then `TYPE D3:C.TXT` and `DIR O:` again:
both still there. Switch off and on: `DIR D2:` and `DIR D3:` still show the
files.

## 9. Report

Send the notes from each step. For anything that differs, the exact
message and what was on the screen before it help most.
