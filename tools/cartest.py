#!/usr/bin/env python3
"""The CAR: command tests: each probe in tools/carprobes/*.py runs on EOS
(Altirra) and is compared with what real SDX showed for it, kept by
tools/carref.py in the reference directory: the screen lines and the files
left on D1:. 'mask': regular expressions whose group 1 is not compared
(a random id). A probe with 'differs': 'reason' is expected to differ (XFAIL:
EOS's own memory layout, no clock yet ...).

usage: cartest.py [group[:probe,probe...] ...]   (references in tests/carref)
"""
import importlib.util
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import eos_test as t  # noqa: E402
import carref  # noqa: E402


# make eosall: EOS in another configuration (tools/eosall.py): numbers
# (free sectors, memory) are not compared
LOOSE = any(os.environ.get(k) for k in ('EOS_MEM', 'EOS_GEO', 'EOS_REAL'))


def eos_text(name, p):
    lines = t.our_lines('car-' + name, dict(p.get('files', {})), p['cmds'], geo=(720, 256),
                        memsize=p.get('mem', '64K'))
    tree = t.disk_tree(t.OUT / ('car-' + name + '.atr'))[0]
    txt = ['# %s: %s' % (name, ' / '.join(p['cmds'])), '## screen']
    txt += lines if lines is not None else ['<no result>']
    txt.append('## files on D1:')
    for path in sorted(tree):
        if path in carref.SKIP:
            continue
        st, data = tree[path]
        txt.append('### %s status $%02X' % (path, st))
        txt.append(carref.show(data))
    return txt


def split(txt):
    """(screen lines, the rest): the screen as EOS may have scrolled it once
    more (its prompt line), the files exactly."""
    i = txt.index('## files on D1:') if '## files on D1:' in txt else len(txt)
    return txt[2:i], txt[i:]


def main():
    ref = ROOT / 'tests' / 'carref'
    groups = sys.argv[1:] or [p.stem for p in sorted((ROOT / 'tools' / 'carprobes').glob('*.py'))]
    counts = {'PASS': 0, 'FAIL': 0, 'XFAIL': 0, 'NOREF': 0}
    for g in groups:
        g, _, only = g.partition(':')
        only = set(only.split(',')) if only else None
        spec = importlib.util.spec_from_file_location(g, ROOT / 'tools' / 'carprobes' / (g + '.py'))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        for name, p in mod.PROBES.items():
            if only and name not in only:
                continue
            rf = ref / (name + '.txt')
            if not rf.exists():
                counts['NOREF'] += 1
                print('%-14s NOREF' % name)
                continue
            want = rf.read_text().rstrip('\n').split('\n')
            if '<no result>' in want:
                counts['NOREF'] += 1
                print('%-14s NOREF  (SDX gave no result)' % name)
                continue
            got = '\n'.join(eos_text(name, p)).rstrip('\n').split('\n')
            for pat in p.get('mask', ()):     # what differs each run (random ids)
                want = [re.sub(pat, lambda m: m.group(0)[:m.start(1) - m.start(0)] + '..' +
                               m.group(0)[m.end(1) - m.start(0):], x) for x in want]
                got = [re.sub(pat, lambda m: m.group(0)[:m.start(1) - m.start(0)] + '..' +
                              m.group(0)[m.end(1) - m.start(0):], x) for x in got]
            if LOOSE:                  # another configuration: its numbers differ
                want = [re.sub(r' *[0-9]+', ' #', x) for x in want]
                got = [re.sub(r' *[0-9]+', ' #', x) for x in got]
            if os.environ.get('EOS_MEM', '64K') != '64K':   # the default RAM disk O:
                got = [x for x in got if not re.search(r'(^|[ ;=])O:|^All ', x)]
                want = [x for x in want if not re.search(r'(^|[ ;=])O:|^All ', x)]
            gs, gf = split(got)
            ws, wf = split(want)
            # the screens end differently (SDX: SDXPROBE typed; EOS: its
            # prompt), so a full screen may be scrolled one line either way
            ok = gf == wf and (gs == ws or gs == ws[1:] or gs[1:] == ws)
            res = 'PASS' if ok else ('XFAIL' if p.get('differs') else 'FAIL')
            counts[res] += 1
            if res == 'FAIL':
                (t.OUT / ('car-' + name + '.diff')).write_text(
                    'SDX:\n%s\nEOS:\n%s\n' % ('\n'.join(want), '\n'.join(got)))
            print('%-14s %s%s' % (name, res, ('  ' + p['differs']) if res == 'XFAIL' else ''))
    print('cartest: %s' % ', '.join('%d %s' % (v, k) for k, v in counts.items()))
    sys.exit(1 if counts['FAIL'] else 0)


if __name__ == '__main__':
    main()
