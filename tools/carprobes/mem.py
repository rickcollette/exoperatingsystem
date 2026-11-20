"""Probes for the CAR: commands of the "mem" group: MEM, PEEK, POKE, MDUMP,
DUMP, BLOAD, SAVE, X, CAR, COMMAND.

Run on real SDX 4.5 and on EOS; the screens and the files left on D1: are
compared. Memory is poked at $0600 (page 6, free) and loaded at $4000.

The test programs are Atari DOS binary files (sources in the comments):
  T1.COM  $3000: writes $5A to $A000 and reads it back, then prints
          "RAM" or "ROM", RAMTOP and MEMTOP in hex ("RAM C0 BC1F"), RTS.
  T2.COM  a segment at $A000 with a routine printing "A000", then a segment
          at $3000 whose INIT prints "INIT" through it; RUN $A000.
  T3.COM  $3000: two PHAs, prints "DV", JMP (DOSVEC).
"""

T1 = bytes.fromhex(
    'ffff00306d30a95a8d00a0ad00a0a2528e6230a241c95af002a24f8e6330a204a56a'
    '204a30e8ade602204a30ade502204a30a9628d4403a9308d4503a90c8d4803a9008d'
    '4903a90b8d4203a2004c56e4484a4a4a4a20553068290fc90a900269066930'
    '9d6230e86052414d20787820787878789be002e1020030')
T2 = bytes.fromhex(
    'ffff00a024a0a220a0a08a8d4403988d4503a9058d4803a9008d4903a90b8d4203a2'
    '004c56e4413030309b00300b30a207a0304c04a0494e49549be202e3020030e002e1'
    '0200a0')
T3 = bytes.fromhex(
    'ffff003025304848a9238d4403a9308d4503a9038d4803a9008d4903a90b8d4203a2'
    '002056e46c0a0044569be002e1020030')

ALL = bytes(range(256))
TXT = b'Hello world\x9bx\x9b'

# $0600: 'A', EOL, $1C (cursor up), $7D (clear screen), $FF
POKES = ['POKE $600 65', 'POKE 1537 $9B', 'POKE $602 28', 'POKE $603 $7D',
         'POKE $604 255']

