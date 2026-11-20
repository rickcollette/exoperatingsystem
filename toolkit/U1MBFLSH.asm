; EOS Toolkit: U1MBFLSH, write an image into the Ultimate 1MB's SDX area
;   U1MBFLSH [d:][path]EOS_U1MB.ROM
; The image (exactly 320 KiB, forty 8 KiB banks with one common reset tail
; and a cartridge trailer, as make u1mb builds it) is read into 20 free
; extended memory banks first, while the DOS still works. After a Y the
; flash is changed with the OS ROM switched out, interrupts and NMIs off and
; everything this program needs in main memory below $4000:
;   - the chip's ID (autoselect): AMD/AMIC/Bright/Hynix/Macronix 29F040
;     (64 KiB sectors) or SST 39SF040 (4 KiB sectors); any other answer,
;     or none (flash writes protected, SDX module off), stops it before
;     anything is erased;
;   - sector erase of $00000-$4FFFF only (never chip erase): the U1MB BIOS,
;     BASIC and OS banks ($50000-$7FFFF) are never addressed;
;   - each byte programmed through the SDX window ($A000, bank in $D5E0),
;     each 8 KiB bank compared with the image;
;   - then a cold start, into the new image.
; A failure stops with a message on the screen; the U1MB BIOS stays as it
; was, so its setup still starts after a reset.
; Uses only SpartaDOS X calls (it also runs under SDX). Needs 20 free
; extended banks (NBANKS): start the DOS without a RAM disk.
U_GETPAR smb 'U_GETPAR'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
GETS     smb 'GETS'
COMTAB   smb 'COMTAB'

V_setme  equ $07F1             ; memory index A selected (kept on a stack)
V_popme  equ $07F4
mode     equ $0778
scan     equ $0779
dentry   equ $0789
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
PORTB    equ $D301
NMIEN    equ $D40E
SDXREG   equ $D5E0             ; U1MB SDX bank (bits 0-5), bit 7: SDX off
SAVMSC   equ $58
COLDSV   equ $E477
EOL      equ $9B
NEB      equ 20                ; extended banks for the image (16 KiB each)
NFB      equ 40                ; 8 KiB flash banks

ptr      equ $80               ; flash address
src      equ $82               ; extended memory / buffer address
scr      equ $84               ; the screen's status line
cnt      equ $86               ; (3) polling time-out

        blk reloc main
start   jsr U_GETPAR
        bne s1
        jmp usage
s1      jsr u1det              ; an Ultimate 1MB?
        bcc s2
        jsr PRINTF
        dta c'No Ultimate 1MB found',EOL,0
        rts
s2      lda p_prog_end+1         ; all of this program below the bank window
        cmp #$40
        bcc s3
        jsr PRINTF
        dta c'MEMLO too high: the program must end below $4000',EOL,0
        rts
s3      lda COMTAB+$1D         ; NBANKS: the free extended banks
        sta nbanks
        cmp #NEB
        bcs s4
        jsr PRINTF
        dta c'Needs %b free extended banks, %b free:',EOL
        dta c'start without a RAM disk',EOL,0
        dta a(neb_v,nbanks)
        rts
s4      ldx #0                 ; the PORTB value of each (indices 4..)
s5      txa
        clc
        adc #4
        jsr V_setme
        lda PORTB
        sta pbtab,x
        jsr V_popme
        inx
        cpx #NEB
        bcc s5

; ---- the image into extended memory ------------------------------------------
        lda #4
        sta mode
        lda #0
        sta scan
        jsr FOPEN
        lda dentry+3           ; exactly $050000 bytes (3 bytes, low first)
        ora dentry+4
        bne badsize
        lda dentry+5
        cmp #5
        beq rd0
badsize jsr FCLOSE
        jsr PRINTF
        dta c'The image must be exactly 320 KiB',EOL,0
        rts
rd0     lda #0
        sta eb
rd1     lda #0
        sta kb
rd2     lda p_buf              ; 1 KiB at a time
        sta addpos
        lda p_buf+1
        sta addpos+1
        lda #0
        sta bytbuf
        sta memreix
        lda #4
        sta bytbuf+1
        jsr FREAD
        lda bytbuf
        bne short
        lda bytbuf+1
        cmp #4
        bne short
        lda kb                 ; to $4000 + kb*1K in bank eb
        asl @
        asl @
        adc #$40
        sta src+1
        lda #0
        sta src
        lda p_buf
        sta ptr
        lda p_buf+1
        sta ptr+1
        php
        sei
        lda PORTB
        pha
        ldx eb
        lda pbtab,x
        sta PORTB
        ldx #4
        ldy #0
