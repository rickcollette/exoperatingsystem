; EOS CAR: JIFFY.SYS: the clock driver (built into EOS: _EOSDRV 5 turns it on;
; DEVICE JIFFY in EOSSYS.SYS does the same without loading this file).
_EOSDRV smb '_EOSDRV'

        blk reloc main
start   lda #5
        jmp _EOSDRV

        blk update address
        blk update symbols
