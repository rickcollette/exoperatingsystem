; EOS oracle test: U_PARAM (copybuf COMTAB+$BF, BUFOFF, Z) six times, then PRO_NAME on some strings (name, Z, A, Y).
PRINTF   smb 'PRINTF'
U_PARAM  smb 'U_PARAM'
PRO_NAME smb 'PRO_NAME'
COMTAB   smb 'COMTAB'

name     equ $0762
bufadr   equ $15
EOL      equ $9B

        blk reloc main
start   jsr U_PARAM
        php
        pla
        and #$02
        sta vz
        ldx #0
p1      lda COMTAB+$BF,x
        sta buf,x
        inx
        cmp #EOL
        beq p2
        cpx #30
        bcc p1
        lda #EOL
        sta buf,x
p2      lda COMTAB+$0A
        sta vb
        jsr PRINTF
        dta c'u [%s] z%d b%2x',EOL,0
        dta a(buf,vz,vb)
        dec cnt
        bne start
        ldx #0                 ; PRO_NAME on each string, from offset 0
n1      stx vi
        lda strs,x
        sta bufadr
        lda strs+1,x
        sta bufadr+1
        ldy #$FF               ; Y+1 = 0
        jsr PRO_NAME
        php
        sta va
        sty vy
        pla
        and #$02
        sta vz
        ldx #10
n2      lda name,x
        sta buf,x
        dex
        bpl n2
        lda #EOL
        sta buf+11
        jsr PRINTF
        dta c'n [%s] z%d a%2x y%2x',EOL,0
        dta a(buf,vz,va,vy)
        ldx vi
        inx
        inx
        cpx #10
        bne n1
        rts

cnt     dta 6
vz      dta 0,0
vb      dta 0,0
va      dta 0,0
vy      dta 0,0
vi      dta 0
strs    dta a(s1,s2,s3,s4,s5)
s1      dta c'FOO.BAR',EOL
s2      dta c'>DIR>X.Y Z',EOL
s3      dta c'LONGNAME9.TOOLONG',EOL
s4      dta c'A*.?',EOL
s5      dta c'D2:Q',EOL
buf     :32 dta 0

        blk update address
        blk update symbols
