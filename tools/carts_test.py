#!/usr/bin/env python3
"""EOS cartridge image variants in Altirra: each boots to its prompt, runs
its startup batch from D1: (a file copied, a CAR: file read from the
cartridge's banks), survives a warm reset, and reads the file back; the
host checks the disk afterwards.

usage: carts_test.py [name ...]      (default: all)

  maxflash8  build/EOS.car       AtariMax/Maxflash 8 Mbit (1 MiB), type 42
  sic        build/EOS_SIC.car   SIC! 512 KiB, CAR type 56 (make sic)
  sicplus    build/EOS_SICP.car  SIC!+ 1024 KiB, CAR type 83 (make sic)

The CAR header's type selects Altirra's cartridge emulation. Needs what
tools/emu.py needs.
"""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import eos_test as T  # noqa: E402
import sdfs  # noqa: E402

OUT = emu.BUILD / 'carts'
CARTS = {
    'maxflash8': (emu.BUILD / 'EOS.car', emu.BUILD / 'eos', 42),
    'sic': (emu.BUILD / 'EOS_SIC.car', emu.BUILD / 'sic', 56),
    'sicplus': (emu.BUILD / 'EOS_SICP.car', emu.BUILD / 'sic', 83),
}
PAYLOAD = b'CART WRITE OK\x9bwritten by EOS\x9b'


def label(labels, name):
    for line in (labels / 'kernel.lab').read_text().splitlines():
        f = line.split()
        if len(f) == 3 and f[2].upper() == name.upper():
            return int(f[1], 16)
    raise KeyError(name)


def run(name):
    car, labels, ctype = CARTS[name]
    e = []
    data = car.read_bytes()
    if data[:4] != b'CART' or int.from_bytes(data[4:8], 'big') != ctype:
        return ['%s is not a CAR image of type %d' % (car, ctype)]
    tree = OUT / (name + '-tree')
    shutil.rmtree(tree, ignore_errors=True)
    tree.mkdir(parents=True)
    (tree / 'WRITE.IN').write_bytes(PAYLOAD)
    (tree / 'EOSAUTO.BAT').write_bytes(emu.atascii(['COPY WRITE.IN WRITE.OUT',
                                                     'TYPE CAR:ALIASES.INI']))
    atr = OUT / (name + '.atr')
    emu.mkatr(atr, tree, ['EOSAUTO.BAT', 'WRITE.IN'], 92160)
    mem = OUT / (name + '.bin')
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (label(labels, 'k_getline'), emu.win(mem))]
    with emu.Session(OUT, [atr], cart=car, name=name, turbo=True, debugcmds=cmds):
        m = T.wait_dump(mem, 90)
        if m is None:
            emu.screenshot(OUT / (name + '.png'))
            return ['no EOS prompt (see %s)' % (OUT / (name + '.png'))]
        mem.unlink()
        wid = emu.window_id()
        emu.keys(wid, 'F5')
        m2 = T.wait_dump(mem, 60)
        if m2 is not None:
            mem.unlink()
            emu.type_line(wid, 'TYPE WRITE.OUT')
            m2 = T.wait_dump(mem, 60)
        emu.screenshot(OUT / (name + '.png'))
    first, after = T.screen(m), T.screen(m2) if m2 else []
    check = T.check
    check(T.word(m, 0x0A) == 0x0A3A, 'DOSVEC $%04X' % T.word(m, 0x0A), e)
    check(any('EOS' in s and 'Extendable' in s for s in first), 'no EOS banner', e)
    check('XCOPY=COPY /R' in first, 'CAR:ALIASES.INI not read', e)
    check('CART WRITE OK' in after, 'WRITE.OUT not read after the warm reset', e)
    vol = sdfs.Volume(str(atr))
    files = dict((n, en.get('data')) for n, en in vol.check())
    check(not vol.errors and files.get('/WRITE.OUT') == PAYLOAD, 'D1:WRITE.OUT on the host', e)
    return e


def main():
    emu.ensure_display()
    OUT.mkdir(parents=True, exist_ok=True)
    failed = 0
    for name in sys.argv[1:] or list(CARTS):
        e = run(name)
        print('%-10s %s  %s' % (name, 'FAIL' if e else 'PASS', ', '.join(e) or
              'CAR type %d: prompt, batch file, CAR: file read, file written; prompt and '
              'file read again after a warm reset' % CARTS[name][2]), flush=True)
        failed += bool(e)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
