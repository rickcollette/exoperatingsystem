#!/usr/bin/env python3
"""The Mutineer matrix (docs/history/MUTINEER_PROMPT.md): each configuration runs the walk
scenario on EOS (tools/mutineer_test.py); with MUTINEER_SDX=1 on real SDX
first, and the disks are compared (tools/mutineer_cmp.py). A table goes to
build/mutineer-results/matrix.md: PASS (EOS walks; with SDX: and its files
match SDX's), FAIL, OUT-OF-SCOPE (SDX does not run it either) or SDX-FAILS.

The axes start from the base (800XL, 320K RAMBO, NTSC, 850, R-Time 8, no
CONFIG.SYS) and change one at a time.

usage: mutineer_matrix.py [cell ...]      (in xvfb-run, or tools/prun.py mutineer)
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import emu  # noqa: E402
OUT = ROOT / 'build' / 'mutineer-results'
BASE = {'hardware': '800xl', 'mem': '320K', 'video': 'ntsc', 'clock': 'rtime8', 'real': False,
        'config': '', 'cfgname': ''}
# A CONFIG.SYS replaces the drivers SDX loads without one: these come too
DRV = 'DEVICE SPARTA|DEVICE SIO|DEVICE RTIME8'
CELLS = {
    'base': {},
    'hw-130xe': {'hardware': '130xe', 'mem': '128K'},
    'hw-1200xl': {'hardware': '1200xl', 'mem': '64K'},
    'hw-xegs': {'hardware': 'xegs', 'mem': '64K'},
    'mem-64K': {'mem': '64K'},
    'mem-128K': {'mem': '128K'},
    'mem-256K': {'mem': '256K'},
    'mem-320KCOMPY': {'mem': '320KCOMPY'},
    'mem-576K': {'mem': '576K'},
    'mem-576KCOMPY': {'mem': '576KCOMPY'},
    'mem-1088K': {'mem': '1088K'},
    'pal': {'video': 'pal'},
    'real': {'real': True},
    'noclock': {'clock': 'none'},
    'cfg-osram': {'config': 'USE OSRAM|' + DRV, 'cfgname': 'osram'},
    'cfg-banked': {'config': 'USE BANKED|' + DRV, 'cfgname': 'banked'},
    'cfg-ramdisk': {'config': DRV + '|DEVICE RAMDISK O,8', 'cfgname': 'ramdisk'},
}


def run(cart, c):
    cmd = [sys.executable, str(ROOT / 'tools' / 'mutineer_test.py'), '--cart', cart,
           '--scenario', 'walk', '--hardware', c['hardware'], '--mem', c['mem'],
           '--video', c['video'], '--clock', c['clock']]
    if c['real']:
        cmd.append('--real')
    if c['config']:
        cmd += ['--config', c['config'], '--cfgname', c['cfgname']]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
    line = (p.stdout.strip().splitlines() or ['?'])[-1]
    tag = line.split()[0] if line != '?' else ''
    return p.returncode == 0, line, OUT / tag / 'D1.atr'


# cells where real SDX does not run the walk either (2026-11-03 matrix):
# out of scope, not run
NOT_ON_SDX = {
    'hw-130xe': 'Mutineer crashes on 128K (on SDX too)',
    'hw-1200xl': 'Mutineer crashes on 64K (on SDX too)',
    'hw-xegs': 'Mutineer crashes on 64K (on SDX too)',
    'mem-64K': 'Mutineer crashes on 64K (on SDX too)',
    'mem-128K': 'Mutineer crashes on 128K (on SDX too)',
    'mem-576KCOMPY': 'SDX stops at step 27',
    'noclock': 'Mutineer asks for the date without a clock (on SDX too)',
    'cfg-osram': 'Mutineer crashes with USE OSRAM (on SDX too)',
}
# MUTINEER_SDX=1: also on real SDX, the disks compared (EOS is tested on
# its own otherwise: SDX is a reference)
WITH_SDX = os.environ.get('MUTINEER_SDX', '') not in ('', '0')


def main():
    names = sys.argv[1:] or list(CELLS)
    rows = []
    for n in names:
        c = dict(BASE, **CELLS[n])
        if WITH_SDX:
            ok_s, line_s, atr_s = run('sdx', c)
        if n in NOT_ON_SDX and not WITH_SDX:
            res, why = 'OUT-OF-SCOPE', NOT_ON_SDX[n]
        elif WITH_SDX and not ok_s:
            res, why = 'SDX-FAILS', line_s
        else:
            ok_e, line_e, atr_e = run('eos', c)
            if not ok_e:
                res, why = 'FAIL', line_e
            elif not WITH_SDX:
                res, why = 'PASS', line_e
            else:
                p = subprocess.run([sys.executable, str(ROOT / 'tools' / 'mutineer_cmp.py'),
                                    str(atr_s), str(atr_e)], capture_output=True, text=True)
                res = 'PASS' if p.returncode == 0 else 'FAIL'
                why = p.stdout.strip().splitlines()[-1] if res == 'PASS' else p.stdout.strip().replace('\n', '; ')
        rows.append('| %s | %s | %s |' % (n, res, why))
        print(rows[-1], flush=True)
    if not emu.WORKER:              # (tools/prun.py writes it after its workers)
        save(rows, names)


def save(rows, names):
    """The table: these cells' rows replace their old ones."""
    table = OUT / 'matrix.md'
    old = table.read_text().splitlines() if table.exists() else []
    keep = [r for r in old if r.startswith('| ') and r.split('|')[1].strip() not in names
            and not r.startswith('| cell')]
    table.write_text('\n'.join(['| cell | result | detail |', '|---|---|---|'] + keep + rows) + '\n')


if __name__ == '__main__':
    main()
