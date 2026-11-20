#!/usr/bin/env python3
"""Run GEFINA.COM (mkgefina.py) on real SDX and print what U_GEFINA set.

show_gefina.py [pre-command ...]: the commands run first in AUTOEXEC.BAT,
e.g. `C:` to make drive 3 current (GEFINA itself runs as D1:GEFINA).
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import sdxprobe  # noqa: E402

here = Path(__file__).resolve().parent
pre = sys.argv[1:]
cmds = pre + ['D1:GEFINA', 'D1:'] if pre else ['GEFINA']
cpu, ram = sdxprobe.run(cmds, [here / 'GEFINA.COM'])
print('pre %r CURDEV $%02X' % (pre, cpu[0x8FFF]))
for i, c in enumerate((here / 'gefina.txt').read_text().split('\n')[:-1]):
    r = cpu[0x9000 + 80 * i:0x9000 + 80 * i + 76]
    p = r[12:76]
    end = p.find(0xAA)
    print('%-24s dev $%02X name %r path %r' % (c, r[0], bytes(r[1:12]).decode('latin-1'),
                                              bytes(p[:end if end >= 0 else 64]).decode('latin-1')))
