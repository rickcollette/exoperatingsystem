; EOS test: jsector_io with memreix and with an XDCB. D1:'s sector 1 read
; to a program extended bank (MALLOC index 4, memreix), its first 8 bytes
; shown through V_setme; then as an XDCB ($B1) to main memory; then an
; XDCB with a 24-bit sector number (184). Each: s<status>, then bytes.
PRINTF   smb 'PRINTF'
MALLOC   smb 'MALLOC'

jsector_io equ $070C
V_setme  equ $07F1
V_popme  equ $07F4
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUF     equ $0304
DTIMLO   equ $0306
DBYT     equ $0308
DAUX     equ $030A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B
zp       equ $80

        blk reloc main
start   lda #0
        sta bytbuf
        lda #1
        sta bytbuf+1
        ldx #$04
        ldy #0
        jsr MALLOC
        bpl s1
        jsr PRINTF
        dta c'nomem',EOL,0
        rts
s1      stx mx
        lda #$31
        ldx addpos
        ldy addpos+1
        jsr dcb
        lda mx
        sta memreix
        jsr io
        lda mx                 ; the bytes, out of the bank
        jsr V_setme
        ldy #7
s2      lda (zp),y
        sta buf,y
        dey
        bpl s2
        jsr V_popme
        jsr show
        lda #0
        sta memreix
        lda #$B1               ; an XDCB to main memory
        ldx bufa
        ldy bufa+1
        jsr dcb
        jsr io
        jsr show
        lda #$B1               ; sector 65537: not for SIO
        ldx bufa
        ldy bufa+1
        jsr dcb
        lda #1
        sta DAUX+2
        jsr io
        rts

* dcb: device A, buffer YX, sector 1, 128 bytes; zp = the buffer
dcb     sta DDEVIC
        stx DBUF
        stx zp
        sty DBUF+1
        sty zp+1
        lda #1
        sta DUNIT
        sta DAUX
        lda #0
        sta DAUX+1
        sta DAUX+2
        sta DAUX+3
        sta DAUX+4
        sta DAUX+5
        lda #'R'
        sta DCOMND
        lda #$40
        sta DSTATS
        lda #7
        sta DTIMLO
        lda #128
        sta DBYT
        lda #0
        sta DBYT+1
        rts
io      jsr jsector_io
        sta st
        jsr PRINTF
        dta c's%b',EOL,0
        dta a(st)
        rts
show    jsr PRINTF
        dta c'%b %b %b %b %b %b %b %b',EOL,0
        dta a(buf,buf+1,buf+2,buf+3,buf+4,buf+5,buf+6,buf+7)
        rts

mx      dta 0
st      dta 0
bufa    dta a(buf)
buf     :128 dta 0

        blk update address
        blk update symbols
