#!/usr/bin/env python3
"""Unpack the SDX Toolkit disk (toolkit.atr) for the tests: its files to
build/tk/, and to build/tkx/ the same with each NAME.ARC unpacked into a
directory NAME/ (tools/unarc.py).

usage: tkunpack.py [media/toolkit.atr [builddir]]
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import sdfs  # noqa: E402
import unarc  # noqa: E402


def main():
    atr = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'media' / 'toolkit.atr'
    build = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / 'build'
    n = 0
    for path, e in sdfs.Volume(str(atr)).check():
        data = e.get('data')
        if data is None:                       # a directory
            continue
        rel = Path(path.lstrip('/'))
        (build / 'tk' / rel).parent.mkdir(parents=True, exist_ok=True)
        (build / 'tk' / rel).write_bytes(data)
        if rel.suffix.upper() == '.ARC':
            dest = build / 'tkx' / rel.parent / rel.stem
            dest.mkdir(parents=True, exist_ok=True)
            for name, member in unarc.members(data):
                (dest / name).write_bytes(member)
                n += 1
        else:
            (build / 'tkx' / rel).parent.mkdir(parents=True, exist_ok=True)
            (build / 'tkx' / rel).write_bytes(data)
            n += 1
    print('tkunpack: %d files in %s' % (n, build / 'tkx'))


if __name__ == '__main__':
    main()
