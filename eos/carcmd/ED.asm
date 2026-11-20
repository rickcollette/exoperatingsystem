; EOS CAR: ED, the full-screen text editor
;   ED [d:][path][filename.ext]
; A line editor: lines of up to 127 characters (longer ones are split when
; loaded, which marks the text changed), typing inserts. The window is the
; status line, $ED text lines (10 when not set, 1 to 22, more is 22) and a
; message line; lines wider than the screen scroll sideways.
;
; Memory: the text lives from MEMLO to MEMTOP. The lines above the cursor
; line are at the bottom (each ends in an EOL), the lines below it at the
; top (each starts with an EOL), the cursor line is in lbuf, and the free
; space in between always has room for lbuf and its EOL.
;
; Keys: ESC quit; ^L load; ^S save; ^U/^D window one line shorter/longer;
; ^V EOLs shown; arrows (or F1-F4) move; ^B/^E start/end of the text;
; ^A/^Z start/end of the line; ^T tag the line, ^G go to it; ^Q the next
; key as a character; SHIFT-CTRL-up/down a page up/down; CTRL-INSERT a
; blank in; CTRL-DELETE the character out (at the end: the next line
; joined); SHIFT-INSERT a copy of the cursor line before the tagged line,
; then the next line; SHIFT-DELETE the line out; BACK SPACE the character
; before the cursor out (at the start: joined to the line above);
; RETURN splits the line; SHIFT-CTRL-E clears the text.
U_GETPAR smb 'U_GETPAR'
U_GETKEY smb 'U_GETKEY'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
ERR_GMSG smb 'ERR_GMSG'
GETENV   smb 'GETENV'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
LBUFF    equ $0580
ATRACT   equ $4D
LMARGN   equ $52
RMARGN   equ $53
ROWCRS   equ $54
COLCRS   equ $55
CRSINH   equ $02F0
CH       equ $02FC
MEMTOP   equ $02E5
MEMLO    equ $02E7
ICCOM0   equ $0342
ICBAL0   equ $0344
ICBLL0   equ $0348
CIOV     equ $E456
EOL      equ $9B
ESC      equ $1B
MAXLEN   equ 127               ; characters in a line
NAMELEN  equ 60                ; characters of a file name
NOTAG    equ $FF               ; tag+1 = $FF: no line tagged

p        equ $80               ; pointers
q        equ $82
s        equ $84

        blk reloc main
start   lda #EOL
        sta fname
        jsr U_GETPAR           ; the file, if one is given
        beq st1
        ldx #0
st0     lda COMTAB+$21,x
        sta fname,x
        inx
        cmp #EOL
        beq st1
        cpx #NAMELEN
        bcc st0
        lda #EOL
        sta fname,x
st1     lda RMARGN             ; the screen: dw characters of each row used
        sec
        sbc LMARGN
        bcc w40
        cmp #31
        bcc w40
        cmp #120
        bcc w1
w40     lda #39
w1      sta dw
        lda #10                ; the window: $ED lines
        sta hgt
        lda edn
        ldx edn+1
        jsr GETENV
        bmi st3
        ldx #0
        stx tmp
st2     lda LBUFF,x
        cmp #'0'
        bcc st2b
        cmp #'9'+1
        bcs st2b
        and #$0F
        sta tmp+1
        lda tmp
        cmp #26
        bcs st2a
        asl @
        asl @
        adc tmp
        asl @
        adc tmp+1
        bcc st2c
st2a    lda #255
st2c    sta tmp
        inx
        bne st2
st2b    lda tmp
        beq st2d
        cmp #23
        bcc st2e
st2d    lda #22
st2e    sta hgt
st3     lda MEMLO              ; the text's memory
        sta lo
        lda MEMLO+1
        sta lo+1
        lda MEMTOP
        sta hi
        lda MEMTOP+1
        sta hi+1
        sec
        lda hi
        sbc lo
        lda hi+1
        sbc lo+1
        cmp #4
        bcs st4
        jsr PRINTF
        dta c'Out of memory',EOL,0
        rts
st4     jsr clearbuf
        lda #0
        sta vis
        sta msgon
        lda #$7D
        jsr eputc
        lda fname
        cmp #EOL
        beq main
        jsr load

* ---- the main loop ---------------------------------------------------------------
main    jsr refresh
        jsr getkey
        sta kch
        stx kx
        lda msgon              ; a message goes with the next key
        beq mn1
        jsr clrmsg
mn1     lda kch
        ldx kx
        cpx #0
        beq mn2
        tax                    ; SHIFT-CTRL keys: 1 page up, 2 page down,
        dex                    ; 3 clear
        txa
        clc
        adc #NKEYS
        bne mn4
mn2     ldx #NKEYS-1
mn3     cmp keys,x
        beq mn3a
        dex
        bpl mn3
        jsr insch              ; anything else: typed in
        jmp main
mn3a    txa
mn4     asl @
        tax
        lda keyjmp,x
        sta jump+1
        lda keyjmp+1,x
        sta jump+2
        jsr jump
        jmp main
jump    jmp $FFFF              ; (the operand set above: no JMP () through a
                               ; vector that could sit at $xxFF)

* ---- the keys ----------------------------------------------------------------------
k_quit  lda chg
        beq kq1
        lda m_quita
        ldx m_quita+1
        jsr ask
        bcs kq2
