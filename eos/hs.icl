* High speed SIO (included in dev.asm): the Ultra Speed protocol (US
* Doubler, Happy, Speedy, SIO2PC and the like). hs_drv is an SIO driver
* (chapter 22) through the kernel's stub, in the last sio_vector entry from
* the start, as SDX has its own: each unit 1-15 has a POKEY divisor in
* hs_tab. The first R, P, W or S for a unit asks the drive for it ('?' at
* the normal rate; $80, none, when it does not answer); SIOSET n US sets
* it, SIOSET n NONE ($80) turns it off. For disk units with one, R, P, W
* and S go out and in at that rate, polled with the interrupts off; C=0
* and A = Y = status. Anything else: C=1, the next driver or the OS does
* it.

AUDF3   equ $D204
AUDF4   equ $D206
AUDC4   equ $D207
AUDCTL  equ $D208
STIMER  equ $D209
SKRES   equ $D20A
SEROUT  equ $D20D
SERIN   equ $D20D
IRQST   equ $D20E
SKSTAT  equ $D20F
PBCTL   equ $D303              ; (CB2: the SIO command line)
hs_p    equ $45                ; (the FMS's zp_q, saved)
hs_div  equ $80                ; working variables in page 0 meanwhile, the
hs_try  equ $81                ; caller's bytes kept on the stack
hs_sum  equ $82
hs_st   equ $83
hs_t    equ $84
hs_last equ $85
hs_n    equ $86                ; (2)
hs_one  equ $88                ; '?': the drive's answer
hs_xfm  equ $89                ; $80: XF551 commands (hs_tab bit 6)
hs_dsc  equ $8A                ; $80: the data read is not kept (the probe)
hs_wk   equ $8B                ; frames to wait for an ACK (WAITACK * 2)
hs_fb   equ $8C                ; $80: the next byte sent starts a frame
HS_ZN   equ 13

hs_drv
.ifdef IDE
        jsr ide_drv            ; the CompactFlash card's drives first
        bcs hs_d0
        rts
hs_d0
.endif
        lda DDEVIC
        cmp #$FD               ; SIOSET's: $FF set unit DUNIT's divisor to
        bcs hs_cfg             ; DAUX1, $FE A = it; $FD the values
        cmp #$31
        bne hs_no
        lda DUNIT
        beq hs_no
        cmp #16
        bcs hs_no
        lda DCOMND
        cmp #'R'
        beq hd1
        cmp #'P'
        beq hd1
        cmp #'W'
        beq hd1
        cmp #'S'
        bne hs_no
hd1     lda memreix            ; a buffer in another bank: EOS's own way
        bne hs_no              ; (through fs_sbuf)
        ldy #0                 ; off (DEVICE SIO /A): the OS's SIO
        jsr hs_vget
        bmi hs_no
        ldy DUNIT
        jsr hs_tget            ; (Y: the divisor)
        jpl hs_go              ; (0: not asked yet)
hs_no   sec
        rts
hs_cfg  ldy DUNIT
        cmp #$FD               ; $FD: DUNIT 0 off ($80), 1 REFRESH, 2
        bne hc_u               ; WAITACK; DAUX2 nonzero: set to DAUX1;
        cpy #3                 ; A = it
        bcs hs_no
        lda DAUX2
        beq hcv1
        lda DAUX1
        jsr hs_vset
        cpy #0                 ; off: no unit has a rate any more
        bne hcv1
        ldy #15
hcv0    lda #$80
        jsr hs_tset
        dey
        bne hcv0
hcv1    jsr hs_vget
        tya
        clc
        rts
hc_u    cpy #16
        bcs hs_no
        cmp #$FF
        bne hc1
        lda DAUX1              ; (0: none, $FF: not asked yet)
        bne hc0
        lda #$80
hc0     cmp #$FF
        bne hc0a
        lda #0
hc0a    jsr hs_tset
hc1     jsr hs_tget            ; (0 not asked, $80 none, $81 NORMAL)
        tya
        clc
        rts
* hs_tset: hs_tab,y = A (under the OS ROM; its own PORTB save: k_romoff's
* is the caller's, the FMS's)
hs_tset pha
        lda PORTB
        tax
        and #$FE
        sta PORTB
        pla
        sta hs_tab,y
        stx PORTB
        rts
* hs_vset, hs_vget: the same for hs_off (Y=0), hs_ref (1) and the
* WAITACK (2, hs_tab's unit 0 slot)
hs_vset pha
        lda PORTB
        tax
        and #$FE
        sta PORTB
        pla
        sta hs_off,y
        stx PORTB
        rts
hs_vget lda PORTB
        pha
        and #$FE
        sta PORTB
        lda hs_off,y
        jmp hsg1
* hs_tget: Y = hs_tab,y (under the OS ROM); Z, N from it
hs_tget lda PORTB
        pha
        and #$FE
        sta PORTB
        lda hs_tab,y
hsg1
        tay
        pla
        sta PORTB
        cpy #0
        rts

hs_go   ldx #HS_ZN-1           ; the caller's page 0 bytes kept
hgz1    lda hs_div,x
        pha
        dex
        bpl hgz1
        lda #0
        sta hs_xfm
        sta hs_dsc
        sty hs_div
        ldy #2                 ; the ACK wait: WAITACK frames twice (OS: 2)
        jsr hs_vget
        tya
        asl @
        bne hgw
        lda #2
hgw     sta hs_wk
        lda hs_div
        bne hgo
        jsr hs_ask             ; not asked yet
        bpl hgo
        ldx #0                 ; none: the OS does it
hgz3    pla
        sta hs_div,x
        inx
        cpx #HS_ZN
        bcc hgz3
        sec
        rts
hgo     bit hs_div             ; bit 6: XF551 commands (SIOSET n XF or
        bvc hgx                ; INDUS): the frame at the normal rate with
        lda #$80               ; the command's bit 7 on, the rest at the
        sta hs_xfm             ; divisor
        lda hs_div
        and #$3F
        sta hs_div
hgx     lda #2                 ; tries
        sta hs_try
hs_again jsr hs_xfer
        cmp #1
        beq hs_done
        dec hs_try
        bne hs_again
        pha                    ; failed: with REFRESH 128 the drive is asked
        ldy #1                 ; again on its next use
        jsr hs_vget
        bpl hs_d1
        lda #0
        ldy DUNIT
        jsr hs_tset
hs_d1   pla
hs_done sta DSTATS
        ldx #0
hgz2    pla
        sta hs_div,x
        inx
        cpx #HS_ZN
        bcc hgz2
        lda DSTATS
        tay
        clc
        rts

* hs_ask: the unit's divisor from the drive ('?', one byte, at the normal
* rate) to hs_div and hs_tab ($80, N=1: none); the DCB kept
hs_ask  ldx #9
ha1     lda DCOMND,x
        pha
        dex
        bpl ha1
        lda #'?'
        sta DCOMND
        lda #$40
        sta DSTATS
        lda #<hs_one
        sta DBUFLO
        ldx #0
        stx DBUFLO+1
        stx DBYTLO+1
        stx DAUX1
        stx DAUX2
        inx
        stx DTIMLO
        stx DBYTLO
        lda #$28               ; (19200 baud)
        sta hs_div
        jsr hs_xfer
        cmp #1
        bne ha_xf
        ldy #$80
        lda hs_one             ; (0, or no faster: none)
        beq ha2
        cmp #$28
        bcs ha2
        tay
        bne ha2
ha_xf   lda #'N'               ; no '?': the XF551's commands, as SDX: its
        sta DCOMND             ; configuration ($CE, 12 bytes) at divisor
        lda #12                ; $10, not kept
        sta DBYTLO
        lda #$80
        sta hs_xfm
        sta hs_dsc
        lda #$10
        sta hs_div
        jsr hs_xfer
        ldx #0
        stx hs_xfm
        stx hs_dsc
        ldy #$80
        cmp #1
        bne ha2
        ldy #$50               ; XF
ha2     sty hs_div
        tya
        ldy DUNIT
        jsr hs_tset
        ldx #0
ha3     pla
        sta DCOMND,x
        inx
        cpx #10
        bcc ha3
        lda hs_div
        rts

* hs_xfer: one try; A = status
hs_xfer lda hs_p
        pha
        lda hs_p+1
        pha
        php
        sei
        lda #0                 ; POKEY: channels 3+4 joined at 1.79 MHz
        sta IRQEN
        lda #$28
        sta AUDCTL
        lda hs_div
        bit hs_xfm             ; (XF551: the frame at the normal rate)
        bpl hx0
        lda #$28
hx0     sta AUDF3
        lda #0
        sta AUDF4
        lda #$A0
        sta AUDC4
        sta STIMER             ; (the timers from these values)
        jsr hs_sout            ; sending (output needed enabled)
        lda #$34               ; the command line on
        sta PBCTL
        lda #0                 ; the command frame and its checksum
        sta hs_sum
        lda DDEVIC             ; the device: DDEVIC + DUNIT - 1
        clc
        adc DUNIT
        sec
        sbc #1
        jsr hs_put
        ldx #1
hx1     lda hs_frm-1,x         ; DCOMND, DAUX1, DAUX2
        tay
        lda $0300,y
        cpx #1
        bne hx1a
        ora hs_xfm
hx1a    jsr hs_put
        inx
        cpx #4
        bcc hx1
        lda hs_sum
        jsr hs_put
        jsr hs_wout
        lda #$3C               ; the command line off
        sta PBCTL
        jsr hs_rin             ; receiving from now on
        ldx hs_wk              ; ACK within WAITACK * 2 frames
        jsr hs_get
        jcs hx_to
        cmp #'A'
        jne hx_nak
        lda hs_div             ; (XF551: the rest at the divisor; the
        sta AUDF3              ; timers restarted, else the first bit
        sta STIMER             ; sent goes at the old rate)
        lda DSTATS
        bpl hx_rd
        ldy #2                 ; write: a pause after the ACK first (about
        ldx #0                 ; 1.4 ms: the drive turns round to receive;
hxw     dex                    ; Altirra's drive answers data sent at once
        bne hxw                ; with NAK)
        dey
        bne hxw
        jsr hs_sout            ; the data, its checksum, then ACK
        jsr hs_ptr
        lda #0
        sta hs_sum
        jsr hs_ncnt
        beq hx3
        ldy #0                 ; (inline, about 50 cycles a byte: Altirra's
        ldx #0                 ; drive takes them as fast as they come)
        stx hs_fb
        beq xw2                ; the first byte straight out
