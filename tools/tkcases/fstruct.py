"""FSTRUCT: Atari binaries (segments with and without a header, run and
init addresses alone and together, a $FFFA block, a segment cut short),
a SpartaDOS X relocatable file from the Toolkit and made up ones with each
kind of block, a text file (152), an empty file, a missing file. Each case
fits on the screen."""
from tk_test import case, TKX


def w(*v):
    return b''.join(bytes([x & 255, x >> 8]) for x in v)


def seg(a, data, head=True):
    return (w(0xFFFF) if head else b'') + w(a, a + len(data) - 1) + bytes(data)


BIN1 = (seg(0x2000, range(4)) + seg(0x3000, b'xy', head=False) + seg(0x2E2, w(0x2000)) +
        seg(0x2E0, w(0x2003)))
BIN2 = (seg(0x600, b'\xa9\x00\x60') + seg(0x2E0, w(0x600, 0x601)) + w(0xFFFA) +
        w(0x4000, 0x4001) + b'zz')
CUT = seg(0x2000, range(8))[:-3]
# SpartaDOS X relocatable blocks: $FFFE with data and without (BSS), fixups
# with an address after $FD (an $FC in it), a symbol's references, a symbol defined, $FFF9
# with the address 0 and not 0, fixups that the file's end cuts short
REL1 = (w(0xFFFE) + bytes([1, 0]) + w(0, 5) + b'ABCDE' +
        w(0xFFFE) + bytes([2, 0x80]) + w(5, 0x100) +
        w(0xFFFD) + bytes([1, 0x10, 0, 0xFD, 0xFC, 0x12, 3, 0xFC]) +
        w(0xFFFB) + b'PRINTF  ' + w(2) + bytes([1, 0xFC]))
REL2 = (w(0xFFFC) + bytes([1]) + w(2) + b'MYSYM   ' + w(0xFFF9) + bytes([3, 0x80]) + w(0, 0x40) +
        w(0xFFF9) + bytes([4, 0x80]) + w(0x1234, 0x20) + w(0xFFFD) + bytes([1, 1, 2]))
ORIG = 'UTILS/FILEUTIL/FSTRUCT/FSTRUCT.COM'


def files():
    return {'BIN1': BIN1, 'BIN2': BIN2, 'CUT': CUT, 'ODD': w(0xFFFF) + b'\x00',
            'REL1': REL1, 'REL2': REL2,
            'FOX': b'The quick brown fox jumps over the lazy dog',
            'CRC.DLL': (TKX / 'UTILS/FILEUTIL/CRC32/CRC32.DLL').read_bytes()}


CASES = {
    'fstruct': case(ORIG, ['FSTRUCT BIN1'], files=files()),
    'fstruct2': case(ORIG, ['FSTRUCT CUT', 'FSTRUCT ODD', 'FSTRUCT FOX', 'FSTRUCT NOPE'],
                     files=files()),
    # (apart from fstruct2: the error lines with their blank lines fill the screen)
    'fstruct2b': case(ORIG, ['TYPE NUL: >>E0', 'FSTRUCT E0', 'FSTRUCT'], files=files()),
    'fstruct3': case(ORIG, ['FSTRUCT BIN2'], files=files()),
    'fstruct4': case(ORIG, ['FSTRUCT CRC.DLL'], files=files()),
    'fstruct5': case(ORIG, ['FSTRUCT REL1'], files=files()),
    'fstruct6': case(ORIG, ['FSTRUCT REL2'], files=files()),
}
