; EOS Toolkit: HEXDEC, a 32-bit number in decimal and in hex
;   HEXDEC number
; A decimal number, or a hex one after a $, printed as "decimal = $hex":
; the hex in whole bytes from the highest one that is not 0. Digits past
; 32 bits wrap around; the number ends at the first character that is no
; digit. No number, or none after the $: the usage line.
U_GETPAR smb 'U_GETPAR'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

COMFNAM  equ $21               ; (COMTAB+: the parameter)
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR
        beq usage
        ldx #3
        lda #0
s0      sta num,x
        dex
        bpl s0
        ldx #0
        lda COMTAB+COMFNAM
        cmp #'$'
        beq hex
        jsr digit              ; decimal: at least one digit
        bcs usage
dec1    pha                    ; num = num * 10 + the digit
        jsr times2
        ldy #3
dec2    lda num,y
        sta tmp,y
        dey
        bpl dec2
        jsr times2
        jsr times2
        clc
        ldy #0
dec3    lda num,y
        adc tmp,y
        sta num,y
        iny
        tya
        eor #4
        bne dec3
        pla
        jsr add
        inx
        lda COMTAB+COMFNAM,x
        jsr digit
        bcc dec1
        bcs show
hex     inx                    ; hex: at least one digit after the $
        lda COMTAB+COMFNAM,x
        jsr hexdig
        bcs usage
hex1    pha                    ; num = num * 16 + the digit
        ldy #4
hex2    jsr times2
        dey
        bne hex2
        pla
        jsr add
        inx
        lda COMTAB+COMFNAM,x
        jsr hexdig
        bcc hex1
        bcs show
usage   jsr PRINTF
        dta c'Use: hexdec [number]',EOL,0
        rts

* show: "decimal = $hex"
show    ldy #3                 ; the hex bytes, from the highest non-zero one
sh1     lda num,y
        bne sh2
        dey
        bne sh1
sh2     ldx #0
sh3     lda num,y
        lsr @
        lsr @
        lsr @
        lsr @
        jsr hexout
        lda num,y
        and #$0F
        jsr hexout
        dey
        bpl sh3
        lda #0
        sta hbuf,x
        ldx #0                 ; the decimal digits, lowest first, by
sh4     lda #0                 ; repeated division by 10
        sta rem
        ldy #32
sh5     asl num
        rol num+1
        rol num+2
        rol num+3
        rol rem
        lda rem
        cmp #10
        bcc sh6
        sbc #10
        sta rem
        inc num
sh6     dey
        bne sh5
        lda rem
        ora #'0'
        sta tmp,x              ; (tmp: 10 digits at most, reversed)
        inx
        lda num
        ora num+1
        ora num+2
        ora num+3
        bne sh4
        ldy #0
sh7     dex
        lda tmp,x
        sta dbuf,y
        iny
        txa
        bne sh7
        lda #0
        sta dbuf,y
        jsr PRINTF
        dta c'%s = $%s',EOL,0
        dta a(dbuf,hbuf)
        rts
hexout  cmp #10
        bcc ho1
        adc #'A'-10-1-'0'      ; (C=1)
ho1     adc #'0'
        sta hbuf,x
        inx
        rts

* times2: num = num * 2 (32 bits); keeps X, Y
times2  asl num
        rol num+1
        rol num+2
        rol num+3
        rts
* add: num = num + A; keeps X
add     clc
        adc num
        sta num
        bcc ad1
        inc num+1
        bne ad1
        inc num+2
        bne ad1
        inc num+3
ad1     rts
* digit: A a decimal digit: C=0 and A its value; C=1 not one
digit   cmp #'0'
        bcc dg_no
        cmp #'9'+1
        bcs dg_no
        sbc #'0'-1             ; (C=0)
        clc
        rts
dg_no   sec
        rts
* hexdig: A a hex digit (0-9, A-F, a-f): C=0 and A its value; C=1 not one
hexdig  jsr digit
        bcc hd_ret
        and #$DF               ; (a-f as A-F)
        cmp #'A'
        bcc dg_no
        cmp #'F'+1
        bcs dg_no
        sbc #'A'-10-1          ; (C=0)
        clc
hd_ret  rts

num     dta 0,0,0,0
tmp     :10 dta 0
rem     dta 0
dbuf    :11 dta 0
hbuf    :9 dta 0

        blk update address
        blk update symbols
