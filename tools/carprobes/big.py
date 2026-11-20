"""Probes for CAR:ARC and CAR:MENU (group "big").

Long listings go to files with >> so the screen part stays short; the
files left on D1: carry the rest (and the archives SDX's ARC writes, to be
compared byte for byte with EOS's).
"""
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _tk(name):
    p = ROOT / 'build' / 'tk' / name
    return p.read_bytes() if p.exists() else b''


def _lines(*ls):
    return b''.join(x.encode('latin-1') + b'\x9b' for x in ls)


_rnd = random.Random(7)
MAN_BAT = _tk('MAN_BAT.ARC')          # SDX-made: 13 crunched .MAN pages
TXT_A = _lines('hello world', 'the second line', 'ARC test ===')
TXT_B = b'\x00' * 300 + b'\x90\x90\x90\x07\x07' + b'\x09' * 600 + bytes(range(256))
BIN_C = bytes(_rnd.randrange(256) for _ in range(1500))
SKEW = bytes(_rnd.choice(b'\x00\x00\x00\x00\x01\x01\x02\x03\x04\x90') for _ in range(3000))
TEXT_D = _lines(*['line %d of a longer text file with words words words' % i for i in range(60)])

FILES = {'A.TXT': TXT_A, 'B.TXT': TXT_B, 'C.BIN': BIN_C, 'E.TXT': b''}

PROBES = {
    # no parameters, unknown command, no archive name, missing archive
    'arc-usage': {'files': {'T.ARC': MAN_BAT},
                  'cmds': ['ARC >>U.TXT', 'ARC Q T', 'ARC L', 'ARC L NONE',
                           'ARC X NONE.ARC']},
    # L and V (to files), with masks, .ARC added or given
    'arc-list': {'files': {'T.ARC': MAN_BAT},
                 'cmds': ['ARC L T >>L.TXT', 'ARC V T >>V.TXT', 'ARC L T E*.MAN F*.*',
                          'ARC V T.ARC I*.MAN', 'ARC LN T NONE.*']},
    # V with totals; H (screen off) on a list
    'arc-list2': {'files': {'T.ARC': MAN_BAT},
                  'cmds': ['ARC VH T G*.MAN', 'ARC LW T S*.*']},
    # a file that is not an archive
    'arc-bad': {'files': {'A.TXT': TXT_A},
                'cmds': ['ARC L A.TXT', 'ARC X A.TXT']},
    # X: masks, into a directory, to NUL:, E, notes off
    'arc-x': {'differs': 'SDX disk has AUTOEXEC.BAT and SDXPROBE.COM: 4 sectors less free',
             'files': {'T.ARC': MAN_BAT},
              'cmds': ['ARC X T F*.MAN', 'MD SUB', 'ARC XN T SUB>I*.MAN',
                       'ARC X T NUL:G*.*', 'ARC E T NONE.MAN', 'ARC E T R*.MAN', 'DIR SUB>']},
    # P: to the screen and to a file
    'arc-p': {'files': {'T.ARC': MAN_BAT},
              'cmds': ['ARC P T FI.MAN >>P.TXT', 'ARC P T NEXT.MAN >>Q.TXT', 'ARC P T NOPE.MAN']},
    # A: stored, packed, crunched, empty; the archive left is compared
    'arc-a': {'differs': 'SDX fails 139 reading the empty E.TXT (EOS adds it)',
             'files': dict(FILES),
              'cmds': ['ARC A N A.TXT B.TXT C.BIN E.TXT', 'ARC V N >>NV.TXT', 'ARC L N >>NL.TXT']},
    # A with no file list (*.*: is the archive itself left out?)
    'arc-a2': {'differs': 'SDX adds its AUTOEXEC.BAT and fails 139 on the empty E.TXT',
             'files': dict(FILES),
               'cmds': ['ARC A N', 'ARC L N >>NL.TXT', 'ARC A N NOPE.*']},
    # squeezed and crunched text
    'arc-a3': {'files': {'SKEW.BIN': SKEW, 'D.TXT': TEXT_D},
               'cmds': ['ARC A N SKEW.BIN D.TXT', 'ARC V N']},
    # M, U, F, D, B
    'arc-mufd': {'differs': 'SDX fails 139 on the empty E.TXT; extra files and no clock on EOS',
             'files': dict(FILES),
                 'cmds': ['ARC A N A.TXT', 'ARC M N B.TXT', 'ARC U N A.TXT C.BIN',
                          'ARC F N E.TXT', 'ARC DB N A.TXT', 'ARC L N', 'DIR']},
    # D of everything; D with no list; F/D/U on a missing archive
    'arc-d': {'differs': 'SDX disk has AUTOEXEC.BAT and SDXPROBE.COM; no clock: archive dates',
             'files': dict(FILES),
              'cmds': ['ARC A N A.TXT', 'ARC D N A.TXT', 'DIR', 'ARC A M A.TXT',
                       'ARC D M', 'ARC F Z A.TXT', 'ARC D Z A.TXT', 'ARC U Y A.TXT']},
    # S (stored) and G (password): the archives are compared
    'arc-sg': {'differs': 'SDX leaves S.XAR after 146; the library words 146 differently',
             'files': dict(FILES),
               'cmds': ['ARC AS S B.TXT', 'ARC V S', 'ARC AGPW G A.TXT',
                        'ARC P G >>G1.TXT', 'ARC PGPW G >>G2.TXT', 'MD X', 'ARC XGPW G X>',
                        'ARC XW G NUL:']},
    # the archive in a directory, files from another one
    'arc-dir': {'differs': 'no clock: archive dates; SDX disk has 2 more files',
             'files': {'A.TXT': TXT_A, 'SUB/B.TXT': TXT_A},
                'cmds': ['MD D', 'ARC A D>Z A.TXT SUB>*.TXT', 'ARC L D>Z', 'DIR D>']},
    # no empty file: *.* (the archive itself?), A again (replacing), U, D B
    'arc-a4': {'differs': 'the test disks differ in AUTOEXEC.BAT (SDX: SDXPROBE), which ARC A *.* archives', 'files': {'A.TXT': TXT_A, 'B.TXT': TXT_B, 'C.BIN': BIN_C},
               'cmds': ['ARC A N', 'ARC A N A.TXT', 'ARC U N A.TXT', 'ARC DB N B.TXT',
                        'ARC V N >>NV.TXT']},
    # a wrong password on X; D and F on a missing archive
    'arc-crc': {'files': {'A.TXT': TXT_A},
                'cmds': ['ARC AGPW G A.TXT', 'MD X', 'ARC X G X>', 'ARC D NONE A.TXT',
                         'ARC F NEW A.TXT', 'ARC L NEW']},
    # the first screen of MENU: it waits for a key after drawing it
    'menu-1': {'files': {'A.TXT': TXT_A, 'B.TXT': TXT_B, 'SUB/C.TXT': TXT_A},
               'keywait': True, 'differs': 'MENU waits for a key',
               'cmds': ['MENU']},
}
