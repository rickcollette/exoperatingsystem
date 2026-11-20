"""XFCONF: a device that is no disk, a drive that is not there, Altirra's
drive checked, set to its own density (double), to 40 tracks two sides
and to 80 tracks two sides, and back. The menus need keys typed, which
the harness cannot do."""
from tk_test import case

CASES = {
    'xfconf': case('UTILS/DISKUTIL/XFCONF/XFCONF.COM',
                   ['XFCONF CAR:', 'XFCONF D2:', 'XFCONF D1:', 'XFCONF D1: /3', 'XFCONF D1: /4',
                    'XFCONF D1: /5', 'XFCONF D1: /3']),
}
