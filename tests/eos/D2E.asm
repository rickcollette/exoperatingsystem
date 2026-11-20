; EOS test: a file opened for update ($0C) on an Atari DOS 2 / MyDOS disk
; does not grow: 100 bytes written to D2:A.TXT (60 bytes) end in 136.
FOPEN    smb 'FOPEN'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
U_SFAIL  smb 'U_SFAIL'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B

        blk reloc main
start   lda namea
        sta FILE_P
        lda namea+1
        sta FILE_P+1
        lda #$0C
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta h
        lda trapv
        ldx trapv+1
        jsr U_SFAIL
        lda texta
        sta addpos
        lda texta+1
        sta addpos+1
        lda #100
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jsr FWRITE
        lda #1
trap    sta v
        lda h
        sta file_id
        jsr FCLOSE
        jsr PRINTF
        dta c'end %b',EOL,0
        dta a(v)
        rts

trapv   dta a(trap)
namea   dta a(name)
texta   dta a(text)
name    dta c'D2:A.TXT',EOL
h       dta 0
v       dta 0,0
text    :100 dta c'x'

        blk update address
        blk update symbols
