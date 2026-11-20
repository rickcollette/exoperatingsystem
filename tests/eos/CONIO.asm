; EOS oracle test: MUL_32, DIV_32, FGETS, FPUTS, PUTS, VPRINTF and
; PUT_V. MUL_32 and DIV_32 print all 12 bytes at COMTAB+$FF afterwards, so
; what they leave in the operands shows too.
PRINTF   smb 'PRINTF'
VPRINTF  smb 'VPRINTF'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FGETS    smb 'FGETS'
FPUTS    smb 'FPUTS'
FPUTC    smb 'FPUTC'
PUTS     smb 'PUTS'
PUTC     smb 'PUTC'
MUL_32   smb 'MUL_32'
DIV_32   smb 'DIV_32'
PUT_V    smb 'PUT_V'
FILE_P   smb 'FILE_P'
U_GETPAR smb 'U_GETPAR'
COMTAB   smb 'COMTAB'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR           ; M: MUL_32 and DIV_32, else the rest
        lda COMTAB+$21
        cmp #'M'
        jne part2
        ldx #0                 ; MUL_32 and DIV_32 on the operand table
mloop   stx ci
        ldy #0
m1      lda ops,x
        sta COMTAB+$FF,y
        inx
        iny
        cpy #8
        bne m1
        lda ops,x              ; 0 multiply, 1 divide
        bne m2
        jsr MUL_32
        jmp m3
m2      jsr DIV_32
m3      php
        pla
        and #1
        sta vc
        jsr show
        lda ci
        clc
        adc #9
        tax
        cpx #9*NOPS
        bne mloop
        rts
part2

        lda fnadr              ; FGETS from a file: buffer lengths 40, 4,
        sta FILE_P             ; 40, 40 ...
        lda fnadr+1
        sta FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda #0
        sta ci
g1      ldx ci
        ldy lens,x
        beq g3
        inc ci
        ldx #39
        lda #'.'
g2      sta buf,x
        dex
        bpl g2
        lda bufadr
        ldx bufadr+1
        jsr FGETS
        php
        sta ra
        sty ry
        pla
        and #$80
        sta rn
        lda #EOL
        sta buf+39
        jsr PRINTF
        dta c'g a=%2x y=%2x n=%2x [%s]',EOL,0
        dta a(ra,ry,rn,buf)
        jmp g1
g3      jsr FCLOSE

        lda t1adr              ; PUTS: with an EOL inside the length,
        ldx t1adr+1            ; then without one
        ldy #20
        jsr PUTS
        lda t2adr
        ldx t2adr+1
        ldy #3
        jsr PUTS
        lda #EOL
        jsr PUTC

        lda vadr               ; VPRINTF and FPUTC 100 through PUT_V
        sta PUT_V
        lda vadr+1
        sta PUT_V+1
        jsr VPRINTF
        dta c'v%d',EOL,0
        dta a(n7)
        lda file_id
        pha
        lda #100
        sta file_id
        lda #'w'
        jsr FPUTC
        lda #EOL
        jsr FPUTC
        pla
        sta file_id
        rts

* vout: each character twice
vout    jsr PUTC
        jmp PUTC

* show: the 12 bytes at COMTAB+$FF as three 32-bit numbers
show    ldx #0
        ldy #3
s1      lda COMTAB+$FF,x
        sta v1,y
        lda COMTAB+$103,x
        sta v2,y
        lda COMTAB+$107,x
        sta v3,y
        inx
        dey
        bpl s1
        jsr PRINTF
        dta c'%8x %8x %8x c%d',EOL,0
        dta a(v1,v2,v3,vc)
        rts

NOPS     equ 11
ops     dta $12,$34,$56,$78, 0,0,0,$10, 0
        dta 0,0,$FF,$FF, 0,1,0,1, 0
        dta $FF,$FF,$FF,$FF, 0,0,0,2, 0
        dta 0,0,0,0, $12,$34,$56,$78, 0
        dta 0,$0F,$42,$40, 0,0,0,7, 1
        dta $FF,$FF,$FF,$FF, 0,1,0,0, 1
        dta 0,0,0,5, 0,0,0,10, 1
        dta $12,$34,$56,$78, $12,$34,$56,$78, 1
        dta 0,0,0,5, 0,0,0,0, 1
        dta 0,1,0,0, 0,1,0,0, 0
        dta $80,0,0,0, 0,0,0,2, 0
lens    dta 40,4,40,40,40,40,0
ci      dta 0
ra      dta 0,0,0,0
ry      dta 0,0,0,0
rn      dta 0,0,0,0
n7      dta 7,0,0,0
vc      dta 0,0,0,0
v1      dta 0,0,0,0
v2      dta 0,0,0,0
v3      dta 0,0,0,0
fnadr   dta a(fname)
bufadr  dta a(buf)
t1adr   dta a(t1)
t2adr   dta a(t2)
vadr    dta a(vout)
fname   dta c'LINES.TXT',EOL
t1      dta c'puts one',EOL,c'not shown'
t2      dta c'abcdef'
buf     :40 dta 0

        blk update address
        blk update symbols
