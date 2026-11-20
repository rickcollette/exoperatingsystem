; EOS CAR: MAN, the documentation viewer
;   MAN [fname] [/P|?]
; The directories of $MANPATH (separated by ;) hold the pages: files with
; the extension HLP, MAN, DOC or TXT. MAN alone lists the pages. MAN NAME
; finds NAME.HLP/MAN/DOC/TXT along $MANPATH (several: a list to pick one
; from) and shows it through the viewer in $PAGER, or prints it when there
; is none, when the viewer is TYPE or MORE, or with /P. $PAGER is a command
; line with ; for blanks and % where the file goes, a blank after it (at
; the end without %), e.g. SET PAGER=LESS;/C;% ; ECHO as the viewer
; prints the line. /? lists the pages of that name.
U_GETPAR smb 'U_GETPAR'
U_GETKEY smb 'U_GETKEY'
U_LOAD   smb 'U_LOAD'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
PRINTF   smb 'PRINTF'
PUTC     smb 'PUTC'
GETENV   smb 'GETENV'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FCLOSE   smb 'FCLOSE'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'
FLAG     smb 'FLAG'

mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
dentry   equ $0789
LBUFF    equ $0580
LMARGN   equ $52
RMARGN   equ $53
EOL      equ $9B
BSLASH   equ $5C
NMATCH   equ 9                 ; matches kept
MLEN     equ 64                ; bytes of each

t        equ $80               ; string pointer
spec     equ $82               ; the page's specification

        blk reloc main
start   lda #0
        sta opt_p
        sta opt_q
        sta nlen
        sta dotx
p1      jsr U_GETPAR
        beq p_end
        lda COMTAB+$21
        cmp #'/'
        bne p_nm
        ldx #1                 ; switches: /P, /?
ps1     lda COMTAB+$21,x
        cmp #EOL
        beq p1
        cmp #'P'
        bne ps2
        sta opt_p
ps2     cmp #'?'
        bne ps3
        sta opt_q
ps3     inx
        bne ps1
p_nm    lda nlen               ; the page: the first name, without an
        bne p1                 ; extension, at most 8 characters
        ldx #0
pn1     lda COMTAB+$21,x
        cmp #EOL
        beq pn2
        cmp #'.'
        bne pn1a
        sta dotx               ; an extension: not wanted
pn1a    sta pname,x
        inx
        cpx #8
        bcc pn1
pn2     lda #EOL
        sta pname,x
        stx nlen
        jmp p1

p_end   lda mpn                ; $MANPATH
        ldx mpn+1
        jsr GETENV
        bpl mp1
        jsr PRINTF
        dta c'Use: man command',EOL,c'Error: $MANPATH is not defined',EOL,0
        rts
mp1     ldx #0
mp2     lda LBUFF,x
        sta mpath,x
        inx
        cmp #EOL
        beq mp3
        cpx #127
        bcc mp2
        lda #EOL
        sta mpath,x
mp3     lda dotx
        beq mp4
        jsr PRINTF
        dta c'Use: man command',EOL,c'Error: omit the extension',EOL,0
        rts
mp4     lda alla               ; MAN alone: every page
        sta lspec
        lda alla+1
        sta lspec+1
        lda nlen
        beq list
        ldx #0                 ; NAME.*
fn1     lda pname,x
        cmp #EOL
        beq fn2
        sta pstar,x
        inx
        bne fn1
fn2     ldy #0
fn3     lda s_star,y
        sta pstar,x
        inx
        iny
        cpy #3
        bcc fn3
        lda opt_q              ; /?: the pages of that name listed
        jeq find
        lda pstara
        sta lspec
        lda pstara+1
        sta lspec+1

* ---- MAN alone (or with /?): the pages, in the order of the directories, a
* line (or more) for each
list    lda RMARGN             ; columns of 9 characters
        sec
        sbc LMARGN
        bcc cl0
        cmp #31
        bcs cl1
cl0     lda #39
cl1     clc                    ; (width + 1) / 9
        adc #2
        ldx #0
cl2     cmp #9
        bcc cl3
        sbc #9
        inx
        bne cl2
cl3     stx ncols
        lda #0
        sta col
        jsr PRINTF
        dta EOL,c'Available help pages:',EOL,EOL,0
        lda #0
        sta mi
