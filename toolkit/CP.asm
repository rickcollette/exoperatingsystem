; EOS Toolkit: CP, copy one file to another with native quoted argv.
;   cp source destination
; Files are streamed through a fixed 256-byte buffer.  Existing destinations
; are replaced; copying a path onto itself is rejected before it is opened.
U_ARGC smb 'U_ARGC'
U_ARGV smb 'U_ARGV'
FOPEN  smb 'FOPEN'
FREAD  smb 'FREAD'
FWRITE smb 'FWRITE'
FCLOSE smb 'FCLOSE'
U_FAIL smb 'U_FAIL'
PRINTF smb 'PRINTF'
FILE_P smb 'FILE_P'

file_id equ $0760
mode    equ $0778
scan    equ $0779
attr    equ $077A
addpos  equ $0782
bytbuf  equ $0785
memreix equ $0787
EOL     equ $9B
ptr     equ $80

        blk reloc main
start   jsr U_ARGC
        cmp #2
        beq helpq
        cmp #3
        bne usage
        lda #1
        jsr getsrc
        lda #2
        jsr getdst
        ldx #0
same    lda src,x
        cmp dst,x
        bne open
        cmp #EOL
        beq self
        inx
        bne same
self    lda #129
        jmp U_FAIL
helpq   lda #1
        jsr U_ARGV
        cpy #6
        bne usage
        sta ptr
        stx ptr+1
        ldy #0
hq1     lda (ptr),y
        cmp help,y
        bne usage
        iny
        cpy #6
        bcc hq1
usage   jsr PRINTF
        dta c'Use: cp source destination',EOL,0
        rts

open    lda a_src
        ldx a_src+1
        jsr setfp
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta hin
        lda a_dst
        ldx a_dst+1
        jsr setfp
        lda #8
        sta mode
        jsr FOPEN
        lda file_id
        sta hout
read    lda hin
        sta file_id
        jsr setbuf
        jsr FREAD
        php
        lda bytbuf
        sta count
        lda bytbuf+1
        sta count+1
        plp
        bmi last
        jsr write
        jmp read
last    jsr write
        lda hin
        sta file_id
        jsr FCLOSE
        lda hout
        sta file_id
        jmp FCLOSE

write   lda count
        ora count+1
        beq wrret
        lda hout
        sta file_id
        jsr setbuf
        lda count
        sta bytbuf
        lda count+1
        sta bytbuf+1
        jsr FWRITE
wrret   rts
setbuf  lda a_buffer
        sta addpos
        lda a_buffer+1
        sta addpos+1
        lda #0
        sta bytbuf
        lda #1
        sta bytbuf+1
        lda #0
        sta memreix
        rts
setfp   sta FILE_P
        stx FILE_P+1
        rts

getsrc  jsr U_ARGV
        sta ptr
        stx ptr+1
        sty len
        ldy #0
        ldx #0
gs1     cpy len
        beq gs2
        lda (ptr),y
        sta src,x
        iny
        inx
        bne gs1
gs2     lda #EOL
        sta src,x
        rts
getdst  jsr U_ARGV
        sta ptr
        stx ptr+1
        sty len
        ldy #0
        ldx #0
gd1     cpy len
        beq gd2
        lda (ptr),y
        sta dst,x
        iny
        inx
        bne gd1
gd2     lda #EOL
        sta dst,x
        rts

help    dta c'--help'
len     dta 0
hin     dta 0
hout    dta 0
count   dta a(0)
a_src   dta a(src)
a_dst   dta a(dst)
a_buffer dta a(buffer)
src     :128 dta 0
dst     :128 dta 0
buffer  :256 dta 0

        blk update address
        blk update symbols
