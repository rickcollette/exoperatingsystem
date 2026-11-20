"""DD: skips and counts from a redirected input to the screen and to files
(checked by COMP against the bytes they should hold: no output when the
same), an input that ends before count (136), a skip past the end, a
missing input, numbers in $hex and too large, the usage line. A line
from a TYPE marks the end of each command's output."""
from tk_test import case


def rnd(n, seed=12345):
    out, x = bytearray(), seed
    for _ in range(n):
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF
        out.append(x >> 16 & 255)
    return bytes(out)


FOX = b'The quick brown fox jumps over the lazy dog'
BIG = rnd(3000)
FILES = {'FOX': FOX, 'B256': bytes(range(256)), 'BIG': BIG, 'R20': BIG[10:30],
         'R2K': BIG[1000:], 'ABC': b'abc', 'C': b'c', 'M': b'--\x9b'}


def eof136(lines):
    """EOS names error 136 "End Of File", SDX 4.50 "System error" (it has
    no message of its own for 136): EOS's message table, not DD."""
    return [x.replace('136 End Of File', '136 System error') for x in lines]


def marked(cmds):
    out = []
    for c in cmds:
        out += [c, 'TYPE M']
    return out


CASES = {
    'dd': case('UTILS/FILEUTIL/DD/DD.COM',
               marked(['DD', 'DD 4 10 <<FOX', 'DD 40 <<FOX', 'DD 40 10 <<FOX', 'DD 0 0 <<FOX',
                       'DD X <<FOX', 'DD 4 X <<FOX', 'DD 100 <<FOX', 'DD $10 $3 <<FOX',
                       'DD 4 3 <<NOPE']),
               files=FILES, norm=eof136),
    'dd2': case('UTILS/FILEUTIL/DD/DD.COM',
                marked(['DD 0 300 <<B256 >>OUT', 'COMP OUT B256', 'DD 10 20 <<BIG >>OUT2',
                        'COMP OUT2 R20', 'DD 1000 <<BIG >>OUT3', 'COMP OUT3 R2K',
                        'DD 2 <<ABC >>OUT4', 'COMP OUT4 C', 'DD 0 5 <<NUL:',
                        'DD 5000000000 1 <<FOX', 'DD 1 2 3 <<FOX']),
                files=FILES, norm=eof136),
}
