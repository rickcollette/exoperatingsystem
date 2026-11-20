* The SIDE3's SD card over SPI (included by ide.icl when SD is defined):
* sd_init and id_xfer, the rest is ide.icl's (the APT drives, the requests).
*
* $D5F3 (SD_ST): bit 7 the card present (set by writing it; it stays clear
* without a card), 5 its power, 4 the fast clock, 1 busy (read), 0 the SPI
* to the card (not the clock chip). $D5F4 (SD_D): a byte written is sent,
* the byte read is the one that came back. Cards in SPI mode: CMD0, CMD8,
* ACMD41 until ready, CMD58 (block or byte addresses: ide_ok bit 6 byte);
* CMD17 reads a 512-byte block, CMD24 writes one; CMD9 (the CSD) gives the
* size for DEVINFO.

SD_ST   equ $D5F3
SD_D    equ $D5F4
SD_ON   equ $B1                ; present, powered, fast, the card
SD_SLOW equ $A1

* sd_x: A out, A (and N, Z) the byte back; sd_ff: $FF out
sd_ff   lda #$FF
sd_x    sta SD_D
sx1     lda SD_ST
        and #$02
        bne sx1
        lda SD_D
        rts

* sd_cmd: command A ($40 + n), its argument id_lba+3 ... id_lba (sent
* high byte first), CRC Y: A = R1 (bit 7: no answer). Changes X.
sd_cmd  pha
        jsr sd_ff
        pla
        jsr sd_x
        lda id_lba+3
        jsr sd_x
        lda id_lba+2
        jsr sd_x
        lda id_lba+1
        jsr sd_x
        lda id_lba
        jsr sd_x
        tya
        jsr sd_x
        ldx #10
sc1     jsr sd_ff
        bpl sc2
        dex
        bne sc1
sc2     rts

* sd_arg: id_lba = A, 0, 0, 0 (low byte A)
sd_arg  sta id_lba
        lda #0
        sta id_lba+1
        sta id_lba+2
        sta id_lba+3
        rts

* sd_init: the card ready: C=0 (ide_ok $80, $C0 with byte addresses); C=1
* none
sd_init lda #SD_SLOW
        sta SD_ST
        lda SD_ST
        bmi si0
si_no   sec
        rts
si0     ldx #10                ; 80 clocks
si1     jsr sd_ff
        dex
        bne si1
        lda #0                 ; CMD0: SPI mode (its CRC $95)
        jsr sd_arg
        lda #$40
        ldy #$95
        jsr sd_cmd
        cmp #1
        bne si_no
        lda #$AA               ; CMD8: 2.7-3.6 V, check $AA (CRC $87)
        jsr sd_arg
        lda #1
        sta id_lba+1
        lda #$48
        ldy #$87
        jsr sd_cmd
        and #$FE               ; (idle or not: no error bits; Altirra's
        bne si_no              ; card answers $00)
        ldx #4
si2     jsr sd_ff
        dex
        bne si2
        lda RTCLOK+2           ; ACMD41 (high capacity) until ready, 3 s
        sta id_t
si3     lda #0
        jsr sd_arg
        lda #$77               ; CMD55
        ldy #$FF
        jsr sd_cmd
        lda #0
        jsr sd_arg
        lda #$40
        sta id_lba+3
        lda #$69
        ldy #$FF
        jsr sd_cmd
        cmp #0
        beq si4
        lda RTCLOK+2
        sec
        sbc id_t
        cmp #180
        bcc si3
        bcs si_no
si4     lda #0                 ; CMD58: the OCR, bit 30 block addresses
        jsr sd_arg
        lda #$7A
        ldy #$FF
        jsr sd_cmd
        cmp #0
        bne si_no
        jsr sd_ff              ; (its first byte: bit 6, CCS)
        and #$40
        beq si4a
        lda #$80               ; block addresses
        bne si4b
si4a    lda #$C0               ; byte addresses
si4b    sta ide_ok
        ldx #3
si5     jsr sd_ff
        dex
        bne si5
        lda #SD_ON
        sta SD_ST
        clc
        rts

* id_xfer: command A ('R', 'P', 'W', or $EC for the size) for id_lba with
* DBUF and DBYT: A = status
id_xfer sta id_c
        lda memreix            ; the buffer's bank
        beq ix0
        jsr k_tconv
        jmp ix0a
ix0     lda PORTB
ix0a    sta id_pb
        lda DBUFLO
        sta id_p
        lda DBUFHI
        sta id_p+1
        lda DBYTLO
        sta id_n
        lda DBYTHI
        sta id_n+1
        lda id_c
        cmp #$EC
        jeq ix_csd
        jsr id_cnt             ; (DBYT a multiple of 512: blocks one by one)
        bit ide_ok             ; byte addresses: the LBA x 512
        bvc ix1
        lda id_lba+2
        sta id_lba+3
        lda id_lba+1
        sta id_lba+2
        lda id_lba
        sta id_lba+1
        lda #0
        sta id_lba
        asl id_lba+1
        rol id_lba+2
        rol id_lba+3
