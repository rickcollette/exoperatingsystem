; EOS Toolkit: FT, find a text in text files
;   FT [d:][path][fname[.ext]] [/C][/I][/V] [pattern]
; The pattern is the rest of the line (spaces too), or asked for when
; there is none; at most 128 characters. Escapes: \a bell, \b $7E, \e
; escape, \n EOL, \s blank, \t tab, \z and \0 zero, \xHH any code, \cX
; X's low 5 bits, \? any character, \ before anything else: that
; character. A blank in the pattern also matches a tab or the EOL.
; Each line that has the pattern is shown as NAME,line:text (lines from
; 0, tabs as blanks); for one file given without wildcards without the
; name. /C: the number of matching lines of each file instead (one file
; without wildcards: the lines too). /I: upper and lower case alike. /V:
; each file's name before it is searched. At the end the number of all
; matching lines. A line ends at an EOL or after 255 characters; a
; longer one ends the search in that file.
U_GETATR smb 'U_GETATR'
U_FSPEC  smb 'U_FSPEC'
U_SLASH  smb 'U_SLASH'
U_PATH   smb 'U_PATH'
U_EXPAND smb 'U_EXPAND'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FCLOSE   smb 'FCLOSE'
FCLOSEAL smb 'FCLOSEAL'
GETS     smb 'GETS'
PUTS     smb 'PUTS'
PRINTF   smb 'PRINTF'
TOUPPER  smb 'TOUPPER'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

BUFOFF   equ $0A               ; (COMTAB+: the place in the line)
LBUF     equ $3F               ; (COMTAB+: the command line)
DSPFLG   equ $02FE
file_id  equ $0760
name     equ $0762
mode     equ $0778
addpos   equ $0782
bytbuf   equ $0785
dentry   equ $0789
EOL      equ $9B
BSLASH   equ $5C
TAB      equ $7F
BUFSZ    equ 512

dst      equ $80               ; (rdline)
src      equ $82               ; (getc)

        blk reloc main
start   lda #0
        ldx #2
s0      sta total,x
        dex
        bpl s0
        sta single
        lda #$80               ; files, not directories
        jsr U_GETATR
        jsr U_FSPEC
        lda a_opts
        ldx a_opts+1
        ldy #6
        jsr U_SLASH
        jsr FFIRST
        bmi finish
        ldx #10                ; no wildcard: one file
s1      lda name,x
        cmp #'?'
        beq s2
        dex
        bpl s1
        dec single
s2      lda file_id
        sta dirid
        lda mode
        sta dirmode
        jsr names
        ldx COMTAB+BUFOFF      ; the pattern: the rest of the line,
        dex                    ; from the first character that is no
s2a     inx                    ; separator (U_SLASH may stop before
        lda COMTAB+LBUF,x      ; them), or asked for
        cmp #' '
        beq s2a
        cmp #','
        beq s2a
        ldy #0
        cmp #EOL
        bne s4
        jsr PRINTF
        dta c'Search for:',b(EOL,0)
        lda a_raw
        ldx a_raw+1
        ldy #128
        jsr GETS
        bpl pattern
finish  jsr FCLOSEAL
        jsr PRINTF
        dta b(EOL),c'%e matches total',b(EOL,0)
        dta a(total)
        rts
s3      lda COMTAB+LBUF,x
s4      sta raw,y
        cmp #EOL
        beq pattern
        inx
        iny
        bpl s3
        lda #EOL
        sta raw+127

pattern ldx #$FF               ; the pattern from raw: escapes, any
        ldy #0                 ; characters marked, /I in capitals
p1      sty patlen
        lda #0
        sta wild,y
        inx
        bmi p3
        lda raw,x
        cmp #EOL
        beq p3
        cmp #BSLASH
        bne p2
        jsr escape
p2      bit opt_i
        bpl p2a
        jsr TOUPPER
p2a     sta pat,y
        iny
        bpl p1
p3      lda patlen
        beq finish

file    lda a_full             ; each file
        sta FILE_P
        lda a_full+1
        sta FILE_P+1
        bit opt_v
        bpl f0
        jsr PRINTF
        dta c'%p',b(EOL,0)
        dta a(FILE_P)
f0      lda #4
        sta mode
        jsr FOPEN
        lda #0
        sta bpos
        sta bpos+1
        sta blen
        sta blen+1
        sta beof
        ldx #2
f1      lda #$FF               ; line -1, no matches yet
        sta lineno,x
        lda #0
        sta count,x
        dex
        bpl f1
line    inc lineno
        bne l0
        inc lineno+1
        bne l0
        inc lineno+2
l0      jsr rdline
        sty linelen
        php
        pla
        sta lstat
        jsr match
        bcc l4
        ldx #0
        jsr inc24
        ldx #count-total
        jsr inc24
        bit single             ; one file: no name, the lines even with /C
        bmi l1
        bit opt_c
        bmi l4
        jsr PRINTF
        dta c'%s,',0
        dta a(short)
l1      ldx #0                 ; tabs shown as blanks
l2      lda linebuf,x
        cmp #TAB
        bne l3
        lda #' '
        sta linebuf,x
l3      inx
        cpx linelen
        bcc l2
        ror DSPFLG             ; (C=1: control codes shown as they are)
        jsr PRINTF
        dta c'%e:',0
        dta a(lineno)
        lda a_line
        ldx a_line+1
        ldy #255
        jsr PUTS
        asl DSPFLG
l4      bit lstat
        bmi l5
        jmp line
l5      jsr FCLOSE
        bit opt_c
        bpl l6
        jsr PRINTF
        dta c'%s: %e matches',b(EOL,0)
        dta a(short,count)
