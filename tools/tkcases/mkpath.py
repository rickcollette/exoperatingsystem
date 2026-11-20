"""MKPATH: the usage line (also with options only), a new path, the same
again (151) and with /F, /V and /VV, /F with /V and /VV, .. in the path,
a drive and the main directory, a name in the way that is a file, a bad
option; CD and PWD show what was made."""
from tk_test import case

M = 'UTILS/SHELLUTL/MKPATH/MKPATH.COM'
CASES = {
    'mkpath': case(M, ['MKPATH', 'MKPATH /V', 'MKPATH A>B>C', 'CD A>B>C', 'PWD', 'CD >',
                       'MKPATH A>B>C', 'MKPATH /F A>B>D', 'CD A>B>D', 'PWD', 'CD >',
                       'MKPATH /V X>Y', 'MKPATH /VV P>Q>R', 'MKPATH /VF A>B>E', 'MKPATH /FVV A>B>F',
                       'CD A>B>F', 'PWD', 'CD >']),
    'mkpath-2': case(M, ['MKPATH M>..>N', 'CD N', 'PWD', 'CD >', 'CD M', 'PWD', 'CD >',
                         'MKPATH /VV D1:>S>T', 'CD S>T', 'PWD', 'CD >', 'MKPATH >', 'MKPATH /V D1:',
                         'mkpath /vv low>er', 'MKPATH A.TXT>V', 'MKPATH /X Q', 'MKPATH /F A.TXT',
                         'ECHO end'],
                     files={'A.TXT': b'alpha\x9b'}),
}
