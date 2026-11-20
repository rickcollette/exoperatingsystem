#!/usr/bin/env python3
"""Parse SpartaDOS X binaries (Programming Guide chapter 2).

blocks(data) yields (kind, fields, payload) for $FFFF/$FFFA absolute
segments, $FFFE relocatable/BSS blocks, $FFFD fix-ups, $FFFB symbol
references and $FFFC symbol definitions.

usage: sdxbin.py file            list blocks
       sdxbin.py --weak in out   mark every symbol reference weak
"""
import struct
import sys


def fixlen(d, i, size):
    """Length of fix-up data at i: size, or up to and including the $FC end."""
    if size:
        return size
    j = i
    while d[j] != 0xFC:
        j += 3 if d[j] == 0xFD else 2 if d[j] == 0xFE else 1
    return j + 1 - i


def blocks(d):
    """$FFF9 (65816 extension, Programming Guide 19.1.3) is not decoded yet."""
    i = 0
    last = 0xFFFF
    while i + 1 < len(d):
        sig = d[i] | d[i + 1] << 8
        if sig in (0xFFFF, 0xFFFA) or sig < 0xFFF9:
            # after an absolute segment the next one may omit its signature
            j = i if sig < 0xFFF9 else i + 2
            if sig == 0xFFFF and d[j] | d[j + 1] << 8 == 0xFFFF:
                j += 2
            sig = last = sig if sig >= 0xFFF9 else last
            start, end = struct.unpack_from('<HH', d, j)
            yield 'abs', dict(sig=sig, start=start, end=end, at=i), d[j + 4:j + 5 + end - start]
            i = j + 5 + end - start
        elif sig == 0xFFFE:
            num, ctl, off, size = struct.unpack_from('<BBHH', d, i + 2)
            n = 0 if ctl & 0x80 else size
            yield 'reloc', dict(num=num, ctl=ctl, off=off, size=size, at=i), d[i + 8:i + 8 + n]
            i += 8 + n
        elif sig == 0xFFFD:
            num, size = struct.unpack_from('<BH', d, i + 2)
            size = fixlen(d, i + 5, size)
            yield 'fixup', dict(num=num, size=size, at=i), d[i + 5:i + 5 + size]
            i += 5 + size
        elif sig == 0xFFFB:
            name = d[i + 2:i + 10]
            size = fixlen(d, i + 12, struct.unpack_from('<H', d, i + 10)[0])
            yield 'xref', dict(name=bytes(b & 0x7F for b in name).decode('latin1').rstrip(),
                               weak=bool(name[7] & 0x80), size=size, at=i), d[i + 12:i + 12 + size]
            i += 12 + size
        elif sig == 0xFFFC:
            num, off = struct.unpack_from('<BH', d, i + 2)
            yield 'xdef', dict(num=num, off=off, name=d[i + 5:i + 13].decode('latin1').rstrip(),
                               at=i), b''
            i += 13
        else:
            raise ValueError('unknown block signature $%04X at %d' % (sig, i))


def weaken(d):
    d = bytearray(d)
    for kind, f, _ in blocks(bytes(d)):
        if kind == 'xref':
            d[f['at'] + 9] |= 0x80
    return bytes(d)


def main():
    if sys.argv[1] == '--weak':
        open(sys.argv[3], 'wb').write(weaken(open(sys.argv[2], 'rb').read()))
        return
    for kind, f, p in blocks(open(sys.argv[1], 'rb').read()):
        print(kind, {k: v for k, v in f.items() if k != 'at'}, len(p))


if __name__ == '__main__':
    main()
