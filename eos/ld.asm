* EOS (Extendable Operating System): bank 5, the binary loader and the symbol table
*
* U_LOAD: Atari DOS segments ($FFFF),
* SDX absolute segments ($FFFA), relocatable and BSS blocks ($FFFE), fix-ups
* ($FFFD), symbol references ($FFFB, weak ones too) and definitions ($FFFC).

        icl 'equ.icl'
        icl 'kernel.icl'

        opt h-f+


E_EOF   equ 136
E_NOTBIN equ 152
E_NOSYM equ 154
E_NOMEM equ 158
E_CONFLICT equ 179
E_ARCH  equ 184
E_PATHLEN equ 182

        org CARTLO
        jmp u_load             ; $A000 LD_LOAD
        jmp lookup             ; $A003 LD_LOOKUP
        jmp reset_lv           ; $A006 LD_RESET
        jmp s_lookup           ; $A009 LD_SLOOKUP
        jmp s_add              ; $A00C LD_SADD
        jmp s_next             ; $A00F LD_SNEXT
        jmp u_unload           ; $A012 LD_UNLOAD
        jmp s_clear            ; $A015 LD_SCLEAR

* ---- U_LOAD -----------------------------------------------------------------
* FILE_P: the file; FLAG: bit 7 load only, bit 6 run only with a RUN vector
u_load  lda SYSLEVEL           ; this program's level: what to restore after it
        cmp #NLEVEL
        bcc ul0
        lda #E_NOMEM
        jsr farcall
        dta b(BK_LIB),a(L_FAIL)
ul0     tax
        lda FLAG               ; bits 7/6 are public; bit 0 is loader-private
        and #$C0
        sta FLAG
        lda MEMLO
        sta ld_mlo,x
        lda MEMLO+1
        sta ld_mhi,x
        lda COMTAB+$1D
        sta ld_xbn,x
        lda xb_cur
        sta ld_xbc,x
        lda xb_ptr
        sta ld_xbl,x
        lda xb_ptr+1
        sta ld_xbh,x
        lda sx_ptr             ; MALLOC $02 with a USE
        sta ld_sxl,x
        lda sx_ptr+1
        sta ld_sxh,x
        lda SYMBOL
        sta ld_slo,x
        lda SYMBOL+1
        sta ld_shi,x
        lda tr_n
        sta ld_trap,x
        lda #0                 ; EXTENDED: what this load puts where
        ldx #18
