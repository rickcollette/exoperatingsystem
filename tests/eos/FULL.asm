; EOS oracle test: writing until the disk is full.
PRINTF   smb 'PRINTF'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FWRITE   smb 'FWRITE'
FTELL    smb 'FTELL'
FILELENG smb 'FILELENG'
FILE_P   smb 'FILE_P'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787

        blk reloc main
start   lda big
        ldx big+1
        jsr create
        lda trapp
        ldx trapp+1
        jsr U_SFAIL
loop    jsr write
        jmp loop
trap    sta err                ; the write that did not fit
        jsr FTELL
        jsr PRINTF
        dta c'error %b at %e',$9B,0
        dta a(err,addpos)
        jsr FCLOSE
        lda big
        ldx big+1
        jsr reopen
        jsr FILELENG
        jsr PRINTF
        dta c'length %e',$9B,0
        dta a(addpos)
        jsr FCLOSE
        lda small              ; nothing more fits
        ldx small+1
        jsr create
        lda trap2p
        ldx trap2p+1
        jsr U_SFAIL
        jsr write
        jsr U_XFAIL
        jsr PRINTF
        dta c'small written',$9B,0
        jmp done
trap2   sta err
        jsr PRINTF
        dta c'small: error %b',$9B,0
        dta a(err)
done    jsr FCLOSE
        rts

create  sta FILE_P
        stx FILE_P+1
        lda #8
        bne op
reopen  sta FILE_P
        stx FILE_P+1
        lda #4
op      sta mode
        lda #0
        sta scan
        sta attr
        jmp FOPEN
write   lda bufp
        sta addpos
        lda bufp+1
        sta addpos+1
        lda #<1000
        sta bytbuf
        lda #>1000
        sta bytbuf+1
        lda #0
        sta memreix
        jmp FWRITE

err     dta 0
trapp   dta a(trap)
trap2p  dta a(trap2)
big     dta a(n_big)
small   dta a(n_small)
n_big   dta c'BIG.DAT',$9B
n_small dta c'SMALL.DAT',$9B
bufp    dta a(buf)
buf     :1000 dta $55

        blk update address
        blk update symbols
