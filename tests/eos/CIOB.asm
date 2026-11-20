; EOS oracle test: CIO GET CHARACTERS on D: (plain Atari binary): 8 bytes,
; then 30 more where only 12 are left (the end of the file), then one byte
; with a length of 0 (the byte in A); after each the status, the length CIO
; returns, the bytes in the buffer, the position NOTE gives and where the
; IOCB's buffer address points (from buf).
CIOV    equ $E456
IOCB    equ $340
EOL     equ $9B

        opt h+
        org $3000
start   ldx #$10
        lda #12
        sta IOCB+2,x
        jsr CIOV
        ldx #$10               ; open D1:ABC.TXT for reading
        lda #<name
        sta IOCB+4,x
        lda #>name
        sta IOCB+5,x
        lda #3
        sta IOCB+2,x
        lda #4
        sta IOCB+10,x
        lda #0
        sta IOCB+11,x
        jsr CIOV
        lda #8
        jsr getn
        lda #30
        jsr getn
        ldx #$10               ; rewind: POINT 19, then one byte, length 0
        lda #19
        sta IOCB+12,x
        lda #0
        sta IOCB+13,x
        sta IOCB+14,x
        lda #37
        sta IOCB+2,x
        jsr CIOV
        ldx #$10
        lda #7
        sta IOCB+2,x
        lda #0
        sta IOCB+8,x
        sta IOCB+9,x
        jsr CIOV
        sta buf
        lda #EOL
        sta buf+1
        jsr report
        rts

* getn: GET CHARACTERS of A bytes into buf (cleared to '.'), then report
getn    pha
        ldx #39
        lda #'.'
gn1     sta buf,x
        dex
        bpl gn1
        lda #EOL
        sta buf+40
        ldx #$10
        lda #7
        sta IOCB+2,x
        lda #<buf
        sta IOCB+4,x
        lda #>buf
        sta IOCB+5,x
        pla
        sta IOCB+8,x
        lda #0
        sta IOCB+9,x
        jsr CIOV
* report: status, length, the buffer, the position
report  sty st
        ldx #$10
        lda IOCB+8,x
        sta len
        lda IOCB+4,x           ; the buffer address the IOCB keeps
        sec
        sbc #<buf
        sta bfo
        lda #38                ; NOTE
        sta IOCB+2,x
        jsr CIOV
        ldx #$10
        lda IOCB+12,x
        sta pos
        lda st
        ldx #0
        jsr hex
        lda len
        ldx #3
        jsr hex
        lda pos
        ldx #6
        jsr hex
        lda bfo
        ldx #9
        jsr hex
        lda #<line
        ldy #>line
        jsr print
        lda #<buf
        ldy #>buf
* print an EOL terminated line on E:
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
* hex: A as two digits at line+X
hex     pha
        lsr @
        lsr @
        lsr @
        lsr @
        jsr hd
        sta line,x
        pla
        and #$0F
        jsr hd
        sta line+1,x
        rts
hd      cmp #10
        bcc hd1
        adc #6
hd1     adc #'0'
        rts

name    dta c'D1:ABC.TXT',EOL
line    dta c'.. .. .. ..',EOL
st      dta 0
len     dta 0
pos     dta 0
bfo     dta 0
buf     :48 dta 0

        run start
