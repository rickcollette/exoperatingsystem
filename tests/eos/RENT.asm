; EOS oracle test: RENDIR, RENAME on a directory, CHVOL, U_GETFLG on the
; parameters, ERRNO after a caught error.
PRINTF   smb 'PRINTF'
MKDIR    smb 'MKDIR'
RENDIR   smb 'RENDIR'
RENAME   smb 'RENAME'
CHVOL    smb 'CHVOL'
GETDFREE smb 'GETDFREE'
U_GETFLG smb 'U_GETFLG'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
FILE_P   smb 'FILE_P'
FLAG     smb 'FLAG'
ERRNO    smb 'ERRNO'

scan     equ $0779
path     equ $07A0
EOL      equ $9B

        blk reloc main
start   lda #$11               ; U_GETFLG on each parameter, default $11
        jsr U_GETFLG
        lda FLAG
        sta v
        jsr PRINTF
        dta c'f %2x',EOL,0
        dta a(v)
        dec cnt
        bne start

        ldx #0                 ; MKDIR OLD, RENDIR OLD NEW
        jsr spec
        jsr MKDIR
        ldx #2
        jsr spec
        jsr RENDIR
        jsr PRINTF
        dta c'rendir',EOL,0
        lda trapv              ; RENAME NEW XX: a directory, an error
        ldx trapv+1
        jsr U_SFAIL
        ldx #4
        jsr spec
        lda #0
        sta scan
        jsr RENAME
        jsr U_XFAIL
        jsr PRINTF
        dta c'rename ok',EOL,0
        jmp vol
trap    sta v
        lda ERRNO
        sta v+1
        jsr PRINTF
        dta c'rename err %b errno %b',EOL,0
        dta a(v,v+1)
vol     ldx #6                 ; CHVOL NEWVOL, GETDFREE
        jsr spec
        jsr CHVOL
        ldx #8
        jsr spec
        jsr GETDFREE
        lda #EOL
        sta path+14
        jsr PRINTF
        dta c'vol [%s]',EOL,0
        dta a(path+6)
        rts

spec    lda names,x
        sta FILE_P
        lda names+1,x
        sta FILE_P+1
        rts

trapv   dta a(trap)
names   dta a(s1,s2,s3,s4,s5)
s1      dta c'OLD',EOL
s2      dta c'OLD NEW',EOL
s3      dta c'NEW XX',EOL
s4      dta c'D1:NEWVOL',EOL
s5      dta c'D1:',EOL
v       dta 0,0,0,0
cnt     dta 6

        blk update address
        blk update symbols
