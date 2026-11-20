"""DIRNAME (no SDX original): the device and directory part of SDX paths
(D1:>DIR>FILE, D1:DIR>FILE, devices, backslashes, < for the parent, a >
at the end, the main directory), the errors. The expected lines come
from a model of Unix dirname with SDX's separators: the separator after a
device or a lone > stays (blank lines are not seen; a line "D1:" would be
taken for the prompt, so D2: and D3: stand for devices alone)."""
from tk_test import case

SEP = ':><\\'
USE = 'Use: dirname path'


def strip(p):
    while len(p) >= 2 and p[-1] in '>\\' and p[-2] not in SEP:
        p = p[:-1]
    return p


def dirname(p):
    p = strip(p.upper())
    return strip(p[:max([i + 1 for i, c in enumerate(p) if c in SEP] + [0])])


ARGS = ['D1:>DIR>FILE.EXT', 'D1:DIR>FILE', 'FILE.TXT', 'D2:FILE', 'CAR:X.COM', 'D1:>DIR>SUB>',
        'A:\\DOS\\CMD.COM', 'D1:<<UP.TXT', 'd2:>low>case.txt', 'D1:>FILE', 'D1:>', 'D3:', '>',
        '>FILE', 'DIR>FILE', 'D1:>A>B>C>D>E>F>G>H>NAME.EXT']

CASES = {
    'dirname': case(None, ['DIRNAME ' + a for a in ARGS], files={}, prog='DIRNAME.COM',
                    want=[x for x in (dirname(a) for a in ARGS) if x]),
    'dirname2': case(None, ['DIRNAME', 'DIRNAME A B', 'DIRNAME D1:>X>Y.Z >>O.TXT', 'TYPE O.TXT'],
                     files={}, prog='DIRNAME.COM', want=[USE, USE, 'D1:>X']),
}
