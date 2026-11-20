"""WC: the three counts and each option alone or together, words split by
blanks and EOLs only (not tabs), a last line without an EOL, paths,
wildcards (the first match), and the errors. Left out: an empty file
(SDX reads the test disk's empty files with error 139), standard input
(EOS has no pipes) and /W/C written together (SDX: 156, EOS's U_SLASH
takes it)."""
from tk_test import case

ORIG = 'UTILS/FILEUTIL/WC/WC.COM'
FILES = {'A.TXT': b'one two  three\x9bfour\x9b\x9b five', 'T.TXT': b'a\x7fb c\x9b',
         'S.TXT': b'   \x9b \x9bword', 'SUB/S.TXT': b'x y\x9b'}

CASES = {
    'wc': case(ORIG, ['WC A.TXT', 'WC /W A.TXT', 'WC /L a.txt', 'WC /C A.TXT', 'WC /LW A.TXT',
                      'WC /W /C A.TXT', 'WC /WW A.TXT'], files=FILES),
    'wc2': case(ORIG, ['WC T.TXT', 'WC S.TXT', 'WC SUB>S.TXT', 'WC D1:SUB>S.TXT', 'WC *.TXT',
                       'WC A.TXT /W'], files=FILES),
    'wc3': case(ORIG, ['WC NOPE.TXT', 'WC /X A.TXT', 'WC NOPE>X.TXT', 'WC SUB>'], files=FILES),
}
