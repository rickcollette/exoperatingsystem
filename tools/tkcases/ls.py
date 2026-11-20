"""LS: full names in a directory, with /C, attributes, paths, devices,
and the errors (against the SDX Toolkit's LS); EOS's own switches -l, -w,
-a (also /L /W /A) and the - forms of all of them (expected lines)."""
from tk_test import case

FILES = {'A.TXT': b'hello', 'SUB/B.TXT': b'x', 'SUB/C.DAT': b'yy'}
ORIG = 'UTILS/SHELLUTL/LS/LS.COM'

# the test disks' entries all have the date 1-01-25 12:00 (sdfs.build)
XFILES = {'A.TXT': b'hello', 'BIG.DAT': b'b' * 110000, 'SUB/B.TXT': b'x', 'SUB/C.DAT': b'yy',
          'SUB/H.TXT': b'hh', 'SUB/LONGNAME.EXT': b'z' * 9999, 'SUB/DEEP/X.TXT': b'x'}
ROOT = ['A.TXT', 'BIG.DAT', 'LS.COM', 'AUTOEXEC.BAT', 'SDXPROBE.COM']   # (disk order)


def long(name, size, attrs='---'):
    """A line of -l: name, size (bytes, K from 100000 on, <DIR>), date, time,
    attributes H P A."""
    if size is None:
        sz = '<DIR>'
    elif size < 100000:
        sz = '%5d' % size
    else:
        sz = '%4dK' % ((size >> 10) + ((size >> 9) & 1))
    return '%-12s %s  1-01-25 12:00 %s' % (name, sz, attrs)


def wide(names, width=38):
    """-w: names in columns 13 wide, a name only where it ends before the
    screen's last column."""
    out, line, col = [], '', 0
    for n in names:
        if line:
            nxt = col + 13
            if len(line) >= nxt:
                nxt += 13
            if nxt + len(n) >= width:
                out.append(line)
                line, col = n, 0
                continue
            line, col = line.ljust(nxt) + n, nxt
        else:
            line, col = n, 0
    if line:
        out.append(line)
    return out


HIDE = 'ATTRIB +H +A SUB>H.TXT'

CASES = {
    'ls': case(ORIG, ['LS', 'LS /C', 'LS SUB>', 'LS /C SUB>', 'LS *.TXT', 'LS D1:'], files=FILES),
    'ls2': case(ORIG, ['LS +S', 'LS + *.TXT', 'LS NOPE>', 'LS /X', 'LS SUB>*.Q',
                       'LS /C D1:SUB>', 'LS -S S*.*', 'LS Q.Q', 'LS SUB', 'LS /CC A.TXT',
                       'LS A.TXT B.TXT', 'LS >SUB>', 'LS CAR:X.COM', 'LS /C CAR:X.COM',
                       'LS A:A.TXT', 'LS /C D1:A.TXT'], files=FILES),
    'lsl': case(None, [HIDE, 'LS -l SUB>', 'LS -la SUB>', 'LS /L/A *.DAT'], files=XFILES,
                prog='LS.COM',
                want=[long('B.TXT', 1), long('C.DAT', 2), long('LONGNAME.EXT', 9999),
                      long('B.TXT', 1), long('C.DAT', 2), long('H.TXT', 2, 'H-A'),
                      long('LONGNAME.EXT', 9999), long('DEEP', None),
                      long('BIG.DAT', 110000)]),
    'lsl2': case(None, [HIDE, 'ATTRIB +P A.TXT', 'LS -L +H SUB>', 'LS /l A.TXT', 'LS -lw *.TXT',
                        'LS -L +S SUB>'], files=XFILES, prog='LS.COM',
                 want=[long('H.TXT', 2, 'H-A'), long('A.TXT', 5, '-P-'), long('A.TXT', 5, '-P-'),
                       long('DEEP', None)]),
    'lsw': case(None, [HIDE, 'LS -w', 'LS /W/A', 'LS -aw SUB>', 'LS -W SUB>'], files=XFILES,
                prog='LS.COM',
                want=wide(ROOT) + wide(ROOT + ['SUB>']) +
                wide(['B.TXT', 'C.DAT', 'H.TXT', 'LONGNAME.EXT', 'DEEP>']) +
                wide(['B.TXT', 'C.DAT', 'LONGNAME.EXT'])),
    'lsdash': case(None, [HIDE, 'LS -c SUB>', 'LS -C A.TXT', 'LS -ca SUB>DEEP', 'LS -a SUB>',
                          'LS -S S*.*', 'LS -AH SUB>', 'LS -l /X'], files=XFILES,
                   prog='LS.COM',
                   want=['D:SUB>B.TXT', 'D:SUB>C.DAT', 'D:SUB>LONGNAME.EXT', 'D:A.TXT',
                         'D:SUB>DEEP>', 'SUB>B.TXT', 'SUB>C.DAT', 'SUB>H.TXT',
                         'SUB>LONGNAME.EXT', 'SUB>DEEP>', 'SDXPROBE.COM',
                         'SUB>B.TXT', 'SUB>C.DAT', 'SUB>LONGNAME.EXT', '156 Bad parameter']),
}
