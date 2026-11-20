; EOS test (tools/side_test.py, E2): multi-sector requests to D2: through
; jsector_io. Sectors 1-4 in one request (DBYT 2048) must equal four
; single reads; sectors 200-201 written in one request (DBYT 1024, a
; pattern) must read back the same one at a time. Prints "MS READ OK" or
; "MS READ BAD", "MS WRITE OK" or "MS WRITE BAD" (or the status).
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
ptr      equ $80
pt2      equ $82

        blk reloc main
start   lda #'R'               ; sectors 1-4 at once to big
        ldx #1
        ldy #8                 ; (DBYT high: 2048)
        jsr req_b
        bmi fail
        lda #1                 ; then one at a time to one, each compared
        sta sec
rs1     lda #'R'
        ldx sec
        ldy #2
        jsr req_1
        bmi fail
        jsr cmp1
        bne rd_bad
        inc sec
        lda sec
        cmp #5
        bcc rs1
        jsr PRINTF
        dta c'MS READ OK',$9B,0
        jmp wr
rd_bad  jsr PRINTF
        dta c'MS READ BAD',$9B,0
        jmp wr
fail    sta st
        jsr PRINTF
        dta c'MS status %b',$9B,0
        dta a(st)
        rts
wr      ldx #0                 ; a pattern in big: 1024 bytes
wp1     txa
        eor #$5A
        sta big,x
        eor #$FF
        sta big+$100,x
        txa
        sta big+$200,x
        eor #$A5
        sta big+$300,x
        inx
        bne wp1
        lda #'P'               ; sectors 200-201 at once
        ldx #200
        ldy #4                 ; (1024)
        jsr req_b
        bmi fail
        lda #200
        sta sec
ws1     lda #'R'
        ldx sec
        ldy #2
        jsr req_1
        bmi fail
        jsr cmp1
        bne wr_bad
        inc sec
        lda sec
        cmp #202
        bcc ws1
        jsr PRINTF
        dta c'MS WRITE OK',$9B,0
        rts
wr_bad  jsr PRINTF
        dta c'MS WRITE BAD',$9B,0
        rts

; req_b: command A for sector X of D2:, DBYT Y*256, buffer big; req_1:
; one sector to one. N=1 an error (A the status)
req_b   pha
        lda bga
        sta DBUF
        lda bga+1
        sta DBUF+1
        jmp rq
req_1   pha
        lda ona
        sta DBUF
        lda ona+1
        sta DBUF+1
rq      pla
        sta DCMND
        stx DAUX
        sty DBYT+1
        lda #0
        sta DBYT
        sta DAUX+1
        lda #$31
        sta DDEVIC
        lda #2
        sta DUNIT
        lda #$40
        ldy DCMND
        cpy #'R'
        beq rq1
        lda #$80
rq1     sta DSTATS
        lda #7
        sta DTIMLO
        jsr jsector_io
        rts

; cmp1: one = big's part for sector sec (from the first sector of the
; request: sector 1 or 200); Z=1 equal
cmp1    lda sec
        sec
        sbc #1
        cmp #4
        bcc c0
        lda sec
        sec
        sbc #200
c0      asl @
        clc
        adc bga+1
        sta pt2+1
        lda bga
        sta pt2
        lda ona
        sta ptr
        lda ona+1
        sta ptr+1
        ldx #2
        ldy #0
c1      lda (ptr),y
        cmp (pt2),y
        bne c2
        iny
        bne c1
        inc ptr+1
        inc pt2+1
        dex
        bne c1
c2      rts

sec     dta 0
st      dta 0
bga     dta a(big)
ona     dta a(one)
big     :2048 dta 0
one     :512 dta 0

        blk update address
        blk update symbols
