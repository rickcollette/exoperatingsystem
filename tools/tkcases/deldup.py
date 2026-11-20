"""DELDUP: copies found by size and contents whatever their names, /V,
/R (the disk listed afterwards), files left alone (hidden, protected,
directories), the same directory twice, and the usage."""
from tk_test import case

ORIG = 'UTILS/FILEUTIL/DELDUP/DELDUP.COM'
BIG = bytes(range(256)) * 3 + b'end'
FILES = {'A/X.TXT': b'hello', 'A/Y.TXT': b'world', 'A/Z.DAT': BIG, 'A/W.DAT': b'other',
         'A/SUB/Q.TXT': b'hello', 'A/H.TXT': b'hello',
         'B/X.TXT': b'hello', 'B/YY.TXT': b'world', 'B/Z.DAT': BIG[:-1] + b'x',
         'B/N.DAT': b'', 'B/M.DAT': BIG}

CASES = {
    'deldup': case(ORIG, ['DELDUP', 'DELDUP A>', 'DELDUP A B>', 'DELDUP A> B>*.*'], files=FILES),
    'deldup2': case(ORIG, ['ATTRIB +H A>H.TXT', 'DELDUP A> B>', 'DELDUP A> A>', 'DELDUP A>SUB> A>'],
                    files=FILES),
    'deldup3': case(ORIG, ['DELDUP A> B> /V'], files=FILES),
    'deldup4': case(ORIG, ['DELDUP D1:A> B> /R', 'DIR A>'], files=FILES,
                    norm=lambda ls: [x for x in ls if 'FREE SECTORS' not in x]),
    'deldup5': case(ORIG, ['DELDUP NOPE> B>', 'DELDUP A> B> /X', 'DELDUP B> A>SUB>'], files=FILES),
}