xw1     lda IRQST              ; each next one when the one before is taken
        and #$10               ; (output needed)
        beq xw2
        jsr hs_need
xw2     stx IRQEN              ; its latch reset, the byte out
        lda #$10
        sta IRQEN
        lda (hs_p),y
        sta SEROUT
        clc
        adc hs_sum
        adc #0
        sta hs_sum
        iny
        bne xw3
        inc hs_p+1
xw3     inc hs_n
        bne xw1
        inc hs_n+1
        bne xw1
hx3     lda hs_sum
        jsr hs_put
        jsr hs_wout
        jsr hs_rin
        ldx hs_wk
        jsr hs_get
        jcs hx_to
        cmp #'A'
        jne hx_nak
hx_rd   lda DTIMLO             ; COMPLETE within DTIMLO seconds
        asl @
        asl @
        asl @
        asl @
        asl @
        asl @
        tax
        jsr hs_get
        jcs hx_to
        cmp #'C'
        jne hx_err
        bit DSTATS             ; reading: the data and its checksum
        bvc hx_ok
        jsr hs_ptr
        lda #0
        sta hs_sum
        bit hs_dsc             ; (not kept: the probe, the slow way)
        bmi hx4s
        jsr hs_ncnt
        beq hx5
        ldy #0                 ; inline, as the writes
        ldx #0
