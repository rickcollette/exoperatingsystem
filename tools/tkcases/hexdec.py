"""HEXDEC: decimal and $hex numbers, wrapping past 32 bits, and bad ones."""
from tk_test import case

CASES = {
    'hexdec': case('UTILS/SHELLUTL/HEXDEC/HEXDEC.COM',
                   ['HEXDEC 255', 'HEXDEC $FF', 'HEXDEC 0', 'HEXDEC 4294967295', 'HEXDEC $FFFFFFFF',
                    'HEXDEC $1A2B3C', 'HEXDEC 65536', 'HEXDEC', 'HEXDEC 4294967296', 'HEXDEC $100000000',
                    'HEXDEC XYZ', 'HEXDEC $G1', 'HEXDEC 12AB']),
}
