"""SEQ (no SDX original): last alone, first and last, first step last,
counting down, $hex, the 32-bit end (no wrap past 4294967295 or below 0),
nothing for SEQ 0, many numbers through >>, the errors. The expected
lines come from Python's range (Unix seq; with first above last SEQ
counts down)."""
from tk_test import case

M = 4294967295
USE = 'Use: seq [first [step]] last'


def seq(first, step, last):
    if first <= last:
        return [str(x) for x in range(first, last + 1, step)]
    return [str(x) for x in range(first, last - 1, -step)]


CASES = {
    'seq': case(None, ['SEQ 3', 'SEQ 4 6', 'SEQ 1 3 10', 'SEQ 5 2', 'SEQ 10 4 1', 'SEQ 0',
                       'SEQ 0 0', "SEQ '$FE' '$101'"],
                files={}, prog='SEQ.COM',
                want=seq(1, 1, 3) + seq(4, 1, 6) + seq(1, 3, 10) + seq(5, 1, 2) + seq(10, 4, 1)
                + seq(0, 1, 0) + seq(254, 1, 257)),
    'seq2': case(None, ['SEQ 4294967290 3 4294967295', 'SEQ 4294967294 4294967295',
                        'SEQ 5 3 0', 'SEQ 65534 65537', 'SEQ $FFFFFFFF 2147483648 0', 'SEQ 7 100 8'],
                 files={}, prog='SEQ.COM',
                 want=seq(M - 5, 3, M) + seq(M - 1, 1, M) + seq(5, 3, 0) + seq(65534, 1, 65537)
                 + seq(M, 2147483648, 0) + seq(7, 100, 8)),
    'seq3': case(None, ['SEQ', 'SEQ X', 'SEQ 1 0 5', 'SEQ 1 2 3 4', 'SEQ -1', 'SEQ 1 X',
                        'SEQ 2 1 3 >>S.TXT', 'TYPE S.TXT'],
                 files={}, prog='SEQ.COM', want=[USE] * 6 + seq(2, 1, 3)),
    'seq4': case(None, ['SEQ 1000 >>S.TXT', 'TYPE S.TXT'], files={}, prog='SEQ.COM',
                 want=seq(1, 1, 1000)[-22:]),
}
