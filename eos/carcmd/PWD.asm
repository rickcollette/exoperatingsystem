; EOS CAR: PWD, the current directory of every drive that answers
;   PWD
; Drives A: up to the one $MAXDRV names (O: without it); one line each,
; the drive (its letter, or Dn: when a CIO device has the letter), the
; path from the main directory and a > at the end.
; Drives that give an error are left out.
GETCWD   smb 'GETCWD'
GETENV   smb 'GETENV'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'
_DRVNAME smb '_DRVNAME'
_DRVNM   smb '_DRVNM'

path     equ $07A0
LBUFF    equ $0580
EOL      equ $9B

        blk reloc main
start   lda #15                ; the last drive: $MAXDRV, else O:
        sta last
        lda mxa
        ldx mxa+1
        jsr GETENV
        bmi s0
        lda LBUFF
        cmp #'A'
        bcc s0
        cmp #'O'+1
        bcs s0
        sbc #'A'-2             ; (C=0: A is 1)
        sta last
s0      lda nma                ; each drive by its name (_DRVNAME)
        sta FILE_P
        lda nma+1
        sta FILE_P+1
        lda #1
        sta drv
d1      lda drv
        jsr _DRVNAME
        lda trapv              ; an error: the drive is left out
        ldx trapv+1
        jsr U_SFAIL
        jsr GETCWD
        jsr U_XFAIL
        jsr PRINTF
        dta c'%s%s>',EOL,0
        dta a(_DRVNM,path)
        jmp next
trap
next    inc drv
        lda last
        cmp drv
        bcs d1
        rts

trapv   dta a(trap)
nma     dta a(_DRVNM)
mxa     dta a(mxname)
last    dta 0
drv     dta 0
mxname  dta c'MAXDRV',EOL

        blk update address
        blk update symbols
