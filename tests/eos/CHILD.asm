; EOS oracle test: the child of NEST.COM. Its parameter says how it ends:
; R: STATUS 5 and RTS, F: U_FAIL 7, T: U_FAIL 170, E: U_FAIL 171.
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
STATUS   smb 'STATUS'
SYSLEVEL smb 'SYSLEVEL'
COMTAB   smb 'COMTAB'
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR
        lda SYSLEVEL
        sta lv
        lda COMTAB+$21
        sta md
        jsr PRINTF
        dta c' child %c lv=%2x',EOL,0
        dta a(md,lv)
        lda md
        cmp #'R'
        bne c1
        lda #5
        sta STATUS
        rts
c1      cmp #'F'
        bne c2
        lda #7
        jmp U_FAIL
c2      cmp #'T'
        bne c3
        lda #170
        jmp U_FAIL
c3      lda #171
        jmp U_FAIL

md      dta 0,0
lv      dta 0,0

        blk update address
        blk update symbols
