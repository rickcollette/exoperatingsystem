; EOS CAR: MAP, which disk unit a drive letter reaches
;   MAP [unit] [SIO|OS|NORMAL|OFF] [d:]   or   MAP [d:]fname[.ext]
; A first parameter that is a number: d: (the current drive when none is
; given) becomes disk unit 'unit' in MAP's own table (_MAPTAB: SWAP's
; sio_index is apart, as on SDX), and the drive's entry is shown: K:=3,
; with SIO or OFF after it when the drive has that mode. A mode given
; alone changes the mode (NORMAL clears it). Only units 1-15 are stored
; (16 and up are shown, but would name another device here). The kernel
; sends a disk request for the drive to its unit, in its mode: NORMAL as
; usual (PBI devices, then SIO), SIO without the PBI devices, OFF not at
; all (138); the transfer speed is SIOSET's. OS: "OS cannot be used in
; OSRAM mode!" and nothing changes (EOS has no OS mode).
; Anything else first names a text file of such lines (nothing shown).
; Without parameters: the usage and each drive's unit.
U_GETPAR smb 'U_GETPAR'
_DRVNAME smb '_DRVNAME'
_DRVNM   smb '_DRVNM'
_DRVLET  smb '_DRVLET'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FGETC    smb 'FGETC'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
COMTAB2  smb 'COMTAB2'
CURDEV   smb 'CURDEV'
_MAPTAB  smb '_MAPTAB'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
EOL      equ $9B
E_BADPARM equ 156

        blk reloc main
start   ldy COMTAB+$0A         ; the rest of the command line, in capitals
        ldx #0
s1      lda COMTAB+$3F,y
        jsr upper
        sta line,x
        iny
        inx
        cmp #EOL
        bne s1
        lda #0
        sta lpos
        jsr token
        bne s2
        jsr PRINTF             ; no parameters: the usage and the table
        dta c'Usage:',EOL
        dta c'MAP [unit] [SIO|OS|NORMAL|OFF] [d:]',EOL,0
        ldx #1
s1a     stx drv
        lda _MAPTAB-1,x
        sta unit
        txa                    ; the drive's name: A:, or Dn: when a CIO
        jsr _DRVNAME           ; device has the letter
        jsr PRINTF
        dta c'%s=%b',0
        dta a(_DRVNM,unit)
        ldx drv
        jsr mshow
        ldx drv
        inx
        cpx #16
        bcc s1a
        rts
s2      jsr number             ; a number first: MAP parameters
        bcs s_file
        lda #0
        sta lpos
        lda #1
        sta echo
        jmp doline

* the file: each line as MAP parameters
s_file  ldx #0                 ; the name kept (what follows is not used)
sfa     lda tok,x
        sta fnm,x
        inx
        cmp #EOL
        bne sfa
        lda #0
        sta echo
        lda fna
        sta FILE_P
        lda fna+1
        sta FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta hnd
f1      ldx #0
        stx eof
f2      stx lx
        lda hnd
        sta file_id
        jsr FGETC
        bpl f3
        inc eof
        lda #EOL
f3      jsr upper
        ldx lx
        sta line,x
        cmp #EOL
        beq f4
        cpx #63
        bcs f2
        inx
        bne f2
f4      lda #0
        sta lpos
        jsr doline
        lda eof
        beq f1
        lda hnd
        sta file_id
        jmp FCLOSE

* doline: the MAP parameters in line (an empty line does nothing)
doline  lda #0
        sta uset
        sta drv
        sta mmode
        sta ntok
dl1     jsr token
        beq dl_do
        inc ntok
        jsr kind
        cmp #K_UNIT
        bne dl2
        lda val
        sta unit
        inc uset
        jmp dl1
dl2     cmp #K_MODE
        bne dl3
        lda val
        sta mmode
        jmp dl1
dl3     cmp #K_DRV
        bne dl_bad
        lda val
        sta drv
        jmp dl1
dl_bad  lda #E_BADPARM
        jmp U_FAIL
dl_do   lda ntok
        bne dl0
        rts
dl0     lda drv                ; no drive: the current one
        bne dl1a
        lda CURDEV
        cmp #$10
        bcs dl0a
        and #$0F
        bne dl0b
dl0a    lda #1
dl0b    sta drv
dl1a    ldx drv
        lda _MAPTAB-1,x        ; shown: the entry as it is
        sta shown
        lda mmode              ; OS: not here
        cmp #3
        bne dl3a
        jsr PRINTF
        dta c'OS cannot be used in OSRAM mode!',EOL,0
        jmp dl_show
dl3a    lda mmode              ; a change: the drive's cached sectors
        ora uset               ; written to the old unit first
        beq dl4
        ldy #2                 ; (bm_flush)
        jsr blk
        lda mmode
        cmp #0                 ; a mode: kept (NORMAL 1 is kept as 0)
        beq dl4
        cmp #1
        bne dl3b
        lda #0
dl3b    sta _MAPTAB+14,x
dl4     lda uset               ; the drive gets the unit
        beq dl_show
        lda unit
        sta shown
        beq dl_show
        cmp #16
        bcs dl_show
        sta _MAPTAB-1,x
dl_show lda mmode              ; changed: cached sectors forgotten, read
        ora uset               ; again from the new unit
        beq dl_sh1
        ldy #3                 ; (bm_abort)
        jsr blk
