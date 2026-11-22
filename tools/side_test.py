#!/usr/bin/env python3
"""EOS on the flash cartridges with storage of their own, in Altirra: SIDE,
SIDE2, MyIDE II and SIDE3, each with its build/EOS_<NAME>.rom as the
device's flash (make flash). Each boots to EOS's prompt (no cartridge in
the slot), runs its startup batch from D1: (a file copied, a CAR: file read
from the flash's banks, BASIC entered and left with DOS: the cartridge off
and on again), survives a warm reset and reads the file back.

With a CompactFlash card (SIDE, SIDE2, MyIDE II: "<name>-cf"): an APT
table at LBA 0 maps a 512-byte SDFS partition to D2:; EOS's own driver
(eos/ide.icl) lists it, reads a file, writes one, and APT shows the table;
the host checks the partition afterwards.

usage: side_test.py [name ...]      (default: all)

Needs what tools/emu.py needs.
"""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import eos_test as T  # noqa: E402
import sdfs  # noqa: E402
import apt  # noqa: E402

OUT = emu.BUILD / 'side'
# name: the device's tag (and firmware type), its image, its build
CARTS = {
    'side': ('side', 'EOS_SIDE.rom'),
    'side2': ('side2', 'EOS_SIDE2.rom'),
    'myide2': ('myide2', 'EOS_MYIDE2.rom'),
    'side3': ('side3', 'EOS_SIDE3.rom'),
}
PAYLOAD = b'FLASH CART WRITE OK\x9bwritten by EOS\x9b'
BASIC = ['10 PRINT "BASIC";" OK"', '20 DOS', 'RUN']


def label(name, sym):
    for line in (emu.BUILD / name / 'kernel.lab').read_text().splitlines():
        f = line.split()
        if len(f) == 3 and f[2].upper() == sym.upper():
            return int(f[1], 16)
    raise KeyError(sym)


def run(name):
    tag, rom = CARTS[name]
    rom = emu.BUILD / rom
    if not rom.exists():
        return ['no %s (make flash)' % rom]
    e = []
    tree = OUT / (name + '-tree')
    shutil.rmtree(tree, ignore_errors=True)
    tree.mkdir(parents=True)
    (tree / 'WRITE.IN').write_bytes(PAYLOAD)
    (tree / 'GO.TXT').write_bytes(emu.atascii(BASIC))
    (tree / 'EOSAUTO.BAT').write_bytes(emu.atascii(['COPY WRITE.IN WRITE.OUT',
                                                     'TYPE CAR:ALIASES.INI',
                                                     'BASIC /I <<D1:GO.TXT']))
    atr = OUT / (name + '.atr')
    emu.mkatr(atr, tree, ['EOSAUTO.BAT', 'WRITE.IN', 'GO.TXT'], 92160)
    mem = OUT / (name + '.bin')
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (label(name, 'k_prompt'), emu.win(mem))]
    with emu.Session(OUT, [atr], cart=None, name=name, turbo=True, debugcmds=cmds,
                     devices=[{'tag': tag}], firmware={tag: rom}):
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
    check(any('EOS' in s and 'Extendable' in s for s in first), 'no EOS banner', e)
    check('XCOPY=COPY /R' in first, 'CAR:ALIASES.INI not read', e)
    check('BASIC OK' in first, 'BASIC did not run (or EOS did not come back)', e)
    check('FLASH CART WRITE OK' in after, 'WRITE.OUT not read after the warm reset', e)
    vol = sdfs.Volume(str(atr))
    files = dict((n, en.get('data')) for n, en in vol.check())
    check(not vol.errors and files.get('/WRITE.OUT') == PAYLOAD, 'D1:WRITE.OUT on the host', e)
    return e


CF_SECTORS = 8192
PART_START, PART_SIZE = 64, 2048
CF_PAYLOAD = b'CF WRITE OK\x9bwritten through EOS\'s own driver\x9b'


def cf_image(path):
    part = OUT / 'cf-part.atr'
    sdfs.build(str(part), PART_SIZE, 512, {'HELLO.TXT': b'CF PARTITION READ OK\x9b'})
    raw = part.read_bytes()[16:]
    img = bytearray(CF_SECTORS * 512)
    img[:512] = apt.new_table([{'start': PART_START, 'size': PART_SIZE}], {2: 1})
    img[PART_START * 512:PART_START * 512 + len(raw)] = raw
    path.write_bytes(img)


