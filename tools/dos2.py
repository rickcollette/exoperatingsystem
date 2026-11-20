#!/usr/bin/env python3
"""Atari DOS 2.0S / 2.5 disk images on the host: list, extract, check.

The documented DOS 2 format: VTOC at sector 360 (code, total, free, bitmap
of sectors 0-719 from byte 10, bit 7 first, 1 = free), directory in
sectors 361-368 (8 entries of 16 bytes: status, sector count, first
sector, name 8+3), data sectors ending in a link (file number << 2 | next
>> 8, next & $FF, byte count). DOS 2.5 enhanced density (1040 sectors):
VTOC2 at sector 1024, bitmap of sectors 48-1023 in bytes 0-121, free
sectors above 719 in bytes 122-123.

MyDOS (format reference: its 4.51 sources): an entry with status $04 has
16-bit links (link byte 0 = next sector's high byte, 1 = low, no file
number); $10 alone (as MyDOS writes it) marks a subdirectory, 8
consecutive sectors laid out like the main directory. A VTOC whose code is 3 or more (256-byte sectors) has its
bitmap continue in sectors 359, 358 ... (the VTOC is read as one block:
sector 360, then 359, ...).

usage: dos2.py ls|check IMAGE
       dos2.py extract IMAGE DIR
"""
import struct
import sys
from pathlib import Path


