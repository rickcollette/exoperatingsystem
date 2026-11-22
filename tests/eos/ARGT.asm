; EOS test: the native shell argc/argv sidecar, including quoted blanks,
; empty arguments and backslash escapes.
U_ARGC smb 'U_ARGC'
U_ARGV smb 'U_ARGV'
PUTC   smb 'PUTC'

EOL    equ $9B
ptr    equ $15

        blk reloc main
start   jsr U_ARGC
        sta count
        clc
        adc #'0'
        jsr PUTC
        lda #EOL
        jsr PUTC
        lda #0
        sta index
next    lda index
        jsr U_ARGV
        bcs done
        sta ptr
        stx ptr+1
        sty len
        lda #'['
        jsr PUTC
        ldy #0
chars   cpy len
        beq close
        lda (ptr),y
        jsr PUTC
        iny
        bne chars
close   lda #']'
        jsr PUTC
        lda #EOL
        jsr PUTC
        inc index
        lda index
        cmp count
        bcc next
done    rts

count   dta 0
index   dta 0
len     dta 0

        blk update address
        blk update symbols