kq1     pla                    ; out of the main loop
        pla
        lda #0
        sta CRSINH
        lda #$7D
        jmp eputc
kq2     rts

k_load  lda chg
        beq kl1
        lda m_losea
        ldx m_losea+1
        jsr ask
        bcs kl2
kl1     lda m_loada
        ldx m_loada+1
        jsr input
        bcs kl2
        jsr load
        lda #3
        sta dirty
kl2     rts

k_save  lda m_savea
        ldx m_savea+1
        jsr input
        bcs ks1
        jmp save
ks1     rts

k_short lda hgt                ; ^U: the window a line shorter
        cmp #2
        bcc ksh1
        dec hgt
        lda #3
        sta dirty
ksh1    rts
k_long  lda hgt                ; ^D: a line longer
        cmp #22
        bcs ksh1
        inc hgt
        lda #3
        sta dirty
        rts

k_vis   lda vis                ; ^V: EOLs shown or not
        eor #1
        sta vis
        lda #2
        sta dirty
        rts

k_up    jsr up1
        jmp clampx
k_down  jsr down1
        jmp clampx
k_left  lda cx
        beq kle1
        dec cx
kle1    rts
k_right lda cx
        cmp llen
        bcs kle1
        inc cx
        rts

k_begin jsr up1                ; ^B: the start of the text
        bcc k_begin
        lda #0
        sta cx
        rts
k_end   jsr down1              ; ^E: the end
        bcc k_end
        lda llen
        sta cx
        rts
k_home  lda #0                 ; ^A, ^Z: the start, the end of the line
        sta cx
        rts
k_eol   lda llen
        sta cx
        rts

k_tag   lda cy                 ; ^T: this line tagged
        sta tag
        lda cy+1
        sta tag+1
        lda m_tagda
        ldx m_tagda+1
        jmp showmsg
k_go    lda tag+1              ; ^G: to the tagged line
        cmp #NOTAG
        beq kg1
        lda tag
        sta tmp
        lda tag+1
        sta tmp+1
        jsr goline
        jmp clampx
kg1     jmp beep

k_quote jsr U_GETKEY           ; ^Q: the next key as a character
        bmi kqu1
        cmp #EOL
        jeq k_ret
        jmp insch0
kqu1    rts

k_pgup  ldx hgt                ; a page up
kpu1    txa
        pha
        jsr up1
        pla
        tax
        dex
        bne kpu1
        sec
        lda top
        sbc hgt
        sta top
        lda top+1
        sbc #0
        sta top+1
        bcs kpu2
        lda #0
        sta top
        sta top+1
kpu2    lda #2
        sta dirty
        jmp clampx
k_pgdn  ldx hgt                ; a page down
kpd1    txa
        pha
        jsr down1
        pla
        tax
        dex
        bne kpd1
        clc
        lda top
        adc hgt
        sta top
        bcc kpd1a
        inc top+1
kpd1a   sec                    ; nor further than a full last window
        lda nlines
        sbc hgt
        sta tmp2
        lda nlines+1
        sbc #0
        sta tmp2+1
        bcs kpd1b
        lda #0
        sta tmp2
        sta tmp2+1
kpd1b   lda tmp2
        cmp top
        lda tmp2+1
        sbc top+1
        bcs kpd2
        lda tmp2
        sta top
        lda tmp2+1
        sta top+1
kpd2    lda cy                 ; the top no further than the cursor line
        cmp top
        lda cy+1
        sbc top+1
        bcs kpu2
        lda cy
        sta top
        lda cy+1
        sta top+1
        jmp kpu2

k_erase lda chg                ; SHIFT-CTRL-E: the text cleared
        beq ke1
        lda m_losea
        ldx m_losea+1
        jsr ask
        bcs ke2
ke1     jsr clearbuf
ke2     rts

k_ins   lda #' '               ; CTRL-INSERT: a blank, the cursor stays
        jsr insch0
        bcs ki1
        dec cx
ki1     rts

k_bs    lda cx                 ; BACK SPACE
        beq kb1
        dec cx
        jmp delch
kb1     lda cy                 ; at the start: joined to the line above
        ora cy+1
        beq ki1
        jsr up1
        lda llen
        sta cx
        jsr joinnx
        bcc ki1
        jsr down1              ; too long: back
        lda #0
        sta cx
        jmp beep

k_del   jmp delch              ; CTRL-DELETE

k_ret   jsr room2              ; RETURN: the line split at the cursor
        bcc kr1
        jmp nomem
kr1     lda pend
        sta p
        lda pend+1
        sta p+1
        ldy #0
kr2     cpy cx
        bcs kr3
        lda lbuf,y
        sta (p),y
        iny
        bne kr2
kr3     lda #EOL
        sta (p),y
        iny
        tya
        clc
        adc pend
        sta pend
        bcc kr4
        inc pend+1
kr4     ldx #0                 ; the rest to the start of lbuf
        ldy cx
kr5     cpy llen
        bcs kr6
        lda lbuf,y
        sta lbuf,x
        inx
        iny
        bne kr5
kr6     stx llen
        lda #0
        sta cx
        jsr inccy
        jsr incnl
        lda cy                 ; the lines after it are one further
        sta tmp
        lda cy+1
        sta tmp+1
        jsr tagins
        jmp chg2

k_cpy   lda tag+1              ; SHIFT-INSERT: a copy before the tagged line
        cmp #NOTAG
        bne kc0
        jmp beep
