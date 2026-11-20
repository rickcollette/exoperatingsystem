* EOS (Extendable Operating System): bank 4, character devices CON: PRN: NUL:
*

        icl 'equ.icl'
        icl 'kernel.icl'

        opt h-f+

D_LIST  equ $FE                ; ICAX6 of a D: listing (mode 6)
D_NONE  equ $FF                ; ICAX6 after a failed OPEN

E_OK    equ 1
E_EOF   equ 136
E_NOFUNC equ 146
E_TOOMANY equ 161

        org CARTLO
        jmp con_entry          ; $A000
        jmp prn_entry          ; $A003
        jmp nul_entry          ; $A006
        jmp w_open             ; $A009 CIO D: handler (kernel.asm k_dhand)
        jmp w_close            ; $A00C
        jmp w_get              ; $A00F
        jmp w_put              ; $A012
        jmp d_stat             ; $A015
        jmp w_spec             ; $A018
        jmp clk_entry          ; $A01B CLK: (kernel kd_clk)
        jmp clk_inst           ; $A01E DEVICE RTIME8 / JIFFY (the shell)
        jmp e_read             ; $A021 E: input from the redirected file
        jmp hs_drv             ; $A024 high speed SIO (SIOSET's driver)
        jmp rd_sio             ; $A027 the RAM disk's sectors (kernel ks_rd)
.ifdef IDE
        jmp ide_init           ; $A02A the CompactFlash card: its drives (boot)
.else
        rts                    ; $A02A (no card)
        dta b(0,0)
.endif
        jmp fw_wrap            ; $A02D the FMS's dsk_entry: the byte window
        jmp fw_keep            ; $A030 (fw.icl)
        jmp w_gp               ; $A033 kernel kc_get, kc_put: Y=0 GET, $40 PUT
        jmp l2_get             ; $A036 the second-level cache (l2.icl)
        jmp l2_put             ; $A039
        jmp l2_drop            ; $A03C
        jmp l2_init            ; $A03F
        jmp l2_drop1           ; $A042
        jmp xbounce            ; $A045 the FMS's bounce (bounce.icl)
        jmp mt_fresh           ; $A048 the FMS's mount: the same disk? (fw.icl)
        jmp d_ppos             ; $A04B the DOS 2 bank's kd_pos (fw.icl)

* The D: entries keep the page 0 bytes EOS uses ($15-$16, $43-$48) for the
* caller, as SDX leaves them: resident programs keep pointers there across
* CIO calls (REMMS).
w_open  jsr zsave
        jsr d_open
        jmp zrest
w_close jsr zsave
        jsr d_close
        jmp zrest
w_gp    cpy #0
        bne w_put
w_get   jsr zsave
        jsr d_get
        jmp zrest
w_put   jsr zsave
        jsr d_put
        jmp zrest
w_spec  jsr zsave
        jsr d_spec
        jmp zrest
* zsave: keeps A, X, Y; zrest: keeps A, X, Y, sets N from Y (the status)
zsave   pha
        lda $15
        sta zs_v
        lda $16
        sta zs_v+1
        lda $43
        sta zs_v+2
        lda $44
        sta zs_v+3
        lda $45
        sta zs_v+4
        lda $46
        sta zs_v+5
        lda $47
        sta zs_v+6
        lda $48
        sta zs_v+7
        pla
        rts
zrest   pha
        lda zs_v
        sta $15
        lda zs_v+1
        sta $16
        lda zs_v+2
        sta $43
        lda zs_v+3
        sta $44
        lda zs_v+4
        sta $45
        lda zs_v+5
        sta $46
        lda zs_v+6
        sta $47
        lda zs_v+7
        sta $48
        pla
        cpy #0
        rts

* e_read: the next byte of standard input (redirected to a file) for E:
* GET (kernel.asm k_ehand): C=0, A = the byte; C=1 at its end or an error
e_read  lda COMTAB+7             ; the input file's next byte in the byte
        cmp fw_h               ; window (fw_set, after the last read):
        bne er0                ; from there (kernel kfx1: A, C=0)
        lda fw_n
        beq er0
        jmp kfx1
er0     jsr zsave
        lda file_id
        pha
        lda addpos
        pha
        lda addpos+1
        pha
        lda bytbuf
        pha
        lda bytbuf+1
        pha
        lda memreix
        pha
        lda COMTAB+7
        sta file_id
        lda #<dc_b
        sta addpos
        lda #>dc_b
        sta addpos+1
        lda #1
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        tay                    ; kd_read
        jsr jkernel
        sta dc_st
        pla
        sta memreix
        pla
        sta bytbuf+1
        pla
        sta bytbuf
        pla
        sta addpos+1
        pla
        sta addpos
        pla
        sta file_id
        ldy #1
        jsr zrest
        lda dc_st
        cmp #$80               ; C=1 an error (the end)
        lda dc_b
        rts

* ---- CLK: the clock -----------------------------------------------------------
* Kernel functions 100 kd_gettd (the date and time to date, DD MM YY, and
* time, HH MM SS) and 101 kd_settd (from them). With DEVICE RTIME8 (and
* without an EOSSYS.SYS) the R-Time 8 cartridge when it answers; with
* DEVICE JIFFY a soft clock: the time last set plus the jiffies (RTCLOK, 50
* or 60 a second) counted since. With neither the registers stay as set.
clk_entry cpy #100
        beq ck_get
        cpy #101
        beq ck_set
        cpy #8
        beq ck_rts
        lda #E_NOFUNC
ck_rts  rts
ck_get  lda clk_on
        lsr @
        bcc ck_g0
        jsr rt_read
        bcc ck_ok
ck_g0   lda clk_on
        and #4
        beq ck_g1
        jsr u1_read
        bcc ck_ok
ck_g1   lda clk_on
        and #2
        beq ck_ok
        jsr sc_now
ck_ok   lda #E_OK
        rts
ck_set  jsr sc_mark            ; (the R-Time 8 is not set: Altirra ignores it)
        lda clk_on             ; the U1MB clock is
        and #4
        beq ck_s1
        jsr u1_set
ck_s1   lda #E_OK
        rts

* clk_inst: A = 1 the R-Time 8, else the U1MB's clock (bit 2 of clk_on),
* 2 the soft clock, on; C=1 when neither hardware clock answers (then they
* stay off)
clk_inst cmp #1
        bne ci_j
        jsr rt_read
        bcs ci_u1
        lda clk_on
        ora #1
        sta clk_on
        clc
cin_ret rts
ci_u1   jsr u1_read
        bcs cin_ret
        lda clk_on
        ora #4
        sta clk_on
        clc
        rts
ci_j    jsr sc_mark
        lda clk_on
        ora #2
        sta clk_on
        clc
        rts

* rt_read: the R-Time 8's date and time to date/time; C=1 when it does not
* answer with sensible values (they stay as they were)
rt_read ldx #5
rr1     stx ck_x
        jsr k_rt8
        bcs rr_no
        ldx ck_x
        cmp rt_max,x
        bcs rr_no
        sta ck_v,x
        dex
        bpl rr1
        lda ck_v+3             ; day and month from 1
        beq rr_no
        lda ck_v+4
        beq rr_no
        lda ck_v+2             ; sec min hour -> time HH MM SS
        sta time
        lda ck_v+1
        sta time+1
        lda ck_v
        sta time+2
        lda ck_v+3
        sta date
        lda ck_v+4
        sta date+1
        lda ck_v+5
        sta date+2
        clc
        rts
rr_no   sec
        rts
rt_max  dta b(60,60,24,32,13,100)

* ---- the U1MB's clock: a DS1305 on SPI through $D3E2 -----------------------
* Writes: bit 0 chip enable, bit 1 the clock (0: high), bit 2 the data out;
* bit 3 of a read is the chip's data. A bit goes in when the clock goes low
* again, comes out when it goes high. Registers 0-6: seconds, minutes,
* hours (bit 6: 12-hour mode, bit 5 then PM), day of the week, date, month,
* year, all BCD; $0F control (bit 6 write protect); +$80 to write.
* u1_det first: on a machine without the U1MB $D380-$D3FF are the PIA's
* mirrors ($D382/$D386 PACTL, $D383 PBCTL) and $D3E2 must not be written.
U1RTC   equ $D3E2

* u1_det: C=0 when the U1MB answers ($D382 and $D386 read $FF where PACTL
* would be, $D383, its cold start flag, has bit 7 only)
u1_det  lda $D382
        and $D386
        cmp #$FF
        bne u1_no
        lda $D383
        and #$7F
        bne u1_no
        clc
        rts
u1_no   sec
        rts

* u1_read: the clock's date and time to date/time, as rt_read; C=1 when
* there is no U1MB or the values are not sensible
u1_read jsr u1_det
        bcs u1r_x
        jsr u1_beg
        lda #0                 ; from register 0
        jsr u1_out
        ldx #0
ur1     stx ck_x
        jsr u1_in
        ldx ck_x
        cpx #2
        bne ur2
        jsr u1_hour
        jmp ur3
ur2     cpx #5
        bne ur2a
        and #$1F               ; (the month's bit 7: the century)
ur2a    jsr u1_bin
ur3     bcs u1r_no
        ldx ck_x
        ldy u1_map,x
        bmi ur4                ; (the day of the week)
        cmp rt_max,y
        bcs u1r_no
        sta ck_v,y
ur4     inx
        cpx #7
        bcc ur1
        jsr u1_end
        lda ck_v+3             ; day and month from 1
        beq u1r_x1
        lda ck_v+4
        beq u1r_x1
        ldx #2
ur5     lda ck_v+3,x           ; date DD MM YY, time HH MM SS
        sta date,x
        dex
        bpl ur5
        lda ck_v+2
        sta time
        lda ck_v+1
        sta time+1
        lda ck_v
        sta time+2
        clc
        rts
u1r_no  jsr u1_end
u1r_x1  sec
u1r_x   rts
u1_map  dta b(0,1,2,$FF,3,4,5)

* u1_hour: the hours register A to 0-23 in A; C=1 when not BCD
u1_hour pha
        and #$40
        beq uh24
        pla
        pha
        and #$1F               ; 12-hour: 1-12, bit 5 PM
        jsr u1_bin
        bcs uh_no
        cmp #12
        bne uh1
        lda #0
uh1     sta ck_r
        pla
        and #$20
        beq uh2
        lda ck_r
        clc
        adc #12
        clc
        rts
uh2     lda ck_r
        clc
        rts
uh24    pla
        and #$3F
        jmp u1_bin
uh_no   pla
        sec
        rts

* u1_bin: BCD A to binary; C=1 when a digit is not 0-9
u1_bin  sta ck_r
        and #$0F
        cmp #10
        bcs ub_no
        lda ck_r
        lsr @
        lsr @
        lsr @
        lsr @
        cmp #10
        bcs ub_no
        tax                    ; tens * 10 + units
        lda ck_r
        and #$0F
ub1     dex
        bmi ub2
        adc #10
        bcc ub1
ub2     clc
        rts
ub_no   sec
        rts

* u1_bcd: binary A (0-99) to BCD
u1_bcd  ldx #0
ud1     cmp #10
        bcc ud2
        sbc #10
        inx
        bne ud1
ud2     sta ck_r
        txa
        asl @
        asl @
        asl @
        asl @
        ora ck_r
        rts

* u1_set: date/time to the clock (24-hour mode), its write protection
* lifted meanwhile and set back as it was
u1_set  jsr u1_det
        bcs us_x
        jsr u1_beg             ; the control register
        lda #$0F
        jsr u1_out
        jsr u1_in
        sta ck_hz
        jsr u1_end
        lda ck_hz
        and #$BF
        jsr u1_ctl
        jsr u1_beg
        lda #$80               ; registers 0-6
        jsr u1_out
        lda time+2
        jsr us_out
        lda time+1
        jsr us_out
        lda time
        jsr us_out
        lda #1                 ; (the day of the week: not kept by EOS)
        jsr u1_out
        lda date
        jsr us_out
        lda date+1
        jsr us_out
        lda date+2
        jsr us_out
        jsr u1_end
        lda ck_hz
        jmp u1_ctl
us_out  jsr u1_bcd
        jmp u1_out
us_x    rts
* u1_ctl: A to the control register
u1_ctl  pha
        jsr u1_beg
        lda #$8F
        jsr u1_out
        pla
        jsr u1_out
        jmp u1_end

* u1_beg: chip enable on, the clock low; u1_end: off
u1_beg  lda #$02
        sta U1RTC
        lda #$03
        sta U1RTC
        rts
u1_end  lda #$02
        sta U1RTC
        rts
* u1_out: A to the chip, MSB first; keeps X
u1_out  ldy #8
uo1     asl @
        pha
        lda #0
        rol @
        asl @
        asl @                  ; the bit -> bit 2
        ora #$01               ; clock high
        sta U1RTC
        ora #$02               ; clock low: the bit goes in
        sta U1RTC
        pla
        dey
        bne uo1
        rts
* u1_in: A = the chip's next byte, MSB first; keeps X
u1_in   ldy #8
        lda #0
        sta ck_r
ui1     lda #$01               ; clock high: the chip's bit comes out
        sta U1RTC
        lda U1RTC
        and #$08
        cmp #$08
        rol ck_r
        lda #$03
        sta U1RTC
        dey
        bne ui1
        lda ck_r
        rts

* sc_mark: the soft clock's base: date/time now, at the jiffy count now
sc_mark jsr jiffies
        ldx #2
sm1     lda ck_j,x
        sta sc_j,x
        lda date,x
        sta sc_d,x
        lda time,x
        sta sc_t,x
        dex
        bpl sm1
        rts

* sc_now: the soft clock to date/time: whole seconds since sc_j are added
* to the base (which moves on with them)
sc_now  jsr jiffies
        sec                    ; elapsed = now - sc_j
        lda ck_j+2
        sbc sc_j+2
        sta ck_e+2
        lda ck_j+1
        sbc sc_j+1
        sta ck_e+1
        lda ck_j
        sbc sc_j
        sta ck_e
        lda PALNTS             ; seconds = elapsed / 50 or 60
        beq sn0
        lda #50
        bne sn1
sn0     lda #60
sn1     sta ck_hz
        lda #0
        sta ck_r
        ldx #24
sn2     asl ck_e+2
        rol ck_e+1
        rol ck_e
        rol ck_r
        lda ck_r
        cmp ck_hz
        bcc sn3
        sbc ck_hz
        sta ck_r
        inc ck_e+2
sn3     dex
        bne sn2
        sec                    ; the base moves to now - remainder
        lda ck_j+2
        sbc ck_r
        sta sc_j+2
        lda ck_j+1
        sbc #0
        sta sc_j+1
        lda ck_j
        sbc #0
        sta sc_j
sn4     lda ck_e               ; hours: 3600 s at a time
        bne sn5
        lda ck_e+1
        cmp #>3600
        bcc sn6
        bne sn5
        lda ck_e+2
        cmp #<3600
        bcc sn6
sn5     sec
        lda ck_e+2
        sbc #<3600
        sta ck_e+2
        lda ck_e+1
        sbc #>3600
        sta ck_e+1
        lda ck_e
        sbc #0
        sta ck_e
        inc sc_t
        jmp sn4
sn6     lda ck_e+1             ; minutes, then seconds
        bne sn7
        lda ck_e+2
        cmp #60
        bcc sn8
sn7     sec
        lda ck_e+2
        sbc #60
        sta ck_e+2
        bcs sn7a
        dec ck_e+1
sn7a    inc sc_t+1
        jmp sn6
sn8     clc
        adc sc_t+2
        sta sc_t+2
        cmp #60                ; carries: seconds, minutes, hours, days
        bcc sn9
        sbc #60
        sta sc_t+2
        inc sc_t+1
sn9     lda sc_t+1
        cmp #60
        bcc sn10
        sbc #60
        sta sc_t+1
        inc sc_t
        bne sn9
sn10    lda sc_t
        cmp #24
        bcc sn11
        sbc #24
        sta sc_t
        jsr sc_day
        jmp sn10
sn11    ldx #2
sn12    lda sc_d,x
        sta date,x
        lda sc_t,x
        sta time,x
        dex
        bpl sn12
        rts
* sc_day: the next day (months of 28-31 days, a leap year every fourth)
sc_day  inc sc_d
        ldx sc_d+1
        lda md_len-1,x
        cpx #2
        bne sd1
        tay
        lda sc_d+2
        and #3
        bne sd0
        iny
sd0     tya
sd1     cmp sc_d
        bcs sd_ret
        lda #1
        sta sc_d
        inc sc_d+1
        lda sc_d+1
        cmp #13
        bcc sd_ret
        lda #1
        sta sc_d+1
        inc sc_d+2
        lda sc_d+2
        cmp #100
        bcc sd_ret
        lda #0
        sta sc_d+2
sd_ret  rts
md_len  dta b(31,28,31,30,31,30,31,31,30,31,30,31)
* jiffies: RTCLOK (high byte first) to ck_j, read until it is stable
jiffies lda RTCLOK+2
        sta ck_j+2
        lda RTCLOK+1
        sta ck_j+1
        lda RTCLOK
        sta ck_j
        lda RTCLOK+2
        cmp ck_j+2
        bne jiffies
        rts

* ---- CON: the screen editor E:, open on IOCB 0 ----------------------------
con_entry cpy #0
        beq con_read
        cpy #1
        beq con_write
        jmp common

con_read lda #C_GETB
        bne con_io
con_write lda #C_PUTB
con_io  ldx #0
        sta IOCB0+ICCOM
        lda addpos
        sta IOCB0+ICBAL
        lda addpos+1
        sta IOCB0+ICBAH
        lda bytbuf
        sta IOCB0+ICBLL
        lda bytbuf+1
        sta IOCB0+ICBLH
        ora bytbuf             ; CIO takes a length of 0 as 64K
        beq ci_ok
        jsr CIOV
        lda IOCB0+ICBLL
        sta bytbuf
        lda IOCB0+ICBLH
        sta bytbuf+1
        tya
        bmi ci_ret
ci_ok   lda #E_OK
ci_ret  rts

* ---- PRN: not yet -------------------------------------------------------
prn_entry lda #E_NOFUNC
        rts

* ---- NUL: reads end of file, takes any write ---------------------------
nul_entry cpy #0
        jne common
        lda #0
        sta bytbuf
        sta bytbuf+1
        lda #E_EOF
        rts

* ---- CIO D: on the DSK: kernel device ----------------------------------------
* X = IOCB * 16; the kernel handle is kept in the IOCB's ICAX6 (ICAX3-5 hold
* the file position of POINT and NOTE, as on SDX). Status in Y.
d_open  stx dc_x
        lda #0                 ; a BW-DOS program's 4+32: the directory the
        sta dn_dir             ; name is opened raw (SDX's 36: read along
        lda ICAX1Z             ; $PATH)
        cmp #$24
        bne do0
        bit bw_on
        bpl do0
        sta dn_dir