def part_files(path):
    raw = path.read_bytes()[PART_START * 512:(PART_START + PART_SIZE) * 512]
    size = len(raw)
    hdr = bytes([0x96, 0x02, (size >> 4) & 0xFF, (size >> 12) & 0xFF, 0x00, 0x02,
                 size >> 20]) + bytes(9)
    atr = OUT / 'cf-after.atr'
    atr.write_bytes(hdr + raw)
    vol = sdfs.Volume(str(atr))
    return vol.errors, dict((n, en.get('data')) for n, en in vol.check())


def run_cf(name):
    tag, rom = CARTS[name]
    rom = emu.BUILD / rom
    hd = OUT / (name + '-cf.img')
    cf_image(hd)
    tree = OUT / (name + '-cf-tree')
    shutil.rmtree(tree, ignore_errors=True)
    tree.mkdir(parents=True)
    (tree / 'WRITE.IN').write_bytes(CF_PAYLOAD)
    (tree / 'Y.TXT').write_bytes(emu.atascii(['Y']))
    (tree / 'MST.COM').write_bytes((emu.BUILD / 'eos' / 'MST.COM').read_bytes())
    (tree / 'EOSAUTO.BAT').write_bytes(emu.atascii(['DIR D2:', 'TYPE D2:HELLO.TXT',
                                                     'COPY WRITE.IN D2:WRITE.OUT',
                                                     'TYPE D2:WRITE.OUT', 'APT',
                                                     'APT NEW 512K <<Y.TXT >>N.TXT',
                                                     'APT >>T.TXT', 'MST >>M.TXT']))
    atr = OUT / (name + '-cf.atr')
    emu.mkatr(atr, tree, ['EOSAUTO.BAT', 'WRITE.IN', 'Y.TXT', 'MST.COM'], 92160)
    mem = OUT / (name + '-cf.bin')
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (label(name, 'k_prompt'), emu.win(mem))]
    dev = [{'tag': tag, 'buses': {'0': {'children': [{'tag': 'harddisk', 'params': {
        'path': emu.win(hd), 'write_enabled': True, 'solid_state': True,
        'sectors': CF_SECTORS}}]}}}]
    with emu.Session(OUT, [atr], cart=None, name=name + '-cf', turbo=True, debugcmds=cmds,
                     devices=dev, firmware={tag: rom}):
        m = T.wait_dump(mem, 90)
        emu.screenshot(OUT / (name + '-cf.png'))
    if m is None:
        return ['no EOS prompt (see %s)' % (OUT / (name + '-cf.png'))]
    lines = T.screen(m)
    e = []
    check = T.check
    check(any('HELLO    TXT' in x for x in lines), 'DIR D2: shows no HELLO.TXT', e)
    check('CF PARTITION READ OK' in lines, 'TYPE D2:HELLO.TXT', e)
    check('CF WRITE OK' in lines, 'D2:WRITE.OUT not read back', e)
    check(any(x.startswith('APT on unit 1, table at LBA 0') for x in lines) and
          any(x.startswith('D2: partition 1') for x in lines), 'APT shows no table', e)
    vol = sdfs.Volume(str(atr))
    d1 = dict((n, en.get('data')) for n, en in vol.check())
    after = (d1.get('/T.TXT') or b'').decode('latin-1').split('\x9b')
    check(any(x.split()[:2] == ['2', 'DOS'] and x.split()[3:5] == ['1024', '512']
              for x in after), 'APT NEW (DEVINFO, a table write): %r' % after[-4:], e)
    ms = (d1.get('/M.TXT') or b'').decode('latin-1').split('\x9b')
    check('MS READ OK' in ms and 'MS WRITE OK' in ms,
          'multi-sector requests (E2): %r' % ms[:3], e)
    errors, files = part_files(hd)
    check(not errors, 'partition: %s' % '; '.join(errors[:3]), e)
    check(files.get('/WRITE.OUT') == CF_PAYLOAD, 'WRITE.OUT on the partition differs', e)
    return e


def main():
    emu.ensure_display()
    OUT.mkdir(parents=True, exist_ok=True)
    failed = 0
    for name in sys.argv[1:] or list(CARTS) + ['side-cf', 'side2-cf', 'myide2-cf', 'side3-cf']:
        e = run_cf(name[:-3]) if name.endswith('-cf') else run(name)
        print('%-10s %s  %s' % (name, 'FAIL' if e else 'PASS', ', '.join(e) or (
              'APT partition as D2: (EOS\'s driver): DIR, TYPE, COPY to it, read back, '
              'APT, APT NEW 512K (DEVINFO, table written), multi-sector reads and writes; '
              'partition checked on the host' if name.endswith('-cf') else
              'prompt, batch file, CAR: file read, BASIC and back, file written; '
              'read again after a warm reset')), flush=True)
        failed += bool(e)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
