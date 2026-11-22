#!/usr/bin/env python3
"""Fail the build gate when EOS's fixed resident footprint grows unnoticed."""
import sys
from pathlib import Path


LIMITS = {
    'K_MEMLO': 0x17C9,
    'FMS_END': 0xC7A7,
    'BF_DAT2': 0xC800,
}


def labels(path):
    out = {}
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) == 3:
            try:
                out[fields[2].upper()] = int(fields[1], 16)
            except ValueError:
                pass
    return out


def main():
    got = labels(sys.argv[1] if len(sys.argv) > 1 else 'build/eos/kernel.lab')
    errors = []
    for name, limit in LIMITS.items():
        if name not in got:
            errors.append('%s missing' % name)
        elif name == 'BF_DAT2' and got[name] != limit:
            errors.append('%s=$%04X, expected $%04X' % (name, got[name], limit))
        elif name != 'BF_DAT2' and got[name] > limit:
            errors.append('%s=$%04X exceeds $%04X' % (name, got[name], limit))
    if errors:
        print('resident-size: ' + '; '.join(errors), file=sys.stderr)
        return 1
    print('resident-size: MEMLO=$%04X, under-ROM end=$%04X, cache=$%04X' %
          (got['K_MEMLO'], got['FMS_END'], got['BF_DAT2']))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
