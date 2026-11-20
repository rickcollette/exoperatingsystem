; EOS oracle test: extended memory: NBANKS, COMTAB2-3/-2, T_, then MALLOC
; $04 of the size given until it fails (index, N, address when it worked),
; 8 at most.
MALLOC   smb 'MALLOC'
U_GETNUM smb 'U_GETNUM'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
COMTAB2  smb 'COMTAB2'
T_       smb 'T_'

addpos   equ $0782
bytbuf   equ $0785
EOL      equ $9B

        blk reloc main
start   jsr U_GETNUM           ; the block size
        sta sz
        stx sz+1
        lda COMTAB+$1D
        sta v1
        lda COMTAB2-3
        sta v2
        lda COMTAB2-2
        sta v3
        ldx #7
t1      lda T_+4,x
        sta tt,x
        dex
        bpl t1
        jsr PRINTF
        dta c'nb %2x eb %2x et %2x',EOL,0
        dta a(v1,v2,v3)
        jsr PRINTF
        dta c't %2x %2x %2x %2x %2x %2x %2x %2x',EOL,0
        dta a(tt,tt+1,tt+2,tt+3,tt+4,tt+5,tt+6,tt+7)
        lda #8
        sta cnt
m1      lda sz
        sta bytbuf
        lda sz+1
        sta bytbuf+1
        ldx #$04
        ldy #0
        jsr MALLOC
        php
        stx rx
        pla
        and #$80
        sta rn
        lda #0                 ; the address only when it worked
        sta ah
        sta al
        lda rn
        bne m0
        lda addpos+1
        sta ah
        lda addpos
        sta al
m0
        jsr PRINTF
        dta c'm x%2x n%2x a%2x%2x',EOL,0
        dta a(rx,rn,ah,al)
        lda rn
        bne m2
        dec cnt
        bne m1
m2      rts

cnt     dta 0
sz      dta a(0)
v1      dta 0,0
v2      dta 0,0
v3      dta 0,0
rx      dta 0,0
rn      dta 0,0
ah      dta 0,0
al      dta 0,0
tt      :8 dta 0

        blk update address
        blk update symbols
