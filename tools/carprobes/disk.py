"""CAR: probes, group "disk": CHVOL, CHTD, CHKDSK, PWD, DF, DEV, MAP,
SETPATHS, APPEND. Run on SDX by tools/carref.py; EOS's versions are
eos/carcmd/<NAME>.asm.

DIR NONE.X shows only the volume line (and the free sectors), which is
how the volume name is looked at after CHVOL.
"""

L = lambda *lines: b''.join(x.encode('latin-1') + b'\x9b' for x in lines)  # noqa: E731

TREE = {'A.DAT': L('aaa'), 'B.DAT': L('bbb'), 'C.TXT': L('ccc'),
        'SUB/X.DAT': L('xxx'), 'SUB/DEEP.D/Y.TXT': L('yyy')}

PROBES = {
    # PWD: line format (root, subdirectories with extensions), drives left out
    'pwd-1': {'files': TREE,
              'cmds': ['PWD', 'CD SUB', 'PWD', 'CD DEEP.D', 'PWD', 'CD >', 'PWD', 'PWD X']},
    # does $MAXDRV limit the drives PWD and DF look at?
    'pwd-2': {'differs': "names: a drive whose letter is a CIO device's (C: D: E: K:) is D3: D4: D5: DK: on EOS", 'files': {}, 'cmds': ['SET MAXDRV=C:', 'PWD', 'DF /A']},

    # DEV: the table as SDX has it
    'dev-1': {'differs': "driver addresses are EOS's own; no clock driver (CLK: $0000)", 'files': {}, 'cmds': ['DEV', 'DEV X']},

    # DF: columns, sums; /A lists the drives that fail
    'df-1': {'files': TREE, 'cmds': ['DF', 'DF A:', 'DF /Z']},
    'df-2': {'differs': "names: a drive whose letter is a CIO device's (C: D: E: K:) is D3: D4: D5: DK: on EOS", 'files': {}, 'cmds': ['DF /A']},

    # CHKDSK: the plain and the /X layout, drive given, errors
    'chkdsk-1': {'files': TREE, 'cmds': ['CHKDSK', 'CHKDSK D1:']},
    'chkdsk-2': {'files': TREE, 'cmds': ['CHKDSK /X']},
    # into files: the spaces and blank lines the screen comparison drops
    'chkdsk-f': {'files': TREE,
                 # the sequence number: SDX also writes the header when a
                 # file is created, EOS only when it is closed or flushed
                 'mask': [r'Volume: .{8} (..) ..'], 'cmds': ['CHKDSK >>C.LOG', 'CHKDSK /X >>X.LOG']},
    'chkdsk-3': {'differs': "CAR: disk information not as SDX's (Cart 4.4, 8192-byte sectors)", 'files': {}, 'cmds': ['CHKDSK D9:', 'CHKDSK CAR:', 'CHKDSK /Z', 'CHKDSK A: B:']},

    # CHVOL: message, lower case and spaces, length, device, errors
    'chvol-1': {'files': {}, 'cmds': ['CHVOL TESTING', 'DIR NONE.X', 'CHVOL D1:my disk',
                                      'DIR NONE.X', 'CHVOL LONGNAME12', 'DIR NONE.X']},
    'chvol-2': {'files': {}, 'cmds': ['CHVOL', 'CHVOL A:', 'CHVOL A.BCD', 'DIR NONE.X',
                                      'CHVOL >SUB>NAME', 'DIR NONE.X', 'CHVOL D9:X']},
    'chvol-3': {'files': {}, 'cmds': ['CHVOL   lead', 'DIR NONE.X', 'CHVOL A,B', 'DIR NONE.X',
                                      'CHVOL *?', 'DIR NONE.X']},

    # CHTD: message, default attributes (-H -P), archive bit, directories
    'chtd-1': {'differs': "dates: SDX's reference run had its clock at 6-06-23 23:51, EOS's starts at 1-01-25 (chtd-5 sets both)", 'files': TREE, 'cmds': ['CHTD *.DAT', 'DIR', 'CHTD /Q C.TXT', 'DIR C.TXT']},
    'chtd-2': {'differs': "dates: SDX's reference run had its clock at 6-06-23 23:51, EOS's starts at 1-01-25 (chtd-5 sets both)", 'files': TREE, 'cmds': ['ATR +P B.DAT', 'ATR +H C.TXT', 'ATR +A A.DAT',
                                       'CHTD *.*', 'DIR /A']},
    'chtd-3': {'differs': "dates: SDX's reference run had its clock at 6-06-23 23:51, EOS's starts at 1-01-25 (chtd-5 sets both)", 'files': TREE, 'cmds': ['ATR +P B.DAT', 'CHTD +P *.*', 'DIR /A']},
    'chtd-4': {'differs': "dates: SDX's reference run had its clock at 6-06-23 23:51, EOS's starts at 1-01-25 (chtd-5 sets both)", 'files': TREE, 'cmds': ['CHTD', 'CHTD NONE.X', 'CHTD SUB', 'CHTD +S *.*',
                                       'CHTD SUB>*.*', 'DIR']},
    # a set date: files and a directory get it (the clocks' own times differ)
    'chtd-5': {'files': dict(TREE, **{'D.TXT': L('15-03-26'), 'T.TXT': L('12:34:00')}),
               'cmds': ['DATE <<D.TXT >>O.TXT', 'TIME <<T.TXT >>O.TXT', 'ERASE O.TXT',
                        'CHTD C.TXT', 'CHTD SUB', 'DIR C.TXT', 'DIR SUB']},

    # APPEND: $PATH grows by ';' and the parameter
    'append-1': {'files': {}, 'cmds': ['PATH', 'APPEND D2:', 'PATH', 'APPEND d9:>dos>',
                                       'PATH', 'APPEND', 'APPEND A: B:', 'PATH']},
    'append-2': {'files': {}, 'cmds': ['APPEND CAR:', 'PATH', 'SET PATH=', 'CAR:APPEND A:',
                                       'SET']},

    # SETPATHS and MAP with parameters did not end on SDX (25 s) when
    # several ran in one probe: one command per probe to find which hangs
    'setpaths-1': {'files': TREE, 'cmds': ['SETPATHS A:>SUB>', 'PWD']},
    'setpaths-2': {'files': dict(TREE, **{'P.TXT': L('A:>SUB>DEEP.D>')}),
                   'cmds': ['SETPATHS P.TXT', 'PWD']},
    'setpaths-3': {'files': dict(TREE, **{'P.TXT': L('a:>none>', '', '  a:>sub>')}),
                   'cmds': ['SETPATHS P.TXT', 'PWD']},
    'setpaths-4': {'files': TREE, 'cmds': ['SETPATHS']},
    'setpaths-5': {'files': TREE, 'cmds': ['SETPATHS NONE.TXT', 'PWD']},
    'setpaths-6': {'files': TREE, 'cmds': ['SETPATHS A:>NONE>', 'PWD']},
    'setpaths-7': {'files': TREE, 'cmds': ['SETPATHS SUB', 'PWD']},

    # MAP: help screen and drive table (does it show SWAP's sio_index?)
    'map-1': {'differs': "names: a drive whose letter is a CIO device's (C: D: E: K:) is D3: D4: D5: DK: on EOS", 'files': {}, 'cmds': ['MAP']},
    'map-2': {'differs': "names: a drive whose letter is a CIO device's (C: D: E: K:) is D3: D4: D5: DK: on EOS", 'files': {}, 'cmds': ['MAP 3 DK:', 'MAP']},
    'map-3': {'differs': "names: a drive whose letter is a CIO device's (C: D: E: K:) is D3: D4: D5: DK: on EOS", 'files': {}, 'cmds': ['MAP 1 SIO B:', 'MAP']},
    'map-4': {'files': {}, 'cmds': ['MAP 16 B:']},
    'map-5': {'files': {}, 'cmds': ['MAP B: X']},
    'map-6': {'files': {}, 'cmds': ['MAP NONE.TXT']},
    'map-7': {'files': {}, 'cmds': ['MAP 3']},
    'map-8': {'differs': "names: a drive whose letter is a CIO device's (C: D: E: K:) is D3: D4: D5: DK: on EOS", 'files': {}, 'cmds': ['MAP 2 OS', 'MAP']},
    'map-9': {'differs': "names: a drive whose letter is a CIO device's (C: D: E: K:) is D3: D4: D5: DK: on EOS", 'files': {'M.TXT': L('3 SIO DK:', '1 normal B:')}, 'cmds': ['MAP M.TXT', 'MAP']},
    'map-10': {'differs': "names: a drive whose letter is a CIO device's (C: D: E: K:) is D3: D4: D5: DK: on EOS", 'files': {}, 'cmds': ['SWAP 3 4', 'MAP']},
}
