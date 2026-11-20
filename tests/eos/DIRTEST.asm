; EOS oracle test: GETDFREE, FFIRST/FNEXT with search attributes, CHDIR
; and GETCWD.
PRINTF   smb 'PRINTF'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
FCLOSE   smb 'FCLOSE'
CHDIR    smb 'CHDIR'
GETCWD   smb 'GETCWD'
GETDFREE smb 'GETDFREE'
FILE_P   smb 'FILE_P'
U_GETPAR smb 'U_GETPAR'
COMTAB   smb 'COMTAB'

scan     equ $0779
dentry   equ $0789
path     equ $07A0
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR           ; 1: GETDFREE and searches, 2: directories
        lda COMTAB+$21
        cmp #'2'
        jeq part2
        ldx #0                 ; GETDFREE D1:
        jsr spec
        jsr GETDFREE
        ldx #16
d1      lda path,x
        sta df,x
        dex
        bpl d1
        jsr PRINTF
        dta c'f %2x %2x %4x %4x',EOL,0
        dta a(df,df+1,df+2,df+4)
        jsr PRINTF
        dta c'f %2x %2x %2x',EOL,0
        dta a(df+14,df+15,df+16)
        lda #EOL
        sta df+14
        jsr PRINTF
        dta c'f [%s]',EOL,0
        dta a(df+6)

        ldx #2                 ; *.*, everything
        lda #0
        jsr list
        ldx #2                 ; directories only
        lda #$08
        jsr list
        ldx #2                 ; no directories
        lda #$80
        jsr list
        ldx #4                 ; SUB>*.TXT
        lda #0
        jsr list
        ldx #6                 ; NONE.*
        lda #0
        jsr list
        rts

part2   jsr cwd                ; CHDIR and GETCWD
        ldx #8
        jsr spec
        jsr CHDIR
        jsr cwd
        ldx #10
        jsr spec
        jsr CHDIR
        jsr cwd
        ldx #12
        jsr spec
        jsr CHDIR
        jsr cwd
        ldx #14
        jsr spec
        jsr CHDIR
        jsr cwd
        rts

* list: FFIRST/FNEXT on spec X with scan A
list    sta scan
        sta sc
        jsr spec
        jsr PRINTF
        dta c'l %2x',EOL,0
        dta a(sc)
        jsr FFIRST
        bmi l3
l1      ldx #10
l2      lda dentry+6,x
        sta nm,x
        dex
        bpl l2
        jsr PRINTF
        dta c' %2x [%s] %6x',EOL,0
        dta a(dentry,nm,dentry+3)
        jsr FNEXT
        bpl l1
        jsr FCLOSE
l3      rts

* cwd: GETCWD on D1:, printed
cwd     ldx #0
        jsr spec
        jsr GETCWD
        ldx #0
c1      lda path,x
        sta buf,x
        beq c2
        inx
        cpx #63
        bcc c1
c2      lda #EOL
        sta buf,x
        jsr PRINTF
        dta c'c [%s]',EOL,0
        dta a(buf)
        rts

spec    lda names,x
        sta FILE_P
        lda names+1,x
        sta FILE_P+1
        rts

names   dta a(s_d1,s_all,s_sub,s_none,s_cd1,s_cd2,s_cd3,s_cd4)
s_d1    dta c'D1:',EOL
s_all   dta c'*.*',EOL
s_sub   dta c'SUB>*.TXT',EOL
s_none  dta c'NONE.*',EOL
s_cd1   dta c'SUB',EOL
s_cd2   dta c'DEEP.D',EOL
s_cd3   dta c'<',EOL
s_cd4   dta c'>',EOL
sc      dta 0,0
df      :17 dta 0
nm      :11 dta 0
        dta EOL
buf     :64 dta 0

        blk update address
        blk update symbols
