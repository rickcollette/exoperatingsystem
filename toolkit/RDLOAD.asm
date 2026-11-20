; EOS Toolkit: RDLOAD, a RAM disk back from RDDUMP's file
;   RDLOAD [d:][path]file [d:]
; Without a drive, the one in $RAMDISK. The drive must answer the read
; configuration command (N) as a RAM disk does, and the file must be the
; size of the disk. Only the sectors the dump's bitmap marks as in use
; are written: the dump's sector 1 gives where its bitmap is and how
; long. At MEMLO: a sector's buffer, then the bitmap.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_FAIL   smb 'U_FAIL'
GETENV   smb 'GETENV'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FSEEK    smb 'FSEEK'
FTELL    smb 'FTELL'
FILELENG smb 'FILELENG'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

device   equ $0761
mode     equ $0778
scan     equ $0779
addpos   equ $0782             ; also FSEEK's, FTELL's and FILELENG's
bytbuf   equ $0785             ; position (3 bytes)
MEMLO    equ $02E7
LBUFF    equ $0580
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUFLO   equ $0304
DTIMLO   equ $0306
DBYTLO   equ $0308
DAUX1    equ $030A
FILLEN   equ $1A               ; (COMTAB+: the parameter's length, the
COMFNAM  equ $21               ; parameter)
EOL      equ $9B
buf      equ $80               ; zero page: the sector buffer at MEMLO,
bmp      equ $82               ; the bitmap after it, a byte of it
bp       equ $84

        blk reloc main
start   jsr U_GETPAR           ; the file
        jeq bad
        lda #0
        sta scan
        lda #4
        sta mode
        jsr FOPEN
        jsr U_GETPAR           ; the drive, else $RAMDISK
        bne s2
        lda rdptr
        ldx rdptr+1
        jsr GETENV
        jmi bad
        ldx #0
s1      lda LBUFF,x
        sta COMTAB+COMFNAM,x
        cmp #EOL
        beq s1a
        inx
        bpl s1
s1a     stx COMTAB+FILLEN
s2      jsr U_GEFINA
        lda device
        cmp #$10
        jcs bad
        sta unit
        ora #$40
        sta letter
        lda MEMLO
        sta buf
        sta bmp
        lda MEMLO+1
        sta buf+1
        clc
        adc #1
        sta bmp+1
        jsr dbuf
        lda #12                ; its configuration
        sta DBYTLO
        lda #0
        sta DBYTLO+1
        sta DAUX1+1
        lda #4
        sta DAUX1
        lda #'N'
        ldx #$40
        jsr sio
        jmi notrd
        ldy #0                 ; one track
        lda (buf),y
        cmp #1
        jne notrd
        ldy #6                 ; 256 bytes a sector
        lda (buf),y
        cmp #1
        jne notrd
        iny
        lda (buf),y
        jne notrd
        ldy #2                 ; the sectors: 64 a bank
        lda (buf),y
        sta left+1
        iny
        lda (buf),y
        sta left
        and #$3F
        jne notrd
        jsr FILELENG           ; the file: as many sectors
        lda addpos
        bne mism
        lda addpos+1
        cmp left
        bne mism
        lda addpos+2
        cmp left+1
        beq s3
mism    jsr PRINTF
        dta c'Size mismatch',EOL,0
        rts
s3      jsr rdsec              ; the dump's sector 1: the bitmap's
        ldy #$0F               ; sectors, the first one
        lda (buf),y
        sta nbm
        iny
        lda (buf),y
        sta pos+1
        iny
        lda (buf),y
        sta pos+2
        lda pos+1              ; it is at (first - 1) * 256
        bne s4
        dec pos+2
s4      dec pos+1
        lda #0
        sta pos
        jsr seek
        lda bmp                ; the whole bitmap after the buffer
        sta addpos
        lda bmp+1
        sta addpos+1
        lda #0
        sta bytbuf
        lda nbm
        sta bytbuf+1
        jsr FREAD
        lda #0                 ; from the file's start
        sta pos
        sta pos+1
        sta pos+2
        jsr seek

* each sector in use (its bit in the bitmap 0; 1 is free) gets its 256
* bytes of the file, read on from the last ones unless sectors were left
* out
l1      inc sector
        bne l2
        inc sector+1
l2      lda sector+1           ; its bitmap byte: sector / 8
        sta bp+1
        lda sector
        ldx #3
l3      lsr bp+1
        ror @
        dex
        bne l3
        clc
        adc bmp
        sta bp
        lda bp+1
        adc bmp+1
        sta bp+1
        lda sector
        and #7
        tax
        ldy #0
        lda (bp),y
        and bits,x
        bne l6                 ; free
        lda sector             ; at (sector - 1) * 256
        sec
        sbc #1
        sta pos+1
        lda sector+1
        sbc #0
        sta pos+2
        lda #0
        sta pos
        jsr FTELL
        ldx #2
l4      lda pos,x
        cmp addpos,x
        bne l5
        dex
        bpl l4
        bmi l5a
l5      jsr seek
l5a     jsr rdsec
        bmi done
        jsr dbuf
        lda #0
        sta DBYTLO
        lda #1
        sta DBYTLO+1
        lda sector
        sta DAUX1
        lda sector+1
        sta DAUX1+1
        lda #'P'
        ldx #$80
        jsr sio
        bpl l6
        jmp U_FAIL
l6      lda left               ; until the last sector
        bne l7
        dec left+1
l7      dec left
        lda left
        ora left+1
        jne l1
done    jsr FCLOSE
        jsr PRINTF
        dta c'Ramdisk restored',EOL,0
        rts
notrd   jsr PRINTF
        dta c'%c: is not a ramdisk',EOL,0
        dta a(letter)
        rts
bad     lda #156               ; bad parameter
        jmp U_FAIL

* rdsec: the file's next 256 bytes to the buffer; N=1 at its end
rdsec   lda buf
        sta addpos
        lda buf+1
        sta addpos+1
        lda #0
        sta bytbuf
        lda #1
        sta bytbuf+1
        jmp FREAD
* seek: the file to pos
seek    ldx #2
se1     lda pos,x
        sta addpos,x
        dex
        bpl se1
        jmp FSEEK
* dbuf: the transfer to and from the buffer
dbuf    lda buf
        sta DBUFLO
        lda buf+1
        sta DBUFLO+1
        rts
* sio: command A, DSTATS X, to the drive unit; A the status, N=1 an error
sio     sta DCOMND
        stx DSTATS
        lda #$31
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #7
        sta DTIMLO
        jmp COMTAB-11          ; (SIO to main memory)

rdptr   dta a(rdname)
rdname  dta c'RAMDISK',EOL
bits    dta $80,$40,$20,$10,$08,$04,$02,$01
unit    dta 0
letter  dta 0
nbm     dta 0
left    dta a(0)
sector  dta a(0)
pos     dta 0,0,0

        blk update address
        blk update symbols
