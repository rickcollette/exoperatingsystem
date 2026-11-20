"""BSAVE: the OS ROM saved (the same on both systems) and shown by DUMP, or
compared by COMP (no output when the same): 16 bytes, multi-sector areas,
an empty one, address arithmetic, a symbol; missing and bad parameters, an
address above 64K, a bad path. A line from a TYPE marks the end of each
command's output."""
from tk_test import case


def marked(cmds):
    out = []
    for c in cmds:
        out += [c, 'TYPE M']
    return out


FILES = {'M': b'--\x9b'}

CASES = {
    'bsave': case('UTILS/SYSUTIL/BSAVE/BSAVE.COM',
                  marked(['BSAVE', 'BSAVE F1', 'BSAVE F1 $E000', 'BSAVE F1 $E000 X',
                          'BSAVE F1 X 16', 'BSAVE F1 $10000 16', 'BSAVE NOPE>F4 $E000 4',
                          'BSAVE F1 1:$4000 16', 'BSAVE F8 COMTAB 4']),
                  files=FILES),
    'bsave2': case('UTILS/SYSUTIL/BSAVE/BSAVE.COM',
                   ['POKE $600 $41', 'POKE $601 $42', 'POKE $602 $9B', 'POKE $603 $FF'] +
                   marked(['BSAVE F1 $600 4', 'DUMP F1', 'BSAVE F3 $600+2 2', 'DUMP F3',
                           'BSAVE F7 $600 0', 'DUMP F7', 'BSAVE F5 $E000 1024',
                           'BSAVE F6 57856 512', 'COMP F5 F6 512', 'BSAVE D1:F9 $E1FE $103',
                           'COMP F9 F5 0 510']),
                   files=FILES),
}
