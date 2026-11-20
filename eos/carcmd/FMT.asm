; EOS CAR: FMT, the text formatter
;   FMT [/S|J] [<<][path]fname[.ext] [ncol]
; Reads the file (standard input without one) and writes lines of at most
; ncol-1 characters: a line that reaches ncol characters is broken at its
; last blank (the blank goes), or, with no blank in it, before its last
; character (which is lost). What follows a break at a blank is carried on
; with the next line (the EOL becomes a blank) unless that line is empty
; or the text ends. /S takes the blanks at the start of a line and makes
; runs of blanks one; /J justifies the lines broken at a blank to ncol-1
; (blanks at their start and end go, the rest is spread over the gaps
; from the left). ncol is 32 to 127; anything else, or none, is the
; screen width. A second name after the file is the width.
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
PUTC     smb 'PUTC'
FOPEN    smb 'FOPEN'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
GETC     smb 'GETC'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
LMARGN   equ $52
RMARGN   equ $53
EOL      equ $9B
NONE     equ $FF               ; pushed back: nothing

        blk reloc main
start   lda #0
        sta opt_s
        sta opt_j
        sta named
        sta ncol
p1      jsr U_GETPAR
        jeq p_end
        lda COMTAB+$21
        cmp #'/'
        bne p_nm
        ldx #1                 ; switches: /S, /J (together too)
ps1     lda COMTAB+$21,x
        cmp #EOL
        beq p1
        cmp #'S'
        bne ps2
        sta opt_s
        beq ps3
ps2     cmp #'J'
        bne p_bad
        sta opt_j
ps3     inx
        bne ps1
p_bad   lda #156
        jmp U_FAIL
p_nm    lda named              ; the first name: the file
        bne p_num
        inc named
        ldx #0
pn1     lda COMTAB+$21,x
        sta fname,x
        inx
        cmp #EOL
        bne pn1
        beq p1
p_num   ldx #0                 ; the second: the width, if it is a number
        stx val
pd1     lda COMTAB+$21,x
        cmp #EOL
        beq pd3
        cmp #'0'
        jcc p1
        cmp #'9'+1
        jcs p1
        and #$0F
        sta dg
        lda val                ; val = val * 10 + digit, at most 255
        cmp #26
        bcs pd2
        asl @
        asl @
        adc val
        asl @
        adc dg
        bcc pd2a
pd2     lda #255
pd2a    sta val
        inx
        bne pd1
pd3     lda val
        cmp #32
        jcc p1
        cmp #128
        jcs p1
        sta ncol
        jmp p1

p_end   lda ncol               ; none: the screen width
        bne nc1
        lda RMARGN
        sec
        sbc LMARGN
        bcc w40
        cmp #31
        bcc w40
        cmp #127
        bcs w40
        adc #1
        bne w1
w40     lda #40
w1      sta ncol
nc1     lda named
        beq go
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
        lda file_id
        sta hin

go      lda #0
        sta olen
        sta soft
        lda #1
        sta atst
        lda #NONE
        sta back
loop    jsr rdc
        jmi eof
        cmp #EOL
        bne c1
        lda soft               ; after a break at a blank: carried on
        beq c0
        lda #0
        sta soft
        lda olen
        beq loop               ; (nothing left: the line just goes on)
        jsr rdc                ; unless an empty line or the end follows
        bmi c0
        sta back
        cmp #EOL
        beq c0
        lda #' '
        bne c2
c0      lda olen               ; the end of a line: as it is
        sta elen
        jsr emit
        lda #0
        sta olen
        lda #1
        sta atst
        lda back               ; (the end of the text)
        cmp #NONE
        bne loop
        lda eofl
        jne ef1
        jmp loop
c1      ldx #0
        cmp #' '
        bne c3
c2      ldx opt_s              ; /S: no blanks at the start of a line or
        beq c3                 ; of a row, one of several
        ldx atst
        bne loop
        ldx olen
        beq loop
        cmp ob-1,x
        beq loop
