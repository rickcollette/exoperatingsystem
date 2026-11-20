; EOS CAR: core of DATE and TIME.
;   DATE [/T|dd[-mm][-yy]|mm[-dd][-yy]]
;   TIME [/T|hh[:mm][:ss]]
; Without a parameter: the current value and a prompt for a new one
; (RETURN alone keeps it). /T shows the value only; another switch sets
; the lowest value (1-01-00, 0:00:00). A value given sets the fields
; given, from the first on: blanks and '-' (DATE) or ':' (TIME) separate
; them, anything else ends them; a value out of range is reported as
; <Invalid Date> / <Invalid Time>, a parameter that is not a number is
; 156. $DAYTIME=1 puts the month first in DATE.
; IS_TIME: 0 DATE, 1 TIME (set by DATE.asm / TIME.asm).
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
GETS     smb 'GETS'
GETENV   smb 'GETENV'

LBUFF    equ $0580
EOL      equ $9B
E_BADPAR equ 156
        icl 'DATEequ.icl'

        blk reloc main
start   lda #0
        sta us
        .if IS_TIME=0
        lda p_dayt             ; $DAYTIME=1: month first
        ldx p_dayt+1
        jsr GETENV
        bmi s0
        lda LBUFF
        cmp #'1'
        bne s0
        lda LBUFF+1
        cmp #EOL
        bne s0
        inc us
        .endif
s0      jsr clk_get
        jsr U_GETPAR
        jeq ask
        lda COMTAB+$21         ; a number, or /T
        jsr isdig
        bcc cmdl
        cmp #'/'
        jne bad
        lda COMTAB+$22
        cmp #'T'
        beq show
        ldx #2                 ; another switch: the lowest value
mn1     lda lowest,x
        .if IS_TIME=0
        sta date,x
        .else
        sta time,x
        .endif
        dex
        bpl mn1
        jmp clk_set
show    jsr getf
        jsr PRINTF
        .if IS_TIME=0
        dta c'%2b-%02b-%02b',EOL,0
        .else
        dta c'%2b:%02b:%02b',EOL,0
        .endif
        dta a(f0,f1,f2)
        rts

cmdl    ldy #0                 ; the parameters, a blank between them
        sty ip
cl1     ldx #0
        ldy ip
cl2     lda COMTAB+$21,x
        cmp #EOL
        beq cl3
        sta ibuf,y
        inx
        iny
        cpy #60
        bcc cl2
        jmp bad
cl3     lda #' '
        sta ibuf,y
        iny
        sty ip
        jsr U_GETPAR
        bne cl1
        ldy ip
        lda #EOL
        sta ibuf,y
        jmp setv

ask     jsr getf
        jsr PRINTF
        .if IS_TIME=0
        dta c'Current date is: %2b-%02b-%02b',EOL,0
        .else
        dta c'Current time is: %2b:%02b:%02b',EOL,0
        .endif
        dta a(f0,f1,f2)
        .if IS_TIME=0
        lda us
        beq a_eu
        jsr PRINTF
        dta c'Enter new (MM-DD-YY): ',0
        jmp a_in
a_eu    jsr PRINTF
        dta c'Enter new (DD-MM-YY): ',0
        .else
        jsr PRINTF
        dta c'Enter new (HH:MM:SS): ',0
        .endif
a_in    lda #EOL
        sta ibuf
        lda p_ibuf
        ldx p_ibuf+1
        ldy #62
        jsr GETS
        bmi a_none
        lda ibuf
        cmp #EOL
        bne setv
a_none  rts

; setv: the numbers in ibuf replace the first fields; the first character
; that is neither a digit nor a separator ends them
setv    jsr getf
        ldx #0
        stx nn
        stx ip
sv1     ldy ip                 ; separators
        lda ibuf,y
        cmp #EOL
        beq sv_end
        jsr issep
        bcs sv2
        inc ip
        bne sv1
sv2     jsr isdig
        bcs sv_end
        lda #0                 ; the number (255 when it is bigger)
        sta nv
sv3     lda ibuf,y
        jsr isdig
        bcs sv4
        and #$0F
        sta nv+1
        lda nv
        cmp #26
        bcs sv_big
        asl @
        asl @
        adc nv
        asl @
        adc nv+1
        bcc sv3a
sv_big  lda #255
sv3a    sta nv
        iny
        bne sv3
sv4     sty ip
        ldx nn
        cpx #3
        bcs sv1
        lda nv
        sta f0,x
        inc nn
        jmp sv1
sv_end  jsr putf
        bcs inval
        jmp clk_set
inval   jsr PRINTF
        .if IS_TIME=0
        dta c'<Invalid Date>',EOL,0
        .else
        dta c'<Invalid Time>',EOL,0
        .endif
        rts

bad     lda #E_BADPAR
        jmp U_FAIL

; issep: C=0 when A separates numbers
issep   ldx #1
is1     cmp seps,x
        beq is2
        dex
        bpl is1
        sec
        rts
is2     clc
        rts
; isdig: C=0 when A is a digit
isdig   cmp #'0'
        bcc id1
        cmp #'9'+1
        rts
id1     sec
        rts

; getf: the fields f0 f1 f2 in the order shown
getf    .if IS_TIME=0
        ldx #0
        ldy #1
        lda us
        beq gf1
        ldx #1
        ldy #0
gf1     lda date,x
        sta f0
        lda date,y
        sta f1
        lda date+2
        sta f2
        .else
        ldx #2
gf1     lda time,x
        sta f0,x
        dex
        bpl gf1
        .endif
        rts

; putf: the fields back into the register, checked; C=1 when not valid
putf    .if IS_TIME=0
        ldx #0
        ldy #1
        lda us
        beq pf1
        ldx #1
        ldy #0
pf1     lda f0
        sta nd,x
        lda f1
        sta nd,y
        lda f2
        sta nd+2
        cmp #100               ; year 0-99
        bcs pf_bad
        lda nd+1               ; month 1-12
        beq pf_bad
        cmp #13
        bcs pf_bad
        tax
        lda mdays-1,x
        cpx #2                 ; February in a leap year
        bne pf2
        pha
        lda nd+2
        and #3
        bne pf3
        pla
        clc
        adc #1
        pha
pf3     pla
pf2     sta nv                 ; day 1 to the month's last
        lda nd
        beq pf_bad
        cmp nv
        beq pf4
        bcs pf_bad
pf4     ldx #2
pf5     lda nd,x
        sta date,x
        dex
        bpl pf5
        clc
        rts
        .else
        lda f0
        cmp #24
        bcs pf_bad
        lda f1
        cmp #60
        bcs pf_bad
        lda f2
        cmp #60
        bcs pf_bad
        ldx #2
pf1     lda f0,x
        sta time,x
        dex
        bpl pf1
        clc
        rts
        .endif
pf_bad  sec
        rts

        icl 'DATEclk.icl'

us      dta 0
nn      dta 0
ip      dta 0
nv      dta 0,0
f0      dta 0
f1      dta 0
f2      dta 0
nd      dta 0,0,0
        .if IS_TIME=0
seps    dta c' -'
lowest  dta b(1,1,0)
        .else
seps    dta c' :'
lowest  dta b(0,0,0)
        .endif
mdays   dta b(31,28,31,30,31,30,31,31,30,31,30,31)
n_dayt  dta c'DAYTIME',EOL
p_dayt  dta a(n_dayt)
p_ibuf  dta a(ibuf)
ibuf    :64 dta 0

        blk update address
        blk update symbols
