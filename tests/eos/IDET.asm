; EOS test: sector I/O through jsector_io $070C to an IDE2.0PLUS BIOS
; (tools/ideplus_test.py). Each request in the table: its device, unit,
; command, then the status and the first 8 bytes read, in decimal.
PRINTF   smb 'PRINTF'

jsector_io equ $070C
DDEVIC   equ $0300
DUNIT    equ $0301
DCMND    equ $0302
DSTATS   equ $0303
DBUF     equ $0304
DTIMLO   equ $0306
DBYT     equ $0308
DAUX     equ $030A
EOL      equ $9B

        blk reloc main
start   lda #0
        sta idx
next    ldx idx
        lda req,x
        bne go
        rts
go      sta DDEVIC
        sta dv
        lda req+1,x
        sta DUNIT
        sta un
        lda req+2,x
        sta DCMND
        sta cm
        lda req+3,x            ; no data: DSTATS 0, else read ($40)
        ora req+4,x
        beq nodat
        lda #$40
nodat   sta DSTATS
        lda req+3,x
        sta DBYT
        lda req+4,x
        sta DBYT+1
        lda req+5,x
        sta DAUX
        lda req+6,x
        sta DAUX+1
        lda #0
        sta DAUX+2
        sta DAUX+3
        sta DAUX+4
        sta DAUX+5
        lda #7
        sta DTIMLO
        lda bufa
        sta DBUF
        lda bufa+1
        sta DBUF+1
        ldy #0                 ; a fresh buffer each time
        tya
clr     sta buf,y
        iny
        bne clr
        jsr jsector_io
        sty st
        jsr PRINTF
        dta c'%b %b %b: %b %b %b %b %b %b %b %b %b',EOL,0
        dta a(dv,un,cm,st,buf,buf+1,buf+2,buf+3,buf+4,buf+5,buf+6,buf+7)
        lda idx
        clc
        adc #7
        sta idx
        jmp next

; device, unit, command, length (word), sector (word); 0 ends
req     dta $20,1,$53,a(4),a(0)        ; the BIOS's physical device: status
        dta $20,1,$52,a(512),a(0)      ; LBA 0: the APT header
        dta $A0,1,$52,a(512),a(0)      ; the same as an XDCB
        dta $31,2,$53,a(4),a(0)        ; D2: status
        dta $31,2,$4E,a(12),a(0)       ; D2: PERCOM
        dta $31,2,$52,a(512),a(1)      ; D2: sector 1 (SDFS boot sector)
        dta $31,2,$6E,a(64),a(0)       ; D2: DISKINFO
        dta 0

idx     dta 0
dv      dta 0
un      dta 0
cm      dta 0
st      dta 0
bufa    dta a(buf)
buf     :512 dta 0

        blk update address
        blk update symbols
