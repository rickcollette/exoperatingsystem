; EOS test: the command line as a program finds it: LBUF raw, then each
; parameter from U_GETPAR, in brackets.
PRINTF   smb 'PRINTF'
U_GETPAR smb 'U_GETPAR'
COMTAB   smb 'COMTAB'
EOL      equ $9B

        blk reloc main
start   ldy #0
s1      lda COMTAB+$3F,y
        sta buf,y
        iny
        cmp #EOL
        beq s2
        cpy #64
        bcc s1
s2      jsr PRINTF
        dta c'<%s>',EOL,0
        dta a(buf)
p1      jsr U_GETPAR
        beq p2
        ldy #0
p1a     lda COMTAB+$21,y
        sta buf,y
        iny
        cmp #EOL
        bne p1a
        jsr PRINTF
        dta c'[%s]',EOL,0
        dta a(buf)
        jmp p1
p2      rts

buf     :65 dta 0

        blk update address
        blk update symbols
