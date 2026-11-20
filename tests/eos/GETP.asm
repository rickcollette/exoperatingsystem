; EOS oracle test: U_GETPAR eight times: "[parameter] z BUFOFF" each (z 1:
; none left), to see how blanks and commas separate parameters.
PRINTF   smb 'PRINTF'
U_GETPAR smb 'U_GETPAR'
COMTAB   smb 'COMTAB'
EOL      equ $9B

        blk reloc main
start   lda #8
        sta n
g1      jsr U_GETPAR
        php
        pla
        and #$02               ; (Z)
        lsr @
        sta z
        lda COMTAB+$0A         ; BUFOFF
        sta off
        ldx #0                 ; the parameter, its EOL ended (0 for PRINTF)
g3      lda COMTAB+$21,x
        cmp #EOL
        beq g4
        sta par,x
        inx
        cpx #28
        bcc g3
g4      lda #0
        sta par,x
        jsr PRINTF
        dta c'[%s] %b %b',EOL,0
        dta a(par,z,off)
        dec n
        bne g1
        rts
n       dta 0
z       dta 0
off     dta 0
par     :29 dta 0

        blk update address
        blk update symbols
