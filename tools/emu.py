"""Headless Altirra session runner shared by the test suites.

A session boots Altirra under wine (inside xvfb, see ensure_display) with an
optional cartridge and up to four disks, waits until a marker file appears on
one of the disks, takes a screenshot and stops the emulator. Disks are
modified in place (/bootrw).
"""
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

import atrtool

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
# local test media, not in git (.gitignore): disk images, the SDX Toolkit,
# the IDE2.0PLUS vendor files (README.md lists them)
MEDIA = ROOT / 'media'
# EMU_WORKER=N (tools/prun.py): a Wine prefix of its own (a copy of
# build/wine), so that sessions can run side by side: each one ends with
# wineserver -k, which stops every emulator in its prefix
WORKER = os.environ.get('EMU_WORKER', '')
WINEPREFIX = BUILD / ('wine-' + WORKER if WORKER else 'wine')
ALTIRRA = Path(os.environ.get(
    'ALTIRRA_EXE',
    Path.home() / 'AtariMutineer/Privateer/tools/altirra/4.40/Altirra64.exe'))
SDX_CART = Path(os.environ.get(
    'SDX_CART', Path.home() / 'AtariMutineer/Privateer/third_party/SDX450_maxflash8.car'))
EOL = b'\x9b'


def ensure_display():
    """Re-exec the calling script under xvfb-run when there is no X display."""
    if not os.environ.get('DISPLAY'):
        os.execvp('xvfb-run', ['xvfb-run', '-a', '-s', '-screen 0 1024x768x24',
                               sys.executable, *sys.argv])
    for tool in ['wine', 'xdotool', 'import']:
        if not shutil.which(tool):
            sys.exit('missing tool: ' + tool)
    if not ALTIRRA.exists():
        sys.exit('Altirra not found, set ALTIRRA_EXE (%s)' % ALTIRRA)
    if WORKER and not WINEPREFIX.exists():
        tmp = BUILD / ('wine-%s.tmp' % WORKER)
        shutil.rmtree(tmp, ignore_errors=True)
        subprocess.run(['cp', '-a', str(BUILD / 'wine'), str(tmp)], check=True)
        tmp.rename(WINEPREFIX)
    WINEPREFIX.mkdir(parents=True, exist_ok=True)


def win(path):
    return 'Z:' + str(Path(path).resolve()).replace('/', '\\')


def atascii(lines):
    return EOL.join(s.encode('ascii') for s in lines) + EOL


def text(data):
    return data.replace(EOL, b'\n').decode('latin-1')


def extract(atr, name, dest):
    """Extract one file (path relative to MAIN, '/' separated) via atr."""
    out = Path(dest) / 'x'
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    f = out / name.lstrip('/\\')
    # atrtool handles the legacy SDFS images used by the SDX oracle. Native
    # release and test disks are EOSFS v2 and have exact-case names.
    import sdfs
    try:
        volume = sdfs.Volume(str(atr))
        if volume.eosfs:
            entry = dict(volume.check()).get('/' + name.strip('/\\'))
            if volume.errors or not entry or 'data' not in entry:
                return None
            return entry['data']
    except (OSError, ValueError, sdfs.SdfsError):
        # A marker poll can catch the emulator between sector writes. The
        # caller retries, so treat that transient image as not ready yet.
        return None
    if not atrtool.get(atr, name, f):
        return None
    return f.read_bytes()


def blank_atr(path, sectors, seclen):
    """Unformatted ATR; 128/256 byte images have three 128 byte boot sectors."""
    size = sectors * seclen - (3 * (seclen - 128) if seclen == 256 else 0)
    hdr = bytes([0x96, 0x02, (size >> 4) & 0xFF, (size >> 12) & 0xFF,
                 seclen & 0xFF, seclen >> 8, size >> 20]) + bytes(9)
    Path(path).write_bytes(hdr + bytes(size))


def mkatr(path, tree, files, size, boot=None):
    """Build an SDFS image with mkatrgo from paths relative to tree."""
    atrtool.create(path, tree, files, size=size, boot=boot)


def ini_str(s):
    return '"%s"' % s.replace('\\', '\\\\').replace('"', '\\"')


