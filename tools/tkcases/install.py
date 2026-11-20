"""INSTALL: two programs installed; an unload (LOAD alone) leaves them in
memory (MEM: main memory rises by the same amount as on SDX) and they
still run. install_sym: the symbol an installed program defines stays
after an unload (fails on EOS: its loader drops it, see the report)."""
import re
import struct

from tk_test import TKX, case


def grow(lines):
    """MEM's addresses are EOS's own: Main as the rise from the first MEM,
    Ext not compared."""
    out, base = [], None
    for x in lines:
        m = re.match(r'Main: \$([0-9A-F]{4}),', x)
        if m:
            v = int(m.group(1), 16)
            base = v if base is None else base
            x = 'Main: +%d' % (v - base)
        elif x.startswith('Ext: '):
            x = 'Ext:'
        out.append(x)
    return out


# a program of two RTS that defines the symbol TESTSYM at the second
PUB = (b'\xfe\xff' + struct.pack('<BBHH', 1, 0, 0, 2) + b'\x60\x60'
       + b'\xfc\xff' + struct.pack('<BH', 1, 1) + b'TESTSYM ')


def sym(lines):
    """TESTSYM's address and level are the system's own."""
    return [re.sub(r'\$[0-9A-F]{4} \$[0-9A-F]{2}$', '$XXXX $LV', x) for x in lines]


CASES = {
    'install': case('UTILS/SYSUTIL/INSTALL/INSTALL.COM',
                    ['MEM', 'INSTALL HEXDEC.COM CIODEV.COM', 'LOAD', 'MEM', 'HEXDEC 7'],
                    files={'HEXDEC.COM': (TKX / 'UTILS/SHELLUTL/HEXDEC/HEXDEC.COM').read_bytes(),
                           'CIODEV.COM': (TKX / 'UTILS/SYSUTIL/CIODEV/CIODEV.COM').read_bytes()},
                    norm=grow),
    'install_sym': case('UTILS/SYSUTIL/INSTALL/INSTALL.COM',
                        ['INSTALL PUB.COM', 'SL TESTS', 'LOAD', 'SL TESTS'],
                        files={'PUB.COM': PUB,
                               'SL.COM': (TKX / 'UTILS/SYSUTIL/SL/SL.COM').read_bytes()},
                        norm=sym),
}