class Dos2:
    def __init__(self, path):
        self.data = bytearray(Path(path).read_bytes())
        self.seclen = struct.unpack_from('<H', self.data, 4)[0]
        self.nsec = (len(self.data) - 16 - (384 if self.seclen == 256 else 0)) // self.seclen + \
            (3 if self.seclen == 256 else 0)
        self.dbytes = self.seclen - 3
        v = self.sec(360)
        self.code, self.total, self.free = v[0], v[1] | v[2] << 8, v[3] | v[4] << 8
        self.ed = self.nsec == 1040 and self.seclen == 128 and self.total == 1010
        # MyDOS: the VTOC goes on in 359, 358 ...: code - 2 pages of 256
        # bytes (one 256-byte sector, or two 128-byte ones, each)
        if self.code <= 2:
            self.vsecs = [360]
        else:
            n = (self.code - 2) * (256 // self.seclen)
            self.vsecs = [360 - i for i in range(n)]
        self.vpages = len(self.vsecs)

    def vtoc(self):
        return b''.join(bytes(self.sec(s)) for s in self.vsecs)

    def sec(self, n):
        if n <= 3 or self.seclen == 128:
            o, size = 16 + (n - 1) * 128, 128
        else:
            o, size = 16 + 384 + (n - 4) * self.seclen, self.seclen
        return self.data[o:o + size]

    def isfree(self, s):
        if s < 720 or not self.ed:
            v = self.vtoc()
            return (v[10 + s // 8] >> (7 - s % 8)) & 1
        v2 = self.sec(1024)
        s -= 48
        return (v2[s // 8] >> (7 - s % 8)) & 1

    def entries(self, base=361):
        for i in range(64):
            b = self.sec(base + i // 8)
            e = b[(i % 8) * 16:(i % 8) * 16 + 16]
            if len(e) < 16 or e[0] == 0:
                return
            yield i, e

    @staticmethod
    def name(e):
        n, x = e[5:13].decode('latin-1').rstrip(), e[13:16].decode('latin-1').rstrip()
        return n + ('.' + x if x else '')

    def chain(self, e):
        """[(sector, data, file number or None)] of a file, by its links."""
        out, s, seen = [], e[3] | e[4] << 8, set()
        long = e[0] & 0x04
        while s and s not in seen and len(out) < self.nsec:
            seen.add(s)
            b = self.sec(s)
            d = self.dbytes
            out.append((s, bytes(b[:b[d + 2]]), None if long else b[d] >> 2))
            s = (b[d] << 8 | b[d + 1]) if long else ((b[d] & 3) << 8 | b[d + 1])
        return out

    def files(self, base=361):
        for i, e in self.entries(base):
            if e[0] & 0x40 and not e[0] & 0x80 and not e[0] & 0x10:
                yield i, e

    def dirs(self, base=361):
        for i, e in self.entries(base):
            if e[0] & 0x10 and not e[0] & 0x80:
                yield i, e

    def walk(self, base=361, path=''):
        """(path, entry number, entry) of every file, subdirectories too."""
        for i, e in self.files(base):
            yield path + self.name(e), i, e
        for i, e in self.dirs(base):
            yield from self.walk(e[3] | e[4] << 8, path + self.name(e) + '/')

    def check(self):
        errs = []
        used = {}
        for _, _, e in self.walk():
            pass
        for d, i, e in [(p, i, e) for p, i, e in self.walk()]:
            n = d
            ch = self.chain(e)
            if len(ch) != (e[1] | e[2] << 8):
                errs.append('%s: %d sectors, entry says %d' % (n, len(ch), e[1] | e[2] << 8))
            for s, d, fn in ch:
                if fn is not None and fn != i:
                    errs.append('%s: sector %d has file number %d, not %d' % (n, s, fn, i))
                if s in used:
                    errs.append('%s: sector %d also in %s' % (n, s, used[s]))
                used[s] = n
                if self.isfree(s):
                    errs.append('%s: sector %d marked free' % (n, s))
            for s, d, fn in ch[:-1]:
                if len(d) != self.dbytes:
                    errs.append('%s: sector %d holds %d bytes before the end' % (n, s, len(d)))
        def dirsecs(base=361):
            for i, e in self.dirs(base):
                b0 = e[3] | e[4] << 8
                for s in range(b0, b0 + 8):
                    used[s] = 'directory ' + self.name(e)
                yield from [b0]
                yield from dirsecs(b0)
        list(dirsecs())
        top = 1024 if self.ed else min(self.nsec + 1, 8 * (self.vpages * self.seclen - 10))
        free = [s for s in range(1, top) if self.isfree(s)]
        lo = sum(1 for s in free if s < 720 or not self.ed)
        hi = sum(1 for s in free if s >= 720)
        if lo != self.free:
            errs.append('VTOC free %d, bitmap %d' % (self.free, lo))
        if self.ed:
            v2 = self.sec(1024)
            if v2[122] | v2[123] << 8 != hi:
                errs.append('VTOC2 free %d, bitmap %d' % (v2[122] | v2[123] << 8, hi))
            v = self.sec(360)
            for s in range(48, 720):
                if ((v[10 + s // 8] >> (7 - s % 8)) & 1) != ((v2[(s - 48) // 8] >> (7 - (s - 48) % 8)) & 1):
                    errs.append('VTOC and VTOC2 differ at sector %d' % s)
                    break
        for s in range(1, top):
            if s in used or s in self.vsecs or 361 <= s <= 368 or s <= 3 or s == 1024:
                continue
            if not self.isfree(s) and s not in used and s != 720:
                errs.append('sector %d used by nothing' % s)
                break
        return errs


def build(path, nsec, seclen, files, name_order=None):
    """A MyDOS image (format as read above) of nsec sectors of seclen bytes
    (sectors 1-3 always 128). files maps 'DIR/NAME.EXT' to bytes; a
    directory is made for each DIR. Files get 16-bit links ($46) when the
    disk has sectors past 1023, else DOS 2 links with file numbers ($42).
    Sectors are allocated lowest first, as MyDOS does."""
    nbytes = 10 + (nsec + 8) // 8
    pages = -(-nbytes // 256)
    code = 2 if nsec < 1024 and pages == 1 else pages + 2
    vsecs = [360] if code == 2 else [360 - i for i in range((code - 2) * (256 // seclen))]
    long = nsec >= 1024
    dbytes = seclen - 3
    img = {}
    used = set([0] + list(range(1, 4)) + vsecs + list(range(361, 369)))

    def alloc(n=1):
        """n consecutive free sectors, lowest first."""
        s = 1
        while any(x in used for x in range(s, s + n)) or s + n - 1 > nsec:
            s += 1
            if s > nsec:
                raise ValueError('disk full')
        used.update(range(s, s + n))
        return s

    def name83(n):
        b_, _, e = n.partition('.')
        return b_.ljust(8).encode()[:8] + e.ljust(3).encode()[:3]

    tree = {'': []}
    for p_, d in files.items():
        parts = p_.split('/')
        for i in range(1, len(parts)):
            dd = '/'.join(parts[:i])
            if dd not in tree:
                tree[dd] = []
                tree['/'.join(parts[:i - 1])].append((parts[i - 1], None))
        tree['/'.join(parts[:-1])].append((parts[-1], d))

    def mkdir(d, base):
        ents = []
        for i, (n, data) in enumerate(tree[d]):
            if data is None:
                sub = alloc(8)
                mkdir((d + '/' + n) if d else n, sub)
                ents.append(bytes([0x10, 8, 0]) + struct.pack('<H', sub) + name83(n))
                continue
            secs = [alloc() for _ in range(max(1, -(-len(data) // dbytes)))]
            for k, sec in enumerate(secs):
                chunk = data[k * dbytes:(k + 1) * dbytes]
                nxt = secs[k + 1] if k + 1 < len(secs) else 0
                link = bytes([nxt >> 8, nxt & 0xFF]) if long else bytes([i << 2 | nxt >> 8, nxt & 0xFF])
                img[sec] = chunk.ljust(dbytes, b'\0') + link + bytes([len(chunk)])
            ents.append(bytes([0x46 if long else 0x42, len(secs) & 0xFF, len(secs) >> 8]) +
                        struct.pack('<H', secs[0]) + name83(n))
        body = b''.join(ents).ljust(8 * 128, b'\0')
        for k in range(8):
            img[base + k] = body[k * 128:(k + 1) * 128]

    mkdir('', 361)
    total = nsec - len([s for s in used if s and s <= 368 or s in vsecs]) + 0
    total = sum(1 for s in range(1, nsec + 1) if s not in vsecs and not 361 <= s <= 368 and s > 3)
    free = sum(1 for s in range(1, nsec + 1) if s not in used)
    v = bytearray(len(vsecs) * seclen)
    v[0], v[1], v[2], v[3], v[4] = code, total & 0xFF, total >> 8, free & 0xFF, free >> 8
    for sec in range(nsec + 1):
        if sec not in used:
            v[10 + sec // 8] |= 0x80 >> (sec % 8)
    for k, sec in enumerate(vsecs):
        img[sec] = bytes(v[k * seclen:(k + 1) * seclen])
    out = bytearray(16 + 384 + (nsec - 3) * seclen if seclen == 256 else 16 + nsec * 128)
    paras = (len(out) - 16) // 16
    out[0:16] = struct.pack('<HHHB', 0x0296, paras & 0xFFFF, seclen, paras >> 16) + bytes(9)
    for sec, data in img.items():
        if sec <= 3 or seclen == 128:
            o = 16 + (sec - 1) * 128
        else:
            o = 16 + 384 + (sec - 4) * seclen
        out[o:o + len(data)] = data
    Path(path).write_bytes(out)


def main():
    cmd, img = sys.argv[1], sys.argv[2]
    d = Dos2(img)
    if cmd == 'ls':
        print('%s: DOS 2 (code %d), %d x %d, total %d, free %d%s' % (
            img, d.code, d.nsec, d.seclen, d.total, d.free, ', ED' if d.ed else ''))
        for p, i, e in d.walk():
            print('%02X %4d %-20s %d bytes' % (e[0], e[1] | e[2] << 8, p,
                                               sum(len(x) for _, x, _ in d.chain(e))))
    elif cmd == 'check':
        errs = d.check()
        print('\n'.join(errs) or 'ok')
        sys.exit(1 if errs else 0)
    elif cmd == 'extract':
        out = Path(sys.argv[3])
        out.mkdir(parents=True, exist_ok=True)
        for p, i, e in d.walk():
            (out / p).parent.mkdir(parents=True, exist_ok=True)
            (out / p).write_bytes(b''.join(x for _, x, _ in d.chain(e)))


if __name__ == '__main__':
    main()
