; EOS test: an Atari DOS binary (on the test disk as HX.EXE): prints "ram"
; when $A000 is RAM (a cartridge off, as X leaves it), else "rom".
CIOV    equ $E456
IOCB    equ $340
EOL     equ $9B

        opt h+
        org $3000
start   lda $A000
        eor #$FF
        sta $A000
        cmp $A000
        php
        eor #$FF
        sta $A000
        plp
        beq s1
        lda #<rom
        ldy #>rom
        bne s2
s1      lda #<ram
        ldy #>ram
s2      ldx #0
        sta IOCB+4,x
        tya
        sta IOCB+5,x
        lda #9
        sta IOCB+2,x
        lda #8
        sta IOCB+8,x
        lda #0
        sta IOCB+9,x
        jmp CIOV
ram     dta c'ram',EOL
rom     dta c'rom',EOL

        run start
