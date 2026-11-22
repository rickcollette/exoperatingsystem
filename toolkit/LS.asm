; EOS Toolkit: LS, the files of a directory
;   LS [-clwa] [+|-][AHPS] [d:][path/][pattern]
; The switches come first, each as -x or /X, several letters after one
; - or / (-la, /L/A). A - group made only of the letters C L W A is
; switches, any other one (-H, -S, -AH) attributes as everywhere.
; Plain: one full name per line, as the SDX Toolkit's LS: the device as
; it is given (none for the current one; -c: D before the device and the
; colon always), the path, the name, > after a directory. Without -a or
; attributes neither hidden entries nor directories; -a: all entries.
; -l: one line per entry, name, size (bytes, K from 100000 on, M from
; 10000K on, <DIR>), date, time and the attributes H P A (- when not
; set), 37 columns. -w: the names in columns 13 wide, as many as fit the
; screen. -l wins over -w; -c counts only for the plain list.
U_GETATR smb 'U_GETATR'
U_ARGV   smb 'U_ARGV'
U_FSPEC  smb 'U_FSPEC'
U_FAIL   smb 'U_FAIL'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
FCLOSE   smb 'FCLOSE'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
CURDEV   smb 'CURDEV'
DEVNAME  smb 'DEVNAME'

BUFOFF   equ $0A               ; (COMTAB+: the place in the line)
LBUF     equ $3F               ; (COMTAB+: the command line)
LMARGN   equ $52
RMARGN   equ $53
device   equ $0761
dentry   equ $0789             ; status, node, size, name, date, time
path     equ $0640
EOL      equ $9B

        blk reloc main
start   lda #$FF
        jsr U_ARGV             ; select the native 127-byte argv contract
        lda #0
        ldx #3
s0      sta flags,x
        dex
        bpl s0
        sta col
        sta pos
        jsr getsw
        lda RMARGN             ; the screen's width for -w
        sec
        sbc LMARGN
        clc
        adc #1
        sta width
        lda #$A0               ; not hidden, no directories; -a: all
        bit opt_a
        bpl s1
        lda #0
s1      jsr U_GETATR
        jsr U_FSPEC
        jsr FFIRST
        jmi done
entry   ldy #0                 ; EOSFS v2 exact, length-tagged name
        ldx dentry+6
e1      cpx #0
        beq e1z
        lda dentry+7,y
        sta fname,y
        iny
        dex
        bne e1
e1z     lda #EOL
        sta fname,y
        bit opt_l
        bpl e1a
        jsr long
        jmp next
e1a     lda dentry
        and #$20               ; a directory: > after it
        beq e2
        lda #'/'
        sta fname,y
        iny
        lda #EOL
        sta fname,y
e2      bit opt_w
        bpl e2a
        jsr wide
        jmp next
e2a     bit opt_c
        bpl e3
        lda #'D'
        jsr PUTC
e3      lda device
        cmp CURDEV
        bne e4
        bit opt_c              ; the current device: nothing, or the colon
        bpl e8
        bmi e7
e4      and #$F0
        beq e6
        lsr @                  ; a named device: its 3 letters
        lsr @
        tax
        ldy #3
e5      lda DEVNAME,x
        jsr PUTC
        inx
        dey
        bne e5
        beq e7
e6      lda device             ; a drive: its letter
        and #$0F
        ora #'@'
        jsr PUTC
e7      lda #':'
        jsr PUTC
e8      jsr PRINTF
        dta c'%s%s',EOL,0
        dta a(path,fname)
next    jsr FNEXT
        jpl entry
done    bit opt_l              ; the last line of -w ended
        bmi d1
        bit opt_w
        bpl d1
        lda pos
        beq d1
        lda #EOL
        jsr PUTC
d1      jmp FCLOSE

* wide: the name (Y long) in the next column that has room for it
wide    sty len
        lda pos
        beq w3
        lda col                ; the next column, past a full one
        clc
        adc #13
        cmp pos
        beq w0
        bcs w1
w0      clc
        adc #13
w1      sta col
        clc
        adc len
        bcs w2
        cmp width
        bcc w2a
w2      lda #EOL               ; no room: a new line
        jsr PUTC
        lda #0
        sta col
        sta pos
        beq w3
w2a     lda pos                ; spaces up to the column
        cmp col
        bcs w3
        lda #' '
        jsr PUTC
        inc pos
        bne w2a
