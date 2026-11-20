; EOS probe: U_GETFLG on each parameter (default $11), then what U_GETPAR
; finds after it.
PRINTF   smb 'PRINTF'
U_GETFLG smb 'U_GETFLG'
U_GETPAR smb 'U_GETPAR'
FLAG     smb 'FLAG'
COMTAB   smb 'COMTAB'
EOL      equ $9B

        blk reloc main
start   lda #$11
        jsr U_GETFLG
        php
        sta va
        pla
        sta vp
        lda FLAG
        sta v
        lda COMTAB+$0A
        sta vb
        jsr PRINTF
        dta c'f %2x a%2x p%2x b%2x',EOL,0
        dta a(v,va,vp,vb)
        dec cnt
        bne start
        rts
cnt     dta 7
v       dta 0,0
va      dta 0,0
vp      dta 0,0
vb      dta 0,0

        blk update address
        blk update symbols
