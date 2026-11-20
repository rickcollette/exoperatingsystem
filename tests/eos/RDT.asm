; EOS test: a directory read raw (FOPEN mode $14, scan $20 as SC does),
; 23 bytes at a time with FREAD: each entry's status and name printed, then
; "end". Parameter: the directory (A:> ...).
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
U_GETPAR smb 'U_GETPAR'
FILE_P   smb 'FILE_P'
COMTAB   smb 'COMTAB'

mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR
        lda fna
        sta FILE_P
        lda fna+1
        sta FILE_P+1
        lda #$14
        sta mode
        lda #$20
        sta scan
        lda #0
        sta attr
        jsr FOPEN
r1      ldx #5
r2      lda parm,x
        sta addpos,x
        dex
        bpl r2
        lda #0
        sta addpos+2
        sta memreix
        jsr FREAD
        bmi r_end
        ldx #10
r3      lda ent+6,x
        sta nm,x
        dex
        bpl r3
        jsr PRINTF
        dta c'%b %s',EOL,0
        dta a(ent)
        dta a(nm)
        jmp r1
r_end   jsr FCLOSE
        jsr PRINTF
        dta c'end',EOL,0
        rts

fna     dta a(COMTAB+$21)
parm    dta a(ent),b(0),a(23),b(0)
ent     :23 dta b($AA)
nm      :11 dta b(0)
        dta b(0)

        blk update address
        blk update symbols
