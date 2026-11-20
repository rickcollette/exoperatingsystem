#!/usr/bin/env python3
"""Speed measurements (E1): frames (RTCLOK, tests/eos/TCK.COM) to copy a
40 KB file and to list a directory of 60 files, on EOS and on SDX, with
the SIO patch on (the file system's own time) or off (real drive timing).

usage: speed.py [eos|sdx] [patch|real] [us]   (in xvfb-run; a worker of its own)
  us: SIOSET 1 US first (EOS's high speed SIO); EOS_DISKEMU=usdoubler and
      real for a drive with Ultra Speed and real timing
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import emu  # noqa: E402
import eos_test as t  # noqa: E402


def frames(lines):
    ts = []
    import re
    for x in lines:
        m = re.search(r't (\d+) (\d+) (\d+)$', x)     # (after TYPE's text without EOL too)
        if m:
            a, b, c = map(int, m.groups())
            ts.append(a * 65536 + b * 256 + c)
    return [ts[i + 1] - ts[i] for i in range(len(ts) - 1)]


def main():
    system = sys.argv[1] if len(sys.argv) > 1 else 'eos'
    real = len(sys.argv) > 2 and sys.argv[2] == 'real'
    emu.ensure_display()
    files = {'TCK.COM': t.ours('TCK.COM'), 'BIG.DAT': bytes(range(256)) * 160,
             'SKT.COM': t.ours('SKT.COM'), 'HUGE/BIG.DAT': bytes(range(256)) * 1200}
    for i in range(300):               # a big directory: the last file opened
        files['MANY/F%03d.TXT' % i] = b'x'
    for i in range(60):
        files['D/F%02d.TXT' % i] = b'x'
    cmds = ['TCK', 'COPY BIG.DAT BIG2.DAT', 'TCK', 'DIR D >>NUL:', 'TCK', 'CD HUGE', '>SKT',
            'CD ..', 'TCK', 'TYPE MANY>F299.TXT', 'TYPE MANY>F298.TXT', 'TYPE MANY>F297.TXT',
            'TCK']
    import os
    if len(sys.argv) > 3 and sys.argv[3] == 'us':   # EOS's high speed SIO (E2)
        cmds = ['SIOSET 1 US'] + cmds
    if real:
        os.environ['EOS_REAL'] = '1'
    if system == 'sdx':
        lines = t.sdx_lines('speed-sdx', files, cmds, geo=(2880, 256), timeout=600)
    else:
        lines = t.our_lines('speed', files, cmds, geo=(2880, 256), timeout=600)
    f = frames(lines or [])
    print('%s %s copy %s frames, dir %s frames, 120 seeks %s frames, 3 opens in 300 files %s'
          % (system, 'real' if real else 'patch', f[0] if f else '?', f[1] if len(f) > 1 else '?',
             f[2] if len(f) > 2 else '?', f[3] if len(f) > 3 else '?'))


if __name__ == '__main__':
    main()