kc0     ldx #0
kc1     cpx llen
        bcs kc2
        lda lbuf,x
        sta cbuf,x
        inx
        bne kc1
kc2     stx clen
        lda cy                 ; where to go after: the next line
        sta oc
        lda cy+1
        sta oc+1
        lda oc                 ; (one further when the copy goes above)
        cmp tag
        lda oc+1
        sbc tag+1
        bcc kc4
        inc oc
        bne kc4
        inc oc+1
kc4     inc oc
        bne kc5
        inc oc+1
kc5     lda tag
        sta tmp
        lda tag+1
        sta tmp+1
        jsr goline
        lda clen               ; room for the tagged line and the copy
        clc
        adc #1
        jsr room
        bcc kc5a
        jmp nomem
kc5a    jsr pushln             ; the tagged line below, the copy current
        ldx #0
kc6     cpx clen
        bcs kc7
        lda cbuf,x
        sta lbuf,x
        inx
        bne kc6
kc7     stx llen
        jsr incnl
        inc tag
        bne kc8
        inc tag+1
kc8     lda oc
        sta tmp
        lda oc+1
        sta tmp+1
        jsr goline
        jsr clampx
        jmp chg2

k_dline lda qbeg               ; SHIFT-DELETE: the line out
        cmp hi
        bne kd1
        lda qbeg+1
        cmp hi+1
        beq kd3
kd1     lda cy
        sta tmp
        lda cy+1
        sta tmp+1
        jsr nextln             ; the next line comes up
        ldx #0
kd2     cpx nlen
        bcs kd2a
        lda nbuf,x
        sta lbuf,x
        inx
        bne kd2
kd2a    stx llen
        jmp kd5
kd3     lda pend               ; the last line: the one above becomes current
        cmp lo
        bne kd4
        lda pend+1
        cmp lo+1
        bne kd4
        lda #0                 ; the only line: emptied
        sta llen
        sta cx
        jmp chg2
kd4     lda cy
        sta tmp
        lda cy+1
        sta tmp+1
        jsr prevln
        jsr deccy
kd5     jsr tagdel
        jsr decnl
        lda #0
        sta cx
        jmp chg2

* ---- editing the cursor line ---------------------------------------------------
* insch: A typed in at the cursor (only characters that are not control
* codes, those need ^Q); insch0: any A. C=1 when it could not be.
insch   cmp #$20
        bcc ic_no
        cmp #$7D
        bcc insch0
        cmp #$A0
        bcc ic_no
        cmp #$FD
        bcs ic_no
insch0  sta chr
        lda llen
        cmp #MAXLEN
        bcs ic_full
        lda #1
        jsr room
        bcs ic_mem
        ldx llen
ic1     cpx cx
        beq ic2
        lda lbuf-1,x
        sta lbuf,x
        dex
        bne ic1
ic2     lda chr
        sta lbuf,x
        inc llen
        inc cx
        lda #1
        jsr setdirty
        jsr setchg
        clc
        rts
ic_mem  jsr nomem
        sec
        rts
ic_full jsr beep
ic_no   sec
        rts

* delch: the character at the cursor out; at the end the next line joined
delch   ldx cx
        cpx llen
        bcs dc3
dc1     inx
        cpx llen
        bcs dc2
        lda lbuf,x
        sta lbuf-1,x
        bne dc1
        beq dc1
dc2     dec llen
        lda #1
        jsr setdirty
        jmp setchg
dc3     jsr joinnx
        bcc dc4
        jmp beep
dc4     rts

* joinnx: the next line joined to the cursor line; C=1 when there is
* none or both are too long together
joinnx  lda qbeg
        cmp hi
        bne jn1
        lda qbeg+1
        cmp hi+1
        bne jn1
        sec
        rts
jn1     lda qbeg               ; its length first
        sta p
        lda qbeg+1
        sta p+1
        ldx #0
jn2     jsr incp
        jsr p_hi
        bcs jn3
        ldy #0
        lda (p),y
        cmp #EOL
        beq jn3
        inx
        bne jn2
jn3     txa
        clc
        adc llen
        bcs jn_no
        cmp #MAXLEN+1
        bcc jn4
jn_no   sec
        rts
jn4     jsr nextln
        ldx #0
        ldy llen
jn5     cpx nlen
        bcs jn6
        lda nbuf,x
        sta lbuf,y
        inx
        iny
        bne jn5
jn6     sty llen
        clc                    ; line cy+1 has gone
        lda cy
        adc #1
        sta tmp
        lda cy+1
        adc #0
        sta tmp+1
        jsr tagdel
        jsr decnl
        jsr chg2
        clc
        rts

* ---- moving between lines ----------------------------------------------------
* up1: the line above becomes the cursor line; C=1 at the first line
up1     lda pend
        cmp lo
        bne u1
        lda pend+1
        cmp lo+1
        bne u1
        sec
        rts
u1      jsr pushln
        jsr prevln
        jsr deccy
        clc
        rts

* down1: the line below becomes the cursor line; C=1 at the last line
down1   lda qbeg
        cmp hi
        bne d1
        lda qbeg+1
        cmp hi+1
        bne d1
        sec
        rts
d1      jsr nextln             ; the next line out of the top part
        lda pend               ; lbuf and its EOL to the bottom part
        sta p
        lda pend+1
        sta p+1
        ldy #0
d2      cpy llen
        bcs d3
        lda lbuf,y
        sta (p),y
        iny
        bne d2
