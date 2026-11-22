; EOS Toolkit: WC, words, lines and bytes of a text file
;   wc [-wlc] [filename]
; Without a file name standard input is read. Lines are the EOLs, a word
; ends at a space, an EOL or the end of the file. Each count is printed
; in 8 columns, words, lines, bytes, then the file name as it was given;
; the options choose which counts (none given: all three).
U_GETPAR smb 'U_GETPAR'
U_ARGV   smb 'U_ARGV'
TOLOWER  smb 'TOLOWER'
FOPEN    smb 'FOPEN'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

        icl 'UNIXH.icl'

        blk reloc main
start   lda #$FF
        jsr U_ARGV
        ldx #12+1              ; the counts and flags to 0
s0      lda #0
        sta bytes,x
        dex
        bpl s0
        jsr unargs
        jcs usage
        lda opt_c
        ora opt_l
        ora opt_w
        bne s1
        dec opt_c
        dec opt_l
        dec opt_w
s1      jsr unin
        jcs usage
        lda unfiles
        beq next
        dec named
next    jsr FGETC
        bmi end
        ldx #0
        jsr inc32              ; a byte
        cmp #EOL
        beq n_eol
        cmp #' '
        beq n_sep
        lda #$FF               ; in a word
        sta inword
        bne next
n_eol   ldx #4
        jsr inc32              ; a line
n_sep   bit inword
        bpl next
        jsr word
        jmp next
end     bit inword             ; a word up to the end
        bpl e0
        jsr word
e0      ldx #4                 ; words, lines, bytes as chosen
e1      lda opt_c,x
        bpl e2
        txa
        asl @
        adc a_bytes            ; (C=0)
        sta pr_arg
        lda a_bytes+1
        adc #0
        sta pr_arg+1
        jsr PRINTF
        dta c'%8l',0
pr_arg  dta a(0)
e2      dex
        dex
        bpl e1
        bit named
        bpl e3
        jsr PRINTF
        dta c' %p',0
        dta a(a_unames)
        jsr FCLOSE
e3      jsr PRINTF
        dta b(EOL,0)
        rts
usage   jsr PRINTF
        dta c'Use: wc [-wlc] [filename]',EOL,0
        rts

* word: one more word, none open
word    ldx #8
        jsr inc32
        lda #0
        sta inword
        rts
* inc32: the count at bytes+X plus 1; keeps A
inc32   inc bytes,x
        bne i1
        inc bytes+1,x
        bne i1
        inc bytes+2,x
        bne i1
        inc bytes+3,x
i1      rts

a_bytes dta a(bytes)
unsw
opt_c   dta b(0),c'c'
opt_l   dta b(0),c'l'
opt_w   dta b(0),c'w'
UNSWN   equ *-unsw
unval   dta 0
bytes   dta 0,0,0,0            ; bytes, lines, words: in the order of
lines   dta 0,0,0,0            ; the flags above, 2 bytes apart there
words   dta 0,0,0,0
inword  dta 0
named   dta 0
        icl 'UNIX.icl'
unend   equ *

        blk update address
        blk update symbols
