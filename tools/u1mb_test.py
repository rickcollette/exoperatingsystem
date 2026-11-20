#!/usr/bin/env python3
"""EOS_U1MB.rom installed in the U1MB SDX slot of Altirra's Ultimate1MB and
booted from it.

usage: u1mb_test.py [slot] [flash-A29040] [flash-SST39SF040] [refuse] [protected] [cart]

cart: the first installation without SDX: an empty SDX slot, the U1MB's SDX
off and its cartridge port on, EOS.car (Maxflash) in it; U1MBFLSH from that
EOS writes the slot and the machine restarts into it.

The emulated U1MB's 512 KiB flash is composed on the host (build/u1mb-fw):
  $00000-$4FFFF  the SDX slot: build/EOS_U1MB.rom (40 banks of 8 KiB)
  $50000-$53FFF  tests/u1mb/boot.asm: a boot stub, not the U1MB BIOS: SDX
                 module on at bank 0, the configuration locked
  $70000-$73FFF  AltirraOS for XL/XE, assembled by MADS from the Altirra
                 source tree (ALTIRRA_SRC, default ../ALTIRRA_ORIGINAL)
and loaded as Altirra's U1MB firmware, with no cartridge. EOS must reach
its prompt from the slot (DOSVEC, banner), run its startup batch (a file
copied on D1:, a CAR: file read from the slot's banks), and reach the
prompt again after a warm reset, where the copied file is read back; the
host then checks the disk. Altirra's ".ultimate" status is logged to
build/u1mb-fw/u1mb.log.

The AtariMax EOS.car on a U1MB with the SDX module off is not tested: in
Altirra the U1MB's SDX register write ($D5E0) reaches the cartridge port as
well, and a Maxflash 1 Mb cartridge takes any write to $D580-$D5FF as
"cartridge off", so the OS never sees it.

This tests EOS's bank switching through the U1MB SDX register and its
reset path, not the U1MB BIOS's menu, flashing or configuration storage.
Needs what tools/emu.py needs, mads, and make u1mb.
"""
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import eos_test as T  # noqa: E402
import sdfs  # noqa: E402

OUT = emu.BUILD / 'u1mb-fw'
ROM = emu.BUILD / 'EOS_U1MB.rom'
ALTIRRA_SRC = Path(os.environ.get('ALTIRRA_SRC', emu.ROOT.parent / 'ALTIRRA_ORIGINAL'))
MADS = os.environ.get('MADS', 'mads')
LABELS = emu.BUILD / 'u1mb'
PAYLOAD = b'U1MB SLOT WRITE OK\x9bwritten by EOS from the U1MB SDX slot\x9b'


def label(name):
    for line in (LABELS / 'kernel.lab').read_text().splitlines():
        f = line.split()
        if len(f) == 3 and f[2].upper() == name.upper():
            return int(f[1], 16)
    raise KeyError(name)


def build_firmware(protect=False, extcart=False):
    OUT.mkdir(parents=True, exist_ok=True)
    kernel = OUT / 'kernelxl.rom'
    ksrc = ALTIRRA_SRC / 'src' / 'Kernel'
    if not kernel.exists():
        if not (ksrc / 'source' / 'main.xasm').exists():
            raise RuntimeError('no AltirraOS source at %s (set ALTIRRA_SRC)' % ksrc)
        subprocess.run([MADS, '-i:autobuild', '-i:autobuild_default', '-d:_KERNEL_XLXE=1', '-s',
                        '-p', '-i:source/Shared', '-b:$c000', '-o:' + str(kernel),
                        'source/main.xasm'], cwd=ksrc, check=True, capture_output=True)
    tag = 'wp' if protect else 'ext' if extcart else ''
    stub = OUT / ('boot%s.bin' % ('-' + tag if tag else ''))
    subprocess.run([MADS, 'boot.asm', '-s', '-o:' + str(stub)] +
                   (['-d:PROTECT=1'] if protect else []) + (['-d:EXTCART=1'] if extcart else []),
                   cwd=emu.ROOT / 'tests' / 'u1mb', check=True, capture_output=True)
    eos = ROM.read_bytes()
    k, b = kernel.read_bytes(), stub.read_bytes()
    if len(eos) != 0x50000 or len(k) != 0x4000 or len(b) != 0x4000:
        raise RuntimeError('sizes: EOS %d, OS %d, stub %d' % (len(eos), len(k), len(b)))
    fw = bytearray(b'\xff' * 0x80000)
    fw[0:0x50000] = eos
    fw[0x50000:0x54000] = b
    fw[0x70000:0x74000] = k
    path = OUT / ('u1mb-%s.rom' % (tag or 'eos'))
    path.write_bytes(fw)
    return path


