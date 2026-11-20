; EOS Toolkit: NVWGL, a clock's NV-RAM on the screen
;   NVWGL
; The 256 bytes of NV-RAM (through the clock driver's I_NVRAM: X the
; address; C=0 read to A, C=1 write A; C=1 back on an error) as 16 rows
; of 16 hex bytes, "--" where a byte cannot be read; under them 32 bytes
; from the cursor as characters, and the cursor's address in hex and in
; decimal. The screen is drawn from the end backwards (each character
; printed moves the cursor left), and only bytes that changed, the cursor
; and the cell it left are drawn again. Keys: the arrows move the cursor,
; two hex digits (0-9, A-F) write a byte there and move on, any other key
; drops a first digit, the space bar ends.
I_NVRAM  smb 'I_NVRAM'
PUTC     smb 'PUTC'
U_GETKEY smb 'U_GETKEY'

ROWCRS   equ $54
COLCRS   equ $55
CRSINH   equ $02F0
CH       equ $02FC
CLS      equ $7D
ESC      equ $1B
EOL      equ $9B

        blk reloc main
start   ldx #0                 ; nothing known yet: all to be drawn
        txa
i1      sta val,x
        sta known,x
        sta redraw,x
        inx
        bne i1
        lda #$80               ; the cursor at 0
        sta redraw
        lda #1
        sta CRSINH
        jsr clear

* the screen, then a key
draw    lda #23                ; the cursor's address: decimal, then hex
        sta COLCRS
        lda #21
        sta ROWCRS
        lda #0
        sta inv
        lda dec
        jsr hex2
        lda dec+1
        jsr hex1
        dec COLCRS
        dec COLCRS
        dec COLCRS
        lda cur
        jsr hex2
        dec ROWCRS             ; 32 characters from the cursor, row 19
        dec ROWCRS
        lda #4
        sta COLCRS
        lda cur
        sta adr
d1      ldx adr
        jsr nvread
        bcc d2
        lda #' '
d2      jsr char
        inc adr
        lda COLCRS
        cmp #36
        bcc d1
        dec ROWCRS             ; the bytes, row 17 up, 255 down to 0
d3      dec ROWCRS
        lda #35
        sta COLCRS
d4      lda #0                 ; the cursor's byte inverse
        sta inv
        dec gadr
        lda gadr
        cmp cur
        bne d5
        lda #$80
        sta inv
d5      ldx gadr
        lda redraw,x
        bne d6
        lda known,x            ; not to be drawn, "--" already there
        and #$40
        bne d9
d6      jsr nvread
        ldx gadr
        bcc d7
        lda known,x            ; no value: "--"
        ora #$40
        sta known,x
        jsr drawn
        lda #'-'
        jsr putinv
        lda #'-'
        jsr putinv
        jmp d10
d7      ldy known,x            ; the same value as drawn: left as it is
        bpl d8
        ldy redraw,x
        bne d8
        cmp val,x
        beq d9
d8      sta val,x
        lda known,x
        ora #$80
        sta known,x
        jsr drawn
        lda val,x
        jsr hex2
        jmp d10
d9      jsr left               ; two columns on
        jsr left
d10     bpl d4                 ; (N: past the row's start)
        lda gadr
        bne d3

k1      lda CH                 ; a key
        cmp #$FF
        beq k1
        jsr U_GETKEY
        cmp #' '
        bne k2
        lda #0                 ; space: the end
        sta CRSINH
        jmp clear
k2      cmp #'0'               ; a hex digit
        bcc k4
        cmp #'9'+1
        bcc k3
        cmp #'A'
        bcc k4
        cmp #'F'+1
        bcs k4
        sbc #'A'-'9'-1-1       ; (C=0)
k3      and #$0F
        asl digit
        asl digit
        asl digit
        asl digit
        ora digit
        sta digit
        lsr second
        bcs k3a                ; the second one: written
        lda #2                 ; (1 after the key's end below)
        sta second
        bne kend
k3a     ldx cur
        sec
        jsr I_NVRAM
        lda #1
        bne fwd
k4      cmp #$1C               ; an arrow: up, down 16; left, right 1
        bcc kend
        cmp #$20
        bcs kend
        and #3
        ror @
        bne k5
        lda #16
k5      pha
        php
        ldx cur                ; the cell left is drawn again
        lda #$40
        sta redraw,x
        plp
        pla
        bcs fwd
        sta step
        sec
        lda cur
        sbc step
        jmp move
fwd     clc
        adc cur
move    sta cur
        tax
        lda #$80
        sta redraw,x

* kend: the cursor's address in decimal (BCD) for the next drawing; a
* first digit is dropped unless this key was it
kend    lda cur
        ldx #0
        ldy #0
ke1     cmp #100
        bcc ke2
        sbc #100
        inx
        bne ke1
ke2     cmp #10
        bcc ke3
        sbc #10
        iny
        bne ke2
ke3     sta dec
        tya
        asl @
        asl @
        asl @
        asl @
        ora dec
        sta dec
        stx dec+1
        lsr second
        jmp draw

* nvread: byte X of the NV-RAM; C=1 an error
nvread  clc
        jmp I_NVRAM

* drawn: byte X is drawn: not again unless it is the cursor's
drawn   lda redraw,x
        bmi dr1
        lda #0
        sta redraw,x
dr1     rts

* hex2: A as two hex digits, the low one first, leftwards; hex1: the low
* digit alone
hex2    pha
        jsr hex1
        pla
        lsr @
        lsr @
        lsr @
        lsr @
hex1    and #$0F
        cmp #10
        bcc hx1
        adc #'A'-10-'0'-1      ; (C=1)
hx1     adc #'0'
* putinv: A printed (inverse when the cursor's), the cursor one left of
* where it was; left: one column left; N=1 when past column 4
putinv  ora inv
        jsr PUTC
        dec COLCRS
left    dec COLCRS
        ldy COLCRS
        cpy #4
        rts

* char: A as a character: the screen's control codes after an ESC so
* that they show, and EOL as the ESC character
char    pha
        and #$7F
        ldx #7
ch1     cmp ctrl,x
        beq ch2
        dex
        bpl ch1
        pla
        jmp PUTC
ch2     lda #ESC
        jsr PUTC
        pla
        cmp #EOL
        bne ch3
        lda #ESC
ch3     jmp PUTC

clear   lda #CLS
        jmp PUTC

ctrl    dta $1B,$1C,$1D,$1E,$1F,$7D,$7E,$7F
cur     dta 0                  ; the cursor's address
adr     dta 0                  ; the characters' address,
gadr    dta 0                  ; the bytes' (from 0 down)
inv     dta 0
digit   dta 0
second  dta 0
step    dta 0
dec     dta 0,0
val     :256 dta 0             ; each byte as drawn,
known   :256 dta 0             ; bit 7 drawn, bit 6 "--" drawn,
redraw  :256 dta 0             ; $80 the cursor, $40 to be drawn again

        blk update address
        blk update symbols
