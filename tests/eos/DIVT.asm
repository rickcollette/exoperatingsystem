; EOS oracle test: DIVIO/XDIVIO. Output to OUT.TXT (new, then appended),
; read back; input from IN.TXT until its end (which ends the redirection).
PRINTF   smb 'PRINTF'
DIVIO    smb 'DIVIO'
XDIVIO   smb 'XDIVIO'
GETS     smb 'GETS'
FOPEN    smb 'FOPEN'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
PUTC     smb 'PUTC'
FILE_P   smb 'FILE_P'
COMTAB   smb 'COMTAB'

mode     equ $0778
scan     equ $0779
EOL      equ $9B

        blk reloc main
start   lda COMTAB+6
        sta h0
        lda COMTAB+7
        sta h1
        ldx #0                 ; output to OUT.TXT
        jsr spec
        ldy #0
        jsr DIVIO
        jsr PRINTF
        dta c'first line',EOL,0
        ldy #0
        jsr XDIVIO
        ldx #0                 ; appended
        jsr spec
        ldy #2
        jsr DIVIO
        jsr PRINTF
        dta c'appended',EOL,0
        ldy #0
        jsr XDIVIO
        jsr PRINTF
        dta c'out %2x in %2x',EOL,0
        dta a(h0,h1)
        ldx #0                 ; OUT.TXT back
        jsr spec
        lda #4
        sta mode
        lda #0
        sta scan
        jsr FOPEN
t1      jsr FGETC
        bmi t2
        jsr PUTC
        jmp t1
t2      jsr FCLOSE
        ldx #2                 ; input from IN.TXT
        jsr spec
        ldy #1
        jsr DIVIO
g1      lda bufa
        ldx bufa+1
        ldy #40
        jsr GETS
        bmi g2
        jsr PRINTF
        dta c'got [%s]',EOL,0
        dta a(buf)
        jmp g1
g2      lda COMTAB+7
        sta h1
        jsr PRINTF
        dta c'end, in %2x',EOL,0
        dta a(h1)
        rts

spec    lda names,x
        sta FILE_P
        lda names+1,x
        sta FILE_P+1
        rts

names   dta a(s_out,s_in)
s_out   dta c'OUT.TXT',EOL
s_in    dta c'IN.TXT',EOL
h0      dta 0,0
h1      dta 0,0
bufa    dta a(buf)
buf     :40 dta 0

        blk update address
        blk update symbols
