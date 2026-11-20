#!/usr/bin/env python3
"""make eosall (T1): EOS tested inside itself in each configuration: every
CAR: command probe (tools/cartest.py; outside the default configuration
the numbers, free sectors and memory, are not compared) and EOS's own
driver and utility tests (tools/eos_test.py, no SDX), on 64K and 320K
RAMBO, with the SIO patch on and off, on SD, ED, DD and QD disks. A line
per configuration, exit 1 when one failed.

usage: eosall.py [config ...]   (tools/prun.py runs the tests side by side)
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# EOS-only tests: drivers and utilities with their expected results
EOS_TESTS = ['siodrv', 'con80', 'sc', 'uexpand', 'blkio', 'secmx', 'zsys', 'comexe', 'runext',
             'doskey', 'boot-64K', 'reset', 'builddir', 'hssio', 'envsys']
CONFIGS = {
    'default': {},
    '320K': {'EOS_MEM': '320K'},
    'nosiopatch': {'EOS_REAL': '1'},
    'sd': {'EOS_GEO': '720x128'},
    'ed': {'EOS_GEO': '1040x128'},
    'qd': {'EOS_GEO': '1440x256'},
}


def run(cfg, kind, names):
    env = dict(os.environ, **CONFIGS[cfg])
    p = subprocess.run([sys.executable, str(ROOT / 'tools' / 'prun.py'), '-j',
                        os.environ.get('JOBS', '3'), kind] + names,
                       env=env, capture_output=True, text=True)
    last = (p.stdout.strip().splitlines() or ['?'])[-1]
    bad = [x for x in p.stdout.splitlines() if ' FAIL' in x or 'ERROR' in x]
    return p.returncode == 0, last, bad


def main():
    failed = 0
    for cfg in sys.argv[1:] or list(CONFIGS):
        for kind, names in (('car', []), ('eos', EOS_TESTS)):
            ok, last, bad = run(cfg, kind, names)
            print('%-11s %-4s %s %s' % (cfg, kind, 'PASS' if ok else 'FAIL', last), flush=True)
            for x in bad:
                print('    ' + x, flush=True)
            failed += not ok
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
