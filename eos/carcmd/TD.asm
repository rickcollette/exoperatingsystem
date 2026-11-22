; EOS CAR: TD, the time/date line
;   TD [ON|OFF]
; The first call stays resident (TD alone installs it with the line off)
; and says TD installed. Another word, or a second one, is 156.
; A deferred vertical blank routine shows the date and time in a text line
; at the top of the screen: when the display list begins with 24 blank
; scan lines, a short list of its own (8 blank lines, the text line, 8
; blank lines) takes their place and jumps on into the rest. The clock is
; read through I_GETTD (a clock driver) every 10 frames; without one the
; kernel's date/time registers are shown. $DAYTIME=1 at the time of the
; call gives the American format. The last character shows the keyboard
; state: X capitals, x lower case, Control in inverse video.
; Symbols defined: I_TDON (A = 0 off, else on) and I_FMTTD (Y/X = a
; buffer of 32 bytes: the date and time as text with an EOL, C=0).
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
INSTALL  smb 'INSTALL'
S_ADDIZ  smb 'S_ADDIZ'
S_ADD    smb 'S_ADD'
SYMBOL   smb 'SYMBOL'
EXTENDED smb 'EXTENDED'
GETENV   smb 'GETENV'
        icl 'DATEequ.icl'

CRITIC   equ $42
VVBLKD   equ $0224
SDLSTL   equ $0230
INVFLG   equ $02B6
SHFLOK   equ $02BE
LBUFF    equ $0580
EOL      equ $9B
E_BADPAR equ 156

        blk reloc main
start   lda #$FF               ; the parameter: $FF none, 1 ON, 0 OFF
        sta want
        jsr U_GETPAR
        beq s2
        lda #1
        lda COMTAB+$21
        and #$DF
        tax
        lda COMTAB+$22
        and #$DF
        tay
        lda #1
        cpx #'O'
        bne s_bad
        cpy #'N'
        bne s1
        ldy COMTAB+$23
        cpy #EOL
        beq s1a
s_bad   lda #E_BADPAR
        jmp U_FAIL
s1      tya
        and #$DF
        tay
        cpy #'F'
        bne s_bad
        lda COMTAB+$23
        and #$DF
        tay
        cpy #'F'
        bne s_bad
        ldy COMTAB+$24
        cpy #EOL
        bne s_bad
        lda #0
s1a     sta want
        jsr U_GETPAR           ; one parameter only
        bne s_bad
s2      lda #0                 ; $DAYTIME=1: American format
        sta us
        lda p_dayt
        ldx p_dayt+1
        jsr GETENV
        bmi s3
        lda LBUFF
        cmp #'1'
        bne s3
        lda LBUFF+1
        cmp #EOL
        bne s3
        inc us
s3      lda p_ntdon            ; installed already: through I_TDON
        ldx p_ntdon+1
        jsr jfsymbol
        beq inst
        sta s_upd+1            ; the installed copy takes the format
        stx s_upd+2
        lda want
        cmp #$FF
        beq s_ret
        ldx us
s_upd   jmp $FFFF
s_ret   rts

inst    jsr place
        lda want               ; off unless ON is given
        cmp #1
        beq i1
        lda #0
i1      sta ton
        lda #1
        sta cnt
        jsr hook
        lda p_hook
        ldx p_hook+1
        jsr S_ADDIZ
        lda p_ntdon            ; the symbols I_TDON and I_FMTTD
        ldx p_ntdon+1
        ldy #0
        jsr addsym
        lda p_nfmt
        ldx p_nfmt+1
        ldy #2
        jsr addsym
        dec INSTALL
        jsr PRINTF
        dta c'TD installed',EOL,0
        rts

; addsym: the symbol named at AX, its address the word at p_tdon+Y
addsym  sta as_rd+1
        stx as_rd+2
        ldx #7
as_rd   lda $FFFF,x
        sta SYMBOL+2,x
        dex
        bpl as_rd
        lda p_tdon,y
        sta SYMBOL+$0B
        lda p_tdon+1,y
        sta SYMBOL+$0C
        lda #0
        sta EXTENDED
        jmp S_ADD

; place: the text line (40 bytes, not across a 4K boundary) and the display
; list (8 bytes, not across a 1K boundary) in area
place   lda p_area
        sta line
        lda p_area+1
        sta line+1
        clc                    ; line+39 in the next 4K: from that 4K on
        lda line
        adc #39
        tax
        lda line+1
        adc #0
        eor line+1
        and #$F0
        beq pl1
        lda line+1
        adc #$10-1             ; (C=0 here; +$0F, then the low bits off)
        and #$F0
        sta line+1
        lda #0
        sta line
