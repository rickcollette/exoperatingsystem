#!/usr/bin/env python3
"""FORMAT tests: EOS's formatter menu formats D2: in Altirra, then the disk
is checked on the host (tools/sdfs.py): an SDFS of the size picked, no
errors, the free count FORMAT showed.

Each case: the image put in D2: (blank of a geometry, or a copy of a file),
the keys pressed after U 2 (Z picks the next size, F formats, B builds the
directory only), and the total sectors and sector size expected.

usage: fmt_test.py [--real] [--mem SIZE] [case ...]   (in xvfb-run)
  --real: SIO patch off, accurate sector timing; --mem: e.g. 320K
"""
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import eos_test as t  # noqa: E402
import sdfs  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = t.OUT / 'fmt'

# name: (D2 image: (sectors, seclen) blank or a path, keys, total, seclen)
CASES = {
    'f-90k': ((720, 128), ['f'], 720, 128),
    'f-127k': ((1040, 128), ['f'], 1040, 128),
    'f-180k': ((720, 256), ['f'], 720, 256),
    'f-360k': ((1440, 256), ['f'], 1440, 256),
    'f-720k': ((1440, 512), ['f'], 1440, 512),
    'f-1440k': ((2880, 512), ['f'], 2880, 512),
    'f-16m': ((65535, 256), ['f'], 65535, 256),
    # the user's image: an SDFS 1440 x 512 disk formatted again
    'f-user720k': (ROOT / 'media' / 'b1440_512.atr', ['f'], 1440, 512),
    # Z through every size and Advanced back to 180K, on a 720 x 256 image
    'z-180k': ((720, 256), ['z'] * 8 + ['f'], 720, 256),
    # Z to 720K on a 720 x 256 image: the drive takes the new geometry
    'z-720k': ((720, 256), ['z', 'z', 'f'], 1440, 512),
    # B: build the directory on what the drive holds
    'b-16m': ((65535, 256), ['b'], 65535, 256),
    # Mode EOS (M twice): EOSFS (docs/EOSFS.md)
    'e-180k': ((720, 256), ['m', 'm', 'f'], 720, 256),
    'e-720k': ((1440, 512), ['m', 'm', 'f'], 1440, 512),
    'e-16m': ((65535, 256), ['m', 'm', 'b'], 65535, 256),
    'b-8000': ((8000, 256), ['b'], 8000, 256),
    # the skew (S): Ultra Speed on Altirra's US Doubler (its format command
    # with a sector order, $66), High Speed on its XF551 ($A1); the disk
    # command log must show the command
    's-us-180k': ((720, 256), ['s', 's', 'f'], 720, 256, ('usdoubler', '66')),
    's-xf-180k': ((720, 256), ['s', 'f'], 720, 256, ('xf551', 'A1')),
}


REAL = False
MEM = '64K'


def run(name, case):
    img, keys, total, seclen = case[:4]
    emul, want_cmd = case[4] if len(case) > 4 else (None, None)
    OUT.mkdir(parents=True, exist_ok=True)
    log = OUT / (name + '-cmd.log')
    log.unlink(missing_ok=True)
    old = {k: os.environ.get(k) for k in ('EOS_DISKEMU', 'EMU_DBG')}
    if emul:
        os.environ['EOS_DISKEMU'] = emul
        os.environ['EMU_DBG'] = '.logopen %s|lfe diskcmd|bp $%04X ".logclose; g"' % (
            emu.win(log), t.label('k_prompt'))
    try:
        return run1(name, img, keys, total, seclen, want_cmd, log)
    finally:
        for k, v in old.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def run1(name, img, keys, total, seclen, want_cmd, log):
    d1 = t.disk(name + '-d1', {'AUTOEXEC.BAT': emu.atascii(['FORMAT'])})
    d2 = OUT / (name + '.atr')
    if isinstance(img, tuple):
        emu.blank_atr(d2, *img)
    else:
        d2.write_bytes(Path(img).read_bytes())
    mem = OUT / (name + '.bin')
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (t.label('k_prompt'), emu.win(mem))]
    with emu.Session(OUT, [d1, d2], cart=t.CAR, name=name, turbo=True, debugcmds=cmds,
                     real=REAL, memsize=MEM):
        time.sleep(10)
        wid = emu.window_id()
        emu.keys(wid, 'u', '2')
        time.sleep(4)
        emu.screenshot(OUT / (name + '-menu.png'))
        for k in keys:
            emu.keys(wid, k)
            time.sleep(1)
        time.sleep((20 if total > 3000 else 10) * (6 if REAL else 1))
        emu.screenshot(OUT / (name + '-done.png'))
        emu.keys(wid, 'Escape')
        time.sleep(1)
        emu.keys(wid, 'Escape')
        m = t.wait_dump(mem, 20)
    shown = [s for s in t.screen(m) if s] if m else ['<no dump>']
    (OUT / (name + '.txt')).write_text('\n'.join(shown) + '\n')
    try:
        v = sdfs.Volume(str(d2))
        v.check()
    except sdfs.SdfsError as e:
        return False, 'not SDFS: %s' % e
    if v.errors:
        return False, 'check: %s' % v.errors[0]
    if v.eosfs != name.startswith('e-'):
        return False, 'EOSFS %s, want %s' % (v.eosfs, name.startswith('e-'))
    if (v.total, v.seclen) != (total, seclen):
        return False, 'size %d x %d, want %d x %d' % (v.total, v.seclen, total, seclen)
    want = [s for s in shown if s.strip().startswith('Free')]
    if not want or int(want[-1].split()[-1]) != v.free:
        return False, 'free on disk %d, shown %r' % (v.free, want)
    if want_cmd:
        cmds = log.read_text(errors='replace') if log.exists() else ''
        if 'Unit 32, Command %s' % want_cmd not in cmds:
            return False, 'no format command $%s in the disk log' % want_cmd
        return True, '%d x %d, %d free, formatted with $%s' % (v.total, v.seclen, v.free,
                                                               want_cmd)
    return True, '%d x %d, %d free' % (v.total, v.seclen, v.free)


def main():
    global REAL, MEM
    args = sys.argv[1:]
    if '--real' in args:
        args.remove('--real')
        REAL = True
    if '--mem' in args:
        i = args.index('--mem')
        MEM = args[i + 1]
        del args[i:i + 2]
    names = args or list(CASES)
    fails = 0
    for n in names:
        t0 = time.monotonic()
        ok, why = run(n, CASES[n])
        fails += not ok
        print('%-12s %s %4ds  %s' % (n, 'PASS' if ok else 'FAIL', time.monotonic() - t0, why),
              flush=True)
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
