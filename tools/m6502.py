"""A small NMOS 6502 interpreter (documented opcodes, decimal mode).

Used by tools/hostsim.py to run EOS code on the host. Memory goes through
read(addr) and write(addr, value) of the bus object given to CPU().
"""

C, Z, I, D, B, U, V, N = 1, 2, 4, 8, 16, 32, 64, 128


class CPU:
    def __init__(self, bus):
        self.bus = bus
        self.a = self.x = self.y = 0
        self.s = 0xFF
        self.p = U | I
        self.pc = 0
        self.cycles = 0
        self.ops = self._table()

    # ---- helpers ------------------------------------------------------------
    def rd(self, a):
        return self.bus.read(a & 0xFFFF)

    def wr(self, a, v):
        self.bus.write(a & 0xFFFF, v & 0xFF)

    def rdw(self, a):
        return self.rd(a) | self.rd(a + 1) << 8

    def rdw_zp(self, a):
        return self.rd(a & 0xFF) | self.rd((a + 1) & 0xFF) << 8

    def push(self, v):
        self.wr(0x100 + self.s, v)
        self.s = (self.s - 1) & 0xFF

    def pull(self):
        self.s = (self.s + 1) & 0xFF
        return self.rd(0x100 + self.s)

    def nz(self, v):
        self.p = (self.p & ~(N | Z)) | (v & N) | (0 if v else Z)
        return v

    def fetch(self):
        v = self.rd(self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        return v

    def fetchw(self):
        v = self.rdw(self.pc)
        self.pc = (self.pc + 2) & 0xFFFF
        return v

    # ---- addressing modes: return an address -------------------------------
    def imm(self):
        a = self.pc
        self.pc = (self.pc + 1) & 0xFFFF
        return a

    def zp(self):
        return self.fetch()

    def zpx(self):
        return (self.fetch() + self.x) & 0xFF

    def zpy(self):
        return (self.fetch() + self.y) & 0xFF

    def ab(self):
        return self.fetchw()

    def abx(self):
        return (self.fetchw() + self.x) & 0xFFFF

    def aby(self):
        return (self.fetchw() + self.y) & 0xFFFF

    def izx(self):
        return self.rdw_zp(self.fetch() + self.x)

    def izy(self):
        return (self.rdw_zp(self.fetch()) + self.y) & 0xFFFF

    # ---- instructions --------------------------------------------------------
    def adc(self, v):
        c = self.p & C
        if self.p & D:
            lo = (self.a & 0x0F) + (v & 0x0F) + c
            hi = (self.a >> 4) + (v >> 4)
            if lo > 9:
                lo += 6
                hi += 1
            bin_ = (self.a + v + c) & 0xFF
            self.p = (self.p & ~(Z | N | V)) | (0 if bin_ else Z)
            if hi & 8:
                self.p |= N
            if ~(self.a ^ v) & (self.a ^ (hi << 4)) & 0x80:
                self.p |= V
            if hi > 9:
                hi += 6
            self.p = (self.p & ~C) | (C if hi > 15 else 0)
            self.a = ((hi << 4) | (lo & 0x0F)) & 0xFF
            return
        r = self.a + v + c
        self.p = (self.p & ~(C | V)) | (C if r > 0xFF else 0) | \
            (V if ~(self.a ^ v) & (self.a ^ r) & 0x80 else 0)
        self.a = self.nz(r & 0xFF)

    def sbc(self, v):
        if self.p & D:
            c = 1 - (self.p & C)
            r = self.a - v - c
            lo = (self.a & 0x0F) - (v & 0x0F) - c
            hi = (self.a >> 4) - (v >> 4)
            if lo < 0:
                lo -= 6
                hi -= 1
            if hi < 0:
                hi -= 6
            self.p = (self.p & ~(C | V)) | (C if r >= 0 else 0) | \
                (V if (self.a ^ v) & (self.a ^ r) & 0x80 else 0)
            self.nz(r & 0xFF)
            self.a = ((hi << 4) | (lo & 0x0F)) & 0xFF
            return
        self.adc(v ^ 0xFF)

    def cmp(self, r, v):
        t = r - v
        self.p = (self.p & ~C) | (C if t >= 0 else 0)
        self.nz(t & 0xFF)

    def branch(self, cond):
        off = self.fetch()
        if cond:
            self.pc = (self.pc + (off - 256 if off & 0x80 else off)) & 0xFFFF

    def _table(self):
        t = {}

        def ld(reg, mode):
            def f():
                setattr(self, reg, self.nz(self.rd(mode())))
            return f

        def st(reg, mode):
            def f():
                self.wr(mode(), getattr(self, reg))
            return f

        modes = {'imm': self.imm, 'zp': self.zp, 'zpx': self.zpx, 'zpy': self.zpy, 'ab': self.ab,
                 'abx': self.abx, 'aby': self.aby, 'izx': self.izx, 'izy': self.izy}

        for op, m in [(0xA9, 'imm'), (0xA5, 'zp'), (0xB5, 'zpx'), (0xAD, 'ab'), (0xBD, 'abx'),
                      (0xB9, 'aby'), (0xA1, 'izx'), (0xB1, 'izy')]:
            t[op] = ld('a', modes[m])
        for op, m in [(0xA2, 'imm'), (0xA6, 'zp'), (0xB6, 'zpy'), (0xAE, 'ab'), (0xBE, 'aby')]:
            t[op] = ld('x', modes[m])
        for op, m in [(0xA0, 'imm'), (0xA4, 'zp'), (0xB4, 'zpx'), (0xAC, 'ab'), (0xBC, 'abx')]:
            t[op] = ld('y', modes[m])
        for op, m in [(0x85, 'zp'), (0x95, 'zpx'), (0x8D, 'ab'), (0x9D, 'abx'), (0x99, 'aby'),
                      (0x81, 'izx'), (0x91, 'izy')]:
            t[op] = st('a', modes[m])
        for op, m in [(0x86, 'zp'), (0x96, 'zpy'), (0x8E, 'ab')]:
            t[op] = st('x', modes[m])
        for op, m in [(0x84, 'zp'), (0x94, 'zpx'), (0x8C, 'ab')]:
            t[op] = st('y', modes[m])

        alu = {
            'ora': lambda v: setattr(self, 'a', self.nz(self.a | v)),
            'and': lambda v: setattr(self, 'a', self.nz(self.a & v)),
            'eor': lambda v: setattr(self, 'a', self.nz(self.a ^ v)),
            'adc': self.adc, 'sbc': self.sbc,
            'cmp': lambda v: self.cmp(self.a, v),
        }
        base = {'ora': 0x00, 'and': 0x20, 'eor': 0x40, 'adc': 0x60, 'cmp': 0xC0, 'sbc': 0xE0}
        offs = {'izx': 0x01, 'zp': 0x05, 'imm': 0x09, 'ab': 0x0D, 'izy': 0x11, 'zpx': 0x15,
                'aby': 0x19, 'abx': 0x1D}
        for name, b in base.items():
            for m, o in offs.items():
                fn, md = alu[name], modes[m]
                t[b + o] = (lambda fn, md: lambda: fn(self.rd(md())))(fn, md)

        for op, m in [(0xE0, 'imm'), (0xE4, 'zp'), (0xEC, 'ab')]:
            t[op] = (lambda md: lambda: self.cmp(self.x, self.rd(md())))(modes[m])
        for op, m in [(0xC0, 'imm'), (0xC4, 'zp'), (0xCC, 'ab')]:
            t[op] = (lambda md: lambda: self.cmp(self.y, self.rd(md())))(modes[m])

        def bit(md):
            def f():
                v = self.rd(md())
                self.p = (self.p & ~(N | V | Z)) | (v & (N | V)) | (0 if v & self.a else Z)
            return f
        t[0x24] = bit(self.zp)
        t[0x2C] = bit(self.ab)

        def rmw(fn, md):
            def f():
                a = md()
                self.wr(a, fn(self.rd(a)))
            return f

        def asl(v):
            self.p = (self.p & ~C) | (C if v & 0x80 else 0)
            return self.nz((v << 1) & 0xFF)

        def lsr(v):
            self.p = (self.p & ~C) | (v & 1)
            return self.nz(v >> 1)

        def rol(v):
            c = self.p & C
            self.p = (self.p & ~C) | (C if v & 0x80 else 0)
            return self.nz(((v << 1) | c) & 0xFF)

        def ror(v):
            c = self.p & C
            self.p = (self.p & ~C) | (v & 1)
            return self.nz((v >> 1) | (0x80 if c else 0))

        def inc(v):
            return self.nz((v + 1) & 0xFF)

        def dec(v):
            return self.nz((v - 1) & 0xFF)

        for fn, b in [(asl, 0x00), (rol, 0x20), (lsr, 0x40), (ror, 0x60)]:
            t[b + 0x06] = rmw(fn, self.zp)
            t[b + 0x16] = rmw(fn, self.zpx)
            t[b + 0x0E] = rmw(fn, self.ab)
            t[b + 0x1E] = rmw(fn, self.abx)
            t[b + 0x0A] = (lambda fn: lambda: setattr(self, 'a', fn(self.a)))(fn)
        for fn, b in [(dec, 0xC0), (inc, 0xE0)]:
            t[b + 0x06] = rmw(fn, self.zp)
            t[b + 0x16] = rmw(fn, self.zpx)
            t[b + 0x0E] = rmw(fn, self.ab)
            t[b + 0x1E] = rmw(fn, self.abx)

        t[0xE8] = lambda: setattr(self, 'x', inc(self.x))
        t[0xC8] = lambda: setattr(self, 'y', inc(self.y))
        t[0xCA] = lambda: setattr(self, 'x', dec(self.x))
        t[0x88] = lambda: setattr(self, 'y', dec(self.y))
        t[0xAA] = lambda: setattr(self, 'x', self.nz(self.a))
        t[0xA8] = lambda: setattr(self, 'y', self.nz(self.a))
        t[0x8A] = lambda: setattr(self, 'a', self.nz(self.x))
        t[0x98] = lambda: setattr(self, 'a', self.nz(self.y))
        t[0xBA] = lambda: setattr(self, 'x', self.nz(self.s))
        t[0x9A] = lambda: setattr(self, 's', self.x)

        t[0x48] = lambda: self.push(self.a)
        t[0x68] = lambda: setattr(self, 'a', self.nz(self.pull()))
        t[0x08] = lambda: self.push(self.p | B | U)
        t[0x28] = lambda: setattr(self, 'p', (self.pull() & ~B) | U)

        for op, flag, val in [(0x18, C, 0), (0x38, C, 1), (0x58, I, 0), (0x78, I, 1),
                              (0xB8, V, 0), (0xD8, D, 0), (0xF8, D, 1)]:
            t[op] = (lambda f, v: lambda: setattr(self, 'p', (self.p | f) if v else (self.p & ~f)))(flag, val)

        for op, flag, val in [(0x10, N, 0), (0x30, N, 1), (0x50, V, 0), (0x70, V, 1),
                              (0x90, C, 0), (0xB0, C, 1), (0xD0, Z, 0), (0xF0, Z, 1)]:
            t[op] = (lambda f, v: lambda: self.branch(bool(self.p & f) == bool(v)))(flag, val)

        def jsr():
            a = self.fetchw()
            r = (self.pc - 1) & 0xFFFF
            self.push(r >> 8)
            self.push(r & 0xFF)
            self.pc = a

        def rts():
            lo = self.pull()
            self.pc = ((self.pull() << 8 | lo) + 1) & 0xFFFF

        def rti():
            self.p = (self.pull() & ~B) | U
            lo = self.pull()
            self.pc = self.pull() << 8 | lo

        def brk():
            self.pc = (self.pc + 1) & 0xFFFF
            self.push(self.pc >> 8)
            self.push(self.pc & 0xFF)
            self.push(self.p | B | U)
            self.p |= I
            self.pc = self.rdw(0xFFFE)

        def jmpi():
            a = self.fetchw()
            # 6502 page wrap bug
            self.pc = self.rd(a) | self.rd((a & 0xFF00) | ((a + 1) & 0xFF)) << 8

        t[0x20] = jsr
        t[0x60] = rts
        t[0x40] = rti
        t[0x00] = brk
        t[0x4C] = lambda: setattr(self, 'pc', self.fetchw())
        t[0x6C] = jmpi
        t[0xEA] = lambda: None
        return t

    def step(self):
        op = self.fetch()
        f = self.ops.get(op)
        if f is None:
            self.pc = (self.pc - 1) & 0xFFFF
            raise IllegalOpcode('illegal opcode $%02X at $%04X' % (op, self.pc))
        f()
        self.cycles += 1


class IllegalOpcode(Exception):
    pass
