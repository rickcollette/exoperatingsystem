#!/usr/bin/env python3
"""Build the EOS maintenance disk: an SDFS image with what installing EOS
on a U1MB and setting up an IDE2.0PLUS needs.

usage: mkmaint.py out.atr

An EOS disk: EOS (from its cartridge or the U1MB slot) reads EOSSYS.SYS,
which turns on the clock driver and no RAM disk, so U1MBFLSH has its 20 free
extended banks, and EOSAUTO.BAT, which shows README.TXT. There are no SDX
startup files. EOS itself is never loaded from disk: its cartridge starts
it and tells the OS not to boot a disk.

  EOS_U1MB.ROM, EOS_U1MB.MD5   the U1MB slot image and its MD5
  U1MBFLSH U1MBCHK             write / check the image (EOS Toolkit)
  APT FORMAT                   partition, make file systems (EOS's CAR:)
  MD5 MEMINFO MACH             check files, memory, the machine (Toolkit)
  MAN/*.MAN                    their pages (TYPE MAN>APT.MAN)
  IDEPLUS/                     the IDE2.0PLUS vendor utilities, when the
                               local media/IDE2.0PLUS/ directory has them
"""
import hashlib
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import emu  # noqa: E402

B = ROOT / 'build'
SIZE = 737280                     # 720 KiB
TOOLKIT = ['U1MBFLSH', 'U1MBCHK', 'MD5', 'MEMINFO', 'MACH']
CARCMD = ['APT', 'FORMAT']
PAGES = {'U1MBFLSH': ROOT / 'toolkit/man/U1MBFLSH.txt', 'U1MBCHK': ROOT / 'toolkit/man/U1MBCHK.txt',
         'MD5': ROOT / 'toolkit/man/MD5.txt', 'MEMINFO': ROOT / 'toolkit/man/MEMINFO.txt',
         'MACH': ROOT / 'toolkit/man/MACH.txt'}
CARPAGES = ['APT', 'FORMAT', 'IDEPLUS', 'U1MB']
VENDOR = ['BIOS21.COM', 'BIOSUPD.TXT', 'BIOS21.MD5', 'DEVINFO.COM', 'DEVINFO.TXT',
          'DISKINFO.COM', 'DISKINFO.TXT', 'MBRVIEW.COM', 'MBRVIEW.TXT', 'XMENU.COM', 'XMENU.TXT',
          'RECOVER.BIN', 'RECOVER.TXT']

README = '''EOS maintenance disk
--------------------
EOSSYS.SYS starts no RAM disk, so
U1MBFLSH has room for the image.

First install, no SDX needed: U1MB
setup SDX off, EOS.car cartridge in.

1 Check the image:
  U1MBCHK EOS_U1MB.ROM
  MD5 EOS_U1MB.ROM  (= EOS_U1MB.MD5)
2 Write it into the U1MB SDX area
  (U1MB setup: flash writes allowed):
  U1MBFLSH EOS_U1MB.ROM
  then: cartridge out, U1MB setup SDX
  on (320K, GOS off): EOS starts.
3 Partition the IDE2.0PLUS disk:
  APT INIT   (APT INIT /F: in use)
  APT NEW 32M      (each partition)
  APT MAP D2: 1    (each drive)
  restart the computer, then
  FORMAT /QQ D2: NAME
4 IDE2.0PLUS BIOS 2.1: IDEPLUS>BIOS21
  (when the disk has it)

Help: TYPE MAN>U1MBFLSH.MAN and so on.
The full test: docs/HARDWARE_TEST.md'''


def ascii_lines(text):
    return emu.atascii(text.rstrip('\n').split('\n'))


def main():
    out = Path(sys.argv[1]).resolve()
    rom = B / 'EOS_U1MB.rom'
    need = [rom] + [B / 'etk' / (t + '.COM') for t in TOOLKIT] + \
           [B / 'eos' / 'car' / (c + '.COM') for c in CARCMD]
    missing = [str(p) for p in need if not p.exists()]
    if missing:
        sys.exit('mkmaint: missing %s (make u1mb eos toolkit)' % ', '.join(missing))
    with tempfile.TemporaryDirectory(dir=B) as tmp:
        tree = Path(tmp)
        files = []

        def put(name, data):
            (tree / name).parent.mkdir(parents=True, exist_ok=True)
            (tree / name).write_bytes(data)
            files.append(name)

        put('README.TXT', ascii_lines(README))
        put('EOSSYS.SYS', ascii_lines('DEVICE RTIME8'))           # EOS: clock, no RAM disk
        put('EOSAUTO.BAT', ascii_lines('TYPE README.TXT'))
        data = rom.read_bytes()
        put('EOS_U1MB.ROM', data)
        put('EOS_U1MB.MD5', ascii_lines(hashlib.md5(data).hexdigest().upper() + '  EOS_U1MB.ROM'))
        for t in TOOLKIT:
            put(t + '.COM', (B / 'etk' / (t + '.COM')).read_bytes())
        for c in CARCMD:
            put(c + '.COM', (B / 'eos' / 'car' / (c + '.COM')).read_bytes())
        man = []
        for name, src in PAGES.items():
            if src.exists():
                man.append(('MAN/%s.MAN' % name, ascii_lines(src.read_text())))
        for name in CARPAGES:
            src = ROOT / 'eos' / 'carfiles' / (name + '.MAN')
            man.append(('MAN/%s.MAN' % name, src.read_bytes()))
        files.append('MAN')
        for name, data in man:
            put(name, data)
        vend = ROOT / 'media' / 'IDE2.0PLUS'
        have = [v for v in VENDOR if (vend / v).exists()]
        if have:
            files.append('IDEPLUS')
            for v in have:
                put('IDEPLUS/' + v, (vend / v).read_bytes())
        emu.mkatr(out, tree, files, SIZE)
    print('mkmaint: %s, %d files%s' % (out, len(files),
          ', with the IDE2.0PLUS vendor files' if have else ''))


if __name__ == '__main__':
    main()
