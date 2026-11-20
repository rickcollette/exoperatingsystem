; EOS oracle test: copy a file (parameters: source, destination) with
; FREAD/FWRITE in 100-byte pieces; the destination is compared on disk.
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
U_GETPAR smb 'U_GETPAR'
FILE_P   smb 'FILE_P'
COMTAB   smb 'COMTAB'
PRINTF   smb 'PRINTF'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR           ; source
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta hin
        jsr U_GETPAR           ; destination
        lda #8
        sta mode
        jsr FOPEN
        lda file_id
        sta hout
c1      lda hin
        sta file_id
        jsr setbuf
        jsr FREAD
        php
        lda bytbuf
        sta n
        lda bytbuf+1
        sta n+1
        plp
        bmi c2                 ; the end (what was read still counts)
        jsr wr
        jmp c1
c2      jsr wr
        lda hin
        sta file_id
        jsr FCLOSE
        lda hout
        sta file_id
        jsr FCLOSE
        jsr PRINTF
        dta c'copied',EOL,0
        rts
wr      lda n
        ora n+1
        beq w1
        lda hout
        sta file_id
        jsr setbuf
        lda n
        sta bytbuf
        lda n+1
        sta bytbuf+1
        jsr FWRITE
w1      rts
setbuf  lda bufa
        sta addpos
        lda bufa+1
        sta addpos+1
        lda #100
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        rts

hin     dta 0
hout    dta 0
n       dta a(0)
bufa    dta a(buf)
buf     :100 dta 0

        blk update address
        blk update symbols
