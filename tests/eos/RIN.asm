; EOS test: standard input (redirected with <<): up to 6 lines read with
; GETS, each printed in brackets, then "end".
GETS     smb 'GETS'
PRINTF   smb 'PRINTF'
EOL      equ $9B

        blk reloc main
start   lda #6
        sta n
r1      lda bufa
        ldx bufa+1
        ldy #40
        jsr GETS
        bmi r2
        jsr PRINTF             ; (%s ends at the EOL)
        dta c'[%s]',EOL,0
        dta a(buf)
        dec n
        bne r1
r2      jsr PRINTF
        dta c'end',EOL,0
        rts

n       dta 0
bufa    dta a(buf)
buf     :40 dta 0

        blk update address
        blk update symbols
