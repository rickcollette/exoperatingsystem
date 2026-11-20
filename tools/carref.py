#!/usr/bin/env python3
"""Run the CAR: command probes (tools/carprobes/*.py) on real SDX and keep
what SDX shows: the screen and the files left on D1:, as text, for the
EOS versions of the commands to be matched against.

usage: carref.py OUTDIR [group[:probe,probe...] ...]   (in xvfb-run; one at a time)
"""
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import eos_test as t  # noqa: E402

SKIP = {'/SDXPROBE.COM', '/AUTOEXEC.BAT'}


def show(data):
    if data is None:
        return '<directory>'
    if all(32 <= b < 127 or b == 0x9B for b in data):
        return data.replace(b'\x9b', b'\n').decode('latin-1')
    return 'hex ' + data.hex()


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    groups = sys.argv[2:] or [p.stem for p in sorted((ROOT / 'tools' / 'carprobes').glob('*.py'))]
    for g in groups:
        g, _, only = g.partition(':')
        only = set(only.split(',')) if only else None
        spec = importlib.util.spec_from_file_location(g, ROOT / 'tools' / 'carprobes' / (g + '.py'))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        for name, p in mod.PROBES.items():
            if only and name not in only:
                continue
            files = dict(p.get('files', {}))
            lines = t.sdx_lines('ref-' + name, files, p['cmds'], geo=(720, 256), ends=True,
                                memsize=p.get('mem', '64K'), last='CONFIG.SYS' in files)
            tree = t.disk_tree(t.OUT / ('ref-' + name + '-sdx.atr'))[0]
            txt = ['# %s: %s' % (name, ' / '.join(p['cmds'])), '## screen']
            txt += lines if lines is not None else ['<no result>']
            txt.append('## files on D1:')
            for path in sorted(tree):
                if path in SKIP:
                    continue
                st, data = tree[path]
                txt.append('### %s status $%02X' % (path, st))
                txt.append(show(data))
            (out / (name + '.txt')).write_text('\n'.join(txt) + '\n')
            print(name, 'ok' if lines is not None else 'no result')


if __name__ == '__main__':
    main()