hr1     lda IRQST              ; input ready
        and #$20
        beq hr2
        jsr hs_rdy             ; (else with the time-out)
        jcs hx_to
hr2     stx IRQEN              ; its latch reset
        lda #$20
        sta IRQEN
        lda SERIN
        sta (hs_p),y
        clc
        adc hs_sum
        adc #0
        sta hs_sum
        iny
        bne hr3
        inc hs_p+1
hr3     inc hs_n
        bne hr1
        inc hs_n+1
        bne hr1
        beq hx5
hx4s    jsr hs_cnt
hx4     jsr hs_end
        beq hx5
        ldx #2
        jsr hs_get
        bcs hx_to
        ldy #0
        bit hs_dsc
        bmi hx4a
        sta (hs_p),y
hx4a    jsr hs_next
        jmp hx4
hx5     lda hs_sum             ; the checksum
        pha
        ldx #2
        jsr hs_get
        pla
        bcs hx_to
        cmp hs_last
        bne hx_cks
        jsr hs_quiet           ; more after it: a longer frame than asked
        bcs hx_ck2             ; (a sector of zeros read as 128 bytes)
hx_ok   lda #1
        bne hx_x
hx_to   lda #138               ; timeout
        bne hx_x
hx_nak  lda #139               ; NAK
        bne hx_x
hx_err  lda #144               ; the drive's error
        bne hx_x
hx_cks  jsr hs_quiet           ; checksum: the rest of a longer frame
hx_ck2  lda #143               ; taken first (a 256-byte sector read as
                               ; 128: DOS 2's density test), else the
                               ; next command goes unheard
