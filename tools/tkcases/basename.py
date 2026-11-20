"""BASENAME (no SDX original): the name part of SDX paths (D1:>DIR>FILE,
D1:DIR>FILE, devices, backslashes, < for the parent, a > at the end),
a suffix taken off, the errors. The expected lines come from a model of
Unix basename with SDX's separators (blank lines are not seen)."""
from tk_test import case

SEP = ':><\\'
USE = 'Use: basename path [suffix]'


def strip(p):
    while len(p) >= 2 and p[-1] in '>\\' and p[-2] not in SEP:
        p = p[:-1]
    return p


def basename(p, suf=''):
    p = strip(p.upper())
    b = p[max([i + 1 for i, c in enumerate(p) if c in SEP] + [0]):]
    suf = suf.upper()
    if suf and len(b) > len(suf) and b.endswith(suf):
        b = b[:-len(suf)]
    return b


ARGS = [('D1:>DIR>FILE.EXT',), ('D1:DIR>FILE',), ('FILE.TXT',), ('D1:FILE',),
        ('CAR:X.COM',), ('D1:>DIR>SUB>',), ('A:\\DOS\\CMD.COM',), ('D1:<<UP.TXT',),
        ('d2:>low>case.txt',), ('D1:>DIR>FILE.EXT', '.EXT'), ('FILE.TXT', 'TXT'),
        ('FILE.TXT', 'FILE.TXT'), ('FILE.TXT', '.COM'), ('D1:>',), ('D1:',), ('>',),
        ('D1:>A>B>C>D>E>F>G>H>NAME.LONGEREXT',)]

CASES = {
    'basename': case(None, ['BASENAME ' + ' '.join(a) for a in ARGS], files={},
                     prog='BASENAME.COM', want=[x for x in (basename(*a) for a in ARGS) if x]),
    'basename2': case(None, ['BASENAME', 'BASENAME A B C', 'BASENAME D1:>X>Y.Z >>O.TXT',
                             'TYPE O.TXT'], files={}, prog='BASENAME.COM',
                      want=[USE, USE, 'Y.Z']),
}