pl1     clc
        lda line
        adc #40
        sta dl
        lda line+1
        adc #0
        sta dl+1
        clc                    ; dl+7 in the next 1K: from that 1K on
        lda dl
        adc #7
        lda dl+1
        adc #0
        eor dl+1
        and #$FC
        beq pl2
        clc
        lda dl+1
        adc #4
        and #$FC
        sta dl+1
        lda #0
        sta dl
pl2     lda line               ; the code that writes them
        sta v_ln+1
        lda line+1
        sta v_ln+2
        lda dl
        sta pl_dl+1
        lda dl+1
        sta pl_dl+2
        clc                    ; the jump at dl+5, written by the VBI
        lda dl
        adc #5
        sta v_jw+1
        lda dl+1
        adc #0
        sta v_jw+2
        ldx #4                 ; 8 blank, text, 7 blank, jump
pl3     lda dltab,x
pl_dl   sta $FFFF,x
        dex
        bpl pl3
        ldx #0                 ; the text address
        lda line
        jsr pl_put
        lda line+1
        ldx #1
        jsr pl_put
        lda #' '               ; blank text
        sta tbuf
        lda #EOL
        sta tbuf+1
        jmp v_show
pl_put  pha                    ; byte X of the address after $42
        lda dl
        clc
        adc #2
        sta pp_st+1
        lda dl+1
        adc #0
        sta pp_st+2
        pla
pp_st   sta $FFFF,x
        rts

; hook: the VBI routine in (again after a RESET)
hook    lda VVBLKD
        cmp p_vb
        bne h1
        lda VVBLKD+1
        cmp p_vb+1
        beq h_ret
h1      lda CRITIC             ; no deferred VBI while the vector changes
        pha
        lda #1
        sta CRITIC
        lda VVBLKD
        sta v_os+1
        lda VVBLKD+1
        sta v_os+2
        lda p_vb
        sta VVBLKD
        lda p_vb+1
        sta VVBLKD+1
        pla
        sta CRITIC
h_ret   rts

; ---- resident ---------------------------------------------------------------

; I_TDON: A = 0 off, else on (X = 1: American format, when called by TD)
tdon    stx us
        cmp #0
        beq td1
        lda #1
td1     sta ton
        jsr findclk
        lda #1
        sta cnt
        clc
        rts

; findclk: the address of I_GETTD (0: none)
findclk lda p_ngettd
        ldx p_ngettd+1
        jsr jfsymbol
        bne fc1
        lda #0
        tax
fc1     sta gettd
        stx gettd+1
        rts

; I_FMTTD: Y/X = a 32-byte buffer: the date and time, EOL ended
fmttd   sty ft_st+1
        stx ft_st+2
        jsr clk_get
        jsr format
        ldx #0
ft1     lda tbuf,x
ft_st   sta $FFFF,x
        inx
        cmp #EOL
        bne ft1
        clc
        rts

; the deferred VBI
vbi     lda ton
        beq v_off
        lda SDLSTL             ; our list in use?
        cmp dl
        bne v_chk
        lda SDLSTL+1
        cmp dl+1
        beq v_upd
v_chk   lda SDLSTL             ; another list: 24 blank lines first?
        sta v_rd+1
        lda SDLSTL+1
        sta v_rd+2
        ldx #2
v_rd    lda $FFFF,x
        cmp #$70
        bne v_os
        dex
        bpl v_rd
        lda #$01               ; ours instead, jumping to its 4th byte
        sta jb
        lda SDLSTL
        sta odl
        clc
        adc #3
        sta jb+1
        lda SDLSTL+1
        sta odl+1
        adc #0
        sta jb+2
        ldx #2
v_j1    lda jb,x
v_jw    sta $FFFF,x
        dex
        bpl v_j1
        lda dl
        sta SDLSTL
        lda dl+1
        sta SDLSTL+1
v_os    jmp $FFFF              ; the old VVBLKD (set at install; no JMP () that
                               ; a vector at $xxFF would break)
v_off   lda SDLSTL             ; off: the old list back
        cmp dl
        bne v_os
        lda SDLSTL+1
        cmp dl+1
        bne v_os
        lda odl
        sta SDLSTL
        lda odl+1
        sta SDLSTL+1
        jmp v_os
