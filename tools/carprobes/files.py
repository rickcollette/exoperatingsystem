"""CAR: probes, group "files": COPY, COMP, FIND, DELTREE, UNERASE, SORTDIR.
Run on SDX by tools/carref.py; EOS's versions are eos/carcmd/<NAME>.asm.

COPY's prompts (/C, /I) and DELTREE's question (without /Y) wait for keys,
so they are not probed; nor is UNERASE when it finds a file it can
restore (it asks for each). ATR (CAR:) sets attributes where a probe needs
hidden or protected files.
"""

L = lambda *lines: b''.join(x.encode('latin-1') + b'\x9b' for x in lines)  # noqa: E731

TREE = {'A.DAT': L('aaa'), 'B.DAT': L('bbbbbb'), 'C.TXT': L('ccc', 'cc'),
        'SUB/X.DAT': L('xxx'), 'SUB/DEEP.D/Y.TXT': L('yyy')}

# COMP: A.TXT is B.TXT and one more line; C.BIN and D.BIN differ in 3 bytes,
# E.BIN is C.BIN one byte later
C = bytes(range(64))
D = bytearray(C)
D[5], D[20], D[63] = 0xFF, 0x00, 0x01
COMPF = {'A.TXT': L('ABCDEFGHIJ', 'more'), 'B.TXT': L('ABCDEFGHIJ'),
         'A2.TXT': L('ABCDEFGHIJ', 'more'), 'C.BIN': C, 'D.BIN': bytes(D),
         'E.BIN': b'\x00' + C, 'EMPTY.DAT': b''}

SORTF = {'ZED.TXT': L('zz'), 'A1.TXT': L('a' * 300), 'B.DAT': L('bbbbbb'),
         '2X.COM': L('x' * 40), 'M.ABC': L('m'), 'SUB/X.DAT': L('xxx')}

