"""CAR: probes, group "dev": DATE, TIME, TD, KEY, CON, SIOSET, RS232, FORMAT.
Run on SDX by tools/carref.py; EOS's versions are eos/carcmd/<NAME>.asm.

Notes for whoever runs them:
- date-ask and time-ask feed the DATE/TIME prompt from a file (<<). If
  SDX reads the answer from the keyboard instead of standard input they
  wait for a key: drop them then (that is the answer to the question).
- sioset-a and format-ram boot with their own CONFIG.SYS, so their output
  goes to files (>>). format-ram needs a 130XE (RAMDISK O: of 4 banks).
- No probe formats D1:.
"""

L = lambda *lines: b''.join(x.encode('latin-1') + b'\x9b' for x in lines)  # noqa: E731

PROBES = {
    # DATE: /T layout (one-digit day), setting, partial values, separators
    'date-1': {'files': {},
               'cmds': ['DATE 5-2-21', 'DATE /T', 'DATE 7', 'DATE /T', 'DATE 9 3',
                        'DATE /T', 'DATE 28.12.99', 'DATE /T', 'DATE 1/1/00', 'DATE /T']},
    # DATE: what is refused, and how
    'date-2': {'files': {},
               'cmds': ['DATE 1-1-21', 'DATE 31-02-21', 'DATE /T', 'DATE 29-02-00', 'DATE /T',
                        'DATE 29-02-01', 'DATE 1-13-21', 'DATE 0-1-21', 'DATE 1-1-2021',
                        'DATE X', 'DATE /X', 'DATE /T /T', 'DATE /T']},
    # DATE with $DAYTIME=1: the month first, in and out
    'date-us': {'files': {},
                'cmds': ['DATE 5-2-21', 'SET DAYTIME=1', 'DATE /T', 'DATE 12-25-99', 'DATE /T',
                         'DATE 25-12-99', 'SET DAYTIME=2', 'DATE /T']},
    # the prompt, answered from a file: text, layout, RETURN alone
    'date-ask': {'files': {'IN.TXT': L('7-3-21'), 'NL.TXT': L(''), 'BAD.TXT': L('99')},
                 'cmds': ['DATE 1-2-21', 'DATE <<IN.TXT', 'DATE /T', 'DATE <<NL.TXT',
                          'DATE /T', 'DATE <<BAD.TXT', 'SET DAYTIME=1', 'DATE <<NL.TXT']},

    # TIME: /T layout (one-digit hour), partial values, refused values
    'time-1': {'differs': "timing: SDX's clock moves on a second during the batch, EOS's soft clock not yet", 'files': {},
               'cmds': ['TIME 9:05:00', 'TIME /T', 'TIME 23:59', 'TIME /T', 'TIME 7 8 9', 'TIME /T',
                        'TIME 0.1.2', 'TIME /T']},
    'time-2': {'files': {},
               'cmds': ['TIME 24', 'TIME 12:60', 'TIME 1:2:60', 'TIME X', 'TIME /X',
                        'TIME 123', 'SET DAYTIME=1', 'TIME 13:00:00', 'TIME /T']},
    'time-ask': {'differs': "SDX's clock starts at 23:51 (EOS's at 0:00), and timing", 'files': {'IN.TXT': L('10:20:30'), 'NL.TXT': L('')},
                 'cmds': ['TIME <<IN.TXT', 'TIME /T', 'TIME <<NL.TXT']},

    # TD: messages (the line itself is not in the screen text)
    'td-1': {'differs': 'MEM figures: EOS memory layout', 'files': {}, 'cmds': ['TD', 'TD', 'TD ON', 'TD OFF', 'TD X', 'TD ON OFF', 'MEM']},

    # KEY: messages, installing once, switches
    'key-1': {'differs': 'MEM figures: EOS memory layout', 'files': {}, 'cmds': ['MEM', 'KEY', 'KEY', 'KEY OFF', 'KEY', 'KEY ON', 'MEM']},
    'key-2': {'files': {}, 'cmds': ['KEY X', 'KEY OFF', 'KEY ON OFF', 'KEY /X', 'KEY']},

    # CON without CON64.SYS / CON.SYS: errors, and does 64/80 clear the screen?
    'con-1': {'files': {}, 'cmds': ['CON', 'CON 41', 'CON X', 'CON 40', 'ECHO after 40']},
    'con-2': {'files': {}, 'cmds': ['ECHO before', 'CON 64', 'ECHO after 64', 'CON 80',
                                    'ECHO after 80', 'CON 40 80']},

    # SIOSET with SDX's default SIO.SYS: table layout, one unit, words, errors
    'sioset-1': {'files': {}, 'cmds': ['SIOSET', 'SIOSET 1', 'SIOSET D1:', 'SIOSET A',
                                       'SIOSET 16', 'SIOSET X']},
    'sioset-2': {'files': {}, 'cmds': ['SIOSET REFRESH', 'SIOSET WAITACK', 'SIOSET WAITACK $10',
                                       'SIOSET WAITACK', 'SIOSET WAITACK 2', 'SIOSET REFRESH 5',
                                       'SIOSET 2 NORMAL', 'SIOSET 2 RESET', 'SIOSET 2 FOO']},
    'sioset-3': {'files': {}, 'cmds': ['SIOSET 0', 'SIOSET 1 NORMAL 5', 'SIOSET 1 US',
                                       'SIOSET 1 RESET']},
    # SIOSET: what a later SIOSET shows for each protocol set before; the
    # values kept
    'sioset-4': {'files': {}, 'cmds': ['SIOSET 2 NORMAL', 'SIOSET 2', 'SIOSET 3 INDUS', 'SIOSET 3',
                                       'SIOSET 4 XF', 'SIOSET 4', 'SIOSET 5 US 9', 'SIOSET 5',
                                       'SIOSET WAITACK 16', 'SIOSET REFRESH 128', 'SIOSET WAITACK',
                                       'SIOSET REFRESH', 'SIOSET 0']},
    # SIOSET when SIO.SYS is the OS's (/A): SDX's SIOSET fails to load
    # (154: SIO.SYS's symbols are not there) and leaves no files, EOS's
    # answers 154 after the redirection opened them (empty); SDX's screen
    # is not in its reference (its probe address runs while it boots)
    'sioset-a': {'differs': 'SDX: 154 before the redirection, no files; EOS: 154, the files empty', 'files': {'CONFIG.SYS': L('DEVICE SPARTA', 'DEVICE SIO /A')},
                 'cmds': ['SIOSET >>S1.TXT', 'SIOSET 1 >>S2.TXT', 'SIOSET REFRESH >>S3.TXT',
                          'SIOSET WAITACK >>S4.TXT', 'SIOSET 1 NORMAL >>S5.TXT']},

    # RS232 without an interface: errors (each may take the SIO time-outs)
    'rs232-1': {'files': {}, 'cmds': ['RS232 /X', 'RS232 X', 'RS232 /E', 'RS232']},

    # FORMAT /QQ: errors only (no other drive to format)
    'format-1': {'files': {}, 'cmds': ['FORMAT /X', 'FORMAT /QQ D9:', 'FORMAT /QQQ D9:',
                                       'FORMAT /QQ CAR:', 'FORMAT /QQ D9: TOOLONGNAME',
                                       'FORMAT /QQ D9: A B']},
    # RAMDISK.SYS from the prompt with the default RAM disk (O:) in place:
    # a second one on O:, then drives past O: (not drives: P, Q, R)
    'ramdisk-more': {'differs': 'SDX prints nothing for the third failed RAMDISK.SYS and after',
                     'mem': '320K', 'files': {},
                     'cmds': ['RAMDISK.SYS', 'RAMDISK.SYS P,2', 'RAMDISK.SYS Q,2', 'RAMDISK.SYS R,2',
                              'DIR P:', 'DIR Q:', 'DIR R:']},
    # three RAM disks (O: from CONFIG.SYS, N: and M: typed), a fourth on L:,
    # one on a drive in use, what each holds
    'ramdisk-three': {'differs': 'SDX prints nothing for the third failed RAMDISK.SYS and after',
                      'mem': '1088K', 'files': {'CONFIG.SYS': L('DEVICE SPARTA', 'DEVICE SIO',
                                                                  'DEVICE RAMDISK O,4')},
                      'cmds': ['RAMDISK.SYS N,4', 'RAMDISK.SYS M,2', 'RAMDISK.SYS L,2',
                               'RAMDISK.SYS N,2', 'RAMDISK.SYS A,2', 'CHKDSK O:', 'CHKDSK N:',
                               'CHKDSK M:', 'DIR L:']},
    # FORMAT /QQ on a ramdisk: messages, free sectors (is the last one
    # free?), the name given, the name when none is given (kept or blank?)
    'format-ram': {'mem': '320K', 'mask': [r'Volume: .{8} .. (..)'], 'files': {'CONFIG.SYS': L('DEVICE SPARTA', 'DEVICE SIO',
                                             'DEVICE RAMDISK O,4')},
                   'cmds': ['FORMAT /QQ O: RAMVOL >>F1.TXT', 'CHKDSK O: >>C1.TXT',
                            'DIR O: >>D1.TXT', 'FORMAT /QQ O: >>F2.TXT', 'CHKDSK O: >>C2.TXT',
                            'FORMAT /QQ O: lower >>F3.TXT', 'CHKDSK O: >>C3.TXT']},
}
