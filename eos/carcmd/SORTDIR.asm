; EOS CAR: SORTDIR, a directory's entries put in order
;   SORTDIR d:[path] [/N|T|S|D|X]
; /N by name (then type, the default), /T by type (then name), /S by size
; (then name and type), /D by date and time (then name and type); /X the
; other way round. Directories come first. The directory is read and
; written in place (direct directory access); entries in use come first,
; in order, the free ones after them. The directory must end with : > or
; backslash, else the options are shown. SpartaDOS (SDFS) disks only.
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FSEEK    smb 'FSEEK'
GETDFREE smb 'GETDFREE'
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
dentry   equ $0789
path     equ $07A0
MEMTOP   equ $02E5
MEMLO    equ $02E7
EOL      equ $9B
BSLASH   equ $5C
ST_USED  equ $08
ST_DEL   equ $10

ptr      equ $80
pa       equ $82               ; the entries compared
pb       equ $84
pk       equ $86               ; the pointer being placed
pp       equ $88               ; pointer array work pointer

        blk reloc main
start   lda #1                 ; by name unless /T, /S or /D
        sta crit
        lda #0
        sta desc
        sta plen
p1      jsr U_GETPAR
        beq p_end
        lda COMTAB+$21
        cmp #'/'
        bne p_dir
        ldx #1
p2      lda COMTAB+$21,x
        cmp #EOL
        beq p1
        cmp #'X'
        bne p3
        sta desc
        beq p5                 ; (Z=1 from the compare)
p3      ldy #3
p4      cmp critch,y
        beq p4a
        dey
        bpl p4
        lda #156
        jmp U_FAIL
p4a     iny
        cpy #1                 ; (/N: the default, it changes nothing)
        beq p5
        sty crit
p5      inx
        bne p2
p_dir   ldx #0                 ; the directory
p6      lda COMTAB+$21,x
        sta spec,x
        inx
        cmp #EOL
        bne p6
        dex
        stx plen
        jmp p1
p_end   ldx plen               ; a directory: it ends with : > or backslash
        beq usage
        lda spec-1,x
        cmp #':'
        jeq g1
        cmp #'>'
        jeq g1
        cmp #'<'
        jeq g1
        cmp #BSLASH
        jeq g1
usage   jsr PRINTF             ; (a blank line first: SDX's screen has
        dta EOL                ; one more line here)
        dta c'Use: SORTDIR d:[path] [/NTSDX]',EOL
        dta c'/N - sort by file name (default)',EOL
        dta c'/T - sort by file type',EOL
        dta c'/S - sort by file size',EOL
        dta c'/D - sort by creation date',EOL
        dta c'/X - reverse sort',EOL,0
        rts
g1      lda #EOL
        sta spec,x
        lda a_spec
        sta FILE_P
        lda a_spec+1
        sta FILE_P+1
        jsr GETDFREE           ; SpartaDOS disks only
        lda path
        and #$F0
        cmp #$20
        beq g2
        lda #148
        jmp U_FAIL
g2      lda a_spec
        sta FILE_P
        lda a_spec+1
        sta FILE_P+1
        lda #$1C               ; the directory itself, to read and write
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        sec                    ; its entries: the length less the header
        lda dentry+3
        sbc #23
        sta dlen
        lda dentry+4
        sbc #0
        sta dlen+1
        lda dentry+5
        sbc #0
        bne nomem
        jsr memory
        clc                    ; room for them and a pointer to each
        lda top
        adc dlen
        sta parr
        lda top+1
        adc dlen+1
        sta parr+1
        bcs nomem
        lda dlen               ; (23 bytes each: 2 / 23 of it is enough,
        sta n                  ; an eighth is plenty)
        lda dlen+1
        lsr @
        ror n
        lsr @
        ror n
        lsr @
        ror n
        sta n+1
        clc
        lda parr
        adc n
        tax
        lda parr+1
        adc n+1
        bcs nomem
        cmp mtop+1
        bcc g3
        bne nomem
        cpx mtop
        bcc g3
nomem   lda #158
        jmp U_FAIL
g3      lda top
        sta addpos
        lda top+1
        sta addpos+1
        lda dlen
        sta bytbuf
        lda dlen+1
        sta bytbuf+1
        lda #0
        sta memreix
        ora dlen
        ora dlen+1
        jeq close
        jsr FREAD
* pointers to the entries in use
        lda #0
        sta n
        sta n+1
        lda top
        sta ptr
        lda top+1
        sta ptr+1
        lda parr
        sta pp
        lda parr+1
        sta pp+1
        lda dlen
        sta left
        lda dlen+1
        sta left+1
c1      jsr isused
        bcc c2
        ldy #0
        lda ptr
        sta (pp),y
        iny
        lda ptr+1
        sta (pp),y
        jsr pp2
        inc n
        bne c2
        inc n+1
c2      jsr next
        bcs c1
* insertion sort of the pointers (stable)
        lda #1
        sta i
        lda #0
        sta i+1
s1      lda i
        cmp n
        lda i+1
        sbc n+1
        jcs s_done
        lda i                  ; pk = p[i]
        ldx i+1
        jsr pidx
        ldy #0
        lda (pp),y
        sta pk
        iny
        lda (pp),y
        sta pk+1
        lda i                  ; j = i
        sta j
        lda i+1
        sta j+1
s2      lda j
        ora j+1
        beq s3
        lda j                  ; p[j-1] after pk? then it moves up
        sec
        sbc #1
        pha
        lda j+1
        sbc #0
        tax
        pla
        jsr pidx
        ldy #0
        lda (pp),y
        sta pa
        iny
        lda (pp),y
        sta pa+1
        jsr after
        bcc s3
        ldy #2                 ; p[j] = p[j-1]
        lda pa
        sta (pp),y
        iny
        lda pa+1
        sta (pp),y
        lda j
        bne s2a
        dec j+1
