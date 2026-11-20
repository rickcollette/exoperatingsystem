; EOS test: MKDIR, RMDIR, REMOVE of a directory and a file updated in
; place (mode $0C) on D2:, each status on one line. EOS runs it on a MyDOS
; disk, SDX on an SDFS disk with the same files.
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
MKDIR    smb 'MKDIR'
RMDIR    smb 'RMDIR'
REMOVE   smb 'REMOVE'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'

mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B

        blk reloc main
start   ldx #0
s1      stx ix
        lda ops,x
        beq s2
        jsr one
        ldx ix
        inx
        inx
        inx
        bne s1
s2      jsr PRINTF
        dta EOL,0
        rts

one     lda ops+1,x
        sta FILE_P
        lda ops+2,x
        sta FILE_P+1
        lda #0
        sta scan
        sta attr
        lda trapv
        ldx trapv+1
        jsr U_SFAIL
        ldx ix
        lda ops,x
        cmp #1
        beq o_mk
        cmp #2
        beq o_rm
        cmp #3
        beq o_del
        lda #$0C               ; update: 150 bytes read twice, 10 written
        sta mode
        jsr FOPEN
        jsr rd
        jsr rd
        lda texta
        sta addpos
        lda texta+1
        sta addpos+1
        lda #10
        sta bytbuf
        jsr FWRITE
        jsr FCLOSE
        jmp ok
o_mk    jsr MKDIR
        jmp ok
o_rm    jsr RMDIR
        jmp ok
o_del   jsr REMOVE
ok      jsr U_XFAIL
        lda #1
trap    sta v
        jsr PRINTF
        dta c'%b ',0
        dta a(v)
        rts
rd      lda bufa
        sta addpos
        lda bufa+1
        sta addpos+1
        lda #150
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jmp FREAD

trapv   dta a(trap)
texta   dta a(text)
bufa    dta a(buf)
text    dta c'0123456789'
v       dta 0,0
ix      dta 0
; 1 MKDIR, 2 RMDIR, 3 REMOVE, 4 update
ops     dta 1,a(n1),1,a(n2),1,a(n1),2,a(n3),1,a(n4),2,a(n4),2,a(n5),3,a(n3)
        dta 4,a(n6),2,a(n7),0
n1      dta c'D2:NEW',EOL
n2      dta c'D2:SUB>NEW2',EOL
n3      dta c'D2:SUB',EOL
n4      dta c'D2:TMP',EOL
n5      dta c'D2:NOPE',EOL
n6      dta c'D2:BIG.DAT',EOL
n7      dta c'D2:SUB>NEW2',EOL
buf     :150 dta 0

        blk update address
        blk update symbols
