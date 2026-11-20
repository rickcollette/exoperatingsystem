; EOS CAR: LESS, the paging text viewer
;   LESS [/C] [<<][path]fname[.ext] [>>[path]fname[.ext]]
; The text (the file, or standard input without one) is loaded into free
; memory, MEMLO to MEMTOP. Text without any EOL but with CR or LF is PC
; (or CP/M, Unix) text and is converted: LF ends a line, CR goes, BELL,
; BACKSPACE, TAB, DELETE and the hard space become their Atari
; counterparts. On the screen, rows are one character short of its width
; (longer lines are folded; the character at the fold is lost, as on SDX),
; TABs become blanks to the next multiple of 8, and the codes the screen
; editor would act on (BELL, BACKSPACE, DELETE ...) blanks. Text of up to
; 23 rows is printed and LESS ends; longer text is paged, with the keys
; listed at the bottom and the number of the top row at the right. Output that is not the screen
; gets the (converted) text unfolded, and an EOL after it. Text that does
; not fit in memory is shown as far as it goes, then LESS fails with 158.
; /C clears the screen first.
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
PUTC     smb 'PUTC'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
GETC     smb 'GETC'
U_GETKEY smb 'U_GETKEY'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

dev_index equ $0740
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
LMARGN   equ $52
RMARGN   equ $53
ROWCRS   equ $54
COLCRS   equ $55
CRSINH   equ $02F0
MEMTOP   equ $02E5
MEMLO    equ $02E7
ICCOM0   equ $0342
ICBAL0   equ $0344
ICBLL0   equ $0348
CIOV     equ $E456
EOL      equ $9B
ESC      equ $1B
ROWS     equ 23                ; text lines on a page

p        equ $80               ; text pointer
q        equ $82               ; second text pointer, row table pointer

        blk reloc main
start   lda #0
        sta clr
        sta named
        sta full
p1      jsr U_GETPAR
        beq p_end
        lda COMTAB+$21
        cmp #'/'
        bne p_nm
        ldx #1                 ; switches: /C
ps1     lda COMTAB+$21,x
        cmp #EOL
        beq p1
        cmp #'C'
        bne p_bad
        sta clr
        inx
        bne ps1
p_bad   lda #156
        jmp U_FAIL
p_nm    lda named              ; the file: the first name given
        bne p1
        inc named
        ldx #0
pn1     lda COMTAB+$21,x
        sta fname,x
        inx
        cmp #EOL
        bne pn1
        beq p1

p_end   lda #0                 ; is the output the screen?
        sta scr
        ldx COMTAB+6
        lda dev_index,x
        and #$F0
        cmp #$30
        bne sw0
        inc scr
sw0     lda RMARGN             ; the rows: one short of the screen width
        sec
        sbc LMARGN
        bcc w40
        cmp #31
        bcc w40
        cmp #120
        bcc w1
w40     lda #39
w1      sta w

* ---- the text into memory --------------------------------------------------
        lda MEMLO
        sta lo
        lda MEMLO+1
        sta lo+1
        lda MEMTOP             ; (a byte kept for the EOL at the end)
        sta hi
        lda MEMTOP+1
        sta hi+1
        lda hi
        bne mt1
        dec hi+1
mt1     dec hi
        lda named
        beq ld_in
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
        lda lo
        sta addpos
        lda lo+1
        sta addpos+1
        sec
        lda hi
        sbc lo
        sta bytbuf
        lda hi+1
        sbc lo+1
        sta bytbuf+1
        lda #0
        sta memreix
        jsr FREAD
        php
        clc
        lda lo
        adc bytbuf
        sta tend
        lda lo+1
        adc bytbuf+1
        sta tend+1
        plp
        bmi ld_cl
        jsr FGETC              ; memory full: is there more?
        bmi ld_cl
        inc full               ; what fits is shown, then error 158
ld_cl   jsr FCLOSE
        jmp conv

ld_in   lda lo                 ; standard input, to its end
        sta p
        lda lo+1
        sta p+1
li1     lda p
        cmp hi
        lda p+1
        sbc hi+1
        bcc li2
        inc full
        bcs li3
li2     jsr GETC
        bmi li3
        ldy #0
        sta (p),y
        jsr incp
        jmp li1
li3     lda p
        sta tend
        lda p+1
        sta tend+1

