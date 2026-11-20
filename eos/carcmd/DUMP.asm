; EOS CAR: DUMP, a file in hex and ATASCII
;   DUMP [d:][path]fname[.ext] [[$]start] [[$]len] [/A]
; Eight bytes a line from the file position start (default 0), len bytes
; (default: up to the end of the file); the addresses are file positions.
; /A shows only letters, digits and punctuation, the rest as dots. Without
; a file name the input comes from CON: (the keyboard). The dump starts
; with an empty line; EOL is shown as ESC, as SDX does it.
U_GETPAR smb 'U_GETPAR'
U_GETADR smb 'U_GETADR'
U_GETNUM smb 'U_GETNUM'
U_SLASH  smb 'U_SLASH'
U_FAIL   smb 'U_FAIL'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
FSEEK    smb 'FSEEK'
PRINTF   smb 'PRINTF'
PUTC     smb 'PUTC'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B

        blk reloc main
start   lda COMTAB+$0A         ; the file name, or CON:
        sta bo
        jsr U_GETPAR
        beq d_con
        lda COMTAB+$21
        cmp #'/'               ; a switch first: no file name
        bne d2
        lda bo
        sta COMTAB+$0A
d_con   ldx #4
dc1     lda s_con,x
        sta fname,x
        dex
        bpl dc1
        jmp d3
d2      ldx #0
d2a     lda COMTAB+$21,x
        sta fname,x
        inx
        cmp #EOL
        bne d2a
d3      lda #0                 ; start, length
        sta pos
        sta pos+1
        sta pos+2
        lda #$FF
        sta len
        sta len+1
        sta len+2
        jsr U_GETNUM
        beq d4
        lda COMTAB-6
        sta pos
        lda COMTAB-5
        sta pos+1
        lda COMTAB-4
        sta pos+2
        jsr U_GETNUM
        beq d4
        lda COMTAB-6
        sta len
        lda COMTAB-5
        sta len+1
        lda COMTAB-4
        sta len+2
d4      lda opta
        ldx opta+1
        ldy #2
        jsr U_SLASH
        lda opt_a              ; /A: dl_dot 1
        and #1
        sta dl_dot
        lda fna                ; open it
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
        sta fid
        lda pos                ; to the start
        ora pos+1
        ora pos+2
        beq d5
        lda pos
        sta addpos
        lda pos+1
        sta addpos+1
        lda pos+2
        sta addpos+2
        jsr FSEEK
d5      jsr dl_start
        lda pos
        sta dl_a
        lda pos+1
        sta dl_a+1
        lda pos+2
        sta dl_a+2
lp      lda len                ; this line: up to 8 bytes
        ora len+1
        ora len+2
        jeq done
        lda len+1
        ora len+2
        bne l1
        lda len
        cmp #8
        bcc l2
l1      lda #8
l2      sta want
        lda fid
        sta file_id
        lda bufa
        sta addpos
        lda bufa+1
        sta addpos+1
        lda want
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jsr FREAD
        php
        lda bytbuf
        sta got
        plp
        bpl l3
        lda #0                 ; the end of the file
        sta len
        sta len+1
        sta len+2
        lda got
        jeq done
        bne l4
l3      sec
        lda len
        sbc got
        sta len
        bcs l4
        lda len+1
        bne l3a
        dec len+2
l3a     dec len+1
l4      jsr dl_head
        lda #0
        sta idx
l4a     ldx idx
        lda rbuf,x
        jsr dl_hex
        inc idx
        lda idx
        cmp got
        bcc l4a
        jsr dl_tail
        clc
        lda dl_a
        adc got
        sta dl_a
        jcc lp
        inc dl_a+1
        jne lp
        inc dl_a+2
        jmp lp
done    lda fid
        sta file_id
        jmp FCLOSE

fid     dta 0
bo      dta 0
want    dta 0
got     dta 0
pos     dta 0,0,0
len     dta 0,0,0
opta    dta a(opt_a)
opt_a   dta 0,c'A'
fna     dta a(fname)
bufa    dta a(rbuf)
rbuf    :8 dta 0
idx     dta 0
s_con   dta c'CON:',EOL
fname   :64 dta 0

        icl 'MEMlib.icl'

        blk update address
        blk update symbols
