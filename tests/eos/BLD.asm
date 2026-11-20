; EOS test: BUILDDIR (13.2) on D2: with the label TESTLAB, then "done".
BUILDDIR smb 'BUILDDIR'
PRINTF   smb 'PRINTF'
DDEVIC   equ $0300
DUNIT    equ $0301
EOL      equ $9B

        blk reloc main
start   lda #$31
        sta DDEVIC
        lda #2
        sta DUNIT
        lda laba
        ldx laba+1
        jsr BUILDDIR
        jsr PRINTF
        dta c'done',EOL,0
        rts
laba    dta a(lab)
lab     dta c'TESTLAB '

        blk update address
        blk update symbols