* ---- PC text: no EOL anywhere, but CR or LF ---------------------------------
conv    lda #0
        sta pcf
        jsr p_lo
cv1     jsr p_end_
        bcs cv3
        ldy #0
        lda (p),y
        cmp #EOL
        beq cv_done            ; Atari text: as it is
        cmp #13
        beq cv2
        cmp #10
        bne cv2a
cv2     sta pcf
cv2a    jsr incp
        jmp cv1
cv3     lda pcf
        beq cv_done
        jsr p_lo               ; p reads, q writes
        lda lo
        sta q
        lda lo+1
        sta q+1
cv4     jsr p_end_
        bcs cv9
        ldy #0
        lda (p),y
        jsr incp
        cmp #13                ; CR goes, LF ends the line
        beq cv4
        cmp #10
        bne cv6
        lda #EOL
        bne cvst
cv6     ldx #4
cv7     cmp cvfrom,x
        beq cv8
        dex
        bpl cv7
        bmi cvst
cv8     lda cvto,x
cvst    sta (q),y
        inc q
        bne cv4
        inc q+1
        jmp cv4
cv9     lda q
        sta tend
        lda q+1
        sta tend+1
cv_done

        lda scr
        bne onscr
* ---- not the screen: the text as it is, and an EOL --------------------------
        lda tend
        sta p
        lda tend+1
        sta p+1
        ldy #0
        lda #EOL
        sta (p),y
        inc tend
        bne nsc0
        inc tend+1
nsc0
        lda clr
        beq o1
        lda #$7D
        jsr PUTC
o1      jsr p_lo
o2      jsr p_end_
        bcs o3
        ldy #0
        lda (p),y
        jsr PUTC
        jsr incp
        jmp o2
o3      jmp fin

* ---- the screen: a table of the screen rows (their addresses) ---------------
onscr   lda tend
        sta tbl
        sta q
        lda tend+1
        sta tbl+1
        sta q+1
        lda #0
        sta n
        sta n+1
        jsr p_lo
rt1     jsr p_end_
        bcs rt_done
        clc                    ; room for one more entry?
        lda q
        adc #2
        tax
        lda q+1
        adc #0
        cpx hi
        sbc hi+1
        bcc rt1a
        inc full
        jmp rt_done
rt1a    ldy #0
        lda p
        sta (q),y
        iny
        lda p+1
        sta (q),y
        clc
        lda q
        adc #2
        sta q
        bcc rt1b
        inc q+1
rt1b    inc n
        bne rt1c
        inc n+1
rt1c    ldx #0                 ; X: the row's length
rt2     jsr p_end_
        bcs rt_done
        ldy #0
        lda (p),y
        jsr incp
        cmp #EOL
        beq rt1
        cmp #$7F               ; TAB: to the next multiple of 8
        bne rt2n
        txa
        ora #7
        tax
rt2n    inx
        cpx w
        bcc rt2
        jsr p_end_             ; a full row: the character after it is
        bcs rt_done            ; lost (an EOL ends the row), as on SDX
        jsr incp
        jmp rt1

rt_done lda clr
        beq rd0
        lda #$7D
        jsr PUTC
rd0     lda n+1                ; up to a page: printed, the end
        bne pager
        lda n
        cmp #ROWS+1
        bcs pager
        lda #0
        sta rr
        sta rr+1
rd1     lda rr
        cmp n
        bcs rd3
        jsr bldrow
        stx cnt
        ldx #0
rd2     lda rowbuf,x
        jsr PUTC
        inx
        cpx cnt
        bcc rd2
        inc rr
        bne rd1
rd3     jmp fin

* ---- paging ---------------------------------------------------------------------
pager   sec                    ; the last top line
        lda n
        sbc #ROWS
        sta max
        lda n+1
        sbc #0
        sta max+1
        lda #1
        sta CRSINH
        lda #0
        sta top
        sta top+1
redraw  jsr draw
key     jsr U_GETKEY
        bmi key
        cmp #'a'
        bcc k0
        cmp #'z'+1
        bcs k0
        and #$DF
k0      ldx #NKEYS-1
k1      cmp keys,x
        beq k2
        dex
        bpl k1
        bmi key
k2      lda keyact,x
        bmi k3
        jsr down               ; a positive number: lines down
        jmp redraw
