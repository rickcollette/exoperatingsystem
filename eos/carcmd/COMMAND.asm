; EOS CAR: COMMAND, the command processor as a program
;   COMMAND
; On SDX the command processor is the program CAR:COMMAND.COM, reloaded
; after every external command unless LOAD COMMAND.COM keeps it in memory.
; EOS's command processor lives in the cartridge and needs no memory, so
; this program only goes back to it: running COMMAND (or LOAD COMMAND.COM)
; is harmless, and programs that look for CAR:COMMAND.COM find it.
        blk reloc main
start   rts

        blk update address
        blk update symbols
