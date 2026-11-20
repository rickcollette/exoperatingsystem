; EOS oracle test: U_FAIL with the error code given as the parameter (which
; codes print a message).
U_GETNUM smb 'U_GETNUM'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
EOL      equ $9B

        blk reloc main
start   jsr U_GETNUM
        pha
        jsr PRINTF
        dta c'x',EOL,0
        pla
        jmp U_FAIL

        blk update address
        blk update symbols
