#!/usr/bin/env python3
"""The BASIC benchmark: tests/bench/BENCH.BAS, the same Atari BASIC program,
on Atari DOS 2.5, MyDOS 4.53/4, SpartaDOS X 4.50 and EOS, each pair on the
same kind of work disk in D2: (BENCH.BAS and its files there):

  dos2   a DOS 2.0S/2.5 disk (720 x 128): DOS 2.5 and EOS
  mydos  a MyDOS disk (720 x 256): MyDOS and EOS
  sdfs   an SDFS disk (720 x 256): SDX and EOS (SDX's ATARIDOS.SYS only
         reads DOS 2 disks, so SDX writes on its own format)

DOS 2.5 and MyDOS boot from their own disks in D1: (media/DOS25.ATR,
media/MYDOS453.ATR) with BASIC on; ENTER "D2:BENCH.BAS" and RUN are typed.
EOS and SDX feed the same two lines to BASIC from a batch file. BENCH.BAS
writes D2:RESULT.TXT (a job and its frames per line); the host reads it.

Two timings, as tools/bench.py: "fs", Altirra's standard drive with the
SIO patch (EOS and SDX set to SIOSET 2 NORMAL first, so that every DOS
goes through the OS's SIO and the patch: the DOS's own time), and "drive",
a US Doubler with accurate timing, each DOS as it is (EOS and SDX use its
Ultra Speed, DOS 2.5 and MyDOS the standard speed).

usage: basbench.py [run ...]   (runs: <system>-<format>-<timing>, e.g.
                                dos25-dos2-fs; default: all twelve)
Results: build/basbench.json (tools/benchmd.py puts them in BENCHMARKS.md).
"""
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import dos2  # noqa: E402
import sdfs  # noqa: E402
import eos_test as T  # noqa: E402

OUT = emu.BUILD / 'basbench'
RESULTS = emu.BUILD / 'basbench.json'
BENCH = emu.ROOT / 'tests' / 'bench' / 'BENCH.BAS'
JOBS = ['PUTBYTE', 'GETBYTE', 'BLKWRITE', 'BLKREAD', 'RECWRITE', 'RECREAD', 'CREATE', 'DIR',
        'OPEN', 'SEEK', 'RENAME', 'DELETE']
PAIRS = [('dos25', 'dos2'), ('eos', 'dos2'), ('mydos', 'mydos'), ('eos', 'mydos'),
         ('sdx', 'sdfs'), ('eos', 'sdfs')]
RUNS = ['%s-%s-%s' % (s, f, t) for t in ('fs', 'drive') for s, f in PAIRS]
BOOT = {'dos25': 'DOS25.ATR', 'mydos': 'MYDOS453.ATR'}
TYPED = ['ENTER "D2:BENCH.BAS"', 'RUN']


def work_disk(path, fmt):
    files = {'BENCH.BAS': emu.atascii(BENCH.read_text().splitlines())}
    if fmt == 'dos2':
        dos2.build(str(path), 720, 128, files)
    elif fmt == 'mydos':
        dos2.build(str(path), 720, 256, files)
    else:
        sdfs.build(str(path), 720, 256, files)


def result(path, fmt):
    """RESULT.TXT's lines from the work disk, or None."""
    try:
        if fmt == 'sdfs':
            vol = sdfs.Volume(str(path))
            data = dict((n, e.get('data')) for n, e in vol.check()).get('/RESULT.TXT')
        else:
            d = dos2.Dos2(str(path))
            data = None
            for _, e in d.files():
                if d.name(e) == 'RESULT.TXT':
                    data = b''.join(x for _, x, _ in d.chain(e))
    except Exception:
        return None
    if not data:
        return None
    lines = data.decode('latin-1').split('\x9b')
    return lines if 'END' in lines else None


def parse(lines):
    out = {}
    for x in lines:
        f = x.split()
        if len(f) >= 2 and f[0] in JOBS:
            out[f[0]] = int(float(f[1]))
            if out[f[0]] < 0 and len(f) > 2:       # an error: its number and line
                out[f[0] + '-line'] = int(float(f[2]))
    return out


def run(name):
    system, fmt, timing = name.split('-')
    OUT.mkdir(parents=True, exist_ok=True)
    d2 = OUT / (name + '-d2.atr')
    work_disk(d2, fmt)
    env = {'EOS_DISKEMU': 'usdoubler' if timing == 'drive' else ''}
    old = {k: os.environ.get(k) for k in env}
    os.environ.update(env)
    try:
        if system in BOOT:
            d1 = OUT / (name + '-d1.atr')
            d1.write_bytes((emu.MEDIA / BOOT[system]).read_bytes())
            sess = emu.Session(OUT, [d1, d2], cart=None, name=name, turbo=True,
                               real=timing == 'drive', basic=True)
        else:
            batch = (['SIOSET 2 NORMAL'] if timing == 'fs' else []) + ['BASIC /I <<D1:GO.TXT']
            files = {'AUTOEXEC.BAT': emu.atascii(batch), 'GO.TXT': emu.atascii(TYPED)}
            d1 = T.disk(name + '-d1', files)
            sess = emu.Session(OUT, [d1, d2], cart=T.CAR if system == 'eos' else emu.SDX_CART,
                               name=name, turbo=True, real=timing == 'drive')
        with sess:
            if system in BOOT:
                time.sleep(20)                 # to BASIC's READY
                wid = emu.window_id()
                emu.type_keys(wid, TYPED[0])
                time.sleep(10)
                emu.type_keys(wid, TYPED[1])
            deadline = time.monotonic() + 1200
            lines = None
            while time.monotonic() < deadline:
                time.sleep(5)
                lines = result(d2, fmt)
                if lines:
                    break
            emu.screenshot(OUT / (name + '.png'))
    finally:
        for k, v in old.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
    if not lines:
        return {'error': 'no D2:RESULT.TXT (see %s)' % (OUT / (name + '.png'))}
    return parse(lines)


def main():
    emu.ensure_display()
    res = json.loads(RESULTS.read_text()) if RESULTS.exists() else {}
    for name in sys.argv[1:] or RUNS:
        res[name] = run(name)
        print(name, res[name], flush=True)
        RESULTS.write_text(json.dumps(res, indent=1))


if __name__ == '__main__':
    main()