def boot_disk(name, batch, files):
    import shutil
    tree = OUT / (name + '-tree')
    shutil.rmtree(tree, ignore_errors=True)
    tree.mkdir()
    for f, data in files.items():
        (tree / f).write_bytes(data)
    (tree / 'EOSAUTO.BAT').write_bytes(emu.atascii(batch))
    atr = OUT / (name + '.atr')
    emu.mkatr(atr, tree, ['EOSAUTO.BAT'] + list(files), 92160)
    return atr


def run(name, fw, cart, k_getline):
    """Boot, startup batch, warm reset, TYPE WRITE.OUT: (first, after, status, atr)."""
    atr = boot_disk(name, ['COPY WRITE.IN WRITE.OUT', 'TYPE CAR:ALIASES.INI'],
                    {'WRITE.IN': PAYLOAD})
    mem = OUT / (name + '.bin')
    mem.unlink(missing_ok=True)
    log = OUT / (name + '.log')
    log.unlink(missing_ok=True)
    cmds = ['.logopen %s' % emu.win(log),
            'bp $%04X ".writemem %s 0 L10000; .ultimate; .logclose; g"' % (k_getline, emu.win(mem))]
    with emu.Session(OUT, [atr], cart=cart, name=name, turbo=True, debugcmds=cmds,
                     ultimate1mb=True, firmware={'u1mb': fw}):
        m = T.wait_dump(mem, 90)
        if m is None:
            emu.screenshot(OUT / (name + '.png'))
            return None, [], '', atr
        mem.unlink()
        wid = emu.window_id()
        emu.keys(wid, 'F5')
        m2 = T.wait_dump(mem, 60)
        if m2 is not None:
            mem.unlink()
            emu.type_line(wid, 'TYPE WRITE.OUT')
            m2 = T.wait_dump(mem, 60)
        emu.screenshot(OUT / (name + '.png'))
    status = log.read_text(errors='replace') if log.exists() else ''
    return m, T.screen(m2) if m2 else [], status, atr


def checks(m, after, status, atr, e):
    check = T.check
    first = T.screen(m)
    check(T.word(m, 0x0A) == 0x0A3A, 'DOSVEC $%04X' % T.word(m, 0x0A), e)
    check(any('EOS' in s and 'Extendable' in s for s in first), 'no EOS banner', e)
    check(any(s == 'D1:' for s in first), 'no prompt', e)
    check('XCOPY=COPY /R' in first, 'CAR:ALIASES.INI not read', e)
    check('U1MB SLOT WRITE OK' in after, 'WRITE.OUT not read after the warm reset', e)
    check('Ultimate1MB is not active' not in status and 'Cartridge bank' in status,
          'U1MB not active in Altirra', e)
    vol = sdfs.Volume(str(atr))
    files = dict((n, en.get('data')) for n, en in vol.check())
    check(not vol.errors and files.get('/WRITE.OUT') == PAYLOAD, 'D1:WRITE.OUT on the host', e)


