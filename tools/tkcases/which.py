"""WHICH (no SDX original): built-in commands, programs in the current
directory, along $PATH (CAR: by default, then SET PATH), with a device or
directory given, with an extension, several names, not found, the errors.
The expected lines follow the command processor's search (eos/cp.asm):
built-in, then NAME.COM as given, then after each $PATH entry."""
from tk_test import case

USE = 'Use: which command ...'
FILES = {'SUB/P.COM': b'\xff\xff', 'SUB/Q.BAT': b'x', 'A.TXT': b'x'}

CASES = {
    'which': case(None, ['WHICH TYPE', 'WHICH cls copy', 'WHICH DIR', 'WHICH WHICH', 'WHICH NOPE',
                         'WHICH D1:WHICH', 'WHICH SUB>P', 'WHICH P', 'WHICH A.TXT', 'WHICH SUB>Q.BAT',
                         'WHICH D1:DIR', 'WHICH CAR:DIR', 'WHICH DIR.COM'],
                  files=FILES, prog='WHICH.COM',
                  want=['TYPE: built-in', 'CLS: built-in', 'COPY: built-in', 'CAR:DIR.COM',
                        'WHICH.COM', 'NOPE: not found', 'D1:WHICH.COM', 'SUB>P.COM',
                        'P: not found', 'A.TXT', 'SUB>Q.BAT', 'D1:DIR: not found',
                        'CAR:DIR.COM', 'CAR:DIR.COM']),
    'which2': case(None, ['SET PATH=D1:SUB;CAR:', 'WHICH P DIR', 'SET PATH=D1:>SUB>',
                          'WHICH P DIR', 'SET PATH', 'WHICH DIR P', 'WHICH', 'WHICH -X',
                          'WHICH DIR >>O.TXT', 'TYPE O.TXT'],
                   files=dict(FILES, **{'DIR.COM': b'\xff\xff'}), prog='WHICH.COM',
                   want=['D1:SUB>P.COM', 'DIR.COM', 'D1:>SUB>P.COM', 'DIR.COM', 'DIR.COM',
                         'P: not found', USE, USE, 'DIR.COM']),
}
