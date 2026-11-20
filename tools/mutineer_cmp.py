#!/usr/bin/env python3
"""Compare the Mutineer disk after an SDX run with the disk after an EOS run
of the same scenario (tools/mutineer_test.py): which files differ. Dates and
times written into the files (the BBS stamps messages and callers with the
clock) are masked: digits in DD/DD/DD and DD:DD:DD patterns.

usage: mutineer_cmp.py SDX.atr EOS.atr      exit 1 when files differ
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sdfs  # noqa: E402

STAMP = re.compile(rb'\d\d[/:]\d\d[/:]\d\d(\d\d)?')


def tree(atr):
    v = sdfs.Volume(str(atr))
    out = {}
    for p, e in v.walk():
        if 'data' in e:
            out[p] = e['data']
    return out


def mask(b):
    return STAMP.sub(lambda m: b'#' * len(m.group(0)), b)


def main():
    a, b = tree(sys.argv[1]), tree(sys.argv[2])
    diff = 0
    for p in sorted(set(a) | set(b)):
        if p not in a or p not in b:
            print('%-40s only on %s' % (p, 'SDX' if p in a else 'EOS'))
            diff += 1
        elif mask(a[p]) != mask(b[p]):
            print('%-40s differs (%d / %d bytes)' % (p, len(a[p]), len(b[p])))
            diff += 1
    print('%d files differ' % diff)
    sys.exit(1 if diff else 0)


if __name__ == '__main__':
    main()
