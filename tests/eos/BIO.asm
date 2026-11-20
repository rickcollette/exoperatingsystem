; EOS test: jblock_io $0706 on D1:. bm_fread sector 1 and bm_read sector 4
; (each: its status, then its first 8 bytes), bm_flush, bm_abort
; and function 6 (none: 146): their statuses.
PRINTF   smb 'PRINTF'

jblock_io equ $0706
DDEVIC   equ $0300
DUNIT    equ $0301
DBUF     equ $0304
DAUX     equ $030A
EOL      equ $9B

        blk reloc main
start   lda #4                 ; bm_fread 1
        ldx #1
        jsr xfer
        lda #0                 ; bm_read 4
        ldx #4
        jsr xfer
        ldy #2
        jsr call
        ldy #3
        jsr call
        ldy #6
call    lda #$31
        sta DDEVIC
        lda #1
        sta DUNIT
        jsr jblock_io
        sta st
        jsr PRINTF
        dta c's%b',EOL,0
        dta a(st)
        rts

xfer    pha
        stx DAUX
        lda #0
        sta DAUX+1
        lda bufa
        sta DBUF
        lda bufa+1
        sta DBUF+1
        pla
        tay
        jsr call
        jsr PRINTF
        dta c'%b %b %b %b %b %b %b %b',EOL,0
        dta a(buf,buf+1,buf+2,buf+3,buf+4,buf+5,buf+6,buf+7)
        rts

st      dta 0
bufa    dta a(buf)
buf     :128 dta 0

        blk update address
        blk update symbols
