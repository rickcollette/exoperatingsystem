#!/usr/bin/env python3
"""Pack files into the CAR: device's banks (eos/car.asm).

The banks hold CARDLEN = $1FF0 bytes of data each; the last 16 bytes of
every bank are the cartridge tail (taken from bank 0's image), so a reset
in any bank still starts EOS. Bank BK_CARD begins with 'EOSC', the number
of files (word), then 24 bytes per file: status ($08), the first byte's
offset in its bank (word), length (3 bytes), name length plus 16 exact name
bytes, and the first byte's bank. The data follows, file after file.

usage: mkcarfs.py out.bin bank0.bin first_bank file ...
"""
import struct
import sys
from pathlib import Path

CARDLEN = 0x1FF0
BANK = 0x2000
DATE = (3, 11, 26)          # the files' date and time: fixed, so the image
TIME = (12, 0, 0)           # is the same on every build


def main():
    out, bank0, first, *files = sys.argv[1:]
    first = int(first)
    tail = Path(bank0).read_bytes()[-16:]
    names = []
    for f in files:
        name = Path(f).name.lower().encode()
        if not 1 <= len(name) <= 16:
            sys.exit('mkcarfs: CAR name must be 1-16 bytes: %s' % f)
        names.append(bytes([len(name)]) + name.ljust(16, b'\0'))
    if len(set(names)) != len(names):
        sys.exit('mkcarfs: duplicate exact CAR name')
    dirlen = 6 + 24 * len(files)
    if dirlen > CARDLEN:
        sys.exit('mkcarfs: too many files')
    data = bytearray(dirlen)
    data[0:6] = b'EOSC' + struct.pack('<H', len(files))
    for i, (f, n) in enumerate(zip(files, names)):
        body = Path(f).read_bytes()
        at = len(data)
        bank, off = first + at // CARDLEN, at % CARDLEN
        e = (bytes([0x08]) + struct.pack('<H', off) +
             struct.pack('<I', len(body))[:3] + n + bytes([bank]))
        data[6 + 24 * i:6 + 24 * i + 24] = e
        data += body
    banks = b''
    for i in range(0, len(data), CARDLEN):
        banks += data[i:i + CARDLEN].ljust(CARDLEN, b'\xff') + tail
    Path(out).write_bytes(banks)
    print('mkcarfs: %d files, %d bytes, %d banks' % (len(files), len(data), len(banks) // BANK))


if __name__ == '__main__':
    main()
