; EOS Toolkit: CDD, change the current drive and directory
;   CDD [d:path]
; As CD, and the drive given becomes the current one too. No parameter:
; nothing is done.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
CHDIR    smb 'CHDIR'
CURDEV   smb 'CURDEV'

device   equ $0761             ; (U_GEFINA: the device of the parameter)

        blk reloc main
start   jsr U_GETPAR
        beq done
        jsr U_GEFINA
        lda device
        sta CURDEV
        jmp CHDIR
done    rts

        blk update address
        blk update symbols
