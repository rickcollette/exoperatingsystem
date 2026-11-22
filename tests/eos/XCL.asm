; EOS native test: XCOMLI consumes all 127 public command-line bytes.
XCOMLI smb 'XCOMLI'
COMTAB smb 'COMTAB'
EOL equ $9B

        blk reloc main
start   ldx #0
x1      lda prefix,x
        sta COMTAB+$3F,x
        inx
        cpx #5
        bcc x1
        lda #'x'
x2      sta COMTAB+$3F,x
        inx
        cpx #127
        bcc x2
        lda #EOL
        sta COMTAB+$3F,x
        jmp XCOMLI
prefix  dta c'echo '

        blk update address
        blk update symbols
