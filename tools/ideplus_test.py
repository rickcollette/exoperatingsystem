#!/usr/bin/env python3
"""IDE2.0PLUS (IDE Plus 2.0) in Altirra: flash its BIOS from EOS, export the
flash, boot from the exported image and use an APT partition through it.

usage: ideplus_test.py [flash] [storage] [apt] [partition] [mapmode]   (default: all)

flash    EOS runs media/IDE2.0PLUS/BIOS21.COM (the KMK/DLT BIOS 2.1 updater) on an
         emulated IDE2.0PLUS whose flash starts erased. A breakpoint on the
         updater's key input ($2C5C) answers each question from the screen;
         at EOS's prompt afterwards Altirra's System.SaveFirmwareIDEMain
         (run by .autotest_cmd, its save dialog filled by xdotool) writes the
         128 KiB main flash to build/ideplus/ide-main.rom. The image must hold
         the PBI ROM signature and the BIOS 2.1 identification.
storage  A second session loads ide-main.rom as the device's firmware, with a
         disposable disk image: an APT table at LBA 0, partition 1 (SDFS,
         512-byte sectors) mapped to D2:. IDET.COM checks the BIOS's
         physical device ($20, also as an XDCB) and D2:'s status, PERCOM,
         sector read and DISKINFO; DIR and TYPE read D2:, COPY writes it.
         After a warm reset (F5) D2: is read again. The host then checks the
         partition's file system, the written file and the unchanged table.
partition  APT on a blank disk: INIT, NEW, MAP, DEL, and FORMAT on the new
         drives after a restart.
apt      EOS's APT command on the same device: the listing, a mapping
         change with its preview and confirmation, the table written back
         with its other bytes unchanged, and the new mapping after a cold
         start. (Skipped while the command is not built.)

Altirra's fast boot is off in the storage sessions: with it on, Altirra
answers disk SIO requests for an empty drive slot itself (a timeout) before
the OS asks the PBI devices, so the BIOS's drives would never be reached.
Everything runs on copies under build/ideplus; nothing is written to real
hardware. Needs what tools/emu.py needs, and build/EOS.car (make eos).
"""
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import eos_test as T  # noqa: E402
import sdfs  # noqa: E402
import apt  # noqa: E402

OUT = emu.BUILD / 'ideplus'
ROM = OUT / 'ide-main.rom'
UPDATER = emu.MEDIA / 'IDE2.0PLUS' / 'BIOS21.COM'
HD_SECTORS = 16384                      # an 8 MiB disposable disk
PART_START, PART_SIZE = 64, 2048
UPD_KEY = 0x2C5C                         # BIOS21.COM: its Y/N key input

# the updater's questions and EOS's answers ("Continue scanning? N" selects
# the device just found for flashing)
ANSWERS = [('Try?', 'y'), ('Continue scanning?', 'n'), ('Reflash anyway?', 'y'),
           ('Chip erase?', 'y'), ('Chip write?', 'y'), ('Retry?', 'n'),
           ('Try again?', 'n'), ('Exit to DOS?', 'y')]


def ide_device(hd, sectors=HD_SECTORS):
    return [{'tag': 'kmkjzide2',
             'params': {'enablesdx': False, 'revision': 'd', 'id': 0, 'nvramguard': True},
             'buses': {'0': {'children': [{'tag': 'harddisk', 'params': {
                 'path': emu.win(hd), 'write_enabled': True, 'solid_state': True,
                 'sectors': sectors}}]}}}]


def boot_disk(name, files, batch):
    tree = OUT / (name + '-tree')
    shutil.rmtree(tree, ignore_errors=True)
    tree.mkdir(parents=True)
    for fname, data in files.items():
        (tree / fname).write_bytes(data)
    (tree / 'EOSAUTO.BAT').write_bytes(emu.atascii(batch))
    atr = OUT / (name + '.atr')
    emu.mkatr(atr, tree, ['EOSAUTO.BAT'] + list(files), 92160)
    return atr


