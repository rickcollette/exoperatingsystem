; EOS CAR: ENV.SYS: the environment to an extended bank of its own (16 KiB
; instead of 256 bytes; the top free bank, as CON.SYS takes one); without
; extended RAM it stays where it is (_EOSDRV 6).
_EOSDRV smb '_EOSDRV'

        blk reloc main
start   lda #6
        jmp _EOSDRV

        blk update address
        blk update symbols