ls1     jsr nextdir
        bcs ls9
        lda col
        beq ls1a
        lda #EOL
        jsr PUTC
        lda #0
        sta col
ls1a    lda lspec
        sta t
        lda lspec+1
        sta t+1
        jsr mkspec
        jsr first
        bcs ls1
ls2     jsr isext
        bcs ls5
        lda col                ; a new column: a line full, or the gap
        beq ls3
        cmp ncols
        bcc ls2a
        lda #EOL
        jsr PUTC
        lda #0
        sta col
        beq ls3
ls2a    lda #' '
ls2b    jsr PUTC
        dec pad
        bpl ls2b
ls3     ldx #0
        lda #8
        sta pad
ls4     lda dentry+6,x
        cmp #' '
        beq ls4a
        jsr PUTC
        dec pad
        inx
        cpx #8
        bcc ls4
ls4a    inc col
ls5     jsr FNEXT
        bpl ls2
        jsr FCLOSE
        jmp ls1
ls9     lda col                ; after a list: its line ended, a blank line
        beq ls10
        lda #EOL
        jsr PUTC
        jsr PUTC
ls10    rts

* ---- MAN NAME: the pages of that name ------------------------------------------
find    lda #0
        sta nm
        sta mi
fd1     jsr nextdir
        bcs fd5
        lda pstara
        sta t
        lda pstara+1
        sta t+1
        jsr mkspec
        jsr first
        bcs fd1
fd2     jsr isext
        bcs fd4
        lda nm                 ; the directory, the name and the extension
        cmp #NMATCH
        bcs fd4
        jsr mslot
        ldx #0
        ldy #0
fd3     lda dbuf,x
        cmp #EOL
        beq fd3a
        sta (t),y
        inx
        iny
        bne fd3
fd3a    lda dsep
        beq fd3b
        sta (t),y
        iny
fd3b    ldx #0
fd3c    lda dentry+6,x
        cmp #' '
        beq fd3d
        sta (t),y
        iny
fd3d    inx
        cpx #8
        bcc fd3c
        lda #'.'
        sta (t),y
        iny
fd3e    lda dentry+6,x
        sta (t),y
        iny
        inx
        cpx #11
        bcc fd3e
        lda #EOL
        sta (t),y
        inc nm
fd4     jsr FNEXT
        bpl fd2
        jsr FCLOSE
        jmp fd1

fd5     lda nm
        bne fd6
        jsr PRINTF
        dta c'No manuals found for ',b($27),c'%s',b($27),EOL,0
        dta a(pname)
        rts
fd6

pick    lda #0                 ; one of several: the user picks it
        sta sel
        lda nm
        cmp #2
        bcc show
pk1     lda sel
        jsr mslot
        ldx sel
        inx
        stx num
        jsr PRINTF
        dta c'%b %p',EOL,0
        dta a(num,t)
        inc sel
        lda sel
        cmp nm
        bcc pk1
        jsr PRINTF
        dta c'Which one (1-%b)? ',0
        dta a(nm)
pk2     jsr U_GETKEY
        bmi pk_no
        cmp #$1B
        beq pk_no
        sec
        sbc #'1'
        bcc pk2
        cmp nm
        bcs pk2
        sta sel
        clc
        adc #'1'
        jsr PUTC
        lda #EOL
        jsr PUTC
        jmp show
pk_no   lda #EOL
        jmp PUTC

* ---- the page: the viewer from $PAGER, or printed ------------------------------
show    lda sel
        jsr mslot
        lda t
        sta spec
        lda t+1
        sta spec+1
        lda opt_p
        jne dump
        lda pgn
        ldx pgn+1
        jsr GETENV
        jmi dump
        ldx #0                 ; the program: up to the first ;
        ldy #0
sh1     lda LBUFF,x
        cmp #EOL
        beq sh2
        cmp #';'
        beq sh2
        sta prog,y
        inx
        iny
        cpy #40
        bcc sh1
sh2     lda #EOL
        sta prog,y
        sty plen
        stx pi
        lda #0                 ; the parameters: ; to blanks, % to the file
        sta pct
        ldy #0
        ldx pi
