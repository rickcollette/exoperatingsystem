; EOS test: an SIO driver in sio_vector ($0718) serving a drive: D8:'s
; transfers go to unit 1 (C=1: the next driver, then SIO, does them). Stays
; at $3000 after it ends; prints "installed" or "full".
EOL     equ $9B
DUNIT   equ $0301
DDEVIC  equ $0300
sio_vector equ $0718
IOCB    equ $340
CIOV    equ $E456

        opt h+
        org $3000
drv     lda DDEVIC
        cmp #$31
        bne drv_x
        lda DUNIT
        cmp #8
        bne drv_x
        lda #1
        sta DUNIT
drv_x   sec
        rts

start   ldx #0
s1      lda sio_vector+1,x
        beq s2
        inx
        inx
        cpx #8
        bcc s1
        lda #<full
        ldy #>full
        jmp print
s2      lda #<drv
        sta sio_vector,x
        lda #>drv
        sta sio_vector+1,x
        lda #<inst
        ldy #>inst
print   ldx #0
        sta IOCB+4,x
        tya
        sta IOCB+5,x
        lda #9
        sta IOCB+2,x
        lda #64
        sta IOCB+8,x
        lda #0
        sta IOCB+9,x
        jmp CIOV

inst    dta c'installed',EOL
full    dta c'full',EOL

        run start
