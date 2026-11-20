"""RDDUMP, RDLOAD: the harness has no RAM disk (64K, and EOS's RAM disk
does not answer the configuration command N: see the report), so only the
refusals: no parameters, a floppy drive, a file that is not there, a dump
that is not of the size."""
from tk_test import case

CASES = {
    'rddump': case('UTILS/DISKUTIL/RDDUMP/RDDUMP.COM',
                   ['RDDUMP', 'RDDUMP D1:', 'RDDUMP D1: X.BIN', 'RDDUMP CAR: X.BIN']),
    'rdload': case('UTILS/DISKUTIL/RDDUMP/RDLOAD.COM',
                   ['RDLOAD', 'RDLOAD D.BIN', 'RDLOAD NOPE.BIN', 'RDLOAD D.BIN D1:', 'RDLOAD'],
                   files={'D.BIN': bytes(16384)}),
}