ul00    sta EXTENDED,x
        dex
        bpl ul00
        sta ld_xnew
        lda #$04
        sta mode
        lda #$80               ; not a directory
        sta scan
        jsr farcall
        dta b(BK_LIB),a(L_GEFINA)
        ldy #9                 ; kd_open
        jsr jkernel
        bpl ul1
        cmp #170               ; not found: SDX names the file first
        bne ul_f
        pha
        jsr k_romoff           ; (and U_FAIL then names no program: one
        lda #EOL               ; "File" line)
        sta CMDNAME
        jsr k_romon
        lda #EOL               ; on a line of its own, a blank line after it
        jsr ld_putc            ; (as SDX)
        ldx #0
ulm1    lda ld_file,x
        jsr ld_putc
        inx
        cpx #5
        bcc ulm1
        lda FILE_P
        sta fadr
        lda FILE_P+1
        sta fadr+1
        ldy #0
ulm2    lda (fadr),y
        cmp #EOL
        beq ulm3
        jsr ld_putc
        iny
        cpy #64
        bcc ulm2
ulm3    lda #EOL
        jsr ld_putc
        pla
ul_f    jsr farcall
        dta b(BK_LIB),a(L_FAIL)
ul1     lda device             ; path: the program's directory (SDX 4.46),
        cmp #$10               ; from DSK:
        bcs ul1a
        ldy #21
        jsr farcall
        dta b(BK_FMS),a(CARTLO)
ul1a    lda file_id
        sta ld_fid
        inc SYSLEVEL
        jsr k_ownml
        lda #0
        sta ld_blen
        sta ld_bpos
        sta ld_eof
        sta ld_run
        sta RUNAD
        sta RUNAD+1
        jsr getw               ; a binary file starts with $FFFF, $FFFA or $FFFE
        bcs ul_nb
        lda ld_sig+1
        cmp #$FF
        bne ul_nb
        lda ld_sig
        cmp #$FF
        beq ul_blk
        cmp #$FA
        beq ul_blk
        cmp #$FE
        beq ul_blk
ul_nb   lda #E_NOTBIN
        jmp fail

* one block per round, its signature in ld_sig
ul_next jsr getw
        bcc ul_blk
        jmp ul_done            ; end of file
ul_blk  lda ld_sig+1
        cmp #$FF
        bne ul_seg             ; a segment without signature
        lda ld_sig
        cmp #$FF
        beq ul_abs
        cmp #$FA
        beq ul_abs
        cmp #$FE
        bne ul_b1
        jmp ul_reloc
ul_b1   cmp #$FD
        bne ul_b2
        jmp ul_fixup
ul_b2   cmp #$FB
        bne ul_b3
        jmp ul_xref
ul_b3   cmp #$FC
        bne ul_b4
        jmp ul_xdef
ul_b4   cmp #$F9
        bne ul_nb
        lda #E_ARCH
        jmp fail

* ---- absolute segment ------------------------------------------------------
ul_abs  jsr getw               ; start, or a second $FFFF
        jcs ul_trunc
        lda ld_sig
        and ld_sig+1
        cmp #$FF
        beq ul_abs
ul_seg  lda ld_sig
        sta ld_beg
        lda ld_sig+1
        sta ld_beg+1
        jsr getw
        jcs ul_trunc
        lda ld_sig
        sta ld_end
        lda ld_sig+1
        sta ld_end+1
        sec                    ; length = end - start + 1
        lda ld_end
        sbc ld_beg
        sta ld_len
        lda ld_end+1
        sbc ld_beg+1
        sta ld_len+1
        bcc ul_trunc
        inc ld_len
        bne ua1
        inc ld_len+1
ua1     lda ld_end+1           ; not over the library ($A000-$BFFF)
        cmp #$A0
        bcc ua2
        lda ld_beg+1
        cmp #$C0
        bcc ua_conf
ua2     lda ld_beg+1           ; nor over the kernel ($0700 up to the
        cmp MEMLO+1            ; program's MEMLO)
        bcc ua_lo
        bne ua_ok
        lda ld_beg
        cmp MEMLO
        bcs ua_ok
ua_lo   lda ld_end+1
        cmp #$07
        bcc ua_ok
ua_conf lda #E_CONFLICT
        jmp fail
ua_ok   jsr setfirst
        lda #0
        sta INITAD
        sta INITAD+1
        jsr rdblk
        jcs ul_trunc
        lda INITAD
        ora INITAD+1
        beq ua_next
        bit FLAG               ; $80 ignores INIT ($C0 does not)
        bpl ua_init
        bvc ua_next
ua_init lda INITAD
        sta ke_adr
        lda INITAD+1
        sta ke_adr+1
        jsr ld_exec
ua_next jmp ul_next
ul_trunc lda #E_NOTBIN
        jmp fail

* ---- relocatable or BSS block -----------------------------------------------
ul_reloc jsr getb              ; number
        jcs ul_trunc
        cmp #NBLK
        jcs ul_trunc
        sta ld_num
        jsr getb
        jcs ul_trunc
        sta ld_ctl
        jsr getw
        jcs ul_trunc
        lda ld_sig
        sta ld_off
        lda ld_sig+1
        sta ld_off+1
        jsr getw
        jcs ul_trunc
        lda ld_sig
        sta ld_len
        lda ld_sig+1
        sta ld_len+1
* memory index (low bits of the control byte): 0 main memory; 2, system
* extended, falls back to main memory as MALLOC does; 4, program extended
* (banked, out of memory when there is none, as on a 64K SDX), the
* program's first such block in a new bank. $40: page aligned.
        ldx ld_num
        lda #0
        sta ld_mx,x
        lda ld_ctl
        and #$0F
        cmp #$04
        bne ur0
        jmp ur_bank
ur0     lda ld_ctl
        and #$40
        beq ur1
        lda MEMLO
        beq ur1
        lda #0
        sta MEMLO
        inc MEMLO+1
ur1     ldx ld_num
        lda MEMLO
        sta ld_beg
        sta ld_ldlo,x
        sec
        sbc ld_off
        sta ld_bslo,x
        lda MEMLO+1
        sta ld_beg+1
        sta ld_ldhi,x
        sbc ld_off+1
        sta ld_bshi,x
        clc
        lda MEMLO
        adc ld_len
        tay
        lda MEMLO+1
        adc ld_len+1
        bcs ur_mem
        cmp MEMTOP+1
        bcc ur2
        bne ur_mem
        cpy MEMTOP
        bcc ur2
        beq ur2
ur_mem  lda #E_NOMEM
        jmp fail
ur2     sty MEMLO
        sta MEMLO+1
        jsr k_ownml
ur_go   jsr ur_load
        jcs ul_trunc
        jmp ul_next

* ur_load: the block's data (or zeros) in its memory; C=1 file too short
ur_load ldx ld_num             ; EXTENDED+3 on: each block's memory index
        lda ld_mx,x
        ldy EXTENDED+1
        cpy #16
        bcs ur_l1
        sta EXTENDED+3,y
        inc EXTENDED+1
ur_l1   jsr bank_in
        jsr ur_data
        jmp bank_out
ur_data bit ld_ctl
        bmi ur_bss
        jsr setfirst
        jmp rdblk
ur_bss  lda ld_beg             ; BSS: zero filled
        sta fadr
        lda ld_beg+1
        sta fadr+1
        ldy #0
        ldx ld_len+1
        tya
ub1     cpx #0
        beq ub3
ub2     sta (fadr),y
        iny
        bne ub2
        inc fadr+1
        dex
        bne ub2
ub3     ldx ld_len
        beq ub5
ub4     sta (fadr),y
        iny
        dex
        bne ub4
ub5     clc
        rts

* ur_bank: an index 4 block in program extended memory
ur_bank lda ld_xnew            ; the program's first: a new bank
        bne ubk1
        inc ld_xnew
        jsr farcall
        dta b(BK_LIB),a(L_XBNEW)
        jcs ur_mem
ubk1    lda ld_len
        sta bytbuf
        lda ld_len+1
        sta bytbuf+1
        lda ld_ctl
        sta ga_op
        jsr farcall
        dta b(BK_LIB),a(L_XALLOC)
        jcs ur_mem
        txa
        ldx ld_num
        sta ld_mx,x
        sta EXTENDED
        lda addpos
        sta ld_beg
        sta ld_ldlo,x
        sec
        sbc ld_off
        sta ld_bslo,x
        lda addpos+1
        sta ld_beg+1
        sta ld_ldhi,x
        sbc ld_off+1
        sta ld_bshi,x
        jmp ur_go

* bank_in, bank_out: the memory of block ld_num in and out (V_setme);
* bank_out keeps A and the flags
bank_in ldx ld_num
        lda ld_mx,x
        beq bi_ret
        jsr k_setme
bi_ret  rts
bank_out php
        pha
        ldx ld_num
        lda ld_mx,x
        beq bo_ret
        jsr k_popme
bo_ret  pla
        plp
        rts

* ---- fix-ups: add a block's base -------------------------------------------
ul_fixup jsr getb
        bcs ul_trunc2
        cmp #NBLK
        bcs ul_trunc2
        tax
        stx ld_num             ; also the first target
        lda ld_bslo,x
        sta ld_val
        lda ld_bshi,x
        sta ld_val+1
        jsr getw
        bcs ul_trunc2
        jsr fixups
        bcs ul_trunc2
        jmp ul_next
ul_trunc2 jmp ul_trunc

* ---- symbol references: add a symbol's address -----------------------------
ul_xref jsr getname
        bcs ul_trunc2
        ldx #5                 ; importing U_ARGV opts into the native sidecar
uxa1    lda ld_name,x
        cmp ux_argn,x
        bne uxa2
        dex
        bpl uxa1
        lda FLAG
        ora #1
        sta FLAG
uxa2
        jsr getw               ; fix-up size
        bcs ul_trunc2
        lda #0
        sta ld_num
        lda ld_name+7
        and #$80
        sta ld_err             ; $80: weak
        lda ld_name+7
        and #$7F
        sta ld_name+7
        jsr lookup
        bcc ux_fix
        bit ld_err
        bmi ux_skip
        ldx #0                 ; SDX names the symbol first
ux_m1   lda ld_sym,x
        jsr ld_putc
        inx
        cpx #7
        bcc ux_m1
        ldx #0
ux_m2   lda ld_name,x
        cmp #' '
        beq ux_m3
        jsr ld_putc
        inx
        cpx #8
        bcc ux_m2
ux_m3   lda #E_NOSYM
        jmp fail
ux_skip lda #0                 ; weak and not defined: leave the words alone
        sta ld_val
        sta ld_val+1
ux_fix  jsr fixups
        bcs ul_trunc2
        jmp ul_next

* ---- symbol definitions -----------------------------------------------------
ul_xdef jsr getb
        bcs ul_trunc2
        cmp #NBLK
        bcs ul_trunc2
        sta ld_num
        jsr getw
        jcs ul_trunc2
        jsr getname
        jcs ul_trunc2
        ldx ld_num
        clc
        lda ld_bslo,x
        adc ld_sig
        sta ld_val
        lda ld_bshi,x
        adc ld_sig+1
        sta ld_val+1
        jsr addsym
        bcc ul_next2
        jmp fail
ul_next2 jmp ul_next

* ---- end of file: run it ----------------------------------------------------
ul_done lda FLAG               ; legacy COMTAB programs have 64 line bytes
        and #1
        bne uld_ok
        ldx #0
uld_l   lda COMTAB+CT_LBUF,x
        cmp #EOL
        beq uld_ok
        inx
        cpx #64
        bcc uld_l
        lda #E_PATHLEN         ; never silently truncate a legacy command
        jmp fail
uld_ok  ldy #7                 ; kd_close
        lda ld_fid
        sta file_id
        jsr jkernel
        bit FLAG
        bpl ud_run
        rts                    ; load only: the program stays
ud_run  lda RUNAD
        ora RUNAD+1
        bne ud_go
        bit FLAG               ; $40: no RUN vector, no run
        bvs ud_end
        lda ld_run
        beq ud_end
        lda ld_first
        sta RUNAD
        lda ld_first+1
        sta RUNAD+1
ud_go   lda #0
        sta INSTALL
        lda RUNAD
        sta ke_adr
        lda RUNAD+1
        sta ke_adr+1
        ldx SYSLEVEL           ; the program's extended memory is in while
        lda EXTENDED           ; it runs, as on SDX
        sta ld_rx-1,x
        beq ud_g1
        jsr k_setme
ud_g1   jsr ld_exec
        ldx SYSLEVEL
        lda ld_rx-1,x
        beq ud_end
        jsr k_popme
ud_end  jsr unload             ; the status for the caller: in A, or an
        lda STATUS             ; error when negative
        ldx #0
        stx STATUS
        cmp #0
        bpl ud_ret
        jsr farcall
        dta b(BK_LIB),a(L_FAIL)
ud_ret  rts

* ld_exec: k_exec, a BW-DOS program (it starts with BW-DOS's check: "S" at
* $0700, "B" at $0703) with a BW-DOS page 7 (bw.icl)
ld_exec lda ke_adr
        sta fadr
        lda ke_adr+1
        sta fadr+1
        ldy #11
lx1     cpy #6                 ; (a branch offset)
        beq lx2
        lda (fadr),y
        cmp bw_sig,y
        bne lx_eos
lx2     dey
        bpl lx1
        jsr farcall
        dta b(BK_LIB2),a(L2_BWENTER)
        jsr k_exec
        jsr farcall
        dta b(BK_LIB2),a(L2_BWLEAVE)
        rts
lx_eos  jmp k_exec
bw_sig  dta b($AD,$00,$07,$C9,$53,$D0,$00,$AD,$03,$07,$C9,$42)

ld_file dta c'File '
ld_sym  dta c'Symbol '
ux_argn dta c'U_ARGV'
* ld_putc: A to standard output; keeps X, Y
ld_putc jsr farcall
        dta b(BK_LIB),a(L_PUTC)
        rts

* ---- ending a program ---------------------------------------------------------
* unload: the program returned: free its memory and symbols unless it set
* INSTALL, go back one level
unload  lda SYSLEVEL
        jeq un_ret
        ldx #15                ; the files opened at this level close
uc1     lda dev_index,x
        cmp #$FF
        beq uc2
        lda f_level,x
        cmp SYSLEVEL
        bcc uc2
        stx file_id
        stx ld_err
        ldy #1                 ; a redirection to it ends too
uc3     txa
        cmp COMTAB+6,y
        bne uc4
        lda dv_on,y
        beq uc4
        lda #0
        sta dv_on,y
        lda dv_sv,y
        sta COMTAB+6,y
uc4     dey
        bpl uc3
        ldy #7                 ; kd_close
        jsr jkernel
        ldx ld_err
uc2     dex
        bpl uc1
        dec SYSLEVEL
        ldx SYSLEVEL           ; its traps go in any case
        lda ld_trap,x
        sta tr_n
        bit INSTALL
        bmi un_keep
        lda MEMLO              ; MEMLO the program set itself stays
        cmp ld_owl,x
        bne un_ml
        lda MEMLO+1
        cmp ld_owh,x
        bne un_ml
        lda ld_mlo,x
        sta MEMLO
        lda ld_mhi,x
        sta MEMLO+1
        lda ld_slo,x           ; its symbols go with its memory (one that
        sta SYMBOL             ; stays, INSTALLed above it, keeps its
        lda ld_shi,x           ; symbols: LOAD then INSTALL, LOAD alone)
        sta SYMBOL+1
un_ml
        lda ld_xbn,x
        sta COMTAB+$1D
        lda ld_xbc,x
        sta xb_cur
        lda ld_xbl,x
        sta xb_ptr
        lda ld_xbh,x
        sta xb_ptr+1
        lda ld_sxl,x
        sta sx_ptr
        lda ld_sxh,x
        sta sx_ptr+1
iz1     ldy iz_n               ; and its reset routines (S_ADDIZ): they are
        beq un_keep            ; queued in level order
        lda iz_lv-1,y
        cmp SYSLEVEL
        beq un_keep
        bcc un_keep
        dec iz_n
        jmp iz1
un_keep lda #0
        sta INSTALL
un_ret  rts

* U_UNLOAD: remove the program loaded last (with
* FLAG $80), resident or not
u_unload lda #0
        sta INSTALL
        jmp unload

* reset_lv: back in the command processor: end every level
reset_lv lda SYSLEVEL
        beq lr_ret
        jsr unload
        jmp reset_lv
lr_ret  rts

* failing while loading: close the file, end the level, then U_FAIL
fail    pha
        lda ld_fid
        sta file_id
        ldy #7
        jsr jkernel
        lda #0
        sta INSTALL
        jsr unload
        pla
        jsr farcall
        dta b(BK_LIB),a(L_FAIL)

* ---- helpers -----------------------------------------------------------------

* setfirst: the first segment or block is where a program without a RUN
* vector starts
setfirst lda ld_run
        bne sf_ret
        lda ld_beg
        sta ld_first
        lda ld_beg+1
        sta ld_first+1
        dec ld_run
sf_ret  rts

* fixups: apply fix-up bytes (ld_sig: how many, 0 = up to $FC), adding
* ld_val to each word; the target starts as block ld_num. C=1: truncated.
fixups  lda ld_sig
        sta ld_cnt
        lda ld_sig+1
        sta ld_cnt+1
        ora ld_sig
        sta ld_cflag
        ldx ld_num
        lda ld_ldlo,x
        sta ld_pos
        lda ld_ldhi,x
        sta ld_pos+1
fx1     jsr fgetb
        bcs fx_ret
        bvs fx_done            ; the counted bytes are used up
        cmp #$FC
        bne fx2
        lda ld_cflag           ; $FC ends an uncounted block
        beq fx_done
        bne fx1
fx2     jsr fx_one
        bcc fx1
fx_ret  rts
fx_done clc
        rts

* fgetb: the next fix-up byte; V=1 when a counted block has none left
fgetb   lda ld_cflag
        beq fg_rd
        lda ld_cnt
        ora ld_cnt+1
        bne fg_dec
        clc
        bit fg_v
        rts
fg_dec  lda ld_cnt
        bne fg_d1
        dec ld_cnt+1
fg_d1   dec ld_cnt
fg_rd   jsr getb
        clv
        rts
fg_v    dta b($40)

* fx_one: act on one fix-up byte in A; C=1 on a truncated file
fx_one  cmp #$FC
        beq fo_ok
        cmp #$FE
        bne fo1
        jsr fgetb              ; new target block
        bcs fo_err
        bvs fo_err
        cmp #NBLK
        bcs fo_err
        tax
        stx ld_num             ; (bank_in follows the target)
        lda ld_ldlo,x
        sta ld_pos
        lda ld_ldhi,x
        sta ld_pos+1
fo_ok   clc
        rts
fo_err  sec
        rts
fo1     cmp #$FD
        bne fo2
        jsr fgetb              ; absolute address, then fix
        bcs fo_err
        bvs fo_err
        sta ld_pos
        jsr fgetb
        bcs fo_err
        bvs fo_err
        sta ld_pos+1
        jmp fix0               ; always main memory
fo2     cmp #$FF
        bne fo3
        lda #250               ; skip 250
        jsr advance
        clc
        rts
fo3     jsr advance
* fix: the word at ld_pos += ld_val
fix     jsr bank_in            ; in the target block's memory
        jsr fix0
        jmp bank_out
fix0    lda ld_pos
        sta fadr
        lda ld_pos+1
        sta fadr+1
        ldy #0
        clc
        lda (fadr),y
        adc ld_val
        sta (fadr),y
        iny
        lda (fadr),y
        adc ld_val+1
        sta (fadr),y
        clc
        rts
advance clc
        adc ld_pos
        sta ld_pos
        bcc ad1
        inc ld_pos+1
ad1     rts

* getname: 8 bytes to ld_name
getname ldx #0
gn1     jsr getb
        bcs gn_ret
        sta ld_name,x
        inx
        cpx #8
        bcc gn1
        clc
gn_ret  rts

* getw: a word to ld_sig; C=1 at the end of the file
getw    jsr getb
        bcs gw_ret
        sta ld_sig
        jsr getb
        sta ld_sig+1
gw_ret  rts

* getb: the next byte of the file; C=1 at its end. Keeps X.
getb    stx gb_x
        ldx ld_bpos
        cpx ld_blen
        bcc gb_have
        jsr refill
        bcs gb_end
        ldx #0
gb_have lda ld_buf,x
        inx
        stx ld_bpos
        ldx gb_x
        clc
        rts
gb_end  ldx gb_x
        rts

* refill: read up to 128 bytes into ld_buf; C=1 when none were left
refill  lda ld_eof
        bne rf_end
        lda #<ld_buf
        sta addpos
        lda #>ld_buf
        sta addpos+1
        lda #128
        ldx #0
        jsr kread
        bpl rf_ok
        cmp #E_EOF
        bne rf_fail
        dec ld_eof
rf_ok   lda bytbuf
        sta ld_blen
        lda #0
        sta ld_bpos
        lda ld_blen
        beq rf_end
        clc
        rts
rf_end  sec
        rts
rf_fail jmp fail

* rdblk: ld_len bytes of the file to ld_beg: what is buffered, then the rest
* straight from the file. C=1 when the file ends first.
rdblk   lda ld_beg
        sta fadr
        lda ld_beg+1
        sta fadr+1
rb1     lda ld_len
        ora ld_len+1
        beq rb_ok
        ldx ld_bpos
        cpx ld_blen
        bcs rb_direct
        lda ld_buf,x
        inx
        stx ld_bpos
        ldy #0
        sta (fadr),y
        inc fadr
        bne rb2
        inc fadr+1
rb2     lda ld_len
        bne rb3
        dec ld_len+1
rb3     dec ld_len
        jmp rb1
rb_direct lda ld_eof
        bne rb_short
        lda fadr
        sta addpos
        lda fadr+1
        sta addpos+1
        lda ld_len
        ldx ld_len+1
        jsr kread
        bpl rb_ok
        cmp #E_EOF
        bne rf_fail
rb_short sec
        rts
rb_ok   clc
        rts

* kread: kernel read of XA bytes of the file to addpos
kread   sta bytbuf
        stx bytbuf+1
        lda ld_fid
        sta file_id
        lda #0
        sta memreix
        tay                    ; kd_read
        jmp jkernel

* ---- symbols -----------------------------------------------------------------

* lookup: the symbol ld_name: C=0 and ld_val, or C=1. The RAM list
* (SYMBOL; record: link, name, level, address) comes before the ROM table.
lookup  lda SYMBOL
        sta fadr
        lda SYMBOL+1
        sta fadr+1
lk1     lda fadr
        ora fadr+1
        beq lk_rom
        ldy #2
lk2     lda (fadr),y
        cmp ld_name-2,y
        bne lk_nxt
        iny
        cpy #10
        bcc lk2
        ldy #11
        lda (fadr),y
        sta ld_val
        iny
        lda (fadr),y
        sta ld_val+1
        clc
        rts
lk_nxt  ldy #0
        lda (fadr),y
        tax
        iny
        lda (fadr),y
        stx fadr
        sta fadr+1
        jmp lk1
lk_rom  lda #<symtab
        sta fadr
        lda #>symtab
        sta fadr+1
lk3     ldy #0
        lda (fadr),y
        beq lk_none
lk4     lda (fadr),y
        cmp ld_name,y
        bne lk5
        iny
        cpy #8
        bcc lk4
        lda (fadr),y
        sta ld_val
        iny
        lda (fadr),y
        sta ld_val+1
        clc
        rts
lk5     clc
        lda fadr
        adc #10
        sta fadr
        bcc lk3
        inc fadr+1
        bne lk3
lk_none sec
        rts

* ---- S_LOOKUP, S_ADD, S_NEXT ---------------------------
* The SYMBOL structure: +0 the list, +2 name, +$0A level, +$0B address.

* s_lookup: the symbol named at SYMBOL+2: Z=0 and its address at SYMBOL+$0B,
* memory index 0 in EXTENDED; Z=1 when there is none
s_lookup jsr sy_name
        jsr lookup
        bcs sy_no
        lda ld_val
        sta SYMBOL+$0B
        lda ld_val+1
        sta SYMBOL+$0C
        lda #0
        sta SYMBOL+$0D
        sta EXTENDED
sy_yes  lda #1                 ; Z=0
        rts
sy_no   lda #0
        rts
sy_name ldx #7
sy1     lda SYMBOL+2,x
        sta ld_name,x
        dex
        bpl sy1
        rts

* s_add: the symbol at SYMBOL+2 = SYMBOL+$0B, a record at MEMLO; C=1 when
* out of memory
s_add   jsr sy_name
        lda SYMBOL+$0B
        sta ld_val
        lda SYMBOL+$0C
        sta ld_val+1
        jmp addsym

* s_next: the next symbol to SYMBOL+2 ... (the first when SYMBOL+2 is 0):
* the RAM list, then the system's table. Z=1 at the end.
s_next  lda SYMBOL+2
        bne sn1
        lda SYMBOL
        sta sn_p
        lda SYMBOL+1
        sta sn_p+1
        lda #0
        sta sn_rom
sn1     lda sn_p
        sta fadr
        lda sn_p+1
        sta fadr+1
        lda #0
        sta SYMBOL+$0D
        bit sn_rom
        bmi sn_rom1
        ora fadr                ; A = 0
        ora fadr+1
        bne sn2
        lda #<symtab           ; end of the RAM list
        sta sn_p
        lda #>symtab
        sta sn_p+1
        dec sn_rom
        bne sn1
sn2     ldy #12                ; a RAM record: name, level, address
sn3     lda (fadr),y
        sta SYMBOL,y
        dey
        cpy #2
        bcs sn3
        ldy #1                 ; then its link
        lda (fadr),y
        sta sn_p+1
        dey
        lda (fadr),y
        sta sn_p
        jmp sy_yes
sn_rom1 ldy #0                 ; a ROM entry: name, address
        lda (fadr),y
        jeq sy_no
sn4     lda (fadr),y
        sta SYMBOL+2,y
        iny
        cpy #10
        bcc sn4
        lda SYMBOL+$0B         ; the address follows the name: a byte up,
        sta SYMBOL+$0C         ; the high byte first
        lda SYMBOL+$0A
        sta SYMBOL+$0B
        lda #0
        sta SYMBOL+$0A
        clc
        lda sn_p
        adc #10
        sta sn_p
        bcc sn5
        inc sn_p+1
sn5     jmp sy_yes

* s_clear: the RAM symbols of levels above the
* caller's (SYSLEVEL) leave the list. sc_p: the FMS's scratch pointer,
* free between FMS calls.
sc_p    equ $47
s_clear lda #<SYMBOL           ; fadr: the link that may change
        sta fadr
        lda #>SYMBOL
        sta fadr+1
sc1     ldy #0                 ; the record it points to
        lda (fadr),y
        sta ld_val
        iny
        lda (fadr),y
        sta ld_val+1
        ora ld_val
        beq sc_ret
        lda ld_val             ; its level
        sta sc_p
        lda ld_val+1
        sta sc_p+1
        ldy #10
        lda (sc_p),y
        and #$3F
        cmp SYSLEVEL
        beq sc_keep
        bcc sc_keep
        ldy #0                 ; above: the link skips it
        lda (sc_p),y
        sta (fadr),y
        iny
        lda (sc_p),y
        sta (fadr),y
        jmp sc1
sc_keep lda sc_p             ; kept: its link is the next to look at
        sta fadr
        lda sc_p+1
        sta fadr+1
        jmp sc1
sc_ret  rts

* addsym: a RAM symbol ld_name = ld_val of this level, its record allocated
* at MEMLO; C=1, A = status when out of memory
addsym  clc
        lda MEMLO
        sta fadr
        adc #13
        tay
        lda MEMLO+1
        sta fadr+1
        adc #0
        cmp MEMTOP+1
        bcc as1
        bne as_mem
        cpy MEMTOP
        bcc as1
as_mem  lda #E_NOMEM
        sec
        rts
as1     sty MEMLO
        sta MEMLO+1
        jsr k_ownml
        ldy #0
        lda SYMBOL
        sta (fadr),y
        iny
        lda SYMBOL+1
        sta (fadr),y
as2     iny
        lda ld_name-2,y
        sta (fadr),y
        cpy #9
        bcc as2
        iny
        lda SYSLEVEL
        and #$3F
        sta (fadr),y
        iny
        lda ld_val
        sta (fadr),y
        iny
        lda ld_val+1
        sta (fadr),y
        lda fadr
        sta SYMBOL
        lda fadr+1
        sta SYMBOL+1
        clc
        rts

* the system's symbols: name, address (generated from eos/symbols.txt)
symtab  icl 'symtab.icl'
        dta b(0)

        icl 'tail.icl'
