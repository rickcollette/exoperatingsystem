"""TOUCH: new empty files, /C and /H, in the main directory and in a
subdirectory, and the errors. The dates are left out: EOS in the emulator
has no clock (its date is the one of the program last loaded), SDX's runs."""
import re
from tk_test import case

ORIG = 'UTILS/FILEUTIL/TOUCH/TOUCH.COM'
FILES = {'A.TXT': b'one', 'B.TXT': b'two', 'SUB/C.TXT': b'x'}


def norm(lines):
    """The program's own size, the free sectors, and the dates."""
    out = []
    for x in lines:
        x = re.sub(r'^TOUCH +COM +\d+', 'TOUCH COM', x)
        x = re.sub(r'^\d+ FREE SECTORS', 'FREE', x)
        out.append(re.sub(r'\d+-\d\d-\d\d +\d+:\d\d$', 'DATE', x))
    return out


CASES = {
    'touch': case(ORIG, ['TOUCH', 'TOUCH /X A.TXT', 'TOUCH NOPE>X.TXT', 'TOUCH CAR:X.COM',
                         'TOUCH F:'], files=FILES),  # (a drive: E: is the screen on EOS)
    'touch2': case(ORIG, ['TOUCH /C NEW1.TXT', 'TOUCH NEW2.TXT', 'TOUCH a.txt', 'TOUCH /H B.TXT',
                          'TOUCH /CH NEW4.TXT', 'TOUCH /C A.TXT', 'TOUCH SUB>NEW3.TXT',
                          'TOUCH D1:SUB>C.TXT', 'DIR', 'DIR SUB>'], files=FILES, norm=norm),
}
