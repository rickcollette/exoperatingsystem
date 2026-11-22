; EOSFS native test: allocate a sparse tail, then write into its middle gap.
FOPEN  smb 'FOPEN'
FCLOSE smb 'FCLOSE'
FREAD  smb 'FREAD'
FWRITE smb 'FWRITE'
FSEEK  smb 'FSEEK'
PRINTF smb 'PRINTF'
FILE_P smb 'FILE_P'

file_id equ $0760
mode    equ $0778
scan    equ $0779
attr    equ $077A
addpos  equ $0782
bytbuf  equ $0785
memreix equ $0787
EOL     equ $9B

        blk reloc main
start   lda #8
        jsr open
        lda #0
        ldx #4                 ; 1024
        jsr seek
        lda #'A'
        sta buf
        lda #1
        jsr io_write
        jsr FCLOSE

        lda #$0C
        jsr open
        lda #0
        ldx #2                 ; 512, inside the unallocated gap
        jsr seek
        lda #'B'
        sta buf
        lda #1
        jsr io_write
        jsr FCLOSE

        lda #4
        jsr open
        lda #$FF               ; 511
        ldx #1
        jsr seek
        lda #3
        jsr io_read
        lda #0                 ; 1024
        ldx #4
        jsr seek
        lda #1
        jsr io_read_tail
        jsr FCLOSE
        jsr PRINTF
        dta c'%2x %2x %2x %2x',EOL,0
        dta a(buf,buf+1,buf+2,buf+3)
        rts

open    sta mode
        lda a_name
        sta FILE_P
        lda a_name+1
        sta FILE_P+1
        lda #0
        sta scan
        sta attr
        jmp FOPEN
seek    sta addpos
        stx addpos+1
        lda #0
        sta addpos+2
        jmp FSEEK
io_read sta count
        lda a_buf
        ldx a_buf+1
        bne io_read0
io_read_tail sta count
        lda a_buf3
        ldx a_buf3+1
io_read0 sta addpos
        stx addpos+1
        ldx #0
        beq io
io_write sta count
        lda a_buf
        ldx a_buf+1
        sta addpos
        stx addpos+1
        ldx #1
io      lda count
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        cpx #0
        beq ior
        jmp FWRITE
ior     jmp FREAD

a_name dta a(name)
a_buf  dta a(buf)
a_buf3 dta a(buf+3)
name   dta c'gap.bin',b(EOL)
count  dta 0
buf    :4 dta 0

        blk update address
        blk update symbols
