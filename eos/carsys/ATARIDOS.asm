; EOS CAR: ATARIDOS.SYS. EOS has this driver's work built in (the disk, SIO and
; Atari DOS 2 file systems are in the cartridge; EOSSYS.SYS DEVICE ATARIDOS loads
; nothing), so loading this file only returns.
        blk reloc main
start   rts

        blk update address
