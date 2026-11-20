"""STRINGS (no SDX original): the printable runs of a binary file, 4 or
-n length (-n 2, -n6, -12), runs at the very start and end, a run longer
than a screen line, a text file, standard input with << and output with
>>, the errors. The expected screen lines come from the files (Unix
strings, but runs of $20-$7C: $7D and $7E clear the screen and delete in
ATASCII), wrapped as E: wraps them."""
import re
import emu
from tk_test import case

BIN = (b'ABCD\x00\x01xy\x02abc\x03hello world\xff\x9bQRSTU\x80\x00' + b'\x10' * 20 +
       b'k' * 100 + b'\x00ab\x01abcdefgh\x7f12345678' + bytes(range(256)) + b'tail end')
TXT = emu.atascii(['one', 'three', 'a', 'four four'])
FILES = {'BIN.DAT': BIN, 'T.TXT': TXT, 'E.DAT': b'', 'Z.DAT': bytes(300)}
USE = 'Use: strings [-n length] [filename]'


def strings(data, n=4):
    return [m.decode() for m in re.findall(rb'[\x20-\x7c]{%d,}' % n, data)]


def rows(lines):
    """Text lines as the 38 columns of the screen show them (blank rows dropped)."""
    out = []
    for x in lines:
        for i in range(0, max(len(x), 1), 38):
            if x[i:i + 38].strip():
                out.append(x[i:i + 38].strip())
    return out


CASES = {
    'strings': case(None, ['STRINGS BIN.DAT', 'STRINGS E.DAT', 'STRINGS Z.DAT'],
                    files=FILES, prog='STRINGS.COM', want=rows(strings(BIN))),
    'strings2': case(None, ['STRINGS -n 2 BIN.DAT'], files=FILES, prog='STRINGS.COM',
                     want=rows(strings(BIN, 2))),
    'strings4': case(None, ['STRINGS -n6 BIN.DAT', 'STRINGS -n 255 BIN.DAT'],
                     files=FILES, prog='STRINGS.COM', want=rows(strings(BIN, 6))),
    'strings5': case(None, ['STRINGS -12 <<BIN.DAT', 'STRINGS T.TXT', 'STRINGS -n 1 T.TXT >>O.TXT',
                            'STRINGS O.TXT'],
                     files=FILES, prog='STRINGS.COM',
                     want=rows(strings(BIN, 12) + strings(TXT) + strings(TXT))),
    'strings3': case(None, ['STRINGS NOPE.DAT', 'STRINGS -n 0 BIN.DAT', 'STRINGS -n 256 BIN.DAT',
                            'STRINGS -x BIN.DAT', 'STRINGS - BIN.DAT', 'STRINGS BIN.DAT T.TXT',
                            'STRINGS -n'],
                     files=FILES, prog='STRINGS.COM',
                     want=['File NOPE.DAT', '170 File not found'] + [USE] * 6),
}
