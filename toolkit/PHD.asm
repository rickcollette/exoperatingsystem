; EOS Toolkit: PHD, save the current directory, then change directory
;   PHD [d:path]
; The current device and its directory go to the environment variable
; _OLDWD (as DSKA:\SUB, for PLD), then the parameter is used as by CDD:
; the directory and the current drive change to it.
DEVNAME  smb 'DEVNAME'
CURDEV   smb 'CURDEV'
FILE_P   smb 'FILE_P'
GETCWD   smb 'GETCWD'
PUTENV   smb 'PUTENV'
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
CHDIR    smb 'CHDIR'

device   equ $0761
path     equ $0640             ; (GETCWD: the path, $00 ended)
EOL      equ $9B

        blk reloc main
start   lda CURDEV             ; the device: its name's first three letters
        pha                    ; (DEVNAME has four for each, the device
        and #$F0               ; number in the high nibble) and the unit as
        lsr @                  ; a letter, A for 1 (and for none)
        lsr @
        tax
        ldy #0
dn      lda DEVNAME,x
        sta val,y
        inx
        iny
        cpy #3
        bcc dn
        pla
        and #$0F
        bne unit
        lda #1
unit    ora #$40
        sta val,y
        iny
        lda #':'
        sta val,y
        iny
        sty pos
        lda pcur               ; the directory on the current device
        sta FILE_P
        lda pcur+1
        sta FILE_P+1
        jsr GETCWD
        lda path               ; the main directory: /
        bne cwd
        lda #'/'
        sta path
        lda #0
        sta path+1
cwd     ldx #0
        ldy pos
cw1     lda path,x
        sta val,y
        beq cw2
        cmp #EOL
        beq cw2
        inx
        iny
        cpy #64
        bcc cw1
cw2     lda #EOL
        sta val,y
        lda pvar
        ldx pvar+1
        jsr PUTENV
        jsr U_GETPAR           ; then as CDD
        beq done
        jsr U_GEFINA
        lda device
        sta CURDEV
        jsr CHDIR
done    rts

pcur    dta a(cur)             ; (addresses in the program: words, which
pvar    dta a(var)             ; the loader relocates)
cur     dta c':',EOL
pos     dta 0
var     dta c'_OLDWD='
val     :65 dta 0

        blk update address
        blk update symbols
