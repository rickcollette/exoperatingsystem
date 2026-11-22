; EOS CAR: CHTD, files get the current time and date
;   CHTD [/Q] [+A|H|P|S] [-A|H|P|S] [d:][path]fname[.ext]
; Every matching entry changes, hidden, protected and directories too
; (as SDX 4.5 does: the attributes are taken but select nothing).
; No specification or no match: nothing, no error. Each file is opened
; to append, written with nothing and closed, which gives its entry the
; kernel's date and time; a protected file is unprotected for that, and
; its protection and archive bit are put back after it. A directory gets
; the date and time through CHMOD with attribute bit 7 (EOS's FMS: stamp
; the entry; as SDX, directories are stamped too).
; "Changing TD in NAME.EXT" for each, unless /Q.
U_GETPAR smb 'U_GETPAR'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
FOPEN    smb 'FOPEN'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
CHMOD    smb 'CHMOD'
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
dentry   equ $0789
BSLASH   equ $5C
EOL      equ $9B
NMAX     equ 100               ; files changed in one run

        blk reloc main
start   lda #0
        sta opt_q
        lda #EOL
        sta spec
p1      jsr U_GETPAR
        jeq p_end
        lda COMTAB+$21
        cmp #'+'
        beq p_att
        cmp #'-'
        beq p_att
        cmp #'/'
        beq p_sw
        ldx #0                 ; the specification
p2      lda COMTAB+$21,x
        sta spec,x
        inx
        cmp #EOL
        bne p2
        jmp p1
p_att   jmp p1                 ; attributes: taken, but all entries change
p_sw    ldx #1                 ; /Q
ps1     lda COMTAB+$21,x
        cmp #EOL
        beq p1
        cmp #'Q'
        bne ps2
        sta opt_q
ps2     inx
        bne ps1
p_end   lda spec               ; no specification: nothing (no *.*)
        cmp #EOL
        bne e1
        rts
e1      ldx #0                 ; the directory part, with its device
        ldy #0
e2      lda spec,x
        cmp #EOL
        beq e4
        inx
        cmp #':'
        beq e3
        cmp #'/'
        beq e3
        cmp #'<'
        beq e3
        cmp #BSLASH
        bne e2
e3      txa
        tay
        jmp e2
e4      sty plen
        lda spa                ; the matching files, gathered first
        sta FILE_P
        lda spa+1
        sta FILE_P+1
        lda #0                 ; every entry, directories too
        sta scan
        lda #0
        sta nf
        lda tba
        sta tp
        lda tba+1
        sta tp+1
        jsr FFIRST
        bmi g_end
g1      lda nf
        cmp #NMAX
        bcs g3
        ldy #0                 ; status, then NAME.EXT
        lda dentry
        jsr tput
        iny
        ldx #0
g2      lda dentry+6,x
        jsr tput
        iny
        inx
        cpx #11
        bcc g2
        clc
        lda tp
        adc #12
        sta tp
        bcc g2a
        inc tp+1
g2a     inc nf
g3      jsr FNEXT
        bpl g1
g_end   jsr FCLOSE
        lda nf                 ; none: nothing
        bne c0
        rts
c0      lda tba
        sta tp
        lda tba+1
        sta tp+1
c1      jsr mkname             ; full: the directory part and NAME.EXT
        lda opt_q
        bne c2
        jsr PRINTF
        dta c'Changing TD in %s',EOL,0
        dta a(fname)
c2      lda fua
        sta FILE_P
        lda fua+1
        sta FILE_P+1
        ldy #0
        jsr tget
        and #$20               ; a directory: stamped through CHMOD
        beq c2a
        lda #$80
        jsr setatr
        jmp c4
c2a
        jsr tget
        and #$05               ; protected and archived: put back after
        sta keep
        and #$01
        beq c3
        lda #$10               ; unprotected for the change
        jsr setatr
c3      lda #9                 ; append nothing
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda #0
        sta bytbuf
        sta bytbuf+1
        sta memreix
        lda tba
        sta addpos
        lda tba+1
        sta addpos+1
        jsr FWRITE
        jsr FCLOSE
        lda keep
        beq c4
        jsr setatr
c4      clc
        lda tp
        adc #12
        sta tp
        bcc c5
        inc tp+1
c5      dec nf
        jne c1
        rts

* setatr: CHMOD of full with the new attributes A
setatr  sta attr
        lda #0
        sta scan
        jmp CHMOD

* mkname: fname = NAME.EXT of the entry at tp, full = the directory part
* and fname
mkname  ldy #1
        ldx #0
mk1     jsr tget
        cmp #' '
        beq mk2
        sta fname,x
        inx
mk2     iny
        cpy #9
        bcc mk1
        jsr tget
        cmp #' '
        beq mk4
        lda #'.'
        sta fname,x
        inx
mk3     jsr tget
        cmp #' '
        beq mk4
        sta fname,x
        inx
        iny
        cpy #12
        bcc mk3
mk4     lda #EOL
        sta fname,x
        ldx #0
mk5     cpx plen
        bcs mk6
        lda spec,x
        sta full,x
        inx
        bne mk5
mk6     ldy #0
mk7     lda fname,y
        sta full,x
        inx
        iny
        cmp #EOL
        bne mk7
        rts

* tget: A = byte Y of the entry at tp; tput: A to it. Keep X and Y.
tget    lda tp
        sta tg+1
        lda tp+1
        sta tg+2
tg      lda table,y
        rts
tput    pha
        lda tp
        sta tq+1
        lda tp+1
        sta tq+2
        pla
tq      sta table,y
        rts

spa     dta a(spec)
fua     dta a(full)
tba     dta a(table)
tp      dta a(0)
opt_q   dta 0
plen    dta 0
nf      dta 0
keep    dta 0
spec    :65 dta 0
fname   :13 dta 0
full    :80 dta 0
table   :NMAX*12 dta 0

        blk update address
        blk update symbols
