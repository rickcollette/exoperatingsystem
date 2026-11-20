"""CRC32: files of 1 byte to several sectors, decimal and /H hex, a wildcard
(the first match), lists ended by a /, a missing file, a bad option, the
usage line; the results checked against zlib too (check())."""
import zlib

from tk_test import case


def pat(n, m=7, a=3):
    return bytes((i * m + a) & 255 for i in range(n))


def rnd(n, seed=12345):
    out, x = bytearray(), seed
    for _ in range(n):
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF
        out.append(x >> 16 & 255)
    return bytes(out)


FILES = {
    'ONE': b'a', 'ABC': b'abc', 'B55': pat(55), 'B64': pat(64), 'B256': bytes(range(256)),
    'BIG': rnd(3000), 'FOX': b'The quick brown fox jumps over the lazy dog',
}
DLL = {'CRC32.DLL': 'UTILS/FILEUTIL/CRC32/CRC32.DLL'}


def files():
    from tk_test import TKX
    f = dict(FILES)
    for n, p in DLL.items():
        f[n] = (TKX / p).read_bytes()      # the original loads it
    return f


def check():
    """The decimal lines of case crc32 as zlib computes them."""
    return ['%d %d %s' % (zlib.crc32(FILES[n]), len(FILES[n]), n)
            for n in ('ONE', 'ABC', 'B55', 'B64', 'B256', 'BIG', 'FOX')]


CASES = {
    'crc32': case('UTILS/FILEUTIL/CRC32/CRC32.COM',
                  ['CRC32 ONE ABC B55 B64', 'CRC32 B256,BIG FOX', 'CRC32 /H ONE D1:BIG',
                   'crc32 /h fox', 'CRC32 B*', 'CRC32', 'CRC32 /H'],
                  files=files()),
    'crc32b': case('UTILS/FILEUTIL/CRC32/CRC32.COM',
                   ['CRC32 ONE /X ABC', 'CRC32 /H ONE /H ABC',
                    'CRC32 ONE NOPE ABC', 'CRC32 /X ONE', 'CRC32 >>OUT ABC FOX', 'TYPE OUT',
                    'TYPE NUL: >>E0', 'CRC32 E0'],
                   files=files()),
}

if __name__ == '__main__':
    print('\n'.join(check()))
