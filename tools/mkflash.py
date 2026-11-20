#!/usr/bin/env python3
"""Flash images for cartridges whose flash EOS's banks sit in as they are:
SIDE, SIDE2 and MyIDE II (512 KiB, EOS's bank n at n x 8K) and SIDE3
(8 MiB, EOS's bank n at $780000 + n x 8K, where the SIDE3 starts with its
SDX switch on). The rest of the flash is erased ($FF). The raw file is what
the cartridge's own flasher writes and what Altirra takes as the device's
firmware.

usage: mkflash.py out.rom side|side2|myide2|side3 bank0.bin [bank1.bin ...]
"""
import sys
from pathlib import Path

BANK = 0x2000
LAYOUT = {'side': (0x80000, 0), 'side2': (0x80000, 0), 'myide2': (0x80000, 0),
          'side3': (0x800000, 0x780000)}


def build(kind, paths):
    size, base = LAYOUT[kind]
    banks = []
    for p in paths:
        raw = Path(p).read_bytes()
        if not raw or len(raw) % BANK:
            raise ValueError(f'{p}: size {len(raw)} is not a nonzero multiple of {BANK}')
        banks += [raw[i:i + BANK] for i in range(0, len(raw), BANK)]
    if base + len(banks) * BANK > size:
        raise ValueError(f'EOS uses {len(banks)} banks: more than the flash holds')
    img = bytearray(b'\xff' * size)
    for i, b in enumerate(banks):
        img[base + i * BANK:base + (i + 1) * BANK] = b
    return bytes(img), len(banks)


def main():
    if len(sys.argv) < 4 or sys.argv[2] not in LAYOUT:
        sys.exit(__doc__.split('usage:', 1)[1].strip())
    try:
        img, n = build(sys.argv[2], sys.argv[3:])
    except (OSError, ValueError) as e:
        sys.exit('mkflash: %s' % e)
    Path(sys.argv[1]).write_bytes(img)
    print('mkflash: %s, %d banks, %d KiB' % (sys.argv[2], n, len(img) // 1024))


if __name__ == '__main__':
    main()
