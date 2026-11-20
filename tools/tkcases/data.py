"""DATA: decimal and hex lines (/H /$ /C), no line numbers, line numbers and
step, numbers to a line, the options' numbers in their fixed order, start
and count (0: nothing, any other: up to the end, as on SDX), an empty
file, standard input, a start past the end, a bad
option, a missing file; the lines of a larger file written to a file (the
case data4 leaves them on both disks)."""
from tk_test import case


def pat(n, m=7, a=3):
    return bytes((i * m + a) & 255 for i in range(n))


def rnd(n, seed=12345):
    out, x = bytearray(), seed
    for _ in range(n):
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF
        out.append(x >> 16 & 255)
    return bytes(out)


FILES = {'ABC': b'abc', 'B20': pat(20, 13, 250), 'BIG': rnd(3000), }
ORIG = 'UTILS/FILEUTIL/DATA/DATA.COM'

CASES = {
    'data': case(ORIG, ['DATA ABC', 'DATA B20', 'DATA B20 /H', 'DATA B20 /H$', 'DATA B20 /HC',
                        'DATA B20 /H$C'], files=FILES),
    'data2': case(ORIG, ['DATA B20 /N', 'DATA B20 /L 100 5', 'DATA B20 /S 4',
                         'DATA B20 /SL 3 1000 10', 'DATA B20 10 5', 'DATA B20 $12',
                         'TYPE NUL: >>E0', 'DATA E0', 'DATA B20 0 0', 'DATA B20 19 1'],
                  files=FILES),
    'data3': case(ORIG, ['DATA NOPE', 'DATA B20 /X', 'DATA <<ABC', 'DATA B20 /HN',
                         'DATA ABC /S 0', 'DATA B20 30'], files=FILES),
    'data5': case(ORIG, ['DATA B20 /L 65534 1', 'DATA b20 /hc', 'DATA ABC 1 /L',
                         'DATA ABC /L 5', 'DATA B20 /C'], files=FILES),
    'data4': case(ORIG, ['DATA BIG >>OUT', 'DATA BIG 100 50 /H$ >>OUT2', 'DATA BIG 2990 /HC',
                         'DATA BIG 2995 99 /NS 2'], files=FILES),
}