do0     jsr d_name
        bcs d_oerr
        lda ICAX1Z
        cmp #6                 ; 6: the directory listed as Atari DOS 2
        beq d_dir              ; lists it (FDOPEN $0B: names, sectors, free)
        sta mode
        and #$40               ; +64: scan for the attributes in ICAX2
        beq do5
        lda ICAX2Z
        sta attr
        lda mode
        and #$BF
        sta mode
        lda #$A0
        bne do6
do5     lda #$A0               ; (hidden files too, as the kernel does)
do6     sta scan
        lda mode
        cmp #36                ; 36: read, the file looked for along $PATH
        bne do7                ; (not yet: the name as given)
        lda #4
        bit bw_on              ; (a BW-DOS program: its directory, raw)
        bpl do6a
        lda #$14
do6a    sta mode
do7     ldy #9                 ; kd_open
        jsr jkernel
        bmi d_oerr
        ldx dc_x
        lda file_id
        sta IOCB0+ICAX6,x
        ldy #1
        rts
d_dir   lda #$0B
        sta mode
        lda #0                 ; (directories too)
        sta scan
        jsr farcall
        dta b(BK_LIB2),a(L2_FDOPEN6)
        bmi d_oerr
        ldx dc_x
        lda #D_LIST
        sta IOCB0+ICAX6,x
        ldy #1
        rts