dl_sh1  lda echo
        beq dl_ret
        lda drv
        jsr _DRVNAME
        jsr PRINTF
        dta c'%s=%b',0
        dta a(_DRVNM,shown)
        ldx drv
        jmp mshow
dl_ret  rts

* blk: jblock_io function Y for drive drv (the FMS's cache for it); keeps
* nothing but drv
blk     lda #$31
        sta $0300              ; DDEVIC
        lda drv
        sta $0301              ; DUNIT
        jsr $0706              ; jblock_io
        ldx drv
        rts

* mshow: drive X's mode (SIO, OFF) and the end of the line
mshow   lda _MAPTAB+14,x
        cmp #2
        bne ms1
        jsr PRINTF
        dta c' SIO',0
        jmp ms2
ms1     cmp #4
        bne ms2
        jsr PRINTF
        dta c' OFF',0
ms2     jsr PRINTF
        dta EOL,0
        rts

* token: the next word of line to tok (EOL ended); Z=1 when none
token   ldy lpos
tk1     lda line,y
        cmp #' '
        beq tk2
        cmp #','
        bne tk3
tk2     iny
        bne tk1
tk3     ldx #0
tk4     lda line,y
        cmp #EOL
        beq tk5
        cmp #' '
        beq tk5
        cmp #','
        beq tk5
        sta tok,x
        iny
        inx
        cpx #63
        bcc tk4
tk5     sty lpos
        lda #EOL
        sta tok,x
        txa
        rts

K_FILE  equ 0
K_UNIT  equ 1
K_MODE  equ 2
K_DRV   equ 3
* kind: what tok is: K_UNIT (val 1-15), K_MODE (val 1 NORMAL, 2 SIO,
* 3 OS, 4 OFF), K_DRV (val the drive 1-15), else K_FILE
kind    jsr number             ; digits only: a unit
        bcs kd1
        sta val
        lda #K_UNIT
        rts
kd1     ldx #0                 ; a mode
        stx kn
kd2     stx kx
        inc kn
        ldy #0
kd3     lda modes,x
        beq kd5
        cmp tok,y
        bne kd4
        inx
        iny
        cmp #EOL
        bne kd3
        lda kn                 ; NORMAL 1, SIO 2, OS 3, OFF 4
        sta val
        lda #K_MODE
        rts
kd4     ldx kx                 ; the next name
kd4a    lda modes,x
        inx
        cmp #EOL
        bne kd4a
        beq kd2
kd5     ldx #0                 ; a drive: X:, Dn:, n: with n 1-15
kd6     lda tok,x
        cmp #EOL
        beq kd_file
        inx
        cmp #':'
        bne kd6
        lda tok,x
        cmp #EOL
        bne kd_file
        dex
        cpx #1
        bne kd7
        lda tok                ; one character: a letter A-O or digit
        cmp #'A'
        bcc kd8
        jsr _DRVLET            ; (D: is D1:, a CIO device's letter not a
        bcs kd_file            ; drive)
        jmp kd_drv
kd7     lda tok                ; D and a number or a letter
        cmp #'D'
        bne kd_file
        cpx #2
        bne kd9
        lda tok+1
        cmp #'A'
        bcc kd8
        cmp #'O'+1
        bcs kd_file
        sbc #'A'-2
        jmp kd_drv
kd8     cmp #'1'
        bcc kd_file
        cmp #'9'+1
        bcs kd_file
        and #$0F
        jmp kd_drv
kd9     cpx #3                 ; D10: ... D15:
        bne kd_file
        lda tok+1
        cmp #'1'
        bne kd_file
        lda tok+2
        cmp #'0'
        bcc kd_file
        cmp #'5'+1
        bcs kd_file
        and #$0F
        adc #10                ; C=0
kd_drv  sta val
        lda #K_DRV
        rts
kd_file lda #K_FILE
        rts

* number: tok as a decimal number up to 255 in A, C=0; C=1 not one
number  lda #0
        sta val
        tax
        lda tok
        cmp #EOL
        beq nu_no
nu1     lda tok,x
        cmp #EOL
        beq nu_ok
        cmp #'0'
        bcc nu_no
        cmp #'9'+1
        bcs nu_no
        and #$0F
        pha
        lda val
        cmp #26
        bcs nu_big
        asl @
        asl @
        adc val
        asl @
        sta val
        pla
        adc val
        bcs nu_no
        sta val
        inx
        bne nu1
nu_big  pla
nu_no   sec
        rts
nu_ok   lda val
        clc
        rts

* upper: A in capitals
upper   cmp #'a'
        bcc up1
        cmp #'z'+1
        bcs up1
        and #$DF
up1     rts

fna     dta a(fnm)
hnd     dta 0
eof     dta 0
lx      dta 0
lpos    dta 0
kx      dta 0
val     dta 0
unit    dta 0
drv     dta 0
mmode   dta 0
uset    dta 0
ntok    dta 0
echo    dta 0
shown   dta 0
modes   dta c'NORMAL',EOL,c'SIO',EOL,c'OS',EOL,c'OFF',EOL,0
kn      dta 0
line    :130 dta 0
tok     :65 dta 0
fnm     :65 dta 0

        blk update address
        blk update symbols
