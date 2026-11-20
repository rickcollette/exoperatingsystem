; EOS CAR: COMEXE.SYS: from now on a program named NAME.EXE (or NAME when
; there is no NAME.COM) runs as X NAME.EXE, with the cartridge off; +NAME
; goes past it (_EOSDRV 0; the command processor does it).
_EOSDRV smb '_EOSDRV'

        blk reloc main
start   lda #0
        jmp _EOSDRV

        blk update address
        blk update symbols
