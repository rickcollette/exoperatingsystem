#!/usr/bin/env python3
"""Toolkit survey: run each Toolkit binary on real SDX and on EOS and
compare the screen output (the main progress measure, see PROGRESS.md).

The binaries are every file under build/tkx/ (the unpacked Toolkit) that is
a binary, minus those with $FFF9 (65816) blocks or strong references to
_65816 / H_* symbols: 110 programs and drivers.

Each binary runs alone from the startup batch, with no arguments, after a
CLS. SDX's results are cached in build/survey/sdx/ (delete to redo). A
binary passes when both systems produce the same screen lines; when neither
returns to the prompt in time (it waits for a key) it is "input", not
counted.

usage: tk_survey.py [name ...]      (names like WC.COM; default all)
"""
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import sdxbin  # noqa: E402
import eos_test as T  # noqa: E402

TK = emu.BUILD / 'tkx'
SURVEY = emu.BUILD / 'survey'
TIMEOUT = 25


def binaries():
    out = {}
    for f in sorted(TK.rglob('*')):
        if f.is_dir():
            continue
        d = f.read_bytes()
        if len(d) < 2 or (d[0] | d[1] << 8) not in (0xFFFF, 0xFFFA, 0xFFFE):
            continue
        try:
            bl = list(sdxbin.blocks(d))
        except ValueError:
            continue
        refs = [x['name'] for k, x, _ in bl if k == 'xref' and not x['weak']]
        if any(r == '_65816' or r.startswith('H_') for r in refs):
            continue
        out.setdefault(f.name, f)
    return out


def run(system, name, path):
    files = {name: path.read_bytes()}
    cmds = [name]
    if system == 'sdx':
        lines = T.sdx_lines('tk-' + name, files, cmds, timeout=TIMEOUT)
    else:
        lines = T.our_lines('tk-' + name, files, cmds, timeout=TIMEOUT)
    return lines


def main():
    emu.ensure_display()
    T.OUT.mkdir(parents=True, exist_ok=True)
    (SURVEY / 'sdx').mkdir(parents=True, exist_ok=True)
    bins = binaries()
    names = sys.argv[1:] or list(bins)
    results = {}
    for n in names:
        t0 = time.monotonic()
        cache = SURVEY / 'sdx' / (n + '.json')
        if cache.exists():
            want = json.loads(cache.read_text())
        else:
            want = run('sdx', n, bins[n])
            cache.write_text(json.dumps(want))
        got = run('ours', n, bins[n])
        if want is None and got is None:
            status = 'input'
        elif want == got:
            status = 'PASS'
        else:
            status = 'FAIL'
            (SURVEY / ('diff-' + n + '.txt')).write_text('SDX:\n%s\nEOS:\n%s\n' % (
                '\n'.join(want or ['(no result)']), '\n'.join(got or ['(no result)'])))
        results[n] = status
        print('%-14s %-5s %3.0fs  %s' % (n, status, time.monotonic() - t0,
                                         (got or ['(no result)'])[0][:40] if status != 'PASS' else ''),
              flush=True)
    if not sys.argv[1:]:
        (SURVEY / 'results.json').write_text(json.dumps(results, indent=1))
    passed = sum(s == 'PASS' for s in results.values())
    print('pass %d of %d (input: %d)' % (passed, len(results),
                                          sum(s == 'input' for s in results.values())))


if __name__ == '__main__':
    main()