rd3     lda (ptr),y
        sta (src),y
        iny
        bne rd3
        inc ptr+1
        inc src+1
        dex
        bne rd3
        pla
        sta PORTB
        plp
        inc kb
        lda kb
        cmp #16
        bcc rd2
        inc eb
        lda eb
        cmp #NEB
        bcc rd1
        jsr FCLOSE
        jmp chk
short   jsr FCLOSE
        jsr PRINTF
        dta c'Read error',EOL,0
        rts

; ---- the image's checks: one reset tail in every bank, a cartridge -----------
chk     php
        sei
        lda PORTB
        pha
        lda pbtab              ; bank 0's tail
        sta PORTB
        ldx #15
ck1     lda $5FF0,x
        sta tail,x
        dex
        bpl ck1
        lda #0
        sta fb
ck2     lda fb
        lsr @
        tax
        lda pbtab,x
        sta PORTB
        lda fb                 ; $5FF0 or $7FF0
        and #1
        asl @
        asl @
        asl @
        asl @
        asl @
        ora #$5F
        sta src+1
        lda #$F0
        sta src
        ldy #15
ck3     lda (src),y
        cmp tail,y
        bne ck_bad
        dey
        bpl ck3
        inc fb
        lda fb
        cmp #NFB
        bcc ck2
        pla
        sta PORTB
        plp
        lda tail+12            ; cartridge present, run address $A000-$BFFF
        bne ck_bad2
        lda tail+11
        cmp #$A0
        bcc ck_bad2
        cmp #$C0
        bcs ck_bad2
        jmp ask
ck_bad  pla
        sta PORTB
        plp
ck_bad2 jsr PRINTF
        dta c'Not an EOS U1MB slot image (bank tails differ)',EOL,0
        rts

; ---- the question ------------------------------------------------------------
ask     jsr PRINTF
        dta c'Ultimate 1MB SDX area $00000-$4FFFF',EOL
        dta c'(320 KiB) is erased and written. The',EOL
        dta c'U1MB BIOS, BASIC and OS ($50000-',EOL
        dta c'$7FFFF) are not touched. Do not reset',EOL
        dta c'or switch off until the computer',EOL
        dta c'restarts. Write (Y/N)? ',0
        lda p_ans
        ldx p_ans+1
        ldy #8
        jsr GETS
        php
        jsr PRINTF
        dta EOL,0
        plp
        bmi no
        ldx #0
as1     lda ans,x
        cmp #' '
        bne as2
        inx
        cpx #8
        bcc as1
as2     and #$DF
        cmp #'Y'
        beq flash
no      jsr PRINTF
        dta c'Not written.',EOL,0
        rts

; ==== from here on: no OS, no interrupts, no DOS ==============================
flash   sei
        lda #0
        sta NMIEN
        sta src                ; the ROM's font to the RAM under it: ANTIC
        lda #$E0               ; reads $E000-$E3FF from there meanwhile
        sta src+1
        ldx #4
        ldy #0
fn1     lda #$FF
        sta PORTB
        lda (src),y
        pha
        lda #$FE
        sta PORTB
        pla
        sta (src),y
        iny
        bne fn1
        inc src+1
        dex
        bne fn1
        lda #$FE               ; OS ROM, BASIC, self test off, no bank
        sta PORTB
        lda SAVMSC             ; the status line: the screen's row 23
        clc
        adc #<(23*40)
        sta scr
        lda SAVMSC+1
        adc #>(23*40)
        sta scr+1
        ldx p_m_id
        ldy p_m_id+1
        jsr show

        lda #0                 ; the chip's ID, against what bank 0 holds
        sta SDXREG
        lda $A000
        sta norm
        lda $A001
        sta norm+1
        jsr unlock
        lda #$90
        sta $B555
        lda #0
        sta SDXREG
        lda $A000
        sta mid
        lda $A001
        sta did
        jsr unlock             ; back to reading
        lda #$F0
        sta $B555
        lda #0
        sta SDXREG
        lda #$F0
        sta $A000
        lda mid                ; no answer: the data itself came back
        cmp norm
        bne id1
        lda did
        cmp norm+1
        beq unknown
id1     ldx #0
id2     lda chips,x
        beq unknown
        cmp mid
        bne id3
        lda chips+1,x
        cmp did
        beq id4
