"""DIRNAME (no SDX original): the device and directory portion of exact-case
native / paths, including roots and trailing slashes."""
from tk_test import case

SEP = ':/'
USE = 'Use: dirname path'


def strip(p):
    while len(p) >= 2 and p[-1] == '/' and p[-2] not in SEP:
        p = p[:-1]
    return p


def dirname(p):
    p = strip(p)
    return strip(p[:max([i + 1 for i, c in enumerate(p) if c in SEP] + [0])])


ARGS = ['D1:/DIR/FILE.EXT', 'D1:DIR/FILE', 'FILE.TXT', 'D2:FILE', 'CAR:X.COM', 'D1:/DIR/SUB/',
        '/usr/bin/cat', 'D1:/../UP.TXT', 'd2:/low/case.txt', 'D1:/FILE', 'D1:/', 'D3:', '/',
        '/FILE', 'DIR/FILE', 'D1:/A/B/C/D/E/F/G/H/Name.Ext']

CASES = {
    'dirname': case(None, ['DIRNAME ' + a for a in ARGS], files={}, prog='DIRNAME.COM',
                    want=[x for x in (dirname(a) for a in ARGS) if x]),
    'dirname2': case(None, ['DIRNAME', 'DIRNAME A B', 'DIRNAME D1:/X/Y.Z >>O.TXT', 'TYPE O.TXT'],
                     files={}, prog='DIRNAME.COM', want=[USE, USE, 'D1:/X']),
}
