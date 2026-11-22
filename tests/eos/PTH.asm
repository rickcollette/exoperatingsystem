; EOS oracle test: what U_LOAD leaves in path ($0640) for the program, as
; bytes up to the first $00 or EOL, and that byte.
PRINTF   smb 'PRINTF'
path     equ $0640
EOL      equ $9B

        blk reloc main
start   ldx #0
p1      lda path,x
        beq p2
        cmp #EOL
        beq p2
        sta buf,x
        inx
        cpx #63
        bcc p1
p2      sta vt
        lda #EOL
        sta buf,x
        jsr PRINTF
        dta c'p [%s] %2x',EOL,0
        dta a(buf,vt)
        rts
vt      dta 0,0
buf     :64 dta 0

        blk update address
        blk update symbols
