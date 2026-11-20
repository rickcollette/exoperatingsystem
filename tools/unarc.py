#!/usr/bin/env python3
"""Unpack SEA ARC archives (the format of SpartaDOS X Toolkit .ARC files).

Supports methods 2 (stored), 3 (packed), 4 (squeezed) and 8 (crunched),
which is everything on the SDX 4.5 Toolkit disk. Every member is checked
against its CRC-16.

usage: unarc.py archive.arc [destdir]      (no destdir: list members)
"""
import os
import struct
import sys


def crc16(data):
    crc = 0
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc


def unrle(data):
    """ARC run length decoding: $90 n repeats the previous byte n-1 times."""
    out = bytearray()
    i = 0
    while i < len(data):
        b = data[i]
        i += 1
        if b != 0x90:
            out.append(b)
            continue
        n = data[i]
        i += 1
        if n == 0:
            out.append(0x90)
        else:
            out += out[-1:] * (n - 1)
    return bytes(out)


def unsqueeze(data):
    count, = struct.unpack_from('<H', data)
    nodes = [struct.unpack_from('<hh', data, 2 + 4 * k) for k in range(count)]
    pos = (2 + 4 * count) * 8
    out = bytearray()
    while pos < len(data) * 8:
        node = 0
        while node >= 0:
            bit = data[pos >> 3] >> (pos & 7) & 1
            pos += 1
            node = nodes[node][bit]
        if node == -257:            # EOF
            break
        out.append(-node - 1)
    return bytes(out)


def uncrunch(data):
    """Dynamic LZW, 9..max bits, code 256 clears (compress 4.0 bit packing)."""
    maxbits = data[0]
    data = data[1:]
    bits, pos = 9, 0
    table = [bytes([k]) for k in range(256)] + [b'']
    out = bytearray()
    prev = None
    block_end = 0
    while True:
        # codes come in blocks of 'bits' bytes (8 codes); a size change or a
        # clear discards the rest of the current block
        if pos + bits > len(data) * 8:
            break
        code = int.from_bytes(data[pos >> 3:(pos >> 3) + 3], 'little') >> (pos & 7) & ((1 << bits) - 1)
        pos += bits
        if code == 256:
            table = table[:257]
            prev = None
            pos = block_end + ((pos - block_end + bits * 8 - 1) // (bits * 8)) * bits * 8
            bits = 9
            block_end = pos
            continue
        if code < len(table):
            entry = table[code]
            if prev is not None:
                table.append(prev + entry[:1])
        elif prev is not None and code == len(table):
            entry = prev + prev[:1]
            table.append(entry)
        else:
            raise ValueError('bad LZW code %d' % code)
        out += entry
        prev = entry
        if len(table) >= 1 << bits and bits < maxbits:
            pos = block_end + ((pos - block_end + bits * 8 - 1) // (bits * 8)) * bits * 8
            bits += 1
            block_end = pos
    return unrle(bytes(out))


METHODS = {2: lambda d: d, 3: unrle, 4: lambda d: unrle(unsqueeze(d)), 8: uncrunch}


def members(arc):
    i = 0
    while i < len(arc) and arc[i] == 0x1A and arc[i + 1]:
        method = arc[i + 1]
        name = arc[i + 2:i + 15].split(b'\0')[0].decode('ascii')
        size, _date, _time, crc, length = struct.unpack_from('<IHHHI', arc, i + 15)
        packed = arc[i + 29:i + 29 + size]
        i += 29 + size
        if method not in METHODS:
            raise ValueError('%s: unsupported method %d' % (name, method))
        data = METHODS[method](packed)[:length]
        if len(data) != length or crc16(data) != crc:
            raise ValueError('%s: CRC or length mismatch' % name)
        yield name, data


def main():
    arc = open(sys.argv[1], 'rb').read()
    dest = sys.argv[2] if len(sys.argv) > 2 else None
    for name, data in members(arc):
        print('%8d  %s' % (len(data), name))
        if dest:
            os.makedirs(dest, exist_ok=True)
            open(os.path.join(dest, name), 'wb').write(data)


if __name__ == '__main__':
    main()
