; EOS Toolkit: INVERSE, a filter: standard input to standard output with
; bit 7 of every character set (inverse video)
;   ECHO text | INVERSE | MORE
;   INVERSE <<file
; Without redirected input it reads the keyboard, up to CTRL-3 or BREAK.
GETC     smb 'GETC'
PUTC     smb 'PUTC'

        blk reloc main
start   jsr GETC
        bmi done
        ora #$80
        jsr PUTC
        jmp start
done    rts

        blk update address
        blk update symbols
