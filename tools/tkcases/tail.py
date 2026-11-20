"""TAIL (no SDX original): the last lines, 10 or -n count (-n 3, -n3, -3),
fewer lines than asked, empty and long lines, no EOL at the end, an input
larger than memory, standard input with << and output with >>, the
errors. The expected screen lines come from the files (Unix tail),
wrapped as E: wraps them."""
import emu
from tk_test import case

N = ['n%d' % i for i in range(1, 31)]
A = ['one', 'two', 'three']
LONG = ['first', 'L' + 'y' * 140 + 'Z', 'last']
HUGE = ['huge line %05d .........................' % i for i in range(1, 1201)]   # 48 KB, more than the memory
FILES = {'N.TXT': emu.atascii(N), 'A.TXT': emu.atascii(A), 'E.TXT': b'',
         'LONG.TXT': emu.atascii(LONG), 'NOEOL.TXT': emu.atascii(A) + b'abc',
         'SUB/S.TXT': emu.atascii(A)}
USE = 'Use: tail [-n count] [filename]'


def rows(lines):
    """Text lines as the 38 columns of the screen show them (blank rows dropped)."""
    out = []
    for x in lines:
        for i in range(0, max(len(x), 1), 38):
            if x[i:i + 38].strip():
                out.append(x[i:i + 38].strip())
    return out


CASES = {
    'tail': case(None, ['TAIL N.TXT', 'TAIL -n 3 N.TXT', 'TAIL -n2 A.TXT', 'TAIL -1 SUB>S.TXT',
                        'TAIL -n 0 N.TXT', 'TAIL -5 A.TXT', 'TAIL E.TXT'],
                 files=FILES, prog='TAIL.COM',
                 want=rows(N[-10:] + N[-3:] + A[-2:] + A[-1:] + A)),
    'tail2': case(None, ['TAIL -n 2 LONG.TXT', 'TAIL -2 NOEOL.TXT', 'TAIL -2 <<N.TXT',
                         'TAIL -n 12 <<N.TXT >>OUT.TXT', 'TAIL -n 100 OUT.TXT'],
                  files=FILES, prog='TAIL.COM',
                  want=rows(LONG[-2:] + ['three', 'abc' + N[-2], N[-1]] + N[-12:])),
    'tail3': case(None, ['TAIL NOPE.TXT', 'TAIL -x A.TXT', 'TAIL - A.TXT', 'TAIL -n A.TXT',
                         'TAIL -n', 'TAIL -n 1x A.TXT', 'TAIL -n 70000 A.TXT', 'TAIL A.TXT N.TXT',
                         'TAIL -n 65535 A.TXT'],
                  files=FILES, prog='TAIL.COM',
                  want=['File NOPE.TXT', '170 File not found'] + [USE] * 7 + A),
    'tail4': case(None, ['TAIL -n 4 <<HUGE.TXT'],
                  files=dict(FILES, **{'HUGE.TXT': emu.atascii(HUGE)}), prog='TAIL.COM',
                  want=rows(HUGE[-4:])),
    # more lines asked than fit: the first ones go, the end is still right
    'tail5': case(None, ['TAIL -n 2000 HUGE.TXT'],
                  files=dict(FILES, **{'HUGE.TXT': emu.atascii(HUGE)}), prog='TAIL.COM',
                  want=rows(HUGE)[-22:]),
}
