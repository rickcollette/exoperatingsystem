; EOS Toolkit: HEAD, the first lines of a file
;   HEAD [-n count | -count] [filename]
; The first count lines (10 when none is given) to standard output; a
; file with fewer lines is copied whole. Without a name standard input
; is read.
U_GETPAR smb 'U_GETPAR'
FOPEN    smb 'FOPEN'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

        icl 'UNIXH.icl'

        blk reloc main
start   lda #10
        sta unnum
        lda #0
        sta unnum+1
        jsr unargs
        bcs usage
        jsr unin
        bcs usage
h1      lda unnum              ; count lines left
        ora unnum+1
        beq h_end
h2      jsr FGETC
        bmi h_end
        jsr PUTC
        cmp #EOL
        bne h2
        lda unnum
        bne h3
        dec unnum+1
h3      dec unnum
        jmp h1
h_end   lda unfiles
        beq h4
        jmp FCLOSE
h4      rts
usage   jsr PRINTF
        dta c'Use: head [-n count] [filename]',EOL,0
        rts

unsw    equ *                  ; (no switches but -n)
UNSWN   equ 0
unval   dta c'N'

        icl 'UNIX.icl'
unend   equ *

        blk update address
        blk update symbols
