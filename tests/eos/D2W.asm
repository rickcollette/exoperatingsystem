; EOS test: file management on an Atari DOS 2 disk in D2: append, rename,
; delete, lock (CHMOD), a locked file not deleted.
FOPEN    smb 'FOPEN'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
RENAME   smb 'RENAME'
REMOVE   smb 'REMOVE'
CHMOD    smb 'CHMOD'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'

mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B

        blk reloc main
start   ldx #0                 ; append to D2:SMALL.TXT
        jsr spec
        lda #9
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda texta
        sta addpos
        lda texta+1
        sta addpos+1
        lda #6
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jsr FWRITE
        jsr FCLOSE
        ldx #2                 ; rename it
        jsr spec
        lda #0
        sta scan
        jsr RENAME
        ldx #4                 ; delete BIG.DAT
        jsr spec
        jsr REMOVE
        ldx #6                 ; lock RENAMED.TXT
        jsr spec
        lda #0
        sta scan
        lda #$01
        sta attr
        jsr CHMOD
        lda trapv              ; deleting it fails
        ldx trapv+1
        jsr U_SFAIL
        ldx #6
        jsr spec
        jsr REMOVE
        jsr U_XFAIL
        jsr PRINTF
        dta c'deleted?',EOL,0
        rts
trap    sta v
        jsr PRINTF
        dta c'locked %b',EOL,0
        dta a(v)
        rts

spec    lda names,x
        sta FILE_P
        lda names+1,x
        sta FILE_P+1
        rts
trapv   dta a(trap)
texta   dta a(text)
text    dta c'more',EOL,EOL
v       dta 0,0
names   dta a(s1,s2,s3,s4)
s1      dta c'D2:SMALL.TXT',EOL
s2      dta c'D2:SMALL.TXT RENAMED.TXT',EOL
s3      dta c'D2:BIG.DAT',EOL
s4      dta c'D2:RENAMED.TXT',EOL

        blk update address
        blk update symbols