c3      ldx #0
        stx atst
        ldx olen
        sta ob,x
        inx
        stx olen
        cpx ncol
        bcc loop
        dex                    ; full: the last blank
f1      lda ob,x
        cmp #' '
        beq f2
        dex
        bne f1
        ldx ncol               ; none: the line without its last character
        dex
        stx elen
        lda #0
        sta soft
        jsr emit
        lda #0
        sta olen
        jmp loop
f2      stx brk
        stx elen
        lda opt_j
        sta just
        jsr emit
        lda #1
        sta soft
        ldx brk                ; the rest to the start of the buffer
        inx
        ldy #0
sh1     cpx olen
        bcs sh2
        lda ob,x
        sta ob,y
        inx
        iny
        bne sh1
sh2     sty olen
        jmp loop

eof     lda olen               ; a last line without EOL
        beq ef1
        sta elen
        jsr emit
ef1     lda named
        beq ef2
        lda hin
        sta file_id
        jsr FCLOSE
ef2     rts

* rdc: the next input byte (the one pushed back first); N=1 at the end
rdc     lda back
        cmp #NONE
        beq rd0
        pha
        lda #NONE
        sta back
        pla
        ldx #0                 ; N=0
        rts
rd0     lda eofl
        bne rd_e
        lda named
        beq rd_in
        lda hin
        sta file_id
        jsr FGETC
        jmp rd1
rd_in   jsr GETC
rd1     bpl rd2
        lda #1
        sta eofl
rd_e    ldx #$FF               ; N=1
rd2     rts

* emit: ob[0..elen) and an EOL; justified to ncol-1 when just is set
* (just is cleared)
emit    lda just
        jeq em_pl
        lda #0
        sta just
        ldx #0                 ; blanks at the start and the end go
em0     cpx elen
        jcs em_pl
        lda ob,x
        cmp #' '
        bne em0a
        inx
        bne em0
em0a    stx bgn
em0b    ldx elen
        lda ob-1,x
        cmp #' '
        bne em0c
        dec elen
        bne em0b
em0c    lda #0                 ; the gaps (runs of blanks)
        sta gaps
        ldx bgn
em1     inx
        cpx elen
        bcs em2
        lda ob,x
        cmp #' '
        bne em1
        lda ob-1,x
        cmp #' '
        beq em1
        inc gaps
        bne em1
em2     lda gaps
        beq em_pb
        clc                    ; the blanks to add: each and the rest
        lda ncol
        sbc elen               ; ncol - 1 - (elen - bgn)
        clc
        adc bgn
        ldx #0
em3     cmp gaps
        bcc em4
        sbc gaps
        inx
        bne em3
em4     sta rest
        stx each
        ldx bgn
em5     cpx elen
        bcs em_eol
        lda ob,x
        jsr PUTC
        cmp #' '
        bne em8
        lda ob-1,x             ; only after the first blank of a run
        cmp #' '
        beq em8
        lda #' '
        ldy each
        beq em7
em6     jsr PUTC
        dey
        bne em6
em7     ldy rest
        beq em8
        dec rest
        jsr PUTC
em8     inx
        bne em5
em_pb   ldx bgn                ; no gap: as it is
        bpl em9
em_pl   ldx #0
em9     cpx elen
        bcs em_eol
        lda ob,x
        jsr PUTC
        inx
        bne em9
em_eol  lda #EOL
        jmp PUTC

opt_s   dta 0
opt_j   dta 0
named   dta 0
ncol    dta 0
val     dta 0
dg      dta 0
hin     dta 0
olen    dta 0
elen    dta 0
atst    dta 0
soft    dta 0
back    dta 0
eofl    dta 0
brk     dta 0
bgn     dta 0
just    dta 0
gaps    dta 0
each    dta 0
rest    dta 0
fna     dta a(fname)
fname   :64 dta 0
ob      :132 dta 0

        blk update address
        blk update symbols