s2a     dec j
        jmp s2
s3      lda j                  ; p[j] = pk
        ldx j+1
        jsr pidx
        ldy #0
        lda pk
        sta (pp),y
        iny
        lda pk+1
        sta (pp),y
        inc i
        jne s1
        inc i+1
        jmp s1
* written back: the sorted entries, then the others as they were
s_done  lda #23
        sta addpos
        lda #0
        sta addpos+1
        sta addpos+2
        jsr FSEEK
        lda parr
        sta pp
        lda parr+1
        sta pp+1
        lda n
        sta i
        lda n+1
        sta i+1
w1      lda i
        ora i+1
        beq w2
        ldy #0
        lda (pp),y
        sta ptr
        iny
        lda (pp),y
        sta ptr+1
        jsr wr23
        jsr pp2
        lda i
        bne w1a
        dec i+1
w1a     dec i
        jmp w1
w2      lda top
        sta ptr
        lda top+1
        sta ptr+1
        lda dlen
        sta left
        lda dlen+1
        sta left+1
w3      jsr isused
        bcs w4
        jsr wr23
w4      jsr next
        bcs w3
close   jsr FCLOSE
        jsr PRINTF
        dta c'Sort completed!',EOL,0
        rts

* isused: C=1 when the entry at ptr is in use
isused  ldy #0
        lda (ptr),y
        and #ST_USED|ST_DEL
        cmp #ST_USED
        beq iu1
        clc
        rts
iu1     sec
        rts
* next: ptr to the next entry; C=0 after the last
next    clc
        lda ptr
        adc #23
        sta ptr
        bcc nx1
        inc ptr+1
nx1     sec
        lda left
        sbc #23
        sta left
        lda left+1
        sbc #0
        sta left+1
        bcc nx_end
        lda left
        cmp #23
        lda left+1
        sbc #0
        rts                    ; C=1 while 23 bytes or more are left
nx_end  clc
        rts
pp2     clc
        lda pp
        adc #2
        sta pp
        bcc pp2a
        inc pp+1
pp2a    rts
* pidx: pp = &p[AX]
pidx    stx pp+1
        asl @
        rol pp+1
        clc
        adc parr
        sta pp
        lda pp+1
        adc parr+1
        sta pp+1
        rts
* wr23: the entry at ptr to the directory
wr23    lda ptr
        sta addpos
        lda ptr+1
        sta addpos+1
        lda #23
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jmp FWRITE

* after: C=1 when the entry at pa goes after the one at pk; directories
* come first either way
after   ldy #0
        lda (pa),y
        eor (pk),y
        and #$20
        beq af_s
        lda (pk),y             ; one is a directory: pa after pk when pk is
        and #$20               ; the directory
        cmp #$20
        rts
af_s    lda desc
        beq af0
        lda pa                 ; descending: the other way round
        sta pb
        lda pa+1
        sta pb+1
        lda pk
        sta pa
        lda pk+1
        sta pa+1
        jsr cmpab
        php
        lda pa                 ; (pa back)
        pha
        lda pb
        sta pa
        lda pb+1
        sta pa+1
        pla
        sta pk
        plp
        rts
af0     lda pk
        sta pb
        lda pk+1
        sta pb+1
* cmpab: C=1 when the entry at pa is greater than the one at pb
cmpab   ldx crit
        lda keyst-1,x
        tax
ca1     lda keys,x
        bmi ca_eq
        and #$3F
        tay
        lda (pa),y
        sta ka
        lda (pb),y
        sta kb
        lda keys,x
        and #$40               ; a year: 80-99 before 00-79
        beq ca2
        lda ka
        jsr year
        sta ka
        lda kb
        jsr year
        sta kb
ca2     lda kb
        cmp ka
        bcc ca_gt              ; kb < ka
        bne ca_lt
        inx
        bne ca1
ca_eq
ca_lt   clc
        rts
ca_gt   sec
        rts
year    cmp #80
        bcs yr1
        adc #100
yr1     rts

* memory: the entries go after the program (or MEMLO), up to MEMTOP
memory  lda a_pend
        sta top
        lda a_pend+1
        sta top+1
        lda MEMLO+1
        cmp top+1
        bcc me1
        bne me0
        lda MEMLO
        cmp top
        bcc me1
me0     lda MEMLO
        sta top
        lda MEMLO+1
        sta top+1
me1     lda MEMTOP
        sta mtop
        lda MEMTOP+1
        sta mtop+1
        rts

* the order of the bytes compared for each criterion ($40: a year)
critch  dta c'NTSD'
keyst   dta b(0,12,24,39)          ; where each starts in keys
keys
kn      dta b(6,7,8,9,10,11,12,13,14,15,16,$FF)
kt      dta b(14,15,16,6,7,8,9,10,11,12,13,$FF)
ks      dta b(5,4,3,6,7,8,9,10,11,12,13,14,15,16,$FF)
kd      dta b($40+19,18,17,20,21,22,6,7,8,9,10,11,12,13,14,15,16,$FF)

a_spec  dta a(spec)
a_pend  dta a(pend)
crit    dta 0
desc    dta 0
plen    dta 0
ka      dta 0
kb      dta 0
top     dta a(0)
mtop    dta a(0)
parr    dta a(0)
dlen    dta a(0)
left    dta a(0)
n       dta a(0)
i       dta a(0)
j       dta a(0)
spec    :68 dta 0
pend    equ *

        blk update address
        blk update symbols
