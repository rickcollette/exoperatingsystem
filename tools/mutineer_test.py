#!/usr/bin/env python3
"""The Atari Mutineer BBS on EOS and on real SDX: boot the cart with a fresh
copy of atari-mutineer-v1.4.1-16mb-all-drivers.atr in D1:, type the disk's
START batch for a communication driver, then call the BBS through
Altirra's emulated modem (a TCP port on this machine) and walk it: the
login screen, a new user, the main menu, log off. The caller's transcript
and the files the BBS changed are kept per run.

usage: mutineer_test.py [--cart eos|sdx] [--driver 850] [--mem 320K]
                        [--real] [--hardware 800xl] [--video ntsc]
                        [--scenario login|walk]      (in xvfb-run)
Results go to build/mutineer-results/<cart>-<driver>-<mem>[...]/.
"""
import argparse
import shutil
import socket
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import sdfs  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
DISK = ROOT / 'media' / 'atari-mutineer-v1.4.1-16mb-all-drivers.atr'
OUT = emu.BUILD / 'mutineer-results'
CARTS = {'eos': emu.BUILD / 'EOS.car', 'sdx': emu.SDX_CART}
START = {'850': 'START850.BAT', 'fn': 'STARTFN.BAT',
         'rvf': 'STARTRVF.BAT', 'rvt': 'STARTRVT.BAT'}   # (R-Verter: not emulated)
FUJI = emu.BUILD / 'fujinet'
FNPC = FUJI / 'fnpc' / 'build' / 'dist'
NETSIO = FUJI / 'bridge' / 'altirra-custom-device' / 'netsio.atdevice'


def devices(driver, port, clock):
    """Altirra's device list: the clock, and the 850 with a modem that
    answers calls on port (full 850 emulation, as the R: handler talks to
    the 850 itself)."""
    devs = []
    if clock == 'rtime8':
        devs.append({'tag': 'rtime8'})
    if driver == '850':
        modem = {'ipv6': False, 'port': port, 'netmode': 'none', 'unthrottled': False,
                 'connect_rate': 9600, 'check_rate': False, 'telnet': False,
                 'outbound': False, 'telnetlf': False}
        devs.append({'tag': '850', 'params': {'baudex': True, 'emulevel': 2},
                     'buses': {'0': {'children': [{'tag': 'modem', 'params': modem}]}}})
    if driver == 'fn':                 # FujiNet-PC through the NetSIO hub
        devs.append({'tag': 'custom', 'params': {'path': emu.win(NETSIO), 'hotreload': False}})
    return devs


