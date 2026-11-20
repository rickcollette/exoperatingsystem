#!/usr/bin/env python3
"""The EOS Toolkit disk: build/EOSTK.atr, an SDFS double density disk (720 x
256) with EOS's own utilities (build/etk/NAME.COM) in the main directory and
their man pages (toolkit/man/NAME.txt, made ATASCII as CAR:'s are by
tools/mkmanpages.py) in MAN>.

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
    files = {}
    for com in sorted((ROOT / 'build' / 'etk').glob('*.COM')):
        files[com.name] = com.read_bytes()
    for txt in sorted((ROOT / 'toolkit' / 'man').glob('*.txt')):
        files['MAN/%s.MAN' % txt.stem] = mkmanpages.convert(txt.read_text(), txt.name)
    sdfs.build(str(out), 720, 256, files)
    print('mketk: %s, %d programs, %d man pages' % (
        out, sum('/' not in f for f in files), sum('/' in f for f in files)))


if __name__ == '__main__':
    main()
