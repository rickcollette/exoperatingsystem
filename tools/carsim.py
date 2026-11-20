#!/usr/bin/env python3
"""Try CAR: commands on the host simulator (tools/hostsim.py), without the
emulator and without touching build/EOS.car.

The commands named are assembled from eos/carcmd/NAME.asm into a private
directory, packed into a private CAR: device (tools/mkcarfs.py) after the
code banks of build/eos/*.bin, and run against a disk made of the files
given. Everything goes to --out (a scratch directory).

usage: carsim.py --out DIR [--cmd NAME ...] [--file NAME=PATH ...]
                 [--text NAME=line1|line2] [--geo SECTORS,SIZE] -- LINE ...

    carsim.py --out /tmp/x --cmd DIR --cmd DIRS --text A.TXT='hello' -- 'DIR' 'DIRS'
"""
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import hostsim  # noqa: E402
import sdfs  # noqa: E402

BANKS = ['boot', 'lib', 'fms', 'cp', 'dev', 'ld', 'lib2', 'dos2', 'car']


def build_car(out, cmds, extra=()):
    """The private cartridge with CAR: holding the commands (and extra files)."""
    out.mkdir(parents=True, exist_ok=True)
    coms = []
    for c in cmds:
        src = ROOT / 'eos' / 'carcmd' / (c + '.asm')
        dst = out / (c + '.COM')
        r = subprocess.run(['mads', src.name, '-s', '-o:' + str(dst)], cwd=src.parent,
                           capture_output=True, text=True)
        if r.returncode:
            sys.exit('mads %s:\n%s%s' % (c, r.stdout, r.stderr))
        coms.append(str(dst))
    coms += list(extra)
    xb = ROOT / 'build' / 'eos'
    carfs = out / 'carfs.bin'
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkcarfs.py'), str(carfs),
                    str(xb / 'boot.bin'), '9'] + coms, check=True, capture_output=True)
    car = out / 'EOS.car'
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkcarx.py'), str(car)] +
                   [str(xb / (b + '.bin')) for b in BANKS] + [str(carfs)], check=True)
    return car


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--cmd', action='append', default=[])
    ap.add_argument('--carfile', action='append', default=[], help='another file for CAR:')
    ap.add_argument('--file', action='append', default=[], help='NAME=PATH on D1:')
    ap.add_argument('--text', action='append', default=[], help="NAME=line|line on D1:")
    ap.add_argument('--geo', default='720,256')
    ap.add_argument('lines', nargs='*')
    a = ap.parse_args()
    out = Path(a.out)
    car = build_car(out, a.cmd, a.carfile)
    files = {}
    for f in a.file:
        n, p = f.split('=', 1)
        files[n] = Path(p).read_bytes()
    for f in a.text:
        n, t = f.split('=', 1)
        files[n] = b''.join(x.encode('latin-1') + b'\x9b' for x in t.split('|'))
    total, size = (int(x) for x in a.geo.split(','))
    atr = out / 'd1.atr'
    sdfs.build(str(atr), total, size, files)
    sim = hostsim.Sim(car=car, disks={1: str(atr)})
    print(sim.run(a.lines), end='')
    print('\n[%s]' % sim.stopped)


if __name__ == '__main__':
    main()
