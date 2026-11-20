"""CDD: no parameter, a directory with and without a drive, back to the
main directory, a directory that is not there and a file. (Once in SUB the
program is run as D1:>CDD: the command processor looks for it in the
current directory.)"""
from tk_test import case

CASES = {
    'cdd': case('UTILS/SHELLUTL/CDD/CDD.COM',
                ['CDD', 'PWD', 'CDD SUB', 'PWD', 'D1:>CDD D1:>', 'PWD', 'CDD D1:SUB', 'PWD',
                 'D1:>CDD >', 'PWD', 'CDD SUB>', 'PWD', 'D1:>CDD ..', 'PWD', 'CDD NOPE', 'PWD',
                 'CDD A.TXT', 'PWD', 'CD >'],
                files={'A.TXT': b'alpha\x9b', 'SUB/IN.TXT': b'inner\x9b'}),
}