def write_ini(path, turbo=False, devices=None, ultimate1mb=False, firmware=None, u1mb_flash=None):
    """Write Altirra profile settings; devices is Altirra's device list (JSON).

    firmware maps Altirra firmware type names ('kmkjzide2', 'u1mb') to raw
    image paths: each becomes a custom firmware entry and that type's default
    (Altirra's Firmware\\Available and Firmware\\Default keys; the default
    refers to the entry by its name).
    """
    root = 'User\\Software\\virtualdub.org\\Altirra'
    extra = []
    if devices is not None:
        import json
        js = json.dumps(devices, separators=(',', ':'))
        extra = ['"Devices" = %s' % ini_str(js)]
    fw = sorted((firmware or {}).items())
    for i, (fwtype, fwpath) in enumerate(fw):
        extra += ['[%s\\Firmware\\Available\\%016X]' % (root, 0x8E05000000000000 + i),
                  '"Path" = %s' % ini_str(win(fwpath)),
                  '"Name" = %s' % ini_str('EOS test ' + fwtype),
                  '"Type" = %s' % ini_str(fwtype),
                  '"Flags" = 0']
    if fw:
        extra += ['[%s\\Firmware\\Default]' % root]
        extra += ['"%s" = %s' % (t, ini_str('EOS test ' + t)) for t, _ in fw]
    # U1MB: Altirra's first start makes its stock profiles and the XL/XE one
    # current; that profile's Hardware category (U1MB among it) would hide
    # the global profile's "Memory: Ultimate1MB". Use the global profile.
    profiles = (['[%s\\Profiles]' % root, '"Defaults inited" = 1', '"Current profile" = 0']
                if ultimate1mb else [])
    Path(path).write_text('\n'.join([
        '; Altirra settings for headless BW-DOS tests',
        '[%s\\Settings]' % root,
        '"Pause when inactive" = 0',
        ] + (['"Flash: Ultimate1MB flash mode" = "%s"' % u1mb_flash] if u1mb_flash else []) + profiles + [
        '[%s\\Profiles\\00000000]' % root,
        '"Pause when inactive" = 0',
        '"Disk: SIO patch enabled" = 1',
        '"Kernel: Fast boot enabled" = 1',
        '"Disk: Accurate sector timing" = 0',
        '"Turbo mode" = %d' % turbo,
        '"Memory: Ultimate1MB" = %d' % ultimate1mb,
        ] + extra + ['']), encoding='utf-8')


def screenshot(path):
    subprocess.run(['import', '-window', 'root', str(path)], capture_output=True)


def window_id(timeout=15):
    """Altirra's window (retried: it can be missing right after a dialog)."""
    deadline = time.monotonic() + timeout
    while True:
        p = subprocess.run(['xdotool', 'search', '--name', 'Altirra'], capture_output=True,
                           text=True)
        ids = p.stdout.split()
        if ids or time.monotonic() > deadline:
            return ids[-1] if ids else None
        time.sleep(0.5)


def keys(wid, *seq):
    for k in seq:
        subprocess.run(['xdotool', 'key', '--window', wid, '--clearmodifiers', k], capture_output=True)
        time.sleep(0.2)


def type_line(wid, s):
    """Type a command line; xdotool sends ':' as ';', so avoid drive prefixes."""
    subprocess.run(['xdotool', 'type', '--window', wid, '--delay', '60', s], capture_output=True)
    keys(wid, 'Return')


KEYSYM = {':': 'shift+semicolon', '"': 'shift+apostrophe', '>': 'shift+period',
          '<': 'shift+comma', '?': 'shift+slash', '*': 'shift+8', '!': 'shift+1',
          '$': 'shift+4', '(': 'shift+9', ')': 'shift+0', '_': 'shift+minus', '+': 'shift+equal',
          ' ': 'space', '.': 'period', ',': 'comma', '/': 'slash', '-': 'minus', '=': 'equal',
          ';': 'semicolon', "'": 'apostrophe'}


def type_keys(wid, s):
    """Type a line a character at a time: shifted characters (: " > ...)
    as keys, the rest with xdotool type, so that they and doubled letters
    come through, unlike type_line."""
    for c in s:
        if c in KEYSYM:
            keys(wid, KEYSYM[c])
        else:
            subprocess.run(['xdotool', 'type', '--window', wid, c], capture_output=True)
            time.sleep(0.15)
    keys(wid, 'Return')


