#!/usr/bin/env python3
"""EOS (Extendable Operating System) tests, run against real SpartaDOS X 4.5 as the
oracle where SDX has an equivalent.

Each test prints PASS, FAIL or XFAIL (XFAIL only for items still open in
PROGRESS.md). Memory is inspected through an Altirra breakpoint that writes
the 64K CPU view to the host (see docs/history/EOS_PLAN.md, "Test oracle").

usage: eos_test.py [test ...]
"""
import os
import io
import re
import subprocess
import sys
import tarfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import sdxprobe  # noqa: E402
import sdfs  # noqa: E402

OUT = emu.BUILD / 'eos-results'
CAR = emu.BUILD / 'EOS.car'
LABELS = emu.BUILD / 'eos'
VERSION = (emu.ROOT / 'VERSION').read_text().strip()


def label(name, module='kernel'):
    for line in (LABELS / (module + '.lab')).read_text().splitlines():
        f = line.split()
        if len(f) == 3 and f[2].upper() == name.upper():
            return int(f[1], 16)
    raise KeyError(name)


def word(m, a):
    return m[a] | m[a + 1] << 8


def wait_dump(mem, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if mem.exists() and mem.stat().st_size == 0x10000:
            time.sleep(0.5)
            m = mem.read_bytes()
            if len(m) == 0x10000:      # (not caught while the emulator rewrites it)
                return m
        time.sleep(0.5)
    return None


class Dumper:
    """An emulator session that dumps memory at breakpoint bp and runs on.

    with Dumper(name, bp, disks=[...]) as d:
        m = d.first          # memory at the first hit (None on timeout)
        m = d.step(lambda wid: emu.type_line(wid, 'DIR'))   # next hit
    """

    def __init__(self, name, bp, cart=CAR, disks=(), memsize='64K', timeout=60, run_on=True):
        self.mem = OUT / (name + '.bin')
        self.mem.unlink(missing_ok=True)
        self.name = name
        self.timeout = timeout
        cmds = ['bp $%04X ".writemem %s 0 L10000%s"' % (bp, emu.win(self.mem), '; g' * run_on)]
        self.session = emu.Session(OUT, list(disks), cart=cart, name=name, memsize=memsize,
                                   turbo=True, debugcmds=cmds)
        self.shots = 0

    def __enter__(self):
        self.session.__enter__()
        self.first = wait_dump(self.mem, self.timeout)
        return self

    def step(self, action):
        self.mem.unlink(missing_ok=True)
        action(emu.window_id())
        m = wait_dump(self.mem, self.timeout)
        self.shots += 1
        emu.screenshot(OUT / ('%s-%d.png' % (self.name, self.shots)))
        return m

    def __exit__(self, *exc):
        emu.screenshot(OUT / (self.name + '.png'))
        self.session.__exit__(*exc)


def dump_at(name, bp, cart=CAR, disks=(), memsize='64K', timeout=60, then=None,
            ultimate1mb=False, devices=None):
    """Boot, break at bp, return the 64K CPU view (None on timeout).

    The breakpoint dumps memory and lets the emulator run on. With then, a
    function of the Altirra window id, the first dump is dropped, then() runs
    and the next hit of bp is returned instead.
    """
    mem = OUT / (name + '.bin')
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000; g"' % (bp, emu.win(mem))]
    with emu.Session(OUT, list(disks), cart=cart, name=name, memsize=memsize, turbo=True,
                     debugcmds=cmds, ultimate1mb=ultimate1mb, devices=devices):
        m = wait_dump(mem, timeout)
        if m is not None and then:
            mem.unlink()
            then(emu.window_id())
            m = wait_dump(mem, timeout)
        emu.screenshot(OUT / (name + '.png'))
    return m


def screen(m):
    """The 24 x 40 text screen at SAVMSC as ATASCII lines (inverse dropped)."""
    base = word(m, 0x58)
    lines = []
    for row in range(24):
        s = ''
        for c in m[base + 40 * row:base + 40 * row + 40]:
            c &= 0x7F
            c = c + 0x20 if c < 0x40 else c - 0x40 if c < 0x60 else c
            s += chr(c) if 32 <= c < 127 else '.'
        lines.append(s.strip())
    return lines


def check(cond, what, errors):
    if not cond:
        errors.append(what)


def t_boot(memsize, reset=False):
    """The cart boots to a prompt: banner, fixed addresses, MEMLO; also after
    a warm reset (Altirra F5) when reset is set."""
    then = (lambda wid: emu.keys(wid, 'F5')) if reset else None
    m = dump_at('boot-' + memsize + '-reset' * reset, label('k_prompt'), memsize=memsize,
                then=then)
    if m is None:
        return False, 'no breakpoint hit'
    e = []
    check(word(m, 0x0A) == 0x0A3A, 'DOSVEC $%04X' % word(m, 0x0A), e)
    check(m[0x0A3A] == 0x4C, 'COMTAB is not a JMP', e)
    check(m[0x0700] == ord('S') and m[0x0701] == 0x45, 'page 7 signature', e)
    check(word(m, 0x2E7) <= 0x18FF, 'MEMLO $%04X' % word(m, 0x2E7), e)
    text = screen(m)
    banner = 'EOS v%s (c)2026 Rick Collette' % VERSION
    check(any(s == banner for s in text), 'no exact banner', e)
    check(text and any(s == '[D1:/]' for s in text), 'no prompt', e)
    return not e, ', '.join(e) or 'MEMLO $%04X' % word(m, 0x2E7)


def t_boot_ideplus(reset=False):
    """Boot with Altirra's IDE2.0PLUS PBI device enabled, optionally reset.

    This checks EOS startup and warm-reset compatibility with the device's
    flash erased. tools/ideplus_test.py flashes BIOS 2.1 and tests drives,
    sector I/O, partitions and APT.
    """
    devices = [{'tag': 'kmkjzide2', 'params': {
        'enablesdx': False, 'revision': 'd', 'id': 0, 'nvramguard': True,
    }}]
    then = (lambda wid: emu.keys(wid, 'F5')) if reset else None
    name = 'boot-ideplus-reset' if reset else 'boot-ideplus'
    m = dump_at(name, label('k_prompt'), then=then, devices=devices)
    if m is None:
        return False, 'no EOS prompt breakpoint with IDE2.0PLUS enabled'
    e = []
    check(word(m, 0x0A) == 0x0A3A, 'DOSVEC $%04X' % word(m, 0x0A), e)
    check(screen(m) and any(s == '[D1:/]' for s in screen(m)), 'no prompt', e)
    return not e, ', '.join(e) or ('EOS prompt after IDE2.0PLUS reset' if reset else
                                   'EOS prompt with IDE2.0PLUS enabled')


def t_hardware_man(page, title):
    """Check that a target-specific hardware page is available through MAN."""
    with Dumper('man-' + page.lower(), label('k_prompt')) as d:
        m = d.step(lambda wid: emu.type_line(wid, 'man ' + page.lower() + ' /P'))
    if m is None:
        return False, 'MAN did not return to the command prompt'
    lines = screen(m)
    return any(title in line for line in lines), (
        'page text missing: %r' % lines[-8:] if not any(title in line for line in lines)
        else 'MAN ' + page + ' page displayed')


# EOS_EOSFS=1: EOS's disks are EOSFS (docs/EOSFS.md), SDX's stay SDFS
EOSFS = os.environ.get('EOS_EOSFS', '') not in ('', '0')


def disk(name, files, size=92160, geo=None):
    """SDFS image from {path: bytes} ('SUB/X.TXT' makes SUB a directory):
    by mkatr, or with geo = (sectors, sector size) by sdfs.build. With
    EOS_EOSFS set, EOS's disks (names without -sdx) are EOSFS."""
    if os.environ.get('EOS_GEO') and '-sdx' not in name:   # make eosall: the disk
        n, sz = os.environ['EOS_GEO'].split('x')
        geo = (int(n), int(sz))
    if EOSFS and '-sdx' not in name:
        atr = OUT / (name + '.atr')
        # EOSFS is exact-case and EOS's default startup names are lowercase.
        # Keep test payload names as authored (many cases deliberately test
        # uppercase names), but install the four automatically opened files
        # under their native v2 names.
        startup = {'CONFIG.SYS': 'config.sys', 'EOSSYS.SYS': 'eossys.sys',
                   'AUTOEXEC.BAT': 'autoexec.bat', 'EOSAUTO.BAT': 'eosauto.bat'}

        def native_name(path):
            if path in startup:
                return startup[path]
            return path

        files = {native_name(p): data for p, data in files.items()}
        sdfs.build(str(atr), *(geo or (size // 128, 128)), files, eosfs=True)
        return atr
    if geo:
        atr = OUT / (name + '.atr')
        sdfs.build(str(atr), geo[0], geo[1], files)
        return atr
    tree = OUT / (name + '-tree')
    if tree.exists():
        import shutil
        shutil.rmtree(tree)
    tree.mkdir(parents=True)
    order = []
    for p, data in files.items():
        f = tree / p
        f.parent.mkdir(parents=True, exist_ok=True)
        d = str(Path(p).parent)
        if d != '.' and d not in order:
            order.append(d)
        f.write_bytes(data)
        order.append(p)
    atr = OUT / (name + '.atr')
    emu.mkatr(atr, tree, order, size)
    return atr


def d2_disk(name, d2):
    """The disk for D2: an SDFS image of the files in a dict, or a copy of
    an existing ATR (a path)."""
    if isinstance(d2, dict):
        return disk(name, d2)
    atr = OUT / (name + '.atr')
    atr.write_bytes(Path(d2).read_bytes())
    return atr


def sdx_lines(name, files, commands, geo=None, timeout=120, d2=None, memsize='64K', ends=False,
              last=False):
    """Run commands from AUTOEXEC.BAT on real SDX after a CLS; the output
    lines (blank lines dropped), or None. d2: files for a disk in D2:.
    ends: the batch may end before its last line (SDXPROBE): after a short
    wait SDXPROBE is typed at the prompt. last: drivers from a CONFIG.SYS
    may run the probe's address while booting: the last dump counts."""
    if ends:
        timeout = 25
    files = dict(files)
    files['AUTOEXEC.BAT'] = emu.atascii(['CLS'] + list(commands) + ['SDXPROBE'])
    files['SDXPROBE.COM'] = sdxprobe.PROBE.read_bytes()
    key = sdx_key(files, geo, d2, memsize, ends, last)
    hit = sdx_cached(key, name)
    if hit is not False:
        return hit
    atr = disk(name + '-sdx', files, geo=geo)
    disks = [atr] + ([d2_disk(name + '-sdx-d2', d2)] if d2 is not None else [])
    lines = sdx_run(name, disks, timeout, memsize, ends, last)
    if lines is not None:
        sdx_store(key, lines, disks)
    return lines


# SDX's results never change for the same inputs: kept in build/sdx-cache
# by a hash of them, the SDX cartridge and the probe; EOS_FRESH=1 runs SDX
# again
CACHE = emu.BUILD / 'sdx-cache'
FRESH = os.environ.get('EOS_FRESH', '') not in ('', '0')


def sdx_key(files, geo, d2, memsize, ends, last):
    import hashlib
    h = hashlib.sha256()
    for blob in (emu.SDX_CART.read_bytes(), repr(sorted(files.items())).encode(),
                 repr((geo, memsize, ends, last)).encode(),
                 repr(sorted(d2.items())).encode() if isinstance(d2, dict) else
                 (Path(d2).read_bytes() if d2 is not None else b'-')):
        h.update(hashlib.sha256(blob).digest())
    return h.hexdigest()[:24]


def sdx_cached(key, name):
    """The lines kept for key (the disks put back as NAME-sdx*.atr), or False."""
    import json
    f = CACHE / (key + '.json')
    if FRESH or not f.exists():
        return False
    for i, suffix in enumerate(['-sdx', '-sdx-d2']):
        a = CACHE / ('%s-%d.atr' % (key, i))
        if a.exists():
            (OUT / (name + suffix + '.atr')).write_bytes(a.read_bytes())
    return json.loads(f.read_text())


def sdx_store(key, lines, disks):
    import json
    CACHE.mkdir(parents=True, exist_ok=True)
    for i, d in enumerate(disks):
        (CACHE / ('%s-%d.atr' % (key, i))).write_bytes(Path(d).read_bytes())
    (CACHE / (key + '.json')).write_text(json.dumps(lines))


def sdx_run(name, disks, timeout, memsize, ends, last):
    with Dumper(name + '-sdx', sdxprobe.DONE, cart=emu.SDX_CART, disks=disks, timeout=timeout,
                memsize=memsize,
                run_on=last) as d:
        m = d.first
        if last:
            d.timeout = 10
            for _ in range(20):
                m2 = d.step(lambda wid: None)
                if m2 is None:
                    break
                m = m2
        if m is None and ends:
            m = d.step(lambda wid: emu.type_line(wid, 'SDXPROBE'))
    if m is None:
        return None
    return [s for s in screen(m) if s and s != 'D1:SDXPROBE']


def our_lines(name, files, commands, geo=None, timeout=60, d2=None, memsize='64K'):
    """Run commands from AUTOEXEC.BAT on EOS after a CLS; the output lines
    up to the next prompt (blank lines dropped), or None."""
    files = dict(files)
    # Bare executable lookup defaults to lowercase, while arbitrary filenames
    # (including data with a .COM suffix) remain exact.  Install only programs
    # actually invoked by this test under that default name.
    invoked = {line.lstrip().split(None, 1)[0].lstrip('+-').lower()
               for line in commands if line.strip()}
    native = {}
    for path, data in files.items():
        stem = Path(path).stem.lower()
        full = Path(path).name.lower()
        if '/' not in path and (stem in invoked or full in invoked):
            path = path.lower()
        native[path] = data
    files = native
    # a blank line where SDX's batch has SDXPROBE: the same length
    files['AUTOEXEC.BAT'] = emu.atascii(['CLS'] + list(commands) + [' ' * 8])
    files['SDXPROBE.COM'] = sdxprobe.PROBE.read_bytes()   # same free space as on SDX
    atr = disk(name, files, geo=geo)
    disks = [atr] + ([d2_disk(name + '-d2', d2)] if d2 is not None else [])
    with Dumper(name, label('k_prompt'), disks=disks, timeout=timeout, memsize=memsize) as d:
        m = d.first
    if m is None:
        return None
    return [s for s in screen(m) if s and s != '[D1:/]']


def disk_tree(atr):
    """{path: (status bits P H A D L, data)}, the check errors and the free
    sector count of a disk."""
    v = sdfs.Volume(str(atr))
    ents = v.check()
    return {p: (e['status'] & 0x67, e.get('data')) for p, e in ents}, v.errors, v.free


def t_tar_native():
    """CAR:TAR creates real USTAR and reads host-created USTAR."""
    files = {'Mixed Case.txt': emu.atascii(['hello']), 'second.bin': b'abc'}
    got = our_lines('tar-native', files,
                    ['tar c files.tar "Mixed Case.txt" second.bin',
                     'tar t files.tar', 'rm "Mixed Case.txt"',
                     'tar x files.tar', 'type "Mixed Case.txt"'])
    want = ['Mixed Case.txt', 'second.bin',
            'Skipping existing file: second.bin', 'hello']
    if got != want:
        return False, 'Atari create/extract output %r' % got
    tree, errors, _ = disk_tree(OUT / 'tar-native.atr')
    archive = tree.get('/files.tar', (0, None))[1]
    if errors or archive is None:
        return False, 'archive missing or EOSFS errors %r' % errors
    try:
        with tarfile.open(fileobj=io.BytesIO(archive)) as tf:
            members = [(m.name, m.size, tf.extractfile(m).read()) for m in tf]
    except tarfile.TarError as exc:
        return False, 'host rejected USTAR: %s' % exc
    expected = [('Mixed Case.txt', 6, b'hello\x9b'), ('second.bin', 3, b'abc')]
    if members != expected:
        return False, 'host read %r' % (members,)

    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode='w', format=tarfile.USTAR_FORMAT) as tf:
        info = tarfile.TarInfo('Host Name.txt')
        payload = b'from host\x9b'
        info.size = len(payload)
        info.mtime = 0
        tf.addfile(info, io.BytesIO(payload))
    got = our_lines('tar-host', {'host.tar': out.getvalue()},
                    ['tar t host.tar', 'tar x host.tar', 'type "Host Name.txt"'])
    if got != ['Host Name.txt', 'from host']:
        return False, 'host USTAR read output %r' % got

    # Native recursive creation writes explicit directory members and keeps
    # the tree rooted at the argument's basename.
    tree_files = {'tree/one.txt': b'one', 'tree/sub/two.bin': b'two'}
    got = our_lines('tar-tree', tree_files, ['tar c tree.tar tree', 'tar t tree.tar'])
    if got != ['tree', 'tree/one.txt', 'tree/sub', 'tree/sub/two.bin']:
        return False, 'recursive list output %r' % got
    image, errors, _ = disk_tree(OUT / 'tar-tree.atr')
    raw = image.get('/tree.tar', (0, None))[1]
    if errors or raw is None:
        return False, 'recursive archive missing/errors %r' % errors
    try:
        with tarfile.open(fileobj=io.BytesIO(raw)) as tf:
            names = [(m.name, m.isdir(), m.mtime) for m in tf]
            payloads = {m.name: tf.extractfile(m).read() for m in tf if m.isfile()}
    except tarfile.TarError as exc:
        return False, 'recursive archive rejected: %s' % exc
    if names[:4] != [('tree', True, names[0][2]),
                     ('tree/one.txt', False, names[1][2]),
                     ('tree/sub', True, names[2][2]),
                     ('tree/sub/two.bin', False, names[3][2])]:
        return False, 'recursive members %r' % (names,)
    if payloads != {'tree/one.txt': b'one', 'tree/sub/two.bin': b'two'}:
        return False, 'recursive payloads %r' % payloads
    if not all(mtime > 0 for _, _, mtime in names):
        return False, 'creation timestamps were not emitted: %r' % (names,)

    # Host directory entries and timestamps are restored on EOSFS.
    out = io.BytesIO()
    stamp = 1_704_164_645       # 2024-01-02 03:04:05 UTC
    with tarfile.open(fileobj=out, mode='w', format=tarfile.USTAR_FORMAT) as tf:
        di = tarfile.TarInfo('hostdir')
        di.type = tarfile.DIRTYPE
        di.mtime = stamp
        tf.addfile(di)
        fi = tarfile.TarInfo('hostdir/file.txt')
        fi.size = 4
        fi.mtime = stamp
        tf.addfile(fi, io.BytesIO(b'data'))
    got = our_lines('tar-host-tree', {'tree.tar': out.getvalue()},
                    ['tar x tree.tar', 'type hostdir/file.txt'])
    if got != ['data']:
        return False, 'host tree extraction output %r' % got
    extracted, errors, _ = disk_tree(OUT / 'tar-host-tree.atr')
    if errors or extracted.get('/hostdir/file.txt', (0, None))[1] != b'data':
        return False, 'host tree extraction errors %r' % errors
    v = sdfs.Volume(str(OUT / 'tar-host-tree.atr'))
    entries = dict(v.check())
    if entries['/hostdir/file.txt']['date'] != (2, 1, 24) or \
            entries['/hostdir/file.txt']['time'] != (3, 4, 5):
        return False, 'timestamp not restored: %r %r' % (
            entries['/hostdir/file.txt']['date'], entries['/hostdir/file.txt']['time'])

    def v7(name, data=b'', mtime=stamp, kind=b'0'):
        h = bytearray(512)
        h[:len(name)] = name.encode('ascii')
        h[100:108] = b'0000644\0'
        h[108:116] = b'0000000\0'
        h[116:124] = b'0000000\0'
        h[124:136] = ('%011o\0' % len(data)).encode('ascii')
        h[136:148] = ('%011o\0' % mtime).encode('ascii')
        h[148:156] = b'        '
        h[156:157] = kind
        h[148:156] = ('%06o\0 ' % sum(h)).encode('ascii')
        return bytes(h) + data + bytes((-len(data)) % 512)

    old = v7('old.txt', b'v7') + bytes(1024)
    got = our_lines('tar-v7', {'old.tar': old},
                    ['tar t old.tar', 'tar x old.tar', 'type old.txt'])
    if got != ['old.txt', 'v7']:
        return False, 'V7 read output %r' % got

    # Unsafe paths, collisions, checksum damage, and truncation are all
    # explicit and must not create or replace anything.
    hostile = (v7('../escape', b'bad') + v7('/absolute', b'bad') +
               v7('safe.txt', b'replace') + bytes(1024))
    got = our_lines('tar-unsafe', {'unsafe.tar': hostile, 'safe.txt': b'keep'},
                    ['tar x unsafe.tar'])
    if got != ['Skipping unsafe name: ../escape',
               'Skipping unsafe name: /absolute',
               'Skipping existing file: safe.txt']:
        return False, 'unsafe/collision output %r' % got
    unsafe_tree, errors, _ = disk_tree(OUT / 'tar-unsafe.atr')
    if errors or unsafe_tree.get('/safe.txt', (0, None))[1] != b'keep' or \
            '/escape' in unsafe_tree or '/absolute' in unsafe_tree:
        return False, 'unsafe extraction changed disk: %r' % errors
    damaged = bytearray(v7('bad.txt', b'x') + bytes(1024))
    damaged[0] ^= 1
    got = our_lines('tar-malformed', {'bad.tar': bytes(damaged),
                                      'short.tar': v7('short.txt', b'x')[:700]},
                    ['tar t bad.tar', 'tar t short.tar'])
    if got != ['Invalid tar archive', 'short.txt', 'Invalid tar archive']:
        return False, 'malformed archive output %r' % got
    return True, ('USTAR trees/extraction/collisions/timestamps, V7, and '
                  'malformed/unsafe regressions pass')


def t_toolkit_disk():
    """The shipped Toolkit is native EOSFS and a lowercase program loads from D1:."""
    atr = emu.BUILD / 'EOSTK.atr'
    volume = sdfs.Volume(str(atr))
    entries = dict(volume.check())
    if not volume.eosfs or volume.errors:
        return False, 'not clean EOSFS: eosfs=%s errors=%r' % (volume.eosfs, volume.errors)
    if '/basename.com' not in entries or '/man/ed.man' not in entries:
        return False, 'native lowercase Toolkit entries missing'
    with Dumper('toolkit-disk', label('k_prompt'), disks=[atr], memsize='64K') as d:
        if d.first is None:
            return False, 'Toolkit disk did not reach the EOS prompt'
        m = d.step(lambda wid: emu.type_keys(wid, 'D1:basename /alpha/beta.txt'))
    lines = [x for x in screen(m) if x] if m else []
    if 'beta.txt' not in lines:
        return False, 'D1: program load failed: %r' % lines
    return True, 'native EOSFS image mounted and D1:basename executed'


def t_vim_interactive():
    """Drive the real modal editor through Altirra's keyboard on a 64K EOSFS boot."""
    lines = ['line%02d\tvalue' % i for i in range(1, 31)]

    files = {
        'lines.txt': ('\n'.join(lines) + '\n').encode('ascii'),
        'ops.txt': b'ab\ncd\n',
        'move.txt': b'one\ntwo\nthree\n',
        'keep.txt': b'keep\r\nthis\r\n',
        'bad.txt': b'bad\x00text\n',
        'too-long.txt': b'x' * 256 + b'\n',
        'limit.txt': b'l' * 255 + b'\n',
        'AUTOEXEC.BAT': emu.atascii(['CLS']),
    }
    atr = disk('vim-interactive', files, geo=(1440, 128))

    def chars(wid, text):
        for c in text:
            if c == '\n':
                emu.keys(wid, 'Return')
            elif c in emu.KEYSYM:
                emu.keys(wid, emu.KEYSYM[c])
            else:
                subprocess.run(['xdotool', 'type', '--window', wid, c],
                               capture_output=True)
                time.sleep(0.12)

    def command(wid, text, confirm=False):
        # Altirra/X11 intermittently drops SHIFT from ':'.  VIM accepts the
        # same physical key unshifted for automation; real ':' remains the
        # documented command key.
        emu.keys(wid, 'semicolon')
        chars(wid, text)
        emu.keys(wid, 'Return')
        time.sleep(0.8)
        if confirm:
            emu.keys(wid, 'y')

    def edit_new(wid):
        emu.type_line(wid, 'vim new.txt')
        time.sleep(1)
        emu.keys(wid, 'i')
        chars(wid, 'alpha')
        emu.keys(wid, 'Tab')
        chars(wid, 'tab\nbeta')
        emu.keys(wid, 'Escape')
        command(wid, 'wq')

    def edit_ops(wid):
        emu.type_line(wid, 'vim ops.txt')
        time.sleep(1)
        # x deleting a newline, x deleting a byte, dd, o, and a multiline
        # INSERT session must each be completely reversible by one u.
        emu.keys(wid, 'shift+4', 'x', 'u', '0', 'x', 'u', 'd', 'd', 'u', 'o')
        chars(wid, 'new')
        emu.keys(wid, 'Escape', 'u', 'i')
        chars(wid, 'X\nY')
        emu.keys(wid, 'Escape', 'u', '0', 'a', 'z', 'Escape', 'u',
                 'Right', 'Down', 'Up', 'Left', 'i', 'Right', 'Left',
                 'Down', 'Up', 'Escape')
        command(wid, 'w')
        emu.keys(wid, 'n')             # cancellation must retain dirty state
        time.sleep(0.5)
        command(wid, 'wq', confirm=True)

    def edit_lines(wid):
        emu.type_line(wid, 'vim lines.txt')
        time.sleep(1)
        emu.keys(wid, 'shift+g', '0', 'i')
        chars(wid, 'last-')
        emu.keys(wid, 'Escape', 'g', 'g', 'y', 'y', 'p', 'd', 'd', 'u')
        emu.type_keys(wid, '/last-line30')
        emu.keys(wid, 'n')             # wraps to the same sole match
        command(wid, 'wq', confirm=True)

    def edit_moving(wid):
        emu.type_line(wid, 'vim move.txt')
        time.sleep(1)
        emu.keys(wid, 'i', 'Right')
        chars(wid, 'x')
        emu.keys(wid, 'Down')
        chars(wid, 'y')
        emu.keys(wid, 'Down', 'Left')
        chars(wid, 'z')
        emu.keys(wid, 'Up')
        chars(wid, 'q')
        emu.keys(wid, 'Escape')
        command(wid, 'wq', confirm=True)

    def failed_edit(wid):
        emu.type_line(wid, 'vim keep.txt')
        time.sleep(1)
        command(wid, 'e bad.txt')      # validation failure must change nothing
        command(wid, 'e too-long.txt') # the 255-byte line limit is transactional
        command(wid, 'wq', confirm=True)

    def line_limit(wid):
        emu.type_line(wid, 'vim limit.txt')
        time.sleep(1)
        emu.keys(wid, 'shift+4', 'i', 'z', 'Escape')
        command(wid, 'wq', confirm=True)

    with Dumper('vim-interactive', label('k_prompt'), disks=[atr], memsize='64K',
                timeout=90) as d:
        if d.first is None:
            return False, 'no initial 64K command prompt'
        for action in (edit_new, edit_ops, edit_lines, edit_moving, failed_edit,
                       line_limit):
            if d.step(action) is None:
                return False, 'editor did not return to the command prompt'

    tree, errors, _ = disk_tree(atr)
    if errors:
        return False, 'EOSFS errors: %r' % errors
    got_new = tree.get('/new.txt', (0, None))[1]
    got_ops = tree.get('/ops.txt', (0, None))[1]
    got_move = tree.get('/move.txt', (0, None))[1]
    got_keep = tree.get('/keep.txt', (0, None))[1]
    got_bad = tree.get('/bad.txt', (0, None))[1]
    got_lines = tree.get('/lines.txt', (0, None))[1]
    got_limit = tree.get('/limit.txt', (0, None))[1]
    want_lines = ('line01\tvalue\nline01\tvalue\n' +
                  '\n'.join(lines[1:-1]) + '\nlast-line30\tvalue\n').encode('ascii')
    expected = [(got_new, b'alpha\ttab\nbeta\n', 'new LF/tab file'),
                (got_ops, b'ab\ncd\n', 'undo operations'),
                (got_move, b'oxne\ntwyqo\nthzree\n', 'INSERT arrow editing'),
                (got_keep, b'keep\r\nthis\r\n', 'failed :e/CRLF'),
                (got_bad, b'bad\x00text\n', 'rejected input'),
                (got_limit, b'l' * 255 + b'\n', '255-byte/full-line handling'),
                (got_lines, want_lines, 'normal/search/scroll/tab')]
    for got, want, what in expected:
        if got != want:
            return False, '%s: got %r, want %r' % (what, got, want)
    return True, '64K live keyboard modal/edit/undo/search/scroll/LF/CRLF acceptance'


def multi(name, files, groups, **kw):
    """oracle() for each list of commands in groups (one boot each, so that
    each fits on the screen); all must pass."""
    msgs = []
    for i, cmds in enumerate(groups):
        ok, msg = oracle('%s-%d' % (name, i + 1), files, cmds, **kw)
        if not ok:
            return False, '%d: %s' % (i + 1, msg)
        msgs.append(msg)
    return True, ', '.join(msgs)


def oracle(name, files, commands, disk=False, geo=None, d2=None, memsize='64K', sdx_pre=(),
           ends=False, last=False, adjust=None):
    """Same output on SDX and EOS; with disk, also the same files on D1:
    afterwards and no file system errors. d2: files for a disk in D2:.
    ends: the batch file may end early (sdx_lines). adjust: SDX's lines to
    what EOS shows by design where it differs (D: is D1:)."""
    want = sdx_lines(name, files, list(sdx_pre) + list(commands), geo, d2=d2, memsize=memsize,
                     ends=ends, last=last)
    if adjust and want is not None:
        want = adjust(want)
    got = our_lines(name, files, commands, geo, d2=d2, memsize=memsize)
    if disk and want is not None and got is not None:
        st, se, sfree = disk_tree(OUT / (name + '-sdx.atr'))
        ot, oe, ofree = disk_tree(OUT / (name + '.atr'))
        for p in ('/SDXPROBE.COM', '/AUTOEXEC.BAT', '/autoexec.bat'):
            st.pop(p, None)
            ot.pop(p, None)
        if oe:
            return False, 'file system errors: %s' % '; '.join(oe[:3])
        if st != ot:
            diff = sorted(p for p in set(st) | set(ot) if st.get(p) != ot.get(p))
            return False, 'disk differs: %s' % ', '.join(diff[:6])
        if sfree != ofree and not EOSFS:   # (EOSFS has no map sectors)
            return False, 'free sectors: SDX %d, EOS %d' % (sfree, ofree)
    if want is None or got is None:
        return False, 'no result from %s' % ('SDX' if want is None else 'EOS')
    diff = OUT / (name + '.diff')
    diff.unlink(missing_ok=True)
    if EOSFS and got is not None:   # the header's revision byte (DIRTEST's f line)
        got = [re.sub(r'^f 45 ', 'f 21 ', x) for x in got]
        # free sectors differ: no map sectors, a name index per directory
        def nofree(ls):
            ls = [re.sub(r'\d+ FREE SECTORS', '# FREE SECTORS', x) for x in ls]
            return [re.sub(r'^(f \S+ \S+ \S+ )\S+', r'\1#', x) for x in ls]
        got, want = nofree(got), nofree(want)
    if want != got and want[1:] == got:
        want = got                  # a full screen: EOS's prompt line scrolled it once more
    if want != got:
        (OUT / (name + '.diff')).write_text('SDX:\n%s\nEOS:\n%s\n' % ('\n'.join(want), '\n'.join(got)))
        return False, 'output differs, see %s.diff' % name
    return True, '%d lines' % len(want)


def native_output(name, files, commands, want, memsize='64K'):
    """Check behavior that is intentionally native EOS, with no SDX oracle."""
    got = our_lines(name, files, commands, memsize=memsize)
    if got == want:
        return True, '%d lines' % len(want)
    (OUT / (name + '.diff')).write_text('EXPECTED:\n%s\nEOS:\n%s\n' %
                                         ('\n'.join(want), '\n'.join(got or [])))
    return False, 'output differs, see %s.diff' % name


TYPE_FILES = {
    'HELLO.TXT': emu.atascii(['Hello from D1', 'second line', 'third']),
    'SUB/INNER.TXT': emu.atascii(['inner file']),
    'SUB/DEEP/LAST.TXT': emu.atascii(['two levels down']),
}
TYPE_CMDS = ['TYPE HELLO.TXT', 'TYPE SUB/INNER.TXT', 'TYPE /SUB/DEEP/LAST.TXT',
             'TYPE NONE.TXT', 'TYPE D2:X']


def tk(path):
    return (emu.BUILD / 'tkx' / path).read_bytes()


def tk_any(name):
    """A Toolkit binary by its name, wherever it is in build/tkx."""
    return next((emu.BUILD / 'tkx').rglob(name)).read_bytes()


def ours(name):
    """A test program from tests/eos, assembled by make eos."""
    return (emu.BUILD / 'eos' / name).read_bytes()


TEXT = emu.atascii(['Hello from D1', 'second line', 'third'])
MILESTONE_FILES = {
    'HEXDEC.COM': tk('UTILS/SHELLUTL/HEXDEC/HEXDEC.COM'),
    'WC.COM': tk('UTILS/FILEUTIL/WC/WC.COM'),
    'HELLO.TXT': TEXT,
}
MILESTONE_CMDS = ['HEXDEC 1234', 'HEXDEC 255', 'HEXDEC 4294967295', 'HEXDEC',
                  'WC HELLO.TXT', 'WC /L HELLO.TXT', 'WC /CW HELLO.TXT']


SYM_FILES = {
    'SYMLINK.SYS': tk('DRIVERS/SYMLINK/SYMLINK.SYS'),
    'MKLINK.COM': tk('DRIVERS/SYMLINK/MKLINK.COM'),
    'HELLO.TXT': TEXT,
    'SUB/INNER.TXT': emu.atascii(['inner file']),
}
SYM_CMDS = ['SYMLINK.SYS', 'MKLINK HELLO.TXT LINK.TXT', 'MKLINK SUB>INNER.TXT IN.LNK',
            'TYPE LINK.TXT', 'TYPE IN.LNK', 'MKLINK NONE.TXT BAD.LNK', 'TYPE BAD.LNK',
            'MKLINK HELLO.TXT SUB>INNER.TXT']
def full_files(waste):
    """FULL.COM on an SD disk; with waste, a filler file so that the disk
    fills just after a new sector map (free = 63k + 1 before BIG.DAT)."""
    for filler in range(64):
        files = {'FULL.COM': ours('FULL.COM'), 'FILL.DAT': bytes(128 * filler),
                 'AUTOEXEC.BAT': emu.atascii(['CLS', 'FULL']),
                 'SDXPROBE.COM': sdxprobe.PROBE.read_bytes()}
        free = sdfs.Volume(str(disk('full-probe', files))).free
        if not waste or free % 63 == 1:
            break
    del files['AUTOEXEC.BAT'], files['SDXPROBE.COM']
    return files


# B0b: a drive alone as a command makes it current; names without a device
# are then found there (the commands end on A: so that SDXPROBE runs on SDX)
CUR_D2 = {
    'ONLY2.TXT': emu.atascii(['only on drive 2']),
    'HEXDEC.COM': tk('UTILS/SHELLUTL/HEXDEC/HEXDEC.COM'),
    'SUB/IN2.TXT': emu.atascii(['in a directory on drive 2']),
}
CUR_CMDS = ['B:', 'TYPE ONLY2.TXT', 'HEXDEC 4660', 'TYPE SUB>IN2.TXT', 'A:',
            'TYPE ONLY2.TXT', 'TYPE B:ONLY2.TXT', 'D2:', 'TYPE HELLO.TXT', 'D1:',
            'TYPE HELLO.TXT', 'TYPE 2:ONLY2.TXT', 'TYPE DB:ONLY2.TXT', '2:', 'TYPE ONLY2.TXT',
            'DA:', 'TYPE HELLO.TXT']

def t_prompt():
    """The bracketed prompt includes the active drive and directory."""
    got = [our_lines('prompt-' + c[:-1], {}, [c]) for c in ('J:', 'CAR:')]
    nested = our_lines('prompt-dir', {}, ['mkdir rick', 'cd rick', 'pwd'])
    want = [['[DJ:/]'], ['[DCAR1:/]']]
    return got == want and nested == ['D1:/rick/', '[D1:/rick/]'], repr((got, nested))


def t_mem_bytes():
    """Plain MEM reports main RAM and each free extended bank in bytes."""
    results = []
    for size in ('64K', '320K'):
        lines = our_lines('mem-bytes-' + size.lower(), {}, ['mem'], memsize=size)
        main = next((re.fullmatch(r'Free: (\d+) main bytes', x) for x in (lines or [])
                     if x.startswith('Free: ')), None)
        banks = next((re.fullmatch(r'(\d+) Ext banks free \((\d+) bytes\)', x)
                      for x in (lines or []) if 'Ext banks free' in x), None)
        if not main or int(main.group(1)) <= 0 or not banks:
            return False, '%s output %r' % (size, lines)
        if int(banks.group(2)) != int(banks.group(1)) * 16384:
            return False, '%s bank conversion %r' % (size, banks.groups())
        results.append((size, main.group(1), banks.groups()))
    return True, repr(results)


DIRS_FILES = {
    'HELLO.TXT': TEXT,
    'OTHER.DAT': bytes(300),
    'SUB/INNER.TXT': emu.atascii(['inner file']),
    'SUB/DEEP.D/LAST.TXT': emu.atascii(['two levels down']),
}

PARSE_CMDS = ['PARSE A $4000 2:$4000 COMTAB COMTAB+3 COMTAB-4',
              # symbol+n and -n, but not right after a symbol alone (SDX)
              'PARSE A COMTAB-4 COMTAB+3 $10 COMTAB+$10 COMTAB COMTAB-1 COMTAB+1',
              'PARSE A 70000 $123456 NOSUCHSY 12X $10000',
              'PARSE T ONE TWO THREE X TW THREEX',
              'PARSE F D1: SUB> X.COM D2:>A> < *.*',
              'PARSE P D1:X.COM D2:>SUB>X B:Y CAR:Z PRN: J:A>B>',
              'PARSE E',
              'PARSE O ON OFF ON MAYBE']


DIRS_CMDS = [['DIRTEST 1'], ['DIRTEST 2']]


def fdir_files():
    """Entries of all kinds for FDOPEN: dates, times, attributes, sizes."""
    P, H, A = sdfs.ST_PROT, sdfs.ST_HIDDEN, sdfs.ST_ARCH
    return {
        'FDT.COM': ours('FDT.COM'),
        'A.TXT': (bytes(10), (31, 12, 99, 0, 0, 0), 0),
        'B.TXT': (bytes(5), (1, 2, 0, 9, 5, 7), 0),
        'C.DAT': (bytes(120000), (15, 6, 24, 13, 45, 59), A),
        'PROT.X': (bytes(1), (9, 9, 9, 23, 59, 1), P),
        'HIDE.Y': (bytes(2), (10, 10, 10, 12, 0, 30), H),
        'NOEXT': (bytes(3), (2, 3, 4, 11, 59, 0), 0),
        'ALL.ATT': (bytes(4), (5, 5, 5, 1, 2, 3), P | H | A),
        'EMPTY.Z': (b'', (6, 7, 8, 0, 30, 0), 0),
        'DIRX.EXT/IN.F': (bytes(7), (1, 1, 25, 12, 0, 0), 0),
    }


FDIR_MODES = ['0', '1', '2', '8', '$40', '$7F', '$80', '$81', '$88', '$C0', '$FF']


def t_dir_native():
    """DIR decodes the EOSFS length/name/timestamp fields, not legacy 8.3 offsets."""
    files = {
        'phd.com': b'x' * 368,
        'stat.com': b'x' * 1223,
        'long name with spaces.com': b'x' * 17,
        'man/X.TXT': b'x',
    }
    got = our_lines('dir-native', files, ['DIR'])
    if got is None:
        return False, 'no result from EOS'
    want = [
        'Directory: main',
        'phd.com     368  1-01-25 12:00',
        'stat.com    1223  1-01-25 12:00',
        'long name with spaces.com      17  1-0',
        'man  <DIR>   1-01-25 12:00',
    ]
    missing = [line for line in want if line not in got]
    if missing:
        return False, 'missing %r in %r' % (missing, got)
    return True, '%d native directory lines' % len(got)


def t_dir6():
    """D: open mode 6 from BASIC: Atari DOS 2's listing, the lines as SDX
    shows them (measured 2026-11-03; SDX's own run cannot end its batch:
    its BASIC fails saving MEM.SAV on DOS)."""
    prog = ['10 DIM L$(80)', '20 OPEN #1,6,0,"D:*.*"', '30 TRAP 60', '40 INPUT #1,L$',
            '50 PRINT "[";L$;"]":GOTO 40', '60 CLOSE #1', '70 OPEN #1,6,0,"D:A*.*"', '80 TRAP 110',
            '90 INPUT #1,L$', '100 PRINT "<";L$;">":GOTO 90', '110 CLOSE #1:DOS', 'RUN']
    files = {'A.TXT': emu.atascii(['HELLO'] * 40), 'AB.DAT': b'x' * 3000, 'SUB/X.TXT': b'1',
             'GO.TXT': emu.atascii(prog)}
    want = ['[  A       TXT 001]', '[  AB      DAT 012]', '[  GO      TXT 001]',
            '[  AUTOEXECBAT 001]', '[  SDXPROBECOM 001]', '[ :SUB         001]',
            '<  A       TXT 001>', '<  AB      DAT 012>', '<  AUTOEXECBAT 001>']
    got = our_lines('dir6', files, ['BASIC /I <<D1:GO.TXT'], geo=(720, 256))
    if got is None:
        return False, 'no result from EOS'
    miss = [w for w in want if w not in got]
    free = [x for x in got if x.endswith('FREE SECTORS]') or x.endswith('FREE SECTORS>')]
    if miss or len(free) != 2:
        return False, 'missing %r, free lines %r' % (miss, free)
    return True, '%d lines' % len(got)


def t_siodrv():
    """D2: a driver in sio_vector serves files: SVT.COM installs one that
    takes D8:'s transfers to unit 1, so D8: shows D1:'s files."""
    files = {'SVT.COM': ours('SVT.COM'), 'HELLO.TXT': TEXT}
    got = our_lines('siodrv', files, ['TYPE D8:HELLO.TXT', 'SVT', 'TYPE D8:HELLO.TXT', 'DIR D8:'],
                    geo=(720, 256))
    if got is None:
        return False, 'no result from EOS'
    i = next((k for k, x in enumerate(got) if x == 'installed'), None)
    if i is None:
        return False, 'not installed: %r' % got[-6:]
    before, after = got[:i], got[i:]
    if any('Hello from D1' in x for x in before):
        return False, 'D8: answered before the driver: %r' % before
    if not any('Hello from D1' in x for x in after) or not any('SVT' in x and 'COM' in x for x in after):
        return False, 'D8: not served: %r' % after
    return True, '%d lines' % len(got)


TKX = emu.BUILD / 'tkx'
COMTAB = 0x0A3A


def tkfiles():
    """The Toolkit's console programs: RC_GR8.SYS, CON.SYS, Sparta Commander."""
    f = {'RC_GR8.SYS': (TKX / 'DRIVERS/SCRDRV/RC_GR8/RC_GR8.SYS').read_bytes(),
         'CON.SYS': (TKX / 'DRIVERS/SCRDRV/CON/CON.SYS').read_bytes()}
    for n in ('SC.COM', 'SCMAIN.OVL', 'SC.INI'):
        f[n] = (TKX / 'SHELLS/SC109' / n).read_bytes()
    return f


def t_blkio():
    """D2: jblock_io: bm_fread and bm_read give D1:'s sectors 1 and 4 as
    the disk has them; bm_flush and bm_abort succeed; function 6 is 146."""
    got = our_lines('blkio', {'BIO.COM': ours('BIO.COM')}, ['BIO'], geo=(720, 128))
    if got is None:
        return False, 'no result'
    img = (OUT / 'blkio.atr').read_bytes()[16:]
    want = ['s1', ' '.join('%d' % b for b in img[:8]),
            's1', ' '.join('%d' % b for b in img[3 * 128:3 * 128 + 8]), 's1', 's1', 's146']
    return got == want, '%r' % got


def t_secmx():
    """D2: jsector_io with memreix (the sector into a program extended bank)
    and with an XDCB ($B1: as a DCB; a 24-bit sector number: 184)."""
    got = our_lines('secmx', {'MXT.COM': ours('MXT.COM')}, ['MXT'], geo=(720, 128),
                    memsize='320K')
    if got is None:
        return False, 'no result'
    img = (OUT / 'secmx.atr').read_bytes()[16:]
    row = ' '.join('%d' % b for b in img[:8])
    want = ['s1', row, 's1', row, 's184']
    return got == want, '%r' % got


def t_eosdirty():
    """E3: EOSFS's dirty flag (docs/EOSFS.md 3.1): a file written and never
    closed (BASIC, then a loop) leaves the header's revision $46 on the
    disk as soon as a sector has gone out; EOS mounting such a disk counts
    the free sectors again from the bitmap and writes the header clean
    ($45); a COPY ends with it clean."""
    global EOSFS
    old = EOSFS
    EOSFS = True
    try:
        prog = ['10 OPEN #1,8,0,"D1:X.DAT"', '20 FOR I=1 TO 4000:PUT #1,65:NEXT I',
                '30 GOTO 30', 'RUN']
        files = {'GO.TXT': emu.atascii(prog), 'AUTOEXEC.BAT': emu.atascii(['BASIC /I <<D1:GO.TXT'])}
        atr = disk('eosdirty-1', files, geo=(720, 256))
        with Dumper('eosdirty-1', label('k_prompt'), disks=[atr], timeout=40):
            pass
        img = bytearray(atr.read_bytes())
        if img[16 + 32] != 0x46:
            return False, 'left open: revision $%02X, not $46' % img[16 + 32]
        # a disk left so, with a wrong free count on top: mounted, checked,
        # then written to (COPY) and listed
        files2 = {'AUTOEXEC.BAT': emu.atascii(['CLS', 'COPY GO.TXT G2.TXT', 'DIR', ' ' * 8])}
        atr3 = disk('eosdirty-2', dict(files, **files2), geo=(720, 256))
        img3 = bytearray(atr3.read_bytes())
        img3[16 + 32] = 0x46
        img3[16 + 13] = (img3[16 + 13] + 7) & 0xFF
        atr3.write_bytes(bytes(img3))
        with Dumper('eosdirty-2', label('k_prompt'), disks=[atr3], timeout=60) as d:
            m = d.first
        if m is None:
            return False, 'no prompt after the checked mount'
        img3 = atr3.read_bytes()
        v = sdfs.Volume(str(atr3))
        v.check()
        free = img3[16 + 13] | img3[16 + 14] << 8
        if img3[16 + 32] != 0x45:
            return False, 'after the mount: revision $%02X' % img3[16 + 32]
        if v.errors:
            return False, 'sdfs.py: %s' % '; '.join(v.errors[:3])
        if free != v.free:
            return False, 'free count %d, the bitmap says %d' % (free, v.free)
        return True, 'left open: $46 on the disk; mounted: $45, free %d as the bitmap' % free
    finally:
        EOSFS = old


def t_zsys():
    """C5: CAR:Z.SYS: Z: as SD 3.2's: with /S the date set through XIO 37
    and three PUTs reads back through XIO 35; a fourth GET is 136; without
    /S a PUT is 139."""
    prog = ['10 OPEN #1,8,0,"Z:":XIO 37,#1,8,0,"Z:"', '20 PUT #1,2:PUT #1,3:PUT #1,26:CLOSE #1',
            '30 OPEN #1,4,0,"Z:":XIO 35,#1,4,0,"Z:"', '40 GET #1,D:GET #1,M:GET #1,Y',
            '50 PRINT "[";D;" ";M;" ";Y;"]":TRAP 70:GET #1,X', '60 PRINT "no eof"',
            '70 PRINT "e";PEEK(195):CLOSE #1:DOS', 'RUN']
    got = our_lines('zsys', {'GO.TXT': emu.atascii(prog)},
                    ['Z.SYS /S', 'BASIC /I <<D1:GO.TXT'], geo=(720, 256))
    if got is None or '[2 3 26]' not in got or 'e136' not in got:
        return False, '/S: %r' % (got and got[-6:])
    prog2 = ['10 TRAP 30:OPEN #1,8,0,"Z:":XIO 36,#1,8,0,"Z:"', '20 PUT #1,1:PRINT "no error"',
             '30 PRINT "e";PEEK(195):CLOSE #1:DOS', 'RUN']
    got2 = our_lines('zsys2', {'GO.TXT': emu.atascii(prog2)},
                     ['Z.SYS', 'BASIC /I <<D1:GO.TXT'], geo=(720, 256))
    if got2 is None or 'e139' not in got2:
        return False, 'no /S: %r' % (got2 and got2[-6:])
    return True, 'date 2-3-26 set and read back'


def t_comexe():
    """C5: CAR:COMEXE.SYS: HX (only HX.EXE there) and HX.EXE run through X,
    the cartridge off; +HX goes past COMEXE (170); without COMEXE an .EXE
    runs as any program, the cartridge on."""
    files = {'HX.EXE': ours('HX.COM')}
    got = our_lines('comexe', files, ['HX.EXE', 'COMEXE.SYS', 'HX', 'HX.EXE', '+HX'],
                    geo=(720, 256))
    if got is None:
        return False, 'no result'
    tags = [x for x in got if x in ('ram', 'rom') or x.startswith('170')]
    want = ['rom', 'ram', 'ram', '170 File not found']
    return tags == want, '%r' % got


def t_runext():
    """C5: CAR:RUNEXT.SYS: a configuration's associations: NAME.EXT runs its
    program with % the name (or the name at the end) and the rest of the
    line; ! and ^ lines need SHIFT/CTRL; +NAME skips them; RUNEXT lists it."""
    cfg = emu.atascii(['; test', '!TXT,ECHO,shift', 'TXT:DOC,ECHO,[%]', 'DAT,ECHO,x'])
    files = {'RX.CFG': cfg, 'A.TXT': TEXT, 'B.DAT': b'1'}
    got = our_lines('runext', files, ['RUNEXT.SYS RX.CFG', 'A.TXT more', 'X.DOC', 'B.DAT',
                                      '+A.TXT', 'RUNEXT'], geo=(720, 256))
    if got is None:
        return False, 'no result'
    want = ['[A.TXT] more', '[X.DOC]', 'x B.DAT']
    if [x for x in got if x in want] != want or 'DAT,ECHO,x' not in got:
        return False, '%r' % got
    if any('shift' == x for x in got):
        return False, 'a ! line matched: %r' % got
    return True, '%d lines' % len(got)


def t_history_default():
    """Four Up presses reach the oldest entry in the default history."""
    atr = disk('history-default', {}, geo=(720, 256))
    with Dumper('history-default', label('k_prompt'), disks=[atr], timeout=30) as d:
        if d.first is None:
            return False, 'no initial prompt'
        for n in range(1, 5):
            if d.step(lambda wid, n=n: emu.type_keys(wid, 'echo history-%d' % n)) is None:
                return False, 'command %d did not return' % n
        m = d.step(lambda wid: emu.keys(wid, 'Up', 'Up', 'Up', 'Up', 'Return'))
    lines = [x for x in screen(m) if x] if m else []
    count = lines.count('history-1')
    return count == 2, '%d oldest-entry outputs: %r' % (count, lines[-8:])


def t_doskey():
    """C5: CAR:DOSKEY.SYS: a typed line recalled with the up arrow runs
    again; an alias (aliases file) runs its command; with /X an empty line
    lists the directory. Typed into a live prompt, the screen is read from a
    dump taken at the vertical blank."""
    files = {'al.ini': emu.atascii(['e1=echo aliased >alias.out']),
             'AUTOEXEC.BAT': emu.atascii(['doskey.sys al.ini /X'])}
    atr = disk('doskey', files, geo=(720, 256))
    mem = OUT / 'doskey.bin'
    mem.unlink(missing_ok=True)
    cmds = ['bp $C0E2 ".writemem %s 0 L10000; g"' % emu.win(mem)]
    with emu.Session(OUT, [atr], cart=CAR, name='doskey', debugcmds=cmds):
        time.sleep(10)
        wid = emu.window_id()
        emu.type_line(wid, 'CLS')
        time.sleep(2)
        emu.type_line(wid, 'ECHO one')
        time.sleep(2)
        emu.keys(wid, 'Up')
        emu.keys(wid, 'Return')
        time.sleep(2)
        emu.type_line(wid, 'E1')
        time.sleep(2)
        emu.keys(wid, 'Return')
        time.sleep(4)
        emu.type_line(wid, 'CLS')
        time.sleep(2)
        emu.type_line(wid, 'type alias.out')
        time.sleep(3)
        emu.screenshot(OUT / 'doskey.png')
        m = wait_dump(mem, 10)
    if m is None:
        return False, 'no dump'
    lines = [x for x in screen(m) if x]
    ok = any('TYPE ALIAS.OUT' in x.upper() for x in lines) and 'aliased' in lines
    return ok, '%r' % lines


def t_builddir():
    """BUILDDIR (13.2): a soft format of D2: with a label, through EOS's
    CAR:FORMAT; the result is a clean empty EOSFS v2 image."""
    got = our_lines('builddir', {'bld.com': ours('BLD.COM')}, ['bld'],
                    geo=(720, 256), d2={'OLD.TXT': TEXT})
    if got is None:
        return False, 'no result'
    vol = sdfs.Volume(str(OUT / 'builddir-d2.atr'))
    entries = vol.check()
    ok = 'done' in got and vol.eosfs and vol.name == 'TESTLAB' and not entries and not vol.errors
    return ok, 'output=%r label=%r entries=%r errors=%r' % (got, vol.name, entries, vol.errors)


def t_hssio():
    """E2: SIOSET 1 US on Altirra's US Doubler (real timing): the drive's
    index from '?', then TYPE, a COPY (writes) and jblock_io reads at that
    rate give the disk's data."""
    old = {k: os.environ.get(k) for k in ('EOS_DISKEMU', 'EOS_REAL')}
    os.environ['EOS_DISKEMU'] = 'usdoubler'
    os.environ['EOS_REAL'] = '1'
    try:
        got = our_lines('hssio', {'A.TXT': TEXT, 'BIO.COM': ours('BIO.COM')},
                        ['SIOSET 1 US', 'TYPE A.TXT', 'COPY A.TXT B.TXT', 'BIO'],
                        geo=(720, 128), timeout=300)
    finally:
        for k, v in old.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
    if got is None:
        return False, 'no result'
    img = (OUT / 'hssio.atr').read_bytes()[16:]
    tree = disk_tree(OUT / 'hssio.atr')[0]
    ok = ('1  US     $0A' in got and 'Hello from D1' in got and
          ' '.join('%d' % b for b in img[:8]) in got and
          tree.get('/B.TXT', (0, None))[1] == TEXT)
    return ok, '%r' % got


def t_rs232_850():
    """CAR:RS232 downloads and initializes R: from an emulated Atari 850."""
    m = dump_at('rs232-850', label('k_prompt'), timeout=60,
                then=lambda wid: emu.type_line(wid, 'RS232'),
                devices=[{'tag': '850', 'params': {'baudex': True, 'emulevel': 2}}])
    if m is None:
        return False, 'RS232 did not return to the command prompt'
    have_r = any(m[0x031A + x] == ord('R') for x in range(0, 36, 3))
    lines = [x for x in screen(m) if x]
    ok = have_r and not any('138 Device does not respond' in x for x in lines)
    return ok, 'MEMLO $%04X, screen %r' % (word(m, 0x02E7), lines[-5:])


def xf_sio(name, emu_mode, word):
    """SIOSET 1 XF / INDUS on Altirra's XF551 / Indus GT (real timing): the
    XF551's high speed commands (R $D2, P $D0: the disk command log shows
    them), TYPE, a COPY and jblock_io reads give the disk's data."""
    log = OUT / (name + '-cmd.log')
    log.unlink(missing_ok=True)
    keys = ('EOS_DISKEMU', 'EOS_REAL', 'EMU_DBG')
    old = {k: os.environ.get(k) for k in keys}
    os.environ['EOS_DISKEMU'] = emu_mode
    os.environ['EOS_REAL'] = '1'
    # (the log closed at the prompt: k_getline's second instruction, as
    # the first has our_lines's breakpoint)
    os.environ['EMU_DBG'] = '.logopen %s|lfe diskcmd|bp $%04X ".logclose; g"' % (
        emu.win(log), label('k_prompt'))
    try:
        got = our_lines(name, {'A.TXT': TEXT, 'BIO.COM': ours('BIO.COM')},
                        ['SIOSET 1 ' + word, 'TYPE A.TXT', 'COPY A.TXT B.TXT', 'BIO'],
                        geo=(720, 128), timeout=300)
    finally:
        for k, v in old.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
    if got is None:
        return False, 'no result'
    img = (OUT / (name + '.atr')).read_bytes()[16:]
    tree = disk_tree(OUT / (name + '.atr'))[0]
    cmds = log.read_text(errors='replace') if log.exists() else ''
    fast = cmds.count('Command D2'), cmds.count('Command D0') + cmds.count('Command D7')
    ok = ('1  ' + word in got and 'Hello from D1' in got and
          ' '.join('%d' % b for b in img[:8]) in got and
          tree.get('/B.TXT', (0, None))[1] == TEXT and fast[0] > 0 and fast[1] > 0)
    return ok, 'high speed reads %d, writes %d: %r' % (fast + (got,))


def t_xfsio():
    return xf_sio('xfsio', 'xf551', 'XF')


def t_indussio():
    return xf_sio('indussio', 'indusgt', 'INDUS')


def t_envsys():
    """C5: CAR:ENV.SYS: the environment moves to a bank of its own: a
    variable set before stays, then 20 variables of 37 bytes each (over
    700 bytes, the old limit was 256) all show in SET."""
    cmds = ['SET KEEP=1', 'ENV.SYS'] + ['SET V%02d=%s' % (i, 'X' * 32) for i in range(20)] + ['SET']
    got = our_lines('envsys', {}, cmds, geo=(720, 256), memsize='320K', timeout=120)
    if got is None:
        return False, 'no result'
    want = ['KEEP=1'] + ['V%02d=%s' % (i, 'X' * 32) for i in range(20)]
    miss = [w for w in want if w not in got]
    return not miss, 'missing %r' % miss[:3] if miss else '%d lines' % len(got)


def t_xep80():
    """CAR:XEP80.SYS (Altirra's XEP80 handler, eos/xep80) with Altirra's
    XEP80 on joystick port 2: the batch's output after it is on the XEP80's
    80-column screen. Read from its video RAM in a saved state at the next
    prompt: the handler's banner, ECHO, DIR and the prompt."""
    import zipfile
    files = {'AUTOEXEC.BAT': emu.atascii(['CAR:XEP80.SYS', 'ECHO HELLO FROM EOS', 'DIR'])}
    atr = disk('xep80', files, geo=(720, 256))
    st = OUT / 'xep80.atstate2'
    st.unlink(missing_ok=True)
    cmds = ['bp $%04X ".savestate %s"' % (label('k_prompt'), emu.win(st))]
    with emu.Session(OUT, [atr], cart=CAR, name='xep80', debugcmds=cmds,
                     devices=[{'tag': 'xep80', 'params': {'port': 2}}]):
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline and not (st.exists() and zipfile.is_zipfile(st)):
            time.sleep(0.5)
        time.sleep(1)
        emu.screenshot(OUT / 'xep80.png')
    if not st.exists():
        return False, 'no saved state'
    vram = zipfile.ZipFile(st).read('xep80-vram.bin')
    rows = [bytes(c & 0x7F for c in vram[r:r + 80]).decode('latin-1').rstrip('\x1b\x00 ')
            for r in range(0, len(vram), 256)]
    rows = [r for r in rows if r.strip()]
    want = ['for SpartaDOS X loaded', 'HELLO FROM EOS', 'AUTOEXEC BAT', 'FREE SECTORS', '[D1:/]']
    miss = [w for w in want if not any(w in r for r in rows)]
    return not miss, 'missing %r in %r' % (miss, rows[:6]) if miss else '%d rows' % len(rows)


def t_pipes():
    """Pipes (SDX 4.42 on): A | B | C through files in $TEMP, a parameter -
    for the stream coming in; the files are gone afterwards. The same lines
    as SDX's but the free sectors while the first command's file is open
    (EOS takes its sectors at another moment)."""
    files = {'A.TXT': emu.atascii(['alpha', 'beta']), 'B.TXT': emu.atascii(['bee']),
             'INVERSE.COM': (TKX / 'UTILS/SHELLUTL/INVERSE/INVERSE.COM').read_bytes()}
    cmds = ['SET TEMP=D1:>', 'DIR *.TXT | TYPE -', 'ECHO hi | TYPE -',
            'TYPE A.TXT | INVERSE | TYPE -', 'DIR *.TMP', 'ECHO end']
    want = sdx_lines('pipes', files, cmds, geo=(720, 256))
    got = our_lines('pipes', files, cmds, geo=(720, 256))
    if want is None or got is None:
        return False, 'no result (SDX %s, EOS %s)' % (want is not None, got is not None)
    free = lambda ls: [re.sub(r'^\d+ FREE', 'n FREE', x) for x in ls]
    return free(want) == free(got), '%r' % got


def t_pipe_cleanup():
    """Every shell-owned pipeline file is removed after parser, loader,
    command, and disk-full failures.  Inspect the resulting EOSFS image so a
    hidden or partially-created temporary cannot evade a directory wildcard.
    """
    cases = [
        ('parse', {}, ['echo "bad | cat', 'echo end'], '182 Path too long'),
        ('load', {}, ['echo ok | nosuch', 'echo end'], '170 File not found'),
        ('command', {}, ['cat missing | cat', 'echo end'], '170 File not found'),
        ('full', {'fill.bin': b'x' * 90500},
         ['echo 1234567890 | cat', 'echo end'], '162 Disk full'),
    ]
    failures = []
    for label_, files, commands, expected in cases:
        name = 'pipe-cleanup-' + label_
        got = our_lines(name, files, commands)
        paths = disk_tree(OUT / (name + '.atr'))[0]
        leaked = [p for p in paths if p.rsplit('/', 1)[-1].lower().startswith('pipe')]
        if got is None or expected not in got or not got or got[-1] != 'end' or leaked:
            failures.append('%s: output=%r leaked=%r' % (label_, got, leaked))
    return not failures, '; '.join(failures) if failures else 'parse/load/command/full clean'


def t_fsinfo_foreign():
    """The transient inspector bypasses the resident EOSFS mount and walks
    nested DOS2/MyDOS and SDFS directories through physical raw reads."""
    import dos2
    com = (emu.BUILD / 'etk/FSINFO.COM').read_bytes()
    tree = {'A.TXT': b'a', 'SUB/IN.TXT': b'i', 'SUB/DEEP/LAST.DAT': b'z'}
    cases = []
    mydos = OUT / 'fsinfo-mydos-src.atr'
    dos2.build(str(mydos), 720, 128, tree)
    cases.append(('mydos', mydos, 'MyDOS, VTOC revision 2'))
    sparta = OUT / 'fsinfo-sdfs-src.atr'
    sdfs.build(str(sparta), 720, 128, tree, eosfs=False)
    cases.append(('sdfs', sparta, 'SDFS revision $21'))
    tail = ['A.TXT', 'SUB/', 'SUB/IN.TXT', 'SUB/DEEP/', 'SUB/DEEP/LAST.DAT']
    failures = []
    for label_, image, heading in cases:
        got = our_lines('fsinfo-' + label_, {'fsinfo.com': com},
                        ['fsinfo D2:'], d2=image)
        if got is None or heading not in got or got[-5:] != tail:
            failures.append('%s: %r' % (label_, got))
    return not failures, '; '.join(failures) if failures else 'DOS/MyDOS and SDFS recursive'


def t_fscheck_foreign():
    """Transient structural checking accepts clean media and refuses a
    deliberately cross-linked data sector in both foreign formats."""
    import dos2

    def sector_offset(seclen, sector):
        if seclen <= 256 and sector <= 3:
            return 16 + (sector - 1) * 128
        if seclen <= 256:
            return 16 + 384 + (sector - 4) * seclen
        return 16 + (sector - 1) * seclen

    com = (emu.BUILD / 'etk/FSINFO.COM').read_bytes()
    images = []

    dp = OUT / 'fscheck-dos-src.atr'
    dos2.build(str(dp), 720, 128, {'A.TXT': b'a', 'B.TXT': b'b'})
    raw = bytearray(dp.read_bytes())
    root = sector_offset(128, 361)
    raw[root + 16 + 3:root + 16 + 5] = raw[root + 3:root + 5]
    dp.write_bytes(raw)
    images.append(('dos-crosslink', dp, 'cross-linked'))

    sp = OUT / 'fscheck-sdfs-src.atr'
    sdfs.build(str(sp), 720, 128, {'A.TXT': b'a', 'B.TXT': b'b'}, eosfs=False)
    vol = sdfs.Volume(str(sp))
    maps = [e['map'] for _, e in vol.walk() if not e['status'] & sdfs.ST_DIR]
    raw = bytearray(sp.read_bytes())
    a = sector_offset(128, maps[0]) + 4
    b = sector_offset(128, maps[1]) + 4
    raw[b:b + 2] = raw[a:a + 2]
    sp.write_bytes(raw)
    images.append(('sdfs-crosslink', sp, 'cross-linked'))

    dl = OUT / 'fscheck-dos-loop-src.atr'
    dos2.build(str(dl), 720, 128, {'LOOP.DAT': bytes(300)})
    dv = dos2.Dos2(dl)
    index, entry = next(dv.entries())
    first = entry[3] | entry[4] << 8
    raw = bytearray(dl.read_bytes())
    o = sector_offset(128, first)
    raw[o + 125] = (index << 2) | (first >> 8)
    raw[o + 126] = first & 0xff
    dl.write_bytes(raw)
    images.append(('dos-loop', dl, 'loop'))

    sl = OUT / 'fscheck-sdfs-loop-src.atr'
    sdfs.build(str(sl), 720, 128, {'LOOP.DAT': bytes(300)}, eosfs=False)
    sv = sdfs.Volume(str(sl))
    fmap = next(e['map'] for _, e in sv.walk() if not e['status'] & sdfs.ST_DIR)
    raw = bytearray(sl.read_bytes())
    o = sector_offset(128, fmap)
    raw[o:o + 2] = bytes((fmap & 0xff, fmap >> 8))
    sl.write_bytes(raw)
    images.append(('sdfs-loop', sl, 'loop'))

    failures = []
    for label_, image, expected in images:
        got = our_lines('fscheck-' + label_, {'fsinfo.com': com},
                        ['fsinfo --check D2:'], d2=image, timeout=30)
        joined = ' '.join(got or [])
        if expected not in joined or 'Filesystem OK' in joined:
            failures.append('%s: %r' % (label_, got))
    return not failures, ('; '.join(failures) if failures else
                          'cross-links and map/data loops rejected')


def t_fsimport_foreign():
    """Import nested trees from both foreign formats and refuse to overwrite
    an existing exact EOSFS destination."""
    import dos2
    com = (emu.BUILD / 'etk/FSINFO.COM').read_bytes()
    tree = {'A.TXT': emu.atascii(['alpha']),
            'SUB/IN.TXT': emu.atascii(['inner'])}
    images = []
    dp = OUT / 'fsimport-dos-src.atr'
    dos2.build(str(dp), 720, 128, tree)
    images.append(('dos', dp))
    sp = OUT / 'fsimport-sdfs-src.atr'
    sdfs.build(str(sp), 720, 128, tree, eosfs=False)
    images.append(('sdfs', sp))
    failures = []
    for label_, image in images:
        got = our_lines('fsimport-' + label_, {'fsinfo.com': com},
                        ['mkdir imported', 'fsinfo --import D2: imported',
                         'type imported/A.TXT', 'type imported/SUB/IN.TXT'],
                        d2=image, timeout=40)
        if got is None or got[-2:] != ['alpha', 'inner']:
            failures.append('%s: %r' % (label_, got))
    got = our_lines('fsimport-collision', {'fsinfo.com': com},
                    ['mkdir imported', 'echo local >imported/A.TXT',
                     'fsinfo --import D2: imported', 'type imported/A.TXT'],
                    d2=dp, timeout=40)
    if got is None or 'Import collision: imported/A.TXT' not in got or got[-1] != 'local':
        failures.append('collision: %r' % got)
    return not failures, '; '.join(failures) if failures else 'trees imported; collision refused'


def t_fsexport_foreign():
    """Explicit transient export writes one root file to clean DOS2/MyDOS
    and SDFS media, reports a lossy 8.3 mapping before the write, refuses a
    collision, and leaves unsupported sector geometry byte-for-byte intact.
    """
    import dos2
    com = (emu.BUILD / 'etk/FSEXPORT.COM').read_bytes()
    source = 'MixedLongName.txt'
    payload = bytes((i * 37 + 11) & 0xff for i in range(400))
    files = {'fsexport.com': com, source: payload}
    failures = []

    dp = OUT / 'fsexport-dos-src.atr'
    dos2.build(str(dp), 720, 128, {})
    got = our_lines('fsexport-dos', files, ['fsexport "' + source + '" D2:'],
                    d2=dp, timeout=40)
    dout = OUT / 'fsexport-dos-d2.atr'
    dvol = dos2.Dos2(dout)
    dent = {p: e for p, _, e in dvol.walk()}
    data = (b''.join(x for _, x, _ in dvol.chain(dent['MIXEDLON.TXT']))
            if 'MIXEDLON.TXT' in dent else None)
    joined = ''.join(got or [])
    if (got is None or ('Lossy export name: ' + source + ' -> MIXEDLON.TXT') not in joined or
            'Export as MIXEDLON.TXT to DOS2/MyDOS' not in joined or
            data != payload or dvol.check()):
        failures.append('DOS: output=%r data=%r check=%r' %
                        (got, None if data is None else len(data), dvol.check()))

    sp = OUT / 'fsexport-sdfs-src.atr'
    sdfs.build(str(sp), 720, 128, {}, eosfs=False)
    got = our_lines('fsexport-sdfs', files, ['fsexport "' + source + '" D2:'],
                    d2=sp, timeout=40)
    sout = OUT / 'fsexport-sdfs-d2.atr'
    svol = sdfs.Volume(str(sout))
    sent = {p: e for p, e in svol.check()}
    joined = ''.join(got or [])
    if (got is None or ('Lossy export name: ' + source + ' -> MIXEDLON.TXT') not in joined or
            'Export as MIXEDLON.TXT to SDFS' not in joined or
            sent.get('/MIXEDLON.TXT', {}).get('data') != payload or svol.errors):
        failures.append('SDFS: output=%r entries=%r errors=%r' %
                        (got, sorted(sent), svol.errors))

    cp = OUT / 'fsexport-collision-src.atr'
    dos2.build(str(cp), 720, 128, {'MIXEDLON.TXT': b'foreign'})
    before = cp.read_bytes()
    got = our_lines('fsexport-collision', files,
                    ['fsexport "' + source + '" D2:'], d2=cp, timeout=40)
    after = (OUT / 'fsexport-collision-d2.atr').read_bytes()
    if got is None or 'Export collision: MIXEDLON.TXT' not in got or after != before:
        failures.append('collision: output=%r changed=%s' % (got, after != before))

    gp = OUT / 'fsexport-geometry-src.atr'
    sdfs.build(str(gp), 720, 256, {}, eosfs=False)
    before = gp.read_bytes()
    got = our_lines('fsexport-geometry', files,
                    ['fsexport "' + source + '" D2:'], d2=gp, timeout=40)
    after = (OUT / 'fsexport-geometry-d2.atr').read_bytes()
    if (got is None or 'Only 128-byte foreign media can be exported' not in ''.join(got) or
            after != before):
        failures.append('geometry: output=%r changed=%s' % (got, after != before))
    return not failures, ('; '.join(failures) if failures else
                          'DOS/SDFS export, mapping, collision, geometry refusal')


def t_fscreate_foreign():
    """The explicit transient creator makes clean empty 720x128 DOS2 and
    SDFS volumes and refuses a different geometry without changing it."""
    import dos2
    com = (emu.BUILD / 'etk/FSCREATE.COM').read_bytes()
    files = {'fscreate.com': com}
    failures = []

    dp = OUT / 'fscreate-dos-src.atr'
    sdfs.build(str(dp), 720, 128, {'OLD.DAT': b'old'}, eosfs=False)
    got = our_lines('fscreate-dos', files, ['fscreate --dos2 D2:'], d2=dp,
                    timeout=40)
    dvol = dos2.Dos2(OUT / 'fscreate-dos-d2.atr')
    if (got is None or 'Filesystem created' not in got or list(dvol.walk()) or
            dvol.check()):
        failures.append('DOS: output=%r entries=%r check=%r' %
                        (got, list(dvol.walk()), dvol.check()))

    sp = OUT / 'fscreate-sdfs-src.atr'
    dos2.build(str(sp), 720, 128, {'OLD.DAT': b'old'})
    got = our_lines('fscreate-sdfs', files, ['fscreate --sdfs D2:'], d2=sp,
                    timeout=40)
    svol = sdfs.Volume(str(OUT / 'fscreate-sdfs-d2.atr'))
    entries = svol.check()
    if got is None or 'Filesystem created' not in got or entries or svol.errors:
        failures.append('SDFS: output=%r entries=%r errors=%r' %
                        (got, entries, svol.errors))

    gp = OUT / 'fscreate-geometry-src.atr'
    sdfs.build(str(gp), 720, 256, {'OLD.DAT': b'old'}, eosfs=False)
    before = gp.read_bytes()
    got = our_lines('fscreate-geometry', files, ['fscreate --sdfs D2:'], d2=gp,
                    timeout=40)
    after = (OUT / 'fscreate-geometry-d2.atr').read_bytes()
    if (got is None or 'Refusing create: drive is not 720 x 128 bytes' not in
            ''.join(got) or after != before):
        failures.append('geometry: output=%r changed=%s' % (got, after != before))
    return not failures, ('; '.join(failures) if failures else
                          'clean DOS/SDFS creation; geometry refusal')


def t_fsw_native(geo=None, suffix=''):
    """Native EOSFS create/append/update/tree/rename/delete/large-file path,
    using exact command casing and slash paths rather than an SDFS oracle."""
    expected = ['1 created', '2 appended', '3 updated', '4 length 307',
                'sum 33360 of 307', '5 dir', '6 renamed', '7 deleted',
                '8 length 9000', 'sum 53848 of 9000']
    testname = 'fsw' + suffix
    got = our_lines(testname, {'fsw.com': ours('FSW.COM')}, ['fsw'], geo=geo)
    tree, errors, _ = disk_tree(OUT / (testname + '.atr'))
    sizes = {p: len(v[1] or b'') for p, v in tree.items()}
    want = {'/REN.TXT': 307, '/DIR': 0, '/DIR/IN.TXT': 6, '/BIG.DAT': 9000}
    bad = {p: sizes.get(p) for p in want if sizes.get(p) != want[p]}
    leftovers = [p for p in ('/NEW.TXT', '/DEL.TXT', '/EMPTY') if p in tree]
    ok = got == expected and not errors and not bad and not leftovers
    return ok, '%r errors=%r bad=%r leftovers=%r' % (got, errors, bad, leftovers)


def t_fsinfo_native():
    got = our_lines('fsinfo-native', {
        'fsinfo.com': (emu.BUILD / 'etk/FSINFO.COM').read_bytes()}, ['fsinfo D1:'])
    ok = bool(got and got[0] == 'EOSFS v2' and
              re.fullmatch(r'128 bytes/sector, 720 total, \d+ free', got[1]))
    return ok, repr(got)


def t_ddrive():
    """Drive letters and CIO devices: D: at the prompt is always D1: (as CIO
    has it; SDX: drive letter D, D4:), whatever the current drive; E: is the
    screen; K: and C: (CIO devices) are not drives (130); B: is D2:, D4:
    drive 4. Drives whose letter is a CIO device's are named D3:, D4:, D5:,
    DK: (DF /A; PWD)."""
    files = {'A1.TXT': emu.atascii(['one'])}
    cmds = ['D2:', 'TYPE D:A1.TXT', 'TYPE B2.TXT', 'D:', 'TYPE A1.TXT', 'TYPE B:B2.TXT',
            'TYPE D4:X.TXT', 'COPY A1.TXT E:', 'DIR K:', 'DIR C:', 'TYPE DC:X.TXT']
    got = our_lines('ddrive', files, cmds, d2={'B2.TXT': emu.atascii(['two'])})
    want = ['one', 'two', 'one', 'two', '138 Device does not respond', 'A1.TXT', 'one',
            '130 Nonexistent device', '130 Nonexistent device', '138 Device does not respond']
    df = our_lines('ddrive-df', files, ['DF /A', 'PWD'], d2={'B2.TXT': emu.atascii(['two'])})
    names = [x[:4] for x in (df or [])[2:17]]
    want_names = ['A:  ', 'B:  ', 'D3: ', 'D4: ', 'D5: ', 'F:  ', 'G:  ', 'H:  ', 'I:  ',
                  'J:  ', 'DK: ', 'L:  ', 'M:  ', 'N:  ', 'O:  ']
    ok = got == want and names == want_names and (df or [])[-1:] == ['A:/']
    return ok, '%r; %r' % (got, df)


def t_rddump():
    """The RAM disk's PERCOM block (N: one track of all its sectors): the
    EOS Toolkit's RDDUMP saves O: (704 sectors at 320K) to a file, RDLOAD
    puts it back after a file there was deleted."""
    etk = emu.BUILD / 'etk'
    files = {'A.TXT': emu.atascii(['ramdisk data']), 'RDDUMP.COM': (etk / 'RDDUMP.COM').read_bytes(),
             'RDLOAD.COM': (etk / 'RDLOAD.COM').read_bytes()}
    cmds = ['COPY A.TXT O:', 'RDDUMP O: D1:RD.DMP', 'DEL O:A.TXT', 'RDLOAD D1:RD.DMP O:',
            'TYPE O:A.TXT']
    got = our_lines('rddump', files, cmds, geo=(2880, 256), memsize='320K', timeout=200)
    dump = disk_tree(OUT / 'rddump.atr')[0].get('/RD.DMP', (0, b''))[1] or b''
    ok = got == ['A.TXT', '704 sectors dumped', 'Ramdisk restored', 'ramdisk data'] and len(dump) == 704 * 256
    return ok, '%r, %d bytes' % (got, len(dump))


def t_xcomli():
    """XCOMLI (lib): a program runs a command line through the command
    processor and goes on: the Toolkit's XT times ECHO, TYPE and a program
    that is not there (its error shown), then the batch goes on."""
    files = {'XT.COM': (TKX / 'UTILS/SHELLUTL/XT/XT.COM').read_bytes(), 'A.TXT': b'line one\x9bline two\x9b'}
    got = our_lines('xcomli', files, ['XT ECHO HELLO', 'ECHO AFTER', 'XT TYPE A.TXT', 'XT NOSUCH', 'ECHO END'],
                    geo=(720, 256))
    if got is None:
        return False, 'no result'
    shown = [x for x in got if not x.startswith('Time: ')]
    want = ['HELLO', 'AFTER', 'line one', 'line two', 'File NOSUCH.COM', '170 File not found', 'END']
    times = sum(x.startswith('Time: ') for x in got)
    return shown == want and times == 3, '%r' % got


def t_validate():
    """VALIDATE (lib): dates and times at $077B, valid or not (VAL.COM's
    cases; the same as SDX 4.50's)."""
    got = our_lines('validate', {'VAL.COM': ours('VAL.COM')}, ['VAL'], geo=(720, 256))
    return got == ['v 00011111100'], '%r' % got


def t_uexpand():
    """U_EXPAND: ?s to the end of the name or extension come out as *."""
    got = our_lines('uexpand', {'UEX.COM': ours('UEX.COM')},
                    ['UEX *.* AB*.C? HELLO.TXT A?C ????????.??? X*.* *.TXT'])
    want = ['[*.*]', '[AB*.C?]', '[HELLO.TXT]', '[A?C]', '[*.*]', '[X*.*]', '[*.TXT]']
    return got == want, '%r' % got


def t_con80():
    """D4: the 80-column console: RC_GR8.SYS sets _RAWCON, CON.SYS takes
    its memory (XIO 115, $07F7) and becomes E:; the batch goes on through
    it (its output to files: the screen is graphics)."""
    cmds = ['RC_GR8.SYS', 'CON.SYS /E', 'DIR >>D1:OUT.TXT', 'ECHO done >>D1:DONE.TXT']
    got = our_lines('con80', tkfiles(), cmds, geo=(720, 256), memsize='320K')
    if got is None:
        return False, 'no prompt after CON.SYS'
    tree = disk_tree(OUT / 'con80.atr')[0]
    out = (tree.get('/OUT.TXT') or (0, b''))[1] or b''
    done = (tree.get('/DONE.TXT') or (0, b''))[1] or b''
    if b'RC_GR8' not in out or b'done' not in done:
        return False, 'OUT.TXT %r, DONE.TXT %r' % (out[:60], done)
    return True, '%d bytes listed' % len(out)


def t_sc():
    """D4: Sparta Commander: SC.COM sets $COMSPEC, EOS runs SCMAIN.OVL as
    the shell (FLAG $02), which lists the directory through _RAWCON and
    misc_formdir (jmisc 4): at its last jmisc call LBUF holds one of the
    disk's files as a formatted line (name, extension, size, date)."""
    files = tkfiles()
    files['AUTOEXEC.BAT'] = emu.atascii(['RC_GR8.SYS', 'SET SC=D1:>SCMAIN.OVL,N', 'SC'])
    atr = disk('sc', files, geo=(720, 256))
    with Dumper('sc', label('k_misc'), disks=[atr], memsize='320K', timeout=90) as d:
        if d.first is None:
            return False, 'Sparta Commander did not list a directory'
        time.sleep(8)                  # the listing done: the last call's dump
        m = wait_dump(d.mem, 10)
    line = bytes(m[COMTAB + 0x3F:COMTAB + 0x3F + 38]).decode('latin1')
    names = [n.split('.') for n in files]
    if not any(line.startswith('%-8s %-3s' % (a, b)) for a, b in names) or '-25 ' not in line:
        return False, 'line %r' % line
    return True, line.strip()


def t_setboot():
    """SETBOOT: the same output, files and header bytes ($28: the boot
    file's map) as on SDX."""
    files = {'SBT.COM': ours('SBT.COM'), 'HELLO.TXT': TEXT, 'SUB/X.COM': bytes(300)}
    cmds = ['SBT HELLO.TXT', 'SBT SUB>X.COM', 'SBT SUB', 'SBT NONE.X']
    ok, msg = oracle('setboot', files, cmds, disk=True, geo=(720, 256))
    if not ok:
        return ok, msg
    hs = [open(OUT / n, 'rb').read()[16:16 + 128] for n in ('setboot-sdx.atr', 'setboot.atr')]
    diff = [i for i in range(64) if hs[0][i] != hs[1][i] and i not in (38, 39)
            and not (EOSFS and i in (13, 14, 18, 19, 32))]   # (on EOSFS: the revision
            # $45, the free count and the hint: no maps, a name index per directory)
    return not diff, msg + ('; header differs at %s' % diff if diff else '')


def t_dos2w():
    """B9: EOS writes an Atari DOS 2 disk (copy, append, rename, delete,
    lock); tools/dos2.py finds it consistent; SDX with ATARIDOS.SYS lists it
    as EOS does and reads back what EOS wrote."""
    import dos2
    big = bytes((i * 7 + i // 253) & 0xFF for i in range(5000))
    files = {'CPY.COM': ours('CPY.COM'), 'D2W.COM': ours('D2W.COM'), 'FDT.COM': ours('FDT.COM'),
             'BIG.DAT': big, 'SMALL.TXT': emu.atascii(['hello']), 'HEXDEC.COM': tk_any('HEXDEC.COM')}
    got = our_lines('dos2w', files, ['CPY HEXDEC.COM D2:HEX.COM',
                                     'CPY BIG.DAT D2:BIG.DAT', 'CPY BIG.DAT D2:KEEP.DAT',
                                     'CPY SMALL.TXT D2:SMALL.TXT', 'D2W'],
                    d2=emu.MEDIA / 'dossrc-w.atr')
    if got is None or got[-1:] != ['locked 170']:
        return False, 'EOS: %r' % (got or [])[-3:]
    written = OUT / 'dos2w-d2.atr'
    errs = dos2.Dos2(written).check()
    if errs:
        return False, 'dos2.py: ' + '; '.join(errs[:3])
    # the same disk listed by EOS and by SDX, and read back by SDX
    cmds = ['FDT $81 F.OUT D2:*.*', 'CPY D2:KEEP.DAT K.DAT', 'CPY D2:RENAMED.TXT R.TXT',
            'D2:HEX 4660']
    ok, msg = oracle('dos2w-read', files, cmds, disk=True, d2=written,
                     sdx_pre=['CAR:ATARIDOS.SYS'])
    if not ok:
        return ok, msg
    t, e, f = disk_tree(OUT / 'dos2w-read-sdx.atr')
    if t['/K.DAT'][1] != big or t['/R.TXT'][1] != emu.atascii(['hello', 'more', '']):
        return False, 'SDX read back other data'
    return True, msg


def t_dos2seek():
    """A DOS 2 disk: FSEEK keeps byte positions from the file's start (DUMP
    from an offset, near a sector's end and the file's), while CIO's NOTE
    and POINT there give and take DOS 2's sector and byte (tests/bench)."""
    import dos2
    big = bytes((i * 7 + i // 253) & 0xFF for i in range(5000))
    d2 = OUT / 'dos2seek-src.atr'
    dos2.build(str(d2), 720, 128, {'BIG.DAT': big})
    cmds = ['DUMP D2:BIG.DAT 245 16', 'DUMP D2:BIG.DAT 4992 8']   # (DUMP from CAR:)
    got = our_lines('dos2seek', {}, cmds, d2=d2)
    if got is None:
        return False, 'no result from EOS'
    data = []
    for line in got:
        f = line.split()
        if len(f) > 2 and all(len(x) == 2 for x in f[1:9]):
            try:
                data.append(bytes(int(x, 16) for x in f[1:9]))
            except ValueError:
                pass
    want = [big[245:253], big[253:261], big[4992:5000]]
    if data[:3] != want:
        return False, 'DUMP %r, want %r' % ([d.hex() for d in data], [w.hex() for w in want])
    return True, '%d lines' % len(data)


WIKI_ED = (Path.home() / 'AtariProjects/Info_Gathering/wiki/content/Companies/Atari/'
           'Atari_Personal_Financial_Management_System/attachments/'
           'Personal_Finance_Management_System_CX8114_MD-DOS_2.5.atr')


MYDOS_FILES = {'A.TXT': emu.atascii(['hello'] * 10), 'SUB/IN.TXT': emu.atascii(['inner']),
               'SUB/DEEP/LAST.DAT': bytes(range(256)) * 3, 'BIG.DAT': bytes(70000)}


def mydos_img(name, nsec=1440, seclen=256):
    """A MyDOS image (tools/dos2.py build) with subdirectories."""
    import dos2
    p = OUT / (name + '-src.atr')
    dos2.build(str(p), nsec, seclen, MYDOS_FILES)
    return p


def t_mydos_w():
    """MyDOS: EOS writes into a subdirectory and replaces a file; the disk
    checks consistent; SDX reads back what EOS wrote."""
    import dos2
    new = bytes((i * 13) & 0xFF for i in range(9000))
    files = {'CPY.COM': ours('CPY.COM'), 'FDT.COM': ours('FDT.COM'), 'NEW.DAT': new}
    got = our_lines('mydosw', files, ['CPY NEW.DAT D2:SUB>NEW.DAT', 'CPY NEW.DAT D2:A.TXT'],
                    d2=mydos_img('mydosw'))
    if got is None:
        return False, 'no result from EOS'
    errs = dos2.Dos2(OUT / 'mydosw-d2.atr').check()
    if errs:
        return False, 'dos2.py: ' + '; '.join(errs[:3])
    ok, msg = oracle('mydosw-read', files, ['FDT $81 F.OUT D2:SUB>*.*', 'CPY D2:SUB>NEW.DAT K.DAT',
                                            'CPY D2:A.TXT A.DAT'],
                     disk=True, d2=OUT / 'mydosw-d2.atr', sdx_pre=['CAR:ATARIDOS.SYS'])
    if not ok:
        return ok, msg
    t, e, f = disk_tree(OUT / 'mydosw-read-sdx.atr')
    if t['/K.DAT'][1] != new or t['/A.DAT'][1] != new:
        return False, 'SDX read back other data'
    return True, msg


def t_mydos_dirs():
    """B9: MKDIR, RMDIR and update mode ($0C) on a MyDOS disk give the
    statuses SDX gives on an SDFS disk with the same files; an update does
    not grow the file (136, as Atari DOS 2); the disk checks consistent and
    SDX with ATARIDOS.SYS lists the new directories as EOS does."""
    import dos2
    files = {'D2X.COM': ours('D2X.COM'), 'D2E.COM': ours('D2E.COM'),
             'FDT.COM': ours('FDT.COM'), 'CPY.COM': ours('CPY.COM')}
    want = sdx_lines('mydosd', files, ['D2X'], d2=MYDOS_FILES)
    got = our_lines('mydosd', files, ['D2X', 'D2E'], d2=mydos_img('mydosd'))
    if want is None or got is None:
        return False, 'no result: SDX %r, EOS %r' % (want, got)
    if got[:-1] != want or got[-1] != 'end 136':
        return False, 'SDX %r, EOS %r' % (want, got)
    sd = our_lines('mydosd-sd', files, ['D2X'], d2=MYDOS_FILES)
    if sd != want:
        return False, 'SDFS: SDX %r, EOS %r' % (want, sd)
    d = dos2.Dos2(OUT / 'mydosd-d2.atr')
    errs = d.check()
    if errs:
        return False, 'dos2.py: ' + '; '.join(errs[:3])
    tree = {p: b''.join(x for _, x, _ in d.chain(e)) for p, _, e in d.walk()}
    big = bytearray(MYDOS_FILES['BIG.DAT'])
    big[300:310] = b'0123456789'
    a = MYDOS_FILES['A.TXT']
    if tree.get('BIG.DAT') != bytes(big) or tree.get('A.TXT') != b'x' * len(a):
        return False, 'updated files differ'
    dnames = sorted(d.name(e) for _, e in d.dirs())
    if dnames != ['NEW', 'SUB'] or [d.name(e) for _, e in d.dirs(next(
            e[3] | e[4] << 8 for _, e in d.dirs() if d.name(e) == 'SUB'))] != ['DEEP']:
        return False, 'directories: %r' % dnames
    ok, msg = oracle('mydosd-read', {'FDT.COM': ours('FDT.COM')},
                     ['FDT $81 F1.OUT D2:*.*', 'FDT $81 F2.OUT D2:NEW>*.*',
                      'FDT $81 F3.OUT D2:SUB>*.*'],
                     disk=True, d2=OUT / 'mydosd-d2.atr', sdx_pre=['CAR:ATARIDOS.SYS'])
    return ok, '%s; %s' % (' '.join(got), msg)


BS = chr(0x5C)
C1_FILES = {
    'C1.BAT': emu.atascii(['ECHO [%0][%1][%2]x%1y', 'ECHO [%9][%3]', '; comment', ' ;x',
                           'ECHO ' + BS + '$PROMPT', 'ECHO $PATH$PATH', 'ECHO %%1 100%',
                           'ECHO $NOPE$x', 'ECHO /N ab', 'ECHO cd', 'ECHO  two  spaces',
                           'echo ON', 'ECHO shown', 'ECHO OFF', 'ECHO y', '-C2 x']),
    'C2.BAT': emu.atascii(['SET', 'ECHO [%0][%1]']),
    'U.BAT': emu.atascii(['ECHO in U', '-V', 'ECHO after V']),
    'V.BAT': emu.atascii(['ECHO in V %1']),
    'W.BAT': emu.atascii(['ECHO in W']),
    'FAILN.COM': ours('FAILN.COM'),
    'SUB/PRG.COM': ours('HELLO.COM'),
    'SUB/S.BAT': emu.atascii(['ECHO in S']),
}


def c1(name, cmds, ends=True):
    return lambda: oracle(name, C1_FILES, cmds, ends=ends)


C2_FILES = {'FAILN.COM': ours('FAILN.COM'), 'HELLO.COM': ours('HELLO.COM'), 'RIN.COM': ours('RIN.COM'),
            'IN.TXT': emu.atascii(['first', 'second line', 'third'])}


def c2(name, cmds):
    return lambda: oracle(name, C2_FILES, cmds, disk=True)


def cfg(lines, files=None):
    """CONFIG.SYS for SDX (with its drivers) and EOSSYS.SYS for EOS."""
    sdx = emu.atascii(['DEVICE SPARTA', 'DEVICE SIO'] + lines)
    return sdx


C3_FILES = {'CONFIG.SYS': cfg(['ECHO hello cfg', '; comment', 'FOO bar', 'DEVICE NOPE',
                               'SET XX=yy', 'MERGE MORE']),
            'MORE.CFG': emu.atascii(['ECHO merged', 'SET M=1', 'SET BATCH=B.BAT']),
            'B.BAT': emu.atascii(['CLS', 'SET >>S.TXT', 'ECHO in B']),
            'AUTOEXEC.BAT': emu.atascii(['ECHO not run'])}


def t_cfg():
    """C3: CONFIG.SYS read as SDX reads it (ECHO, SET, comments, unknown
    words and missing drivers skipped, MERGE, SET BATCH replaces the
    startup batch file); compared through the environment SET writes."""
    sdx = dict(C3_FILES, **{'B.BAT': emu.atascii(['CLS', 'SET >>S.TXT', 'ECHO in B', 'SDXPROBE'])})
    eos = dict(C3_FILES, **{'B.BAT': emu.atascii(['CLS', 'SET >>S.TXT', 'ECHO in B', ' ' * 8])})
    want = sdx_lines('cfg', sdx, [], last=True)
    got = our_lines('cfg', eos, [])
    if want is None or got is None:
        return False, 'no result: SDX %r, EOS %r' % (want, got)
    a = disk_tree(OUT / 'cfg-sdx.atr')[0].get('/S.TXT', (0, None))[1]
    b = disk_tree(OUT / 'cfg.atr')[0].get('/S.TXT', (0, None))[1]
    if want != got or a != b:
        return False, 'SDX %r %r, EOS %r %r' % (want, a, got, b)
    return True, (b or b'').replace(b'\x9b', b'|').decode()


def t_use(use, memsize):
    """C3: USE in CONFIG.SYS: COMTAB's memory flags, T_ and what MALLOC $02
    grants (index; the address is EOS's own) as on SDX."""
    files = {'CONFIG.SYS': emu.atascii(['USE ' + use, 'DEVICE SPARTA', 'DEVICE SIO']),
             'CT.COM': ours('CT.COM')} if use else {'CT.COM': ours('CT.COM')}
    name = 'use-%s-%s' % ((use or 'default').lower(), memsize)
    want = sdx_lines(name, files, ['CT >>C.TXT'], memsize=memsize, last=True)
    got = our_lines(name, files, ['CT >>C.TXT'], memsize=memsize)
    if want is None or got is None:
        return False, 'no result'
    a = disk_tree(OUT / (name + '-sdx.atr'))[0].get('/C.TXT', (0, b''))[1]
    b = disk_tree(OUT / (name + '.atr'))[0].get('/C.TXT', (0, b''))[1]
    a, b = a.split(b'\x9b'), b.split(b'\x9b')
    if a[:2] != b[:2] or a[2][:10] != b[2][:10]:
        return False, 'SDX %r, EOS %r' % (a, b)
    return True, b'|'.join(b).decode()


C4_FILES = {'A.TXT': emu.atascii(['alpha']), 'B.TXT': emu.atascii(['beta']),
            'C.DAT': emu.atascii(['gamma']), 'SUB/IN.TXT': emu.atascii(['inner']),
            'HELLO.COM': ours('HELLO.COM'), 'FAILN.COM': ours('FAILN.COM')}
C4_TESTS = {
    'c4-dirs': ['CD', 'MD NEW', 'CD NEW', 'CD', 'CWD ..', 'CD', 'MKDIR NEW', 'CREDIR X2', 'RD X2',
                'CD SUB', 'CD', 'CD >', 'RD SUB', 'RMDIR NOPE', 'DELDIR NEW', 'RENDIR SUB DIR2',
                'CD DIR2', 'CD', 'CD NOPE', 'CD D1:>'],
    'c4-files': ['REN A.TXT A2.TXT', 'RENAME *.DAT *.DOC', 'REN B.TXT A2.TXT', 'REN B.TXT',
                 'DEL A2.TXT', 'ERASE NOPE.TXT', 'DELETE C.DOC', 'TYPE B.TXT', 'TYPE NONE'],
    'c4-atr': ['ATR +P A.TXT', 'DEL A.TXT', 'ATTRIB -P +H A.TXT', 'TYPE A.TXT', 'TYPE +H A.TXT',
               'ATR +A *.TXT', 'ATR +P', 'ATR X A.TXT'],
    'c4-misc': ['VERIFY', 'VERIFY ON', 'VERIFY', 'VERIFY OFF', 'VERIFY X', 'REPORT 5', 'REPORT 0',
                'REPORT 170', 'SETERRNO 138', 'REPORT', 'FAILN 150', 'REPORT', 'SWAP 2 O', 'FI'],
    'c4-swap': ['SWAP'],
    'c4-prompt': ['PROMPT', 'PROMPT $L$P_X', 'PROMPT', 'SET PROMPT', 'PROMPT', 'SET PROMPT=D$N'],
    'c4-load': ['LOAD HELLO', 'LOAD', 'BOOT HELLO.COM', 'BOOT NOPE.COM', 'PAUSE 1', 'CLR', 'SET'],
}


def keyed(name, files, commands, keys):
    """Commands from AUTOEXEC.BAT, then lines typed (each answering a
    question or at the prompt); the screens at the end compared."""
    f = dict(files)
    f['AUTOEXEC.BAT'] = emu.atascii(['CLS'] + list(commands))
    f['SDXPROBE.COM'] = sdxprobe.PROBE.read_bytes()
    atr = disk(name + '-sdx', f)
    with Dumper(name + '-sdx', sdxprobe.DONE, cart=emu.SDX_CART, disks=[atr], timeout=10,
                run_on=False) as d:
        d.first
        wid = emu.window_id()
        for k in keys:
            emu.type_line(wid, k)
            time.sleep(2)
        d.timeout = 30
        want = d.step(lambda w: emu.type_line(w, 'SDXPROBE'))
    atr = disk(name, f)
    with Dumper(name, label('k_prompt'), disks=[atr], timeout=30) as d:
        got = d.first
        for k in keys:
            got = d.step(lambda w, k=k: emu.type_line(w, k))
    if want is None or got is None:
        return False, 'no result from %s' % ('SDX' if want is None else 'EOS')
    # SDX: SDXPROBE typed at its prompt (one more line, the screen scrolled
    # once more); EOS: stopped at its prompt. The common tail counts.
    want = [x for x in screen(want) if x and x != 'D1:' and not x.endswith('SDXPROBE')]
    got = [x for x in screen(got) if x and x != '[D1:/]']
    while got and got[-1] in ('[>]', '[D1:/]'):  # EOS waits at its prompt
        got = got[:-1]
    n = min(len(want), len(got))
    want, got = want[len(want) - n:], got[len(got) - n:]
    if want != got:
        (OUT / (name + '.diff')).write_text('SDX:\n%s\nEOS:\n%s\n' % ('\n'.join(want), '\n'.join(got)))
        return False, 'output differs, see %s.diff' % name
    return True, '%d lines' % len(want)


KEY_FILES = {'L.TXT': emu.atascii(['line %d' % i for i in range(1, 31)]),
             'A.TXT': emu.atascii(['alpha']), 'SUB/IN.TXT': emu.atascii(['inner'])}


DIR_FILES = {'A.TXT': emu.atascii(['alpha']), 'B.DAT': bytes(3000), 'SUB/IN.TXT': emu.atascii(['inner']),
             'SUB/X.COM': bytes(300)}
DIR_TESTS = {
    'car-dir1': ['DIR', 'DIRS'],
    'car-dir2': ['DIR /A', 'DIR /C', 'DIR *.TXT'],
    'car-dir3': ['DIRS /A', 'DIRS /C', 'DIR SUB>', 'DIR +S'],
    # (DIR >>file while that file is open: SDX lists the free sectors and the
    # entries as on the disk before the file is closed; EOS not yet, PROGRESS.md)
    'car-dir5': ['DIR /A SUB>', 'DIR NOPE>', 'DIR X15:'],
}


MSGSTORE = Path(__file__).resolve().parents[1] / 'tests' / 'eos' / 'B.COM'


WIKI_MYDOS = Path.home() / 'AtariProjects/Info_Gathering/wiki/content/Languages/C/C_Examples/Greed/attachments/agreed2.atr'


def t_mydos_wiki():
    """A real MyDOS disk (code 3, 16-bit links): listing and a file as SDX
    reads them. AUTORUN.SYS is compared with tools/dos2.py instead: SDX's
    ATARIDOS.SYS stops reading it after 100 bytes, EOS reads all of it."""
    import dos2
    files = {'FDT.COM': ours('FDT.COM'), 'CPY.COM': ours('CPY.COM')}
    ok, msg = oracle('mydos-wiki', files, ['FDT $81 F1.OUT D2:*.*', 'CPY D2:LEVEL03.AGL L.AGL'],
                     disk=True, d2=WIKI_MYDOS, sdx_pre=['CAR:ATARIDOS.SYS'])
    if not ok:
        return ok, msg
    got = our_lines('mydos-wiki-a', files, ['CPY D2:AUTORUN.SYS A.SYS'], d2=WIKI_MYDOS)
    d = dos2.Dos2(WIKI_MYDOS)
    want = [b''.join(x for _, x, _ in d.chain(e)) for p, i, e in d.walk() if p == 'AUTORUN.SYS'][0]
    have = disk_tree(OUT / 'mydos-wiki-a.atr')[0].get('/A.SYS', (0, None))[1]
    return have == want, msg + ('' if have == want else '; AUTORUN.SYS differs from dos2.py')


def dirs_files():
    return dict(DIRS_FILES, **{'DIRTEST.COM': ours('DIRTEST.COM')})


GEO_FILES = dict(TYPE_FILES, **{'FSW.COM': ours('FSW.COM')})
GEO_CMDS = ['TYPE HELLO.TXT', 'TYPE SUB>INNER.TXT', 'FSW']


# exBASIC programs (tests/exbasic/*.bas), compiled by the exBASIC compiler
# (EXBASIC: its path) into build/xb; each runs from the batch file on SDX
# and on EOS, the screen and the disk afterwards must be the same
EXBASIC = Path(os.environ.get(
    'EXBASIC', Path.home() / 'ExBASIC/exbasic/build/compiler/exbasic'))
XB_SRC = Path(__file__).resolve().parents[1] / 'tests' / 'exbasic'


# compiler options for some programs
XB_OPTS = {'XLOW': ['-S:0x1000']}    # below MEMLO: the load-time check


def xb(name):
    """The compiled program NAME.COM (compiled again when the source is newer)."""
    out = emu.BUILD / 'xb'
    out.mkdir(parents=True, exist_ok=True)
    src, com = XB_SRC / (name + '.bas'), out / (name + '.COM')
    if not EXBASIC.exists():
        raise RuntimeError('no exBASIC compiler at %s: run make in the exBASIC '
                           'tree, or set EXBASIC' % EXBASIC)
    newest = max(src.stat().st_mtime, EXBASIC.stat().st_mtime,
                 (EXBASIC.parent / 'exbasic.lib').stat().st_mtime)
    if not com.exists() or com.stat().st_mtime < newest:
        r = subprocess.run([str(EXBASIC), *XB_OPTS.get(name, []), str(src), '-o', str(com)], cwd=out,
                           capture_output=True, text=True)
        if r.returncode:
            raise RuntimeError('exBASIC: %s' % (r.stdout + r.stderr))
    return com.read_bytes()


def t_xb(test, prog, progs=(), cmds=None, **kw):
    files = {p + '.COM': xb(p) for p in [prog, *progs]}
    return oracle(test, files, cmds or [prog, 'ECHO BACK IN DOS'], disk=True, **kw)


XB_TESTS = {
    'xb-hello': ('XHELLO',),
    'xb-file': ('XFILE',),
    'xb-bytes': ('XBYTES',),
    'xb-note': ('XNOTE',),
    'xb-xio': ('XXIO',),
    'xb-dir': ('XDIR',),
    'xb-sdx': ('XSDX',),
    'xb-chain': ('XCHAIN', ['XCHAIN2']),
    'xb-gfx': ('XGFX',),
    'xb-err': ('XERR',),
    'xb-lock': ('XLOCK',),
    'xb-upd': ('XUPD',),
    'xb-aux': ('XAUX',),
    'xb-mem': ('XMEM',),
    'xb-low': ('XLOW', ['XHELLO'], ['XLOW', 'ECHO BACK IN DOS', 'XHELLO']),
    'xb-runlow': ('XRUNLOW', ['XLOW']),
    'xb-mem-128K': ('XMEM', (), None, {'memsize': '128K'}),
    'xb-twice': ('XHELLO', (), ['XHELLO', 'XHELLO', 'ECHO BACK IN DOS']),
    'xb-128K': ('XFILE', (), None, {'memsize': '128K'}),
    'xb-dd': ('XNOTE', (), None, {'geo': (720, 256)}),
}
XB_TESTS = {k: (lambda k=k, a=a: t_xb(k, *a[:3], **(a[3] if len(a) > 3 else {})))
            for k, a in XB_TESTS.items()}


TESTS = {
    'boot-64K': lambda: t_boot('64K'),
    'boot-ideplus': lambda: t_boot_ideplus(),
    'boot-ideplus-reset': lambda: t_boot_ideplus(reset=True),
    # (the pages scroll: their last line, unique to each, stays on screen)
    'man-u1mb': lambda: t_hardware_man('U1MB', 'See also: APT, IDEPLUS'),
    'man-ideplus': lambda: t_hardware_man('IDEPLUS', 'See also: APT, FORMAT'),
    'man-apt': lambda: t_hardware_man('APT', 'See also: IDEPLUS, U1MB, FORMAT'),
    'boot-128K': lambda: t_boot('128K'),
    'boot-320K': lambda: t_boot('320K'),       # RAMBO 320K (Altirra's 320K)
    'reset': lambda: t_boot('64K', reset=True),
    'type': lambda: native_output(
        'type', TYPE_FILES, TYPE_CMDS,
        ['Hello from D1', 'second line', 'third', 'inner file',
         'two levels down', '170 File not found', '138 Device does not respond']),
    'printf': lambda: oracle('printf', {'PRINTF.COM': ours('PRINTF.COM')}, ['PRINTF']),
    'milestone': lambda: oracle('milestone', MILESTONE_FILES, MILESTONE_CMDS),
    'ciod': lambda: oracle('ciod', {'CIOD.COM': ours('CIOD.COM'), 'HELLO.TXT': TEXT}, ['CIOD']),
    'ciob2': lambda: oracle('ciob2', {'CIOB2.COM': ours('CIOB2.COM'), 'B.COM': MSGSTORE.read_bytes()}, ['CIOB2'], geo=(720, 256)),
    'ciob': lambda: oracle('ciob', {'CIOB.COM': ours('CIOB.COM'), 'ABC.TXT': b'ABCDEFGHIJKLMNOPQRST'}, ['CIOB']),
    'fsw': t_fsw_native,
    'symlink': lambda: oracle('symlink', SYM_FILES, SYM_CMDS, disk=True),
    'curdrv': lambda: oracle('curdrv', {'HELLO.TXT': TEXT}, CUR_CMDS, d2=CUR_D2),
    'conio': lambda: multi('conio', {'CONIO.COM': ours('CONIO.COM'), 'LINES.TXT': emu.atascii(
        ['short', 'abcdefghij', 'third'])}, [['CONIO M'], ['CONIO G']]),
    'env': lambda: multi('env', {'ENV.COM': ours('ENV.COM')}, [['ENV 1'], ['ENV 2']]),
    'dirs': lambda: multi('dirs', dirs_files(), DIRS_CMDS, geo=(720, 128)),
    'dirs-dd': lambda: multi('dirs-dd', dirs_files(), DIRS_CMDS, geo=(720, 256)),
    'dirs-512': lambda: multi('dirs-512', dirs_files(), DIRS_CMDS, geo=(1440, 512)),
    'parse': lambda: multi('parse', {'PARSE.COM': ours('PARSE.COM')}, [[c] for c in PARSE_CMDS]),
    'failn': lambda: oracle('failn', {'FAILN.COM': ours('FAILN.COM')}, [
        'FAILN %d' % n for n in (0, 1, 100, 127, 128, 129, 200, 254, 255)]),
    'memt': lambda: oracle('memt', {'MEMT.COM': ours('MEMT.COM')}, ['MEMT']),
    'mem2-128K': lambda: multi('mem2-128K', {'MEM2.COM': ours('MEM2.COM')},
                               [['MEM2 6000'], ['MEM2 16384', 'MEM2 16385']], memsize='128K'),
    'mem2': lambda: oracle('mem2', {'MEM2.COM': ours('MEM2.COM')}, ['MEM2 100']),
    'memt-128K': lambda: oracle('memt-128K', {'MEMT.COM': ours('MEMT.COM')}, ['MEMT'],
                                memsize='128K'),
    'nest': lambda: oracle('nest', {'NEST.COM': ours('NEST.COM'), 'CHILD.COM': ours('CHILD.COM')},
                           ['NEST']),
    'rent': lambda: oracle('rent', {'RENT.COM': ours('RENT.COM')}, ['RENT S A $C0 I N BAR'],
                           disk=True),
    'gflg': lambda: oracle('gflg', {'GFLG.COM': ours('GFLG.COM')}, ['GFLG BAR X 7 FOO.COM B $X',
                                                                   'GFLG S A $C0 I N SX 300']),
    'crunch': lambda: multi('crunch', {'CRUNCH.COM': ours('CRUNCH.COM')}, [
        ['CRUNCH FOO B:X D2:Y 3:Z CAR:W J:V', 'CRUNCH >D>F /AB', 'CRUNCH A,B  C'],
        ['CRUNCH D:', 'CRUNCH E:', 'CRUNCH DSK2:Q PRN:', 'CRUNCH CAR:', 'CRUNCH PRN:X CON:',
         'CRUNCH NUL:Y CLK:']],
        # by design: D: is D1:, E: the screen (E1:) on EOS (SDX: drive
        # letters, D4: and D5:)
        adjust=lambda ls: [{'[D4:] ': '[D1:] ', '[D5:] ': '[E1:] '}.get(x[:6], x[:6]) + x[6:]
                           if i < 2 else x for i, x in enumerate(ls)]),
    'divio': lambda: oracle('divio', {'DIVT.COM': ours('DIVT.COM'), 'IN.TXT': emu.atascii(
        ['one', 'two'])}, ['DIVT'], disk=True),
    'fdir': lambda: multi('fdir', fdir_files(), [['FDT %s F.OUT D1:*.*' % m] for m in FDIR_MODES],
                          disk=True, geo=(1440, 512)),
    'fdir-sd': lambda: multi('fdir-sd', fdir_files(), [['FDT 0 F.OUT D1:*.*'], ['FDT $80 F.OUT D1:*.*'],
                                                        ['FDT $80 F.OUT DIRX.EXT>*.*']],
                             disk=True, geo=(1440, 128)),
    'dir-native': t_dir_native,
    'dir6': t_dir6,
    'siodrv': t_siodrv,
    'uexpand': t_uexpand,
    'envsys': t_envsys,
    'xep80': t_xep80,
    'xcomli': t_xcomli,
    'pipes': t_pipes,
    'pipe-cleanup': t_pipe_cleanup,
    'ddrive': t_ddrive,
    # U_GETPAR: blanks, one comma after a parameter, a comma alone empty
    'getpar': lambda: multi('getpar', {'GETP.COM': ours('GETP.COM')},
                            [['GETP A,,B'], ['GETP A, ,B C,D , E'], ['GETP ,X Y']]),
    'rddump-320K': t_rddump,
    # batch lines longer than the 62 characters SDX keeps: the rest dropped
    'longline': lambda: oracle('longline', {}, ['ECHO ' + '0123456789' * 7, 'ECHO next',
                                                'ECHO ' + '0123456789' * 5 + '01234567',
                                                'ECHO ' + '0123456789' * 5 + '012345678',
                                                'ECHO end']),
    'validate': t_validate,
    'rs232-850': t_rs232_850,
    'hssio': t_hssio,
    'xfsio': t_xfsio,
    'indussio': t_indussio,
    'builddir': t_builddir,
    'history-default': t_history_default,
    'mem-bytes': t_mem_bytes,
    'doskey': t_doskey,
    'runext': t_runext,
    'comexe': t_comexe,
    'eosdirty': t_eosdirty,
    'zsys': t_zsys,
    'blkio': t_blkio,
    'secmx': t_secmx,
    'con80': t_con80,
    'sc': t_sc,
    'uparm': lambda: oracle('uparm', {'UPARM.COM': ours('UPARM.COM')}, ['UPARM FOO B:X,Y  /Z']),
    'argv': lambda: native_output('argv', {'argt.com': ours('ARGT.COM')},
                                  ["argt plain 'two words' \"\" back\\ slash"],
                                  ['5', '[argt]', '[plain]', '[two words]', '[]',
                                   '[back slash]']),
    'argv-long': lambda: native_output(
        'argv-long', {'argt.com': ours('ARGT.COM')}, ['argt ' + 'x' * 100],
        ['2', '[argt]', '[' + 'x' * 37, 'x' * 38, 'x' * 25 + ']']),
    'argv-line-max': lambda: native_output(
        'argv-line-max', {'argt.com': ours('ARGT.COM')}, ['argt ' + 'x' * 122],
        ['2', '[argt]', '[' + 'x' * 37, 'x' * 38, 'x' * 38,
         'x' * 9 + ']']),
    'xcomli-max': lambda: native_output(
        'xcomli-max', {'xcl.com': ours('XCL.COM')}, ['xcl'],
        ['x' * 38, 'x' * 38, 'x' * 38, 'x' * 8]),
    'pipe-long': lambda: native_output(
        'pipe-long', {'argt.com': ours('ARGT.COM')},
        ['echo ignored | argt ' + 'x' * 100],
        ['2', '[argt]', '[' + 'x' * 37, 'x' * 38, 'x' * 25 + ']']),
    'conditionals': lambda: native_output(
        'conditionals', {},
        ['echo a && echo b', 'nosuch && echo no',
         'nosuch || echo recovered', 'echo ok || echo no',
         'echo pipe | cat && echo after', 'nosuch | cat || echo failed'],
        ['a', 'b', 'File nosuch.com', '170 File not found',
         'File nosuch.com', '170 File not found', 'recovered', 'ok',
         'pipe', '170 File not found', 'failed']),
    'shell-vars': lambda: native_output(
        'shell-vars', {'b.bat': emu.atascii(['echo $1 %1'])},
        ['set X=hello', 'echo "$X" \'$X\' ${X}', 'nosuch',
         'echo status=$?', '-b foo'],
        ['HELLO $X HELLO', 'File nosuch.com', '170 File not found',
         'status=170', 'FOO FOO']),
    'legacy-long': lambda: native_output(
        'legacy-long', {'lb.com': ours('LB.COM')}, ['lb ' + 'x' * 70],
        ['182 Path too long']),
    'redir-posix': lambda: native_output(
        'redir-posix', {'rin.com': ours('RIN.COM')},
        ['echo one >out.txt', 'echo two >>out.txt', 'type out.txt', 'rin <out.txt'],
        ['one', 'two', '[one]', '[two]', 'end']),
    'spaced-names': lambda: native_output(
        'spaced-names', {},
        ['echo spaced >"my file.txt"', 'cat "my file.txt"',
         'echo again >>"my file.txt"', 'cp "my file.txt" "other file.txt"',
         'type "other file.txt"', 'mv "other file.txt" "moved file.txt"',
         'type "moved file.txt"', 'del "my file.txt"', 'del "moved file.txt"'],
        ['spaced', 'spaced', 'again', 'spaced', 'again']),
    'builtin-argv': lambda: native_output(
        'builtin-argv', {},
        ['mkdir "my dir"', 'cd "my dir"', 'cd', 'cd /',
         'rmdir "my dir"', 'echo x >"old name"',
         'rename "old name" "new name"', 'cat "new name"',
         'rm "new name"', 'echo end'],
        ['/my dir', 'x', 'end']),
    'sparse-gap': lambda: native_output(
        'sparse-gap', {'spg.com': ours('SPG.COM')}, ['spg'],
        ['00 42 00 41']),
    'core-unix': lambda: native_output(
        'core-unix', {}, ['which ls', 'which cp', 'basename D1:/foo/bar.txt',
                          'dirname D1:/foo/bar.txt', 'which vim', 'which tar'],
        ['CAR:ls.com', 'cp: built-in', 'bar.txt', 'D1:/foo',
         'CAR:vim.com', 'CAR:tar.com']),
    'tar-native': t_tar_native,
    'toolkit-disk': t_toolkit_disk,
    'vim-interactive': t_vim_interactive,
    'fsinfo-native': t_fsinfo_native,
    'fsinfo-foreign': t_fsinfo_foreign,
    'fscheck-foreign': t_fscheck_foreign,
    'fsimport-foreign': t_fsimport_foreign,
    'fsexport-foreign': t_fsexport_foreign,
    'fscreate-foreign': t_fscreate_foreign,
    'pth': lambda: native_output('pth', {'PTH.com': ours('PTH.COM'), 'SUB/PTH.com': ours('PTH.COM'),
                                  'SUB/DEEP.X/PTH.COM': ours('PTH.COM')},
                          ['PTH', 'SUB/PTH', '/SUB/DEEP.X/PTH.COM'],
                          ['p [/] 00', 'p [/SUB/] 00', 'p [/SUB/DEEP.X/] 00']),
    # Toolkit drivers that load into program extended memory (130XE banks)
    'con64-128K': lambda: oracle('con64-128K', {'CON64.SYS': tk_any('CON64.SYS')},
                                 ['CON64.SYS'], memsize='128K'),
    'rcgr8-128K': lambda: oracle('rcgr8-128K', {'RC_GR8.SYS': tk_any('RC_GR8.SYS')},
                                 ['RC_GR8.SYS'], memsize='128K'),
    'setboot': t_setboot,
    'dirw': lambda: oracle('dirw', {'DIRW.COM': ours('DIRW.COM'), 'SUB/AAA.TXT': TEXT,
                                    'SUB/BBB.TXT': TEXT}, ['DIRW'], disk=True, geo=(720, 128)),
    'bat-par': c1('bat-par', ['-C1 one two']),
    'bat-env': c1('bat-env', ['SET X=1', 'SET Y=2', 'SET X=3', 'SET Z=4', 'SET Y', 'SET W=a b', 'SET',
                              'PATH', 'PATH a b', 'PATH'], ends=False),
    'bat-err1': c1('bat-err1', ['FAILN 130', 'ECHO a1', 'TYPE NONE', 'ECHO a2', 'TYPE D15:X',
                                'ECHO a3']),
    'bat-err2': c1('bat-err2', ['NOSUCH', 'ECHO b1', 'FAILN 170', 'ECHO b2', 'TYPE', 'ECHO b3',
                                'D15:', 'ECHO b4']),
    'bat-err3': c1('bat-err3', ['ECHO', 'ECHO c1']),
    'bat-err4': c1('bat-err4', ['ERROR ON', 'FAILN 156', 'ECHO d1']),
    'bat-err5': c1('bat-err5', ['ERROR XX', 'ECHO e1']),
    'bat-err6': c1('bat-err6', ['XYZ:', 'ECHO f1']),
    'bat-chain': c1('bat-chain', ['-U', 'ECHO not reached']),
    'bat-var': c1('bat-var', ['SET BATCH=W.BAT', 'ECHO set']),
    'bat-path': c1('bat-path', ['PATH', 'PRG', 'SET PATH=CAR:;D1:>SUB>', 'PATH', 'PRG',
                                'ECHO $PATH', '-S']),
    'redir1': c2('redir1', ['ECHO hi >>X.TXT', 'ECHO ho >>X.TXT', 'TYPE X.TXT', 'HELLO a b >>Y.TXT',
                            'TYPE Y.TXT', 'ECHO >>Z.TXT mid text', 'TYPE Z.TXT', 'ECHO b>>V.TXT']),
    'redir2': c2('redir2', ['ECHO a >> W.TXT', 'RIN <<IN.TXT', 'RIN << IN.TXT', 'RIN <<NONE.TXT',
                            'TYPE IN.TXT >>T.TXT', 'TYPE T.TXT']),
    'cmdline': lambda: oracle('cmdline', {'LB.COM': ours('LB.COM')}, [
        'LB a Bc,d  "e f"', 'lb x', 'LB $PATH x$PATH', 'ECHO aB', 'LB a >>L.TXT b', 'TYPE L.TXT'],
        disk=True),
    'cfg': t_cfg,
    # the default RAM disk (O:, USE BANKED above 128K), formatted as EOSFS v2
    'ramdisk-320K': lambda: native_output(
        'ramdisk-320K', {'A.TXT': emu.atascii(['hello ramdisk'])},
        ['cp A.TXT O:/A.TXT', 'cat O:/A.TXT', 'mkdir O:/sub',
         'cp A.TXT O:/sub/copy.txt', 'cat O:/sub/copy.txt'],
        ['hello ramdisk', 'hello ramdisk'], memsize='320K'),
    **{n: (lambda n=n: oracle(n, DIR_FILES, DIR_TESTS[n], geo=(720, 256), ends=True))
       for n in DIR_TESTS},
    'key-pause': lambda: keyed('key-pause', KEY_FILES, ['PAUSE', 'ECHO after'], ['']),
    'key-typep': lambda: keyed('key-typep', KEY_FILES, ['TYPE L.TXT /P', 'ECHO aftertype'], ['']),
    'key-more': lambda: keyed('key-more', KEY_FILES, ['MORE L.TXT', 'ECHO aftermore'], ['']),
    'key-del': lambda: keyed('key-del', KEY_FILES, ['DEL *.*', 'ECHO afterdel', 'TYPE A.TXT'], ['N']),
    # (xdotool types no shifted keys into Altirra: $ and _ come from P2.BAT)
    'key-prompt': lambda: keyed('key-prompt', dict(KEY_FILES, **{
        'SUB/P2.BAT': emu.atascii(['PROMPT $N$P$R_'])}), ['PROMPT $L$P_X', 'CD SUB'], [
        'CD', '-P2', 'CD', 'CD ..', 'SET PROMPT', 'CD']),
    **{n: (lambda n=n: oracle(n, C4_FILES, C4_TESTS[n], disk=True, ends=True)) for n in C4_TESTS},
    'use-banked-128K': lambda: t_use('BANKED', '128K'),
    'use-osram-128K': lambda: t_use('OSRAM', '128K'),
    'use-banked-64K': lambda: t_use('BANKED', '64K'),
    'use-default-128K': lambda: t_use('', '128K'),
    'redir3': c2('redir3', ['FAILN 170 >>F.TXT', 'TYPE F.TXT', 'ECHO x >>Q.TXT >>P.TXT', 'TYPE Q.TXT',
                            'TYPE P.TXT', 'ECHO h']),
    'prompt': t_prompt,
    'full': lambda: oracle('full', full_files(False), ['FULL'], disk=True),
    'full-map': lambda: oracle('full-map', full_files(True), ['FULL'], disk=True),
    'fsw-dd': lambda: t_fsw_native((720, 256), '-dd'),
    'fsw-512': lambda: t_fsw_native((1440, 512), '-512'),
    'fsw-hd': lambda: t_fsw_native((8192, 256), '-hd'),
}
TESTS.update(XB_TESTS)


# tests whose results depend on the disk format (EOS_EOSFS mode)
EOSFS_SKIP = {'fdir-sd': 'FDT lists the free sectors (no map sectors on EOSFS)',
              'fdir': 'FDT lists the free sectors (EOSFS: no maps, a name index)',
              'full': 'more fits than on SDFS (no map sectors)',
              'full-map': 'more fits than on SDFS (no map sectors)'}

# Complete native conversion matrix.  The remaining TESTS are retained as an
# SDX/SDFS ABI regression archive; many intentionally inspect 23-byte 8.3
# records or compare SDFS allocation byte-for-byte and are not EOSFS tests.
EOSFS_ACTIVE = [
    'boot-64K', 'boot-ideplus', 'boot-ideplus-reset',
    'man-u1mb', 'man-ideplus', 'man-apt', 'boot-128K', 'boot-320K', 'reset',
    'type', 'printf', 'milestone', 'ciod', 'ciob2', 'ciob',
    'fsw', 'fsw-dd', 'fsw-512', 'fsw-hd', 'pipe-cleanup', 'builddir',
    'argv', 'argv-long', 'argv-line-max', 'xcomli-max', 'pipe-long',
    'conditionals', 'shell-vars', 'legacy-long', 'redir-posix',
    'spaced-names', 'dir-native', 'builtin-argv', 'sparse-gap', 'core-unix', 'tar-native',
    'prompt', 'history-default', 'mem-bytes',
    'toolkit-disk',
    'vim-interactive',
    'fsinfo-native', 'fsinfo-foreign', 'fscheck-foreign', 'fsimport-foreign',
    'fsexport-foreign', 'fscreate-foreign', 'pth', 'ramdisk-320K',
    'use-banked-128K',
]


def main():
    emu.ensure_display()
    OUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or (EOSFS_ACTIVE if EOSFS else list(TESTS))
    failed = 0
    for n in names:
        if EOSFS and n in EOSFS_SKIP:
            print('%-12s SKIP         EOSFS: %s' % (n, EOSFS_SKIP[n]), flush=True)
            continue
        t0 = time.monotonic()
        ok, msg = TESTS[n]()
        print('%-12s %-5s %4.0fs  %s' % (n, 'PASS' if ok else 'FAIL', time.monotonic() - t0, msg),
              flush=True)
        failed += not ok
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
