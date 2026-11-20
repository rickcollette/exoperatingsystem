; EOS oracle test: CIO D: (plain Atari binary, no SDX library).
; Reads D1:HELLO.TXT on IOCB 1 by records and D:HELLO.TXT by bytes, echoing
; to E:; prints the CIO status of each step and of a missing file.
CIOV    equ $E456
IOCB    equ $340
EOL     equ $9B

        opt h+
        org $3000
start   ldx #$10
        jsr close
        lda #<name1
        ldy #>name1
        jsr open
        jsr status
rec     ldx #$10               ; get record into buf
        lda #5
        sta IOCB+2,x
        lda #<buf
        sta IOCB+4,x
        lda #>buf
        sta IOCB+5,x
        lda #64
        sta IOCB+8,x
        lda #0
        sta IOCB+9,x
        jsr CIOV
        bmi rec_end
        lda #<buf
        ldy #>buf
        jsr print
        jmp rec
rec_end jsr status
        ldx #$10
        jsr close
        lda #<name2
        ldy #>name2
        jsr open
byte    ldx #$10               ; get bytes, one at a time
        lda #7
        sta IOCB+2,x
        lda #0
        sta IOCB+8,x
        sta IOCB+9,x
        jsr CIOV
        bmi byte_end
        ldx #0
        jsr putch
        jmp byte
byte_end jsr status
        ldx #$10
        jsr close
        lda #<name3
        ldy #>name3
        jsr open
        jsr status
        ldx #$10
        jsr close
        rts

open    ldx #$10
        sta IOCB+4,x
        tya
        sta IOCB+5,x
        lda #3
        sta IOCB+2,x
        lda #4
        sta IOCB+10,x
        lda #0
        sta IOCB+11,x
        jmp CIOV
close   lda #12
        sta IOCB+2,x
        jmp CIOV
* print "status N" for the status in Y
status  tya
        ldx #0
st1     cmp #100
        bcc st2
        sbc #100
        inx
        bne st1
st2     pha
        txa
        ora #'0'
        sta stat+7
        pla
        ldx #0
st3     cmp #10
        bcc st4
        sbc #10
        inx
        bne st3
st4     ora #'0'
        sta stat+9
        txa
        ora #'0'
        sta stat+8
        lda #<stat
        ldy #>stat
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
putch   pha
        lda #11
        sta IOCB+2,x
        lda #0
        sta IOCB+8,x
        sta IOCB+9,x
        pla
        jmp CIOV

name1   dta c'D1:HELLO.TXT',EOL
name2   dta c'D:HELLO.TXT',EOL
name3   dta c'D1:NONE.TXT',EOL
stat    dta c'status 000',EOL
buf     :64 dta 0

        run start
