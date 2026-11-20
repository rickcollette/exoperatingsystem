"""STAT: files, a directory, sizes around the sector size, hidden and
protected entries (+H, +P), paths, and the errors."""
from tk_test import case

ORIG = 'UTILS/FILEUTIL/STAT/STAT.COM'
FILES = {'A.TXT': b'one', 'E.DAT': b'', 'S256.DAT': b'x' * 256, 'S257.DAT': b'y' * 257,
         'BIG.DAT': b'z' * 5000, 'SUB/B.TXT': b'x', 'SUB/DEEP/C.TXT': b'cc'}

CASES = {
    'stat': case(ORIG, ['STAT', 'STAT A.TXT', 'STAT SUB'], files=FILES),
    'stat2': case(ORIG, ['STAT E.DAT', 'STAT S256.DAT', 'STAT S257.DAT'], files=FILES),
    'stat3': case(ORIG, ['STAT BIG.DAT', 'STAT SUB>DEEP', 'STAT D1:SUB>B.TXT'], files=FILES),
    'stat4': case(ORIG, ['STAT NOPE>A.TXT', 'STAT *.DAT', 'STAT -S S*.*'], files=FILES),
    'stat5': case(ORIG, ['ATTRIB +H +P A.TXT', 'STAT A.TXT', 'STAT +P A.TXT'], files=FILES),
    # 170 names the file looked for ("File NOPE.TXT"): EOS's FFIRST does
    # not leave the name for U_FAIL when it finds nothing
    'stat6': case(ORIG, ['STAT NOPE.TXT', 'STAT SUB>NOPE.TXT', 'ATTRIB +H A.TXT', 'STAT -H A.TXT'],
                  files=FILES),
}
