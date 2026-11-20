; EOS oracle test: writing files through the library.
PRINTF   smb 'PRINTF'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FPUTC    smb 'FPUTC'
FSEEK    smb 'FSEEK'
FILELENG smb 'FILELENG'
FILE_P   smb 'FILE_P'
REMOVE   smb 'REMOVE'
RENAME   smb 'RENAME'
MKDIR    smb 'MKDIR'
RMDIR    smb 'RMDIR'
CHMOD    smb 'CHMOD'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787

        blk reloc main
start   ldx #0                 ; 1: create, 300 bytes + 1 with FPUTC
        jsr spec
        lda #8
        jsr open
        jsr fill
        lda #<300
        ldx #>300
        jsr write
        lda #'X'
        jsr FPUTC
        jsr FCLOSE
        jsr PRINTF
        dta c'1 created',$9B,0

        ldx #0                 ; 2: append
        jsr spec
        lda #9
        jsr open
        lda #6
        ldx #0
        jsr wtext
        jsr FCLOSE
        jsr PRINTF
        dta c'2 appended',$9B,0

        ldx #0                 ; 3: update in place at 10
        jsr spec
        lda #$0C
        jsr open
        lda #10
        sta addpos
        lda #0
        sta addpos+1
        sta addpos+2
        jsr FSEEK
        lda #3
        ldx #0
        jsr wtext
        jsr FCLOSE
        jsr PRINTF
        dta c'3 updated',$9B,0

        ldx #0                 ; 4: read it back
        jsr spec
        lda #4
        jsr open
        jsr FILELENG
        jsr PRINTF
        dta c'4 length %e',$9B,0
        dta a(addpos)
        jsr sum
        jsr FCLOSE

        ldx #2                 ; 5: a directory and a file in it
        jsr spec
        jsr MKDIR
        ldx #4
        jsr spec
        lda #8
        jsr open
        lda #6
        ldx #0
        jsr wtext
        jsr FCLOSE
        jsr PRINTF
        dta c'5 dir',$9B,0

        ldx #6                 ; 6: rename, attributes
        jsr spec
        jsr RENAME
        ldx #8
        jsr spec
        lda #0
        sta scan
        lda #$05               ; +P +A
        sta attr
        jsr CHMOD
        jsr PRINTF
        dta c'6 renamed',$9B,0

        ldx #10                ; 7: create and delete
        jsr spec
        lda #8
        jsr open
        lda #3
        ldx #0
        jsr wtext
        jsr FCLOSE
        ldx #10
        jsr spec
        jsr REMOVE
        ldx #12                ; and an empty directory
        jsr spec
        jsr MKDIR
        ldx #12
        jsr spec
        jsr RMDIR
        jsr PRINTF
        dta c'7 deleted',$9B,0

        ldx #14                ; 8: 9000 bytes, more than one sector map
        jsr spec
        lda #8
        jsr open
        lda #36
        sta cnt
big     jsr fill
        lda #<250
        ldx #>250
        jsr write
        dec cnt
        bne big
        jsr FCLOSE
        ldx #14
        jsr spec
        lda #4
        jsr open
        jsr FILELENG
        jsr PRINTF
        dta c'8 length %e',$9B,0
        dta a(addpos)
        jsr sum
        jsr FCLOSE
        rts

* spec: FILE_P = names[X]
spec    lda names,x
        sta FILE_P
        lda names+1,x
        sta FILE_P+1
        rts
open    sta mode
        lda #0
        sta scan
        sta attr
        jmp FOPEN
* fill: buf = a pattern that changes with every call
fill    ldx #0
f1      txa
        clc
        adc seed
        sta buf,x
        inx
        bne f1
        inc seed
        rts
* write XA bytes of buf; wtext: of text
write   sta bytbuf
        stx bytbuf+1
        lda bufp
        sta addpos
        lda bufp+1
        sta addpos+1
        jmp wr1
wtext   sta bytbuf
        stx bytbuf+1
        lda textp
        sta addpos
        lda textp+1
        sta addpos+1
wr1     lda #0
        sta memreix
        jmp FWRITE
* sum: read the open file in 256-byte pieces, print a 16-bit sum and count
sum     lda #0
        sta total
        sta total+1
        sta count
        sta count+1
s1      lda bufp
        sta addpos
        lda bufp+1
        sta addpos+1
        lda #0
        sta bytbuf
        lda #1
        sta bytbuf+1
        sta memreix
        dec memreix
        jsr FREAD
        php
        ldx #0
s2      cpx bytbuf
        bne s3
        lda bytbuf+1
        beq s4
s3      clc
        lda buf,x
        adc total
        sta total
        bcc s3a
        inc total+1
s3a     inc count
        bne s3b
        inc count+1
s3b     inx
        bne s2
s4      plp
        bpl s1
        jsr PRINTF
        dta c'  sum %d of %d',$9B,0
        dta a(total,count)
        rts

seed    dta 0
cnt     dta 0
total   dta a(0)
count   dta a(0)
names   dta a(n_new,n_dir,n_in,n_ren,n_ren2,n_del,n_empty,n_big)
n_new   dta c'NEW.TXT',$9B
n_dir   dta c'DIR',$9B
n_in    dta c'DIR>IN.TXT',$9B
n_ren   dta c'NEW.TXT REN.TXT',$9B
n_ren2  dta c'REN.TXT',$9B
n_del   dta c'DEL.TXT',$9B
n_empty dta c'EMPTY',$9B
n_big   dta c'BIG.DAT',$9B
text    dta c'APPEND'
textp   dta a(text)
bufp    dta a(buf)
buf     :512 dta 0

        blk update address
        blk update symbols