id3     inx
        inx
        inx
        bne id2
id4     lda chips+2,x
        sta stype
        lda $A000              ; reading again: bank 0 as it was
        cmp norm
        bne unknown
        jmp erase
unknown ldx p_m_unk
        ldy p_m_unk+1
        jmp halt

; ---- erase: 5 sectors of 64 KiB or 80 of 4 KiB from $00000 --------------------
erase   ldx p_m_era
        ldy p_m_era+1
        jsr show
        lda #0
        sta sect
er1     jsr unlock
        lda #$80
        sta $B555
        jsr unlock
        lda stype              ; the sector's address
        bne er2
        lda sect               ; 64 KiB: bank sect*8, $A000
        asl @
        asl @
        asl @
        sta SDXREG
        lda #$A0
        bne er3
er2     lda sect               ; 4 KiB: bank sect/2, $A000 or $B000
        lsr @
        sta SDXREG
        lda #$A0
        bcc er3
        lda #$B0
er3     sta ptr+1
        lda #0
        sta ptr
        lda #$30
        ldy #0
        sta (ptr),y
        jsr wait
        bcs f_era
        inc sect
        lda sect
        ldx stype
        cmp nsect,x
        bcc er1
        lda #0                 ; all of it reads $FF now?
        sta fb
er4     lda fb
        sta SDXREG
        lda #$A0
        sta ptr+1
        ldy #0
        sty ptr
er5     lda (ptr),y
        cmp #$FF
        bne f_era
        iny
        bne er5
        inc ptr+1
        lda ptr+1
        cmp #$C0
        bcc er5
        inc fb
        lda fb
        cmp #NFB
        bcc er4
        jmp prog
f_era   ldx p_m_fera
        ldy p_m_fera+1
        jmp halt

; ---- program and compare, 8 KiB bank by bank ----------------------------------
prog    lda #0
        sta fb
pg1     lda fb                 ; "Bank nn" on the status line
        jsr showbank
        lda #0
        sta pg
pg2     jsr fetch              ; 256 bytes of the image to pbuf
        lda pg
        clc
        adc #$A0
        sta ptr+1
        lda #0
        sta ptr
        sta idx
pg3     ldy idx
        lda pbuf,y
        cmp #$FF               ; (erased already)
        beq pg4
        sta dat
        jsr unlock
        lda #$A0
        sta $B555
        lda fb
        sta SDXREG
        ldy idx
        lda dat
        sta (ptr),y
        jsr wait
        bcs f_prg
pg4     inc idx
        bne pg3
        inc pg
        lda pg
        cmp #32
        bcc pg2
        lda #0                 ; compare the bank
        sta pg
pg5     jsr fetch
        lda fb
        sta SDXREG
        lda pg
        clc
        adc #$A0
        sta ptr+1
        ldy #0
        sty ptr
pg6     lda (ptr),y
        cmp pbuf,y
        bne f_ver
        iny
        bne pg6
        inc pg
        lda pg
        cmp #32
        bcc pg5
        inc fb
        lda fb
        cmp #NFB
        jcc pg1
        lda #0                 ; done: bank 0, the OS back, a cold start
        sta SDXREG
        lda #$FF
        sta PORTB
        jmp COLDSV
f_prg   ldx p_m_fprg
        ldy p_m_fprg+1
        jmp halt
f_ver   ldx p_m_fver
        ldy p_m_fver+1
        jmp halt

