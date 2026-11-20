#!/usr/bin/env python3
"""Games on EOS (Altirra): screenshots after each step, in
build/game-results.

  basic   an Atari DOS 2 disk with a BASIC program in D2: (D1: a disk whose
          AUTOEXEC.BAT runs BASIC /I <<GO.TXT, GO.TXT: RUN "D2:...")
  boot    a boot disk in D1:, COLD /N typed at the prompt

usage: game_test.py [--sdx] [case ...]   (in xvfb-run, or tools/prun.py)
  --sdx  also on real SDX (a reference only: EOS is tested on its own)
"""
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import emu  # noqa: E402
import eos_test as t  # noqa: E402

OUT = emu.BUILD / 'game-results'

# name: (kind, image, program for basic / seconds to wait after COLD /N, shots)
CASES = {
    'fart': ('basic', 'Fart_19xx_Starace_Thomas_J._US_PD_BASIC.atr', 'D2:FART.BAS', 4),
    'hacker': ('boot', 'Hacker_1985_Activision.atr', 20, 4),
    'montezuma': ('boot', 'Montezumas_Revenge_1983_Utopia_Software_US_proto_k_file.atr', 20, 4),
    'montezuma-pb': ('boot', "Montezuma's Revenge (1984)(Parker Brothers)(US)[cr A].atr", 20, 4),
    'montezuma-pb-64K': ('boot', "Montezuma's Revenge (1984)(Parker Brothers)(US)[cr A].atr", 20, 4),
}


def run(name, cart, case):
    kind, image, arg, shots = case
    tag = '%s-%s' % (name, cart)
    game = OUT / (tag + '-game.atr')
    game.write_bytes((ROOT / 'media' / image).read_bytes())
    if kind == 'basic':
        d1 = t.disk(tag + '-d1', {'AUTOEXEC.BAT': emu.atascii(['BASIC /I <<D1:GO.TXT']),
                                  'GO.TXT': emu.atascii(['RUN "%s"' % arg])})
        disks = [d1, game]
    else:
        disks = [game]
    carts = {'eos': t.CAR, 'sdx': emu.SDX_CART}
    mem = name.rsplit('-', 1)[1] if name.endswith('K') else '320K'
    with emu.Session(OUT, disks, cart=carts[cart], name=tag, memsize=mem):
        time.sleep(12)
        emu.screenshot(OUT / (tag + '-0.png'))
        if kind == 'boot':
            wid = emu.window_id()
            emu.type_line(wid, 'COLD /N')
            time.sleep(arg)
        for i in range(1, shots + 1):
            time.sleep(6)
            emu.screenshot(OUT / ('%s-%d.png' % (tag, i)))
    return tag


def main():
    emu.ensure_display()
    OUT.mkdir(parents=True, exist_ok=True)
    args = sys.argv[1:]
    carts = ['eos']
    if '--sdx' in args:
        args.remove('--sdx')
        carts.insert(0, 'sdx')
    for n in args or list(CASES):
        for cart in carts:
            print('%-12s %s  %s' % (n, cart, run(n, cart, CASES[n])), flush=True)


if __name__ == '__main__':
    main()
