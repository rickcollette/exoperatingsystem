; EOS oracle test: U_LOAD of CHILD.COM from a program, and what comes back
; (STATUS, U_FAIL with a status, an error caught by a trap set here, then
; an error nobody catches).
U_LOAD   smb 'U_LOAD'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'
FLAG     smb 'FLAG'
SYSLEVEL smb 'SYSLEVEL'
COMTAB   smb 'COMTAB'
EOL      equ $9B

        blk reloc main
start   lda #'R'
        jsr run
        lda #'F'
        jsr run
        lda trapv              ; T: caught by our trap
        ldx trapv+1
        jsr U_SFAIL
        lda #'T'
        jsr run
        jsr U_XFAIL
        jsr PRINTF
        dta c'no trap',EOL,0
        rts
trap    sta ra
        jsr report
        lda #'E'               ; E: nobody catches it
        jsr run
        rts

* run: CHILD.COM with parameter A
run     sta md
        sta COMTAB+$3F         ; LBUF: the child's parameter
        lda #EOL
        sta COMTAB+$40
        lda #0
        sta COMTAB+$0A         ; BUFOFF
        lda fname
        sta FILE_P
        lda fname+1
        sta FILE_P+1
        lda #0
        sta FLAG
        jsr U_LOAD
        sta ra
report  lda SYSLEVEL
        sta lv
        jsr PRINTF
        dta c'%c a=%2x lv=%2x',EOL,0
        dta a(md,ra,lv)
        rts

trapv   dta a(trap)
fname   dta a(cname)
cname   dta c'CHILD.COM',EOL
md      dta 0,0
ra      dta 0,0
lv      dta 0,0

        blk update address
        blk update symbols