def t_slot():
    e = []
    fw = build_firmware()
    m, after, status, atr = run('slot', fw, None, label('k_getline'))
    if m is None:
        e.append('no EOS prompt from the SDX slot (see %s)' % (OUT / 'slot.png'))
    else:
        T.check('(enabled)' in status.split('Cartridge bank')[-1].split('\n')[0],
                'SDX cartridge bank not enabled', e)
        checks(m, after, status, atr, e)
    return e, ('EOS_U1MB.rom from the U1MB SDX slot: prompt, batch file, CAR: file read, '
               'file written; prompt and file read again after a warm reset')


def t_flash(chip, mode='write'):
    """U1MBFLSH (EOS Toolkit) writes a changed EOS image into the SDX area of
    the running machine: the banner differs, the unused banks held junk
    before; afterwards the machine restarts into the new image and the
    saved flash holds it at $00000-$4FFFF and the rest unchanged."""
    import time
    import ideplus_test as IDE
    name = 'flash-' + chip if mode == 'write' else mode
    fw0 = bytearray(build_firmware(protect=(mode == 'protected'),
                                   extcart=(mode == 'cart')).read_bytes())
    old = ROM.read_bytes()
    for b in range(25, 40):                   # junk where the new image is erased
        fw0[b * 0x2000:b * 0x2000 + 0x1F00] = bytes([0x5A]) * 0x1F00
    if mode == 'cart':                        # a first installation: no EOS in
        fw0[0:0x50000] = b'\xff' * 0x50000    # the slot; EOS.car starts
    fwp = OUT / (name + '-before.rom')
    fwp.write_bytes(fw0)
    new = bytearray(old)                      # "EOS 0.F": the new image
    at = new.find(b'EOS 0.1 Extendable')
    if at < 0:
        return ['no banner in %s' % ROM], ''
    while at >= 0:
        new[at + 6] = ord('F')
        at = new.find(b'EOS 0.1 Extendable', at + 1)
    flsh = emu.BUILD / 'etk' / 'U1MBFLSH.COM'
    if not flsh.exists():
        return ['no %s (make toolkit)' % flsh], ''
    import shutil
    tree = OUT / (name + '-tree')
    shutil.rmtree(tree, ignore_errors=True)
    tree.mkdir()
    (tree / 'NEW.ROM').write_bytes(bytes(new))
    (tree / 'U1MBFLSH.COM').write_bytes(flsh.read_bytes())
    (tree / 'YES.TXT').write_bytes(b'Y\x9b')
    (tree / 'NO.TXT').write_bytes(b'N\x9b')
    files = ['U1MBFLSH.COM', 'YES.TXT', 'NO.TXT', 'NEW.ROM']
    if mode == 'refuse':                      # U1MBCHK on the same image
        (tree / 'U1MBCHK.COM').write_bytes((emu.BUILD / 'etk' / 'U1MBCHK.COM').read_bytes())
        (tree / 'EOSAUTO.BAT').write_bytes(emu.atascii(['U1MBCHK NEW.ROM >>C1.TXT']))
        files += ['U1MBCHK.COM', 'EOSAUTO.BAT']
    if mode != 'refuse':                      # (refuse: the default RAM disk)
        (tree / 'EOSSYS.SYS').write_bytes(emu.atascii(['DEVICE RTIME8']))   # no RAM disk
        files.insert(0, 'EOSSYS.SYS')
    atr = OUT / (name + '.atr')
    emu.mkatr(atr, tree, files, 1048576)
    mem = OUT / (name + '.bin')
    mem.unlink(missing_ok=True)
    after = OUT / (name + '-after.rom')
    junk = OUT / (name + '-start.rom')
    for f in (after, junk):
        f.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; .autotest_cmd System.SaveFirmwareU1MB; g"'
            % (label('k_getline'), emu.win(mem))]
    e = []
    with emu.Session(OUT, [atr], cart=T.CAR if mode == 'cart' else None, name=name,
                     turbo=True, debugcmds=cmds, ultimate1mb=True, firmware={'u1mb': fwp},
                     u1mb_flash=chip, extra_args=['/autotest']):
        m = T.wait_dump(mem, 90)
        if m is None:
            return ['no EOS prompt before flashing'], ''
        mem.unlink()
        IDE.save_dialog(junk)
        time.sleep(2)
        wid = emu.window_id()
        if mode == 'refuse':                  # the default RAM disk: too few banks
            emu.type_keys(wid, 'U1MBFLSH NEW.ROM >>R1.TXT')
        else:
            emu.type_keys(wid, 'U1MBFLSH NEW.ROM <<YES.TXT')
        if mode == 'protected':               # it stops; RESET: the old EOS
            time.sleep(60)
            emu.screenshot(OUT / (name + '-halt.png'))
            emu.keys(emu.window_id(), 'F5')
        m = T.wait_dump(mem, 400)
        if m is None:
            emu.screenshot(OUT / (name + '.png'))
            return ['no EOS prompt after U1MBFLSH (see %s)' % (OUT / (name + '.png'))], ''
        IDE.save_dialog(after)
        for _ in range(20):
            if after.exists() and after.stat().st_size == 0x80000:
                break
            time.sleep(1)
        emu.screenshot(OUT / (name + '.png'))
    lines = T.screen(m)
    if mode not in ('write', 'cart'):         # nothing written, the old EOS
        T.check(any('EOS 0.1 Extendable' in s for s in lines), 'old EOS not running: %r'
                % lines[:4], e)
        if mode == 'refuse':
            r1 = emu.text(emu.extract(atr, 'R1.TXT', OUT / 'x') or b'')
            T.check('Needs 20 free extended banks' in r1, 'RAM disk not refused: %r' % r1, e)
            c1 = emu.text(emu.extract(atr, 'C1.TXT', OUT / 'x') or b'')
            T.check('common reset tail OK' in c1, 'U1MBCHK: %r' % c1, e)
        if not after.exists():
            e.append('flash not saved')
        else:
            T.check(after.read_bytes() == bytes(fw0), 'the flash changed', e)
        return e, ('U1MBCHK accepts the image; U1MBFLSH refused: too few free banks with '
                   'the RAM disk installed; flash unchanged' if mode == 'refuse' else
                   'U1MBFLSH with flash writes protected: stopped before erasing; after RESET '
                   'the old EOS starts and the flash is unchanged')
    T.check(any('EOS 0.F Extendable' in s for s in lines), 'not restarted into the new image: %r'
            % lines[:4], e)
    if not after.exists():
        e.append('flash not saved')
    else:
        a = after.read_bytes()
        T.check(a[:0x50000] == bytes(new), 'SDX area differs from the image at %s' % next(
            (hex(i) for i in range(0x50000) if a[i] != new[i]), None), e)
        T.check(a[0x50000:] == bytes(fw0[0x50000:]), 'BIOS/BASIC/OS area changed', e)
    return e, ('U1MBFLSH with a %s: image loaded, chip identified, SDX area erased and '
               'written, restarted into the new image; saved flash: $00000-$4FFFF the image, '
               '$50000-$7FFFF unchanged' % chip)


def main():
    emu.ensure_display()
    names = sys.argv[1:] or ['slot', 'flash-A29040', 'flash-SST39SF040', 'refuse', 'protected',
                             'cart']
    failed = 0
    for n in names:
        if n == 'slot':
            e, what = t_slot()
        elif n in ('refuse', 'protected', 'cart'):
            e, what = t_flash('A29040', n)
        else:
            e, what = t_flash(n.split('-', 1)[1])
        print('%-18s %s  %s' % (n, 'FAIL' if e else 'PASS', ', '.join(e) or what), flush=True)
        failed += bool(e)
    return 1 if failed else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        sys.exit('u1mb_test: %s' % exc)