d3      lda #EOL
        sta (p),y
        iny
        tya
        clc
        adc pend
        sta pend
        bcc d4
        inc pend+1
d4      ldx #0                 ; and the next line to lbuf
d5      cpx nlen
        bcs d6
        lda nbuf,x
        sta lbuf,x
        inx
        bne d5
d6      stx llen
        jsr inccy
        clc
        rts

* pushln: lbuf with an EOL before it to the top part
pushln  sec
        lda qbeg
        sbc llen
        sta qbeg
        bcs pu1
        dec qbeg+1
pu1     lda qbeg
        bne pu2
        dec qbeg+1
pu2     dec qbeg
        lda qbeg
        sta p
        lda qbeg+1
        sta p+1
        ldy #0
        lda #EOL
        sta (p),y
        ldx #0
pu3     cpx llen
        bcs pu4
        lda lbuf,x
        iny
        sta (p),y
        inx
        bne pu3
pu4     rts

* prevln: the last line of the bottom part out to lbuf
prevln  lda pend
        sta p
        lda pend+1
        sta p+1
        jsr bkline
        ldy #0
pv1     lda (p),y
        cmp #EOL
        beq pv2
        sta lbuf,y
        iny
        bne pv1
pv2     sty llen
        lda p
        sta pend
        lda p+1
        sta pend+1
        rts

* nextln: the first line of the top part out to nbuf (nlen)
nextln  lda qbeg
        sta p
        lda qbeg+1
        sta p+1
        ldx #0
nl1     jsr incp
        jsr p_hi
        bcs nl2
        ldy #0
        lda (p),y
        cmp #EOL
        beq nl2
        sta nbuf,x
        inx
        bne nl1
nl2     stx nlen
        lda p
        sta qbeg
        lda p+1
        sta qbeg+1
        rts

* bkline: p from the start of a line (just after an EOL) to the start of
* the line before it
bkline  jsr decp
bk1     lda p
        cmp lo
        bne bk2
        lda p+1
        cmp lo+1
        beq bk3
bk2     jsr decp
        ldy #0
        lda (p),y
        cmp #EOL
        bne bk1
        jsr incp
bk3     rts

* goline: to line tmp (or the last one)
goline  lda cy
        cmp tmp
        lda cy+1
        sbc tmp+1
        bcc gl2
        lda cy                 ; cy >= tmp: up while above
        cmp tmp
        bne gl1
        lda cy+1
        cmp tmp+1
        beq gl3
gl1     jsr up1
        bcc goline
        rts
gl2     jsr down1
        bcc goline
gl3     rts

* clampx: the cursor no further than the end of the line
clampx  lda cx
        cmp llen
        bcc cl1
        lda llen
        sta cx
cl1     rts

* room: C=0 when the free space has llen + 1 + A bytes; room2: A = 1
room2   lda #1
room    sec
        adc llen
        sta tmp2
        lda #0
        adc #0
        sta tmp2+1
        sec
        lda qbeg
        sbc pend
        tax
        lda qbeg+1
        sbc pend+1
        cpx tmp2
        sbc tmp2+1
        bcc rm_no
        clc
        rts
rm_no   sec
        rts

* clearbuf: no text, one empty line
clearbuf lda lo
        sta pend
        lda lo+1
        sta pend+1
        lda hi
        sta qbeg
        lda hi+1
        sta qbeg+1
        lda #0
        sta llen
        sta cx
        sta hoff
        sta cy
        sta cy+1
        sta top
        sta top+1
        sta chg
        lda #1
        sta nlines
        lda #0
        sta nlines+1
        lda #NOTAG
        sta tag
        sta tag+1
        lda #3
        sta dirty
        rts

* tagins: a line came in at tmp; tagdel: line tmp went
tagins  lda tag+1
        cmp #NOTAG
        beq tg1
        lda tag
        cmp tmp
        lda tag+1
        sbc tmp+1
        bcc tg1
        inc tag
        bne tg1
        inc tag+1
tg1     rts
tagdel  lda tag+1
        cmp #NOTAG
        beq tg1
        lda tag
        cmp tmp
        bne td1
        lda tag+1
        cmp tmp+1
        bne td1
        lda #NOTAG
        sta tag
        sta tag+1
        rts
td1     lda tmp
        cmp tag
        lda tmp+1
        sbc tag+1
        bcs tg1
        lda tag
        bne td2
        dec tag+1
td2     dec tag
        rts

inccy   inc cy
        bne ic9
        inc cy+1
ic9     rts
deccy   lda cy
        bne dy1
        dec cy+1
dy1     dec cy
        rts
incnl   inc nlines
        bne ic9
        inc nlines+1
        rts
decnl   lda nlines
        bne dn1
        dec nlines+1
dn1     dec nlines
        rts
chg2    lda #2
        jsr setdirty
setchg  lda #1
        sta chg
        rts
setdirty cmp dirty
        bcc sd1
        sta dirty
sd1     rts

* ---- the screen -------------------------------------------------------------------
* refresh: the window kept around the cursor, what changed drawn, the
* status line, the cursor
refresh lda #1
        sta CRSINH
        lda cy                 ; above the window: the cursor line on top
        cmp top
        lda cy+1
        sbc top+1
        bcs rf1
        lda cy
        sta top
        lda cy+1
        sta top+1
        jmp rf2
