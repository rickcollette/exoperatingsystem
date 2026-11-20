; EOS Toolkit: CRC32, the CRC-32 of files
;   CRC32 [/H] file ...
; For each file: the CRC-32 (as zlib and "cksum -o 3" compute it), its size
; and its name, in decimal or with /H in hex. A parameter that starts with
; a / ends the list. No file: the usage line.
U_GETPAR smb 'U_GETPAR'
U_SLASH  smb 'U_SLASH'
U_EXPAND smb 'U_EXPAND'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

COMFNAM  equ $21               ; (COMTAB+: the parameter)
file_id  equ $0760
name     equ $0762
mode     equ $0778
scan     equ $0779
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
dentry   equ $0789
EOL      equ $9B
BUFSZ    equ 2048              ; bytes read at a time
ptr      equ $80               ; (zero page: the byte in the buffer)

        blk reloc main
start   jsr mktab
        lda a_opt
        ldx a_opt+1
        ldy #2
        jsr U_SLASH
        jsr nextpar
        bne file
        jsr PRINTF
        dta EOL,c'Use: crc32 [/H] filelist',EOL,0
        rts

file    lda #4
        sta mode
        lda #0
        sta scan
        jsr FOPEN
        ldx #2                 ; the size and the name from its entry
f1      lda dentry+3,x
        sta size,x
        dex
        bpl f1
        ldx #10
f2      lda dentry+6,x
        sta name,x
        dex
        bpl f2
        lda a_nbuf
        ldx a_nbuf+1
        ldy #0
        jsr U_EXPAND
        ldx #3
        lda #$FF
f3      sta crc,x
        dex
        bpl f3
rd      lda a_buf              ; a buffer full at a time, up to nothing more
        sta addpos
        sta ptr
        lda a_buf+1
        sta addpos+1
        sta ptr+1
        lda #<BUFSZ
        sta bytbuf
        lda #>BUFSZ
        sta bytbuf+1
        lda #0
        sta memreix
        jsr FREAD
        lda bytbuf
        sta cnt
        lda bytbuf+1
        sta cnt+1
        ora cnt
        beq done
        ldy #0
rd1     lda (ptr),y            ; crc = crc >> 8 ^ table[crc ^ byte]
        eor crc
        tax
        lda crc+1
        eor tab0,x
        sta crc
        lda crc+2
        eor tab1,x
        sta crc+1
        lda crc+3
        eor tab2,x
        sta crc+2
        lda tab3,x
        sta crc+3
        iny
        bne rd2
        inc ptr+1
rd2     lda cnt
        bne rd3
        dec cnt+1
rd3     dec cnt
        lda cnt
        ora cnt+1
        bne rd1
        beq rd
done    jsr FCLOSE
        ldx #3
d1      lda crc,x
        eor #$FF
        sta crc,x
        dex
        bpl d1
        bit opt_h
        bpl d2
        jsr PRINTF
        dta c'$%08x',0
        dta a(crc)
        jmp d3
d2      jsr PRINTF
        dta c'%l',0
        dta a(crc)
d3      jsr PRINTF
        dta c' %e %s',EOL,0
        dta a(size,nbuf)
        jsr nextpar
        jne file
        rts

* nextpar: the next file name to COMFNAM; Z=1 when there is none, or it
* starts with a /
nextpar jsr U_GETPAR
        beq np_ret
        lda COMTAB+COMFNAM
        cmp #'/'
np_ret  rts

* mktab: the table of the reflected polynomial $EDB88320, one byte of each
* entry in each of tab0 (lowest) to tab3
mktab   ldx #0
mt1     lda #0
        sta crc+1
        sta crc+2
        sta crc+3
        stx crc
        ldy #8
mt2     lsr crc+3
        ror crc+2
        ror crc+1
        ror crc
        bcc mt3
        lda crc+3
        eor #$ED
        sta crc+3
        lda crc+2
        eor #$B8
        sta crc+2
        lda crc+1
        eor #$83
        sta crc+1
        lda crc
        eor #$20
        sta crc
mt3     dey
        bne mt2
        lda crc
        sta tab0,x
        lda crc+1
        sta tab1,x
        lda crc+2
        sta tab2,x
        lda crc+3
        sta tab3,x
        inx
        bne mt1
        rts

a_opt   dta a(opt_h)
a_nbuf  dta a(nbuf)
a_buf   dta a(buf)
opt_h   dta 0,c'H'
crc     dta 0,0,0,0
size    dta 0,0,0,0
cnt     dta 0,0
nbuf    :13 dta 0
tab0    equ *                  ; the tables and the buffer: the free memory
tab1    equ *+256              ; after the program
tab2    equ *+512
tab3    equ *+768
buf     equ *+1024

        blk update address
        blk update symbols
