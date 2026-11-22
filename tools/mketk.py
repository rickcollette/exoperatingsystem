#!/usr/bin/env python3
"""The EOS Toolkit disk: build/EOSTK.atr, an EOSFS v2 double-density disk
(720 x 256) with EOS's own utilities (build/etk/NAME.COM) in the main
directory and their man pages (toolkit/man/NAME.txt, made ATASCII as CAR:'s
are by tools/mkmanpages.py) under /man.

usage: mketk.py [out.atr]
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import mkmanpages  # noqa: E402
import sdfs  # noqa: E402


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'build' / 'EOSTK.atr'
    programs = sorted((ROOT / 'build' / 'etk').glob('*.COM'))
    pages = sorted((ROOT / 'toolkit' / 'man').glob('*.txt'))
    files = {com.name.lower(): com.read_bytes() for com in programs}
    files.update({
        'man/' + txt.stem.lower() + '.man':
            mkmanpages.convert(txt.read_text(), txt.name)
        for txt in pages
    })
    sdfs.build(out, 720, 256, files, volname='EOS', eosfs=True)
    volume = sdfs.Volume(out)
    volume.check()
    if not volume.eosfs or volume.errors:
        raise SystemExit('mketk: invalid EOSFS output: %s' % volume.errors)
    print('mketk: %s, %d programs, %d man pages' % (
        out, len(programs), len(pages)))


if __name__ == '__main__':
    main()