class FujiNet:
    """The NetSIO hub and FujiNet-PC (N: on the SIO bus through Altirra's
    custom device), with a config of their own: no disk slots or CONFIG
    disk (D1: is Altirra's), SIO over network on."""

    def __init__(self, out):
        import os
        import subprocess
        self.out = out
        cfg = (FNPC / 'fnconfig.ini').read_text()
        cfg = cfg.replace('configenabled=1', 'configenabled=0')
        for k in range(1, 11):
            cfg = cfg.replace('enable_device_slot_%d=1' % k, 'enable_device_slot_%d=0' % k)
        (out / 'fnconfig.ini').write_text(cfg)
        env = dict(os.environ)
        self.hub = subprocess.Popen([sys.executable, '-m', 'netsiohub'], cwd=FUJI / 'bridge' / 'fujinet-bridge',
                                    stdout=(out / 'hub.log').open('wb'), stderr=subprocess.STDOUT,
                                    start_new_session=True, env=env)
        time.sleep(2)
        self.fn = subprocess.Popen([str(FNPC / 'fujinet'), '-c', str(out / 'fnconfig.ini'),
                                    '-s', str(out / 'SD')], cwd=FNPC,
                                   stdout=(out / 'fujinet.log').open('wb'), stderr=subprocess.STDOUT,
                                   start_new_session=True, env=env)
        time.sleep(3)

    def close(self):
        import os
        import signal
        for p in (self.fn, self.hub):
            try:
                os.killpg(p.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            p.wait()


class Caller:
    """The caller: a TCP connection to the modem, text in, lines out."""

    def __init__(self, port, log):
        self.sock = socket.create_connection(('127.0.0.1', port), timeout=10)
        self.sock.settimeout(0.25)
        self.log = log.open('ab')
        self.seen = bytearray()

    def close(self):
        self.log.close()
        self.sock.close()

    def expect(self, text, timeout):
        want = text.encode('latin-1')
        end = time.monotonic() + timeout
        start = len(self.seen)
        while time.monotonic() < end:
            try:
                data = self.sock.recv(4096)
            except socket.timeout:
                data = b''
            except OSError:
                return False
            if data:
                self.log.write(data)
                self.log.flush()
                self.seen += bytes(b & 0x7F for b in data)
                if want in self.seen[start:]:
                    return True
            elif data == b'' and False:
                return False
        return False

    def quiet(self, gap, timeout):
        """Read until output came and then nothing for gap seconds."""
        end = time.monotonic() + timeout
        last, got = time.monotonic(), False
        while time.monotonic() < end:
            try:
                data = self.sock.recv(4096)
            except socket.timeout:
                data = None
            except OSError:
                return
            if data:
                self.log.write(data)
                self.log.flush()
                self.seen += bytes(b & 0x7F for b in data)
                last, got = time.monotonic(), True
            elif got and time.monotonic() - last >= gap:
                return

    def send(self, line, end=b'\r\n'):
        for ch in line.encode('latin-1') + end:
            self.sock.sendall(bytes([ch]))
            time.sleep(0.05)
        self.log.write(b'\n>>> ' + line.encode('latin-1') + b'\n')


# (expect, send): the steps of a scenario; send None sends nothing
LOGIN = [
    ('PRESS [RETURN]', ''),
    ('ASCII MODE', None),
    ('[G]oodbye >', 'N'),
    ('Full Name >', 'EOS TESTER'),
    ('Handle >', 'EOSTEST'),
    ('Email >', 'EOS@EXAMPLE.COM'),
    ('Password >', 'PASS1234'),
    ('Password again >', 'PASS1234'),
    ('[Q] Cancel >', 'Y'),
    ('ACCOUNT CREATED.', None),
    ('Read New User Info? [Y/N]', 'N'),
    ('Read Bulletins? [Y/N]', 'N'),
    ('Command >', 'G'),
    ('Log off', 'Y'),
    ('Leave feedback to sysop', 'N'),
    ('Loading WFC', None),
]
MAIN = LOGIN[:LOGIN.index(('Command >', 'G'))]
LOGOFF = LOGIN[LOGIN.index(('Command >', 'G')):]
# logged in: post a message and read it back, the file area, the three
# doors, log off
WALK = MAIN + [
    ('Command >', 'M'),
    ('Msg Command >', 'E'),
    ('Base [', 'A'),
    ('TO: ALL', ''),
    ('SUBJECT: ', 'HELLO EOS'),
    ('1> ', 'THIS IS A TEST'),
    ('2> ', '/'),
    ('[C]ontinue >', 'S'),
    ('SAVED AS MSG#1', None),
    ('Msg Command >', 'R'),
    ('Msg# From-To >', '1'),
    ('THIS IS A TEST', None),
    ('RETURN=Next >', 'Q'),
    ('Msg# From-To >', 'Q'),
    ('Msg Command >', 'X'),
    ('Command >', 'F'),
    ('MUTINEER FILE AREAS', None),
    ('File Command >', 'B'),
    ('NO  FILE NAME', None),
    ('RETURN=File Menu >', ''),
    ('File Command >', 'X'),
    ('Command >', 'D'),
    ('Door Command >', '1'),
    ('BLACKJACK TABLE', None),
    ('[Q] Cash Out >', 'B'),
    ('HIGH ROLLERS BOARD', None),
    ('PRESS RETURN', ''),
    ('[Q] Cash Out >', 'Q'),
    ('CASH OUT:', None),
    ('PRESS RETURN', ''),
    ('Door Command >', '2'),
    ('Choose Class >> ', 'W'),
    ('Your Move >> ', 'A'),
    ('Your Move >> ', 'Q'),
    ('YOUR EXPEDITION IS OVER.', None),
    ('PRESS RETURN', ''),
    ('Door Command >', '3'),
    ('TOURNAMENT ARENA', None),
    ('Arena Command >>', 'V'),
    ('ROUND', None),
    ('PRESS RETURN', ''),
    ('Arena Command >>', 'Q'),
    ('Door Command >', 'X'),
] + LOGOFF
SCENARIOS = {'login': LOGIN, 'walk': WALK,
             # logged in, at the main menu: then --keys, each sent after
             # --key-wait seconds of output (to learn the prompts)
             'explore': LOGIN[:LOGIN.index(('Command >', 'G'))] + [('Command >', None)]}


def connect(port, log, timeout):
    """One call (a connection that is dropped would be a call too)."""
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            return Caller(port, log)
        except OSError:
            time.sleep(2)
    return None


def run(a):
    tag = '-'.join([a.cart, a.driver, a.mem] + (['real'] if a.real else []) +
                   ([a.clock] if a.clock != 'rtime8' else []) +
                   (['reset' if a.reset == 'F5' else 'cold'] if a.reset else []) +
                   (['cfg' + a.cfgname] if a.config else []) +
                   ([a.hardware] if a.hardware != '800xl' else []) +
                   ([a.video] if a.video != 'ntsc' else []) + [a.scenario])
    out = OUT / tag
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    d1 = out / 'D1.atr'
    shutil.copy(DISK, d1)
    # the disk's own advice: its START batch copied to AUTOEXEC.BAT
    v = sdfs.Volume(str(d1))
    bat = dict((p, e) for p, e in v.walk())['/' + START[a.driver]]['data']
    sdfs.overwrite(str(d1), 'AUTOEXEC.BAT', bat)
    if a.reset == 'F5':            # after RESET: the BBS again from EOS's prompt
        other = [b for d, b in START.items() if d != a.driver][0]  # (the unused batch)
        sdfs.overwrite(str(d1), other, emu.atascii(['BASIC /I <<D1:AUTOGO']))
    if a.config:                   # a CONFIG.SYS (the README's place on the disk)
        sdfs.overwrite(str(d1), 'README', emu.atascii(a.config.split('|')), 'CONFIG.SYS')
    log = out / 'caller.txt'
    port = a.port
    steps = list(SCENARIOS[a.scenario])
    for st in filter(None, a.steps.split('|')):   # more steps: expect=>send
        e, _, snd = st.partition('=>')
        if steps and steps[-1] == (e, None):      # the same prompt: answer it
            steps.pop()
        steps.append((e, snd if '=>' in st else None))
    done = 0
    why = ''
    t0 = time.monotonic()
    dbg = None
    if a.bp:                       # memory at each hit of an address, the last kept
        dbg = ['bp $%s ".writemem %s 0 L10000; g"' % (a.bp, emu.win(out / 'bp.bin'))]
    if a.trace:
        dbg = ['.logopen ' + emu.win(out / 'debug.log'), '.tracecio on',
               # each BASIC error: memory to err-*.bin ($C3 the error, $BA the line)
               'ba w $00C3 ".writemem %s 0 L10000; g"' % emu.win(out / 'err.bin')]
    fuji = FujiNet(out) if a.driver == 'fn' else None
    try:
        res = session(a, out, d1, port, steps, log, dbg)
    finally:
        if fuji:
            fuji.close()
    return finish(a, out, d1, tag, steps, *res, t0)


def session(a, out, d1, port, steps, log, dbg):
    done = 0
    why = ''
    with emu.Session(out, [d1], cart=CARTS[a.cart], name='mutineer', memsize=a.mem,
                     turbo=False, real=a.real, devices=devices(a.driver, port, a.clock),
                     hardware=a.hardware, video=a.video, debugcmds=dbg):
        time.sleep(15)
        emu.screenshot(out / 'boot.png')
        time.sleep(a.wfc)
        emu.screenshot(out / 'wfc.png')
        if a.reset:                    # RESET at WFC (Altirra's warm reset)
            emu.keys(emu.window_id(), a.reset)
            time.sleep(10)
            emu.screenshot(out / 'after-reset.png')
            if a.reset == 'F5':        # BASIC's prompt: DOS, then the BBS again
                wid = emu.window_id()  # (its R: handler kept over the reset)
                emu.type_line(wid, 'DOS')
                time.sleep(5)
                other = [b for d, b in START.items() if d != a.driver][0]
                emu.keys(wid, 'minus')    # -NAME: a batch file (xdotool type drops -)
                emu.type_line(wid, other.split('.')[0])
                time.sleep(4)
                emu.screenshot(out / 'restart.png')
                time.sleep(a.wfc)
                emu.screenshot(out / 'wfc2.png')
        if a.trace:                    # the debugger console: close the log
            import subprocess
            wid = emu.window_id()
            subprocess.run(['xdotool', 'windowactivate', '--sync', wid])
            subprocess.run(['xdotool', 'mousemove', '400', '559', 'click', '1'])
            time.sleep(1)
            subprocess.run(['xdotool', 'type', '--delay', '50', '.logclose'])
            subprocess.run(['xdotool', 'key', 'Return'])
            time.sleep(3)
        c = connect(port, log, 30)
        if c is None:
            why = 'no modem listener on port %d' % port
        else:
            try:
                for exp, send in steps:
                    if not c.expect(exp, a.step_timeout):
                        why = 'no %r' % exp
                        break
                    done += 1
                    if send is not None:
                        time.sleep(1.0)
                        c.send(send)
                if a.scenario == 'explore' and done == len(steps):
                    for k in filter(None, a.keys.split(',')) if a.keys else []:
                        c.quiet(3, a.key_wait)
                        c.send(k)
                    c.quiet(10, a.key_wait)
            finally:
                c.close()
            emu.screenshot(out / 'end.png')
    return done, why


def finish(a, out, d1, tag, steps, done, why, t0):
    ok = done == len(steps)
    res = '%s %s  %d/%d steps %ds%s' % (tag, 'PASS' if ok else 'FAIL', done, len(steps),
                                         time.monotonic() - t0, ('  ' + why) if why else '')
    (out / 'result.txt').write_text(res + '\n')
    try:
        v = sdfs.Volume(str(d1))
        v.check()
        if v.errors:
            res += '  disk: %s' % v.errors[0]
            ok = False
    except sdfs.SdfsError as e:
        res += '  disk: %s' % e
        ok = False
    print(res, flush=True)
    return ok


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--cart', default='eos', choices=list(CARTS))
    p.add_argument('--driver', default='850', choices=list(START))
    p.add_argument('--mem', default='320K')
    p.add_argument('--real', action='store_true')
    p.add_argument('--hardware', default='800xl')
    p.add_argument('--video', default='ntsc')
    p.add_argument('--clock', default='rtime8')
    p.add_argument('--scenario', default='login', choices=list(SCENARIOS))
    p.add_argument('--port', type=int, default=6507 + 10 * int(emu.WORKER or 0),
                   help='the call port (850 modem or FujiNet N:); one per EMU_WORKER')
    p.add_argument('--wfc', type=float, default=60, help='seconds to let the BBS start')
    p.add_argument('--step-timeout', type=float, default=120)
    p.add_argument('--trace', action='store_true', help='CIO calls to debug.log')
    p.add_argument('--bp', default='', help='hex address: memory to bp.bin at each hit')
    p.add_argument('--keys', default='', help='explore: lines to send, comma separated')
    p.add_argument('--steps', default='', help='explore: more steps, expect=>send|...')
    p.add_argument('--config', default='', help='CONFIG.SYS lines, | separated')
    p.add_argument('--reset', default='', help='key pressed at WFC: F5 warm reset, shift+F5 cold')
    p.add_argument('--cfgname', default='', help='a short name for the config (results)')
    p.add_argument('--key-wait', type=float, default=20)
    a = p.parse_args()
    sys.exit(0 if run(a) else 1)


if __name__ == '__main__':
    main()
