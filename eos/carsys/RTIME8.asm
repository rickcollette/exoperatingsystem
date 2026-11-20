; EOS CAR: RTIME8.SYS: the clock driver (built into EOS: _EOSDRV 4 turns it on;
; DEVICE RTIME8 in EOSSYS.SYS does the same without loading this file).
_EOSDRV smb '_EOSDRV'

        blk reloc main
start   lda #4
        jmp _EOSDRV

        blk update address
        blk update symbols
