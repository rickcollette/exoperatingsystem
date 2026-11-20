; EOS oracle test: a binary file read the way a CIO binary loader reads it
; (REMMS's): the header bytes one at a time (length 0), each segment's body
; with one GET CHARACTERS into a scratch area ($4000); for each segment its
; start, length, the status and a checksum of what arrived.
CIOV    equ $E456
IOCB    equ $340
EOL     equ $9B

        opt h+
        org $3000
start   ldx #$10
        lda #12
        sta IOCB+2,x
        jsr CIOV
        ldx #$10
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
        jsr getb               ; $FF $FF
        jsr getb
seg     jsr getb               ; start, end
        jcs done
        sta s0
        jsr getb
        sta s0+1
        and s0
        cmp #$FF
        beq seg                ; another $FFFF
        jsr getb
        sta e0
        jsr getb
        sta e0+1
        sec                    ; length = end - start + 1
        lda e0
        sbc s0
        sta ln
        lda e0+1
        sbc s0+1
        sta ln+1
        inc ln
        bne s1
        inc ln+1
s1      ldx #$10
        lda #7
        sta IOCB+2,x
        lda #0
        sta IOCB+4,x
        lda #$40
        sta IOCB+5,x
        lda ln
        sta IOCB+8,x
        lda ln+1
        sta IOCB+9,x
        jsr CIOV
        sty st
        lda #0                 ; checksum of ln bytes at $4000
        sta ck
        sta ck+1
        lda #$00
        sta $CB
        lda #$40
        sta $CC
        ldy #0
        ldx ln+1
c1      cpx #0
        beq c3
c2      lda ($CB),y
        clc
        adc ck
        sta ck
        bcc c2a
        inc ck+1
c2a     iny
        bne c2
        inc $CC
        dex
        jmp c1
c3      cpy ln
        beq c4
        lda ($CB),y
        clc
        adc ck
        sta ck
        bcc c3a
        inc ck+1
c3a     iny
        jmp c3
c4      lda s0+1
        ldx #0
        jsr hex
        lda s0
        ldx #2
        jsr hex
        lda ln+1
        ldx #5
        jsr hex
        lda ln
        ldx #7
        jsr hex
        lda st
        ldx #10
        jsr hex
        lda ck+1
        ldx #13
        jsr hex
        lda ck
        ldx #15
        jsr hex
        lda #<line
        ldy #>line
        jsr print
        jmp seg
done    rts

; getb: one byte (GET CHARACTERS of length 0: the byte in A); C=1 at the end
getb    ldx #$10
        lda #7
        sta IOCB+2,x
        lda #0
        sta IOCB+8,x
        sta IOCB+9,x
        jsr CIOV
        cpy #$80               ; C=1 at the end
        rts

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

name    dta c'D1:B.COM',EOL
line    dta c'.... .... .. ....',EOL
st      dta 0
s0      dta a(0)
e0      dta a(0)
ln      dta a(0)
ck      dta a(0)

        run start
