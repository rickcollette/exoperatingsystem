; EOS test: the frame counter (RTCLOK $12-$14) as three bytes, "t a b c".
PRINTF   smb 'PRINTF'
EOL      equ $9B

        blk reloc main
start   lda $14                ; (read twice: the same frame)
        ldx $13
        ldy $12
        cmp $14
        bne start
        sta c
        stx b
        sty a
        jsr PRINTF
        dta c't %b %b %b',EOL,0
        dta a(a,b,c)
        rts
a       dta 0
b       dta 0
c       dta 0

        blk update address
        blk update symbols
