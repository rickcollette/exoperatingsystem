; EOS Toolkit: RDDUMP, a RAM disk's sectors to a file
;   RDDUMP d: [d:][path]file
; The drive must answer the read configuration command (N) as a RAM disk
; does: one track, sectors of 256 bytes, a multiple of 64 of them. Its
; sectors go to the file in order, 64 at a time (16K at MEMLO); RDLOAD
; puts them back.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_FAIL   smb 'U_FAIL'
FOPEN    smb 'FOPEN'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

device   equ $0761
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
MEMLO    equ $02E7
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUFLO   equ $0304
DTIMLO   equ $0306
DBYTLO   equ $0308
DAUX1    equ $030A
EOL      equ $9B
buf      equ $80               ; zero page: the buffer at MEMLO

        blk reloc main
start   jsr U_GETPAR
        jeq bad
        jsr U_GEFINA
        lda device             ; a drive, D1: to D15:
        cmp #$10
        jcs bad
        sta unit
        ora #$40
        sta letter
        lda MEMLO
        sta buf
        sta DBUFLO
        lda MEMLO+1
        sta buf+1
        sta DBUFLO+1
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
        sta total+1
        iny
        lda (buf),y
        sta left
        sta total
        and #$3F
        jne notrd
        jsr U_GETPAR           ; the file
        jeq bad
        lda #0
        sta scan
        sta attr
        lda #8
        sta mode
        jsr FOPEN
d1      lda left               ; 64 sectors a round
        ora left+1
        beq d4
        lda MEMLO
        sta DBUFLO
        lda MEMLO+1
        sta DBUFLO+1
        lda #64
        sta n
d2      lda #0
        sta DBYTLO
        lda #1
        sta DBYTLO+1
        lda sector
        sta DAUX1
        lda sector+1
        sta DAUX1+1
        lda #'R'
        ldx #$40
        jsr sio
        jmi fail
        inc DBUFLO+1
        inc sector
        bne d3
        inc sector+1
d3      lda left
        bne d3a
        dec left+1
d3a     dec left
        dec n
        bne d2
        lda MEMLO              ; then to the file
        sta addpos
        lda MEMLO+1
        sta addpos+1
        lda #<$4000
        sta bytbuf
        lda #>$4000
        sta bytbuf+1
        jsr FWRITE
        jmp d1
d4      jsr FCLOSE
        jsr PRINTF
        dta c'%d sectors dumped',EOL,0
        dta a(total)
        rts
notrd   jsr PRINTF
        dta c'%c: is not a ramdisk',EOL,0
        dta a(letter)
bad     lda #156               ; bad parameter
fail    jmp U_FAIL

* sio: command A, DSTATS X, to the drive unit; A the status, N=1 an error
sio     sta DCOMND
        stx DSTATS
        lda #$31
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #7
        sta DTIMLO
        jmp COMTAB-11             ; (SIO to main memory)

unit    dta 0
letter  dta 0
n       dta 0
left    dta a(0)
total   dta a(0)
sector  dta a(1)

        blk update address
        blk update symbols
