* DOSKEY.SYS (included in lib2.asm): the command line at the prompt.
* dk_load: DOSKEY [aliases file] [/X]: a history of DK_N lines and the
* aliases (NAME=COMMAND lines) in memory at MEMLO, which stays raised.
* dk_line, instead of the E: line, reads the keys itself: left and right
* arrows, BACKSPACE, characters inserted at the cursor; up arrow, CTRL-P
* or F1 the previous line of the history, down arrow, CTRL-N or F2 the
* next; SHIFT-CLEAR clears the screen; BREAK ends with 128. Then: an alias
* as the first word is replaced by its command; & separates commands,
* given one at a time to the next calls; /X: an empty line is DIR. The
* line goes to LBUF, Y = status (as CIO's). TAB completes the name at the
* cursor from its directory: one match goes in, more are listed.

DK_N    equ 16                 ; history lines, 64 bytes each
DK_AMAX equ 1024               ; aliases at most
dk_p    equ fadr
dk_buf  equ LBUFF+64           ; the line being typed (CP_NAME's place: free then)
dk_fn   equ LBUFF              ; the aliases file's name while loading
dt_txt  equ LBUFF+$20          ; TAB: a name found (LBUFF: the first one)
dk_ws   equ LBUFF+$40-1        ; TAB's scratch (below dk_buf)
dk_ns   equ LBUFF+$40-2
dk_dot  equ LBUFF+$40-3
dk_nm   equ LBUFF+$40-4
dk_fid  equ LBUFF+$40-5

dk_load lda #0
        sta dk_x
        sta dk_na
dl0     jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq dl_mem
        lda COMTAB+CT_COMFNAM
        cmp #'/'
        bne dl1
        lda COMTAB+CT_COMFNAM+1
        cmp #'X'
        bne dl0
        lda #$80
        sta dk_x
        jmp dl0
dl1     ldx #0                 ; the aliases file's name, kept
dl1a    lda COMTAB+CT_COMFNAM,x
        sta dk_fn,x
        inx
        cmp #EOL
        bne dl1a
        dec dk_na
        jmp dl0
dl_mem  lda MEMLO              ; the history at MEMLO
        sta dk_h
        lda MEMLO+1
        sta dk_h+1
        lda #0
        sta dk_hn
        sta dk_hw
        sta dk_al
        sta dk_al+1
        sta dk_pend
        lda dk_h               ; the & parts after it (64 bytes), then the
        clc                    ; aliases
        adc #<(DK_N*64+64)
        sta addpos
        sta dk_a
        lda dk_h+1
        adc #>(DK_N*64+64)
        sta addpos+1
        sta dk_a+1
        bit dk_na
        bpl dl_end
        ldx #0
dl2     lda dk_fn,x
        sta COMTAB+CT_COMFNAM,x
        inx
        cmp #EOL
        bne dl2
        lda #<(COMTAB+CT_COMFNAM)
        sta FILE_P
        lda #>(COMTAB+CT_COMFNAM)
        sta FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        jsr farcall
        dta b(BK_LIB),a(L_FOPEN)
        lda #<DK_AMAX
        sta bytbuf
        lda #>DK_AMAX
        sta bytbuf+1
        lda #0
        sta memreix
        jsr farcall
        dta b(BK_LIB),a(L_FREAD)
        jsr farcall
        dta b(BK_LIB),a(L_FCLOSE)
        lda bytbuf
        sta dk_al
        lda bytbuf+1
        sta dk_al+1
dl_end  lda dk_a               ; MEMLO past the aliases, a 0 after them
        clc
        adc dk_al
        sta dk_p
        lda dk_a+1
        adc dk_al+1
        sta dk_p+1
        ldy #0
        tya
        sta (dk_p),y
        lda dk_p
        clc
        adc #1
        sta MEMLO
        lda dk_p+1
        adc #0
        sta MEMLO+1
        lda #$80
        sta dk_on
        rts

* dk_line: the next command line to LBUF; Y = status
dk_line lda dk_pend            ; the rest of an & line first
        beq dk_key
        jmp dk_next
dk_key  lda #0
        sta dk_len
        sta dk_cur
        lda dk_hn              ; the history: from the newest
        sta dk_hi
dk_get  jsr dk_kbd
        cpy #128
        bcc dk_k1
        jmp dk_brk
dk_k1   cmp #EOL
        jeq dk_eol
        cmp #$7E               ; BACKSPACE
        jeq dk_bs
        cmp #$1E               ; left
        jeq dk_left
        cmp #$1F               ; right
        jeq dk_right
        cmp #$1C               ; up, CTRL-P, F1
        jeq dk_up
        cmp #$10
        jeq dk_up
        cmp #$03
        jeq dk_up
        cmp #$1D               ; down, CTRL-N, F2
        jeq dk_down
        cmp #$0E
        jeq dk_down
        cmp #$04
        jeq dk_down
        cmp #$7D               ; SHIFT-CLEAR: an empty line on a clear screen
        jeq dk_clr
        cmp #$1B               ; ESC: nothing
        jeq dk_get
        cmp #$7F               ; TAB: the name completed
        jeq dk_tab
        ldx dk_len             ; a character, inserted at the cursor
        cpx #63
        bcc dk_ins
        lda #$FD               ; full: the buzzer
        jsr dk_putc
        jmp dk_get
dk_ins  sta dk_t
dk_i1   cpx dk_cur
        beq dk_i2
        lda dk_buf-1,x
        sta dk_buf,x
        dex
        bne dk_i1
dk_i2   lda dk_t
        sta dk_buf,x
        inc dk_len
        jsr dk_putc
        inc dk_cur
        jsr dk_tail
        jmp dk_get

* dk_tail: the line from the cursor on again, a blank after it, the
* cursor back
dk_tail ldx dk_cur
        stx dk_t
dt1     cpx dk_len
        bcs dt2
        lda dk_buf,x
        jsr dk_putc
        inx
        bne dt1
dt2     lda #' '
        jsr dk_putc
        inx
dt3     lda #$1E
        jsr dk_putc
        dex
        cpx dk_t
        bne dt3
        rts

dk_bs   ldx dk_cur
        beq dk_get2
        dec dk_cur
        lda #$1E
        jsr dk_putc
        ldx dk_cur
db1     inx
        cpx dk_len
        beq db2
        bcs db2
        lda dk_buf,x
        sta dk_buf-1,x
        jmp db1
db2     dec dk_len
        jsr dk_tail
dk_get2 jmp dk_get
dk_left ldx dk_cur
        beq dk_get2
        dec dk_cur
        lda #$1E
        jsr dk_putc
        jmp dk_get
dk_right ldx dk_cur
        cpx dk_len
        bcs dk_get2
        inc dk_cur
        lda #$1F
        jsr dk_putc
        jmp dk_get

* up and down: the older or newer line of the history in the line
dk_up   lda dk_hi
        cmp dk_hw              ; the oldest kept?
        beq dk_get2
        sec
        sbc #1
        and #DK_N-1
        sta dk_hi
        jmp dk_show
dk_down lda dk_hi
        cmp dk_hn
        beq dk_get2
        clc
        adc #1
        and #DK_N-1
        sta dk_hi
dk_show jsr dk_wipe
        lda dk_hi
        cmp dk_hn              ; past the newest: empty
        beq ds_end
        jsr dk_ent
        ldy #0                 ; (copied first: PUTC uses fadr)
ds1     lda (dk_p),y
        cmp #EOL
        beq ds2
        sta dk_buf,y
        iny
        cpy #63
        bcc ds1
ds2     sty dk_len
        sty dk_cur
        ldy #0
ds3     cpy dk_len
        beq ds_end
        lda dk_buf,y
        jsr dk_putc
        iny
        bne ds3
ds_end  jmp dk_get
* dk_wipe: the line off the screen (the cursor to its end, then back)
dk_wipe ldx dk_cur
dw1     cpx dk_len
        bcs dw2
        lda #$1F
        jsr dk_putc
        inx
        bne dw1
dw2     ldx dk_len
        beq dw4
dw3     lda #$7E
        jsr dk_putc
        dex
        bne dw3
dw4     lda #0
        sta dk_len
        sta dk_cur
        rts
* dk_ent: dk_p = history line A
dk_ent  lsr @                  ; A * 64
        sta dk_p+1
        lda #0
        ror @
        lsr dk_p+1
        ror @
        clc
        adc dk_h
        sta dk_p
        lda dk_p+1
        adc dk_h+1
        sta dk_p+1
        rts

dk_clr  lda #$7D
        jsr dk_putc
        lda #0
        sta dk_len
        jmp dk_done
dk_brk  lda #EOL
        jsr dk_putc
        ldy #128
        rts

dk_eol  ldx dk_cur             ; the cursor to the end, then the EOL
de1     cpx dk_len
        bcs de2
        lda #$1F
        jsr dk_putc
        inx
        bne de1
de2     lda #EOL
        jsr dk_putc
        ldx dk_len             ; kept in the history unless empty
        beq dk_done
        lda dk_hn
        jsr dk_ent
        ldy #0
de3     cpy dk_len
        beq de4
        lda dk_buf,y
        sta (dk_p),y
        iny
        bne de3
de4     lda #EOL
        sta (dk_p),y
        lda dk_hn
        clc
        adc #1
        and #DK_N-1
        sta dk_hn
        cmp dk_hw              ; full: the oldest goes
        bne dk_done
        clc
        adc #1
        and #DK_N-1
        sta dk_hw
dk_done ldx dk_len             ; the line, an EOL after it
        lda #EOL
        sta dk_buf,x
        lda dk_len
        bne dd1
        bit dk_x               ; /X: an empty line lists the directory
        bpl dd1
        ldx #3
dd0     lda dk_dir,x
        sta dk_buf,x
        dex
        bpl dd0
dd1     jsr dk_alias
        jsr dk_pp              ; kept after the history, split at the &s
        ldy #0
dd3     lda dk_buf,y
        sta (dk_p),y
        iny
        cmp #EOL
        bne dd3
        lda #0
        sta dk_rp
        lda #$80
        sta dk_pend
* dk_next: the next & part to LBUF
dk_next jsr dk_pp
        ldy dk_rp
        ldx #0
dn1     lda (dk_p),y
        cmp #'&'
        beq dn2
        cmp #EOL
        beq dn3
        sta LBUF,x
        inx
        iny
        cpx #63
        bcc dn1
        bcs dn3
dn2     iny                    ; more after it
        sty dk_rp
        bne dn4
dn3     lda #0
        sta dk_pend
dn4     lda #EOL
        sta LBUF,x
        ldy #1
        rts
* dk_pp: dk_p = the & parts' place (after the history)
dk_pp   lda dk_h
        clc
        adc #<(DK_N*64)
        sta dk_p
        lda dk_h+1
        adc #>(DK_N*64)
        sta dk_p+1
        rts
dk_dir  dta c'DIR',b(EOL)

* dk_alias: the first word of dk_buf an alias? Then its command and the
* rest of the line instead
dk_alias lda dk_al
        ora dk_al+1
        beq da_ret
        lda dk_a
        sta dk_p
        lda dk_a+1
        sta dk_p+1
da_line ldy #0
        lda (dk_p),y
        beq da_ret
        ldx #0                 ; NAME= against the word
da1     lda (dk_p),y
        cmp #'='
        beq da_eq
        cmp #EOL
        beq da_next
        cmp dk_buf,x
        bne da_next
        iny
        inx
        bne da1
da_eq   lda dk_buf,x           ; the whole word?
        cmp #' '
        beq da_hit
        cmp #EOL
        beq da_hit
da_next ldy #0
dan1    lda (dk_p),y
        beq da_ret
        iny
        cmp #EOL
        bne dan1
        tya
        clc
        adc dk_p
        sta dk_p
        bcc da_line
        inc dk_p+1
        bne da_line
da_ret  rts
da_hit  stx dk_t               ; the command, then the rest of the line
        iny
        ldx #0
dh1     lda (dk_p),y
        cmp #EOL
        beq dh2
        sta LBUFF,x
        inx
        iny
        cpx #63
        bcc dh1
dh2     ldy dk_t
dh3     lda dk_buf,y
        sta LBUFF,x
        cmp #EOL
        beq dh4
        iny
        inx
        cpx #63
        bcc dh3
        lda #EOL
        sta LBUFF,x
dh4     ldx #0
dh5     lda LBUFF,x
        sta dk_buf,x
        inx
        cmp #EOL
        bne dh5
        rts

* dk_tab: the word before the cursor + "*" (".*" when it has no dot) looked
* up (kd_first, kd_next): one match replaces the name part of the word;
* more are listed on lines of their own and the line is shown again; none:
* the buzzer
dk_tab  ldx dk_cur             ; the word's start
dt_w1   txa
        beq dt_w2
        lda dk_buf-1,x
        cmp #' '
        beq dt_w2
        dex
        bne dt_w1
dt_w2   stx dk_ws
        stx dk_ns              ; and its name part's (after > : backslash)
        ldy #0                 ; the pattern in COMFNAM
        lda #0
        sta dk_dot
dt_p1   cpx dk_cur
        bcs dt_p3
        lda dk_buf,x
        sta COMTAB+CT_COMFNAM,y
        cmp #'.'
        bne dt_p2
        sta dk_dot
dt_p2   cmp #'>'
        beq dt_ps
        cmp #':'
        beq dt_ps
        cmp #BSLASH
        bne dt_p2a
dt_ps   inx
        stx dk_ns
        dex
        lda #0
        sta dk_dot
dt_p2a  inx
        iny
        bne dt_p1
dt_p3   lda #'*'
        sta COMTAB+CT_COMFNAM,y
        iny
        lda dk_dot
        bne dt_p4
        lda #'.'
        sta COMTAB+CT_COMFNAM,y
        iny
        lda #'*'
        sta COMTAB+CT_COMFNAM,y
        iny
dt_p4   lda #EOL
        sta COMTAB+CT_COMFNAM,y
        lda #<(COMTAB+CT_COMFNAM)
        sta FILE_P
        lda #>(COMTAB+CT_COMFNAM)
        sta FILE_P+1
        lda #$20               ; not hidden
        sta scan
        jsr farcall
        dta b(BK_LIB),a(L_GEFINA2)
        jcs dt_none
        ldy #10                ; kd_first
        jsr jkernel
        bmi dt_none
        lda file_id
        sta dk_fid
        lda #0
        sta dk_nm
        jsr dt_name            ; the first: kept in LBUFF
        ldx #0
dt_k1   lda dt_txt,x
        sta LBUFF,x
        inx
        cmp #EOL
        bne dt_k1
dt_more lda dk_fid             ; more?
        sta file_id
        ldy #6
        jsr jkernel
        bmi dt_end
        lda dk_nm
        bne dt_m1
        lda #EOL               ; the second: the first is listed too
        jsr dk_putc
        ldx #0
dt_m0   lda LBUFF,x
        jsr dk_putc
        inx
        cmp #EOL
        bne dt_m0
dt_m1   inc dk_nm
        jsr dt_name
        ldx #0
dt_m2   lda dt_txt,x
        jsr dk_putc
        inx
        cmp #EOL
        bne dt_m2
        jmp dt_more
dt_end  lda dk_fid             ; closed
        sta file_id
        ldy #7
        jsr jkernel
        lda dk_nm
        beq dt_one
        ldx #0                 ; the line again under the list
dt_e1   cpx dk_len
        bcs dt_e2
        lda dk_buf,x
        jsr dk_putc
        inx
        bne dt_e1
dt_e2   stx dk_cur
        jmp dk_get
dt_none lda #$FD
        jsr dk_putc
        jmp dk_get
dt_one  jsr dk_wipe2           ; one: in the line instead of the name part
        ldx dk_ns              ; (what was after the cursor goes)
        ldy #0
dt_o1   lda LBUFF,y
        cmp #EOL
        beq dt_o2
        cpx #63
        bcs dt_o2
        sta dk_buf,x
        inx
        iny
        bne dt_o1
dt_o2   stx dk_len
        ldx #0
dt_o3   cpx dk_len
        bcs dt_o4
        lda dk_buf,x
        jsr dk_putc
        inx
        bne dt_o3
dt_o4   stx dk_cur
        jmp dk_get
* dk_wipe2: the whole line off the screen (dk_wipe, the length kept)
dk_wipe2 lda dk_len
        pha
        jsr dk_wipe
        pla
        sta dk_len
        rts
* dt_name: dentry's name as NAME.EXT (EOL ended) in dt_txt
dt_name ldx #0
        ldy #0
dn_n1   lda dentry+6,y
        cmp #' '
        beq dn_n2
        sta dt_txt,x
        inx
dn_n2   iny
        cpy #8
        bcc dn_n1
        lda dentry+14
        cmp #' '
        beq dn_n4
        lda #'.'
        sta dt_txt,x
        inx
dn_n3   lda dentry+6,y
        cmp #' '
        beq dn_n3a
        sta dt_txt,x
        inx
dn_n3a  iny
        cpy #11
        bcc dn_n3
dn_n4   lda #EOL
        sta dt_txt,x
        rts

* dk_kbd: a key (the OS's K: GET), A; Y = status
dk_kbd  lda KEYBDV+5
        pha
        lda KEYBDV+4
        pha
        rts
dk_putc jsr farcall            ; (keeps X and Y)
        dta b(BK_LIB),a(L_PUTC)
        rts
