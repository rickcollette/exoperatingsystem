"""DPOKE: a word, 1 to 4 bytes (amount 0 and missing), decimal and hex,
a symbol, an index (main memory), 32-bit values, and nothing written for
missing or bad parameters (PEEK shows the result)."""
from tk_test import case

P = 'PEEK $600'
CASES = {
    'dpoke': case('UTILS/SHELLUTL/DPOKE/DPOKE.COM',
                  ['DPOKE $600 $1234', P, 'DPOKE 1536 0', P, 'DPOKE $600 $4142 1', P,
                   'DPOKE $600 $FFFF 0', P, 'DPOKE $600 $A1B2C3D4 4', P, 'PEEK $602',
                   'DPOKE $601 $5A5B 3', P, 'PEEK $602', 'DPOKE 0:$600 513', P,
                   'DPOKE $600', P, 'DPOKE', 'DPOKE $600 X', P, 'DPOKE NOSYM 5', P,
                   'DPOKE $600+2 $3132', 'PEEK $602', 'DPOKE $600 70000', P, 'PEEK $602']),
}
