; EOS Toolkit: NVPEEK, a byte of a clock's NV-RAM
;   NVPEEK address [value]
; Through the clock driver's I_NVRAM (X the address; C=0 read to A, C=1
; write A; C=1 back on an error): the value is written first when one is
; given, then the byte is read and shown in decimal, hex and as a
; character. Without such a driver the program does not load.
U_GETNUM smb 'U_GETNUM'
PRINTF   smb 'PRINTF'
I_NVRAM  smb 'I_NVRAM'

EOL      equ $9B
ESC      equ $1B

        blk reloc main
start   jsr U_GETNUM
        beq usage
        sta adr
        jsr U_GETNUM           ; a value: written
        beq rd
        ldx adr
        sec
        jsr I_NVRAM
        bcs error
rd      ldx adr
        clc
        jsr I_NVRAM
        bcs error
        sta val
        jsr PRINTF
        dta c'%b %b:$%2x, %b $%2x, "',ESC,c'%c"',EOL,0
        dta a(adr,val,adr,val,val,val)
        rts
error   jsr PRINTF
        dta c'NVRAM error!',EOL,0
        rts
usage   jsr PRINTF
        dta c'NVRAM Peek/Poke',EOL
        dta c'Usage: NVPEEK address [value]',EOL,0
        rts

adr     dta 0
val     dta 0

        blk update address
        blk update symbols
