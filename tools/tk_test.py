#!/usr/bin/env python3
"""EOS Toolkit tests: each of EOS's own utilities (toolkit/, built into
build/etk/) against the SDX Toolkit program it replaces. The same command
lines run with the original on real SDX 4.50 (the oracle: make tkx, SDX_CART)
and with EOS's version on EOS; the screen lines must be the same.

Tools that have no SDX original (the Unix-like ones) are checked against
the lines their case expects instead.

The cases are in tools/tkcases/NAME.py (case() below): the original under
build/tkx/, the command lines, the files beside it on the disk, and
optionally a function that both outputs go through before the comparison,
for what may differ: times, addresses.

usage: tk_test.py [case ...]      (tools/prun.py -j N tk)
"""
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import eos_test as t  # noqa: E402

TKX = emu.BUILD / 'tkx'
ETK = emu.BUILD / 'etk'
GEO = (720, 256)


def case(orig, cmds, files=None, norm=None, prog=None, want=None):
    """A case: the original under build/tkx/, the command lines, the files
    beside it on the disk, and a function both outputs go through first.
    A tool with no SDX original (the Unix-like ones): orig None, prog its
    name (NAME.COM in build/etk/) and want the lines EOS must show."""
    return {'orig': orig, 'cmds': cmds, 'files': files or {}, 'norm': norm,
            'prog': prog, 'want': want}


def no_times(lines):
    return [re.sub(r'\d+:\d\d:\d\d\.\d\d', 'T', x) for x in lines]


def load():
    """The cases: tools/tkcases/NAME.py, each with a CASES dict (one file per
    utility, so that they can be written side by side)."""
    import importlib.util
    out = {}
    for f in sorted((Path(__file__).resolve().parent / 'tkcases').glob('*.py')):
        spec = importlib.util.spec_from_file_location('tkcase_' + f.stem, f)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        out.update(mod.CASES)
    return out


CASES = load()


def run(name):
    c = CASES[name]
    prog = c['prog'] or Path(c['orig']).name
    ours = (ETK / prog).read_bytes()
    if c['orig']:
        orig = (TKX / c['orig']).read_bytes()
        want = t.sdx_lines('tk-' + name, dict(c['files'], **{prog: orig}), c['cmds'], geo=GEO)
    else:
        want = list(c['want'])
    got = t.our_lines('tk-' + name, dict(c['files'], **{prog: ours}), c['cmds'], geo=GEO)
    if want is None:
        return False, 'no result from SDX'
    if got is None:
        return False, 'no result from EOS'
    if c['norm']:
        want, got = c['norm'](want), c['norm'](got)
    if want == got:
        return True, '%d lines' % len(got)
    diff = next(i for i in range(max(len(want), len(got)))
                if i >= len(want) or i >= len(got) or want[i] != got[i])
    return False, 'line %d: SDX %r, EOS %r' % (diff, want[diff:diff + 3], got[diff:diff + 3])


def main():
    emu.ensure_display()
    t.OUT.mkdir(parents=True, exist_ok=True)
    failed = 0
    for n in sys.argv[1:] or list(CASES):
        t0 = time.monotonic()
        ok, msg = run(n)
        print('%-12s %-5s %4.0fs  %s' % (n, 'PASS' if ok else 'FAIL', time.monotonic() - t0, msg),
              flush=True)
        failed += not ok
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