k3      cmp #$C0
        bcs k4
        and #$7F               ; $80 + lines: up
        jsr up
        jmp redraw
k4      cmp #$C0
        bne k5
        lda #0                 ; <: the top
        sta top
        sta top+1
        beq redraw
k5      cmp #$C1
        bne k6
        lda max                ; >: the end
        sta top
        lda max+1
        sta top+1
        jmp redraw
k6      cmp #$C2
        bne quit
        jsr goline             ; G: a line number
        jmp redraw
quit    lda #0                 ; Q, ESC: the status line goes
        sta CRSINH
        jsr botrow
        lda #$9C
        jsr eputc
fin     lda full               ; the text did not fit: 158 Out of memory
        beq fin1
        lda #158
        jmp U_FAIL
fin1    rts

* down: A lines further, up to the last page; up: A lines back
down    clc
        adc top
        sta top
        bcc dn1
        inc top+1
dn1     lda max
        cmp top
        lda max+1
        sbc top+1
        bcs dn2
        lda max
        sta top
        lda max+1
        sta top+1
dn2     rts
up      sta tmp
        sec
        lda top
        sbc tmp
        sta top
        lda top+1
        sbc #0
        sta top+1
        bcs up1
        lda #0
        sta top
        sta top+1
up1     rts

* goline: "Line:" in the status line, digits up to RETURN (ESC: none)
goline  jsr botrow
        lda #$9C
        jsr eputc
        ldx #0
gl0     lda glmsg,x
        sta rowbuf,x
        inx
        cpx #6
        bcc gl0
        jsr eputb
        lda #0
        sta ndig
        sta CRSINH
gl1     jsr U_GETKEY
        jmi gl_esc
        cmp #EOL
        beq gl_ok
        cmp #ESC
        jeq gl_esc
        cmp #$7E
        bne gl2
        ldx ndig
        beq gl1
        dec ndig
        jsr eputc
        jmp gl1
gl2     cmp #'0'
        bcc gl1
        cmp #'9'+1
        bcs gl1
        ldx ndig
        cpx #5
        bcs gl1
        sta gdig,x
        inc ndig
        jsr eputc
        jmp gl1
gl_ok   lda #0                 ; the digits to a number (at most 65535)
        sta tmp
        sta tmp+1
        ldx #0
gl3     cpx ndig
        bcs gl5
        lda tmp                ; tmp = tmp * 10 + digit
        ldy tmp+1
        asl tmp
        rol tmp+1
        asl tmp
        rol tmp+1
        bcs gl_big
        adc tmp
        sta tmp
        tya
        adc tmp+1
        sta tmp+1
        bcs gl_big
        asl tmp
        rol tmp+1
        bcs gl_big
        lda gdig,x
        and #$0F
        adc tmp
        sta tmp
        bcc gl4
        inc tmp+1
        beq gl_big
gl4     inx
        bne gl3
gl_big  lda #$FF
        sta tmp
        sta tmp+1
gl5     lda tmp
        sta top
        lda tmp+1
        sta top+1
        lda #0
        jsr down               ; no further than the last page
gl_esc  lda #1
        sta CRSINH
        rts

* draw: the page from line top, and the status line
draw    lda #$7D
        jsr eputc
        lda top
        sta rr
        lda top+1
        sta rr+1
        lda #ROWS
        sta cnt
dr1     jsr bldrow
        jsr eputb
        inc rr
        bne dr6
        inc rr+1
dr6     dec cnt
        bne dr1
        jsr botrow             ; the status line, one short of the width
        ldx #0
st1     lda stmsg,x
        sta rowbuf,x
        inx
        cpx #STLEN
        bcc st1
        lda w
        sec
        sbc #STVIS+5
        tay
        lda #' '
st2     sta rowbuf,x
        inx
        dey
        bne st2
        lda top
        sta tmp
        lda top+1
        sta tmp+1
        jsr dec5
        jmp eputb

* bldrow: row rr to rowbuf (X bytes) with its EOL: TABs as blanks to the
* next multiple of 8, the codes the screen editor acts on as blanks
bldrow  jsr rowadr
        ldx #0
        stx tmp
br1     jsr p_end_
        bcs br_e
        ldy #0
        lda (p),y
        cmp #EOL
        beq br_e
        jsr incp
        cmp #$7F
        bne br3
