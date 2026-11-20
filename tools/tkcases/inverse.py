"""INVERSE: standard input from files (<<): text, every ninth byte value,
a file that is not there; the output to a file shown with DUMP, as the
screen lines do not show inverse video. (Without redirected input it
reads the keyboard: a batch file cannot type. An empty file is left out:
SDX's command processor fails << on it with 139 before the program runs,
EOS runs the program.)"""
from tk_test import case

CASES = {
    'inverse': case('UTILS/SHELLUTL/INVERSE/INVERSE.COM',
                    ['INVERSE <<A.TXT', 'INVERSE <<A.TXT >>O.TXT', 'DUMP O.TXT',
                     'INVERSE <<ALL.DAT >>O.TXT', 'DUMP O.TXT',
                     'INVERSE <<NOPE.TXT', 'ECHO end'],
                    files={'A.TXT': b'The quick brown fox\x9bjumps\x9b',
                           'ALL.DAT': bytes(range(0, 256, 9)) + b'\x9b'}),
}
