; EOS Toolkit: STRINGS, the text in a binary file
;   STRINGS [-n length | -length] [filename]
; Every run of at least length (4 when none is given, 1 to 255) printable
; characters goes to standard output as a line: $20 to $7C ($7D and $7E
; would clear the screen and delete). Without a name standard input is
; read.
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
start   lda #4
        sta unnum
        lda #0
        sta unnum+1
        sta run
        jsr unargs
        bcs usage
        lda unnum+1            ; 1 to 255
        bne usage
        lda unnum
        beq usage
        jsr unin
        bcs usage
s1      jsr FGETC
        bmi s_end
        cmp #$20
        bcc s_brk
        cmp #$7D
        bcs s_brk
        ldx run
        cpx unnum
        bcs s_out              ; long enough: out as it comes
        sta pend,x
        inx
        stx run
        cpx unnum
        bne s1
        ldx #0                 ; now long enough: what was kept
s2      lda pend,x
        jsr PUTC
        inx
        cpx run
        bne s2
        beq s1
s_out   jsr PUTC
        jmp s1
s_brk   jsr s_eol
        jmp s1
s_end   jsr s_eol
        lda unfiles
        beq s3
        jmp FCLOSE
s3      rts
usage   jsr PRINTF
        dta c'Use: strings [-n length] [filename]',EOL,0
        rts
* s_eol: the run ends: an EOL after one that was shown
s_eol   ldx run
        cpx unnum
        bne se1
        lda #EOL
        jsr PUTC
se1     lda #0
        sta run
        rts

unsw    equ *                  ; (no switches but -n)
UNSWN   equ 0
unval   dta c'N'
run     dta 0
pend    :255 dta 0

        icl 'UNIX.icl'
unend   equ *

        blk update address
        blk update symbols