br2     lda #' '
        sta rowbuf,x
        inx
        inc tmp
        lda tmp
        cmp w
        bcs br_e
        and #7
        bne br2
        beq br1
br3     pha
        and #$7F
        cmp #$1B
        bcc br5
        cmp #$20
        bcc br4
        cmp #$7D
        bcc br5
br4     pla                    ; a code the screen editor acts on: a blank
        lda #' '
        pha
br5     pla
        sta rowbuf,x
        inx
        inc tmp
        lda tmp
        cmp w
        bcc br1
br_e    lda #EOL
        sta rowbuf,x
        inx
        rts

* dec5: tmp as 5 digits (leading blanks) to rowbuf+X
dec5    ldy #0
        sty nz
d51     lda #'0'
        sta dg
d52     lda tmp
        cmp p10l,y
        lda tmp+1
        sbc p10h,y
        bcc d53
        lda tmp
        sbc p10l,y
        sta tmp
        lda tmp+1
        sbc p10h,y
        sta tmp+1
        inc dg
        bne d52
d53     lda dg
        cmp #'0'
        bne d54
        lda nz
        bne d54
        cpy #4
        beq d54
        lda #' '
        bne d55
d54     inc nz
        lda dg
d55     sta rowbuf,x
        inx
        iny
        cpy #5
        bcc d51
        rts

* botrow: the cursor to the start of the bottom row
botrow  lda #ROWS
        sta ROWCRS
        lda LMARGN
        sta COLCRS
        lda #0
        sta COLCRS+1
        rts

* eputb: X bytes of rowbuf to the screen editor; eputc: the byte A
eputb   stx ICBLL0
        lda #0
        sta ICBLL0+1
        lda rba
        sta ICBAL0
        lda rba+1
        sta ICBAL0+1
        lda #$0B
        sta ICCOM0
        ldx #0
        jmp CIOV
eputc   pha
        lda #$0B
        sta ICCOM0
        lda #0
        sta ICBLL0
        sta ICBLL0+1
        pla
        ldx #0
        jmp CIOV

* rowadr: p = the address of row rr
rowadr  lda rr
        asl @
        sta q
        lda rr+1
        rol @
        sta q+1
        clc
        lda q
        adc tbl
        sta q
        lda q+1
        adc tbl+1
        sta q+1
        ldy #0
        lda (q),y
        sta p
        iny
        lda (q),y
        sta p+1
        rts

* p_lo: p = the start of the text; p_end_: C=1 when p is at its end;
* incp: p + 1 (keeps A, X, Y)
p_lo    lda lo
        sta p
        lda lo+1
        sta p+1
        rts
p_end_  lda p
        cmp tend
        lda p+1
        sbc tend+1
        rts
incp    inc p
        bne ip1
        inc p+1
ip1     rts


cvfrom  dta b(7,8,9,127,160)
cvto    dta b(253,126,127,126,32)
keys    dta b($1D,'=',EOL,$1C,'-',$1F,'*','F',' ',$1E,'+','B','D','U','<','>','G','Q',ESC)
keyact  dta b(1,1,1,$81,$81,ROWS,ROWS,ROWS,ROWS,$80+ROWS,$80+ROWS,$80+ROWS)
        dta b(ROWS/2,$80+ROWS/2,$C0,$C1,$C2,$C3,$C3)
NKEYS   equ keyact-keys
stmsg   dta b(ESC,$9D),c'line ',b(ESC,$9F),c'page ',b($BE),c'ends ',b($D1),c' quit'
STLEN   equ *-stmsg
STVIS   equ 24
glmsg   dta c'Line: '
p10l    dta l(10000,1000,100,10,1)
p10h    dta h(10000,1000,100,10,1)

clr     dta 0
full    dta 0
named   dta 0
scr     dta 0
pcf     dta 0
w       dta 0
cnt     dta 0
ndig    dta 0
nz      dta 0
dg      dta 0
lo      dta a(0)
hi      dta a(0)
tend    dta a(0)
tbl     dta a(0)
n       dta a(0)
rr      dta a(0)
top     dta a(0)
max     dta a(0)
tmp     dta a(0)
gdig    :5 dta 0
fna     dta a(fname)
rba     dta a(rowbuf)
fname   :64 dta 0
rowbuf  :250 dta 0

        blk update address
        blk update symbols
