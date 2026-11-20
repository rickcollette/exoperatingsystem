; EOS CAR: DOSKEY.SYS [aliases file] [/X]: the command line with a history
; (arrows, CTRL-P/N, F1/F2), aliases (NAME=COMMAND), & between commands
; and, with /X, DIR for an empty line (_EOSDRV 2; lib2 does it).
_EOSDRV smb '_EOSDRV'

        blk reloc main
start   lda #2
        jmp _EOSDRV

        blk update address
        blk update symbols