def check_rom(data):
    """The exported flash: errors (empty when it is a BIOS 2.1 image)."""
    e = []
    if len(data) != 0x20000:
        e.append('size %d, not 131072' % len(data))
        return e
    if data[3] != 0x80 or data[11] != 0x91:
        e.append('no PBI ROM signature ($D803=$%02X $D80B=$%02X)' % (data[3], data[11]))
    if b'[2.1]' not in data or b'IDE+2.0' not in data:
        e.append('no BIOS 2.1 identification')
    if data.count(0xFF) == len(data):
        e.append('flash still erased')
    return e


def save_dialog(path, timeout=30):
    """Fill Altirra's 'Save firmware image' dialog with path."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        p = subprocess.run(['xdotool', 'search', '--name', 'Save firmware image'],
                           capture_output=True, text=True)
        if p.stdout.split():
            time.sleep(1)
            # the dialog has the focus: XTEST input (Wine ignores --window's)
            subprocess.run(['xdotool', 'type', '--delay', '20', emu.win(path)],
                           capture_output=True)
            time.sleep(0.5)
            subprocess.run(['xdotool', 'key', 'Return'], capture_output=True)
            return True
        time.sleep(1)
    return False


def t_flash():
    hd = OUT / 'flash-hd.img'
    hd.write_bytes(bytes(HD_SECTORS * 512))
    atr = boot_disk('flash', {'BIOS21.COM': UPDATER.read_bytes()}, ['BIOS21'])
    q, mem = OUT / 'flash-q.bin', OUT / 'flash-prompt.bin'
    for f in (q, mem, ROM):
        f.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (UPD_KEY, emu.win(q)),
            'bp $%04X ".writemem %s 0 L10000; .autotest_cmd System.SaveFirmwareIDEMain; g"'
            % (T.label('k_prompt'), emu.win(mem))]
    asked = []
    with emu.Session(OUT, [atr], cart=T.CAR, name='flash', turbo=True, debugcmds=cmds,
                     devices=ide_device(hd), extra_args=['/autotest']):
        deadline = time.monotonic() + 300
        while time.monotonic() < deadline and not mem.exists():
            m = T.wait_dump(q, 3)
            if m is None:
                continue
            q.unlink()
            last = ([s for s in T.screen(m) if s] or [''])[-1]
            for question, answer in ANSWERS:
                if question in last:
                    asked.append('%s %s' % (question, answer.upper()))
                    emu.keys(emu.window_id(), answer)
                    break
            else:
                return False, 'unexpected updater screen: %r' % last
        if not mem.exists():
            return False, 'the updater did not return to EOS (%s)' % '; '.join(asked)
        saved = save_dialog(ROM)
        for _ in range(20):
            if ROM.exists() and ROM.stat().st_size == 0x20000:
                break
            time.sleep(1)
        emu.screenshot(OUT / 'flash.png')
    e = []
    if 'Chip write? Y' not in asked:
        e.append('the updater never offered to write the chip')
    if not saved:
        e.append('no save dialog')
    if not ROM.exists():
        e.append('no exported ROM')
    else:
        e += check_rom(ROM.read_bytes())
    return not e, ', '.join(e) or ('flashed and exported %s (%s)' % (ROM.name, '; '.join(asked)))


PAYLOAD = b'IDEPLUS WRITE OK\x9bwritten through the BIOS 2.1 partition\x9b'


def hd_image(path):
    part = OUT / 'part.atr'
    sdfs.build(str(part), PART_SIZE, 512, {'HELLO.TXT': b'IDEPLUS PARTITION READ OK\x9b'})
    raw = part.read_bytes()[16:]
    img = bytearray(HD_SECTORS * 512)
    img[:512] = apt.new_table([{'start': PART_START, 'size': PART_SIZE}], {2: 1})
    img[PART_START * 512:PART_START * 512 + len(raw)] = raw
    path.write_bytes(img)
    return bytes(img[:512])


def partition_files(hd, start=PART_START, count=PART_SIZE):
    """The files on a partition (sdfs.Volume on an ATR copy)."""
    img = hd.read_bytes()
    raw = img[start * 512:(start + count) * 512]
    size = len(raw)
    hdr = bytes([0x96, 0x02, (size >> 4) & 0xFF, (size >> 12) & 0xFF, 0x00, 0x02,
                 size >> 20]) + bytes(9)
    atr = OUT / 'part-after.atr'
    atr.write_bytes(hdr + raw)
    vol = sdfs.Volume(str(atr))
    entries = dict((n, e.get('data')) for n, e in vol.check())
    return vol.errors, entries


def t_storage():
    if not ROM.exists():
        return False, 'no %s (run the flash test first)' % ROM
    hd = OUT / 'storage-hd.img'
    table = hd_image(hd)
    atr = boot_disk('storage', {'IDET.COM': (T.LABELS / 'IDET.COM').read_bytes(),
                                'WRITE.IN': PAYLOAD},
                    ['IDET', 'DIR D2:', 'TYPE D2:HELLO.TXT', 'COPY WRITE.IN D2:WRITE.OUT'])
    mem = OUT / 'storage.bin'
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (T.label('k_prompt'), emu.win(mem))]
    e = []
    with emu.Session(OUT, [atr], cart=T.CAR, name='storage', turbo=True, debugcmds=cmds,
                     devices=ide_device(hd), firmware={'kmkjzide2': ROM}, fastboot=False):
        m = T.wait_dump(mem, 120)
        if m is None:
            return False, 'no EOS prompt with the flashed BIOS'
        first = T.screen(m)
        mem.unlink()
        wid = emu.window_id()
        emu.keys(wid, 'F5')                       # warm reset, then D2: again
        m = T.wait_dump(mem, 60)
        if m is not None:
            mem.unlink()
            emu.type_keys(wid, 'TYPE D2:WRITE.OUT')
            m = T.wait_dump(mem, 60)
        after = T.screen(m) if m else []
        emu.screenshot(OUT / 'storage.png')
    lines = {s.split(':')[0]: s.split(':')[1].split() for s in first if s[:3] in
             ('32 ', '160', '49 ') and ':' in s}
    ok = lambda key: lines.get(key, ['?'])[0] == '1'
    check = T.check
    check(ok('32 1 83'), 'physical device status %s' % lines.get('32 1 83'), e)
    check(lines.get('32 1 82', [])[1:6] == ['0', '65', '80', '84', '0'],
          'LBA 0 is not the APT header: %s' % lines.get('32 1 82'), e)
    check(lines.get('160 1 82') == lines.get('32 1 82'), 'XDCB read differs', e)
    for key, what in (('49 2 83', 'status'), ('49 2 78', 'PERCOM'), ('49 2 82', 'sector 1'),
                      ('49 2 110', 'DISKINFO')):
        check(ok(key), 'D2: %s %s' % (what, lines.get(key)), e)
    # DISKINFO: bus 1 (PBI), controller 0, device 1 (master), partition 1
    check(lines.get('49 2 110', [])[1:6] == ['1', '0', '1', '1', '0'],
          'D2: DISKINFO ids %s' % lines.get('49 2 110'), e)
    check(any('HELLO    TXT' in s for s in first), 'DIR D2: shows no HELLO.TXT', e)
    check('IDEPLUS PARTITION READ OK' in first, 'TYPE D2: did not read the file', e)
    check('IDEPLUS WRITE OK' in after, 'D2:WRITE.OUT not read after the warm reset', e)
    errors, files = partition_files(hd)
    check(not errors, 'partition file system: %s' % '; '.join(errors[:3]), e)
    check(files.get('/WRITE.OUT') == PAYLOAD, 'WRITE.OUT on the partition differs', e)
    check(hd.read_bytes()[:512] == table, 'the APT table changed', e)
    return not e, ', '.join(e) or ('BIOS 2.1 from the exported flash: device $20 and XDCB '
                                   'reads, D2: status/PERCOM/read/DISKINFO, DIR, TYPE, COPY, '
                                   'read after warm reset, partition checked on the host')


P2_START, P2_SIZE = PART_START + PART_SIZE, 1024


def apt_image(path):
    """Two SDFS partitions (1 mapped to D2:, 2 unmapped), a reserved entry
    and bytes after the entries that no APT field covers."""
    img = bytearray(HD_SECTORS * 512)
    for start, size, files in ((PART_START, PART_SIZE, {'HELLO.TXT': b'PARTITION ONE\x9b'}),
                               (P2_START, P2_SIZE, {'P2.TXT': b'PARTITION TWO OK\x9b'})):
        part = OUT / 'part.atr'
        sdfs.build(str(part), size, 512, files)
        raw = part.read_bytes()[16:]
        img[start * 512:start * 512 + len(raw)] = raw
    sec = bytearray(apt.new_table([{'start': PART_START, 'size': PART_SIZE},
                                   {'start': P2_START, 'size': P2_SIZE, 'id': 7}], {2: 1}))
    reserved = bytes([0x83, 0x45]) + (12000).to_bytes(4, 'little') + (16).to_bytes(4, 'little') \
        + b'\x34\x12' + bytes([0x5A, 1, 2, 3])
    sec[5] += 1                                # the header counts it
    sec[18 * 16:19 * 16] = reserved
    sec[400:446] = bytes(range(46))            # not covered by any entry
    img[:512] = sec
    path.write_bytes(img)
    return bytes(sec)


def t_apt():
    if not ROM.exists():
        return False, 'no %s (run the flash test first)' % ROM
    apt_com = T.LABELS / 'car' / 'APT.COM'
    if not apt_com.exists():
        return False, 'no %s (make eos)' % apt_com
    hd = OUT / 'apt-hd.img'
    before = apt_image(hd)
    yes, no = b'Y\x9b', b'N\x9b'
    atr = boot_disk('apt', {'YES.TXT': yes, 'NO.TXT': no},
                    ['APT >>L1.TXT', 'APT MAP 3 2 <<NO.TXT >>L2.TXT',
                     'APT MAP D3: 2 <<YES.TXT >>L3.TXT', 'APT WP 2 ON <<YES.TXT >>L4.TXT',
                     'APT BOOT 2 <<YES.TXT >>L5.TXT',
                     'APT MAP 4 3 <<YES.TXT >>L6.TXT', 'APT MAP 4 9 <<YES.TXT >>L8.TXT',
                     'APT >>L7.TXT'])
    mem = OUT / 'apt.bin'
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (T.label('k_prompt'), emu.win(mem))]
    with emu.Session(OUT, [atr], cart=T.CAR, name='apt', turbo=True, debugcmds=cmds,
                     devices=ide_device(hd), firmware={'kmkjzide2': ROM}, fastboot=False):
        m = T.wait_dump(mem, 180)
        emu.screenshot(OUT / 'apt.png')
    if m is None:
        return False, 'no EOS prompt after the APT batch'
    out = {}
    for i in range(1, 9):
        d = emu.extract(atr, 'L%d.TXT' % i, OUT / 'apt-x')
        out[i] = emu.text(d) if d else ''
    (OUT / 'apt-listings.txt').write_text('\n'.join('== L%d\n%s' % kv for kv in out.items()))
    e = []
    check = T.check
    check('APT on unit 1, table at LBA 0' in out[1], 'listing header: %r' % out[1][:80], e)
    check('D2: partition 1' in out[1], 'listing: no D2: mapping', e)
    check('reserved entry, type $45' in out[1], 'listing: reserved entry not shown', e)
    check('Not written.' in out[2] and 'Change: D3: to partition 2' in out[2],
          'MAP with N: %r' % out[2], e)
    check('Table written and read back' in out[3], 'MAP with Y: %r' % out[3], e)
    check('Change: partition 2 write protection ON' in out[4] and 'D3: follows it' in out[4],
          'WP: %r' % out[4], e)
    check('boot drive D0: to D2:' in out[5], 'BOOT: %r' % out[5], e)
    check('Partition 3 cannot be mapped' in out[6] and 'No partition 9' in out[8]
          and 'Write the table' not in out[6] + out[8], 'refused MAPs: %r' % (out[6] + out[8]), e)
    check('D3: partition 2' in out[7] and 'Boot drive: D2:' in out[7], 'final listing', e)
    # the same edits by the host reference: the sector must be identical
    img = bytearray(HD_SECTORS * 512)
    img[:512] = before
    ref = apt.from_bytes(img)
    ref.set_mapping(3, 2)
    ref.set_partition(2, write_protected=True)
    ref.set_boot_drive(2)
    ref.write()
    after = hd.read_bytes()[:512]
    check(after == bytes(img[:512]),
          'table differs from tools/apt.py at %s' % [i for i in range(512) if after[i] != img[i]][:8], e)
    check(after[18 * 16:19 * 16] == before[18 * 16:19 * 16], 'reserved entry changed', e)
    check(after[400:446] == before[400:446], 'unrelated table bytes changed', e)
    if e:
        return False, ', '.join(e)
    # power off and on: the BIOS reads the new table
    atr2 = boot_disk('apt2', {}, ['TYPE D3:P2.TXT', 'DIR D2:'])
    mem.unlink(missing_ok=True)
    with emu.Session(OUT, [atr2], cart=T.CAR, name='apt2', turbo=True, debugcmds=cmds,
                     devices=ide_device(hd), firmware={'kmkjzide2': ROM}, fastboot=False):
        m = T.wait_dump(mem, 120)
        emu.screenshot(OUT / 'apt2.png')
    lines = T.screen(m) if m else []
    check('PARTITION TWO OK' in lines, 'D3: not mapped after restart: %r' % lines[:12], e)
    check(any('HELLO    TXT' in s for s in lines), 'D2: lost after restart', e)
    if e:
        return False, ', '.join(e)
    # a protective MBR (type $7F) pointing at a revision 1 table at LBA 1:
    # shown, not changed; UNMAP and a flag already set on the first disk
    hd3 = OUT / 'apt3-hd.img'
    img = bytearray(HD_SECTORS * 512)
    mbr = bytearray(512)
    mbr[0x1BE + 4] = 0x7F
    mbr[0x1BE + 8:0x1BE + 12] = (1).to_bytes(4, 'little')
    mbr[0x1BE + 12:0x1BE + 16] = (HD_SECTORS - 1).to_bytes(4, 'little')
    mbr[510:512] = bytes([0x55, 0xAA])
    img[:512] = mbr
    t3 = bytearray(apt.new_table([{'start': PART_START, 'size': PART_SIZE}], {2: 1}))
    t3[0] = 0x20                               # revision 1
    img[512:1024] = t3
    hd3.write_bytes(img)
    atr3 = boot_disk('apt3', {'YES.TXT': yes, 'NO.TXT': no},
                     ['APT >>M1.TXT', 'APT MAP 3 1 <<YES.TXT >>M2.TXT'])
    mem.unlink(missing_ok=True)
    with emu.Session(OUT, [atr3], cart=T.CAR, name='apt3', turbo=True, debugcmds=cmds,
                     devices=ide_device(hd3), firmware={'kmkjzide2': ROM}, fastboot=False):
        T.wait_dump(mem, 120)
    m1 = emu.text(emu.extract(atr3, 'M1.TXT', OUT / 'apt-x') or b'')
    m2 = emu.text(emu.extract(atr3, 'M2.TXT', OUT / 'apt-x') or b'')
    check('table at LBA 1' in m1 and 'Revision 1' in m1, 'MBR/revision listing: %r' % m1[:90], e)
    check('APT revision 1: not changed' in m2, 'revision 1 edit: %r' % m2, e)
    check(hd3.read_bytes() == bytes(img), 'revision 1 disk changed', e)
    # UNMAP of an unmapped drive and a flag already so: nothing to write
    atr4 = boot_disk('apt4', {'YES.TXT': yes, 'NO.TXT': no},
                     ['APT UNMAP 5 <<YES.TXT >>N1.TXT', 'APT AUTO 1 ON <<YES.TXT >>N2.TXT',
                      'APT UNMAP D2: <<NO.TXT >>N3.TXT'])
    snap = hd.read_bytes()
    mem.unlink(missing_ok=True)
    with emu.Session(OUT, [atr4], cart=T.CAR, name='apt4', turbo=True, debugcmds=cmds,
                     devices=ide_device(hd), firmware={'kmkjzide2': ROM}, fastboot=False):
        T.wait_dump(mem, 120)
    n = [emu.text(emu.extract(atr4, 'N%d.TXT' % i, OUT / 'apt-x') or b'') for i in (1, 2, 3)]
    check('D5: is not mapped' in n[0], 'UNMAP unmapped: %r' % n[0], e)
    check('No change.' in n[1], 'AUTO already on: %r' % n[1], e)
    check('Change: D2: unmapped' in n[2] and 'Not written.' in n[2], 'UNMAP with N: %r' % n[2], e)
    check(hd.read_bytes() == snap, 'the disk changed without a Y', e)
    return not e, ', '.join(e) or ('APT listing, MAP (N and Y), WP with its mapping slot, BOOT, '
                                   'refused MAPs, UNMAP, no-change; sector equal to tools/apt.py, '
                                   'reserved and unrelated bytes kept; D3: served by the BIOS '
                                   'after restart; MBR-located revision 1 table shown, not changed')


def t_partition():
    """APT on a blank disk: INIT, NEW, MAP, DEL (refused while mapped), the
    BIOS serving the new partitions after a restart, FORMAT /QQ on them."""
    if not ROM.exists():
        return False, 'no %s (run the flash test first)' % ROM
    hd = OUT / 'part-hd.img'
    nsec = 72000                              # room for a 32 MiB partition
    hd.write_bytes(bytes(nsec * 512))
    yes, no = b'Y\x9b', b'N\x9b'
    one = boot_disk('part1', {'YES.TXT': yes, 'NO.TXT': no},
                    ['APT >>P0.TXT', 'APT INIT <<YES.TXT >>P1.TXT', 'APT NEW 2M <<YES.TXT >>P2.TXT',
                     'APT NEW 1000 <<YES.TXT >>P3.TXT', 'APT NEW 32M <<YES.TXT >>P9.TXT',
                     'APT NEW 2M <<YES.TXT >>P4.TXT',
                     'APT MAP D2: 1 <<YES.TXT >>P5.TXT', 'APT MAP D3: 2 <<YES.TXT >>P6.TXT',
                     'APT MAP D4: 3 <<YES.TXT >>P10.TXT',
                     'APT DEL 2 <<YES.TXT >>P7.TXT', 'APT >>P8.TXT'])
    two = boot_disk('part2', {'YES.TXT': yes, 'WRITE.IN': PAYLOAD},
                    ['FORMAT /QQ D2: DISK1', 'FORMAT /QQ D3: DISK2', 'FORMAT /QQ D4: BIG',
                     'COPY WRITE.IN D2:A.TXT', 'COPY WRITE.IN D3:B.TXT', 'COPY WRITE.IN D4:C.TXT',
                     'DIR D2: >>D2.TXT', 'DIR D3: >>D3.TXT', 'DIR D4: >>D4.TXT',
                     'APT INIT <<YES.TXT >>Q0.TXT',
                     'APT UNMAP D3: <<YES.TXT >>Q1.TXT', 'APT DEL 2 <<YES.TXT >>Q2.TXT',
                     'APT >>Q3.TXT'])
    mem = OUT / 'part.bin'
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (T.label('k_prompt'), emu.win(mem))]
    for atr, name in ((one, 'part1'), (two, 'part2')):     # (a power cycle between)
        mem.unlink(missing_ok=True)
        with emu.Session(OUT, [atr], cart=T.CAR, name=name, turbo=True, debugcmds=cmds,
                         devices=ide_device(hd, nsec), firmware={'kmkjzide2': ROM},
                         fastboot=False):
            T.wait_dump(mem, 300)
            emu.screenshot(OUT / (name + '.png'))
    out = {}
    for atr, names in ((one, ['P%d' % i for i in range(11)]),
                       (two, ['D2', 'D3', 'D4'] + ['Q%d' % i for i in range(4)])):
        for n in names:
            out[n] = emu.text(emu.extract(atr, n + '.TXT', OUT / 'part-x') or b'')
    (OUT / 'part-outputs.txt').write_text('\n'.join('== %s\n%s' % kv for kv in out.items()))
    raw = out
    out = {k: ' '.join(v.split()) for k, v in raw.items()}   # (lines wrap, names pad)
    e = []
    c = T.check
    c('No APT table' in out['P0'], 'blank disk: %r' % out['P0'], e)
    c('a new APT table at LBA 0' in out['P1'] and 'read back' in out['P1'], 'INIT %r' % out['P1'], e)
    c('partition 1, LBA 1' in out['P2'] and '4096 sectors' in out['P2'] and 'read back' in out['P2'],
      'NEW 2M %r' % out['P2'], e)
    c('partition 2, LBA 4097' in out['P3'] and '1000 sectors' in out['P3'], 'NEW 1000 %r' % out['P3'], e)
    c('Not enough room' in out['P4'] and 'Write the table' not in out['P4'], 'NEW too big %r' % out['P4'], e)
    c('mapped to D3:' in out['P7'] and 'Write the table' not in out['P7'], 'DEL mapped %r' % out['P7'], e)
    c('partition 3, LBA 5097' in out['P9'] and '65535 sectors' in out['P9'], 'NEW 32M %r' % out['P9'], e)
    c('D2: partition 1' in out['P8'] and 'D3: partition 2' in out['P8'] and
      'D4: partition 3' in out['P8'], 'listing %r' % out['P8'], e)
    c('C TXT' in out['D4'] and 'BIG' in out['D4'], 'D4: (32 MiB) after FORMAT %r' % out['D4'][:80], e)
    c('A TXT' in out['D2'] and 'DISK1' in out['D2'], 'D2: after FORMAT %r' % out['D2'][:80], e)
    c('B TXT' in out['D3'] and 'DISK2' in out['D3'], 'D3: after FORMAT %r' % out['D3'][:80], e)
    c('INIT /F' in out['Q0'] and 'Write the table' not in out['Q0'], 'INIT on a table %r' % out['Q0'], e)
    c('removed' in out['Q2'] and 'read back' in out['Q2'], 'DEL %r' % out['Q2'], e)
    c('2 partitions' in out['Q3'] and 'D2: partition 1' in out['Q3'] and
      'D4: partition 2' in out['Q3'], 'final listing (D4: follows its partition) %r' % out['Q3'], e)
    img = bytearray(hd.read_bytes())
    t = apt.from_bytes(img)
    c([(q.start, q.size, q.data[0], q.data[12]) for q in t.partitions if q.data[0] & 3] ==
      [(1, 4096, 3, 0x40), (5097, 65535, 3, 0x40)],
      'table on the host %r' % [(q.start, q.size) for q in t.partitions], e)
    c(t.mapped_partition(4) == 2 and t.mapped_partition(3) is None, 'mappings on the host', e)
    errors, files = partition_files(hd, 1, 4096)
    c(not errors and files.get('/A.TXT') == PAYLOAD, 'partition 1 on the host: %s' % errors[:2], e)
    errors, files = partition_files(hd, 5097, 65535)
    c(not errors and files.get('/C.TXT') == PAYLOAD, '32 MiB partition on the host: %s' % errors[:2], e)
    return not e, ', '.join(e) or ('blank disk: INIT, NEW 2M, NEW 1000, NEW 32M (65535 sectors), NEW '
                                   'too big refused, MAP D2:-D4:, DEL refused while mapped; after a '
                                   'restart the BIOS serves all three, FORMAT /QQ and COPY on them '
                                   '(32 MiB too), INIT refused on a table, UNMAP and DEL with D4: '
                                   'following its partition; table and file systems checked on the host')


def t_mapmode():
    """MAP's unit and modes on the IDE2.0PLUS's D2: (MAP B: = drive 2): SIO
    leaves the PBI BIOS out (D2: does not answer), OFF answers 138, unit 1
    shows D1:'s files, unit 2 the partition again; the table stays over a
    warm reset."""
    if not ROM.exists():
        return False, 'no %s (run the flash test first)' % ROM
    hd = OUT / 'map-hd.img'
    hd_image(hd)
    atr = boot_disk('mapm', {'MARK.D1': b'D1\x9b'},
                    ['DIR D2: >>M1.TXT', 'MAP 2 SIO B: >>M0.TXT', 'DIR D2: >>M2.TXT',
                     'MAP 2 OFF B:', 'DIR D2: >>M3.TXT', 'MAP 1 NORMAL B:', 'DIR D2: >>M4.TXT',
                     'MAP 2 B:', 'DIR D2: >>M5.TXT', 'MAP 1 B:', 'MAP >>M6.TXT'])
    mem = OUT / 'mapm.bin'
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (T.label('k_prompt'), emu.win(mem))]
    with emu.Session(OUT, [atr], cart=T.CAR, name='mapm', turbo=True, debugcmds=cmds,
                     devices=ide_device(hd), firmware={'kmkjzide2': ROM}, fastboot=False):
        m = T.wait_dump(mem, 240)
        if m is not None:                     # a warm reset: the table stays
            mem.unlink()
            emu.keys(emu.window_id(), 'F5')
            if T.wait_dump(mem, 60) is not None:
                mem.unlink()
                emu.type_keys(emu.window_id(), 'MAP >>M7.TXT')
                T.wait_dump(mem, 60)
        emu.screenshot(OUT / 'mapm.png')
    o = {n: ' '.join(emu.text(emu.extract(atr, n + '.TXT', OUT / 'map-x') or b'').split())
         for n in ('M0', 'M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'M7')}
    (OUT / 'mapm-outputs.txt').write_text('\n'.join('%s: %s' % kv for kv in o.items()))
    e = []
    c = T.check
    c('HELLO TXT' in o['M1'], 'D2: before MAP %r' % o['M1'][:80], e)
    c('B:=2 SIO' in o['M0'], 'MAP 2 SIO B: %r' % o['M0'], e)
    c('HELLO' not in o['M2'], 'D2: answered with SIO (PBI left out) %r' % o['M2'][:80], e)
    c('HELLO' not in o['M3'], 'D2: answered with OFF %r' % o['M3'][:80], e)
    c('MARK D1' in o['M4'] and 'HELLO' not in o['M4'], 'D2: as unit 1 %r' % o['M4'][:80], e)
    c('HELLO TXT' in o['M5'], 'D2: unit 2 again %r' % o['M5'][:80], e)
    c('B:=1' in o['M6'] and 'B:=1 SIO' not in o['M6'], 'MAP table %r' % o['M6'][:120], e)
    c('B:=1' in o['M7'], 'MAP table after RESET %r' % o['M7'][:120], e)
    return not e, ', '.join(e) or ('MAP on D2: (IDE2.0PLUS): SIO leaves the PBI BIOS out, OFF does '
                                   'not answer, unit 1 shows D1:, unit 2 the partition again '
                                   '(the cache follows), the table stays over a warm reset')


TESTS = {'flash': t_flash, 'storage': t_storage, 'apt': t_apt, 'partition': t_partition,
         'mapmode': t_mapmode}


def main():
    emu.ensure_display()
    OUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or list(TESTS)
    failed = 0
    for n in names:
        try:
            ok, msg = TESTS[n]()
        except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
            ok, msg = False, 'error: %s' % exc
        print('%-8s %s  %s' % (n, 'PASS' if ok else 'FAIL', msg), flush=True)
        failed += not ok
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