* fetch: page pg of flash bank fb from extended memory to pbuf (the OS ROM
* stays off: the bank's PORTB value without bit 0)
fetch   lda fb
        lsr @
        tax
        lda pbtab,x
        and #$FE
        sta PORTB
        lda fb
        and #1
        asl @
        asl @
        asl @
        asl @
        asl @
        ora #$40
        adc pg                 ; (C=0)
        sta src+1
        lda #0
        sta src
        ldy #0
fe1     lda (src),y
        sta pbuf,y
        iny
        bne fe1
        lda #$FE
        sta PORTB
        rts

* unlock: $5555 <- $AA, $2AAA <- $55 (banks 2 and 1); bank 2 stays selected
* for the command byte at $B555
unlock  lda #2
        sta SDXREG
        lda #$AA
        sta $B555
        lda #1
        sta SDXREG
        lda #$55
        sta $AAAA
        lda #2
        sta SDXREG
        rts

* wait: until the operation at (ptr),Y ends (DQ6 stops toggling); C=1 on a
* time-out (about a minute) or when the chip reports a failure (DQ5). The
* erased area and each bank are compared afterwards.
wait    lda #0
        sta cnt
        sta cnt+1
        lda #64
        sta cnt+2
wa1     lda (ptr),y
        sta t1
        lda (ptr),y
        eor t1
        and #$40
        beq wa_end
        lda (ptr),y            ; DQ5: the chip gave up?
        and #$20
        beq wa2
        lda (ptr),y
        sta t1
        lda (ptr),y
        eor t1
        and #$40
        beq wa_end
        bne wa_no
wa2     dec cnt
        bne wa1
        dec cnt+1
        bne wa1
        dec cnt+2
        bne wa1
wa_no   sec
        rts
wa_end  clc
        rts

* show: the status line (X/Y: ATASCII, 0 ended) on the screen's row 23
show    stx src
        sty src+1
        ldy #39
        lda #0
sh0     sta (scr),y
        dey
        bpl sh0
        ldy #0
sh1     lda (src),y
        beq sh_x
        jsr internal
        sta (scr),y
        iny
        cpy #40
        bcc sh1
sh_x    rts
internal cmp #$20
        bcs in1
        adc #$40
        rts
in1     cmp #$60
        bcs in2
        sbc #$20-1             ; (C=0: -$20)
        clc
in2     rts

* showbank: "Writing bank nn of 40" with nn = A+1
showbank clc
        adc #1
        ldx #'0'-1
sb1     inx
        sec
        sbc #10
        bcs sb1
        adc #'0'+10
        stx m_bank+13
        sta m_bank+14
        ldx p_m_bank
        ldy p_m_bank+1
        jmp show

* halt: the message X/Y on the screen and the next line; wait for RESET
halt    jsr show
        lda #0
        sta SDXREG
        lda scr
        sec
        sbc #40
        sta scr
        bcs ha1
        dec scr+1
ha1     ldx p_m_rst
        ldy p_m_rst+1
        jsr show
ha2     jmp ha2

* u1det: C=0 when an Ultimate 1MB answers at $D380-$D3FF (unused registers
* read $FF where the PIA's mirrors would be, $D383 has bit 7 only)
u1det   lda $D382
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

usage   jsr PRINTF
        dta c'Use: U1MBFLSH [d:][path]EOS_U1MB.ROM',EOL
        dta c'Writes the 320 KiB image into the',EOL
        dta c'Ultimate 1MB SDX area, then restarts.',EOL,0
        rts

; manufacturer, device, sector type (0: 64 KiB, 1: 4 KiB); 0 ends
chips   dta $01,$A4,0          ; AMD Am29F040(B)
        dta $37,$86,0          ; AMIC A29040
        dta $AD,$40,0          ; Bright BM29F040
        dta $AD,$A4,0          ; Hynix HY29F040A
        dta $C2,$A4,0          ; Macronix MX29F040
        dta $BF,$B7,1          ; SST 39SF040
        dta 0
nsect   dta 5,80               ; sectors in $00000-$4FFFF
neb_v   dta NEB
m_id    dta c'U1MBFLSH: reading the flash chip ID',0
m_unk   dta c'Unknown or protected flash: not written',0
m_era   dta c'U1MBFLSH: erasing $00000-$4FFFF',0
m_bank  dta c'Writing bank 00 of 40',0
m_fera  dta c'ERASE FAILED: SDX area not usable',0
m_fprg  dta c'WRITE FAILED: SDX area not usable',0
m_fver  dta c'VERIFY FAILED: SDX area not usable',0
m_rst   dta c'U1MB BIOS kept. Press RESET.',0
nbanks  dta 0
eb      dta 0
kb      dta 0
fb      dta 0
pg      dta 0
idx     dta 0
dat     dta 0
sect    dta 0
stype   dta 0
mid     dta 0
did     dta 0
t1      dta 0
norm    dta 0,0
ans     :8 dta 0
tail    :16 dta 0
pbtab   :NEB dta 0
pbuf    :256 dta 0
buf     :1024 dta 0
prog_end

p_ans     dta a(ans)
p_buf     dta a(buf)
p_m_bank  dta a(m_bank)
p_m_era   dta a(m_era)
p_m_fera  dta a(m_fera)
p_m_fprg  dta a(m_fprg)
p_m_fver  dta a(m_fver)
p_m_id    dta a(m_id)
p_m_rst   dta a(m_rst)
p_m_unk   dta a(m_unk)
p_prog_end dta a(prog_end)

        blk update address
        blk update symbols
