; EOS CAR: RAMDISK.SYS [drive[,nbanks]] [/S]: a RAM disk in the extended
; banks (the command processor sets it up: _EOSDRV 3). DEVICE RAMDISK in
; EOSSYS.SYS does the same without loading this file.
_EOSDRV smb '_EOSDRV'

        blk reloc main
start   lda #3
        jmp _EOSDRV

        blk update address
        blk update symbols
