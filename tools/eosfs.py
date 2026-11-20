#!/usr/bin/env python3
"""Build and inspect EOSFS images.

usage: eosfs.py build image.atr sectors seclen dir [volname] [--boot file]
       eosfs.py check|ls|extract ...      (as tools/sdfs.py)

--boot names the boot file inside dir. The default loader is
build/eos/EOSFSBOOT.bin.
"""
import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sdfs  # noqa: E402


def main():
    if sys.argv[1] != 'build':
        sys.exit(sdfs.main())
    p = argparse.ArgumentParser(description='build an EOSFS image')
    p.add_argument('command', choices=['build'])
    p.add_argument('image')
    p.add_argument('sectors', type=int)
    p.add_argument('sector_length', type=int, choices=(128, 256, 512))
    p.add_argument('directory')
    p.add_argument('volume', nargs='?', default='EOS')
    p.add_argument('--boot', metavar='FILE', help='file in the image to boot')
    p.add_argument('--loader', type=Path, help='boot loader override')
    a = p.parse_args()
    path, total, seclen, src = a.image, a.sectors, a.sector_length, a.directory
    files = {}
    for root, _, names in os.walk(src):
        for n in sorted(names):
            full = os.path.join(root, n)
            files[os.path.relpath(full, src).replace(os.sep, '/')] = open(full, 'rb').read()
    loader = a.loader
    if loader is not None and not a.boot:
        p.error('--loader requires --boot')
    if a.boot and loader is None:
        loader = Path(__file__).resolve().parents[1] / 'build/eos/EOSFSBOOT.bin'
    if loader is not None and not loader.exists():
        p.error('%s not found; run `make eosfsboot` or use --loader' % loader)
    sdfs.build(path, total, seclen, files, a.volume, eosfs=True, boot=a.boot,
               bootcode=loader.read_bytes() if loader is not None else None)


if __name__ == '__main__':
    main()
