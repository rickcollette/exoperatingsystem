; EOS oracle test: ZCRNAME (COMTAB+3, _CRUNCH) on each parameter: COMFNAM,
; Z, FILLEN and BUFOFF.
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
EOL      equ $9B

        blk reloc main
start   jsr COMTAB+3
        php
        pla
        and #$02
        sta vz
        ldx #0
c1      lda COMTAB+$21,x
        sta buf,x
        inx
        cmp #EOL
        beq c2
        cpx #28
        bcc c1
        lda #EOL
        sta buf,x
c2      lda COMTAB+$1A
        sta vl
        lda COMTAB+$0A
        sta vb
        jsr PRINTF
        dta c'[%s] z%d l%2x b%2x',EOL,0
        dta a(buf,vz,vl,vb)
        lda vz
        beq start
        rts

vz      dta 0,0
vl      dta 0,0
vb      dta 0,0
buf     :30 dta 0

        blk update address
        blk update symbols
