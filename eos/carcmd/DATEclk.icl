; EOS CAR: clock access shared by DATE, TIME and TD.
; The date and time live in the kernel registers date ($077B, DD MM YY)
; and time ($077E, HH MM SS). A clock driver is reached through the CLK:
; device (kernel functions 100 get, 101 set); without one, through the
; symbols I_GETTD / I_SETTD (these work on DATER/TIMER at COMTAB+13/+16,
; C=1 while the clock is busy). With neither, the registers stay as they
; are. After every read the values are copied to DATER/TIMER as well.
; Needs DATEequ.icl before the relocatable block.

; clk_dev: A = the device byte of CLK:, C=0; C=1 when there is none
clk_dev ldx #0
        ldy #0
cd1     lda DEVNAME,x
        cmp #'C'
        bne cd2
        lda DEVNAME+1,x
        cmp #'L'
        bne cd2
        lda DEVNAME+2,x
        cmp #'K'
        bne cd2
        tya
        asl @
        asl @
        asl @
        asl @
        clc
        rts
cd2     txa
        clc
        adc #4
        tax
        iny
        cpy #8
        bcc cd1
        rts                    ; C=1 here

; clk_get: the current date and time into date/time and DATER/TIMER
clk_get jsr clk_dev
        bcs cg_sym
        sta device
        ldy #100
        jsr jkernel
        cmp #0
        bpl clk_cpy
cg_sym  lda p_gettd
        ldx p_gettd+1
        jsr clk_sym
        bcs clk_cpy
        ldx #5                 ; the driver left them in DATER/TIMER
cg1     lda COMTAB+13,x
        sta date,x
        dex
        bpl cg1
; clk_cpy: date/time to DATER/TIMER
clk_cpy ldx #5
cc1     lda date,x
        sta COMTAB+13,x
        dex
        bpl cc1
        rts

; clk_set: set the clock from date/time (the registers keep the values
; when there is no clock)
clk_set jsr clk_cpy
        jsr clk_dev
        bcs cs_sym
        sta device
        ldy #101
        jsr jkernel
        cmp #0
        bpl cs_ret
cs_sym  lda p_settd
        ldx p_settd+1
        jmp clk_sym
cs_ret  rts

; clk_sym: call the routine named at AX, again while it says busy (C=1),
; 255 times at most; C=1 when there is no such symbol or it stayed busy
clk_sym jsr jfsymbol
        beq cy_no
        sta cy_jsr+1
        stx cy_jsr+2
        lda #255
        sta cy_n
cy_jsr  jsr $FFFF
        bcc cy_ret
        dec cy_n
        bne cy_jsr
cy_no   sec
cy_ret  rts

cy_n    dta 0
p_gettd dta a(s_gettd)
p_settd dta a(s_settd)
s_gettd dta c'I_GETTD '
s_settd dta c'I_SETTD '
