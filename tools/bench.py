#!/usr/bin/env python3
"""Benchmarks: EOS on its native EOSFS against SDX 4.50 on SDFS (and EOS on
SDFS for reference), in Altirra with a US Doubler drive. Frames (RTCLOK,
tests/eos/TCK.COM) for four jobs on a 720 KB disk (2880 x 256):

  copy    COPY of a 40 KB file
  dir     DIR of a directory of 60 files (to NUL:)
  seek    120 seeks (FSEEK + 1 byte FREAD) in a 300 KB file (SKT.COM)
  open    TYPE of the last 3 files of a 300-file directory

PFTEST (the Toolkit's PRINTF benchmark, build/tkx) runs on its own on
both systems ("pftest-eos", "pftest-sdx"): its six tests and their average
as it prints them (its own frame counts: shorter is faster).

Two timings: "fs" with Altirra's generic drive and no rotation timing
(both systems use its XF551 commands, bytes as fast as they are handled:
what is left is the DOS's own work and its SIO driver's) and "drive" (no SIO patch, accurate
disk timing: what a real drive gives; SDX and EOS both ask the drive for
its Ultra Speed rate and use it). Results: build/bench.json; tools/benchmd.py writes
docs/BENCHMARKS.md and its charts.

usage: bench.py [run ...]   (runs: eosfs-fs sdx-fs sdfs-fs eosfs-drive
                             sdx-drive sdfs-drive pftest-eos pftest-sdx; one
                             worker: EMU_WORKER)
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import emu  # noqa: E402

JOBS = ['copy', 'dir', 'seek', 'open']
RUNS = {                      # system, format, timing, high speed
    'eosfs-fs': ('eos', 'eosfs', 'fs', False),
    'sdx-fs': ('sdx', 'sdfs', 'fs', False),
    'sdfs-fs': ('eos', 'sdfs', 'fs', False),
    'eosfs-drive': ('eos', 'eosfs', 'drive', False),
    'sdx-drive': ('sdx', 'sdfs', 'drive', False),
    'sdfs-drive': ('eos', 'sdfs', 'drive', False),
    # 320K: EOS's second-level cache (E1) in one of its banks
    'eosfs-fs-320K': ('eos', 'eosfs', 'fs', False, '320K'),
    'eosfs-drive-320K': ('eos', 'eosfs', 'drive', False, '320K'),
}
OUT = emu.BUILD / 'bench.json'
PFTEST = emu.BUILD / 'tkx' / 'DRIVERS' / 'TURBOBRD' / 'EXT816' / 'PFTEST.COM'
PF_TESTS = ['Simple text', 'Substring s', 'Substring p', '8/16/24-bit', '32-bit long',
            'Hex strings']


def pftest(system):
    os.environ.update(EOS_EOSFS='', EOS_DISKEMU='', EMU_REAL='', EOS_FRESH='1')
    import importlib
    import eos_test as t
    importlib.reload(t)
    files = {'PFTEST.COM': PFTEST.read_bytes()}
    if system == 'sdx':
        lines = t.sdx_lines('bench-pftest-sdx', files, ['PFTEST'], timeout=300)
    else:
        lines = t.our_lines('bench-pftest-eos', files, ['PFTEST'], timeout=300)
    out = {}
    for x in lines or []:
        m = re.match(r'\s*([^:]+): (\d+(?:\.\d+)?)', x)
        if m and (m.group(1) in PF_TESTS or m.group(1) == 'Average'):
            out[m.group(1)] = float(m.group(2))
    return out if len(out) == len(PF_TESTS) + 1 else {'error': (lines or ['no result'])[-9:]}


def frames(lines):
    ts = []
    for x in lines or []:
        m = re.search(r't (\d+) (\d+) (\d+)$', x)
        if m:
            a, b, c = map(int, m.groups())
            ts.append(a * 65536 + b * 256 + c)
    return [ts[i + 1] - ts[i] for i in range(len(ts) - 1)]


def run(name):
    if name.startswith('pftest-'):
        return pftest(name[7:])
    system, fmt, timing, us = RUNS[name][:4]
    mem = RUNS[name][4] if len(RUNS[name]) > 4 else '64K'
    os.environ['EOS_EOSFS'] = '1' if fmt == 'eosfs' else ''
    # fs: Altirra's generic drive, which has no Ultra Speed but takes the
    # XF551's commands: SDX's and EOS's own SIO drivers both use them
    os.environ['EOS_DISKEMU'] = 'usdoubler' if timing == 'drive' else ''
    os.environ['EMU_REAL'] = '1' if timing == 'drive' else ''
    os.environ['EOS_FRESH'] = '1'          # (SDX: not from the cache)
    import importlib
    import eos_test as t
    importlib.reload(t)
    files = {'TCK.COM': t.ours('TCK.COM'), 'SKT.COM': t.ours('SKT.COM'),
             'BIG.DAT': bytes(range(256)) * 160, 'HUGE/BIG.DAT': bytes(range(256)) * 1200}
    for i in range(60):
        files['D/F%02d.TXT' % i] = b'x'
    for i in range(300):
        files['MANY/F%03d.TXT' % i] = b'x'
    cmds = (['SIOSET 1 US'] if us else []) + [
        'TCK', 'COPY BIG.DAT BIG2.DAT', 'TCK', 'DIR D> >>NUL:', 'TCK', 'CD HUGE', '>SKT', 'CD ..',
        'TCK', 'TYPE MANY>F299.TXT', 'TYPE MANY>F298.TXT', 'TYPE MANY>F297.TXT', 'TCK']
    if system == 'sdx':
        lines = t.sdx_lines('bench-' + name, files, cmds, geo=(2880, 256), timeout=900)
    else:
        lines = t.our_lines('bench-' + name, files, cmds, geo=(2880, 256), timeout=900,
                            memsize=mem)
    f = frames(lines)
    return dict(zip(JOBS, f)) if len(f) == 4 else {'error': (lines or ['no result'])[-3:]}


def main():
    emu.ensure_display()
    res = json.loads(OUT.read_text()) if OUT.exists() else {}
    for name in sys.argv[1:] or list(RUNS) + ['pftest-eos', 'pftest-sdx']:
        res[name] = run(name)
        print(name, res[name], flush=True)
        OUT.write_text(json.dumps(res, indent=1))


if __name__ == '__main__':
    main()