d_oerr  ldx dc_x                ; a failed OPEN: no file (CIO calls CLOSE
        pha                    ; all the same)
        lda #D_NONE
        sta IOCB0+ICAX6,x
        pla
        tay
        rts
ds_chk  jsr d_name
        jcs d_err
        ldy #19                ; kd_check: 17 bytes in path, as SpartaDOS's
        jsr jkernel            ; XIO 47 has them
        bmi dk_ret
        ldy #16
dk1     lda path,y
        sta (ICBLLZ),y
        dey
        bpl dk1
        lda #1
dk_ret  tay
        rts
d_nofn  lda #E_NOFUNC
d_err   tay
        rts

* d_name: Dn: (the unit CIO found) and the name given to CIO, after its
* device part, to dc_name; FILE_P at it; through U_GEFINA (C=1, A=status)
d_name  lda #'D'
        sta dc_name
        lda ICDNOZ
        ldx #1
        cmp #10
        bcc dn1
        sbc #10
        pha
        lda #'1'
        sta dc_name,x
        inx
        pla
dn1     ora #'0'
        sta dc_name,x
        inx
        lda #':'
        sta dc_name,x
        inx
        ldy #0                 ; skip CIO's device part
dn2     lda (ICBALZ),y
        iny
        cmp #':'
        beq dn3
        cpy #4
        bcc dn2
        ldy #0
