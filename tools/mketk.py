#!/usr/bin/env python3
"""The EOS Toolkit disk: build/EOSTK.atr, an SDFS double density disk (720 x
256) with EOS's own utilities (build/etk/NAME.COM) in the main directory and
their man pages (toolkit/man/NAME.txt, made ATASCII as CAR:'s are by
tools/mkmanpages.py) in MAN>.

usage: mketk.py [out.atr]
"""
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import atrtool  # noqa: E402
import mkmanpages  # noqa: E402


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'build' / 'EOSTK.atr'
    programs = sorted((ROOT / 'build' / 'etk').glob('*.COM'))
    pages = sorted((ROOT / 'toolkit' / 'man').glob('*.txt'))
    with tempfile.TemporaryDirectory(dir=ROOT / 'build') as tmp:
        tree = Path(tmp)
        (tree / 'MAN').mkdir()
        for com in programs:
            (tree / com.name).write_bytes(com.read_bytes())
        for txt in pages:
            (tree / 'MAN' / (txt.stem + '.MAN')).write_bytes(
                mkmanpages.convert(txt.read_text(), txt.name))
        files = [com.name for com in programs] + ['MAN']
        atrtool.create(out, tree, files, sectors=720, sector_size=256,
                       profile='bwdos', volume='EOS')
    print('mketk: %s, %d programs, %d man pages' % (
        out, len(programs), len(pages)))


if __name__ == '__main__':
    main()
