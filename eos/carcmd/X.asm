; EOS CAR: X, run a program without cartridges
;   X [/C|L S|A|N|I|mode] [d:][path]fname[.ext] [parameters]
; The program (an Atari DOS binary file; .COM when no extension is given,
; from the current directory or along $PATH) is loaded and run with the
; cartridge off and the screen at the top of memory (RAMTOP $C0), so
; $A000-$BFFF is free for it; the parameters after its name stay on the
; command line for it. /C clears $80-$FF, $0400-$06FF and MEMLO-MEMTOP
; first ($X containing C does the same without /C, and /C then turns it
; off). /L and the next word choose the loading mode: S 0 (the default:
; INIT and RUN, or the first segment without RUN), A 64 (only with RUN),
; N 128 (neither), I 192 (INIT only), or the number; anything else leaves
; the default. Without a program name X shows how to use it. A missing
; program gives 170 without naming it (as SDX). See Xload.icl.
U_GETPAR smb 'U_GETPAR'
U_GETNUM smb 'U_GETNUM'
U_FAIL   smb 'U_FAIL'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
GETENV   smb 'GETENV'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'
PRINTF   smb 'PRINTF'
U_ERROR  smb 'U_ERROR'
XDIVIO   smb 'XDIVIO'
ERRNO    smb 'ERRNO'
_CURBANK smb '_CURBANK'
_SETBANK smb '_SETBANK'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B
BSLASH   equ $5C
        icl 'Xequ.icl'

        blk reloc main
start   tsx
        stx fe_sp
        lda #0
        sta xs_clr
        sta xs_mode
        lda #1
        sta xs_top
        lda x_xa               ; $X with a C in it: clearing by default
        ldx x_xa+1
        jsr GETENV
        bmi p0
        ldx #0
pc1     lda $0580,x
        cmp #EOL
        beq p0
        inx
        cmp #'C'
        beq pc2
        cmp #'c'
        bne pc1
pc2     lda #1
        sta xs_clr
p0      jsr U_GETPAR
        bne p1
        jsr PRINTF             ; no program named: how to use X
        dta c'Use: X [/C][/L mode] cmd [parms]',EOL,0
        rts
bad     lda #156
        jmp U_FAIL
p1      lda COMTAB+$21
        cmp #'/'
        bne p_name
        ldx #1
p2      lda COMTAB+$21,x
        cmp #EOL
        beq p0
        inx
        cmp #'C'
        bne p3
        lda xs_clr
        eor #1
        sta xs_clr
        jmp p2
p3      cmp #'L'
        bne bad
        lda COMTAB+$21,x       ; /L: the mode is the next word
        cmp #EOL
        bne bad
        jsr U_GETPAR
        beq bad
        ldx #0
        jsr xs_lmode
        jmp p0
p_name  ldx #0
p5      lda COMTAB+$21,x
        sta xs_name,x
        inx
        cmp #EOL
        bne p5
        jmp xs_go

x_xa    dta a(x_xn)
x_xn    dta c'X',EOL

        icl 'Xload.icl'
        icl 'MEMferr.icl'

        blk update address
        blk update symbols
