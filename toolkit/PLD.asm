; EOS Toolkit: PLD, back to the directory PHD saved
;   PLD
; PHD keeps the drive and directory in the environment variable _OLDWD;
; PLD changes to it and removes the variable. Without one nothing is done.
GETENV   smb 'GETENV'
PUTENV   smb 'PUTENV'
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
CHDIR    smb 'CHDIR'
CURDEV   smb 'CURDEV'
COMTAB   smb 'COMTAB'

BUFOFF   equ $0A               ; (COMTAB+: the command line and where the
LBUF     equ $3F               ; next parameter starts)
device   equ $0761
envval   equ $0580             ; (GETENV: the value)
EOL      equ $9B

        blk reloc main
start   lda pname
        ldx pname+1
        jsr GETENV
        bmi done
        ldx #0                 ; the value becomes the command line
copy    lda envval,x
        sta COMTAB+LBUF,x
        inx
        cmp #EOL
        bne copy
        lda pname              ; the name alone: the variable goes
        ldx pname+1
        jsr PUTENV
        lda #0
        sta COMTAB+BUFOFF
        jsr U_GETPAR
        beq done
        jsr U_GEFINA
        lda device
        sta CURDEV
        jsr CHDIR
done    rts

pname   dta a(vname)           ; (addresses in the program: words, which
vname   dta c'_OLDWD',EOL      ; the loader relocates)

        blk update address
        blk update symbols
