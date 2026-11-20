#!/usr/bin/env python3
"""Build a raw 320 KiB EOS image for the U1MB SDX ROM slot.

Unlike mkcarx.py, this image has no CART header.  EOS is assembled with
U1MB-specific fixed-register bank selection, then packed in the standard
EOS module order as 8 KiB banks followed by erased flash banks.  U1MB
firmware remains responsible for selecting/configuring its SDX slot.

usage: mku1mb.py out.rom bank0.bin [bank1.bin ...]
"""
from pathlib import Path
import sys

BANK = 0x2000
SLOT_BANKS = 40
TAIL = 16


def build(paths):
    banks = []
    for path in paths:
        raw = Path(path).read_bytes()
        if not raw or len(raw) % BANK:
            raise ValueError(f"{path}: size {len(raw)} is not a nonzero multiple of {BANK}")
        banks.extend(raw[i:i + BANK] for i in range(0, len(raw), BANK))
    if not banks:
        raise ValueError("no bank images supplied")
    if len(banks) > SLOT_BANKS:
        raise ValueError(f"EOS uses {len(banks)} banks; U1MB SDX slot holds {SLOT_BANKS}")
    tail = banks[0][-TAIL:]
    if any(bank[-TAIL:] != tail for bank in banks):
        raise ValueError("bank tails differ")
    erased = b"\xff" * (BANK - TAIL) + tail
    return b"".join(banks) + erased * (SLOT_BANKS - len(banks))


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__.split("usage:", 1)[1].strip())
    out, *inputs = sys.argv[1:]
    try:
        image = build(inputs)
    except (OSError, ValueError) as exc:
        sys.exit(f"mku1mb: {exc}")
    Path(out).write_bytes(image)
    print(f"mku1mb: {len(image) // BANK} banks, {len(image)} bytes (raw ROM)")


if __name__ == "__main__":
    main()