rf1     clc                    ; below it: at the bottom
        lda top
        adc hgt
        sta tmp2
        lda top+1
        adc #0
        sta tmp2+1
        lda cy
        cmp tmp2
        lda cy+1
        sbc tmp2+1
        bcc rf3
        sec
        lda cy
        sbc hgt
        sta top
        lda cy+1
        sbc #0
        sta top+1
        inc top
        bne rf2
        inc top+1
rf2     lda #2
        jsr setdirty
rf3     lda cx                 ; sideways
        cmp hoff
        bcs rf4
        sbc #7
        bcs rf3a
        lda #0
rf3a    sta hoff
        jmp rf5
rf4     sec
        sbc hoff
        cmp dw
        bcc rf6
        lda cx
        sec
        sbc dw
        adc #7
        sta hoff
rf5     lda #2
        jsr setdirty
rf6     lda dirty
        beq rf9
        cmp #3
        bcc rf7
        lda #$7D
        jsr eputc
        jsr drawall
        lda msgon              ; a message shown again
        beq rf8
        ldx #0
rf7b    lda mbuf,x
        sta sbuf,x
        inx
        cpx dw
        bcc rf7b
        jsr msgout
        jmp rf8
rf7     cmp #2
        bcc rf7a
        jsr drawall
        jmp rf8
rf7a    jsr drawcur
rf8     lda #0
        sta dirty
rf9     jsr status
        sec                    ; the cursor
        lda cy
        sbc top
        clc
        adc #1
        sta ROWCRS
        lda cx
        sec
        sbc hoff
        clc
        adc LMARGN
        sta COLCRS
        lda #0
        sta COLCRS+1
        sta CRSINH
        lda #$1F               ; (moved there and back: the cursor is shown)
        jsr eputc
        lda #$1E
        jmp eputc

* drawall: every row of the window
drawall sec                    ; k: the cursor line's row
        lda cy
        sbc top
        sta k
        lda pend               ; p: the window's first line
        sta p
        lda pend+1
        sta p+1
        ldx k
        beq da1
da0     txa
        pha
        jsr bkline
        pla
        tax
        dex
        bne da0
da1     lda #0
        sta r
da2     lda r
        cmp k
        beq da5
        bcs da6
        lda p                  ; above the cursor line
        sta s
        lda p+1
        sta s+1
        ldy #0
da3     lda (p),y
        cmp #EOL
        beq da4
        iny
        bne da3
da4     sty len
        sec
        tya
        adc p
        sta p
        bcc da4a
        inc p+1
da4a    lda #1
        bne da9
da5     jsr curln              ; the cursor line
        lda qbeg
        sta q
        lda qbeg+1
        sta q+1
        jmp da10
da6     lda q                  ; below it
        cmp hi
        bne da7
        lda q+1
        cmp hi+1
        bne da7
        lda #0                 ; past the end
        sta len
        beq da9
da7     inc q
        bne da7a
        inc q+1
da7a    lda q
        sta s
        lda q+1
        sta s+1
        ldx #0
da8     lda q
        cmp hi
        lda q+1
        sbc hi+1
        bcs da8a
        ldy #0
        lda (q),y
        cmp #EOL
        beq da8a
        inx
        inc q
        bne da8
        inc q+1
        bne da8
da8a    stx len
        lda #1
da9     sta ex
da10    lda r
        clc
        adc #1
        jsr putrow
        inc r
        lda r
        cmp hgt
        jcc da2
        rts

* drawcur: the cursor line's row
drawcur jsr curln
        sec
        lda cy
        sbc top
        clc
        adc #1
* putrow: row A of the screen: len characters at s from hoff on (and the
* EOL shown after them when ex and vis are set), blanks to the width
putrow  sta ROWCRS
        lda LMARGN
        sta COLCRS
        lda #0
        sta COLCRS+1
        sta vc
        ldx #0
        ldy hoff
pr1     lda vc
        cmp dw
        bcs pr5
        cpy len
        bcs pr3
        lda (s),y
        jsr escq
        bcc pr2
        pha
        lda #ESC
        sta rowbuf,x
        inx
        pla
pr2     sta rowbuf,x
        inx
pr2a    iny
        inc vc
        bne pr1
pr3     bne pr4                ; just after the line: its EOL
        lda vis
        and ex
        beq pr4
        lda #ESC
        sta rowbuf,x
        inx
        sta rowbuf,x
        inx
        bne pr2a
pr4     lda #' '
        bne pr2
pr5     jmp eputb

* curln: s, len, ex for the cursor line
curln   lda lbufa
        sta s
        lda lbufa+1
        sta s+1
        lda llen
        sta len
        lda #1
        sta ex
        rts

* escq: C=1 when A is a code the screen editor acts on (shown after ESC)
escq    pha
        and #$7F
        cmp #$1B
        bcc eq1
        cmp #$20
        bcc eq2
        cmp #$7D
        bcs eq2
eq1     pla
        clc
        rts
eq2     pla
        sec
        rts

* status: the top row, inverse: the file name, * when changed, the line
* and the column
status  ldx #0
        lda #' '
sa1     sta sbuf,x
        inx
        cpx dw
        bcc sa1
        lda dw                 ; room for the name
        sec
        sbc #14
        sta tmp
        ldx #0
sa2     lda fname,x
        cmp #EOL
        beq sa3
        sta sbuf+1,x
        inx
        cpx tmp
        bcc sa2