class Session:
    """with Session(out, disks, cart=...) as s: s.wait(disk, 'DONE.LOG')"""

    def __init__(self, out, disks, cart=None, name='session', memsize='64K', turbo=False,
                 debugcmds=None, real=False, devices=None, hardware='800xl', video='ntsc',
                 ultimate1mb=False, extra_args=(), firmware=None, fastboot=True, u1mb_flash=None,
                 basic=False):
        self.out = Path(out)
        self.out.mkdir(parents=True, exist_ok=True)
        self.disks = [Path(d) for d in disks]
        self.name = name
        # make eosall (tools/eosall.py): EOS's configuration from the
        # environment: EOS_MEM the memory (for tests that ask for the
        # default 64K), EOS_REAL=1 the SIO patch off
        if cart and 'sdx' not in str(cart).lower():
            if memsize == '64K':
                memsize = os.environ.get('EOS_MEM') or memsize
            real = real or os.environ.get('EOS_REAL', '') not in ('', '0')
        real = real or os.environ.get('EMU_REAL', '') not in ('', '0')   # (all: tools/bench.py)
        ini = self.out / (name + '.ini')
        write_ini(ini, turbo, devices, ultimate1mb, firmware, u1mb_flash)
        # SDX has its own SIO code, so the OS SIO patch does not apply: use
        # turbo + no sector timing to keep SDX sessions fast
        self.cmd = ['wine', str(ALTIRRA), '/portablealt:' + win(ini), '/hardware:' + hardware,
                    '/memsize:' + memsize, '/basic' if basic else '/nobasic', '/' + video,
                    '/fastboot' if fastboot else '/nofastboot', '/bootrw']
        # fastboot=False: Altirra's fast boot answers SIO for an empty disk
        # slot (D2:-D15:) with a timeout before the OS asks PBI devices, so
        # a PBI BIOS's drives need it off (tools/ideplus_test.py)
        # real: the OS's SIO with the SIO patch off and accurate sector
        # timing, as on a real machine
        self.cmd += (['/nosiopatch', '/accuratedisk'] if real else
                     ['/noaccuratedisk', '/burstio'])
        if os.environ.get('EOS_DISKEMU'):   # the drives' emulation (usdoubler ...)
            self.cmd += ['/diskemu:' + os.environ['EOS_DISKEMU']]
        if cart:                       # a copy: the build may change meanwhile
            snap = self.out / (name + '-cart.car')
            shutil.copyfile(cart, snap)
            self.cmd += ['/cart', win(snap)]
        for d in self.disks:
            self.cmd += ['/disk', win(d)]
        # /autotest: the debugger's .autotest_cmd runs Altirra UI commands
        # (tools/ideplus_test.py: System.SaveFirmwareIDEMain)
        self.cmd += list(extra_args)
        # EMU_DBG: more debugger commands for every session, | between them
        # (tools/bench.py --trace: '.logopen ...|lfe diskcmd|lft -r diskcmd')
        debugcmds = list(debugcmds or []) + [c for c in os.environ.get('EMU_DBG', '').split('|') if c]
        if debugcmds:
            self.cmd += ['/debug'] + [a for c in debugcmds for a in ('/debugcmd', c)]
        self.env = dict(os.environ, WINEPREFIX=str(WINEPREFIX), WINEDEBUG='-all')

    def __enter__(self):
        with open(self.out / (self.name + '-emulator.log'), 'wb') as log:
            self.proc = subprocess.Popen(self.cmd, env=self.env, stdout=log,
                                         stderr=subprocess.STDOUT, start_new_session=True)
        return self

    def wait(self, disk, name, timeout=120):
        """Poll disk (index or path) until file name exists; screenshot either way."""
        atr = self.disks[disk] if isinstance(disk, int) else disk
        deadline = time.monotonic() + timeout
        ok = False
        while time.monotonic() < deadline:
            if extract(atr, name, self.out / (self.name + '-poll')) is not None:
                ok = True
                break
            time.sleep(2)
        screenshot(self.out / (self.name + '.png'))
        return ok

    def __exit__(self, *exc):
        try:
            os.killpg(self.proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        subprocess.run(['wineserver', '-k'], env=self.env, capture_output=True)
        self.proc.wait()
        shutil.rmtree(self.out / (self.name + '-poll'), ignore_errors=True)
        (self.out / (self.name + '-cart.car')).unlink(missing_ok=True)


def bwdos_disk(path, startup, boot='XBW15.DOS', extra=None, size=184320, man=True):
    """BW-DOS disk from build/stage with the given STARTUP.BAT lines.

    extra maps disk paths ('DATA/X.DAT') to bytes. Bootable when boot is set,
    with the native boot sectors (tools/mkboot.py).
    """
    import tempfile
    sys.path.insert(0, str(ROOT / 'tools'))
    import mkboot
    with tempfile.TemporaryDirectory(dir=BUILD) as tmp:
        tree = Path(tmp) / 'tree'
        shutil.copytree(BUILD / 'stage', tree)
        if not man:
            shutil.rmtree(tree / 'MAN')
        (tree / 'STARTUP.BAT').write_bytes(atascii(startup))
        dirs = set()
        for name, data in (extra or {}).items():
            (tree / name).parent.mkdir(parents=True, exist_ok=True)
            (tree / name).write_bytes(data)
            dirs.add(str(Path(name).parent))
        files = ['DOS'] + ['DOS/' + f.name for f in sorted((tree / 'DOS').iterdir())]
        if man:
            files += ['MAN'] + ['MAN/' + f.name for f in sorted((tree / 'MAN').iterdir())]
        for d in sorted(dirs - {'.'}):
            files += [d] + ['%s/%s' % (d, f.name) for f in sorted((tree / d).iterdir())]
        files += [n for n in (extra or {}) if '/' not in n]
        files += ['CONFIG.BAT', 'STARTUP.BAT']
        mkatr(path, tree, files, size, boot=boot and 'DOS/' + boot)
    if boot:
        mkboot.patch(path, BUILD / 'dos' / 'FORMAT.COM', 'BWDOS15')
