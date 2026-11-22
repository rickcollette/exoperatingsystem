#!/usr/bin/env python3
"""Run emulator tests side by side: each test in a process of its own, on
one of N workers (EMU_WORKER=k: its own Wine prefix, tools/emu.py; its own
X server, display 200+k). The result lines are printed as the tests end;
exit 1 when one failed.

usage: prun.py [-j N] eos|car|fmt|mutineer|game|tk [name or pattern ...]
  (PRUN_BASE=b: workers b+1 .. b+N, beside a test already on worker 1)
  eos       tools/eos_test.py tests (EOS_EOSFS passes through)
  car       tools/cartest.py probes (group:probe)
  fmt       tools/fmt_test.py cases
  mutineer  tools/mutineer_matrix.py cells (the table is written at the end)
  game      tools/game_test.py cases (screenshots in build/game-results)
  tk        tools/tk_test.py cases (EOS's Toolkit against the SDX Toolkit)
"""
import importlib.util
import os
import queue
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))

SCRIPTS = {'eos': 'eos_test.py', 'car': 'cartest.py', 'fmt': 'fmt_test.py',
           'mutineer': 'mutineer_matrix.py', 'game': 'game_test.py', 'tk': 'tk_test.py'}


def names(kind):
    if kind == 'eos':
        sys.argv[1:] = []
        import eos_test
        return list(eos_test.EOSFS_ACTIVE if eos_test.EOSFS else eos_test.TESTS)
    if kind == 'fmt':
        import fmt_test
        return list(fmt_test.CASES)
    if kind == 'mutineer':
        import mutineer_matrix
        return list(mutineer_matrix.CELLS)
    if kind == 'game':
        import game_test
        return list(game_test.CASES)
    if kind == 'tk':
        import tk_test
        return list(tk_test.CASES)
    out = []
    for f in sorted((ROOT / 'tools' / 'carprobes').glob('*.py')):
        spec = importlib.util.spec_from_file_location(f.stem, f)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        out += ['%s:%s' % (f.stem, n) for n in mod.PROBES]
    return out


def worker(k, kind, todo, results, lock):
    env = dict(os.environ, EMU_WORKER=str(k))
    env.pop('DISPLAY', None)
    while True:
        try:
            n = todo.get_nowait()
        except queue.Empty:
            return
        t0 = time.monotonic()
        p = subprocess.run(['xvfb-run', '-n', str(200 + k), '-s', '-screen 0 1024x768x24',
                            sys.executable, str(ROOT / 'tools' / SCRIPTS[kind]), n],
                           env=env, capture_output=True, text=True)
        lines = [x for x in p.stdout.splitlines() if x.strip() and not x.startswith('cartest:')]
        if p.returncode not in (0, 1) or not lines:
            tail = (p.stderr.strip().splitlines() or ['?'])[-1]
            lines = ['%-12s ERROR  exit %d: %s' % (n, p.returncode, tail)]
        with lock:
            results.append((n, p.returncode, lines))
            for x in lines:
                print(x, flush=True)
            if p.returncode and time.monotonic() - t0 < 2:
                print('   (worker %d: %s)' % (k, p.stderr.strip()[-300:]), flush=True)


def main():
    args = sys.argv[1:]
    jobs = 3
    if args[:1] == ['-j']:
        jobs = int(args[1])
        args = args[2:]
    kind, wanted = args[0], args[1:]
    if any('*' in w for w in wanted):      # patterns: eos 'xb-*'
        import fnmatch
        every = names(kind)
        wanted = [n for w in wanted for n in (fnmatch.filter(every, w) if '*' in w else [w])]
    todo = queue.Queue()
    for n in wanted or names(kind):
        todo.put(n)
    results, lock = [], threading.Lock()
    t0 = time.monotonic()
    base = int(os.environ.get('PRUN_BASE', '0'))
    ws = [threading.Thread(target=worker, args=(k, kind, todo, results, lock))
          for k in range(base + 1, base + jobs + 1)]
    for w in ws:
        w.start()
    for w in ws:
        w.join()
    if kind == 'mutineer':
        import mutineer_matrix
        mutineer_matrix.save([x for _, _, ls in results for x in ls if x.startswith('| ')],
                             [n for n, _, _ in results])
    bad = [n for n, rc, ls in results if rc or any(re.search(r'\b(FAIL|ERROR)\b', x) and
                                                  'XFAIL' not in x and 'SDX-FAILS' not in x
                                                  for x in ls)]
    print('%s: %d run, %d failed%s, %.0f s with %d workers' % (
        kind, len(results), len(bad), (' (%s)' % ' '.join(bad)) if bad else '',
        time.monotonic() - t0, jobs))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