sa3     lda chg
        beq sa4
        lda #'*'
        sta sbuf+2,x
sa4     clc                    ; the line (from 1), the column (from 1)
        lda cy
        adc #1
        sta num
        lda cy+1
        adc #0
        sta num+1
        lda dw
        sec
        sbc #11
        tax
        jsr dec5
        lda #':'
        sta sbuf,x
        inx
        lda cx
        clc
        adc #1
        sta num
        lda #0
        sta num+1
        jsr dec5               ; (5 digits, the first 2 blank)
        ldx #0
sa5     lda sbuf,x
        ora #$80
        sta rowbuf,x
        inx
        cpx dw
        bcc sa5
        lda #0
        sta ROWCRS
        lda LMARGN
        sta COLCRS
        lda #0
        sta COLCRS+1
        jmp eputb

* dec5: num as 5 digits (leading blanks) to sbuf+X
dec5    ldy #0
        sty nz
d51     lda #'0'
        sta dg
d52     lda num
        cmp p10l,y
        lda num+1
        sbc p10h,y
        bcc d53
        lda num
        sbc p10l,y
        sta num
        lda num+1
        sbc p10h,y
        sta num+1
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
d55     sta sbuf,x
        inx
        iny
        cpy #5
        bcc d51
        rts

* ---- the message line, under the window ------------------------------------------
* showmsg: the text at AX (EOL or 0 ended)
showmsg sta s
        stx s+1
        ldy #0
        ldx #0
sm1     lda (s),y
        beq sm2
        cmp #EOL
        beq sm2
        sta sbuf,x
        inx
        iny
        cpx dw
        bcc sm1
sm2     lda #1
        sta msgon
        txa
        pha
        lda #' '               ; kept for a redraw
sm2a    cpx dw
        bcs sm2b
        sta sbuf,x
        inx
        bne sm2a
sm2b    ldx #0
sm2c    lda sbuf,x
        sta mbuf,x
        inx
        cpx dw
        bcc sm2c
        pla
        tax
msgout  lda #' '               ; sbuf from X on blank, out on the row
sm3     cpx dw
        bcs sm4
        sta sbuf,x
        inx
        bne sm3
sm4     ldx #0
sm5     lda sbuf,x
        jsr escq
        bcc sm6
        lda #' '
sm6     sta rowbuf,x
        inx
        cpx dw
        bcc sm5
        ldy hgt
        iny
        sty ROWCRS
        lda LMARGN
        sta COLCRS
        lda #0
        sta COLCRS+1
        jmp eputb
clrmsg  lda #0
        sta msgon
        tax
        beq msgout

* ask: the question at AX and (Y/N); C=0 for Y
ask     jsr showmsg
        lda #0
        sta CRSINH
        jsr U_GETKEY
        pha
        jsr clrmsg
        pla
        and #$DF
        cmp #'Y'
        beq ak1
        sec
        rts
ak1     clc
        rts

* input: the prompt at AX, then the file name (fname) edited on the
* message line; RETURN takes it (C=0), ESC leaves it (C=1)
input   sta q
        stx q+1
        ldx #0
in0     lda fname,x            ; a copy to edit
        sta ibuf,x
        cmp #EOL
        beq in0a
        inx
        bne in0
in0a    stx ilen
in1     ldy #0                 ; the line: prompt and name
        ldx #0
in2     lda (q),y
        beq in3
        sta sbuf,x
        inx
        iny
        bne in2
in3     stx plen
        ldy #0
in4     cpy ilen
        bcs in5
        lda ibuf,y
        sta sbuf,x
        inx
        iny
        bne in4
in5     stx tmp
        lda #1
        sta CRSINH
        jsr msgout
        lda tmp                ; the cursor after the name
        clc
        adc LMARGN
        sta COLCRS
        lda #0
        sta CRSINH
        lda #$1F
        jsr eputc
        lda #$1E
        jsr eputc
        jsr U_GETKEY
        bmi in_esc
        cmp #EOL
        beq in_ok
        cmp #ESC
        beq in_esc
        cmp #$7E
        bne in6
        lda ilen
        beq in1
        dec ilen
        jmp in1
in6     cmp #'a'               ; capitals
        bcc in7
        cmp #'z'+1
        bcs in7
        and #$DF
in7     cmp #$21
        bcc in1
        cmp #$7D
        jcs in1
        ldx ilen
        cpx #NAMELEN
        bcs in1
        pha
        txa
        clc
        adc plen
        adc #2
        cmp dw
        pla
        jcs in1
        sta ibuf,x
        inc ilen
        jmp in1
in_esc  jsr clrmsg
        sec
        rts
in_ok   jsr clrmsg
        ldx ilen
        beq in_esc
        lda #EOL
        sta ibuf,x
in8     lda ibuf,x
        sta fname,x
        dex
        bpl in8
        clc
        rts

nomem   lda m_mema
        ldx m_mema+1
        jsr showmsg
beep    lda #$FD
        jmp eputc

* ---- the keyboard ----------------------------------------------------------------
* getkey: a key; X=0 and A its code, or X=1 and A = 1 SHIFT-CTRL-up,
* 2 SHIFT-CTRL-down, 3 SHIFT-CTRL-E (the keyboard handler has no codes
* for these)
getkey  lda #0
        sta ATRACT
gk1     lda CH
        cmp #$FF
        beq gk1
        and #$C0
        cmp #$C0
        bne gk3
        lda CH
        ldx #$FF
        stx CH
        and #$3F
        ldx #2
