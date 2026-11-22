; EOS CAR: FORMAT, format a disk
;   FORMAT                      the formatter menu
;   FORMAT /Q|QQ [dn:] [volname] soft format (/Q asks first, /QQ does not)
; A soft format ("build directory") writes an empty EOSFS v2 file system
; on whatever the drive holds: boot sectors (EOS's boot loader, which loads
; the BOOT file; for 512-byte sectors one sector that fails to boot), the
; bitmap, the main directory (a data sector, then its extent list); the rest of
; the disk is free (optimized: the last sector too). The drive's size
; comes from its PERCOM block, else from an EOSFS volume header on it, else
; from its status (single, enhanced or double density, 40 tracks).
; The menu also formats floppies physically (PERCOM block written to a
; drive that has one, then the format command; the skew: Standard, High Speed (XF551 $A1),
; Ultra Speed (US Doubler $66 with a sector order)) and
; Foreign logical creation is provided by transient Toolkit programs.
; All sector I/O goes through jsector_io (device $31, the unit from
; sio_index), so the RAM disk and installed SIO drivers are formatted too;
; the FMS is asked for the disk's information first, so that
; sectors it still has to write are written before.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_FAIL   smb 'U_FAIL'
U_ERROR  smb 'U_ERROR'
U_GETKEY smb 'U_GETKEY'
PRINTF   smb 'PRINTF'
PUTC     smb 'PUTC'
GETS     smb 'GETS'
CURDEV   smb 'CURDEV'
COMTAB2  smb 'COMTAB2'
        icl 'DATEequ.icl'