PROBES = {
    # MEM: the plain and the long form; the error cases
    'mem-1': {'differs': 'EOS memory layout: lower MEMLO; without USE the system extended area is main memory',
               'files': {}, 'cmds': ['MEM', 'MEM /X']},
    'mem-x': {'differs': 'EOS memory layout: lower MEMLO; without USE the system extended area is main memory',
               'files': {}, 'cmds': ['MEM /X >>MX.TXT']},
    'mem-2': {'differs': 'EOS memory layout: lower MEMLO; without USE the system extended area is main memory',
               'files': {}, 'cmds': ['MEM /Q', 'MEM X', 'MEM /x', 'MEM >>M.TXT']},

    # PEEK: the output format, decimal and hex, a symbol, an expression
    'peek-1': {'differs': 'memory contents ($2E8)',
               'files': {}, 'cmds': ['PEEK 10', 'PEEK $2E7+1']},
    'peek-2': {'differs': 'memory contents and COMTAB2 address',
               'files': {}, 'cmds': ['PEEK COMTAB', 'PEEK COMTAB2-4']},
    'peek-3': {'differs': 'memory contents ($02:$4000)',
               'files': {}, 'cmds': ['PEEK 02:$4000', 'PEEK 04:$4000']},
    'peek-4': {'files': {}, 'cmds': POKES + ['PEEK $600', 'PEEK 1537', 'PEEK $602']},
    # PEEK errors: none (nothing at all), a name that is no symbol, junk,
    # an index with no memory, a 24-bit address without a 65C816
    'peek-err': {'differs': 'memory contents; PEEK $FF0000 prints nothing (no 65C816 memory, XRWMEM fails)',
               'files': {}, 'cmds': ['PEEK', 'PEEK NOSUCH', 'PEEK 1X', 'PEEK 99:0',
                                       'PEEK $FF0000', 'PEEK 1 2', 'ECHO end']},

    # POKE: a value over 255, the error cases (the value is read back)
    'poke-1': {'files': {}, 'cmds': ['POKE $600 300', 'MDUMP $600 1', 'POKE $600,7',
                                     'MDUMP $600 1', 'POKE 02:$600 9', 'MDUMP $600 1']},
    'poke-err': {'files': {}, 'cmds': ['POKE', 'POKE 1536', 'POKE 1536 X', 'POKE 99:1536 1',
                                       'POKE NOSUCH 1', 'POKE 1536 1 2', 'ECHO end']},

    # MDUMP: lengths, /R, an index, a symbol; the characters column
    'mdump-1': {'differs': 'memory contents after $604',
               'files': {}, 'cmds': POKES + ['MDUMP $600 12', 'MDUMP $600 8 /R',
                                              'MDUMP 02:$600 3']},
    # (one command each: the first run of these did not finish in time,
    # probably MDUMP 1536 0 = 64K)
    'mdump-2a': {'differs': 'memory contents (COMTAB)',
               'files': {}, 'cmds': ['MDUMP COMTAB 8']},
    'mdump-2b': {'differs': 'memory contents ($FFFC-$0003)',
               'files': {}, 'cmds': ['MDUMP $FFFC 8']},
    'mdump-2c': {'files': {}, 'cmds': ['MDUMP 1536 /R 3', 'MDUMP 1536 3 /R', 'MDUMP 00:1536 3']},
    # without a length: how many lines (from $FFF0, to a file)
    'mdump-def': {'files': {}, 'cmds': ['MDUMP $FFF0 >>MD.TXT']},
    'mdump-err': {'files': {}, 'cmds': ['MDUMP', 'MDUMP 1536 /Q', 'MDUMP NOSUCH',
                                        'MDUMP 99:0 8', 'ECHO end']},
    # every character, on the screen and in a file (ESC before controls?)
    'mdump-chars': {'files': {'ALL.BIN': ALL},
                    'cmds': ['BLOAD ALL.BIN $4000', 'MDUMP $4018 16', 'MDUMP $4078 8',
                             'MDUMP $40F8 8', 'MDUMP $4000 256 >>MC.TXT']},

    # DUMP: a whole file, from a position, a length, past the end, /A
    'dump-1': {'files': {'A.TXT': TXT},
               'cmds': ['DUMP A.TXT', 'DUMP A.TXT 2', 'DUMP A.TXT 2 3', 'DUMP A.TXT $0D',
                        'DUMP A.TXT 2 /A']},
    'dump-err': {'files': {'A.TXT': TXT},
                 'cmds': ['DUMP A.TXT 100', 'DUMP NONE', 'DUMP A.TXT /Q', 'DUMP A.TXT X',
                          'ECHO end']},
    'dump-chars': {'files': {'ALL.BIN': ALL},
                   'cmds': ['DUMP ALL.BIN $18 16', 'DUMP ALL.BIN $78 16 /A',
                            'DUMP ALL.BIN $98 8 /A', 'DUMP ALL.BIN $F8',
                            'DUMP ALL.BIN >>DA.TXT', 'DUMP ALL.BIN /A >>DB.TXT']},

    # BLOAD: main memory, index 2, the error cases
    'bload-1': {'differs': 'memory contents after the loaded bytes',
               'files': {'A.TXT': TXT},
                'cmds': ['BLOAD A.TXT $600', 'MDUMP $600 16', 'BLOAD A.TXT 02:$610',
                         'MDUMP 02:$610 8', 'BLOAD A.TXT 1536+32', 'MDUMP 1568 4']},
    'bload-err': {'files': {'A.TXT': TXT},
                  'cmds': ['BLOAD A.TXT', 'BLOAD', 'BLOAD NONE $600', 'BLOAD A.TXT 99:$4000',
                           'BLOAD A.TXT X', 'ECHO end']},

    # SAVE: the file written (left on D1:), one byte, the error cases
    # (SAVE T3.DAT $607 $600, a last address below the first, did not end)
    'save-1': {'differs': 'memory contents saved after $600',
               'files': {}, 'cmds': ['POKE $600 255', 'SAVE TEST.DAT $600 $607', 'DUMP TEST.DAT',
                                     'SAVE T2.DAT 1536 1536']},
    'save-2': {'differs': 'SAVE without a last address writes 64000 bytes: SDX did not end in time',
               'files': {}, 'cmds': ['SAVE T4.DAT $600', 'SAVE', 'SAVE T5.DAT X $600', 'ECHO end']},

    # X: $A000 is RAM, RAMTOP/MEMTOP while the program runs; INIT and RUN;
    # JMP (DOSVEC); what is left afterwards
    'x-1': {'files': {'T1.COM': T1, 'T2.COM': T2, 'T3.COM': T3},
            'cmds': ['T1', 'X T1', 'X T2', 'X T3', 'PEEK $6A', 'ECHO end']},
    # loading modes, /C, the extension
    'x-2': {'files': {'T1.COM': T1, 'T2.COM': T2},
            'cmds': ['X /L N T2', 'X /LI T2', 'X /L A T2', 'X /L 64 T1.COM', 'X /C T1',
                     'ECHO end']},
    # errors: no name, no file, not a binary file, a bad switch
    'x-err': {'files': {'T1.COM': T1, 'A.TXT': TXT},
              'cmds': ['X', 'X NONE', 'X A.TXT', 'X /Q T1', 'X /L Q T1', 'ECHO end']},
    # a relocatable SDX program under X (risky: may crash SDX)
    'x-reloc': {'files': {}, 'cmds': ['X CAR:MEM.COM', 'ECHO end']},

    # CAR without a cartridge on top (risky: what SDX does with none)
    'car-1': {'files': {}, 'cmds': ['CAR', 'ECHO end']},
    'car-2': {'files': {'T1.COM': T1}, 'cmds': ['CAR T1', 'CAR /Q', 'ECHO end']},
    # /F: run the file even without a cartridge ($A000 is RAM then?)
    'car-f': {'files': {'T1.COM': T1}, 'cmds': ['CAR /F T1', 'ECHO end']},

    # COMMAND as a command (does the batch file go on?)
    'command-1': {'files': {}, 'cmds': ['ECHO before', 'COMMAND', 'ECHO after']},
}
