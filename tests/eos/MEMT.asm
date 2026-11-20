; EOS oracle test: MALLOC with memory indices $00, $02, $04 and $40
; alignment: the index granted, N, whether the block is page aligned; and
; what V_setme 2 / V_popme leave in PORTB.
MALLOC   smb 'MALLOC'
PRINTF   smb 'PRINTF'

addpos   equ $0782
bytbuf   equ $0785
PORTB    equ $D301
V_setme  equ $07F1
V_popme  equ $07F4
EOL      equ $9B

        blk reloc main
start   ldx #0
loop    stx ci
        lda reqs,x
        sta rq
        lda #<1025
        sta bytbuf
        lda #>1025
        sta bytbuf+1
        ldx rq
        ldy #0
        jsr MALLOC
        php
        stx rx
        pla
        and #$80
        sta rn
        lda addpos             ; the address may differ: only whether
        bit rq                 ; an aligned block is aligned
        bvs l2
        lda #0
l2      sta al
        jsr PRINTF
        dta c'm %2x x%2x n%2x lo%2x',EOL,0
        dta a(rq,rx,rn,al)
        ldx ci
        inx
        cpx #5
        bne loop
        lda PORTB
        sta p0
        lda #2
        jsr V_setme
        lda PORTB
        sta p1
        jsr V_popme
        lda PORTB
        sta p2
        jsr PRINTF
        dta c'p %2x %2x %2x',EOL,0
        dta a(p0,p1,p2)
        rts

ci      dta 0
reqs    dta $00,$40,$02,$42,$04
rq      dta 0,0
rx      dta 0,0
rn      dta 0,0
al      dta 0,0
p0      dta 0,0
p1      dta 0,0
p2      dta 0,0

        blk update address
        blk update symbols
