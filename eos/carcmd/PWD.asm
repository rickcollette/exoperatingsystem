; EOS CAR: PWD, the current directory of the active drive
;   PWD
; The drive in native Dn: notation, the path from the main directory, and a
; slash at the end.
GETCWD   smb 'GETCWD'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'
CURDEV   smb 'CURDEV'

path     equ $0640
EOL      equ $9B

        blk reloc main
start   lda #<empty            ; resolve GETCWD on the active drive
        sta FILE_P
        lda #>empty
        sta FILE_P+1
        lda CURDEV
        and #$0F
        cmp #10
        bcc digit
        adc #'A'-2             ; C=1: drive 10 is J
        bne named
digit   ora #'0'
named   sta drvname+1
        jsr GETCWD
        jsr PRINTF
        dta c'%s%s/',EOL,0
        dta a(drvname,path)
        rts

empty   dta b(EOL)
drvname dta c'D1:',b(EOL)

        blk update address
        blk update symbols
