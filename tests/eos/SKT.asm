; EOS speed test: 120 seeks in D1:BIG.DAT (300 KiB), each FSEEK to a
; position 39999 bytes further (round the file) and one byte read, then
; "done". (Run between two TCKs: tools/speed.py.)
FOPEN    smb 'FOPEN'
FSEEK    smb 'FSEEK'
FREAD    smb 'FREAD'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'

mode     equ $0778
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B
SZ0      equ $00               ; 307200 = $04B000
SZ1      equ $B0
SZ2      equ $04
ST0      equ $3F               ; 39999 = $009C3F
ST1      equ $9C

        blk reloc main
start   lda fna
        sta FILE_P
        lda fna+1
        sta FILE_P+1
        lda #4
        sta mode
        jsr FOPEN
        lda #120
        sta n
s1      lda pos                ; seek
        sta addpos
        lda pos+1
        sta addpos+1
        lda pos+2
        sta addpos+2
        jsr FSEEK
        lda bufa
        sta addpos
        lda bufa+1
        sta addpos+1
        lda #0
        sta addpos+2
        sta memreix
        sta bytbuf+1
        lda #1
        sta bytbuf
        jsr FREAD
        clc                    ; the next position, round the file
        lda pos
        adc #ST0
        sta pos
        lda pos+1
        adc #ST1
        sta pos+1
        lda pos+2
        adc #0
        sta pos+2
        lda pos
        cmp #SZ0
        lda pos+1
        sbc #SZ1
        lda pos+2
        sbc #SZ2
        bcc s2
        lda pos                ; past the end: back by the size
        sbc #SZ0
        sta pos
        lda pos+1
        sbc #SZ1
        sta pos+1
        lda pos+2
        sbc #SZ2
        sta pos+2
s2      dec n
        bne s1
        jsr FCLOSE
        jsr PRINTF
        dta c'done',EOL,0
        rts

fna     dta a(fname)
fname   dta c'D1:BIG.DAT',EOL
bufa    dta a(buf)
buf     dta 0
pos     dta 0,0,0
n       dta 0

        blk update address
        blk update symbols