sh7     lda LBUFF,x
        cmp #EOL
        beq sh9
        inx
        cmp #';'
        bne sh8
        lda #' '
        cpy #0                 ; (not at the start)
        beq sh7
        bne sh8a
sh8     cmp #'%'               ; (and a blank after it)
        bne sh8a
        sta pct
        jsr addspec
        lda #' '
sh8a    jsr addlb
        jmp sh7
sh9     lda pct                ; no %: the file at the end
        bne sh10
        cpy #0
        beq sh9a
        lda #' '
        jsr addlb
sh9a    jsr addspec
sh10    lda #EOL
        sta COMTAB+$3F,y
        lda #0
        sta COMTAB+$0A         ; BUFOFF: the parameters from the start
        lda styp               ; the command processor's own TYPE and MORE:
        ldx styp+1             ; the page printed; ECHO: the parameters
        jsr isprog
        jeq dump
        lda smor
        ldx smor+1
        jsr isprog
        jeq dump
        lda sech
        ldx sech+1
        jsr isprog
        bne sh10b
        ldy #0
ec1     lda COMTAB+$3F,y
        jsr PUTC
        iny
        cmp #EOL
        bne ec1
        rts

sh10b   ldx #0                 ; the program file: .COM unless given
sh11    lda prog,x
        cmp #EOL
        beq sh12
        cmp #'.'
        beq sh13
        inx
        bne sh11
sh12    ldy #0
sh12a   lda s_com,y
        sta prog,x
        inx
        iny
        cpy #5
        bcc sh12a
sh13    ldx #0                 ; with a device or a path: as it is
sh13a   lda prog,x
        cmp #EOL
        beq sh14
        cmp #':'
        beq run
        cmp #'>'
        beq run
        cmp #BSLASH
        beq run
        inx
        bne sh13a
sh14    lda proga              ; the current directory, then $PATH
        sta FILE_P
        lda proga+1
        sta FILE_P+1
        jsr exists
        bcc run
        lda pthn
        ldx pthn+1
        jsr GETENV
        jmi run
        ldx #0
sh15    lda LBUFF,x
        sta mpath,x
        inx
        cmp #EOL
        beq sh16
        cpx #127
        bcc sh15
        lda #EOL
        sta mpath,x
sh16    lda #0
        sta mi
sh17    jsr nextdir
        jcs run                ; nowhere: the loader names it
        lda proga
        sta t
        lda proga+1
        sta t+1
        jsr mkspec
        jsr exists
        bcs sh17
        ldx #0                 ; found: that one
sh18    lda sbuf,x
        sta prog,x
        inx
        cmp #EOL
        bne sh18
run     lda proga
        sta FILE_P
        lda proga+1
        sta FILE_P+1
        lda #0
        sta FLAG
        jmp U_LOAD

* isprog: Z=1 when prog is the name at AX (EOL ended)
isprog  sta t
        stx t+1
        ldy #0
ip1     lda (t),y
        cmp prog,y
        bne ip2
        iny
        cmp #EOL
        bne ip1
ip2     rts

* addspec: the file's specification to the parameters; addlb: A to them
addspec lda spec
        sta t
        lda spec+1
        sta t+1
as1     sty lbn
        ldy #0
        lda (t),y
        ldy lbn
        cmp #EOL
        beq as2
        jsr addlb
        inc t
        bne as1
        inc t+1
        bne as1
as2     rts
addlb   cpy #63
        bcs al1
        sta COMTAB+$3F,y
        iny
al1     rts

* ---- dump: the page printed -------------------------------------------------------
dump    lda spec
        sta FILE_P
        lda spec+1
        sta FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
dp1     lda bufa
        sta addpos
        lda bufa+1
        sta addpos+1
        lda #0
        sta bytbuf
        sta memreix
        lda #1
        sta bytbuf+1
        jsr FREAD
        php
        lda bytbuf
        sta n
        lda bytbuf+1
        sta n+1
        ldx #0
dp2     lda n+1
        bne dp3
        cpx n
        bcs dp4
dp3     lda buf,x
        jsr PUTC
        inx
        bne dp2
        dec n+1
        jmp dp2
dp4     plp
        bpl dp1
        jmp FCLOSE

