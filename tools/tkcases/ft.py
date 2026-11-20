"""FT: one file and wildcards, /C (and its one-file form), /I, /V,
escapes, blanks against tabs and EOLs, a last line without an EOL, a line
longer than 255, subdirectories, no match and no file. (No empty file:
SDX reads the test disk's empty files with error 139.)"""
from tk_test import case

ORIG = 'UTILS/FILEUTIL/FT/FT.COM'
E = '\x9b'
FILES = {'A.TXT': ('hello world' + E + 'second line' + E + 'Hello again' + E).encode('latin1'),
         'B.TXT': ('no\x7fmatch hello' + E + 'xyz').encode('latin1'),
         'C.DAT': ('a\x1bb' + E + 'tab\x7fhere' + E + 'end hello' + E + 'q' * 300 + E +
                   'hello after' + E).encode('latin1'),
         'SUB/D.TXT': ('deep hello' + E + 'x?y' + E).encode('latin1')}

CASES = {
    'ft': case(ORIG, ['FT A.TXT hello', 'FT *.TXT hello', 'FT *.TXT /I hello',
                      'FT *.TXT /C hello', 'FT A.TXT /C hello', 'FT NOPE.TXT x'], files=FILES),
    'ft2': case(ORIG, ['FT *.TXT xyz', 'FT B.TXT /I NO MATCH', 'FT *.TXT o\\sw',
                       'FT A.TXT d\\n', 'FT C.DAT \\e', 'FT C.DAT tab here',
                       'FT C.DAT /C hello'], files=FILES),
    'ft3': case(ORIG, ['FT SUB>*.* hello', 'FT SUB>D.TXT x\\?y', 'FT SUB> \\x3F',
                       'FT A.TXT \\cHello', 'FT *.TXT /V /C l', 'FT A.TXT nothing'],
                files=FILES),
    'ft4': case(ORIG, ['FT A.TXT /X hello', 'FT A.TXT \\\\', 'FT *.DAT \\Zq',
                       'FT A.TXT h\\?llo w', 'FT A.TXT \\x'], files=FILES),
}
