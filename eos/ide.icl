* CompactFlash on SIDE, SIDE2 and MyIDE II (included in dev.asm when IDE is
* defined: eos/equ.icl). These cartridges have no PBI BIOS: EOS drives the
* card itself, through the ATA registers at IDE_D (8-bit transfers: the card
* is told so, SET FEATURES $01, after every release from reset).
*
* ide_init (the boot bank, at every start and reset): the card out of reset,
* 8-bit mode, its LBA 0 read: an APT table (docs/HARDWARE_TEST.md, the APT
* command) whose mapping slots give the drives. Up to IDE_N drives on
* partitions of 512-byte sectors are kept (ide_u, the start LBA's low 24
* bits, the size). Nothing is mapped without a card or a table.
*
* ide_drv (first in hs_drv, so in sio_vector from the start): C=1 not ours
*   $31 a mapped unit: R, P, W (DBYT bytes of the 512-byte sector; the rest
*       of a sector read is dropped, of one written zeros; DBYT a multiple
*       of 512: that many sectors from DAUX on, E2), S, N (a PERCOM
*       block: one track of the partition's sectors, 512 bytes), O, ! and "
*       (taken; a format's bad sector list all $FF), ? 139
*   $A0 (an XDCB) unit 1: R, P, W of a 512-byte LBA (DAUX..DAUX+3), as the
*       PBI BIOS's physical device; $20 unit 1 command $6E (DEVINFO): 512
*       bytes, the sector count at 8-11 (from IDENTIFY). APT uses both.
* A buffer in another bank (memreix) is reached with its PORTB value.
* Out: C=0, A = Y = DSTATS = status (1, 138 no answer, 139, 144 error).

IDE_N   equ 4
ATA_DAT equ IDE_D
ATA_FEA equ IDE_D+1
ATA_CNT equ IDE_D+2
ATA_L0  equ IDE_D+3
ATA_L1  equ IDE_D+4
ATA_L2  equ IDE_D+5
ATA_DH  equ IDE_D+6
ATA_CMD equ IDE_D+7
ATA_ST  equ IDE_D+7

id_p    equ $80                ; page 0, the caller's bytes kept meanwhile:
id_n    equ $82                ; the buffer, the bytes left in it,
id_t    equ $84
id_pb   equ $85                ; PORTB for the buffer and the caller's,
id_old  equ $86
id_x    equ $87                ; the map entry,
id_c    equ $88                ; the command,
id_lba  equ $89                ; the LBA (4),
id_k    equ $8D                ; the sectors still to go
ID_ZN   equ 14

* the caller's page 0 bytes to the stack and back (X changes)
.macro ID_SAVE
        ldx #ID_ZN-1
@       lda id_p,x
        pha
        dex
        bpl @-
.endm
.macro ID_REST
        ldx #0
@       pla
        sta id_p,x
        inx
        cpx #ID_ZN
        bcc @-
.endm

* ---- start ---------------------------------------------------------------
ide_init lda #0
        sta ide_ok
        ldx #IDE_N-1
ii0     sta ide_u,x
        dex
        bpl ii0
.ifdef SD
        ID_SAVE
        jsr sd_init            ; SIDE3: the SD card (sd.icl), ide_ok set
        jcs ii_x
.else
.ifdef MYIDE2
        lda #$02               ; MyIDE II: the card powered, then out of
        sta IDE_D+$0E          ; reset (a rising edge on bit 0)
        lda #$03
        sta IDE_D+$0E
.else
        lda #$01               ; SIDE: out of reset, the interface on
        sta IDE_D+$08
.endif
        ID_SAVE
        jsr id_bsy
        jcs ii_x
        lda #$01               ; 8-bit transfers
        sta ATA_FEA
        lda #$E0
        sta ATA_DH
        lda #$EF
        sta ATA_CMD
        jsr id_bsy
        jcs ii_x
        lda #$FF
        sta ide_ok
.endif
        lda #0                 ; LBA 0 to fs_sbuf
        sta id_lba
        sta id_lba+1
        sta id_lba+2
        sta id_lba+3
        lda #<fs_sbuf
        sta DBUFLO
        lda #>fs_sbuf
        sta DBUFHI
        lda #0
        sta DBYTLO
        lda #2
        sta DBYTHI
        lda #0
        sta memreix
        lda #'R'
        jsr id_xfer
        cmp #1
        jne ii_x
        lda fs_sbuf+1          ; an APT table at its start
        cmp #'A'
        bne ii_x
        lda fs_sbuf+2
        cmp #'P'
        bne ii_x
        lda fs_sbuf+3
        cmp #'T'
        bne ii_x
        lda fs_sbuf            ; revision 0, not in the even bytes only
        and #$E0
        bne ii_x
        lda #<(fs_sbuf+16)     ; the mapping slots: D1: at 16, D2: at 32 ...
        sta id_p
        lda #>(fs_sbuf+16)
        sta id_p+1
        ldx #0                 ; (the next free map entry)
        lda #1
        sta id_t
ii2     ldy #0
        lda (id_p),y
        and #3
        cmp #3                 ; mapped, 512-byte sectors
        bne ii3
        ldy #5                 ; below 2^24 (an 8 GB card)
        lda (id_p),y
        bne ii3
        ldy #8                 ; at most 65535 sectors (EOS's sector numbers)
        lda (id_p),y
        iny
        ora (id_p),y
        bne ii3
        lda id_t
        sta ide_u,x
        ldy #2
        lda (id_p),y
        sta ide_l0,x
        iny
        lda (id_p),y
        sta ide_l1,x
        iny
        lda (id_p),y
        sta ide_l2,x
        ldy #6
        lda (id_p),y
        sta ide_sl,x
        iny
        lda (id_p),y
        sta ide_sh,x
        inx
        cpx #IDE_N
        bcs ii_x
ii3     clc
        lda id_p
        adc #16
        sta id_p
        bcc ii4
        inc id_p+1
ii4     inc id_t
        lda id_t
        cmp #16
        bcc ii2
ii_x    ID_REST
        rts

* ---- requests --------------------------------------------------------------
ide_drv bit ide_ok
        bpl id_no
        lda DDEVIC
        cmp #$31
        beq id_d
        cmp #$A0
        beq id_phy
        cmp #$20
        bne id_no
        lda DUNIT              ; DEVINFO
        cmp #1
        bne id_no
        lda DCOMND
        cmp #$6E
        bne id_no
        ID_SAVE
        jsr id_dlba
        lda #$EC               ; IDENTIFY, its sector count to 8-11
        jsr id_xfer
        cmp #1
        jne id_st
        jsr id_info
        lda #1
        jne id_st
id_phy  lda DUNIT              ; the physical disk, an XDCB
        cmp #1
        bne id_no
        lda DCOMND
        cmp #'R'
        beq id_p1
        cmp #'P'
        beq id_p1
        cmp #'W'
        bne id_no
id_p1   ID_SAVE
        jsr id_dlba
        lda DCOMND
        jsr id_xfer
        jmp id_st
id_no   sec
        rts
id_d    ldx #IDE_N-1           ; a mapped unit?
id_d1   lda ide_u,x
        cmp DUNIT
        beq id_d2
        dex
        bpl id_d1
        bmi id_no
id_d2   ID_SAVE
        ldx #IDE_N-1           ; (again: X went to the saving)
id_d3   lda ide_u,x
        cmp DUNIT
        beq id_d4
        dex
        bpl id_d3
id_d4   stx id_x
        lda DCOMND
        cmp #'R'
        beq id_rw
        cmp #'P'
        beq id_rw
        cmp #'W'
        beq id_rw
        cmp #'S'
        jeq id_s
        cmp #'N'
        jeq id_pc
        cmp #'O'
        beq id_ok
        cmp #'!'
        jeq id_fm
        cmp #'"'
        jeq id_fm
        lda #139
        bne id_st
id_ok   lda #1
id_st   sta DSTATS             ; the status; page 0 back
        ID_REST
        lda DSTATS
        tay
        clc
        rts
* a sector: 1 to the partition's size, at its start - 1 + the sector
id_rw   lda DAUX1
        ora DAUX1+1
        beq id_err
        lda ide_sh,x
        cmp DAUX1+1
        bcc id_err
        bne id_rw1
        lda ide_sl,x
        cmp DAUX1
        bcc id_err
id_rw1  lda DCOMND
        sta id_c
        jsr id_cnt               ; the last one too: DAUX + n - 1
        clc
        lda DAUX1
        adc id_k
        sta id_lba
        lda DAUX1+1
        adc #0
        sta id_lba+1
        lda id_lba
        bne id_rw2
        dec id_lba+1
id_rw2  dec id_lba
        lda ide_sh,x
        cmp id_lba+1
        bcc id_err
        bne id_rw3
        lda ide_sl,x
        cmp id_lba
        bcc id_err
id_rw3  sec
        lda DAUX1
        sbc #1
        sta id_lba
        lda DAUX1+1
        sbc #0
        sta id_lba+1
        clc
        lda id_lba
        adc ide_l0,x
        sta id_lba
        lda id_lba+1
        adc ide_l1,x
        sta id_lba+1
        lda #0
        sta id_lba+3
        adc ide_l2,x
        sta id_lba+2
        lda DCOMND
        jsr id_xfer
        jmp id_st
id_err  lda #144
        jne id_st
* S: status (512-byte sectors); N: a PERCOM block (one track of the
* partition's sectors); a format: no bad sectors (all $FF)
id_s    ldx #0
        lda #4
        bne id_out
id_pc   ldx #id_pcv-id_stv
        lda #12
        bne id_out
id_fm   ldx #id_fmv-id_stv
        lda #12
* id_out: A bytes from id_stv+X to DBUF (DBYT at most); a PERCOM block
* gets the size at 2-3
id_out  sta id_t
        lda DBUFLO
        sta id_p
        lda DBUFHI
        sta id_p+1
        ldy #0
id_o1   cpy id_t
        bcs id_o2
        lda DBYTHI
        bne id_o3
        cpy DBYTLO
        bcs id_o2
id_o3   lda id_stv,x
        sta (id_p),y
        inx
        iny
        bne id_o1
id_o2   lda DCOMND
        cmp #'N'
        jne id_ok
        cpy #4
        jcc id_ok
        ldx id_x
        ldy #2
        lda ide_sh,x
        sta (id_p),y
        iny
        lda ide_sl,x
        sta (id_p),y
        jmp id_ok
id_stv  dta b($30,$FF,$E0,$00)
id_pcv  dta b(1,0,0,0,0,4,2,0,$FF,0,0,0)
id_fmv  dta b($FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF)

* id_info: DEVINFO from IDENTIFY in DBUF: words 60-61 (bytes 120-123),
* the sector count, to bytes 8-11
id_info lda DBUFLO
        sta id_p
        lda DBUFHI
        sta id_p+1
        ldy #123
in1     lda (id_p),y
        pha
        dey
        cpy #120
        bcs in1
        ldy #8
in2     pla
        sta (id_p),y
        iny
        cpy #12
        bcc in2
        rts

* id_cnt: id_k = the sectors in DBYT: DBYT / 512 when it is a multiple
* of 512 (several sectors in one command), else 1 (a part of one; the
* rest of it dropped or zeros); 1 for IDENTIFY
id_cnt  lda #1
        sta id_k
        lda id_c
        cmp #$EC
        beq ic1
        lda DBYTLO
        bne ic1
        lda DBYTHI
        lsr @
        bcs ic1
        beq ic1
        sta id_k
ic1     rts

* id_dlba: the LBA from DAUX..DAUX+3 (an XDCB; 28 bits)
id_dlba lda DAUX1
        sta id_lba
        lda DAUX1+1
        sta id_lba+1
        lda DAUX1+2
        sta id_lba+2
        lda DAUX1+3
        and #$0F
        sta id_lba+3
        rts

.ifdef SD
        icl 'sd.icl'
.else
* id_xfer: command A ('R', 'P', 'W' or $EC) for id_lba (or DAUX..: from
* ide_init, LBA 0) with DBUF and DBYT; A = status
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
        jsr id_cnt
        jsr id_bsy
        jcs ix_to
        lda id_k
        sta ATA_CNT
        lda id_c
        cmp #$EC
        beq ix1
        lda id_lba
        sta ATA_L0
        lda id_lba+1
        sta ATA_L1
        lda id_lba+2
        sta ATA_L2
        lda id_lba+3
        ora #$E0
        sta ATA_DH
        lda id_c
        ldx #$20               ; read
        cmp #'R'
        beq ix2
        ldx #$30               ; write
        bne ix2
ix1     lda #$E0
        sta ATA_DH
        ldx #$EC
ix2     stx ATA_CMD
ix_sec  jsr id_drq             ; each sector: DRQ, its 512 bytes
        jcs ix_rt
        lda PORTB
        sta id_old
        lda id_pb
        sta PORTB
        ldy #0
        ldx #2                 ; 512 bytes: 2 x 256
        lda id_c
        cmp #'P'
        beq ix_w
        cmp #'W'
        beq ix_w
ix_r    lda ATA_DAT
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
        iny
        bne ix_r
        inc id_p+1
        dex
        bne ix_r
        beq ix_end
ix_r2   pla
        iny
        bne ix_r
        inc id_p+1
        dex
        bne ix_r
        beq ix_end
ix_w    lda id_n               ; (past DBYT: zeros)
        ora id_n+1
        beq ix_w2
        lda (id_p),y
        sta ATA_DAT
        lda id_n
        bne ix_w1
        dec id_n+1
ix_w1   dec id_n
        iny
        bne ix_w
        inc id_p+1
        dex
        bne ix_w
        beq ix_end
ix_w2   lda #0
        sta ATA_DAT
        iny
        bne ix_w
        inc id_p+1
        dex
        bne ix_w
ix_end  lda id_old
        sta PORTB
        dec id_k
        jne ix_sec
        jsr id_bsy
        bcs ix_to
        lda ATA_ST
        and #$21               ; ERR, write fault
        bne ix_er
        lda #1
        rts
ix_rt   bne ix_er              ; (id_drq: C=1, Z=0 an error, else a time-out)
ix_to   lda #138
        rts
ix_er   lda #144
        rts

* id_bsy: until BSY is off (about 2 s): C=1 time-out; id_drq: until DRQ
* (C=0) or ERR (C=1, Z=0), or a time-out (C=1, Z=1)
id_bsy  lda RTCLOK+2
        sta id_t
ib1     lda ATA_ST
        bpl ib2
        lda RTCLOK+2
        sec
        sbc id_t
        cmp #120
        bcc ib1
        rts
ib2     clc
        rts
id_drq  lda RTCLOK+2
        sta id_t
iq1     lda ATA_ST
        bmi iq2
        lsr @                  ; ERR
        bcs iq3
        and #$04               ; (DRQ, shifted)
        bne iq4
iq2     lda RTCLOK+2
        sec
        sbc id_t
        cmp #120
        bcc iq1
        lda #0                 ; a time-out: C=1, Z=1
        sec
        rts
iq3     lda #1                 ; an error: C=1, Z=0
        rts
iq4     clc
        rts
.endif