v_upd   dec cnt
        bne v_os
        lda #10
        sta cnt
        lda gettd+1            ; the clock driver: into DATER/TIMER
        beq v_reg
        sta v_get+2
        lda gettd
        sta v_get+1
v_get   jsr $FFFF
        bcs v_os               ; busy: next time
        ldx #5
v_g1    lda COMTAB+13,x
        sta date,x
        dex
        bpl v_g1
v_reg   jsr format
        jsr v_show
        jmp v_os

; v_show: tbuf centred into the text line, as screen codes, and the
; keyboard state in the last column but one
v_show  ldx #39
        lda #0
vs1     jsr v_put
        dex
        bpl vs1
        ldx #0
vs2     lda tbuf,x
        cmp #EOL
        beq vs3
        inx
        bne vs2
vs3     stx vs_n               ; start column (40 - length) / 2
        sec
        lda #40
        sbc vs_n
        lsr @
        tay
        ldx #0
vs4     lda tbuf,x
        cmp #EOL
        beq vs5
        jsr scr
        sty vs_y
        stx vs_x
        ldx vs_y
        jsr v_put
        ldx vs_x
        ldy vs_y
        iny
        inx
        bne vs4
vs5     lda #'X'               ; the keyboard state
        bit SHFLOK
        bvs vs6
        bmi vs7
        lda #'x'
        bne vs6
vs7     lda #'X'+$80
vs6     jsr scr
        ldx #38
v_put
v_ln    sta $FFFF,x
        rts

; scr: ATASCII A to the screen code (inverse video kept)
scr     pha
        and #$7F
        cmp #$20
        bcs sc1
        adc #$40               ; $00-$1F: $40-$5F
        bne sc3
sc1     cmp #$60
        bcs sc3                ; $60-$7F: the same
        sbc #$20-1             ; $20-$5F: $00-$3F (C=0 here)
sc3     sta sc_v
        pla
        and #$80
        ora sc_v
        rts

; format: date and time from the registers into tbuf, EOL ended
format  ldx #0
        lda us
        bne fo_us
        lda date               ; DD-MM-YY HH:MM:SS
        jsr two
        jsr dash
        lda date+1
        jsr two
        jsr dash
        lda date+2
        jsr two
        lda #' '
        jsr putb
        lda time
        jsr two
        jsr colon
        lda time+1
        jsr two
        jsr colon
        lda time+2
        jsr two
        jmp fo_end
fo_us   lda date+1             ; MM-DD-YY hh:MM:SSa / p
        jsr two
        jsr dash
        lda date
        jsr two
        jsr dash
        lda date+2
        jsr two
        lda #' '
        jsr putb
        lda #'a'
        sta fo_ap
        lda time
        cmp #12
        bcc fo1
        sbc #12
        ldy #'p'
        sty fo_ap
fo1     cmp #0
        bne fo2
        lda #12
fo2     jsr two
        jsr colon
        lda time+1
        jsr two
        jsr colon
        lda time+2
        jsr two
        lda fo_ap
        jsr putb
fo_end  lda #EOL
putb    sta tbuf,x
        inx
        rts
dash    lda #'-'
        bne putb
colon   lda #':'
        bne putb
; two: A (0-99) as two digits
two     ldy #'0'
tw1     cmp #10
        bcc tw2
        sbc #10
        iny
        bne tw1
tw2     pha
        tya
        jsr putb
        pla
        ora #'0'
        bne putb

        icl 'DATEclk.icl'

want    dta 0
ton     dta 0
us      dta 0
cnt     dta 0
gettd   dta a(0)
line    dta a(0)
dl      dta a(0)
odl     dta a(0)
jb      dta 0,0,0
vs_n    dta 0
vs_x    dta 0
vs_y    dta 0
sc_v    dta 0
fo_ap   dta 0
p_tdon  dta a(tdon)
p_fmttd dta a(fmttd)
p_vb    dta a(vbi)
p_hook  dta a(hook)
p_area  dta a(area)
p_dayt  dta a(n_dayt)
p_ntdon dta a(n_tdon)
p_nfmt  dta a(n_fmt)
p_ngettd dta a(n_gettd)
n_dayt  dta c'DAYTIME',EOL
n_tdon  dta c'I_TDON  '
n_fmt   dta c'I_FMTTD '
n_gettd dta c'I_GETTD '
dltab   dta b($70,$42,0,0,$60)
tbuf    :32 dta 0
area    :96 dta 0

        blk update address
        blk update symbols