;lsio (COMTAB-11): jsector_io (the SIO drivers, the RAM disk, else the
;OS's SIOV) with memreix 0
SIOV     equ $0A2F
RTCLOK   equ $12
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUFLO   equ $0304
DTIMLO   equ $0306
DBYTLO   equ $0308
DAUX1    equ $030A
RANDOM   equ $D20A
CMDLINE  equ $0580              ; LBUFF, the command line
EOL      equ $9B
ESC      equ $1B
E_BADPAR equ 156
        icl 'FORMATbequ.icl'

        blk reloc main
start   lda #1                 ; defaults: optimize, standard skew, EOSFS v2
        sta opt
        lda #0
        sta skew
        sta size
        jsr presize
        lda CURDEV
        and #$0F
        sta drv
        jsr U_GETPAR
        jeq menu
        lda COMTAB+$21         ; /Q or /QQ
        cmp #'/'
        jne bad
        lda COMTAB+$22
        cmp #'Q'
        jne bad
        lda #0                 ; /QQ (or more Q): no question
        sta quiet
        ldx #3
q0      lda COMTAB+$20,x
        cmp #EOL
        beq q1
        cmp #'Q'
        jne bad
        inc quiet
        inx
        bne q0
q1
        lda #0
        sta newvol
        lda COMTAB+$0A         ; BUFOFF: where the name starts in LBUF
        sta vpos
        jsr U_GETPAR           ; [dn:] [volname]
        beq q_go
        jsr isdrv
        bcs q3
        jsr U_GEFINA
        lda device             ; a disk only
        and #$F0
        jne bad
q2      lda device
        and #$0F
        sta drv
        lda COMTAB+$0A
        sta vpos
        jsr U_GETPAR
        beq q_go
q3      jsr setvol             ; (more words are ignored)
q_go    jsr setdrv
        jsr geo
        jcs fail
        lda newvol             ; the name: as given, else the old one
        bne q4
        jsr oldname
q4      lda quiet
        bne q5
        jsr PRINTF
        dta c'Clear drive D%b: (Y/N)? ',0
        dta a(drv)
        jsr U_GETKEY
        bmi q6
        and #$5F
        pha
        jsr PUTC
        lda #EOL
        jsr PUTC
        pla
        cmp #'Y'
        bne q6
q5      jsr builddir
        jcs fail
q6      rts

bad     lda #E_BADPAR
        jmp U_FAIL
fail    jmp U_FAIL

; isdrv: C=0 when COMFNAM ends in ':' (a device, not a name)
isdrv   ldx #0
id1     lda COMTAB+$21,x
        cmp #EOL
        beq id2
        inx
        bne id1
id2     lda COMTAB+$20,x
        cmp #':'
        beq id3
        sec
        rts
id3     clc
        rts

; setvol: the name as typed (its case kept, as SDX's FORMAT does; 8
; characters at most) from LBUF at vpos into vol
setvol  ldy vpos
sv0     lda CMDLINE,y
        cmp #' '
        beq sv0a
        cmp #','
        bne sv0b
sv0a    iny
        bne sv0
sv0b    ldx #0
sv1     lda CMDLINE,y
        cmp #EOL
        beq sv2
        cmp #' '
        beq sv2
        cmp #','
        beq sv2
        sta vol,x
        iny
        inx
        cpx #8
        bcc sv1
        bcs sv4
sv2     lda #' '
sv3     sta vol,x
        inx
        cpx #8
        bcc sv3
sv4     lda #1
        sta newvol
        rts

; setdrv: the SIO unit of drive drv (sio_index)
setdrv  ldx drv
        lda COMTAB2+1,x
        sta unit
        rts

; ---- SIO --------------------------------------------------------------------

; sio: command A on unit, sector s_sec, s_len bytes at s_buf, direction
; s_dir, time-out s_tim. A = the status, N=1 on an error.
sio     sta DCOMND
        lda #$31
        sta DDEVIC
        lda unit
        sta DUNIT
        lda s_dir
        sta DSTATS
        lda s_buf
        sta DBUFLO
        lda s_buf+1
        sta DBUFLO+1
        lda s_tim
        sta DTIMLO
        lda s_len
        sta DBYTLO
        lda s_len+1
        sta DBYTLO+1
        lda s_sec
        sta DAUX1
        lda s_sec+1
        sta DAUX1+1
        jsr SIOV
        lda #7
        sta s_tim
        tya
        rts

; rdsec / wrsec: sector s_sec to / from buf+s_off (its size: 128 for
; sectors 1-3 of a 256-byte disk); A = the status, N=1 on an error
rdsec   lda #$40
        ldx #'R'
        bne rw
wrsec   ldx COMTAB-2           ; WRTCMD: P, or W with verify
        cpx #'W'
        beq wr1
        ldx #'P'
wr1     lda #$80
rw      sta s_dir
        txa
        pha
        lda seclen
        sta s_len
        lda seclen+1
        sta s_len+1
        cmp #1                 ; 256: the first three are 128 bytes
        bne rw1
        lda s_sec+1
        bne rw1
        lda s_sec
        cmp #4
        bcs rw1
        lda #128
        sta s_len
        lda #0
        sta s_len+1
rw1     clc
        lda p_buf
        adc s_off
        sta s_buf
        lda p_buf+1
        adc s_off+1
        sta s_buf+1
        pla
        jmp sio

; ---- the drive's size ---------------------------------------------------------

; geo: seclen, total, tbyte of drive unit; pc_ok 1 when it has a PERCOM
; block, hard 1 when that says one track (a hard disk or ramdisk).
; C=1 and A = status when the drive does not answer.
geo     lda #0
        sta pc_ok
        sta hard
        sta s_off
        sta s_off+1
        sta s_sec
        sta s_sec+1
        lda #12                ; the PERCOM block
        sta s_len
        lda #0
        sta s_len+1
        lda #$40
        sta s_dir
        lda p_pcb
        sta s_buf
        lda p_pcb+1
        sta s_buf+1
        lda #'N'
        jsr sio
        bmi g_hdr
        lda pcb+6              ; 128, 256 or 512 bytes
        sta seclen+1
        lda pcb+7
        sta seclen
        jsr chksz
        bcs g_hdr
        lda pcb                ; tracks x sectors x heads
        beq g_hdr
        sta m_b
        lda pcb+3
        sta m_a
        lda pcb+2
        sta m_a+1
        ora m_a
        beq g_hdr
        jsr mul
        lda pcb+4
        beq g1
        lda #2
        sta m_b
        jsr mul
g1      lda m_a
        sta total
        lda m_a+1
        sta total+1
        lda pcb                ; tracks, +$80 double sided
        ldx pcb+4
        beq g2
        ora #$80
g2      sta tbyte
        inc pc_ok
        lda pcb
        cmp #1
        bne g3
        inc hard
g3      clc
        rts
g_hdr   lda #128               ; an EOSFS header in sector 1?
        sta seclen
        lda #0
        sta seclen+1
        jsr rdhdr
        bcc g_ok
        cmp #138               ; no drive
        beq g_err
        lda #0                 ; 512-byte sectors?
        sta seclen
        lda #2
        sta seclen+1
        jsr rdhdr
        bcc g_ok
g_st    lda #4                 ; the drive's status: its density
        sta s_len
        lda #0
        sta s_len+1
        sta s_sec
        sta s_sec+1
        lda #$40
        sta s_dir
        lda p_pcb
        sta s_buf
        lda p_pcb+1
        sta s_buf+1
        lda #'S'
        jsr sio
        bmi g_err
        lda #<720
        sta total
        lda #>720
        sta total+1
        lda #128
        sta seclen
        lda #0
        sta seclen+1
        lda #40
        sta tbyte
        lda pcb
        and #$20               ; double density
        beq g4
        lda #0
        sta seclen
        lda #1
        sta seclen+1
        bne g_ok
g4      lda pcb
        bpl g_ok               ; enhanced density
        lda #<1040
        sta total
        lda #>1040
        sta total+1
g_ok    clc
        rts
g_err   sec
        rts

; rdhdr: sector 1 as seclen gives it: C=0 when it is an EOSFS header (total
; and seclen from it), else C=1 (A = the status of a failed read, or 0)
rdhdr   lda #1
        sta s_sec
        lda #0
        sta s_sec+1
        sta s_off
        sta s_off+1
        jsr rdsec
        bmi rh_err
        lda buf+32
        cmp #$47
        beq rh21
        cmp #$48
        bne rh_no
rh21    lda buf+33
        sta seclen
        lda buf+34
        sta seclen+1
        jsr chksz
        bcs rh_no
rh1     lda buf+11
        sta total
        lda buf+12
        sta total+1
        lda buf+30
        sta tbyte
        clc
        rts
rh_no   lda #0
rh_err  sec
        rts

; chksz: C=0 when seclen is 128, 256 or 512
chksz   lda seclen
        ldx seclen+1
        bne cz1
        cmp #128
        beq cz_ok
        bne cz_no
cz1     cmp #0
        bne cz_no
        cpx #3
        bcc cz_ok
cz_no   sec
        rts
cz_ok   clc
        rts

; oldname: the volume name on an EOSFS disk, else blanks, into vol
oldname ldx #7
        lda #' '
on1     sta vol,x
        dex
        bpl on1
        lda #1
        sta s_sec
        lda #0
        sta s_sec+1
        sta s_off
        sta s_off+1
        jsr rdsec
        bmi on3
        lda buf+32
        cmp #$47
        beq on2a
        cmp #$48
        bne on3
on2a
        ldx #7
on2     lda buf+22,x
        sta vol,x
        dex
        bpl on2
on3     rts

; mul: m_a (16 bits) = m_a * m_b (8 bits), up to 65535
mul     lda #0
        sta m_r
        sta m_r+1
        ldx #8
mu1     lsr m_b
        bcc mu2
        clc
        lda m_r
        adc m_a
        sta m_r
        lda m_r+1
        adc m_a+1
        sta m_r+1
        bcs mu_big
mu2     asl m_a
        rol m_a+1
        bcs mu3
        dex
        bne mu1
        beq mu4
mu3     lda m_b                ; more to add: too big
        bne mu_big
mu4     lda m_r
        sta m_a
        lda m_r+1
        sta m_a+1
        rts
mu_big  lda #$FF
        sta m_a
        sta m_a+1
        rts

; ---- BUILDDIR: an empty EOSFS v2 file system ---------------------------------

; builddir: on drive unit, size seclen/total, name vol, opt;
; C=1, A = status on an error
builddir jsr flush
        jsr layout
        jcc bd5
        rts

; layout: where builddir puts things for seclen/total/opt: nboot, nbmp,
; dsec, msec, ffree, last, free; C=1, A=162 when the disk is too small
layout  lda #3                 ; boot sectors: 3, or one of 512 bytes
        ldx seclen+1
        cpx #2
        bne bd1
        lda #1
bd1     sta nboot
        ldx #10                ; bits in a bitmap sector: 2^(7+3+size)
        lda seclen+1
        beq bd2
        inx
        cmp #1
        beq bd2
        inx
bd2     stx shift
        lda #0                 ; nbmp = (total + bits) >> shift
        sta t24+2
        lda seclen
        asl @
        sta t24
        lda seclen+1
        rol @
        asl t24
        rol @
        asl t24
        rol @
        sta t24+1
        clc
        lda t24
        adc total
        sta t24
        lda t24+1
        adc total+1
        sta t24+1
        bcc bd3
        inc t24+2
bd3     lsr t24+2
        ror t24+1
        ror t24
        dex
        bne bd3
        lda t24
        sta nbmp
        clc                    ; main directory: data, then its map
        lda nboot
        adc nbmp
        adc #1
        sta dsec
        lda #0
        adc #0
        sta dsec+1
        clc
        lda dsec
        adc #1
        sta msec
        lda dsec+1
        adc #0
        sta msec+1
        clc                    ; the first free sector follows the main map
        lda msec
        adc #1
        sta ffree
        lda msec+1
        adc #0
        sta ffree+1
bd2i
        lda total              ; the last free one
        sta last
        lda total+1
        sta last+1
        lda opt
        bne bd4
        lda last
        bne bd3a
        dec last+1
bd3a    dec last
bd4     sec                    ; free = last - ffree + 1
        lda last
        sbc ffree
        sta free
        lda last+1
        sbc ffree+1
        sta free+1
        bcc ly_no
        inc free
        bne ly_ok
        inc free+1
        jmp ly_ok
ly_no
        lda #162               ; too small a disk
        sec
        rts
ly_ok   clc
        rts
; boot sectors and the volume header
bd5     jsr clrbuf
        lda seclen+1
        cmp #2
        beq bd7
        ldx #0                 ; the EOSFS boot loader, 3 x 128 bytes
bd6     lda xbooter,x
        sta buf,x
        lda xbooter+128,x
        sta buf+128,x
        lda xbooter+256,x
        sta buf+256,x
        inx
        bpl bd6
        bmi bd8
bd7     ldx #10                ; 512: a sector that does not boot
bd7a    lda boot512,x
        sta buf,x
        dex
        bpl bd7a
bd8     lda msec
        sta buf+9
        lda msec+1
        sta buf+10
        lda total
        sta buf+11
        lda total+1
        sta buf+12
        lda free
        sta buf+13
        lda free+1
        sta buf+14
        lda nbmp
        sta buf+15
        lda nboot
        clc
        adc #1
        sta buf+16
        lda #0
        sta buf+17
        sta buf+20
        sta buf+21
        sta buf+40
        sta buf+41
        lda ffree
        sta buf+18
        lda ffree+1
        sta buf+19
        ldx #7
bd9     lda vol,x
        sta buf+22,x
        dex
        bpl bd9
        lda tbyte
        sta buf+30
        ldx seclen+1           ; size code: $80, 0, 1
        lda szcode,x
        sta buf+31
        lda #$47
        sta buf+32
        lda seclen
        sta buf+33
        lda seclen+1
        sta buf+34
        sec                    ; map entries: (seclen - 4) / 2
        lda seclen
        sbc #4
        tax
        lda seclen+1
        sbc #0
        lsr @
        sta buf+36
        txa
        ror @
        sta buf+35
        lsr buf+36             ; EOSFS extents are four bytes, not two
        ror buf+35
        lda #1
        sta buf+37
        lda #0                 ; sequence number 0, as SDX's FORMAT
        sta buf+38
        lda RANDOM
        sta buf+39
        lda #1                 ; sectors 1 (to 3)
        sta s_sec
        lda #0
        sta s_sec+1
        sta s_off
        sta s_off+1
bd10    jsr wrsec
        jmi err
        lda s_sec
        cmp nboot
        bcs bd11
        inc s_sec
        lda s_off
        eor #$80
        sta s_off
        bmi bd10
        inc s_off+1
        bne bd10
; the bitmap
bd11    lda #0
        sta cur
        sta cur+1
        sta cur+2
        sta s_off
        sta s_off+1
        lda nboot
        sta s_sec
        lda #0
        sta s_sec+1
        lda nbmp
        sta cnt
bd12    inc s_sec
        lda #0                 ; one sector of bits
        sta bp
        sta bp+1
bd13    clc                    ; at buf+bp
        lda p_buf
        adc bp
        sta bd_st+1
        lda p_buf+1
        adc bp+1
        sta bd_st+2
        jsr mapbyte
bd_st   sta $FFFF
bd15    clc
        lda cur
        adc #8
        sta cur
        bcc bd16
        inc cur+1
        bne bd16
        inc cur+2
bd16    inc bp
        bne bd17
        inc bp+1
bd17    lda bp
        cmp seclen
        bne bd13
        lda bp+1
        cmp seclen+1
        bne bd13
        jsr wrsec
        jmi err
        dec cnt
        bne bd12
; the main directory and its map
        jsr clrbuf
        lda #$28               ; in use, directory
        sta buf
        lda #44                ; v2 header entry length
        sta buf+3
        lda #4                 ; exact-case root directory name
        sta buf+6
        ldx #3
bd18    lda mainnm,x
        sta buf+7,x
        dex
        bpl bd18
        jsr clk_get
        ldx #5
bd19    lda date,x
        sta buf+38,x
        dex
        bpl bd19
bd19a
        lda dsec
        sta s_sec
        lda dsec+1
        sta s_sec+1
        jsr wrsec
        bmi err
        jsr clrbuf
        lda dsec
        sta buf+4
        lda dsec+1
        sta buf+5
        lda #1
        sta buf+6
bd20    lda msec
        sta s_sec
        lda msec+1
        sta s_sec+1
        jsr wrsec
        bmi err
bd21    clc
        rts
err     sec
        rts

; mapbyte: A = the bitmap byte of sectors cur..cur+7 (bit 7 first, 1 free:
; ffree to last)
mapbyte lda #0
        sta mb_v
        lda cur+2
        bne mb_ret
        ldy #0
mb1     lda cur                ; s = cur + y
        sty mb_y
        clc
        adc mb_y
        sta mb_s
        lda cur+1
        adc #0
        sta mb_s+1
        bcs mb_ret             ; past 65535
        lda mb_s               ; ffree <= s <= last
        cmp ffree
        lda mb_s+1
        sbc ffree+1
        bcc mb2
        lda last
        cmp mb_s
        lda last+1
        sbc mb_s+1
        bcc mb2
        lda bitv,y
        ora mb_v
        sta mb_v
mb2     iny
        cpy #8
        bcc mb1
mb_ret  lda mb_v
        rts

; clrbuf: buf to zeros
clrbuf  lda #0
        tax
cb1     sta buf,x
        sta buf+256,x
        inx
        bne cb1
        rts

; flush: the FMS writes what it holds for the drive (its kd_check)
flush   lda drv
        sta device
        ldy #19
        jmp jkernel

; ---- the physical format ---------------------------------------------------------

; pformat: the menu's density and tracks on unit: the PERCOM block first
; when the drive has one, then the format command; C=1, A = status
pformat lda pc_ok
        beq pf2
        ldx #11                ; tracks, step, sectors, heads-1, density,
pf1     lda pcb,x              ; bytes per sector, $FF
        sta npcb,x
        dex
        bpl pf1
        lda ntrk
        sta npcb
        lda nspt
        sta npcb+3
        lda nspt+1
        sta npcb+2
        lda nhead
        sta npcb+4
        lda g_dens
        beq pf1a
        lda #4                 ; MFM
pf1a    sta npcb+5
        lda seclen+1
        sta npcb+6
        lda seclen
        sta npcb+7
        lda #$FF
        sta npcb+8
        lda #12
        sta s_len
        lda #0
        sta s_len+1
        sta s_sec
        sta s_sec+1
        lda #$80
        sta s_dir
        lda p_npcb
        sta s_buf
        lda p_npcb+1
        sta s_buf+1
        lda #'O'
        jsr sio
        bmi pf_err
pf2     lda seclen             ; the format: the drive answers with a list
        sta s_len              ; of bad sectors
        lda seclen+1
        sta s_len+1
        lda #$40
        sta s_dir
        lda p_buf
        sta s_buf
        lda p_buf+1
        sta s_buf+1
        lda #0
        sta s_sec
        sta s_sec+1
        lda #$B4               ; about three minutes
        sta s_tim
        ldx #'!'
        lda g_dens             ; medium density without PERCOM: '"'
        cmp #1
        bne pf3
        lda pc_ok
        bne pf3
        ldx #'"'
pf3     lda skew               ; High Speed: the XF551's format with its
        beq pf4                ; high speed skew ($A1); Ultra Speed: the
        cmp #1                 ; US Doubler's with a sector order ($66)
        bne pf_us
        ldx #$A1
        bne pf4
pf_us   lda pc_ok
        beq pf4
        lda nspt+1             ; (a real track: up to 64 sectors)
        bne pf4
        lda nspt
        cmp #65
        bcs pf4
        jmp pf_66
pf4     txa
        jsr sio
        bmi pf_err
        clc
        rts
pf_err  sec
        rts

; pf_66: the US Doubler's skewed format: a 128-byte frame, the PERCOM
; block, then the order of a track's sectors: 1 to nspt at every second
; free position (128-byte sectors) or every third (256), for Ultra Speed
; reading. The drive answers with its bad sector list after the
; completion, which SIO does not read (it is a write): a third of a second
; for it to end. (Altirra takes the command but not the order: the gain
; shows on a real drive only.)
pf_66   ldx #127
        lda #0
p66a    sta buf,x
        dex
        bpl p66a
        ldx #11
p66b    lda npcb,x
        sta buf,x
        dex
        bpl p66b
        lda #2
        ldy seclen+1
        beq p66c
        lda #3
p66c    sta sk_k
        lda #0
        sta sk_p
        lda #1
        sta sk_s
p66d    ldx sk_p               ; the first free position from sk_p on
p66e    lda buf+12,x
        beq p66f
        inx
        cpx nspt
        bcc p66e
        ldx #0
        beq p66e
p66f    lda sk_s
        sta buf+12,x
        txa
        clc
        adc sk_k
p66g    cmp nspt
        bcc p66h
        sbc nspt
        jmp p66g
p66h    sta sk_p
        inc sk_s
        lda sk_s
        cmp nspt
        beq p66d
        bcc p66d
        lda #128
        sta s_len
        lda #0
        sta s_len+1
        sta s_sec
        sta s_sec+1
        lda #$80
        sta s_dir
        lda p_buf
        sta s_buf
        lda p_buf+1
        sta s_buf+1
        lda #$B4
        sta s_tim
        lda #$66
        jsr sio
        jmi pf_err
        lda RTCLOK+2
        sta sk_p
p66w    lda RTCLOK+2
        sec
        sbc sk_p
        cmp #20
        bcc p66w
        clc
        rts

; ---- the menu ----------------------------------------------------------------------

; The geometry: g_dens (0-4, d_szl/d_szh), g_trk tracks, g_hd sides (1 or
; 2), g_spt sectors per track. Z picks a standard size (sz_* tables) or
; Advanced, where D, T, H and N set each part. One track is a hard disk
; (or ramdisk, or a disk image of any size): F then builds the file system
; without a physical format.

menu    jsr setdrv
        jsr newdrv
m_show  jsr setgeo
        jsr PRINTF
        dta b($7D),c'EOS Formatter',EOL,EOL
        dta c' U  Unit       D%b:',EOL,0
        dta a(drv)
        jsr PRINTF
        dta c' O  Optimize   %*t',EOL
        dta c' S  Skew       %*t',EOL
        dta c'    Filesystem EOSFS v2',EOL
        dta c' V  Volume     %8s',EOL
        dta c' Z  Size       %*t',EOL,0
        dta a(opt,t_onoff,skew,t_skew,vol,size,t_size)
        lda size
        cmp #nsizes
        bne m_sz
        jsr PRINTF
        dta c' D  Density    %*t',EOL
        dta c' T  Tracks     %b',EOL
        dta c' H  Sides      %b',EOL
        dta c' N  Sec/track  %d',EOL,0
        dta a(g_dens,t_dens,g_trk,g_hd,g_spt)
m_sz    jsr PRINTF
        dta c'    Sectors    %d x %d',EOL,0
        dta a(total,seclen)
        jsr nfree
        jsr PRINTF
        dta c'    Free       %d',EOL,EOL
        dta c' F  Format disk',EOL
        dta c' B  Build directory',EOL
        dta c'ESC Exit',EOL,EOL,0
        dta a(free)
m_key   jsr U_GETKEY
        bpl m_k1
        rts                    ; Break
m_k1    cmp #ESC
        bne m_k2
        rts
m_k2    and #$5F               ; capitals
        ldx #nkeys-1
m_k3    cmp keys,x
        beq m_k4
        dex
        bpl m_k3
        bmi m_key
m_k4    txa
        asl @
        tax
        lda m_jmp+1,x
        pha
        lda m_jmp,x
        pha
        rts

; nfree: free = the free sectors the file system will have (0 when the
; disk is too small)
nfree   jsr layout
        bcc nf1
        lda #0
        sta free
        sta free+1
nf1     rts

k_unit  jsr PRINTF
        dta c'Unit (1-9, A-O)? ',0
        jsr U_GETKEY
        bmi k_u3
        and #$7F
        cmp #'1'
        bcc k_u1
        cmp #'9'+1
        bcs k_u1
        and #$0F
        bne k_u2
k_u1    and #$5F
        cmp #'A'
        bcc k_u3
        cmp #'O'+1
        bcs k_u3
        sbc #'A'-1-1
k_u2    sta drv
        jsr setdrv
        jsr newdrv
k_u3    jmp m_show
k_opt   lda opt
        eor #1
        sta opt
        jmp m_show
k_skew  inc skew
        lda skew
        cmp #3
        bcc k_s1
        lda #0
        sta skew
k_s1    jmp m_show
k_vol   jsr PRINTF
        dta c'Volume name? ',0
        jsr getln
        bmi k_v3
        ldx #0
k_v1    lda lbuf,x
        cmp #EOL
        beq k_v2
        sta vol,x
        inx
        cpx #8
        bcc k_v1
        bcs k_v3
k_v2    cpx #0                 ; RETURN alone: as it was
        beq k_v3
        lda #' '
k_v2a   sta vol,x
        inx
        cpx #8
        bcc k_v2a
k_v3    jmp m_show

; Z: the next standard size, after the last one Advanced
k_size  inc size
        lda size
k_z1    cmp #nsizes+1
        bcc k_z2
        lda #0
        sta size
k_z2    jsr presize
        jmp m_show

; D, T, H, N: Advanced
k_dens  jsr advanced
        inc g_dens
        lda g_dens
        cmp #5
        bcc k_d1
        lda #0
        sta g_dens
k_d1    ldx g_dens             ; its usual sectors per track
        lda d_spt,x
        sta g_spt
        lda #0
        sta g_spt+1
        jmp m_show
k_trk   jsr advanced
        jsr PRINTF
        dta c'Tracks (1-255, 1 = hard disk)? ',0
        jsr getnum
        bcs k_t1
        lda n16+1
        bne k_t1
        lda n16
        beq k_t1
        sta g_trk
k_t1    jmp m_show
k_hd    jsr advanced
        ldx #1
        lda g_hd
        cmp #2
        beq k_h1
        inx
k_h1    stx g_hd
        jmp m_show
k_nspt  jsr advanced
        jsr PRINTF
        dta c'Sectors per track? ',0
        jsr getnum
        bcs k_n1
        lda n16
        ora n16+1
        beq k_n1
        lda n16
        sta g_spt
        lda n16+1
        sta g_spt+1
k_n1    jmp m_show

k_fmt   jsr setgeo
        lda g_trk              ; one track: no physical format
        cmp #1
        beq k_f1
        jsr pformat
        bcs k_err
k_f1    jsr builddir
        bcs k_err
        jmp m_show
k_bld   jsr geo                ; on what the drive holds now
        bcs k_err
        jsr builddir
        bcs k_err
        jsr newdrv
        jmp m_show
k_err   jsr U_ERROR
        jsr PRINTF
        dta c'Press a key',0
        jsr U_GETKEY
        jmp m_show

; advanced: D, T, H and N change the geometry as it is shown
advanced lda #nsizes
        sta size
        rts

; presize: the geometry of standard size `size`
presize ldx size
        cpx #nsizes
        bcs ps_ret
        lda sz_dens,x
        sta g_dens
        lda sz_trk,x
        sta g_trk
        lda sz_hd,x
        sta g_hd
        lda sz_sptl,x
        sta g_spt
        lda sz_spth,x
        sta g_spt+1
ps_ret  rts

; getln: a line into lbuf; N=1 on Break
getln   lda p_lbuf
        ldx p_lbuf+1
        ldy #40
        jmp GETS

; getnum: a decimal number typed (up to 65535) into n16; C=1 when the line
; is empty or not a number
getnum  jsr getln
        bmi gn_no
        lda #0
        sta n16
        sta n16+1
        tax
gn1     lda lbuf,x
        cmp #EOL
        beq gn_end
        sec
        sbc #'0'
        cmp #10
        bcs gn_no
        pha
        lda n16+1              ; n16 = n16 * 10 + digit
        pha
        lda n16
        asl @
        rol n16+1
        asl @
        rol n16+1
        clc
        adc n16
        sta n16
        pla
        adc n16+1
        sta n16+1
        asl n16
        rol n16+1
        pla
        clc
        adc n16
        sta n16
        bcc gn2
        inc n16+1
gn2     inx
        cpx #5
        bcc gn1
        lda lbuf,x
        cmp #EOL
        bne gn_no
gn_end  cpx #0
        beq gn_no
        clc
        rts
gn_no   sec
        rts

; newdrv: what the drive says about itself: the geometry from its PERCOM
; block (one track: a hard disk), else its size; the standard size that
; matches it, else Advanced; the volume name on it
newdrv  jsr geo
        jcs nd_ret
        jsr oldname
        lda seclen+1           ; the density
        ldx #3
        cmp #2
        beq nd1
        ldx #2
        cmp #1
        beq nd1
        ldx #0
        lda pc_ok
        beq nd0
        lda pcb+5              ; MFM 128: medium
        and #4
        beq nd1
        ldx #1
        bne nd1
nd0     lda total+1            ; no PERCOM: 1040 sectors are medium
        cmp #>1040
        bne nd1
        ldx #1
nd1     stx g_dens
        lda pc_ok
        beq nd2
        lda pcb                ; tracks, sides, sectors per track
        sta g_trk
        ldx pcb+4
        inx
        stx g_hd
        lda pcb+3
        sta g_spt
        lda pcb+2
        sta g_spt+1
        jmp nd3
nd2     lda #1                 ; no PERCOM: one side of total / 40 tracks,
        sta g_hd               ; a header's total as one track when it
        lda #40                ; does not divide
        sta g_trk
        ldx #0
nd2a    lda total
        cmp sz_tl,x
        bne nd2b
        lda total+1
        cmp sz_th,x
        bne nd2b
        lda sz_dens,x
        cmp g_dens
        beq nd2c
nd2b    inx
        cpx #nsizes
        bcc nd2a
        lda #1
        sta g_trk
        lda total
        sta g_spt
        lda total+1
        sta g_spt+1
        jmp nd3
nd2c    stx size
        jmp presize
nd3     ldx #0                 ; the standard size it is, else Advanced
nd3a    lda sz_dens,x
        cmp g_dens
        bne nd3b
        lda sz_trk,x
        cmp g_trk
        bne nd3b
        lda sz_hd,x
        cmp g_hd
        bne nd3b
        lda sz_sptl,x
        cmp g_spt
        bne nd3b
        lda sz_spth,x
        cmp g_spt+1
        beq nd4
nd3b    inx
        cpx #nsizes
        bcc nd3a
nd4     stx size
nd_ret  rts

; setgeo: seclen, total, tbyte, nspt, ntrk, nhead from the geometry
setgeo  ldx g_dens
        lda d_szl,x
        sta seclen
        lda d_szh,x
        sta seclen+1
        lda g_spt
        sta nspt
        sta m_a
        lda g_spt+1
        sta nspt+1
        sta m_a+1
        lda g_trk
        sta ntrk
        sta tbyte
        sta m_b
        jsr mul
        lda g_hd
        sta m_b
        sec
        sbc #1
        sta nhead
        beq sg1
        lda tbyte
        ora #$80
        sta tbyte
sg1     jsr mul
        lda m_a
        sta total
        lda m_a+1
        sta total+1
        rts

        icl 'DATEclk.icl'

drv     dta 0
vpos    dta 0
unit    dta 0
quiet   dta 0
newvol  dta 0
opt     dta 0
skew    dta 0
size    dta 0                  ; (size, g_dens, g_trk, g_hd, g_spt: in this order)
g_dens  dta 0
g_trk   dta 0
g_hd    dta 0
g_spt   dta a(0)
n16     dta a(0)
hard    dta 0
pc_ok   dta 0
seclen  dta a(0)
total   dta a(0)
tbyte   dta 0
nspt    dta a(0)
ntrk    dta 0
nhead   dta 0
nboot   dta 0
shift   dta 0
nbmp    dta 0
dsec    dta a(0)
msec    dta a(0)
ffree   dta a(0)
last    dta a(0)
free    dta a(0)
cnt     dta 0
bp      dta a(0)
cur     dta 0,0,0
t24     dta 0,0,0
mb_v    dta 0
mb_y    dta 0
mb_s    dta a(0)
m_a     dta a(0)
m_b     dta 0
m_r     dta a(0)
s_sec   dta a(0)
s_len   dta a(0)
s_buf   dta a(0)
s_off   dta a(0)
s_dir   dta 0
s_tim   dta 7
vol     dta c'        '
pcb     :12 dta 0
npcb    :12 dta 0
sk_k    dta 0                  ; pf_66: the interleave, a position, a sector
sk_p    dta 0
sk_s    dta 0
bitv    dta b($80,$40,$20,$10,$08,$04,$02,$01)
szcode  dta b($80,$00,$01)
mainnm  dta c'main'
boot512 dta b($00,$01,$00,$04,$E0,$07,$4C,$40,$04,$00,$00)
d_szl   dta b(128,128,0,0,0)
d_szh   dta b(0,0,1,2,2)
d_spt   dta b(18,26,18,9,18)
; the standard sizes: 90K 127K 180K 360K 720K 1.44M 16M
sz_dens dta b(0,1,2,2,3,4,2)
sz_trk  dta b(40,40,40,40,80,80,1)
sz_hd   dta b(1,1,1,2,2,2,1)
sz_sptl dta l(18,26,18,18,9,18,65535)
sz_spth dta h(18,26,18,18,9,18,65535)
sz_tl   dta l(720,1040,720,1440,1440,2880,65535)
sz_th   dta h(720,1040,720,1440,1440,2880,65535)
nsizes  equ 7
keys    dta c'UOSVZDTHNFB'
nkeys   equ 11
m_jmp   dta a(k_unit-1,k_opt-1,k_skew-1,k_vol-1,k_size-1,k_dens-1)
        dta a(k_trk-1,k_hd-1,k_nspt-1,k_fmt-1,k_bld-1)
t_onoff dta c'Off',EOL,c'On',EOL,0
t_skew  dta c'Standard',EOL,c'High Speed',EOL,c'Ultra Speed',EOL,0
t_dens  dta c'Single',EOL,c'Medium',EOL,c'Double',EOL,c'DD 512',EOL
        dta c'High',EOL,0
t_size  dta c'90K (SD)',EOL,c'127K (ED)',EOL,c'180K (DD)',EOL,c'360K (DD DS)',EOL
        dta c'720K (DD 512)',EOL,c'1.44M (HD 512)',EOL,c'16M (hard disk)',EOL
        dta c'Advanced',EOL,0
p_buf   dta a(buf)
p_pcb   dta a(pcb)
p_npcb  dta a(npcb)
p_lbuf  dta a(lbuf)
lbuf    :42 dta 0
xbooter
        .local ldrcx
EOSFS_BOOT equ 1
        icl 'FORMATboot.icl'
        .endl
buf     :512 dta 0

        blk update address
        blk update symbols