ix1     lda id_c
        cmp #'R'
        jne ix_w
        lda #$51               ; CMD17
        ldy #$FF
        jsr sd_cmd
        cmp #0
        jne ix_er
        jsr sd_tok
        jcs ix_er
        jsr ix_mx
        ldy #0
        ldx #2                 ; 512 bytes
ix_r    jsr sd_ff
        pha
        lda id_n               ; (past DBYT: dropped)
        ora id_n+1
        beq ix_r2
        pla
        sta (id_p),y
        lda id_n
        bne ix_r1
        dec id_n+1
ix_r1   dec id_n
        jmp ix_r3
ix_r2   pla
ix_r3   iny
        bne ix_r
        inc id_p+1
        dex
        bne ix_r
        jsr ix_mxo
        jsr sd_ff              ; its CRC
        jsr sd_ff
        jsr ix_next
        jne ix1
        lda #1
        rts
ix_w    lda #$58               ; CMD24
        ldy #$FF
        jsr sd_cmd
        cmp #0
        jne ix_er
        jsr sd_ff
        lda #$FE               ; the data token
        jsr sd_x
        jsr ix_mx
        ldy #0
        ldx #2
ix_w0   lda id_n               ; (past DBYT: zeros)
        ora id_n+1
        beq ix_w2
        lda (id_p),y
        pha
        lda id_n
        bne ix_w1
        dec id_n+1
ix_w1   dec id_n
        pla
        jmp ix_w3
ix_w2   lda #0
ix_w3   jsr sd_x
        iny
        bne ix_w0
        inc id_p+1
        dex
        bne ix_w0
        jsr ix_mxo
        jsr sd_ff              ; a CRC (not checked)
        jsr sd_ff
        ldx #8                 ; the data response (the first byte not
ix_dr   jsr sd_ff              ; $FF): xxx00101 accepted
        cmp #$FF
        bne ix_dr1
        dex
        bne ix_dr
ix_dr1  and #$1F
        cmp #$05
        bne ix_er
        lda RTCLOK+2           ; busy (0s) while it writes
        sta id_t
ix_wb   jsr sd_ff
        bne ix_ok
        lda RTCLOK+2
        sec
        sbc id_t
        cmp #120
        bcc ix_wb
        bcs ix_to
ix_ok   jsr ix_next
        jne ix1
        lda #1
        rts
ix_to   lda #138
        rts
ix_er   lda #144
        rts
* the size: CMD9's CSD (16 bytes) to DBUF; version 2: C_SIZE (bits 69-48)
* + 1 times 1024 sectors, to bytes 120-123 (as IDENTIFY's words 60-61)
ix_csd  lda #0
        jsr sd_arg
        lda #$49
        ldy #$FF
        jsr sd_cmd
        cmp #0
        bne ix_er
        jsr sd_tok
        bcs ix_er
        ldy #0
ix_c1   jsr sd_ff
        sta (id_p),y
        iny
        cpy #16
        bcc ix_c1
        jsr sd_ff
        jsr sd_ff
        ldy #9                 ; C_SIZE + 1
        lda (id_p),y
        clc
        adc #1
        sta id_lba
        dey
        lda (id_p),y
        adc #0
        sta id_lba+1
        dey
        lda (id_p),y
        and #$3F
        adc #0
        sta id_lba+2
        lda #0
        sta id_lba+3
        ldx #10                ; x 1024
ix_c2   asl id_lba
        rol id_lba+1
        rol id_lba+2
        rol id_lba+3
        dex
        bne ix_c2
        ldy #120
        ldx #0
ix_c3   lda id_lba,x
        sta (id_p),y
        iny
        inx
        cpx #4
        bcc ix_c3
        lda #1
        rts

* ix_next: one block done: id_k - 1 (Z=1 none left), the address the
* next block's (+1, or +512 with byte addresses)
ix_next bit ide_ok
        bvs nx_b
        inc id_lba             ; +1 block
        bne nx2
        inc id_lba+1
        bne nx2
        inc id_lba+2
        bne nx2
        inc id_lba+3
        jmp nx2
nx_b    clc                    ; +512 bytes
        lda id_lba+1
        adc #2
        sta id_lba+1
        bcc nx2
        inc id_lba+2
        bne nx2
        inc id_lba+3
nx2     dec id_k
        rts

* sd_tok: until the data token $FE (C=0), another byte than $FF or about
* 1 s (C=1)
sd_tok  lda RTCLOK+2
        sta id_t
st1     jsr sd_ff
        cmp #$FE
        beq st2
        cmp #$FF
        bne st3
        lda RTCLOK+2
        sec
        sbc id_t
        cmp #60
        bcc st1
st3     sec
        rts
st2     clc
        rts

* ix_mx, ix_mxo: the buffer's PORTB in and out
ix_mx   lda PORTB
        sta id_old
        lda id_pb
        sta PORTB
        rts
ix_mxo  lda id_old
        sta PORTB
        rts
