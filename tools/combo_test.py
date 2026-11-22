#!/usr/bin/env python3
"""EOS from the U1MB SDX slot with an IDE2.0PLUS: the U1MB's RAM disk and
clock and the IDE2.0PLUS's storage together, in Altirra.

usage: combo_test.py

The machine: Altirra's Ultimate1MB (1088K) with the flash composed by
tools/u1mb_test.py (build/EOS_U1MB.rom in the SDX slot), and an IDE2.0PLUS
whose flash is build/ideplus/ide-main.rom (BIOS 2.1, written by EOS running
BIOS21.COM: tools/ideplus_test.py flash) with a disposable disk: APT, the
partition mapped to D2:. No cartridge; fast boot off (see ideplus_test).

The startup batch reads the U1MB clock (DATE, TIME: DEVICE RTIME8 takes it
when there is no R-Time 8), uses the default RAM disk O: in the U1MB's
extended memory, copies between the RAM disk, D1: and the IDE partition,
lists D2: and the APT table. After a warm reset the RAM disk and D2: are
read again. The host checks the date, the partition's files and D1:.

Not checked: setting the clock (Altirra's DS1305 always reads the host's
time), the U1MB BIOS's own setup and PBI BIOS, real hardware.
"""
import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import eos_test as T  # noqa: E402
import sdfs  # noqa: E402
import ideplus_test as IDE  # noqa: E402
import u1mb_test as U  # noqa: E402

OUT = emu.BUILD / 'combo'
PAYLOAD = b'U1MB RAMDISK TO IDE OK\x9bthrough O: to D2:\x9b'


def main():
    emu.ensure_display()
    OUT.mkdir(parents=True, exist_ok=True)
    if not IDE.ROM.exists():
        print('combo    FAIL  no %s (run tools/ideplus_test.py flash)' % IDE.ROM)
        return 1
    fw = U.build_firmware()
    hd = OUT / 'hd.img'
    table = IDE.hd_image(hd)
    atr = U.boot_disk('combo', ['DATE <<NL.TXT >>DATE.TXT', 'TIME <<NL.TXT >>TIME.TXT',
                                'COPY WRITE.IN O:RD.TXT', 'COPY O:RD.TXT D2:FROMRD.TXT',
                                'DIR D2: >>DIR.TXT', 'APT >>APT.TXT', 'DIR O: >>RDDIR.TXT',
                                'ECHO DONE'], {'WRITE.IN': PAYLOAD, 'NL.TXT': b'\x9b'})
    (OUT / 'combo.atr').write_bytes(atr.read_bytes())
    atr = OUT / 'combo.atr'
    mem = OUT / 'combo.bin'
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (U.label('k_prompt'), emu.win(mem))]
    host_before = datetime.datetime.now()
    with emu.Session(OUT, [atr], cart=None, name='combo', turbo=True, debugcmds=cmds,
                     ultimate1mb=True, devices=IDE.ide_device(hd), fastboot=False,
                     firmware={'u1mb': fw, 'kmkjzide2': IDE.ROM}):
        m = T.wait_dump(mem, 180)
        if m is None:
            emu.screenshot(OUT / 'combo.png')
            print('combo    FAIL  no EOS prompt (see %s)' % (OUT / 'combo.png'))
            return 1
        first = T.screen(m)
        mem.unlink()
        wid = emu.window_id()
        emu.keys(wid, 'F5')
        after = []
        for cmd in ('TYPE O:RD.TXT', 'TYPE D2:FROMRD.TXT'):
            if T.wait_dump(mem, 60) is None:
                break
            mem.unlink()
            emu.type_keys(wid, cmd)
        m2 = T.wait_dump(mem, 60)
        after = T.screen(m2) if m2 else []
        emu.screenshot(OUT / 'combo.png')
    e = []
    check = T.check
    read = lambda n: emu.text(emu.extract(atr, n, OUT / 'x') or b'')
    date, tm, d2dir, apt, rddir = (read(n) for n in ('DATE.TXT', 'TIME.TXT', 'DIR.TXT',
                                                     'APT.TXT', 'RDDIR.TXT'))
    (OUT / 'outputs.txt').write_text('\n'.join(('DATE', date, 'TIME', tm, 'DIR D2:', d2dir,
                                                'APT', apt, 'DIR O:', rddir, 'screen',
                                                *first, 'after reset', *after)))
    check('R-Time 8 not present' not in first, 'the U1MB clock was not taken', e)
    days = {host_before.date(), datetime.datetime.now().date()}
    want = ['%02d-%02d-%02d' % (d.day, d.month, d.year % 100) for d in days] + \
           ['%d-%02d-%02d' % (d.day, d.month, d.year % 100) for d in days]
    check(any(w in date for w in want), 'DATE %r is not the host date %s' % (date.strip(), want), e)
    check(any(c.isdigit() for c in tm), 'TIME output %r' % tm.strip(), e)
    check('RD       TXT' in rddir, 'RAM disk O: listing %r' % rddir[:80], e)
    import re
    free = re.search(r'(\d+) FREE SECTORS', rddir)
    # 1088K: 64 banks, four kept for programs, 64 sectors of 256 bytes each
    check(free and int(free.group(1)) > 3000, 'RAM disk O: is small for 1088K: %r'
          % (free.group(0) if free else rddir[-60:]), e)
    check('FROMRD   TXT' in d2dir, 'D2: listing %r' % d2dir[:80], e)
    check('D2: partition 1' in apt, 'APT listing %r' % apt[:80], e)
    check('U1MB RAMDISK TO IDE OK' in after, 'files not read after the warm reset: %r'
          % after[-8:], e)
    check(after.count('U1MB RAMDISK TO IDE OK') >= 2, 'RAM disk or D2: lost at the warm reset', e)
    errors, files = IDE.partition_files(hd)
    check(not errors and files.get('/FROMRD.TXT') == PAYLOAD, 'D2:FROMRD.TXT on the host', e)
    check(hd.read_bytes()[:512] == table, 'the APT table changed', e)
    print('combo    %s  %s' % ('FAIL' if e else 'PASS', ', '.join(e) or
          'EOS from the U1MB SDX slot with IDE2.0PLUS BIOS 2.1: U1MB clock (date %s), RAM disk '
          'O: in 1088K U1MB memory, copies RAM disk -> IDE partition, APT listing, both read again '
          'after a warm reset' % (date.split(':')[1].split()[0] if ':' in date else '?')), flush=True)
    return 1 if e else 0


if __name__ == '__main__':
    sys.exit(main())