l6      lda dirid
        sta file_id
        lda dirmode
        sta mode
        jsr FNEXT
        bpl l7
        jmp finish
l7      jsr names
        jmp file

* inc24: total+X plus 1
inc24   inc total,x
        bne i1
        inc total+1,x
        bne i1
        inc total+2,x
i1      rts

* match: C=1 when the pattern is in the line
match   lda linelen
        cmp patlen
        bcc m_ret              ; (C=0)
        lda #0
        sta mstart
m1      ldx #0
        ldy mstart
m2      cpx patlen
        bcs m_ret              ; (C=1: all of it)
        cpy linelen
        beq m_no
        lda linebuf,y
        bit opt_i
        bpl m3
        cmp #'a'
        bcc m3
        cmp #'z'+1
        bcs m3
        and #$DF
m3      sta mch
        lda wild,x
        bmi m4
        lda pat,x
        cmp mch
        beq m4
        cmp #' '               ; a blank matches a tab or the EOL too
        bne m5
        lda mch
        cmp #TAB
        beq m4
        cmp #EOL
        bne m5
m4      inx
        iny
        bne m2
m5      inc mstart
        bne m1
m_no    clc
m_ret   rts

* names: the entry's name with the device and path (to open it), and
* alone (to show it)
names   ldx #10
n1      lda dentry+6,x
        sta name,x
        dex
        bpl n1
        lda a_full
        ldx a_full+1
        ldy #0
        jsr U_PATH
        lda a_full
        ldx a_full+1
        jsr U_EXPAND
        lda a_short
        ldx a_short+1
        ldy #0
        jmp U_EXPAND

* hexdig: A a hex digit's value (anything else: 0)
hexdig  jsr TOUPPER
        cmp #'0'
        bcc hx_no
        cmp #'9'+1
        bcc hx1
        cmp #'A'
        bcc hx_no
        cmp #'F'+1
        bcs hx_no
        sbc #'A'-10-1-'0'      ; (C=0)
hx1     and #$0F
        rts
hx_no   lda #0
        rts

* escape: the character after the backslash at raw+X; A = its code,
* X at its last character; keeps Y
escape  sty esc_y
        inx
        lda raw,x
        jsr TOUPPER
        ldy #7
e1      cmp esc_let,y
        beq e_tab
        dey
        bpl e1
        cmp #'?'
        beq e_any
        cmp #'X'
        beq e_hex
        cmp #'C'
        bne e_raw
        cpx #127               ; \cX
        bcs e_raw
        inx
        lda raw,x
        and #$1F
        bpl e_ret
e_hex   cpx #126               ; \xHH
        bcs e_raw
        inx
        lda raw,x
        jsr hexdig
        asl @
        asl @
        asl @
        asl @
        sta hexhi
        inx
        lda raw,x
        jsr hexdig
        ora hexhi
e_ret   ldy esc_y
        rts
e_any   ldy esc_y              ; \?: any character
        lda #$80
        sta wild,y
e_raw   lda raw,x
        ldy esc_y
        rts
e_tab   lda esc_val,y
        ldy esc_y
        rts

* rdline: a line (up to 255 characters, the EOL kept) to linebuf; Y = its
* length. N=1 at the end of the file or when the line does not end
rdline  lda #0
        sta rl_y
rl1     ldy rl_y
        cpy #255
        bcs rl_full
        jsr getc
        bmi rl_end
        ldy rl_y
        sta linebuf,y
        iny
        sty rl_y
        cmp #EOL
        bne rl1
        lda #0                 ; N=0
        rts
rl_full lda #$FF               ; N=1
        rts
rl_end  ldy rl_y
        ldx #$FF               ; N=1
        rts

* getc: the next byte of the file through the buffer; N=1 at the end
getc    lda bpos
        cmp blen
        lda bpos+1
        sbc blen+1
        bcs gc_fill
        clc
        lda a_buf
        adc bpos
        sta src
        lda a_buf+1
        adc bpos+1
        sta src+1
        ldy #0
        lda (src),y
        inc bpos
        bne gc1
        inc bpos+1
gc1     ldy #1                 ; N=0
        rts
gc_fill ldy beof
        bmi gc_ret             ; (N=1)
        lda a_buf
        sta addpos
        lda a_buf+1
        sta addpos+1
        lda #<BUFSZ
        sta bytbuf
        lda #>BUFSZ
        sta bytbuf+1
        jsr FREAD
        bpl gc2
        lda #$88
        sta beof
gc2     lda bytbuf
        sta blen
        lda bytbuf+1
        sta blen+1
        lda #0
        sta bpos
        sta bpos+1
        beq getc
gc_ret  rts

a_opts  dta a(opt_c)
a_raw   dta a(raw)
a_line  dta a(linebuf)
a_full  dta a(full)
a_short dta a(short)
a_buf   dta a(buf)
opt_c   dta b(0),c'C'
opt_i   dta b(0),c'I'
opt_v   dta b(0),c'V'
esc_let dta c'ABENSTZ0'
esc_val dta b($FD,$7E,$1B,EOL,' ',TAB,0,0)
total   dta 0,0,0              ; (count 3 bytes after, for inc24)
count   dta 0,0,0
lineno  dta 0,0,0
single  dta 0
dirid   dta 0
dirmode dta 0
lstat   dta 0
linelen dta 0
patlen  dta 0
mstart  dta 0
mch     dta 0
esc_y   dta 0
hexhi   dta 0
rl_y    dta 0
bpos    dta a(0)
blen    dta a(0)
beof    dta 0
full    :84 dta 0
short   :13 dta 0
pat     :128 dta 0
wild    :128 dta 0
raw     :128 dta 0
linebuf    :256 dta 0
buf     :BUFSZ dta 0

        blk update address
        blk update symbols
