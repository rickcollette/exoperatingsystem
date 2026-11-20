; EOS Toolkit: MKPATH, make a directory and the ones it is in
;   MKPATH [/FV] [d:][path]
; Each directory along the path is made in turn: MKPATH A>B>C makes A,
; A>B and A>B>C (and A>..>B makes A and B). /F goes on when one is
; already there (151), else that stops it. /V prints the whole path made,
; /VV each directory as it is made. No path: the usage line.
U_SLASH  smb 'U_SLASH'
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
U_FAIL   smb 'U_FAIL'
CKSPEC   smb 'CKSPEC'
MKDIR    smb 'MKDIR'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'
COMTAB   smb 'COMTAB'

COMFNAM  equ $21               ; (COMTAB+: the parameter and its length)
FILLEN   equ $1A
name     equ $0762             ; (U_GEFINA: the name, 8+3)
ext      equ $076A
EOL      equ $9B

        blk reloc main
start   lda popts
        ldx popts+1
        ldy #4
        jsr U_SLASH
        jsr U_GETPAR
        bne go
        jsr PRINTF
        dta b(EOL),c'MKPATH [/FV] [d:][path]',b(EOL),0
        rts
go      ldx optv               ; /V once: the whole path
        inx
        bne pre
        jsr making
pre     ldx #0                 ; the path up to each separator after the
pr1     lda COMTAB+COMFNAM,x   ; first character, then the whole of it
        sta buf,x
        cpx COMTAB+FILLEN
        bcs mkone
        cmp #':'
        beq pr2
        jsr CKSPEC
        bne pr2
        pha
        txa
        pha
        lda #EOL
        sta buf,x
        jsr mkone
        pla
        tax
        pla
        sta buf,x
pr2     inx
        bpl pr1
        lda #165               ; (too long a path)
        jmp U_FAIL

* mkone: the directory in buf made; one with no name (D:, the main
* directory, ..) is left alone
mkone   lda pbuf
        sta FILE_P
        lda pbuf+1
        sta FILE_P+1
        jsr U_GEFINA
        lda name
        ora ext
        cmp #' '
        beq mk_ret
        ldx optv               ; /VV: each one
        beq mk1
        inx
        beq mk1
        jsr making
mk1     lda ptrap
        ldx ptrap+1
        jsr U_SFAIL
        jsr MKDIR
        jmp U_XFAIL
* the trap: with /F a directory already there is no error
trap    bit optf
        bpl fail
        cmp #151
        beq mk_ret
fail    jmp U_FAIL
mk_ret  rts

* making: "Making " and the name at FILE_P
making  jsr PRINTF
        dta c'Making %p',b(EOL),0
        dta a(FILE_P)
        rts

popts   dta a(optf)            ; (addresses in the program: words, which
pbuf    dta a(buf)             ; the loader relocates)
ptrap   dta a(trap)
optf    dta 0,c'F'             ; (U_SLASH: a count and the letter)
optv    dta 0,c'V'
buf     :128 dta 0

        blk update address
        blk update symbols
