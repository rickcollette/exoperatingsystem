; EOS Toolkit: WC, words, lines and bytes of a text file
;   WC [/W][/L][/C] [filename]
; Without a file name standard input is read. Lines are the EOLs, a word
; ends at a space, an EOL or the end of the file. Each count is printed
; in 8 columns, words, lines, bytes, then the file name as it was given;
; the options choose which counts (none given: all three).
U_SLASH  smb 'U_SLASH'
U_GETPAR smb 'U_GETPAR'
FOPEN    smb 'FOPEN'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
EOL      equ $9B

        blk reloc main
start   ldx #12+1              ; the counts and flags to 0
s0      lda #0
        sta bytes,x
        dex
        bpl s0
        lda a_opts
        ldx a_opts+1
        ldy #6
        jsr U_SLASH
        lda opt_c
        ora opt_l
        ora opt_w
        bne s1
        dec opt_c
        dec opt_l
        dec opt_w
s1      jsr U_GETPAR
        bne s2
        lda COMTAB+7           ; no file: standard input
        sta file_id
        jmp next
s2      lda #4
        sta mode
        lda #0
        sta scan
        jsr FOPEN
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
        dta a(FILE_P)
        jsr FCLOSE
e3      jsr PRINTF
        dta b(EOL,0)
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

a_opts  dta a(opt_c)
a_bytes dta a(bytes)
opt_c   dta b(0),c'C'          ; (U_SLASH: flag, letter)
opt_l   dta b(0),c'L'
opt_w   dta b(0),c'W'
bytes   dta 0,0,0,0            ; bytes, lines, words: in the order of
lines   dta 0,0,0,0            ; the flags above, 2 bytes apart there
words   dta 0,0,0,0
inword  dta 0
named   dta 0

        blk update address
        blk update symbols