gk2     cmp sccode,x
        beq gk2a
        dex
        bpl gk2
        bmi getkey
gk2a    inx
        txa
        ldx #1
        rts
gk3     jsr U_GETKEY
        bmi getkey
        ldx #0
        rts

* ---- the screen editor --------------------------------------------------------------
* eputb: X bytes of rowbuf; eputc: the byte A
eputb   stx ICBLL0
        lda #0
        sta ICBLL0+1
        lda rowbufa
        sta ICBAL0
        lda rowbufa+1
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

* ---- files ---------------------------------------------------------------------------
* load: fname into the buffer. Lines over 127 characters are split (the
* text is then changed). Errors are shown on the message line.
load    lda #0
        sta hopen
        lda iotrapa
        ldx iotrapa+1
        jsr U_SFAIL
        jsr setfn
        lda #4
        sta mode
        jsr FOPEN
        lda file_id
        sta hfile
        inc hopen
        jsr clearbuf
        lda lo                 ; the file at the bottom of the memory
        sta addpos
        lda lo+1
        sta addpos+1
        sec                    ; (a page left for the split lines)
        lda hi
        sbc lo
        sta bytbuf
        lda hi+1
        sbc lo+1
        sbc #1
        sta bytbuf+1
        lda #0
        sta memreix
        jsr FREAD
        php
        lda bytbuf
        sta tmp
        lda bytbuf+1
        sta tmp+1
        plp
        bmi lo1
        jsr FGETC              ; the memory is full: more in the file?
        bmi lo1
        jsr closef
        jsr U_XFAIL
        jsr clearbuf
        jmp nomem
lo1     jsr closef
        jsr U_XFAIL
        sec                    ; moved to the top: from hi-tmp
        lda hi
        sbc tmp
        sta q
        lda hi+1
        sbc tmp+1
        sta q+1
        clc                    ; from the end down
        lda lo
        adc tmp
        sta p
        lda lo+1
        adc tmp+1
        sta p+1
        lda hi
        sta s
        lda hi+1
        sta s+1
lo2     lda p
        cmp lo
        bne lo3
        lda p+1
        cmp lo+1
        beq lo4
lo3     jsr decp
        lda s
        bne lo3a
        dec s+1
lo3a    dec s
        ldy #0
        lda (p),y
        sta (s),y
        jmp lo2
lo4     lda lo                 ; then the lines to the bottom part: q reads,
        sta p                  ; p writes
        lda lo+1
        sta p+1
        lda #0
        sta nlines
        sta nlines+1
lo5     ldx #0                 ; X: the line's length so far
lo6     lda q
        cmp hi
        lda q+1
        sbc hi+1
        bcs lo9
        ldy #0
        lda (q),y
        inc q
        bne lo6a
        inc q+1
lo6a    cmp #EOL
        beq lo8
        jsr lput
        bcs lo_mem
        inx
        cpx #MAXLEN
        bcc lo6
        lda q                  ; 127: an EOL put in unless one follows
        cmp hi
        lda q+1
        sbc hi+1
        bcs lo7
        lda (q),y
        cmp #EOL
        beq lo6
lo7     lda #1
        sta chg
lo8     lda #EOL
        jsr lput
        bcs lo_mem
        jsr incnl
        jmp lo5
lo9     stx llen               ; the rest after the last EOL: the cursor line
        sec
        lda p
        sbc llen
        sta p
        bcs lo9a
        dec p+1
lo9a    lda p
        sta pend
        lda p+1
        sta pend+1
        ldy #0
lo10    cpy llen
        bcs lo11
        lda (p),y
        sta lbuf,y
        iny
        bne lo10
lo11    lda nlines
        sta cy
        lda nlines+1
        sta cy+1
        jsr incnl
        lda hi
        sta qbeg
        lda hi+1
        sta qbeg+1
        lda #MAXLEN+2          ; room to edit
        jsr room
        bcs lo_mem
        jsr k_begin
        lda #3
        sta dirty
        rts
lo_mem  jsr clearbuf
        jmp nomem

* lput: A to the bottom part at p (C=1 when it would reach q)
lput    pha
        lda p
        cmp q
        lda p+1
        sbc q+1
        pla
        bcs lp1
        ldy #0
        sta (p),y
        jsr incp
        clc
lp1     rts

* save: the buffer to fname; an EOL after the last line unless it is empty
save    lda #0
        sta hopen
        lda iotrapa
        ldx iotrapa+1
        jsr U_SFAIL
        jsr setfn
        lda #8
        sta mode
        jsr FOPEN
        lda file_id
        sta hfile
        inc hopen
        lda lo                 ; the bottom part
        sta p
        lda lo+1
        sta p+1
        sec
        lda pend
        sbc lo
        sta tmp
        lda pend+1
        sbc lo+1
        sta tmp+1
        jsr wr
        lda lbufa              ; the cursor line
        sta p
        lda lbufa+1
        sta p+1
        lda llen
        sta tmp
        lda #0
        sta tmp+1
        jsr wr
        lda qbeg               ; the top part
        sta p
        lda qbeg+1
        sta p+1
        sec
        lda hi
        sbc qbeg
        sta tmp
        lda hi+1
        sbc qbeg+1
        sta tmp+1
        jsr wr
        lda qbeg               ; the last line empty?
        cmp hi
        bne sv1
        lda qbeg+1
        cmp hi+1
        bne sv1
        lda llen
        beq sv2
        bne sv1a
