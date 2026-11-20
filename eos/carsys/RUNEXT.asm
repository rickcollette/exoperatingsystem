; EOS CAR: RUNEXT.SYS [file]: file associations from file (else
; CAR:RUNEXT.CFG), kept in memory; typing a NAME.EXT runs its program
; (_EOSDRV 1; the command processor does it). RUNEXT lists them.
_EOSDRV smb '_EOSDRV'

        blk reloc main
start   lda #1
        jmp _EOSDRV

        blk update address
        blk update symbols
