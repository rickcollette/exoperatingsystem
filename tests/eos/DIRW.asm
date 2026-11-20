; EOS oracle test: a directory opened for update (mode $1C): its second
; entry's name is changed in place, then the directory is listed.
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FSEEK    smb 'FSEEK'
FTELL    smb 'FTELL'
FCLOSE   smb 'FCLOSE'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'

mode     equ $0778
scan     equ $0779
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
dentry   equ $0789
EOL      equ $9B

        blk reloc main
start   jsr dspec
        lda #$1C
        sta mode
        lda #$08
        sta scan
        jsr FOPEN
        jsr rd23               ; the first entry (the header is in dentry)
        jsr rd23               ; the second: its position first
        lda pos
        sta addpos
        lda pos+1
        sta addpos+1
        lda #0
        sta addpos+2
        jsr FSEEK
        lda #'Z'               ; its name starts with Z now
        sta ent+6
        lda enta
        sta addpos
        lda enta+1
        sta addpos+1
        lda #23
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jsr FWRITE
        jsr FCLOSE
        jsr dspec2             ; list it
        lda #0
        sta scan
        jsr FFIRST
        bmi l3
l1      ldx #10
l2      lda dentry+6,x
        sta nm,x
        dex
        bpl l2
        jsr PRINTF
        dta c'[%s]',EOL,0
        dta a(nm)
        jsr FNEXT
        bpl l1
l3      jmp FCLOSE

* rd23: the next 23 bytes to ent, pos = where they were
rd23    jsr FTELL
        lda addpos
        sta pos
        lda addpos+1
        sta pos+1
        lda enta
        sta addpos
        lda enta+1
        sta addpos+1
        lda #23
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jmp FREAD

dspec   lda s1a
        sta FILE_P
        lda s1a+1
        sta FILE_P+1
        rts
dspec2  lda s2a
        sta FILE_P
        lda s2a+1
        sta FILE_P+1
        rts
s1a     dta a(s1)
s2a     dta a(s2)
s1      dta c'SUB>',EOL
s2      dta c'SUB>*.*',EOL
enta    dta a(ent)
pos     dta a(0)
ent     :23 dta 0
nm      :11 dta 0
        dta EOL

        blk update address
        blk update symbols
