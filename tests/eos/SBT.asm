; EOS oracle test: SETBOOT on the file given (the disk's header is compared
; by the test), and on a directory (an error, caught).
SETBOOT  smb 'SETBOOT'
U_GETPAR smb 'U_GETPAR'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'
scan     equ $0779
EOL      equ $9B

        blk reloc main
start   lda trapv
        ldx trapv+1
        jsr U_SFAIL
        jsr U_GETPAR
        lda #0
        sta scan
        jsr SETBOOT
        jsr U_XFAIL
        jsr PRINTF
        dta c'ok',EOL,0
        rts
trap    sta v
        jsr PRINTF
        dta c'err %b',EOL,0
        dta a(v)
        rts
trapv   dta a(trap)
v       dta 0,0

        blk update address
        blk update symbols
