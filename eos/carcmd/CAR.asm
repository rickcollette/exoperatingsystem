; EOS CAR: CAR, enter the external cartridge
;   CAR [/F|N|I|L S|A|N|I|mode] [d:][path][fname] [parameters]
; SDX's cartridge has a slot on top for another cartridge; EOS runs from an
; AtariMax cartridge, which has none. Switching EOS's cartridge off shows
; RAM at $A000-$BFFF (the internal BASIC is kept off), so CAR looks for a
; cartridge there as the OS does ($BFFC zero and not writable) and finds
; none. Should one be there (other hardware), its INIT ($BFFE) and RUN
; ($BFFA) addresses are called with EOS's cartridge off. With no
; cartridge CAR says "Not present!" (no error), as SDX does.
; With a file name the file is loaded and run with the cartridge off (an
; Atari DOS binary file, as X does it, but the screen stays below $A000);
; that also needs a cartridge, unless /F is given (for RAM at $A000, as
; on the Weronika cartridge). /N would enter the cartridge after the
; program instead of the command processor (not with /F). The default
; loading mode is A (64). /I would skip the memory save file ($CAR,
; CAR.SAV): EOS has none, so it is accepted and does nothing.
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
GETENV   smb 'GETENV'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'
PRINTF   smb 'PRINTF'
U_ERROR  smb 'U_ERROR'
XDIVIO   smb 'XDIVIO'
ERRNO    smb 'ERRNO'
_CURBANK smb '_CURBANK'
_SETBANK smb '_SETBANK'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
PORTB    equ $D301
EOL      equ $9B
BSLASH   equ $5C
        icl 'Xequ.icl'

        blk reloc main
start   tsx
        stx fe_sp
        lda #0
        sta xs_clr
        sta xs_top
        sta c_f
        sta c_n
        lda #64
        sta xs_mode
p0      jsr U_GETPAR
        beq p_none
        lda COMTAB+$21
        cmp #'/'
        bne p_name
        ldx #1
p2      lda COMTAB+$21,x
        cmp #EOL
        beq p0
        inx
        cmp #'F'
        bne p3
        sta c_f
        jmp p2
p3      cmp #'N'
        bne p3a
        sta c_n
        jmp p2
p3a     cmp #'I'
        beq p2
        cmp #'L'
        bne bad
        lda COMTAB+$21,x       ; /L: the mode is the next word
        cmp #EOL
        bne bad
        jsr U_GETPAR
        beq bad
        ldx #0
        jsr xs_lmode
        jmp p0
bad     lda #156
        jmp U_FAIL
p_name  ldx #0
p5      lda COMTAB+$21,x
        sta xs_name,x
        inx
        cmp #EOL
        bne p5
        lda c_f                ; /F: no cartridge needed
        bne p6
        jsr cart
        bcs nocart
p6      jsr xs_go
        lda c_f
        bne p7
        lda c_n
        bne enter
p7      rts
p_none  jsr cart               ; no file: the cartridge itself
        bcs nocart
enter   lda #$80
        jsr _SETBANK
        jsr c_init
        jmp ($BFFA)
c_init  jmp ($BFFE)
nocart  jsr PRINTF               ; as SDX: a message, no error
        dta c'Not present!',EOL,0
        rts

* cart: C=0 when a cartridge shows at $A000-$BFFF with EOS's cartridge off
* (and the internal BASIC off): $BFFC is 0 and does not change when written
cart    lda _CURBANK
        sta c_bank
        lda PORTB
        sta c_pb
        ora #$02
        sta PORTB
        lda #$80
        jsr _SETBANK
        ldx #1                 ; C=1: none
        lda $BFFC
        bne c1
        lda #$FF
        sta $BFFC
        lda $BFFC
        bne c0
        dex                    ; not RAM: a cartridge
c0      lda #0
        sta $BFFC
c1      lda c_bank
        jsr _SETBANK
        lda c_pb
        sta PORTB
        cpx #1
        rts

c_f     dta 0
c_n     dta 0
c_bank  dta 0
c_pb    dta 0

        icl 'Xload.icl'
        icl 'MEMferr.icl'

        blk update address
        blk update symbols
