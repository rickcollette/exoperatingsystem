"""CAR: probes, group "text": LESS, MAN, FMT, ED. Run on SDX by
tools/carref.py; EOS's versions are eos/carcmd/<NAME>.asm.

LESS pages (and waits for keys) when the text is longer than 23 screen
lines, so the long texts are only sent to files (>>), where LESS does not
page; the files left on D1: show the bytes exactly. ED is interactive
throughout and has no probe.
"""

L = lambda *lines: b''.join(x.encode('latin-1') + b'\x9b' for x in lines)  # noqa: E731

PARA = ('   The quick brown fox jumps over the lazy dog and keeps running far away '
        'into the   distant   hills beyond the river, where nobody can see it.')
TEXT = L(PARA, '', 'short line', '  indented  twice', 'A' * 50 + 'longwordthatdoesnotfit end',
         'tail')
LONG = L('X' * 100, 'short', 'B' * 38, 'C' * 40, 'end')
PC = (b'pc line one\r\nsecond\tx\r\nbell\x07 bs\x08 del\x7f hard\xa0sp\r\n'
      b'lf only\nlast cr\rend\r\n\x1a\x1a\x1a')
MIXED = b'atari\x9bwith\r\ncr lf\x9b'
LINES23 = L(*['line %02d' % i for i in range(1, 24)])
LINES30 = L(*['line %02d' % i for i in range(1, 31)])
PAGES = {'MAN/LESS.MAN': L('less man page'), 'MAN/FMT.DOC': L('fmt doc page', 'second line'),
         'MAN/AA.HLP': L('aa help'), 'MAN/BB.TXT': L('bb text'), 'MAN/CC.BIN': L('not a page'),
         'DOC/LESS.TXT': L('less text in doc'), 'DOC/DD.MAN': L('dd page')}
MANY = {'MANY/N%02d.MAN' % i: L('page %d' % i) for i in range(1, 15)}
MANY['MANY/SETPATHS.MAN'] = L('long name')
MANY['MANY/LONGNAME.DOC'] = L('long name 2')

PROBES = {
    # LESS: short texts are printed as by TYPE; long lines folded to the width
    'less-1': {'files': {'A.TXT': L('hello', 'world'), 'L.TXT': LONG},
               'cmds': ['LESS A.TXT', 'LESS L.TXT', 'LESS <<A.TXT']},
    # the errors and switches
    'less-2': {'files': {'A.TXT': L('hello')},
               'cmds': ['LESS NONE', 'LESS /X A.TXT', 'LESS A.TXT B.TXT', 'LESS D9:A.TXT']},
    # redirected: no folding (the bytes in O1.TXT); /C into a file
    'less-3': {'files': {'L.TXT': LONG, 'A.TXT': L('hello')},
               'cmds': ['LESS L.TXT >>O1.TXT', 'LESS /C A.TXT >>O2.TXT', 'TYPE O2.TXT']},
    # PC text converted (bytes in P1.TXT), and Atari text with CR LF in it
    'less-4': {'files': {'PC.TXT': PC, 'MIX.TXT': MIXED},
               'cmds': ['LESS PC.TXT >>P1.TXT', 'LESS MIX.TXT >>P2.TXT', 'LESS PC.TXT']},
    # exactly 23 lines: printed, no paging; 30 lines to a file
    'less-5': {'files': {'A.TXT': LINES23, 'B.TXT': LINES30},
               'cmds': ['LESS B.TXT >>O3.TXT', 'LESS A.TXT']},
    # a text larger than memory (to a file, so nothing pages either way)
    'less-6': {'files': {'BIG.TXT': L(*['%05d ' % i + 'z' * 50 for i in range(1100)])},
               'cmds': ['LESS BIG.TXT >>O4.TXT', 'DIR O4.TXT'],
               'differs': 'free memory differs: O4.TXT (what fits before 158) has another length'},

    # FMT: default width, /S, /J, both, a width; the output in files too
    'fmt-1': {'files': {'P.TXT': TEXT},
              'cmds': ['FMT P.TXT', 'FMT /S /J P.TXT 32']},
    'fmt-2': {'files': {'P.TXT': TEXT},
              'cmds': ['FMT P.TXT >>F1.TXT', 'FMT /S P.TXT 40 >>F2.TXT',
                       'FMT /J P.TXT 40 >>F3.TXT', 'FMT /SJ P.TXT 50 >>F4.TXT',
                       'FMT /S/J P.TXT 64 >>F5.TXT']},
    # widths out of range, a width before the name, standard input, errors
    'fmt-3': {'files': {'P.TXT': TEXT},
              'cmds': ['FMT P.TXT 20 >>G1.TXT', 'FMT P.TXT 200 >>G2.TXT', 'FMT P.TXT 0 >>G3.TXT',
                       'FMT 36 P.TXT >>G4.TXT', 'FMT - 36 <<P.TXT >>G5.TXT', 'FMT NONE',
                       'FMT /X P.TXT 36', 'FMT P.TXT 3X'],
              'differs': "FMT - : EOS's U_FAIL prints 'File -' before 170, SDX no File line"},

    # MAN: the default $MANPATH, no $MANPATH
    'man-1': {'files': {}, 'cmds': ['SET', 'MAN', 'SET MANPATH', 'MAN', 'MAN LESS'],
              'differs': "CAR: holds EOS's own man pages, not SDX's"},
    # pages along $MANPATH: the list, a page, /?, /P, not found, duplicates
    'man-2': {'files': PAGES,
              'cmds': ['SET MANPATH=D1:>MAN;D1:>DOC', 'MAN', 'MAN FMT', 'MAN FMT /?',
                       'MAN LESS /?', 'MAN NOPE', 'MAN NOPE /?', 'MAN AA /P', 'MAN CC',
                       'MAN fmt.txt']},
    # $PAGER: TYPE with /P, an internal command (how the line is built), a
    # viewer that is not there, LESS
    'man-3': {'files': PAGES,
              'cmds': ['SET MANPATH=D1:>MAN', 'SET PAGER=ECHO;X;%;Y', 'MAN FMT',
                       'SET PAGER=ECHO', 'MAN FMT', 'SET PAGER=NOPE', 'MAN FMT',
                       'SET PAGER=LESS', 'MAN FMT', 'SET PAGER=TYPE;%', 'MAN FMT',
                       'MAN FMT /P']},
    # the columns of the list; MANPATH entries without > and with a missing one
    'man-4': {'files': MANY,
              'cmds': ['SET MANPATH=D1:>MANY', 'MAN', 'SET MANPATH=D9:;D1:>NOPE;D1:>MANY',
                       'MAN N01', 'MAN']},
}
