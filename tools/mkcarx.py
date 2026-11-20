#!/usr/bin/env python3
"""Build an AtariMax 1 MB (CAR type 42) image from 8K bank images.

Banks not given are filled with the tail of bank 0 (its last 16 bytes: the
reset entry and the cartridge trailer, eos/tail.icl), so the cartridge
starts whichever bank the hardware selects at power-up.

usage: mkcarx.py out.car bank0.bin [bank1.bin ...]  (a file may hold several banks)
"""
import struct
import sys

CAR_TYPE = 42
BANKS = 128
BANK = 8 * 1024
TAIL = 16


def main():
    out, *banks = sys.argv[1:]
    images = []
    for path in banks:
        data = open(path, 'rb').read()
        if not data or len(data) % BANK:
            sys.exit('mkcarx: %s is %d bytes, not a multiple of %d' % (path, len(data), BANK))
        images += [data[i:i + BANK] for i in range(0, len(data), BANK)]
    tail = images[0][-TAIL:]
    for b in images[1:]:
        if b[-TAIL:] != tail:
            sys.exit('mkcarx: bank tails differ')
    blank = b'\xff' * (BANK - TAIL) + tail
    data = b''.join(images) + blank * (BANKS - len(images))
    header = b'CART' + struct.pack('>II', CAR_TYPE, sum(data) & 0xFFFFFFFF) + bytes(4)
    open(out, 'wb').write(header + data)


if __name__ == '__main__':
    main()
