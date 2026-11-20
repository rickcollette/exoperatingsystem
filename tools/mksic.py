#!/usr/bin/env python3
"""Build EOS cartridge images for SIC! (512 KiB, CAR type 56) and SIC!+
(1024 KiB, CAR type 83) from 8 KiB bank images assembled with -D:SIC=1.

SIC! maps 16 KiB banks: $A000-$BFFF shows the upper 8 KiB of the bank
selected by the value written to $D500 (bits 0-4; SIC!+ bit 7: the second
flash chip). EOS's bank n goes into the upper half of SIC! bank n; the
lower halves ($8000-$9FFF, which EOS keeps off) and the unused banks are
erased flash ($FF) with the reset tail in their upper halves, so a reset in
any bank still starts EOS.

usage: mksic.py out.car 512|1024 bank0.bin [bank1.bin ...]
"""
from pathlib import Path
import struct
import sys

BANK = 0x2000
TAIL = 16
TYPES = {512: 56, 1024: 83}


def build(size_k, paths):
    banks = []
    for path in paths:
        raw = Path(path).read_bytes()
        if not raw or len(raw) % BANK:
            raise ValueError(f"{path}: size {len(raw)} is not a nonzero multiple of {BANK}")
        banks.extend(raw[i:i + BANK] for i in range(0, len(raw), BANK))
    sic_banks = size_k // 16
    usable = min(sic_banks, 32)          # bits 0-4 address one flash chip
    if len(banks) > usable:
        raise ValueError(f"EOS uses {len(banks)} banks; SIC! has {usable} upper halves")
    tail = banks[0][-TAIL:]
    if any(b[-TAIL:] != tail for b in banks):
        raise ValueError("bank tails differ")
    erased = b"\xff" * BANK
    upper_erased = b"\xff" * (BANK - TAIL) + tail
    image = bytearray()
    for n in range(sic_banks):
        image += erased + (banks[n] if n < len(banks) else upper_erased)
    return bytes(image)


def main():
    if len(sys.argv) < 4 or sys.argv[2] not in ('512', '1024'):
        sys.exit(__doc__.split("usage:", 1)[1].strip())
    out, size, *inputs = sys.argv[1:]
    size = int(size)
    try:
        data = build(size, inputs)
    except (OSError, ValueError) as exc:
        sys.exit(f"mksic: {exc}")
    header = b"CART" + struct.pack(">II", TYPES[size], sum(data) & 0xFFFFFFFF) + bytes(4)
    Path(out).write_bytes(header + data)
    print(f"mksic: {len(data) // 1024} KiB, CAR type {TYPES[size]}, {len(inputs)} inputs")


if __name__ == "__main__":
    main()
