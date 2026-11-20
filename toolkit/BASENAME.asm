; EOS Toolkit: BASENAME, the name part of a path
;   BASENAME path [suffix]
; Shows what follows the path's last separator (: > < or backslash),
; after a > or backslash at its end is dropped (D1:>DIR>SUB> gives SUB);
; with suffix, without it at the end when the name is longer. A device or
; the main directory alone (D1:, D1:>) gives an empty line.
U_GETPAR smb 'U_GETPAR'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

COMFNAM  equ $21               ; (COMTAB+: the parameter)
EOL      equ $9B
BSLASH   equ $5C

        blk reloc main
start   jsr U_GETPAR
        jeq usage
        ldx #0                 ; the path
b1      lda COMTAB+COMFNAM,x
        sta path,x
        inx
        cmp #EOL
        bne b1
        dex
        stx len
        lda #0
        sta slen
        jsr U_GETPAR           ; the suffix
        beq b3
        ldx #0
b2      lda COMTAB+COMFNAM,x
        sta suf,x
        inx
        cmp #EOL
        bne b2
        dex
        stx slen
        jsr U_GETPAR
        jne usage
b3      ldx len                ; a > or \ at the end goes
b4      cpx #2
        bcc b5
        lda path-1,x
        cmp #'>'
        beq b4a
        cmp #BSLASH
        bne b5
b4a     lda path-2,x
        jsr issep
        beq b5
        dex
        bne b4
b5      stx len
        ldy #0                 ; the name: after the last separator
        ldx #0
b6      cpx len
        bcs b7
        lda path,x
        inx
        jsr issep
        bne b6
        txa
        tay
        jmp b6
b7      sty start0
        lda slen               ; the suffix at the end, the name longer
        beq b9
        lda len
        sec
        sbc start0
        cmp slen
        beq b9
        bcc b9
        lda len
        sec
        sbc slen
        tax
        ldy #0
b8      lda path,x
        cmp suf,y
        bne b9
        inx
        iny
        cpy slen
        bcc b8
        lda len
        sec
        sbc slen
        sta len
b9      ldx start0
b10     cpx len
        bcs b11
        lda path,x
        jsr PUTC
        inx
        bne b10
b11     lda #EOL
        jmp PUTC
usage   jsr PRINTF
        dta c'Use: basename path [suffix]',EOL,0
        rts

* issep: Z=1 when A is a separator (: > < or backslash)
issep   cmp #':'
        beq is1
        cmp #'>'
        beq is1
        cmp #'<'
        beq is1
        cmp #BSLASH
is1     rts

len     dta 0
slen    dta 0
start0  dta 0
path    :128 dta 0
suf     :128 dta 0

        blk update address
        blk update symbols
