"""PLD: nothing saved, then back from a subdirectory to the main
directory and the other way (PHD, the original, saves), the variable
gone afterwards, a saved directory that is no longer there. PHD saves
the device as DSKA:, which EOS's U_GEFINA does not take yet (130): pld-drv
does the same with the drive set as A: and D1:."""
from tk_test import case, TKX

PHD = (TKX / 'UTILS/SHELLUTL/PHDPLD/PHD.COM').read_bytes()
PL = 'UTILS/SHELLUTL/PHDPLD/PLD.COM'

CASES = {
    'pld': case(PL, ['PLD', 'PWD', 'PHD SUB', 'PWD', 'D1:>PLD', 'PWD', 'ECHO $_OLDWD', 'PLD', 'PWD',
                     'CD SUB', 'D1:>PHD D1:>', 'PLD', 'PWD', 'CD >', 'SET _OLDWD=DSKA:>NOPE>', 'PLD',
                     'PWD', 'ECHO $_OLDWD', 'SET _OLDWD=DSKA:', 'PLD', 'PWD'],
                files={'PHD.COM': PHD, 'SUB/IN.TXT': b'inner\x9b'}),
    'pld-drv': case(PL, ['SET _OLDWD=A:>SUB>', 'PLD', 'PWD', 'ECHO $_OLDWD', 'SET _OLDWD=D1:>', 'D1:>PLD',
                         'PWD', 'SET _OLDWD=A:>NOPE>', 'PLD', 'PWD', 'ECHO $_OLDWD', 'SET _OLDWD=A:SUB',
                         'PLD', 'PWD', 'SET _OLDWD=A:', 'D1:>PLD', 'PWD', 'CD >'],
                    files={'SUB/IN.TXT': b'inner\x9b'}),
}
