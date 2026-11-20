; EOS Toolkit: DIRNAME, the device and directory part of a path
;   DIRNAME path
; Shows the path up to its last separator (: > < or backslash), after a
; > or backslash at its end is dropped: D1:>DIR>FILE.EXT gives D1:>DIR,
; D1:>FILE gives D1:>, D1:FILE gives D1:. A name alone gives an empty
; line (the current directory).
U_GETPAR smb 'U_GETPAR'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

COMFNAM  equ $21               ; (COMTAB+: the parameter)
EOL      equ $9B
BSLASH   equ $5C

        blk reloc main
start   jsr U_GETPAR
        beq usage
        ldx #0                 ; the path
d1      lda COMTAB+COMFNAM,x
        sta path,x
        inx
        cmp #EOL
        bne d1
        dex
        jsr U_GETPAR
        bne usage
        jsr strip              ; a > or backslash at the end goes
        ldy #0                 ; Y: after the last separator
        ldx #0
d2      cpx len
        bcs d3
        lda path,x
        inx
        jsr issep
        bne d2
        txa
        tay
        jmp d2
d3      tya                    ; a > or backslash there too, but D1:> and >
        tax
        jsr strip
        ldx #0
d4      cpx len
        bcs d5
        lda path,x
        jsr PUTC
        inx
        bne d4
d5      lda #EOL
        jmp PUTC
usage   jsr PRINTF
        dta c'Use: dirname path',EOL,0
        rts

* strip: len = X less a > or backslash at the end, unless it follows a
* separator or is the first character
strip   cpx #2
        bcc st1
        lda path-1,x
        cmp #'>'
        beq st0
        cmp #BSLASH
        bne st1
st0     lda path-2,x
        jsr issep
        beq st1
        dex
        bne strip
st1     stx len
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
path    :128 dta 0

        blk update address
        blk update symbols
