"""DU: a tree under a directory with /Q and /QQ, name masks (files only),
attributes (the first directory only), and the errors. The main directory
is scanned with masks only: DU.COM itself differs in size (and the
original has DU.OVL beside it)."""
from tk_test import TKX, case

ORIG = 'UTILS/SHELLUTL/DU/DU.COM'
FILES = {'A.TXT': b'one', 'SUB/B.TXT': b'x', 'SUB/DEEP/C.TXT': b'cc',
         'SUB/DEEP/F.DAT': b'f' * 1536, 'SUB/E.TXT': b'e' * 2000, 'EMPTY/X': b'',
         'DU.OVL': (TKX / 'UTILS/SHELLUTL/DU/DU.OVL').read_bytes()}

CASES = {
    'du': case(ORIG, ['DU SUB>', 'DU /Q SUB>', 'DU /QQ SUB>'], files=FILES),
    'du2': case(ORIG, ['DU SUB', 'DU /QQ A.TXT', 'DU NOPE>'], files=FILES),
    'du3': case(ORIG, ['DU /X', 'DU /QQ NOPE', 'DU /QQ *.TXT'], files=FILES),
    'du4': case(ORIG, ['ATTRIB +H SUB>DEEP', 'ATTRIB +P SUB>B.TXT', 'DU -H SUB>', 'DU +H SUB>',
                       'DU /Q +S SUB>', 'DU /Q +P SUB>'], files=FILES),
    'du5': case(ORIG, ['MKDIR SUB>D2', 'COPY A.TXT SUB>Z.TXT', 'DU D1:SUB>', 'DU /QQ SUB>DEEP>'],
                files=FILES),
    'du6': case(ORIG, ['DU /Q *.DAT', 'DU EMPTY>'], files=FILES),
}
