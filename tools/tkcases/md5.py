"""MD5: files around the block and padding sizes (0, 1, 3, 55, 56, 63, 64,
65, 119, 120 bytes, several sectors), /H, the usage lines; /C with a hash
file of MD5's and md5sum's lines (EOL, LF and CR LF ends, lower case hex,
a * before the name, blanks before the line), a wrong hash, lines that are
skipped; a missing file, hash file or option. check() gives the lines of
case md5 as hashlib computes them."""
import hashlib

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
    'ONE': b'a', 'ABC': b'abc', 'B55': pat(55), 'B56': pat(56), 'B63': pat(63), 'B64': pat(64),
    'B65': pat(65), 'B119': pat(119, 3, 1), 'B120': pat(120, 3, 1), 'BIG': rnd(3000),
    'FOX': b'The quick brown fox jumps over the lazy dog',
}


def md5(n):
    return hashlib.md5(FILES[n]).hexdigest().upper()


HASHES = b''.join([
    b'MD5 (ONE) = ' + md5('ONE').encode() + b'\x9b',
    md5('ABC').lower().encode() + b'  ABC\n',
    md5('FOX').encode() + b' *FOX\r\n',
    b'MD5 (B64) = ' + md5('B65').encode() + b'\x9b',
    b'hello world\x9b',
    b'\x9b',
    b'   md5 (BIG) = ' + md5('BIG').lower().encode() + b'\n',
    md5('B55').encode() + b'0 B55\x9b',
    b'MD5 (B56) = ' + md5('B56').encode() + b'F\x9b',
    b'MD5 (B63)=' + md5('B63').encode() + b'\x9b',
    md5('B120').encode() + b'  B120',
])
BAD = b'MD5 (ONE) = ' + md5('ONE').encode() + b'\x9b' + md5('ONE').encode() + b'  NOPE\x9b'
ORIG = 'UTILS/FILEUTIL/MD5/MD5.COM'
ALL = dict(FILES, **{'HASHES.MD5': HASHES, 'BAD.MD5': BAD})


def check():
    return ['MD5 (%s) = %s' % (n, md5(n)) for n in FILES]


CASES = {
    'md5': case(ORIG, ['MD5 ONE ABC', 'MD5 B55,B56', 'MD5 B63 B64', 'MD5 B65', 'md5 fox'],
                files=ALL),
    'md5b': case(ORIG, ['MD5 B119 B120', 'MD5 /H BIG', 'TYPE NUL: >>E0', 'MD5 E0', 'MD5'],
                 files=ALL),
    'md5c': case(ORIG, ['MD5 /C HASHES.MD5', 'MD5 /H /C BAD.MD5'], files=ALL),
    'md5d': case(ORIG, ['MD5 NOPE', 'MD5 ONE NOPE', 'MD5 /C NOPE', 'MD5 /X ONE',
                        'MD5 ONE /X ABC', 'MD5 /C'], files=ALL),
}

if __name__ == '__main__':
    print('\n'.join(check()))