w3      jsr PRINTF
        dta c'%s',0
        dta a(fname)
        lda pos
        clc
        adc len
        sta pos
        rts

* long: name, size, date, time, attributes
long    jsr PRINTF
        dta c'%s ',0
        dta a(fname)
        lda dentry
        and #$20
        beq l1
        jsr PRINTF
        dta c'<DIR>',0
        jmp l5
l1      lda dentry+5           ; under 100000 ($0186A0): in bytes
        bne l1a
        jmp l4
l1a     cmp #$01
        bne l2
        lda dentry+4
        cmp #$86
        bcc l4
        bne l2
        lda dentry+3
        cmp #$A0
        bcc l4
l2      lda dentry+5           ; under 10000K ($9C4000): in K, rounded
        cmp #$9C
        bcc l3
        bne l2a
        lda dentry+4
        cmp #$40
        bcc l3
l2a     lda dentry+5           ; in M, rounded
        lsr @
        lsr @
        lsr @
        lsr @
        adc #0
        sta kb
        lda #0
        sta kb+1
        sta kb+2
        lda #'M'
        bne l3b
l3      lda dentry+5
        sta kb+1
        lda #0
        sta kb+2
        lda dentry+4
        lsr kb+1
        ror @
        lsr kb+1
        ror @
        adc #0
        sta kb
        bcc l3a
        inc kb+1
l3a     lda #'K'
l3b     sta kunit
        jsr PRINTF
        dta c'%4e%c',0
        dta a(kb,kunit)
        jmp l5
l4      jsr PRINTF
        dta c'%5e',0
        dta a(dentry+3)
l5      ldx #2                 ; the attributes H P A
l6      lda dentry
        and abits,x
        beq l7
        lda aletters,x
        bne l8
l7      lda #'-'
l8      sta attrs,x
        dex
        bpl l6
        jsr PRINTF
        dta c' %2b-%02b-%02b %02b:%02b %s',EOL,0
        dta a(dentry+38,dentry+39,dentry+40,dentry+41,dentry+42,attrs)
        rts

* getsw: the switches, /X or -x, before anything else on the line
getsw   ldy COMTAB+BUFOFF
g0      lda COMTAB+LBUF,y
        cmp #' '
        beq g1
        cmp #','
        beq g1
        cmp #'/'
        beq g2
        cmp #'-'
        beq g4
        sty COMTAB+BUFOFF
        rts
g1      iny
        bne g0
g2      iny                    ; /: letters, more / between them
        lda COMTAB+LBUF,y
        jsr isend
        beq g0
        cmp #'/'
        beq g2
        jsr setsw
        bcc g2
        lda #156
        jmp U_FAIL
g4      sty dpos               ; -: switches when all letters are
        iny
        lda COMTAB+LBUF,y
        jsr isend
        beq g7
g5      jsr swidx
        bcs g7
        iny
        lda COMTAB+LBUF,y
        jsr isend
        bne g5
        ldy dpos
g6      iny
        lda COMTAB+LBUF,y
        jsr isend
        beq g0
        jsr setsw
        jmp g6
g7      ldy dpos               ; else attributes: for U_GETATR
        sty COMTAB+BUFOFF
        rts
* isend: Z=1 when A ends a parameter
isend   cmp #' '
        beq ie1
        cmp #','
        beq ie1
        cmp #EOL
ie1     rts
* swidx: X = the switch A (any case); C=1 when it is none
swidx   cmp #'a'
        bcc sw1
        cmp #'z'+1
        bcs sw1
        and #$DF
sw1     ldx #3
sw2     cmp swlet,x
        beq sw3
        dex
        bpl sw2
        sec
        rts
sw3     clc
        rts
* setsw: the switch A on; C=1 when it is none
setsw   jsr swidx
        bcs ss1
        lda #$FF
        sta flags,x
ss1     rts

swlet   dta c'CLWA'
flags
opt_c   dta 0
opt_l   dta 0
opt_w   dta 0
opt_a   dta 0
abits   dta $02,$01,$04
aletters dta c'HPA'
attrs   dta c'---',0
kb      dta 0,0,0
kunit   dta 0
width   dta 0
col     dta 0
pos     dta 0
len     dta 0
dpos    dta 0
fname   :33 dta 0

        blk update address
        blk update symbols
