* EOS (Extendable Operating System): bank 8, the CAR: device (C5)
*
* SDX keeps its external commands in the cartridge as the CAR: device;
* EOS keeps its own there (eos/carcmd, written for EOS). The files are
* read-only and live in the banks from BK_CARD on, CARDLEN bytes in each
* (the bank's tail follows), packed by tools/mkcarfs.py:
*   bank BK_CARD, offset 0: 'EOSC', the number of files (word), then 24
*   bytes per file: status, offset, length, a length plus 16 exact name bytes,
*   and the bank of the first byte. The size remains 24 bytes, but no native
*   code or storage uses an 8.3 record.
* A file's bytes run on from bank to bank. k_bcopy (kernel) copies them
* out, because this bank and the file's are both at $A000.

        icl 'equ.icl'
        icl 'kernel.icl'

        opt h-f+

E_OK    equ 1
E_BADH  equ 134
E_RDONLY equ 135
E_EOF   equ 136
E_NOFUNC equ 146
E_PATH  equ 150
E_TOOMANY equ 161
E_RANGE equ 166
E_NOTFOUND equ 170

zp_s    equ $43                ; k_bcopy: from
zp_d    equ $45                ; and to

ENTLEN  equ 24

        org CARTLO
        jmp car_entry          ; $A000 from the kernel (kd_car)

car_entry cpy #22
        bcs ca_nofn
        cld
        lda car_hi,y
        pha
        lda car_lo,y
        pha
        rts
ca_nofn  lda #E_NOFUNC
        rts
ca_ro    lda #E_RDONLY          ; nothing is written to CAR:
        rts
ca_ok    lda #E_OK
        rts
* 0 read 1 write 2 pos 3 gtpos 4 gtlen 5 - 6 next 7 close 8 initz 9 open
* 10 first 11 rename 12 delete 13 setatr 14 credir 15 deldir 16 chdir
* 17 cwd 18 boot 19 check 20 chvol 21 path
car_lo  dta l(ca_read-1,ca_ro-1,ca_pos-1,ca_gtpos-1,ca_gtlen-1,ca_nofn-1,ca_next-1)
        dta l(ca_close-1,ca_initz-1,ca_open-1,ca_first-1,ca_ro-1,ca_ro-1,ca_ro-1)
        dta l(ca_ro-1,ca_ro-1,ca_chdir-1,ca_cwd-1,ca_ro-1,ca_check-1,ca_ro-1,ca_nofn-1)
car_hi  dta h(ca_read-1,ca_ro-1,ca_pos-1,ca_gtpos-1,ca_gtlen-1,ca_nofn-1,ca_next-1)
        dta h(ca_close-1,ca_initz-1,ca_open-1,ca_first-1,ca_ro-1,ca_ro-1,ca_ro-1)
        dta h(ca_ro-1,ca_ro-1,ca_chdir-1,ca_cwd-1,ca_ro-1,ca_check-1,ca_ro-1,ca_nofn-1)

* ---- the slots of open files ------------------------------------------------
* slot: X = the slot of file_id; C=1, A = 134 when it has none
slot    ldx #NCAR-1
sl1     lda cr_hnd,x
        cmp file_id
        beq sl_ok
        dex
        bpl sl1
        lda #E_BADH
        sec
        rts
sl_ok   clc
        rts
* newslot: a free slot and a free kernel handle (file_id, as the FMS's
* new_fcb chooses it): X; C=1, A = 161 when there is none
newslot ldx #NCAR-1
ns1     lda cr_hnd,x
        cmp #$FF
        beq ns2
        dex
        bpl ns1
ns_no   lda #E_TOOMANY
        sec
        rts
ns2     ldy #0
ns3     lda dev_index,y
        cmp #$FF
        beq ns4
        iny
        cpy #16
        bcc ns3
        bcs ns_no
ns4     sty file_id
        tya
        sta cr_hnd,x
        clc
        rts

* ---- 8 initz, 7 close ---------------------------------------------------------
ca_initz ldx #NCAR-1
        lda #$FF
ci1     sta cr_hnd,x
        dex
        bpl ci1
        rts
ca_close jsr slot
        bcs cc_ret
        lda #$FF
        sta cr_hnd,x
        lda #E_OK
cc_ret  rts

* ---- the directory ------------------------------------------------------------
* entry: file cr_i's 24 bytes to cr_ent; C=1 when there is no such file.
* The directory starts at bank BK_CARD, offset 6.
entry   lda cr_i+1             ; past the count?
        cmp cr_cnt+1
        bcc en1
        bne en_no
        lda cr_i
        cmp cr_cnt
        bcs en_no
en1     lda cr_i               ; offset 6 + 24 * i (within the first bank)
        sta cr_t
        lda cr_i+1
        sta cr_t+1
        asl cr_t               ; * 8
        rol cr_t+1
        asl cr_t
        rol cr_t+1
        asl cr_t
        rol cr_t+1
        lda cr_t               ; * 3
        ldx cr_t+1
        asl cr_t
        rol cr_t+1
        clc
        adc cr_t
        sta cr_t
        txa
        adc cr_t+1
        sta cr_t+1
        clc
        lda cr_t
        adc #<(CARTLO+6)
        sta zp_s
        lda cr_t+1
        adc #>(CARTLO+6)
        sta zp_s+1
        lda #<cr_ent
        sta zp_d
        lda #>cr_ent
        sta zp_d+1
        lda #ENTLEN
        sta bc_n
        lda #BK_CARD
        sta bc_bank
        lda #0
        sta bc_mx
        jsr k_bcopy
        clc
        rts
en_no   sec
        rts
* count: cr_cnt = the number of files ('EOSC' at the start, else none)
count   lda #<CARTLO
        sta zp_s
        lda #>CARTLO
        sta zp_s+1
        lda #<cr_ent
        sta zp_d
        lda #>cr_ent
        sta zp_d+1
        lda #6
        sta bc_n
        lda #BK_CARD
        sta bc_bank
        lda #0
        sta bc_mx
        jsr k_bcopy
        lda #0
        sta cr_cnt
        sta cr_cnt+1
        ldx #3
co1     lda cr_ent,x
        cmp eosc,x
        bne co2
        dex
        bpl co1
        lda cr_ent+4
        sta cr_cnt
        lda cr_ent+5
        sta cr_cnt+1
co2     rts
eosc    dta c'EOSC'

* match: exact length-tagged CAR name against the NUL glob in cr_spat.
match   ldx #0
        ldy #0
        lda #$FF
        sta cr_t               ; no star retry point
mt1     lda cr_spat,x
        beq mt_end
        cmp #'*'
        beq mt_star
        cpy cr_ent+6
        bcs mt_retry
        cmp #'?'
        beq mt_take
        cmp cr_ent+7,y
        bne mt_retry
mt_take inx
        iny
        bne mt1
mt_star inx
        stx cr_t
        sty cr_t+1
        jmp mt1
mt_retry lda cr_t
        cmp #$FF
        beq mt_no
        ldy cr_t+1
        cpy cr_ent+6
        bcs mt_no
        iny
        sty cr_t+1
        ldx cr_t
        jmp mt1
mt_end  cpy cr_ent+6
        bne mt_retry
        clc
        rts
mt_no   sec
        rts

* path: only the main directory (an empty path, or / alone)
* C=1, A = 150 for another
ca_path  lda path
        beq pt_ok
        cmp #'/'
        bne pt_no
pt1     lda path+1
        beq pt_ok
pt_no   lda #E_PATH
        sec
        rts
pt_ok   clc
        rts

* ---- 9 open: reading only ------------------------------------------------------
ca_open  lda mode               ; ($14 as $04: the file's entry in dentry,
        and #$0F               ; which XVER reads for the cartridge's date)
        cmp #$04
        beq co_r
        and #$08
        jne ca_ro
        jmp ca_nofn
co_r    jsr ca_path
        bcs co_ret
        jsr count
        jsr setpat
        bcs co_nf
        lda #0
        sta cr_i
        sta cr_i+1
co4     jsr entry
        bcs co_nf
        jsr match
        bcc co5
        inc cr_i
        bne co4
        inc cr_i+1
        bne co4
co_nf   lda #E_NOTFOUND
co_ret  rts
co5     jsr newslot
        bcs co_ret
        lda cr_ent+23          ; the start, the length, at its first byte
        sta cr_bk,x
        sta cr_sbk,x
        lda cr_ent+1
        sta cr_offl,x
        sta cr_soffl,x
        lda cr_ent+2
        sta cr_offh,x
        sta cr_soffh,x
        lda cr_ent+3
        sta cr_len0,x
        lda cr_ent+4
        sta cr_len1,x
        lda cr_ent+5
        sta cr_len2,x
        lda #0
        sta cr_pos0,x
        sta cr_pos1,x
        sta cr_pos2,x
        jsr ent_native
        lda #E_OK
        rts

* ---- 0 read: bytbuf bytes to addpos (memory memreix) ----------------------------
ca_read  jsr slot
        bcs cr_ret0
        stx cr_x
        lda memreix            ; the caller's memory: its PORTB, the ROM off
        beq rd0
        jsr k_tconv
        and #$FE
rd0     sta bc_mx
        lda addpos
        sta zp_d
        lda addpos+1
        sta zp_d+1
        lda bytbuf
        sta cr_want
        lda bytbuf+1
        sta cr_want+1
        lda #0
        sta bytbuf
        sta bytbuf+1
rd1     lda cr_want
        ora cr_want+1
        bne rd2
        lda #E_OK
cr_ret0 rts
rd2     ldx cr_x               ; the chunk: at most 255, the rest of the
        lda #255               ; file, the rest of the bank, the rest wanted
        sta cr_n
        sec                    ; the rest of the file
        lda cr_len0,x
        sbc cr_pos0,x
        sta cr_t
        lda cr_len1,x
        sbc cr_pos1,x
        sta cr_t+1
        lda cr_len2,x
        sbc cr_pos2,x
        bne rd3
        lda cr_t+1
        bne rd3
        lda cr_t
        bne rd2a
        lda #E_EOF             ; the end (what was read is in bytbuf)
        rts
rd2a    cmp cr_n
        bcs rd3
        sta cr_n
rd3     sec                    ; the rest of the bank
        lda #<CARDLEN
        sbc cr_offl,x
        sta cr_t
        lda #>CARDLEN
        sbc cr_offh,x
        bne rd4
        lda cr_t
        cmp cr_n
        bcs rd4
        sta cr_n
rd4     lda cr_want+1          ; the rest wanted
        bne rd5
        lda cr_want
        cmp cr_n
        bcs rd5
        sta cr_n
rd5     clc                    ; copy
        lda cr_offl,x
        adc #<CARTLO
        sta zp_s
        lda cr_offh,x
        adc #>CARTLO
        sta zp_s+1
        lda cr_bk,x
        sta bc_bank
        lda cr_n
        sta bc_n
        jsr k_bcopy
        ldx cr_x               ; on: the place in the file and in the banks
        lda cr_n
        jsr advance
        clc                    ; and the caller's side
        lda zp_d
        adc cr_n
        sta zp_d
        bcc rd6
        inc zp_d+1
rd6     clc
        lda bytbuf
        adc cr_n
        sta bytbuf
        bcc rd7
        inc bytbuf+1
rd7     sec
        lda cr_want
        sbc cr_n
        sta cr_want
        bcs rd8
        dec cr_want+1
rd8     jmp rd1

* advance: slot X on by A bytes (position, bank and offset)
advance pha
        clc
        adc cr_pos0,x
        sta cr_pos0,x
        bcc av1
        inc cr_pos1,x
        bne av1
        inc cr_pos2,x
av1     pla
        clc
        adc cr_offl,x
        sta cr_offl,x
        bcc av2
        inc cr_offh,x
av2     lda cr_offh,x          ; the bank's end: the next bank
        cmp #>CARDLEN
        bcc av3
        bne av2a
        lda cr_offl,x
        cmp #<CARDLEN
        bcc av3
av2a    sec
        lda cr_offl,x
        sbc #<CARDLEN
        sta cr_offl,x
        lda cr_offh,x
        sbc #>CARDLEN
        sta cr_offh,x
        inc cr_bk,x
        jmp av2
av3     rts

* ---- 2 pos, 3 gtpos, 4 gtlen ----------------------------------------------------
ca_gtpos jsr slot
        bcs gp_ret
        lda cr_pos0,x
        sta addpos
        lda cr_pos1,x
        sta addpos+1
        lda cr_pos2,x
        sta addpos+2
        lda #E_OK
gp_ret  rts
ca_gtlen jsr slot
        bcs gp_ret
        lda cr_len0,x
        sta addpos
        lda cr_len1,x
        sta addpos+1
        lda cr_len2,x
        sta addpos+2
        lda #E_OK
        rts
* pos: from the start again, then on by addpos (at most the length)
ca_pos   jsr slot
        bcs gp_ret
        stx cr_x
        lda cr_len0,x
        cmp addpos
        lda cr_len1,x
        sbc addpos+1
        lda cr_len2,x
        sbc addpos+2
        bcs ps0
        lda #E_RANGE
        rts
ps0     jsr back               ; the file's start
        lda addpos             ; then on by addpos, 255 at a time
        sta cr_t
        lda addpos+1
        sta cr_t+1
        lda addpos+2
        sta cr_t+2
ps1     ldx cr_x
        lda cr_t+2
        ora cr_t+1
        bne ps2
        lda cr_t
        beq ps3
        jsr advance
        lda #E_OK
        rts
ps2     lda #255
        jsr advance
        sec
        lda cr_t
        sbc #255
        sta cr_t
        bcs ps1
        lda cr_t+1
        sbc #0
        sta cr_t+1
        bcs ps1
        dec cr_t+2
        jmp ps1
ps3     lda #E_OK
        rts
* back: slot cr_x to its file's start, position 0
back    ldx cr_x
        lda cr_sbk,x
        sta cr_bk,x
        lda cr_soffl,x
        sta cr_offl,x
        lda cr_soffh,x
        sta cr_offh,x
        lda #0
        sta cr_pos0,x
        sta cr_pos1,x
        sta cr_pos2,x
        rts

* ---- 10 first, 6 next: the directory, entry by entry into dentry --------------
ca_first jsr ca_path
        bcs cf_ret
        ldx #10                ; the directory's name for listings: MAIN
cf0     lda mainnm,x
        sta dir_name,x
        dex
        bpl cf0
        jsr count
        jsr newslot
        bcs cf_ret
        stx cr_x
        jsr setpat             ; preserve the exact native glob
        bcs cf_ret
cf4     lda #0                 ; the next file to look at
        ldx cr_x
        sta cr_pos0,x
        sta cr_pos1,x
        lda #$FF               ; a search, not a file
        sta cr_len2,x
        jmp nx_scan
cf_ret  rts

* setpat: exact native name/glob to the one bounded search buffer. A blank
* pattern means all entries. C=1 only when it exceeds CAR's 16-byte limit.
setpat  ldx #0
sp0     lda name,x
        beq sp_end
        cpx #16
        bcs sp_bad
        sta cr_spat,x
        inx
        bne sp0
sp_end  cpx #0
        bne sp_term
        lda #'*'
        sta cr_spat
        inx
sp_term lda #0
        sta cr_spat,x
        clc
        rts
sp_bad  sec
        rts
ca_next  jsr slot
        bcs cf_ret
        stx cr_x
nx_scan jsr count
        ldx cr_x
        lda cr_pos0,x
        sta cr_i
        lda cr_pos1,x
        sta cr_i+1
nx1     jsr entry
        bcs nx_eof
        inc cr_i
        bne nx2
        inc cr_i+1
nx2     jsr match
        bcs nx1
        ldx cr_x
        lda cr_i
        sta cr_pos0,x
        lda cr_i+1
        sta cr_pos1,x
        jsr ent_native
        lda #E_OK
        rts
nx_eof  lda #E_EOF
        rts

* ent_native: expose the compact CAR record as an EOSFS-shaped record.
ent_native ldx #43
        lda #0
cv0     sta dentry,x
        dex
        bpl cv0
        ldx #22
cv1     lda cr_ent,x
        sta dentry,x
        dex
        bpl cv1
        rts

* ---- 16 chdir, 17 cwd, 19 check -------------------------------------------------
ca_chdir jsr ca_path
        bcs ch_ret
        lda name               ; the main directory only
        cmp #' '
        beq ch_ok
        lda #E_PATH
        rts
ch_ok   lda #E_OK
ch_ret  rts
ca_cwd   lda #0
        sta path
        lda #E_OK
        rts
* check: GETDFREE's information as SDX gives it for its CAR: (8192-byte
* sectors: code 5; the cartridge's 128 of them, none free), with EOS's
* own volume name
ca_check ldx #16
        lda #0
ck1     sta path,x
        dex
        bpl ck1
        lda #$05
        sta path+1
        lda #128
        sta path+2
        ldx #7
ck2     lda carvol,x
        sta path+6,x
        dex
        bpl ck2
        lda #E_OK
        rts
carvol  dta c'Cart EOS'
mainnm  dta c'MAIN       '

        icl 'tail.icl'