PROBES = {
    # ---- COPY ----
    # what is shown per file; copying a file onto itself
    'copy-1': {'files': TREE,
               'cmds': ['COPY A.DAT X.DAT', 'COPY *.DAT SUB>', 'COPY C.TXT',
                        'COPY C.TXT C.TXT']},
    # destination names as RENAME makes them; a directory named without >
    'copy-2': {'files': TREE,
               'cmds': ['COPY *.DAT *.BAK', 'COPY A.DAT SUB>Q*.*', 'COPY *.DAT SUB>*.X',
                        'COPY B.DAT SUB', 'COPY C.TXT SUB>DEEP.D']},
    # empty places with commas; no destination (the current directory)
    'copy-3': {'files': TREE,
               'cmds': ['COPY,,SUB>', 'COPY SUB>X.DAT', 'CD SUB', 'COPY,,>NEW.DAT'],
               'differs': 'copies the test batch file, whose last line differs on EOS (blanks for SDXPROBE)'},
    # /A appends (to a missing file too)
    'copy-4': {'files': TREE,
               'cmds': ['COPY B.DAT A.DAT/A', 'COPY C.TXT NEW.TXT/A', 'COPY *.DAT ALL.TXT/A',
                        'COPY A.DAT /A', 'TYPE A.DAT']},
    # character devices, one command each (together they did not finish)
    'copy-5a': {'files': TREE, 'cmds': ['COPY C.TXT CON:']},
    'copy-5b': {'files': TREE, 'cmds': ['COPY NUL: ZERO.DAT']},
    'copy-5c': {'files': TREE, 'cmds': ['COPY NUL: CON:']},
    'copy-5d': {'files': TREE, 'cmds': ['COPY NUL: Z*.DAT']},
    'copy-5e': {'files': TREE, 'cmds': ['COPY NUL: SUB>'],
                'differs': 'SDX waits (no result); EOS fails with 165'},
    'copy-5f': {'files': TREE, 'cmds': ['COPY *.DAT CON:']},
    # /V summary, /Q quiet, /D the date not kept
    'copy-6': {'files': TREE,
               'cmds': ['COPY /V *.DAT SUB>', 'COPY /Q *.DAT SUB>', 'COPY /V/Q C.TXT SUB>',
                        'MD NEW', 'COPY /V /R SUB NEW>']},
    # the dates: kept, and not with /D
    'copy-6b': {'files': TREE,
                'cmds': ['COPY /D A.DAT SUB>D.DAT', 'COPY A.DAT SUB>E.DAT', 'DIR SUB>'],
                'differs': 'no clock: the /D copy gets no date'},
    # /R: a directory, a directory's contents, a missing destination
    'copy-7': {'files': TREE,
               'cmds': ['COPY /R SUB NEW>', 'MD NEW', 'COPY /R SUB NEW>',
                        'COPY /R SUB> NEW>']},
    # /N skips, /B backs up what is not archived, /K marks the source
    'copy-8': {'files': TREE,
               'cmds': ['COPY /N *.DAT SUB>', 'MD BK', 'COPY /B *.DAT BK>', 'COPY /B *.DAT BK>',
                        'COPY /K C.TXT BK>', 'DIR /A'],
               'differs': 'no clock: the new directory BK gets no date'},
    # /M moves (a name in the destination; to a device)
    'copy-9': {'files': TREE,
               'cmds': ['COPY /M A.DAT SUB>', 'COPY /M B.DAT SUB>NEW.DAT', 'COPY /M C.TXT CON:',
                        'COPY /M /R SUB> >']},
    # errors
    'copy-10': {'files': TREE,
                'cmds': ['COPY NONE.DAT X.DAT', 'COPY A.DAT D9:X.DAT', 'COPY A.DAT NOPATH>X.DAT',
                         'COPY /Z A.DAT X.DAT', 'COPY A.DAT B.DAT C.DAT', 'COPY SUB X.DAT',
                         'COPY']},
    # attributes: hidden sources, +H, a protected destination
    'copy-11': {'files': TREE,
                'cmds': ['ATR +H B.DAT', 'COPY *.DAT SUB>', 'COPY +H *.* SUB>',
                         'ATR +P SUB>A.DAT', 'COPY A.DAT SUB>', 'COPY -A *.DAT SUB>']},

    # attributes alone; wildcards that match nothing; a hidden destination
    'copy-12': {'files': TREE, 'cmds': ['ATR +H B.DAT', 'COPY +H *.* SUB>']},
    'copy-13': {'files': TREE, 'cmds': ['ATR +H B.DAT', 'COPY +H B.DAT SUB>']},
    'copy-14': {'files': TREE, 'cmds': ['COPY +A *.* SUB>', 'COPY -H *.DAT SUB>Q*.*']},
    'copy-15': {'files': TREE, 'cmds': ['COPY *.XYZ SUB>', 'COPY NONE*.DAT SUB>']},
    # COPY +H after the hidden file was copied once; twice in a row
    'copy-17': {'files': TREE, 'cmds': ['ATR +H B.DAT', 'COPY B.DAT SUB>', 'COPY +H *.* SUB>']},
    'copy-18': {'files': TREE, 'cmds': ['ATR +H B.DAT', 'COPY +H *.* SUB>', 'COPY +H *.* SUB>']},
    'copy-16': {'files': TREE, 'cmds': ['ATR +H SUB>X.DAT', 'COPY A.DAT SUB>X.DAT']},

    # ---- COMP ----
    'comp-1': {'files': COMPF,
               'cmds': ['TYPE NUL: >>E0', 'COMP A.TXT B.TXT', 'COMP B.TXT A.TXT',
                        'COMP A.TXT A2.TXT', 'COMP E0 E0']},
    'comp-2': {'files': COMPF, 'cmds': ['COMP C.BIN D.BIN', 'COMP D.BIN C.BIN']},
    # offsets: one given, both, hex, past the end
    'comp-3': {'files': COMPF,
               'cmds': ['COMP C.BIN E.BIN 0 1', 'COMP E.BIN C.BIN 1', 'COMP C.BIN D.BIN $10 $10',
                        'COMP C.BIN D.BIN 100 100']},
    # an empty file against one that is not (made by TYPE: the test disk
    # builder's empty files have no sector, and SDX fails on them with 139)
    'comp-5': {'files': COMPF, 'cmds': ['TYPE NUL: >>E0', 'COMP E0 B.TXT']},
    'comp-6': {'files': COMPF, 'cmds': ['TYPE NUL: >>E0', 'COMP B.TXT E0']},
    'comp-4': {'files': COMPF,
               'cmds': ['COMP', 'COMP A.TXT', 'COMP A.TXT NONE', 'COMP NONE A.TXT',
                        'COMP A.TXT B.TXT X']},

    # ---- FIND ----
    'find-1': {'files': TREE, 'cmds': ['FIND *.DAT', 'FIND D1:*.TXT', 'FIND A:X.DAT']},
    # a directory given; relative to the current one (one command each:
    # together they did not finish)
    'find-2a': {'files': TREE, 'cmds': ['FIND SUB>*.*']},
    'find-2b': {'differs': 'SDX did not finish after CD SUB (no result)',
                'files': TREE, 'cmds': ['CD SUB', 'FIND *.TXT']},
    'find-2c': {'differs': 'SDX did not finish after CD SUB (no result)',
                'files': TREE, 'cmds': ['CD SUB', 'FIND DEEP.D>*.*']},
    'find-2d': {'differs': 'SDX did not finish after CD SUB (no result)',
                'files': TREE, 'cmds': ['CD SUB', 'FIND >*.TXT']},
    'find-2e': {'files': TREE, 'cmds': ['FIND D*']},
    # the order: a directory before a file in the directory
    'find-5': {'files': {'A.DAT': L('a')},
               'cmds': ['MD SUB', 'COPY A.DAT SUB>', 'COPY A.DAT B.DAT', 'FIND *.DAT']},
    'find-3': {'files': TREE,
               'cmds': ['FIND', 'FIND NONE', 'FIND CAR:D*.COM', 'FIND D9:X', 'FIND NONE>X'],
               'differs': "CAR: holds EOS's own set of commands"},
    # hidden files
    'find-4': {'files': TREE, 'cmds': ['ATR +H A.DAT', 'FIND A.DAT', 'FIND *.*']},

    # ---- DELTREE ----
    'deltree-1': {'files': TREE, 'cmds': ['DELTREE /Y SUB', 'DIR']},
    'deltree-2': {'files': TREE, 'cmds': ['DELTREE /YV SUB']},
    'deltree-3': {'files': TREE,
                  'cmds': ['DELTREE', 'DELTREE /Y NONE', 'DELTREE /Y A.DAT', 'DELTREE /YX SUB',
                           'DELTREE /Y /V D1:SUB>']},
    # a hidden file, then a protected one, in the tree
    'deltree-4': {'files': TREE, 'cmds': ['ATR +H SUB>X.DAT', 'DELTREE /YV SUB', 'DIR SUB>']},
    'deltree-5': {'files': TREE, 'cmds': ['ATR +P SUB>X.DAT', 'DELTREE /YV SUB', 'DIR SUB>']},

    # ---- UNERASE (only where nothing can be restored: no question) ----
    'unerase-1': {'files': TREE,
                  'cmds': ['UNERASE', 'UNERASE NONE.DAT', 'UNERASE *.DAT', 'UNERASE D9:X',
                           'UNERASE NOPATH>X']},

    # ---- SORTDIR ----
    'sortdir-1': {'files': SORTF, 'cmds': ['SORTDIR', 'SORTDIR D1:']},
    'sortdir-n': {'files': SORTF, 'cmds': ['SORTDIR D1: /N', 'DIR']},
    'sortdir-t': {'files': SORTF, 'cmds': ['SORTDIR D1: /T', 'DIR']},
    'sortdir-s': {'files': SORTF, 'cmds': ['SORTDIR D1: /S', 'DIR']},
    'sortdir-x': {'files': SORTF, 'cmds': ['SORTDIR D1: /NX', 'DIR']},
    'sortdir-d': {'files': SORTF, 'cmds': ['COPY NUL: NEW.DAT', 'SORTDIR D1: /D', 'DIR'],
                  'differs': 'no clock: NEW.DAT gets no date; an empty file takes one sector '
                             'less on EOS (DIR free count)'},
    # a subdirectory (with and without >), erased entries, several criteria
    'sortdir-2': {'files': SORTF,
                  'cmds': ['ERASE B.DAT', 'SORTDIR D1: /N', 'SORTDIR D1:SUB /N', 'SORTDIR SUB> /S',
                           'SORTDIR D1: /S /N', 'DIR']},
    'sortdir-3': {'files': SORTF,
                  'cmds': ['SORTDIR D1: /Z', 'SORTDIR D9: /N', 'SORTDIR NONE> /N', 'SORTDIR /N',
                           'SORTDIR A.TXT /N']},
}
