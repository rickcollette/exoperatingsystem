"""SHUFFLE: the usage line (nothing, a file name), the main directory, a
subdirectory, one with a single entry, an empty one, one that is not
there. The order is random (POKEY's RANDOM, not the same on the two
systems): the entries DIR lists after the shuffle are compared sorted.
(DOS 2 disks are refused with a message; the cases use one disk in D1:,
a SpartaDOS one.)"""
import re
from tk_test import case


def sorted_dirs(lines):
    """DIR's entries sorted; SHUFFLE.COM's own size and the free sectors
    left out (EOS's SHUFFLE.COM is not the same size)."""
    out, run = [], []
    for x in lines + ['']:
        x = re.sub(r'^\d+ FREE SECTORS', 'FREE SECTORS', x)
        if re.match(r'^\S+ +(\S+ +)?(<DIR>|\d+) +\d+-\d\d-\d\d', x):
            run.append(re.sub(r'^SHUFFLE  COM +\d+', 'SHUFFLE  COM', x))
            continue
        out += sorted(run) + [x]
        run = []
    return out[:-1]


FILES = {'A.TXT': b'alpha\x9b', 'B.TXT': b'beta\x9b', 'C.DAT': bytes(300), 'D.COM': bytes(10),
         'E': b'e\x9b', 'SUB/X1.TXT': b'1\x9b', 'SUB/X2.TXT': b'2\x9b', 'SUB/X3.TXT': b'3\x9b',
         'ONE/ONLY.TXT': b'only\x9b', 'EMPTY/F.TXT': b'f\x9b'}
S = 'UTILS/SHELLUTL/SHUFFLE/SHUFFLE.COM'
CASES = {
    'shuffle': case(S, ['SHUFFLE', 'SHUFFLE A.TXT', 'SHUFFLE NOPE>', 'SHUFFLE SUB>X1.TXT', 'ECHO end'],
                    files=FILES),
    'shuffle-1': case(S, ['SHUFFLE D1:', 'DIR'], files=FILES, norm=sorted_dirs),
    'shuffle-2': case(S, ['SHUFFLE SUB>', 'DIR SUB>', 'SHUFFLE D1:>ONE>', 'DIR ONE>',
                          'ERASE EMPTY>F.TXT', 'SHUFFLE EMPTY>', 'DIR EMPTY>'],
                      files=FILES, norm=sorted_dirs),
}
