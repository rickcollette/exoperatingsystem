"""PERCONF: the usage line, a device that is no disk, a bad keyword, a
drive that is not there; batch mode on Altirra's drive (its PERCOM block
written back as it was, then 80 tracks, step 0). SIDES is left out: SDX
writes the number given as the block's sides-1 byte, EOS one less. The
questions of the interactive mode need keys typed, which the harness
cannot do."""
from tk_test import case

CASES = {
    'perconf': case('UTILS/DISKUTIL/PERCONF/PERCONF.COM',
                    ['PERCONF', 'PERCONF CAR:', 'PERCONF D1: XYZ 1', 'PERCONF D1: TRK',
                     'PERCONF D2:']),
    'perconf_b': case('UTILS/DISKUTIL/PERCONF/PERCONF.COM', ['PERCONF D1: TRK 40']),
    'perconf_dd': case('UTILS/DISKUTIL/PERCONF/PERCONF.COM',
                       ['PERCONF D1: BPS 256 FLG $04 SPT 18 STEP 0 TRK 80']),
}
