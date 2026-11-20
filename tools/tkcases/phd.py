"""PHD: the directory saved in _OLDWD (shown with ECHO $_OLDWD), from the
main directory and from a subdirectory, with and without a new directory,
saved twice, a directory that is not there; PLD (the original) goes back.
PLD needs U_GEFINA to take DSKA: (EOS's does not yet: 130); phd-set does
without it (CD, and PHD itself, back to the main directory)."""
from tk_test import case, TKX

PLD = (TKX / 'UTILS/SHELLUTL/PHDPLD/PLD.COM').read_bytes()

CASES = {
    'phd': case('UTILS/SHELLUTL/PHDPLD/PHD.COM',
                ['PHD', 'ECHO $_OLDWD', 'PHD SUB', 'PWD', 'ECHO $_OLDWD', 'D1:>PLD', 'PWD',
                 'CD SUB', 'D1:>PHD', 'ECHO $_OLDWD', 'D1:>PHD D1:>', 'PWD', 'ECHO $_OLDWD',
                 'PLD', 'PWD', 'D1:>PHD NOPE', 'PWD', 'ECHO $_OLDWD', 'CD >'],
                files={'PLD.COM': PLD, 'SUB/IN.TXT': b'inner\x9b', 'SUB/DEEP/X.TXT': b'x\x9b'}),
    'phd-set': case('UTILS/SHELLUTL/PHDPLD/PHD.COM',
                    ['PHD', 'ECHO $_OLDWD', 'PHD SUB>DEEP', 'PWD', 'ECHO $_OLDWD', 'D1:>PHD ..',
                     'PWD', 'ECHO $_OLDWD', 'D1:>PHD D1:>', 'PWD', 'ECHO $_OLDWD', 'PHD NOPE', 'PWD',
                     'ECHO $_OLDWD', 'PHD A.TXT', 'PWD', 'CD >'],
                    files={'A.TXT': b'a\x9b', 'SUB/DEEP/X.TXT': b'x\x9b'}),
}
