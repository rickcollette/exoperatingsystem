"""HEAD (no SDX original): the first lines, 10 or -n count (-n 3, -n3, -3),
fewer lines than asked, empty and long lines, standard input with << and
output with >>, the errors. The expected screen lines come from the files
(Unix head), wrapped as E: wraps them."""
import emu
from tk_test import case

N = ['n%d' % i for i in range(1, 31)]
A = ['one', 'two', 'three']
LONG = ['L' + 'y' * 140 + 'Z', 'second', 'third']
FILES = {'N.TXT': emu.atascii(N), 'A.TXT': emu.atascii(A), 'E.TXT': b'',
         'LONG.TXT': emu.atascii(LONG), 'NOEOL.TXT': b'abc', 'SUB/S.TXT': emu.atascii(A)}
USE = 'Use: head [-n count] [filename]'


def rows(lines):
    """Text lines as the 38 columns of the screen show them (blank rows dropped)."""
    out = []
    for x in lines:
        for i in range(0, max(len(x), 1), 38):
            if x[i:i + 38].strip():
                out.append(x[i:i + 38].strip())
    return out


CASES = {
    'head': case(None, ['HEAD N.TXT', 'HEAD -n 3 N.TXT', 'HEAD -n2 A.TXT', 'HEAD -1 SUB>S.TXT',
                        'HEAD -n 0 N.TXT', 'HEAD -5 A.TXT', 'HEAD E.TXT'],
                 files=FILES, prog='HEAD.COM',
                 want=rows(N[:10] + N[:3] + A[:2] + A[:1] + A)),
    'head2': case(None, ['HEAD -n 2 LONG.TXT', 'HEAD NOEOL.TXT', 'HEAD -2 <<N.TXT',
                         'HEAD -n 12 <<N.TXT >>OUT.TXT', 'HEAD -n 100 OUT.TXT'],
                  files=FILES, prog='HEAD.COM',
                  want=rows(LONG[:2] + ['abc' + N[0], N[1]] + N[:12])),
    'head3': case(None, ['HEAD NOPE.TXT', 'HEAD -x A.TXT', 'HEAD - A.TXT', 'HEAD -n A.TXT',
                         'HEAD -n', 'HEAD -n 1x A.TXT', 'HEAD -n 70000 A.TXT', 'HEAD A.TXT N.TXT',
                         'HEAD -n 65535 A.TXT'],
                  files=FILES, prog='HEAD.COM',
                  want=['File NOPE.TXT', '170 File not found'] + [USE] * 7 + A),
}
