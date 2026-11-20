"""RUN: no address, no such symbol, above 64K (184 on a 6502), and a
routine at $0600 (INC $0610, RTS) answered Y (it runs: PEEK shows the
count) and N (it does not), decimal, with index 0. The key is put in CH
(764) with POKE first: 43 Y, 35 N. run-sym: a symbol, and one
with -n (the addresses differ between SDX and EOS: blanked); run-symplus:
a symbol with +n (SDX's U_GETADR takes it, EOS's does not yet)."""
import re
from tk_test import case

R = 'UTILS/SHELLUTL/RUN/RUN.COM'
CODE = ['POKE $600 $EE', 'POKE $601 $10', 'POKE $602 $06', 'POKE $603 $60', 'POKE $610 0', 'POKE $611 0']
Y, N = 'POKE 764 43', 'POKE 764 35'


def no_adr(lines):
    return [re.sub(r'\$00:\$[0-9A-Fa-f]{4} \(0:\d+\)', 'ADR', x) for x in lines]


CASES = {
    'run': case(R, CODE + ['RUN', 'RUN NOSUCH', 'RUN $10000', Y, 'RUN $600', 'PEEK $610',
                           N, 'RUN $600', 'PEEK $610', Y, 'RUN 1536', Y, 'RUN 0:$600', 'PEEK $610',
                           N, 'RUN $5FF+1', 'ECHO end']),
    'run-sym': case(R, [N, 'RUN U_GETPAR', N, 'RUN PRINTF-1', 'ECHO end'], norm=no_adr),
    'run-symplus': case(R, [N, 'RUN PRINTF+2', 'ECHO end'], norm=no_adr),
}