dn3     lda (ICBALZ),y
        sta dc_name,x
        cmp #EOL
        beq dn4
        iny
        inx
        cpx #67
        bcc dn3
        lda #EOL
        sta dc_name,x
dn4     lda dn_dir             ; (BW-DOS's 4+32: NAME> names the directory)
        beq dn5
        lda #'>'
        sta dc_name,x
        lda #EOL
        sta dc_name+1,x
        lda #0                 ; (this OPEN only)
        sta dn_dir
dn5     lda #<dc_name
        sta FILE_P
        lda #>dc_name
        sta FILE_P+1
        jsr farcall
        dta b(BK_LIB),a(L_GEFINA2)
        rts

d_close jsr d_fid
        cmp #D_NONE            ; (after a failed OPEN)
        beq dc0
        cmp #D_LIST            ; a listing (mode 6)
        bne dc1
        lda fw_h               ; (its byte window goes)
        cmp #$FE
        bne dc_l
        lda #$FF
        sta fw_h
        lda #0
        sta fw_n
dc_l    jsr farcall
        dta b(BK_LIB2),a(L2_FDCLOSE)
dc0     ldy #1
        rts
dc1     ldy #7                 ; kd_close
        jsr jkernel
        tay
        rts

d_get   jsr d_fid
        cmp #D_LIST            ; a listing: its next byte
        bne dg1
        jsr farcall
        dta b(BK_LIB2),a(L2_FDGETC)
        bmi dg_end
        pha                    ; the rest of the line to the kernel's byte
        lda fw_h               ; window (kf_io: from LBUF, fw_h $FE), when
        cmp #$FE               ; no file has it (none $FF, or a listing's)
        bcc dg_l1
        sec
        lda fd_len
        sbc fd_pos
        beq dg_l1
        bcc dg_l1
        sta fw_n
        clc
        lda #<(COMTAB+CT_LBUF)
        adc fd_pos
        sta kf_op+1
        lda #>(COMTAB+CT_LBUF)
        adc #0
        sta kf_op+2
        lda #$AD               ; LDA abs
        sta kf_op
        lda fd_len             ; (the line is the window's now)
        sta fd_pos
        lda #$FE
        sta fw_h
dg_l1   pla
        ldy #1
        rts
dg_end  ldy #136
        rts
dg1     lda #0
        jsr d_burst
        jcs d_err
        lda #0
        jsr d_io
        jmi d_err
        lda dc_b
        rts

d_put   sta dc_b
        jsr d_fid
        cmp #D_LIST
        jeq d_nofn
        lda #1                 ; this byte (CIO's first) first, then the
        jsr d_io               ; rest of the buffer at once
        bmi dp_r
        lda #1
        jsr d_burst
        jcs d_err
        lda #1
dp_r    tay
        rts

d_stat  ldy #1
        rts

* d_spec: the XIO commands of SDX's D: (User Guide 6.3): on an open file
* 37 POINT, 38 NOTE, 39 its length (ICAX3-5); on names 32 rename, 33
* erase, 35 protect, 36 unprotect, 41 drive and directory, 42 MKDIR, 43
* RMDIR, 44 CHDIR, 45 boot file, 47 the disk's information, 49 attributes
* (ICAX1 set, ICAX2 clear)
d_spec  stx dc_x
        lda ICCOMZ
        cmp #37
        bcc ds_name
        cmp #40
        bcs ds_name
        jsr d_fid              ; 37-39: the open file
        lda ICCOMZ
        cmp #38
        beq ds_note
        bcs ds_len
        lda IOCB0+ICAX3,x      ; POINT
        sta addpos
        lda IOCB0+ICAX4,x
        sta addpos+1
        lda IOCB0+ICAX5,x
        sta addpos+2
        jsr ds_dos2
        ldy #2                 ; kd_pos
ds_k    jsr jkernel
        tay
        rts
ds_note jsr ds_dos2
        ldy #3                 ; kd_gtpos
        bne ds_pos
ds_len  ldy #4                 ; kd_gtlen
ds_pos  jsr jkernel
        jmi d_err
        ldx dc_x
        lda addpos
        sta IOCB0+ICAX3,x
        lda addpos+1
        sta IOCB0+ICAX4,x
        lda addpos+2
        sta IOCB0+ICAX5,x
        ldy #1
        rts
ds_name lda ICCOMZ             ; the commands on names
        cmp #47                ; 47: the disk's information (SpartaDOS's
        jeq ds_chk             ; CHKDSK) to the buffer ICBLL/ICBLH points at
        ldy #ds_n-1
ds1     cmp ds_cmd,y
        beq ds2
        dey
        bpl ds1
        jmp d_nofn
ds2     lda ds_fn,y
        sta dc_b
        lda ds_atr,y
        sta attr
        jsr d_name
        jcs d_err
        lda ICCOMZ
        cmp #32
        bne ds3
        jsr farcall            ; rename: OLD NEW
        dta b(BK_LIB),a(L_RENM)
        tay
        rts
ds3     cmp #49
        bne ds4
        lda ICAX1Z             ; attributes: bits to set, bits to clear
        and #$07
        sta attr
        lda ICAX2Z
        and #$07
        asl @
        asl @
        asl @
        asl @
        ora attr
        sta attr
ds4     lda #0
        sta scan
        lda ICCOMZ
        cmp #41                ; drive and directory: CHDIR, then the drive
        bne ds5
        ldy #16
        jsr jkernel
        bmi ds_ret
        lda device
        sta CURDEV
        ldy #1
        rts
ds5     ldy dc_b
        jsr jkernel
ds_ret  tay
        rts
ds_cmd  dta b(32,33,35,36,41,42,43,44,45,49)
ds_n    equ *-ds_cmd
ds_fn   dta b(11,12,13,13,16,14,15,16,18,13)
ds_atr  dta b(0,0,$01,$10,0,0,0,0,0,0)

* d_burst: GET or PUT CHARACTERS (A = 0 read, 1 write): all but the last
* byte in one kernel call, straight to or from the caller's buffer, which
* CIO's pointers in page 0 then pass (as Atari DOS 2 does it); CIO moves
* the last byte itself. Only at the first byte of a CIO transfer (page 0
* still as the IOCB has it: BASIC may call the handler's PUT directly, with
* page 0 left from an earlier call) and for a buffer below $A000 (the
* kernel's banks are at $A000 while it copies). Keeps X. C=1, A = status
* when the kernel failed (the end of the file aside: CIO gets that next).
d_burst sta dc_dir
        lda kc_from            ; only for CIO's calls (kernel kf_io)
        cmp #$C0
        jcc db_ret
        lda ICCOMZ
        ldy dc_dir
        cmp db_cmd,y
        jne db_ret
        lda ICBALZ             ; the transfer's first byte
        cmp IOCB0+ICBAL,x
        jne db_ret
        lda ICBALZ+1
        cmp IOCB0+ICBAH,x
        jne db_ret
        cmp #$08               ; a BW-DOS program's buffer in page 7 (or
        bcs db_b0              ; below): byte by byte, CIO stores them with
        bit bw_on              ; its page 7 in (bw.icl)
        jmi db_ret
db_b0   lda ICBLLZ
        cmp IOCB0+ICBLL,x
        jne db_ret
        lda ICBLLZ+1
        cmp IOCB0+ICBLH,x
        jne db_ret
        sec                    ; n = the bytes left - 1
        lda ICBLLZ
        sbc #1
        sta bytbuf
        lda ICBLLZ+1
        sbc #0
        sta bytbuf+1
        ora bytbuf
        beq db_ret
        clc                    ; all of it below $A000
        lda ICBALZ
        adc bytbuf
        lda ICBALZ+1
        adc bytbuf+1
        bcs db_ret
        cmp #$A0
        bcs db_ret
        lda ICBALZ             ; reading: from the first byte (CIO stores
        ldy dc_dir             ; the last one); writing: after it (the
        beq db_a               ; handler has written it)
        clc
        adc #1
db_a    sta addpos
        lda ICBALZ+1
        adc #0
        sta addpos+1
        lda #0
        sta memreix
        ldy dc_dir             ; kd_read or kd_write
        jsr jkernel
        sta dc_st
        clc                    ; CIO's pointer and count move past what was done
        lda ICBALZ
        adc bytbuf
        sta ICBALZ
        lda ICBALZ+1
        adc bytbuf+1
        sta ICBALZ+1
        sec
        lda ICBLLZ
        sbc bytbuf
        sta ICBLLZ
        lda ICBLLZ+1
        sbc bytbuf+1
        sta ICBLLZ+1
        ldx dc_x
        lda dc_st
        bpl db_ret
        cmp #136
        beq db_ret
        sec
        rts
db_ret  clc
        rts
db_cmd  dta b(7,11)            ; GET, PUT CHARACTERS

* ds_dos2: CIO's NOTE and POINT: on an Atari DOS 2 or MyDOS disk the
* sector and the byte in it, as those DOSes have them (dos2.asm d_pos,
* d_gtpos; FSEEK and FTELL keep byte positions). Keeps X.
ds_dos2 jsr k_romoff
        lda #$80
        sta d_note
        jmp k_romon

* d_fid: file_id from the IOCB (X)
d_fid   lda IOCB0+ICAX6,x
        sta file_id
        stx dc_x
        rts

* d_io: kernel read (A=0) or write (A=1) of the byte dc_b; status in A, Y
d_io    pha
        lda #<dc_b
        sta addpos
        lda #>dc_b
        sta addpos+1
        lda #1
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        pla
        tay
        jsr jkernel
        tay
        ldx dc_x
        tya
        rts

* write, close, initz and open, the same for every device here
common  cpy #1
        beq ok
        cpy #7
        beq ok
        cpy #8
        beq initz
        cpy #9
        beq newhandle
        lda #E_NOFUNC
        rts
ok      lda #E_OK
initz   rts

* a free kernel handle to file_id
newhandle ldy #0
        lda #$FF
nh1     cmp dev_index,y
        beq nh2
        iny
        cpy #16
        bcc nh1
        lda #E_TOOMANY
        rts
nh2     sty file_id
        lda #E_OK
        rts

        icl 'hs.icl'
        icl 'fw.icl'
        icl 'l2.icl'
        icl 'bounce.icl'
* the FMS's cache buffers (as fms.asm bf_lo, bf_hi)
xbf_lo  dta l(BF_DATA,BF_DATA+SECMAX,BF_DATA+2*SECMAX,BF_DATA+3*SECMAX)
        dta l(BF_DAT2,BF_DAT2+SECMAX,BF_DAT2+2*SECMAX,BF_DAT2+3*SECMAX)
xbf_hi  dta h(BF_DATA,BF_DATA+SECMAX,BF_DATA+2*SECMAX,BF_DATA+3*SECMAX)
        dta h(BF_DAT2,BF_DAT2+SECMAX,BF_DAT2+2*SECMAX,BF_DAT2+3*SECMAX)

* rd_sio (the kernel's ks_rd): the RAM disk's sector DAUX between its bank
* (rd_first + (s-1)/64, page $40 + (s-1) mod 64) and DBUF, DBYT bytes, one
* byte at a time so that DBUF may be anywhere, the bank window too. 138
* past its end.
rd_sio  lda DCOMND             ; R reads, P and W write, N its PERCOM
        cmp #'R'
        beq rs0
        cmp #'P'
        beq rs0
        cmp #'W'               ; block; nothing else
        beq rs0
        cmp #'N'
        beq rd_pcom
        ldy #139
        sty DSTATS
        tya
        rts
* rd_pcom: the RAM disk's PERCOM block to DBUF: one track of all its
* sectors (64 for each bank), one side, double density, 256-byte sectors,
* there (as SDX's: RDDUMP and RDLOAD read it)
rd_pcom lda ks_zq              ; (the FMS's pointer, kept)
        pha
        lda ks_zq+1
        pha
        lda DBUFLO
        sta ks_zq
        lda DBUFHI
        sta ks_zq+1
        ldy #11                ; the block (rp_blk is in the cartridge:
rp1     lda rp_blk,y           ; the sectors go into the copy)
        sta (ks_zq),y
        dey
        bpl rp1
        ldx rd_cx              ; sectors: banks * 64, high byte first
        lda rd_n,x
        lsr @
        lsr @
        ldy #2
        sta (ks_zq),y
        lda rd_n,x
        and #3
        lsr @
        ror @
        ror @
        iny
        sta (ks_zq),y
        pla
        sta ks_zq+1
        pla
        sta ks_zq
        ldy #1
        sty DSTATS
        tya
        rts
rp_blk  dta b(1,0,0,0,0,4,1,0,$FF,0,0,0)
rs0     lda ks_zt
        pha
        lda ks_zt+1
        pha
        lda ks_zq
        pha
        lda ks_zq+1
        pha
        lda DAUX1
        sec
        sbc #1
        sta ks_zt
        lda DAUX2
        sbc #0
        sta ks_zt+1
        lda ks_zt
        asl @
        rol ks_zt+1
        asl @
        rol ks_zt+1
        lda ks_zt+1
        ldx rd_cx
        cmp rd_n,x
        jcs rs_no
        adc rd_first,x
        jsr k_tconv
        and #$FE               ; the OS ROM off, as the RAM disk is kept
        sta ks_pb
        lda ks_zt
        and #$3F
        ora #$40
        sta ks_zt+1
        lda #0
        sta ks_zt
        lda DBUFLO
        sta ks_zq
        lda DBUFHI
        sta ks_zq+1
        lda DBYTLO
        sta ks_n
        lda DBYTHI
        sta ks_n+1
        lda memreix            ; the caller's memory: memreix's, else as it is
        beq rsp
        jsr k_tconv
        jmp rss
rsp     lda PORTB
rss     sta ks_pm
        php
        sei
        ldy #0
rs1     lda ks_n
        ora ks_n+1
        beq rs_end
        lda DCOMND
        cmp #'R'
        bne rs_w
        lda ks_pb              ; read: bank to DBUF
        sta PORTB
        lda (ks_zt),y
        ldx ks_pm
        stx PORTB
        sta (ks_zq),y
        jmp rs2
rs_w    lda ks_pm              ; write: DBUF to the bank
        sta PORTB
        lda (ks_zq),y
        ldx ks_pb
        stx PORTB
        sta (ks_zt),y
        ldx ks_pm
        stx PORTB
rs2     iny
        bne rs3
        inc ks_zt+1
        inc ks_zq+1
rs3     lda ks_n
        bne rs4
        dec ks_n+1
rs4     dec ks_n
        jmp rs1
rs_end  plp
        ldy #1
        bne rs_x
rs_no   ldy #138
rs_x    pla
        sta ks_zq+1
        pla
        sta ks_zq
        pla
        sta ks_zt+1
        pla
        sta ks_zt
        sty DSTATS
        tya
        rts


.ifdef IDE
        icl 'ide.icl'
.endif
        icl 'tail.icl'
