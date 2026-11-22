"""EOSFS-native audits for the Linux-like core commands.

These intentionally use mixed case, spaces and / paths.  The older Toolkit
oracle cases remain useful on SDX but specify its retired 8.3/> contract.
"""
import re
import emu
from tk_test import case

DATE = '  1-01-25 12:00 '


def stable_node(lines):
    return [re.sub(r'Node: \$[0-9A-F]{4}/\d+', 'Node: $NODE/N', line)
            for line in lines]

CASES = {
    'native-core-ls': case(
        None, ['LS -l MiXeD.txt'], files={'MiXeD.txt': b'abc'}, prog='LS.COM',
        want=['MiXeD.txt     3' + DATE + '---']),
    'native-core-stat': case(
        None, ['STAT "Mixed Case.txt"'], files={'Mixed Case.txt': b'abc'},
        prog='STAT.COM', norm=stable_node,
        want=['Name: [Mixed Case.txt]', 'Type: regular file', 'Attr: -----',
              'Node: $NODE/N on DSK1:', 'Size: 3 bytes (1 sectors)',
              'Date:  1-01-25 Time: 12:00:00']),
    'native-core-du': case(
        None, ['DU /QQ SUB/'], files={'SUB/Exact.txt': b'hello'}, prog='DU.COM',
        want=['0 B (0k) in 0 directories', '5 B (0k) in 1 files',
              '5 B (0k) total']),
    'native-core-wc': case(
        None, ['WC -l "Mixed Case.txt"'],
        files={'Mixed Case.txt': emu.atascii(['one two', 'three'])},
        prog='WC.COM', want=['2 Mixed Case.txt']),
    'native-core-which': case(
        None, ['WHICH cat', 'WHICH SUB/prog'],
        files={'SUB/prog.com': b'\xff\xff'}, prog='WHICH.COM',
        want=['cat: built-in', 'SUB/prog.com']),
    'native-core-touch': case(
        None, ['TOUCH "New File"', 'TYPE "New File"', 'ECHO end'],
        files={}, prog='TOUCH.COM', want=['end']),
    'native-core-grep': case(
        None, ['FT *.txt hello'],
        files={'Mixed Case.txt': emu.atascii(['hello world', 'other']),
               'lower.txt': emu.atascii(['hello lower'])},
        prog='FT.COM',
        want=['Mixed Case.txt,0:hello world', 'lower.txt,0:hello lower',
              '2 matches total']),
    'native-core-crc32': case(
        None, ['CRC32 "Mixed Case.bin"'], files={'Mixed Case.bin': b'abc'},
        prog='CRC32.COM', want=['891568578 3 Mixed Case.bin']),
    'native-core-deldup': case(
        None, ['DELDUP left/ right/'],
        files={'left/Long Exact Name.bin': b'same',
               'right/other exact name.bin': b'same'},
        prog='DELDUP.COM',
        want=['** Dup: left/Long Exact Name.bin', '1 dups detected']),
}