sv1     lda hi
        sta p
        lda hi+1
        sta p+1
        jsr decp
        ldy #0
        lda (p),y
        cmp #EOL
        beq sv2
sv1a    lda eola
        sta p
        lda eola+1
        sta p+1
        lda #1
        sta tmp
        lda #0
        sta tmp+1
        jsr wr
sv2     jsr closef
        jsr U_XFAIL
        lda #0
        sta chg
        lda m_saveda
        ldx m_saveda+1
        jmp showmsg

* wr: tmp bytes at p to the file
wr      lda tmp
        ora tmp+1
        beq wr1
        lda p
        sta addpos
        lda p+1
        sta addpos+1
        lda tmp
        sta bytbuf
        lda tmp+1
        sta bytbuf+1
        lda #0
        sta memreix
        lda hfile
        sta file_id
        jmp FWRITE
wr1     rts

* setfn: FILE_P = fname
setfn   lda fnamea
        sta FILE_P
        lda fnamea+1
        sta FILE_P+1
        lda #0
        sta scan
        sta attr
        rts

* closef: the file closed (an error goes to the trap)
closef  lda #0
        sta hopen
        lda hfile
        sta file_id
        jmp FCLOSE

* iotrap: an error while loading or saving: the file closed, the message
* shown; back to the caller of load or save
iotrap  sta err
        lda hopen
        beq it1
        lda #0
        sta hopen
        lda ctrapa
        ldx ctrapa+1
        jsr U_SFAIL
        lda hfile
        sta file_id
        jsr FCLOSE
        jsr U_XFAIL
it1     lda err
        jsr ERR_GMSG
        txa
        pha
        tya
        tax
        pla
        jsr showmsg
        lda #3
        sta dirty
        jmp beep
ctrap   rts

* ---- small helpers ---------------------------------------------------------------
incp    inc p
        bne ip1
        inc p+1
ip1     rts
decp    lda p
        bne dp1
        dec p+1
dp1     dec p
        rts
* p_hi: C=1 when p has reached hi
p_hi    lda p
        cmp hi
        lda p+1
        sbc hi+1
        rts

* ---- data ------------------------------------------------------------------------------
keys    dta b(ESC,$0C,$13,$15,$04,$16,$1C,$1D,$1E,$1F,$02,$05,$01,$1A,$14,$07,$11)
        dta b($FF,$FE,$9D,$9C,$7E,EOL)
NKEYS   equ *-keys
keyjmp  dta a(k_quit,k_load,k_save,k_short,k_long,k_vis,k_up,k_down,k_left,k_right)
        dta a(k_begin,k_end,k_home,k_eol,k_tag,k_go,k_quote)
        dta a(k_ins,k_del,k_cpy,k_dline,k_bs,k_ret)
        dta a(k_pgup,k_pgdn,k_erase)
sccode  dta b($0E,$0F,$2A)     ; the keys - = E (with SHIFT and CTRL)
p10l    dta l(10000,1000,100,10,1)
p10h    dta h(10000,1000,100,10,1)
edn     dta a(edname)
edname  dta c'ED',EOL
m_quita dta a(m_quit)
m_losea dta a(m_lose)
m_loada dta a(m_load)
m_savea dta a(m_save)
m_tagda dta a(m_tagd)
m_mema  dta a(m_mem)
m_saveda dta a(m_saved)
m_quit  dta c'Quit without saving (Y/N)?',0
m_lose  dta c'Text changed, discard it (Y/N)?',0
m_load  dta c'Load: ',0
m_save  dta c'Save: ',0
m_tagd  dta c'Line tagged',0
m_mem   dta c'Out of memory',0
m_saved dta c'Saved',0
iotrapa dta a(iotrap)
ctrapa  dta a(ctrap)
lbufa   dta a(lbuf)
rowbufa dta a(rowbuf)
fnamea  dta a(fname)
eola    dta a(eolc)
eolc    dta b(EOL)

lo      dta a(0)
hi      dta a(0)
pend    dta a(0)               ; the end of the bottom part
qbeg    dta a(0)               ; the start of the top part
llen    dta 0
cx      dta 0
cy      dta a(0)
nlines  dta a(0)
top     dta a(0)
tag     dta a(0)
oc      dta a(0)
hoff    dta 0
hgt     dta 0
dw      dta 0
dirty   dta 0                  ; 1 the cursor line, 2 the window, 3 all
chg     dta 0
vis     dta 0
msgon   dta 0
chr     dta 0
kch     dta 0
kx      dta 0
clen    dta 0
nlen    dta 0
k       dta 0
r       dta 0
len     dta 0
ex      dta 0
vc      dta 0
nz      dta 0
dg      dta 0
plen    dta 0
ilen    dta 0
hopen   dta 0
hfile   dta 0
err     dta 0
tmp     dta a(0)
tmp2    dta a(0)
num     dta a(0)
fname   :NAMELEN+2 dta 0
ibuf    :NAMELEN+2 dta 0
lbuf    :MAXLEN+1 dta 0
nbuf    :MAXLEN+1 dta 0
cbuf    :MAXLEN+1 dta 0
sbuf    :124 dta 0
mbuf    :120 dta 0
rowbuf  :244 dta 0

        blk update address
        blk update symbols
