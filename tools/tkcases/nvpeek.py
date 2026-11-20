"""NVPEEK: no clock driver (the program does not load), then with a stand-in
driver (NVFAKE.COM, built here: I_NVRAM over 64 bytes of page 6, an
error above): the usage line, reads, writes, an address out of range.
The original's usage line names its authors; EOS's does not.
NVWGL: only without a driver (its screen needs keys: see the report)."""
import struct

from tk_test import case


def nvfake(base=0x0680):
    c = bytearray(); refs = {}
    def ref(sym, off): refs.setdefault(sym, []).append(base + len(c) + off)
    c += b'\xa2\x07'                                   # ldx #7
    l1 = len(c)
    nm_at = len(c) + 1; c += b'\xbd\x00\x00'           # lda name,x
    ref('SYMBOL', 1); c += b'\x9d\x02\x00'             # sta SYMBOL+2,x
    c += b'\xca\x10' + bytes([(l1 - (len(c) + 3)) & 0xFF])  # dex, bpl l1
    nv_lo = len(c) + 1; c += b'\xa9\x00'               # lda #<nv
    ref('SYMBOL', 1); c += b'\x8d\x0b\x00'             # sta SYMBOL+$0B
    nv_hi = len(c) + 1; c += b'\xa9\x00'               # lda #>nv
    ref('SYMBOL', 1); c += b'\x8d\x0c\x00'             # sta SYMBOL+$0C
    ref('S_ADD', 1); c += b'\x20\x00\x00'              # jsr S_ADD
    c += b'\xa9\xff'; ref('INSTALL', 1); c += b'\x8d\x00\x00'  # lda #$FF, sta INSTALL
    c += b'\x60'
    nv = base + len(c)
    c[nv_lo] = nv & 0xFF; c[nv_hi] = nv >> 8
    c += b'\xb0\x09\xe0\x40\xb0\x0d'                   # bcs wr, cpx #$40, bcs ret
    mr = len(c) + 1; c += b'\xbd\x00\x00\x18\x60'      # lda mem,x, clc, rts
    c += b'\xe0\x40\xb0\x04'                           # wr: cpx #$40, bcs ret
    mw = len(c) + 1; c += b'\x9d\x00\x00\x18'          # sta mem,x, clc
    c += b'\x60'                                       # ret: rts
    name = base + len(c); c += b'I_NVRAM '
    mem = base + len(c); c += bytes(range(0x40, 0x80))
    for at, v in ((nm_at, name), (mw, mem), (mr, mem)):
        c[at:at + 2] = struct.pack('<H', v)
    out = b'\xfa\xff' + struct.pack('<HH', base, base + len(c) - 1) + bytes(c)
    for sym, ads in refs.items():
        data = b''.join(b'\xfd' + struct.pack('<H', a) for a in ads) + b'\xfc'
        out += b'\xfb\xff' + sym.ljust(8).encode() + struct.pack('<H', len(data)) + data
    return out, nv


def credit(lines):
    return [x.replace(' by DLT', '') for x in lines]


CASES = {
    'nvpeek': case('UTILS/SYSUTIL/NVRAM/NVPEEK.COM',
                   ['NVPEEK 1', 'NVFAKE', 'NVPEEK', 'NVPEEK 5', 'NVPEEK 6 $41', 'NVPEEK 6',
                    'NVPEEK 64', 'NVPEEK 64 1', 'NVPEEK 3 300', 'NVPEEK 3', 'NVPEEK X'],
                   files={'NVFAKE.COM': nvfake()[0]}, norm=credit),
    'nvwgl': case('UTILS/SYSUTIL/NVRAM/NVWGL.COM', ['NVWGL']),
}
