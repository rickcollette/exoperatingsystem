; EOS Toolkit: the common part of the Unix-like tools that read files
; (CAT, HEAD, TAIL, STRINGS), included after the tool's code and data:
; the command line with Unix-style switches, the input (a file or
; standard input) and the free memory.
; The tool includes UNIXH.icl first (the addresses) and declares
; U_GETPAR, FOPEN, COMTAB, FILE_P; it has:
;   unsw    (flag, letter) pairs of its switches, UNSWN their size in bytes
;   unval   the letter that takes a number (-n 5, -n5, also -5), or 0
;   unend   equ * after everything (the free memory starts there)

* unargs: the command line. Words starting with - before the first name
* are switches: letters from unsw (each flag counted down per time
* given; several in one word, -nv), unval with its number (in the word or
* the next one) to unnum, or digits alone (-5) when the tool has unval.
* The other words are file names, each to unames ended by EOL, unfiles
* their count. C=1: a lone -, an unknown letter, a bad number, too many
* names (the tool's usage).
unargs  ldy #0
        sty unfiles
        sty unlen
        sty unstop
        lda #1                 ; argv[0] is the command name
        sta unargi
ua0     cpy #UNSWN
        bcs ua1
        lda #0
        sta unsw,y
        iny
        iny
        bne ua0
ua1     jsr unnext
		jeq ua_ok
        bit unstop
		jmi ua_nm
        lda unfiles
		jne ua_nm
        lda COMTAB+$21
        cmp #'-'
		jne ua_nm
        ldx #1
        lda COMTAB+$21,x
        cmp #EOL
        jeq ua_bad             ; a lone -
        cmp #'-'
        bne ua2
        ldx #2
        lda COMTAB+$21,x
        cmp #EOL               ; -- ends option parsing
        bne ua_help
        dec unstop
        jmp ua1
ua_help ldx #2                 ; --help is the common usage request
        ldy #0
uah1    lda COMTAB+$21,x
        cmp unhelp,y
        jne ua_bad
        inx
        iny
        cpy #4
        bcc uah1
        lda COMTAB+$21,x
        cmp #EOL
        jeq ua_bad
        jne ua_bad
ua2     lda COMTAB+$21,x
        cmp #EOL
        beq ua1
        jsr TOLOWER            ; shared ATASCII/case normalization
        jsr undig
        bcc ua_dig
        cmp unval
        beq ua_val
        ldy #1
ua3     cpy #UNSWN
        jcs ua_bad
        cmp unsw,y
        beq ua4
        iny
        iny
        bne ua3
ua4     dey
        lda unsw,y
        sec
        sbc #1
        sta unsw,y
        inx
        bne ua2
ua_dig  lda unval              ; -5: only for a tool with a number
        jeq ua_bad
        bne ua_v1
ua_val  inx                    ; -n5, or -n 5
        lda COMTAB+$21,x
        cmp #EOL
        bne ua_v1
        jsr unnext
        jeq ua_bad
        ldx #0
ua_v1   jsr unnumw
		jcc ua1
ua_bad  sec
        rts
ua_ok   clc
        rts
ua_nm   ldy unlen              ; a name
        ldx #0
ua5     lda COMTAB+$21,x
        sta unames,y
        iny
        jeq ua_bad
        inx
        cmp #EOL
        bne ua5
        sty unlen
        inc unfiles
        jmp ua1

* unnext: the next native argv word in COMFNAM, in the shape expected by
* the compact option parser.  This is the only copy; names then live in the
* bounded unames area used by the original streaming tools.
unnext lda unargi
        jsr U_ARGV
        bcs unn_none
        sta $8E
        stx $8F
        sty unalen
        ldy #0
unn_cp  cpy unalen
        beq unn_end
        lda ($8E),y
        sta COMTAB+$21,y
        iny
        bne unn_cp
unn_end lda #EOL
        sta COMTAB+$21,y
        inc unargi
        tya
        rts
unn_none lda #EOL
        sta COMTAB+$21
        lda #0
        rts

* unnumw: the decimal number at COMTAB+$21+X up to EOL to unnum (0 to
* 65535); C=1 none or not one
unnumw  lda #0
        sta unnum
        sta unnum+1
        lda COMTAB+$21,x
        jsr undig
        bcs un_ret
un1     sta untmp              ; unnum = unnum * 10 + the digit
        lda unnum+1
        pha
        lda unnum
        asl @
        rol unnum+1
        bcs un_ov
        asl @
        rol unnum+1
        bcs un_ov
        adc unnum              ; (C=0) * 5
        sta unnum
        pla
        adc unnum+1
        sta unnum+1
        bcs un_ret
        asl unnum
        rol unnum+1
        bcs un_ret
        lda unnum
        adc untmp              ; (C=0)
        sta unnum
        bcc un2
        inc unnum+1
        beq un_bad
un2     inx
        lda COMTAB+$21,x
        cmp #EOL
        beq un_ok
        jsr undig
        bcc un1
        rts
un_ov   pla
un_bad  sec
        rts
un_ok   clc
un_ret  rts

* undig: A a digit: C=0 and A its value; C=1 not one (A kept)
undig   cmp #'0'
        bcc ud_no
        cmp #'9'+1
        bcs ud_ret
        and #$0F
        rts
ud_no   sec
ud_ret  rts

* unin: the input opened, its handle in file_id: the one file named, or
* standard input when none is; C=1 more than one name
unin    lda unfiles
        bne ui1
        lda COMTAB+7
        sta file_id
        clc
        rts
ui1     cmp #2
        bcs ui_ret
        ldx #0
* unopen: the file named at unames+X opened for reading; keeps X
unopen  jsr unptr
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        stx untmp
        jsr FOPEN
        ldx untmp
        clc
ui_ret  rts

* unptr: FILE_P at the name at unames+X; keeps X
unptr   txa
        clc
        adc a_unames
        sta FILE_P
        lda a_unames+1
        adc #0
        sta FILE_P+1
        rts

* unmem: the free memory from the end of the program (or MEMLO, when
* higher) to MEMTOP: unbot, untop
unmem   lda a_unend
        sta unbot
        lda a_unend+1
        sta unbot+1
        lda MEMLO+1
        cmp unbot+1
        bcc um1
        bne um0
        lda MEMLO
        cmp unbot
        bcc um1
um0     lda MEMLO
        sta unbot
        lda MEMLO+1
        sta unbot+1
um1     lda MEMTOP
        sta untop
        lda MEMTOP+1
        sta untop+1
        rts


a_unames dta a(unames)
a_unend dta a(unend)
unfiles dta 0
unstop  dta 0
unargi  dta 0
unalen  dta 0
unlen   dta 0
unnum   dta a(0)
untmp   dta 0
unbot   dta a(0)
untop   dta a(0)
unames  :256 dta 0
unhelp  dta c'help'
