; EOS probe: SLEEP with A, X, Y from a table; jiffies (RTCLOK) it took.
PRINTF   smb 'PRINTF'
SLEEP    smb 'SLEEP'
RTCLOK   equ $12
EOL      equ $9B

        blk reloc main
start   ldx #0
s1      stx vi
        lda RTCLOK+2
        sta t0
        lda RTCLOK+1
        sta t0+1
        lda tab,x
        sta va
        lda tab+1,x
        sta vx
        lda tab+2,x
        sta vy
        lda va
        ldx vx
        ldy vy
        jsr SLEEP
        sec
        lda RTCLOK+2
        sbc t0
        sta d
        lda RTCLOK+1
        sbc t0+1
        sta d+1
        jsr PRINTF
        dta c'a%2x x%2x y%2x: %d',EOL,0
        dta a(va,vx,vy,d)
        ldx vi
        inx
        inx
        inx
        cpx #3*6
        bne s1
        rts

vi      dta 0
va      dta 0,0
vx      dta 0,0
vy      dta 0,0
t0      dta 0,0
d       dta 0,0
tab     dta 0,0,0, 10,0,0, 50,0,0, 0,1,0, 0,0,1, 1,1,0

        blk update address
        blk update symbols