hx_x    sta hs_st
        lda #$3C
        sta PBCTL
        lda #0                 ; POKEY as the OS leaves it
        sta AUDCTL
        sta AUDC4
        lda SSKCTL
        sta SKCTL
        lda POKMSK
        sta IRQEN
        plp
        pla
        sta hs_p+1
        pla
        sta hs_p
        lda hs_st
        rts

hs_frm  dta b(2,$0A,$0B)         ; the command frame after the device

* hs_put: A out (with the checksum); keeps X. The frame's first byte
* (hs_fb, set by hs_sout) goes straight to SEROUT; each next one when
* POKEY took the one before into its shift register ("output needed",
* IRQST bit 4, latched): the line never idles between bytes (Altirra's
* drive then takes the frame in a burst, as from SDX's SIO)
hs_put  pha
        clc                    ; the checksum: with end-around carry
        adc hs_sum
        adc #0
        sta hs_sum
        bit hs_fb
        bmi hp_go
        jsr hs_need
hp_go   lda #0                 ; output needed's latch reset, then the byte
        sta hs_fb
        sta IRQEN
        lda #$10
        sta IRQEN
        pla
        sta SEROUT
        rts
* hs_ncnt: hs_n = -DBYT (counted up to 0); Z=1 when none
hs_ncnt sec
        lda #0
        sbc DBYTLO
        sta hs_n
        lda #0
        sbc DBYTLO+1
        sta hs_n+1
        ora hs_n
        rts
* hs_rdy: until input ready, 2 frames at most: C=0, else C=1; keeps X, Y
hs_rdy  lda RTCLOK+2
        sta hs_t
hrd0    lda IRQST
        and #$20
        beq hrd1
        lda RTCLOK+2
        sec
        sbc hs_t
        cmp #3
        bcc hrd0
        rts
hrd1    clc
        rts
* hs_need: until output needed (2 frames at most); keeps X, Y
hs_need lda RTCLOK+2
        sta hs_t
hnd0    lda IRQST
        and #$10
        beq hnd1
        lda RTCLOK+2
        sec
        sbc hs_t
        cmp #3
        bcc hnd0
hnd1    rts
* hs_wout: until the last byte is out: taken into the shift register
* (output needed), then shifted out (transmission finished, bit 3 low)
hs_wout jsr hs_need
        lda #$18
        sta IRQEN
        lda RTCLOK+2
        sta hs_t
hw1     lda IRQST
        and #$08
        beq hw2
        lda RTCLOK+2           ; (2 frames at most)
        sec
        sbc hs_t
        cmp #3
        bcc hw1
hw2     rts
* hs_sout: sending; hs_rin: receiving
hs_sout lda #$23
        sta SKCTL
        sta SKRES
        lda #$10
        sta IRQEN
        lda #$80               ; (a frame starts)
        sta hs_fb
        rts
hs_rin  lda #$13
        sta SKCTL
        sta SKRES
        lda #$20
        sta IRQEN
        rts
* hs_get: a byte within X frames (X=0: 256): A, C=0, the checksum summed
* (hs_last: the byte); C=1 none
hs_get  lda RTCLOK+2
        sta hs_t
hg1     lda IRQST              ; input ready (bit 5 low)
        and #$20
        beq hg2
        lda RTCLOK+2
        cmp hs_t
        beq hg1
        sta hs_t
        dex
        bne hg1
        sec
        rts
hg2     lda #0                 ; its latch reset
        sta IRQEN
        lda #$20
        sta IRQEN
        lda SERIN
        sta hs_last
        clc
        adc hs_sum
        adc #0
        sta hs_sum
        lda hs_last
        clc
        rts
* hs_quiet: until nothing comes for about 1 ms (96 polls: more than a
* byte's time at 19200 baud); C=1 when
* something did (taken and dropped)
hs_quiet clc
hq0     ldy #96
hq1     lda IRQST
        and #$20
        beq hq2
        dey
        bne hq1
        rts
hq2     lda #0
        sta IRQEN
        lda #$20
        sta IRQEN
        lda SERIN
        sec
        bcs hq0
* the buffer: hs_ptr hs_p = DBUF; hs_cnt the count = DBYT (128 for S: 4);
* hs_end Z=1 at the end; hs_next one more
hs_ptr  lda DBUFLO
        sta hs_p
        lda DBUFHI
        sta hs_p+1
        rts
hs_cnt  lda DBYTLO
        sta hs_n
        lda DBYTLO+1
        sta hs_n+1
        rts
hs_end  lda hs_n
        ora hs_n+1
        rts
hs_next inc hs_p
        bne hn1
        inc hs_p+1
hn1     lda hs_n
        bne hn2
        dec hs_n+1
hn2     dec hs_n
        rts
