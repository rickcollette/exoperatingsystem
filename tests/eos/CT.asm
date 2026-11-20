; EOS test: the memory configuration as programs see it: COMTAB+$1A-$1F
; (FILLEN, 800FLG, PBMASK, NBANKS, BANKFLG, OSRMFLG), MEMLO, T_+4-7, and
; what MALLOC $02 (100 bytes) grants.
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
T_       smb 'T_'
MALLOC   smb 'MALLOC'
MEMLO    equ $02E7
addpos   equ $0782
bytbuf   equ $0785
EOL      equ $9B

        blk reloc main
start   ldx #5
s1      lda COMTAB+$1A,x
        sta c,x
        lda T_+4,x
        sta t,x
        dex
        bpl s1
        jsr PRINTF
        dta c'c %2x %2x %2x %2x %2x %2x',EOL,0
        dta a(c,c+1,c+2,c+3,c+4,c+5)
        jsr PRINTF
        dta c't %2x %2x %2x %2x',EOL,0
        dta a(t,t+1,t+2,t+3)
        lda #100
        sta bytbuf
        lda #0
        sta bytbuf+1
        ldx #$02
        jsr MALLOC
        stx mx
        php
        pla
        and #$80
        sta mn
        lda addpos
        sta ma
        lda addpos+1
        sta ma+1
        jsr PRINTF
        dta c'm x%2x n%2x a%2x%2x',EOL,0
        dta a(mx,mn,ma+1,ma)
        rts

c       :6 dta 0
t       :6 dta 0
mx      dta 0
mn      dta 0
ma      dta a(0)

        blk update address
        blk update symbols
