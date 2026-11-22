; EOS Toolkit: CAT, files one after another to standard output
;   CAT [-n] [filename ...]
; Each file is copied as it is; a name with the wildcards * and ? stands
; for the files that match it, in directory order. Without a name
; standard input is read. -n numbers the lines, from 1 over all files.
U_GETPAR smb 'U_GETPAR'
U_ARGV   smb 'U_ARGV'
TOLOWER  smb 'TOLOWER'
FOPEN    smb 'FOPEN'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
U_FAIL   smb 'U_FAIL'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

        icl 'UNIXH.icl'
BSLASH   equ $5C
ptr      equ $80

        blk reloc main
start   jsr unargs
        bcs usage
        lda #$FF
        sta bol
        lda unfiles
        bne c1
        lda COMTAB+7           ; no name: standard input
        sta file_id
        jmp copy
c1      ldx #0
c2      stx cpos
c2a     lda unames,x           ; wildcards?
        cmp #'*'
        beq wild
        cmp #'?'
        beq wild
        inx
        cmp #EOL
        bne c2a
        ldx cpos
        jsr unopen
        jsr copy
        jsr FCLOSE
c_next  ldx cpos               ; the next name
c3      lda unames,x
        inx
        cmp #EOL
        bne c3
        cpx unlen
        bcc c2
        rts
usage   jsr PRINTF
        dta c'Use: cat [-n] [filename ...]',EOL,0
        rts

* wild: the files matching the name at cpos listed (their directory as
* typed and NAME.EXT) from unbot, then each copied
wild    ldx cpos               ; plen: the directory part's length
        ldy #0
        sty plen
w1      lda unames,x
        cmp #EOL
        beq w2
        iny
        inx
        cmp #':'
        beq w1s
        cmp #'/'
        beq w1s
        bne w1
w1s     sty plen
        jmp w1
w2      jsr unmem
        lda unbot
        sta ptr
        lda unbot+1
        sta ptr+1
        lda #0
        sta nfound
        sta nfound+1
        ldx cpos
        jsr unptr
        lda #$80               ; files only
        sta scan
        jsr FFIRST
        bmi w6
w3      clc                    ; room for one more?
        lda ptr
        adc #80
        tax
        lda ptr+1
        adc #0
        cmp untop+1
        bcc w3a
        bne w3m
        cpx untop
        bcc w3a
w3m     lda #158
        jmp U_FAIL
w3a     ldx cpos               ; the directory part
        ldy #0
w3b     cpy plen
        bcs w3c
        lda unames,x
        sta (ptr),y
        inx
        iny
        bne w3b
w3c     lda dentry+6           ; EOSFS v2 length-tagged exact name
        sta namelen
        ldx #0
w4      cpx namelen
        bcs w5
        lda dentry+7,x
        sta (ptr),y
        iny
        inx
        bne w4
w5      lda #EOL
        sta (ptr),y
        iny
        tya
        clc
        adc ptr
        sta ptr
        bcc w5a
        inc ptr+1
w5a     inc nfound
        bne w5b
        inc nfound+1
w5b     jsr FNEXT
        bpl w3
w6      jsr FCLOSE
        lda nfound
        ora nfound+1
        bne w7
        ldx cpos               ; none: opened as it is, for the error
        jsr unopen
        jsr copy
        jsr FCLOSE
        jmp c_next
w7      lda unbot
        sta ptr
        lda unbot+1
        sta ptr+1
w8      lda ptr
        sta FILE_P
        lda ptr+1
        sta FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        jsr copy
        jsr FCLOSE
        ldy #0
w9      lda (ptr),y
        iny
        cmp #EOL
        bne w9
        tya
        clc
        adc ptr
        sta ptr
        bcc w9a
        inc ptr+1
w9a     lda nfound
        bne w9b
        dec nfound+1
w9b     dec nfound
        lda nfound
        ora nfound+1
        bne w8
        jmp c_next

* copy: the file file_id to standard output, -n numbering the lines
copy    jsr FGETC
        bmi cp_ret
        bit o_n
        bpl cp1
        bit bol
        bpl cp1
        inc lineno
        bne cp0
        inc lineno+1
        bne cp0
        inc lineno+2
cp0     jsr PRINTF
        dta c'%5l ',0
        dta a(lineno)
cp1     sta bol                ; (0 unless an EOL: bit 7 set)
        jsr PUTC
        cmp #EOL
        beq copy
        lda #0
        sta bol
        beq copy
cp_ret  rts

unsw
o_n     dta b(0),c'n'
UNSWN   equ *-unsw
unval   dta 0
cpos    dta 0
plen    dta 0
namelen dta 0
bol     dta 0
nfound  dta a(0)
lineno  dta 0,0,0,0

        icl 'UNIX.icl'
unend   equ *

        blk update address
        blk update symbols
