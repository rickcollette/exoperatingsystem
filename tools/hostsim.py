#!/usr/bin/env python3
"""Run the EOS cartridge on the host, without an emulator.

A 6502 (tools/m6502.py) with 64K RAM and the AtariMax 1 MB banking at
$A000-$BFFF. There is no OS ROM: the OS entry points the cartridge uses are
Python functions instead (CIOV for the screen editor on IOCB 0, SIOV for disk
drives backed by ATR images). Fast enough to test the FMS, the loader and
the library in seconds; Altirra (tools/eos_test.py) remains the real test.

    sim = Sim('build/EOS.car', {1: 'disk.atr'})
    print(sim.run(['TYPE HELLO.TXT']))

usage: hostsim.py [-d N=image.atr ...] [command ...]
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import m6502  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
EOL = 0x9B
CIOV, SIOV = 0xE456, 0xE459


class Atr:
    def __init__(self, path):
        self.path = Path(path)
        self.data = bytearray(self.path.read_bytes())
        self.seclen = struct.unpack_from('<H', self.data, 4)[0]

    def where(self, n):
        if self.seclen <= 256 and n <= 3:
            return 16 + (n - 1) * 128, 128
        if self.seclen <= 256:
            return 16 + 384 + (n - 4) * self.seclen, self.seclen
        return 16 + (n - 1) * self.seclen, self.seclen

    def read(self, n):
        o, size = self.where(n)
        if n < 1 or o + size > len(self.data):
            return None
        return bytes(self.data[o:o + size])

    def write(self, n, data):
        o, size = self.where(n)
        if n < 1 or o + size > len(self.data):
            return False
        self.data[o:o + size] = data[:size]
        self.path.write_bytes(self.data)
        return True


def labels(module):
    out = {}
    for line in (ROOT / 'build' / 'eos' / (module + '.lab')).read_text().splitlines():
        f = line.split()
        if len(f) == 3:
            out[f[2].upper()] = int(f[1], 16)
    return out


class Stop(Exception):
    pass


class Sim:
    def __init__(self, car=ROOT / 'build' / 'EOS.car', disks=None, trace=False, xe=False):
        raw = Path(car).read_bytes()[16:]
        self.banks = [raw[i * 8192:(i + 1) * 8192] for i in range(len(raw) // 8192)]
        self.bank = 0
        self.ram = bytearray(0x10000)
        # xe: a 130XE's 4 banks at $4000-$7FFF (PORTB bit 4 clear, bits 2-3)
        self.xbanks = [bytearray(0x4000) for _ in range(4)] if xe else None
        self.disks = {u: Atr(p) for u, p in (disks or {}).items()}
        self.cpu = m6502.CPU(self)
        self.out = bytearray()
        self.input = []
        self.kern = labels('kernel')
        self.trace = trace
        self._os_init()

    # ---- bus ------------------------------------------------------------------
    def _xbank(self, a):
        if self.xbanks and 0x4000 <= a < 0x8000 and not self.ram[0xD301] & 0x10:
            return self.xbanks[(self.ram[0xD301] >> 2) & 3]
        return None

    def read(self, a):
        if 0xA000 <= a < 0xC000 and self.bank is not None:
            return self.banks[self.bank][a - 0xA000]
        xb = self._xbank(a)
        if xb is not None:
            return xb[a - 0x4000]
        if a == 0xD013:                # TRIG3: cartridge present
            return 1
        return self.ram[a]

    def write(self, a, v):
        if 0xD500 <= a < 0xD600:
            n = a & 0xFF
            self.bank = None if n & 0x80 else n
            return
        if 0xA000 <= a < 0xC000 and self.bank is not None:
            return
        xb = self._xbank(a)
        if xb is not None:
            xb[a - 0x4000] = v
            return
        self.ram[a] = v

    # ---- OS ---------------------------------------------------------------------
    def _os_init(self):
        r = self.ram
        r[0x6A] = 0xA0                 # RAMTOP
        struct.pack_into('<H', r, 0x2E5, 0x9C1F)   # MEMTOP
        struct.pack_into('<H', r, 0x2E7, 0x0700)   # MEMLO
        struct.pack_into('<H', r, 0x58, 0x9C40)    # SAVMSC
        r[0x340] = 6                   # IOCB 0 open on E:
        r[0xD301] = 0xFF               # PORTB

    def cio(self):
        c = self.cpu
        x = c.x
        cmd = self.ram[0x342 + x]
        adr = self.ram[0x344 + x] | self.ram[0x345 + x] << 8
        n = self.ram[0x348 + x] | self.ram[0x349 + x] << 8
        status = 1
        if x != 0:
            status = 130
        elif cmd in (0x09, 0x0B):      # put record / put bytes
            if n == 0:
                self.out.append(c.a)
            else:
                for i in range(n):
                    b = self.read((adr + i) & 0xFFFF)
                    self.out.append(b)
                    if cmd == 0x09 and b == EOL:
                        break
        elif cmd in (0x05, 0x07):      # get record / get bytes
            if not self.input:
                raise Stop('input wanted')
            line = self.input.pop(0).encode('latin-1') + bytes([EOL])
            self.out += line           # echo, as the screen editor does
            got = line[:n] if n else line[:1]
            for i, b in enumerate(got):
                self.ram[(adr + i) & 0xFFFF] = b
            struct.pack_into('<H', self.ram, 0x348 + x, len(got))
            if n == 0:
                c.a = got[0]
        elif cmd == 0x0C:
            pass
        else:
            status = 132
        self.ram[0x343 + x] = status
        c.y = status
        c.nz(status)

    def sio(self):
        r = self.ram
        unit, cmd = r[0x301], r[0x302]
        buf = r[0x304] | r[0x305] << 8
        size = r[0x308] | r[0x309] << 8
        sec = r[0x30A] | r[0x30B] << 8
        disk = self.disks.get(unit) if r[0x300] == 0x31 else None
        status = 1
        if disk is None:
            status = 138
        elif cmd == 0x52:
            data = disk.read(sec)
            if data is None or len(data) != size:
                status = 144
            else:
                r[buf:buf + size] = data
        elif cmd in (0x50, 0x57):
            if not disk.write(sec, bytes(r[buf:buf + size])):
                status = 144
        else:
            status = 139
        r[0x303] = status
        self.cpu.y = status
        self.cpu.nz(status)

    # ---- running ------------------------------------------------------------
    def rts(self):
        c = self.cpu
        lo = c.pull()
        c.pc = ((c.pull() << 8 | lo) + 1) & 0xFFFF

    def run(self, lines=(), limit=20_000_000):
        """Boot (first call) and feed lines to the command processor.
        Returns the screen output (ATASCII EOL as newline)."""
        self.input += list(lines)
        c = self.cpu
        if c.pc == 0:
            c.pc = 0xA000              # bank 0: cold start
        start = len(self.out)
        getline = self.kern['K_GETLINE']
        try:
            for _ in range(limit):
                pc = c.pc
                if pc == CIOV:
                    self.cio()
                    self.rts()
                    continue
                if pc == SIOV:
                    self.sio()
                    self.rts()
                    continue
                if pc == getline and not self.input:
                    raise Stop('prompt')
                if pc >= 0xC000 and pc not in (CIOV, SIOV):
                    raise Stop('PC $%04X outside the cartridge and RAM' % pc)
                if self.trace:
                    print('%04X b%s A%02X X%02X Y%02X P%02X S%02X' % (
                        pc, self.bank, c.a, c.x, c.y, c.p, c.s))
                c.step()
            raise Stop('instruction limit')
        except Stop as e:
            self.stopped = str(e)
        return bytes(self.out[start:]).replace(bytes([EOL]), b'\n').decode('latin-1')


def main():
    args = sys.argv[1:]
    disks = {}
    while args[:1] == ['-d']:
        u, p = args[1].split('=', 1)
        disks[int(u)] = p
        args = args[2:]
    sim = Sim(disks=disks)
    print(sim.run(args), end='')
    print('\n[%s]' % sim.stopped)


if __name__ == '__main__':
    main()
