; EOS CAR: SAVE, memory to a binary file
;   SAVE [d:][path]fname[.ext] [$]address [$]address
; Writes an Atari DOS binary file: $FFFF, the first and the last address,
; then the bytes from main memory between them (both included). Nothing
; is checked, as on SDX: a missing address is 0, and a last address below
; the first goes round the top of memory (SDX wrote for over 25 s there).
; Without a file name: 156.
U_GETPAR smb 'U_GETPAR'
U_GETNUM smb 'U_GETNUM'
U_FAIL   smb 'U_FAIL'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FWRITE   smb 'FWRITE'
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
start   jsr U_GETPAR           ; the file
        jeq bad
        ldx #0
s1      lda COMTAB+$21,x
        sta fname,x
        inx
        cmp #EOL
        bne s1
        jsr getn               ; first address
        sta hdr+2
        stx hdr+3
        jsr getn               ; last address
        sta hdr+4
        stx hdr+5
        sec                    ; length = last - first + 1, round memory
        lda hdr+4              ; when last is below first
        sbc hdr+2
        sta n
        lda hdr+5
        sbc hdr+3
        sta n+1
        lda fna
        sta FILE_P
        lda fna+1
        sta FILE_P+1
        lda #8
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta fid
        lda hdra               ; the header
        sta addpos
        lda hdra+1
        sta addpos+1
        lda #6
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jsr FWRITE
        lda hdr+2              ; the bytes: n+1 of them, in two pieces when
        sta addpos             ; that is 65536
        lda hdr+3
        sta addpos+1
        clc
        lda n
        adc #1
        sta bytbuf
        lda n+1
        adc #0
        sta bytbuf+1
        bcc s2
        lda #$FF
        sta bytbuf
        sta bytbuf+1
        jsr wr
        lda #$FF
        sta addpos
        sta addpos+1
        lda #1
        sta bytbuf
        lda #0
        sta bytbuf+1
s2      jsr wr
        lda fid
        sta file_id
        jmp FCLOSE
wr      lda fid
        sta file_id
        lda #0
        sta memreix
        jmp FWRITE
bad     lda #156
        jmp U_FAIL
* getn: the next number in AX; a missing one is 0, a word that is not a
* number counts as 0 and is passed
getn    jsr U_GETNUM
        bne gn_ret
        jsr U_GETPAR
        lda #0
        tax
gn_ret  rts

fid     dta 0
n       dta a(0)
hdra    dta a(hdr)
hdr     dta a($FFFF),a(0),a(0)
fna     dta a(fname)
fname   :64 dta 0

        blk update address
        blk update symbols
