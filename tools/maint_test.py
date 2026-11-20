#!/usr/bin/env python3
"""The EOS maintenance disk (build/EOSMAINT.atr, tools/mkmaint.py) in
Altirra: EOS (EOS.car, 320K) starts from it with its EOSSYS.SYS, which must
install no RAM disk, and every program on it runs.

usage: maint_test.py

A copy of the disk gets a test EOSAUTO.BAT (the disk's own only shows
README.TXT): U1MBCHK and MD5 on the image, FORMAT /QQ on a blank D2:, DIR,
MEMINFO, MACH, APT (no hard disk here: no table may be listed; its I/O error goes to the
screen), U1MBFLSH (no U1MB
here: it must refuse), DIR O: (no RAM disk: it must fail), each into a file
that the host reads afterwards. The real installation on a U1MB with the
same EOSSYS.SYS is tested by tools/u1mb_test.py (flash-*).
"""
import hashlib
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import sdfs  # noqa: E402

OUT = emu.BUILD / 'maint'
DISK = emu.BUILD / 'EOSMAINT.atr'
BATCH = ['TYPE README.TXT', 'U1MBCHK EOS_U1MB.ROM >>T1.TXT', 'MD5 EOS_U1MB.ROM >>T2.TXT',
         'FORMAT /QQ D2: TEST', 'DIR D2: >>T3.TXT', 'MEMINFO >>T4.TXT', 'MACH >>T5.TXT',
         'APT >>T6.TXT', 'U1MBFLSH EOS_U1MB.ROM >>T7.TXT', 'DIR O: >>T8.TXT',
         'ECHO DONE >>DONE.TXT']


def main():
    emu.ensure_display()
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    d1 = OUT / 'd1.atr'
    shutil.copyfile(DISK, d1)
    sdfs.overwrite(str(d1), 'EOSAUTO.BAT', emu.atascii(BATCH))
    d2 = OUT / 'd2.atr'
    emu.blank_atr(d2, 720, 256)
    with emu.Session(OUT, [d1, d2], cart=emu.BUILD / 'EOS.car', name='maint', turbo=True,
                     memsize='320K') as s:
        done = s.wait(0, 'DONE.TXT', 240)
    t = {n: emu.text(emu.extract(d1, n + '.TXT', OUT / 'x') or b'') for n in
         ('T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8')}
    (OUT / 'outputs.txt').write_text('\n'.join('== %s\n%s' % kv for kv in t.items()))
    flat = {k: ' '.join(v.split()) for k, v in t.items()}
    e = []
    md5 = hashlib.md5((emu.BUILD / 'EOS_U1MB.rom').read_bytes()).hexdigest()
    checks = [
        (done, 'the batch did not finish (see %s)' % (OUT / 'maint.png')),
        ('common reset tail OK' in flat['T1'], 'U1MBCHK %r' % flat['T1']),
        (md5 in flat['T2'].lower(), 'MD5 %r (want %s)' % (flat['T2'], md5)),
        ('TEST' in flat['T3'] and 'FREE SECTORS' in flat['T3'], 'FORMAT/DIR D2: %r' % flat['T3'][:80]),
        (bool(flat['T4']), 'no MEMINFO output'),
        (bool(flat['T5']), 'no MACH output'),
        ('APT on unit' not in flat['T6'], 'APT listed a table without a disk %r' % flat['T6']),
        ('No Ultimate 1MB found' in flat['T7'], 'U1MBFLSH without a U1MB %r' % flat['T7']),
        ('X Disk O' not in flat['T8'], 'a RAM disk was installed %r' % flat['T8']),
    ]
    e = [msg for ok, msg in checks if not ok]
    print('maint    %s  %s' % ('FAIL' if e else 'PASS', ', '.join(e) or
          'EOS started from EOSMAINT.atr (no RAM disk); U1MBCHK, MD5 (matches), FORMAT /QQ and '
          'DIR on D2:, MEMINFO, MACH, APT and U1MBFLSH refusing without the hardware'))
    return 1 if e else 0


if __name__ == '__main__':
    sys.exit(main())
