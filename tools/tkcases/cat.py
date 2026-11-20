"""CAT (no SDX original): files one after another, -n numbering, wildcards,
standard input with << and output with >>, the errors (a missing file
ends CAT with EOS's message). The expected
screen lines come from the files (Unix cat), wrapped as E: wraps them."""
import emu
from tk_test import case

A = ['one', 'two', 'three']
B = ['Bee line', '', 'after a blank']
LONG = ['L' + 'x' * 128 + 'Z', 'short']
BIG = ['line %d' % i for i in range(1, 401)]
SUB = ['in sub']
FILES = {'A.TXT': emu.atascii(A), 'B.TXT': emu.atascii(B), 'E.TXT': b'',
         'LONG.TXT': emu.atascii(LONG), 'NOEOL.TXT': b'tail', 'BIG.TXT': emu.atascii(BIG),
         'SUB/S.TXT': emu.atascii(SUB), 'SUB/T.DAT': emu.atascii(['dat'])}
USE = 'Use: cat [-n] [filename ...]'


def rows(lines):
    """Text lines as the 38 columns of the screen show them (blank rows dropped)."""
    out = []
    for x in lines:
        for i in range(0, max(len(x), 1), 38):
            if x[i:i + 38].strip():
                out.append(x[i:i + 38].strip())
    return out


def nf(name):
    """EOS's message for a file that is not there (the program ends)."""
    return ['File ' + name, '170 File not found']


def num(lines, start=1):
    return ['%5d %s' % (i, x) for i, x in enumerate(lines, start)]


CASES = {
    'cat': case(None, ['CAT A.TXT', 'CAT A.TXT B.TXT', 'CAT E.TXT', 'CAT -n A.TXT B.TXT',
                       'CAT NOEOL.TXT', 'CAT A.TXT'],
                files=FILES, prog='CAT.COM',
                want=rows(A + A + B + num(A + B) + ['tail' + A[0]] + A[1:])),
    'cat2': case(None, ['CAT ?.TXT', 'CAT SUB>*.*', 'CAT D1:SUB>S.*', 'CAT LONG.TXT',
                        'CAT -n LONG.TXT'],
                 files=FILES, prog='CAT.COM',
                 want=rows(A + B + SUB + ['dat'] + SUB + LONG + num(LONG))),
    'cat3': case(None, ['CAT NOPE.TXT', 'CAT NOPE*.TXT', 'CAT -x A.TXT', 'CAT - A.TXT',
                        'CAT -nn A.TXT', 'CAT A.TXT NOPE.TXT B.TXT'],
                 files=FILES, prog='CAT.COM',
                 want=nf('NOPE.TXT') + nf('NOPE*.TXT') + [USE, USE] + rows(num(A) + A)
                 + nf('NOPE.TXT')),
    'cat4': case(None, ['CAT <<A.TXT', 'CAT -n <<B.TXT', 'CAT <<A.TXT >>C.TXT', 'CAT A.TXT B.TXT >>D.TXT',
                        'CAT C.TXT D.TXT', 'CAT <<E.TXT'],
                 files=FILES, prog='CAT.COM',
                 want=rows(A + num(B) + A + A + B)),
    'cat5': case(None, ['CAT -n BIG.TXT >>OUT.TXT', 'CAT OUT.TXT'], files=FILES, prog='CAT.COM',
                 want=rows(num(BIG))[-22:]),
}