* ---- helpers ---------------------------------------------------------------------
* nextdir: the next directory of mpath (from mi) to dbuf, dsep = the
* separator to put after it (0: none); C=1 when there are no more
nextdir ldx mi
nd1     lda mpath,x
        cmp #EOL
        beq nd_no
        cmp #';'
        bne nd2
        inx
        bne nd1
nd2     ldy #0
nd3     lda mpath,x
        cmp #EOL
        beq nd4
        cmp #';'
        beq nd4
        sta dbuf,y
        inx
        iny
        cpy #48
        bcc nd3
nd4     stx mi
        lda #EOL
        sta dbuf,y
        lda dbuf-1,y
        ldx #0
        cmp #':'
        beq nd5
        cmp #'>'
        beq nd5
        cmp #BSLASH
        beq nd5
        ldx #'>'
nd5     stx dsep
        clc
        rts
nd_no   stx mi
        sec
        rts

* mkspec: sbuf = dbuf, the separator, the text at t; FILE_P = sbuf
mkspec  ldx #0
mk1     lda dbuf,x
        cmp #EOL
        beq mk2
        sta sbuf,x
        inx
        bne mk1
mk2     lda dsep
        beq mk3
        sta sbuf,x
        inx
mk3     ldy #0
mk4     lda (t),y
        sta sbuf,x
        inx
        iny
        cmp #EOL
        bne mk4
        lda sbufa
        sta FILE_P
        lda sbufa+1
        sta FILE_P+1
        rts

* first: FFIRST on FILE_P, files only; C=1 when nothing (an error too)
first   lda #$80
        sta scan
        lda trapa
        ldx trapa+1
        jsr U_SFAIL
        jsr FFIRST
        jsr U_XFAIL
        bmi fi_no
        clc
        rts
fi_no
trap    sec
        rts

* exists: is there a file FILE_P? C=0 yes
exists  jsr first
        bcs ex1
        jsr FCLOSE
        clc
ex1     rts

* isext: C=0 when dentry's extension is HLP, MAN, DOC or TXT
isext   ldy #11
ie1     ldx #2
ie2     lda dentry+14,x
        cmp exts,y
        bne ie3
        dey
        dex
        bpl ie2
        clc
        rts
ie3     dey                    ; the next extension
        dex
        bpl ie3
        tya
        bpl ie1
        sec
        rts

* mslot: t = the address of match A
mslot   ldx #0
        stx t+1
        asl @                  ; * 64
        asl @
        rol t+1
        asl @
        rol t+1
        asl @
        rol t+1
        asl @
        rol t+1
        asl @
        rol t+1
        clc
        adc matcha
        sta t
        lda t+1
        adc matcha+1
        sta t+1
        rts

exts    dta c'HLPMANDOCTXT'
styp    dta a(s_type)
smor    dta a(s_more)
sech    dta a(s_echo)
s_type  dta c'TYPE',EOL
s_more  dta c'MORE',EOL
s_echo  dta c'ECHO',EOL
s_com   dta c'.COM',EOL
mpn     dta a(mpname)
pgn     dta a(pgname)
pthn    dta a(ptname)
mpname  dta c'MANPATH',EOL
pgname  dta c'PAGER',EOL
ptname  dta c'PATH',EOL
s_all   dta c'*'
s_star  dta c'.*',EOL
alla    dta a(s_all)
pstara  dta a(pstar)
sbufa   dta a(sbuf)
proga   dta a(prog)
matcha  dta a(match)
bufa    dta a(buf)
trapa   dta a(trap)

opt_p   dta 0
opt_q   dta 0
dotx    dta 0
lspec   dta a(0)
nlen    dta 0
ncols   dta 0
col     dta 0
pad     dta 0
mi      dta 0
nm      dta 0
sel     dta 0
num     dta 0
dsep    dta 0
plen    dta 0
pi      dta 0
pct     dta 0
lbn     dta 0
n       dta a(0)
pname   :9 dta 0
pstar   :8 dta 0               ; NAME.* (pname and .*)
        dta 0,0,0,0
mpath   :128 dta 0
dbuf    :50 dta 0
sbuf    :64 dta 0
prog    :48 dta 0
match   :NMATCH*MLEN dta 0
buf     :256 dta 0

        blk update address
        blk update symbols
