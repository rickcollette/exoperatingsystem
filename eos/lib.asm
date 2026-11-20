* EOS (Extendable Operating System): bank 1, the library
*
* Mapped at $A000 while programs run, so the symbols of the library point
* straight into this bank. Behaviour follows the SpartaDOS X 4.5 Programming
* Guide; where it is silent, what real SDX does (tools/probe).

        icl 'equ.icl'
        icl 'kernel.icl'

        opt h-f+


E_EOF   equ 136
E_NODEV equ 130
E_NOMEM equ 158
E_PATHLEN equ 182

COMFNAM equ COMTAB+CT_COMFNAM
LBUF    equ COMTAB+CT_LBUF
BUFOFF  equ COMTAB+CT_BUFOFF
FILLEN  equ COMTAB+CT_FILLEN

        org CARTLO
* entries for the other banks (farcall); programs use the symbols
        jmp u_getpar           ; $A000
        jmp u_gefina           ; $A003
        jmp fopen              ; $A006
        jmp fclose             ; $A009
        jmp fgetc              ; $A00C
        jmp putc               ; $A00F
        jmp u_fail             ; $A012
        jmp fread              ; $A015
        jmp printf             ; $A018
        jmp gefina             ; $A01B
        jmp misc               ; $A01E jmisc
        jmp crunch             ; $A021 ZCRNAME (COMTAB+3)
        jmp xalloc             ; $A024 program extended memory (loader)
        jmp xb_new             ; $A027 a new bank (loader)
        jmp putenv             ; $A02A PUTENV (command processor)
        jmp numenv             ; $A02D NUMENV
        jmp u_error            ; $A030 EOL, the message for error A, EOL
        jmp divio              ; $A033 DIVIO
        jmp xdivio             ; $A036 XDIVIO
        jmp rename             ; $A039 RENAME
        jmp rendir             ; $A03C RENDIR
        jmp u_getnum           ; $A03F U_GETNUM
        jmp renm               ; $A042 RENAME returning the status (CIO D:)
        jmp drvname            ; $A045 _DRVNAME: drive A's name to dv_nm

* ---- U_LOAD: the loader lives in its own bank ------------------------------
u_load  jsr farcall
        dta b(BK_LD),a(LD_LOAD)
        rts

* ---- FORMAT (13.1): the formatter's menu; BUILDDIR (13.2): a soft format of
* drive DUNIT (DDEVIC $31), the label (8 characters) at AX. Both run
* CAR:FORMAT.COM ("FORMAT", "FORMAT /QQ x: LABEL") as a child program; the
* caller's command line is kept under the OS ROM meanwhile.
ff_buf  equ LBUFF              ; the parameters built here first
ff_n    equ LBUFF+$7F
l_format lda #0                ; no parameters: the menu
        sta ff_n
        beq ff_go
builddir sta fadr
        stx fadr+1
        ldx #0
        ldy #0
bd1     lda bd_cmd,y           ; FORMAT /QQ
        sta ff_buf,x
        inx
        iny
        cpy #bd_cmd_end-bd_cmd
        bcc bd1
        lda #'D'               ; Dn: (FORMAT takes the drive so)
        sta ff_buf,x
        inx
        lda DUNIT
        and #$0F
        cmp #10
        bcc bd0
        sbc #10
        pha
        lda #'1'
        sta ff_buf,x
        inx
        pla
bd0     ora #'0'
        sta ff_buf,x
        inx
        lda #':'
        sta ff_buf,x
        inx
        lda #' '
        sta ff_buf,x
        inx
        ldy #0                 ; the label, its blanks dropped at the end
bd2     lda (fadr),y
        sta ff_buf,x
        inx
        iny
        cpy #8
        bcc bd2
bd3     lda ff_buf-1,x
        cmp #' '
        bne bd4
        dex
        bne bd3
bd4     stx ff_n
ff_go   jsr k_romoff           ; the caller's line kept
        ldx #63
fmt1     lda LBUF,x
        sta lb_save,x
        dex
        bpl fmt1
        lda BUFOFF
        sta lb_save+64
        lda FILE_P
        sta lb_save+65
        lda FILE_P+1
        sta lb_save+66
        lda FLAG
        sta lb_save+67
        jsr k_romon
        ldx #0                 ; FORMAT [parameters]
fmt2     lda ff_cmd,x
        sta LBUF,x
        inx
        cpx #6
        bcc fmt2
        ldy #0
fmt3     cpy ff_n
        bcs fmt4
        lda ff_buf,y
        sta LBUF,x
        inx
        iny
        bne fmt3
fmt4     lda #EOL
        sta LBUF,x
        ldx #63                ; LBUFF too: the command line as typed (FORMAT
fmt6    lda LBUF,x             ; reads the volume name there)
        sta LBUFF,x
        dex
        bpl fmt6
        lda #6
        sta BUFOFF
        lda #<ff_name
        sta FILE_P
        lda #>ff_name
        sta FILE_P+1
        lda #0
        sta FLAG
        jsr u_load
        jsr k_romoff           ; the caller's line again
        ldx #63
fmt5     lda lb_save,x
        sta LBUF,x
        dex
        bpl fmt5
        lda lb_save+64
        sta BUFOFF
        lda lb_save+65
        sta FILE_P
        lda lb_save+66
        sta FILE_P+1
        lda lb_save+67
        sta FLAG
        jsr k_romon
        lda #1
        rts
ff_name dta c'CAR:FORMAT.COM',b(EOL)
ff_cmd  dta c'FORMAT'
bd_cmd  dta c' /QQ '
bd_cmd_end equ *

* ---- U_GETPAR: next parameter from LBUF to COMFNAM ------------------------
* Z=1 when there is none; else X = FILLEN = its length, FILE_P -> COMFNAM.
* As on SDX: blanks before it are skipped, after it the blanks and one
* comma; a comma where a parameter would start is an empty one (A,,B: A,
* nothing, B).
u_getpar ldy BUFOFF
gp1     lda LBUF,y
        cmp #' '
        beq gp_skip
        cmp #','
        beq gp_empty
        cmp #EOL
        beq gp_none
        ldx #0
gp2     cmp #'a'               ; in capitals, as on SDX (LBUF keeps the case)
        bcc gp2a
        cmp #'z'+1
        bcs gp2a
        and #$DF
gp2a    sta COMFNAM,x
        inx
        iny
        lda LBUF,y
        cmp #' '
        beq gp_end
        cmp #','
        beq gp_end
        cmp #EOL
        bne gp2
gp_end  lda #EOL
        sta COMFNAM,x
gp_e0   lda LBUF,y             ; BUFOFF goes past the blanks and one comma
        cmp #' '
        bne gp_e2
        iny
        bne gp_e0
gp_e2   cmp #','
        bne gp_e1
        iny
gp_e1   sty BUFOFF
        stx FILLEN
        lda #<COMFNAM
        sta FILE_P
        lda #>COMFNAM
        sta FILE_P+1
        txa
        rts
gp_skip iny
        bne gp1
gp_empty iny                   ; (past the comma: nothing, Z=1)
        ldx #0
        lda #EOL
        sta COMFNAM
        beq gp_e1
gp_none sty BUFOFF
        lda #EOL               ; COMFNAM empty (SL.COM relies on it on SDX)
        sta COMFNAM
        lda #0
        rts

* ---- U_GEFINA: the file specification at FILE_P to device, path, name ------
* An optional device ends with ':' and is a drive letter A-O, D1-D15, or a
* device name from DEVNAME with an optional unit (DSK2, CAR). Without one the
* current device CURDEV is used. The rest goes to path; the directory part
* stays there, $00 terminated, and the file name is converted to name
* (8+3, space padded, '*' filled with '?').
u_gefina jsr gefina
        bcc ug_ret
        jmp u_fail
ug_ret  rts

* gefina: U_GEFINA that returns C=1, A = status instead of failing
gefina  lda FILE_P
        sta fadr
        lda FILE_P+1
        sta fadr+1
        ldy #0
ge1     lda (fadr),y
        jsr isalnum
        bcs ge2
        iny
        cpy #6
        bcc ge1
ge2     cmp #':'
        bne ge_cur
        jsr parsedev
        bcs ge_bad
        sta device
        iny
        bne ge_rest
ge_cur  lda CURDEV
        sta device
        ldy #0
ge_rest ldx #0
gr1     lda (fadr),y
        beq gr1e               ; a NUL ends it too (SC's names)
        cmp #' '               ; a space or comma ends the specification
        beq gr1e               ; (RENAME: the new name follows)
        cmp #','
        bne gr1a
gr1e    lda #EOL
gr1a    sta path,x
        cmp #EOL
        beq gr2
        iny
        inx
        cpx #64
        bcc gr1
        lda #E_PATHLEN
        sec
        rts
ge_bad  lda #E_NODEV
        sec
        rts
gr2     sty ge_stop
        txa                    ; a copy of the whole path for U_GEPATH
        tay
gr2a    lda path,y
        sta ge_rawp,y
        dey
        bpl gr2a
        stx ge_end             ; the name starts after the last >, backslash or <
        ldx #0
        stx ge_ns
gr3     cpx ge_end
        beq gr4
        lda path,x
        inx
        cmp #'>'
        beq gr3s
        cmp #BSLASH
        beq gr3s
        cmp #'<'
        bne gr3
gr3s    stx ge_ns
        jmp gr3
gr4     ldx ge_ns              ; a final . or .. belongs to the path
        lda path,x
        cmp #'.'
        bne gr5
        lda path+1,x
        cmp #EOL
        beq gr4p
        cmp #'.'
        bne gr5
        lda path+2,x
        cmp #EOL
        bne gr5
gr4p    lda ge_end
        sta ge_ns
gr5     ldx #10                ; name
        lda #' '
gr6     sta name,x
        dex
        bpl gr6
        ldy ge_ns
        ldx #0
        lda #8
        sta ge_lim
gn1     lda path,y
        cmp #EOL
        beq gn_end
        iny
        cmp #'.'
        beq gn_dot
        cmp #'*'
        beq gn_star
        cpx ge_lim
        bcs gn1
        sta name,x
        inx
        bne gn1
gn_star lda #'?'
gn_s1   cpx ge_lim
        bcs gn1
        sta name,x
        inx
        bne gn_s1
gn_dot  lda ge_lim             ; a second dot ends the name
        cmp #8
        bne gn_end
        ldx #8
        lda #11
        sta ge_lim
        bne gn1
gn_end  ldx ge_ns
        lda #0
        sta path,x
        clc
        rts

* drvchar: the drive letter A-O or digit 1-9 in A as a drive number in A;
* C=1 when it is neither
drvchar cmp #'1'
        bcc dc_bad
        cmp #'9'+1
        bcs dc_l
        and #$0F
        bne dc_map
dc_l    cmp #'A'
        bcc dc_bad
        cmp #'O'+1
        bcs dc_bad
        sbc #'A'-2             ; C=0: -('A'-1)
dc_map  stx dm_x               ; the drive the map gives (sio_index: SWAP, MAP)
        tax
        lda COMTAB2+1,x
        ldx dm_x
        clc
        rts
dc_bad  sec
        rts

* ciolet: C=0 when CIO has a handler for the letter in A (HATABS); keeps
* A and Y
ciolet  ldx #0
cl1     cmp HATABS,x
        beq cl_yes
        inx
        inx
        inx
        cpx #36
        bcc cl1
        rts                    ; (C=1)
cl_yes  clc
        rts

* drvlet (_DRVLET): the drive letter in A (A-O) as a drive (1-15) in A,
* C=0; as in names, D is D1 and a letter CIO has another device for is not
* a drive: C=1 (also outside A-O). Keeps Y.
drvlet  cmp #'D'
        beq dl_d
        jsr ciolet
        bcc dl_no
        cmp #'A'
        bcc dl_no
        cmp #'O'+1
        bcs dl_ret
        sbc #'A'-2             ; (C=0: A is 1)
        clc
        rts
dl_d    lda #1
        clc
        rts
dl_no   sec
dl_ret  rts

* drvname (_DRVNAME): drive A (1-15) as a name in dv_nm (_DRVNM), EOL
* ended: its letter (A: ... O:), or, when CIO has a device with that letter
* (C: E: K: ...), D and its digit or letter (D3:, DK:), which U_GEFINA reads
* back as the same drive. A = its length; keeps Y.
drvname and #$0F
        sta dv_n
        clc
        adc #'A'-1
        jsr ciolet
        ldx #0
        bcs dvn1
        lda #'D'
        sta dv_nm
        inx
        lda dv_n
        cmp #10
        bcs dvn0
        ora #'0'
        bne dvn1
dvn0    adc #'A'-2             ; (C=1: 10 is J)
dvn1    sta dv_nm,x
        lda #':'
        sta dv_nm+1,x
        lda #EOL
        sta dv_nm+2,x
        inx
        inx
        txa
        rts

* parsedev: the device before ':' (Y characters at fadr) as a device byte
* in A; C=1 when it is not a device
parsedev cpy #0
        bne ds1
        lda CURDEV
        clc
        rts
ds1     sty ge_n
        ldy #0
        lda (fadr),y
        ldx ge_n
        cpx #1
        bne ds2
        jsr ciolet             ; a letter CIO has a device for is that
        bcs ds1a               ; device, not a drive: D: is D1: (as CIO
        cmp #'D'               ; has it; SDX: drive D, D4:), E: CON:, P:
        bne ds1c               ; PRN:, others not here (130)
        lda #'1'
ds1a    jsr drvchar            ; A: ... O:, 1: ... 9:
        ldy ge_n
        rts
ds1c    ldx #$31               ; CON1
        cmp #'E'
        beq ds1d
        ldx #$41               ; PRN1
        cmp #'P'
        bne ds_bad
ds1d    txa
        ldy ge_n
        clc
        rts
ds2     cmp #'A'
        bcc ds_bad
        cpx #2                 ; D and a drive digit or letter: the D is
        bne ds3n               ; ignored (D15: is not a drive, as on SDX)
        cmp #'D'
        bne ds_bad
        iny
        lda (fadr),y
        jsr drvchar
        ldy ge_n
        rts
ds3n    cpx #3                 ; a device name from DEVNAME
        bcc ds_bad
        ldx #0
ds4     ldy #0
ds5     lda (fadr),y
        cmp DEVNAME,x
        bne ds6
        inx
        iny
        cpy #3
        bcc ds5
        txa                    ; X = 4 * device + 3
        lsr @
        lsr @
        asl @
        asl @
        asl @
        asl @
        sta ge_dv
        lda #1
        cpy ge_n
        beq ds7
        jsr unitnum
        bcs ds_bad
ds7     ora ge_dv
        ldy ge_n
        clc
        rts
ds6     txa
        and #$FC
        clc
        adc #4
        tax
        cpx #32
        bcc ds4
ds_bad  ldy ge_n
        sec
        rts

* unitnum: the unit from (fadr),Y up to ge_n: decimal 1-15, or one letter
* A-O (SDX: DSKA: is DSK1:); A = unit, C=1 bad
unitnum lda (fadr),y
        cmp #'A'
        bcc un0
        cmp #'O'+1
        bcs un_bad
        iny
        cpy ge_n
        bne un_bad
        sbc #'A'-1             ; (C=1)
        clc
        rts
un0     lda #0
        sta ge_u
un1     lda (fadr),y
        jsr isdigit
        bcs un_bad
        and #$0F
        pha
        lda ge_u
        asl @
        asl @
        adc ge_u
        asl @
        sta ge_u
        pla
        adc ge_u
        sta ge_u
        iny
        cpy ge_n
        bcc un1
        lda ge_u
        beq un_bad
        cmp #16
        rts
un_bad  sec
        rts

* isdigit, isalnum: C=0 when A is one
isdigit cmp #'0'
        bcc is_no
        cmp #'9'+1
        bcs is_no
        clc
        rts
isalnum jsr isdigit
        bcc is_ret
        cmp #'A'
        bcc is_no
        cmp #'Z'+1
        bcs is_no
        clc
        rts
is_no   sec
is_ret  rts

* ---- FOPEN, FCLOSE, FREAD, FGETC ------------
fopen   jsr u_gefina
        ldy #9                 ; kd_open
        jsr jkernel
        jmi failfp
        rts

fclose  ldy #7                 ; kd_close
        jsr jkernel
        bmi fail
        rts
fail    jmp u_fail

* FREAD: X = 0, N=0; at the end of the file X = $FF, N=1
fread   ldy #0                 ; kd_read
        jsr jkernel
        bpl fr_ok
        cmp #E_EOF
        bne fail
        ldx #$FF
        rts
fr_ok   ldx #0
        rts

* FGETC: A = the next byte; at the end of the file A = EOL, X = $FF, N=1.
* Keeps Y.
fgetc   sty fg_y
        lda file_id            ; the next byte in the byte window (after
        cmp fw_h               ; the last read: dev.asm fw_set): from
        bne fgc0               ; there (kernel kfx1)
        lda fw_n
        beq fgc0
        jsr kfx1
        ldy fg_y
        ldx #0
        cpx #0                 ; N=0
        rts
fgc0    lda addpos
        pha
        lda addpos+1
        pha
        lda bytbuf
        pha
        lda bytbuf+1
        pha
        lda #<fg_b
        sta addpos
        lda #>fg_b
        sta addpos+1
        lda #1
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        tay                    ; kd_read
        jsr jkernel
        sta fg_st
        pla
        sta bytbuf+1
        pla
        sta bytbuf
        pla
        sta addpos+1
        pla
        sta addpos
        ldy fg_y
        lda fg_st
        bpl fg_ok
        cmp #E_EOF
        bne fail
        ldx #$FF
        lda #EOL               ; N=1
        rts
fg_ok   ldx #0
        lda fg_b
        cpx #0                 ; N=0
        rts

* ---- writing and managing files ------
* FWRITE: addpos, bytbuf as FREAD; X = 0
fwrite  ldy #1                 ; kd_write
        jsr jkernel
        bmi fail2
        ldx #0
        rts

* FPUTC: A to the file file_id; keeps A, X, Y
fputc   jsr fputc_
        pha
        lda pc_st
        bmi fp_err
        pla
        rts
fp_err  jmp u_fail

* FILELENG, FTELL, FSEEK: through addpos
fileleng ldy #4
        bne fl_k
ftell   ldy #3
        bne fl_k
fseek   ldy #2
fl_k    jsr jkernel
        bmi fail2
        rts

* REMOVE, RMDIR, MKDIR, CHMOD, CHDIR: the specification at FILE_P
remove  ldy #12
        bne fs_k
rmdir   ldy #15
        bne fs_k
mkdir   ldy #14
        bne fs_k
chmod   ldy #13
        bne fs_k
chdir   ldy #16
        bne fs_k
getcwd  ldy #17                ; GETCWD: the path from the main directory
        bne fs_k               ; to path, $00 at its end
getdfree ldy #19               ; GETDFREE: the disk's information to path
        bne fs_k
chvol   ldy #20                ; CHVOL: the volume name from the name part
        bne fs_k
setboot ldy #18                ; SETBOOT: the file booted from the disk
fs_k    sty fs_fn
        jsr u_gefina
        ldy fs_fn
        jsr jkernel
        bmi failfp
        rts
fail2   jmp u_fail
* failfp: U_FAIL after a call on the file named at FILE_P: that name (as
* typed, without device and path, up to a blank) is the one U_FAIL shows
* before 170 ("File X", as SDX names the file it failed on; an empty name
* shows nothing). ffname: only the name taken (FFIRST: the file looked up
* last is the one named, found or not).
failfp  pha
        jsr ffname
        pla
        jmp u_fail
ffname  lda FILE_P
        sta fadr
        lda FILE_P+1
        sta fadr+1
        ldy #0                 ; the name only: after the last : > or
        ldx #0                 ; backslash (SDX: File X.DAT for SUB>X.DAT)
ff0     lda (fadr),y
        jsr ffend
        beq ff0e
        iny
        cmp #':'
        beq ff0s
        cmp #'>'
        beq ff0s
        cmp #BSLASH
        bne ff0
ff0s    tya
        tax
        bne ff0
ff0e    txa
        clc
        adc fadr
        sta fadr
        bcc ff0f
        inc fadr+1
ff0f    jsr k_romoff
        ldy #0
ff1     lda (fadr),y
        jsr ffend
        beq ff2                ; (the end: an EOL there)
        sta CMDNAME,y
        iny
        cpy #31
        bcc ff1
ff2     lda #EOL
        sta CMDNAME,y
        jmp k_romon
* ffend: Z=1 when A ends a name: a blank, a comma, a / (an option), $00
* or the EOL
ffend   cmp #' '
        beq fe_ret
        cmp #','
        beq fe_ret
        cmp #'/'
        beq fe_ret
        cmp #0
        beq fe_ret
        cmp #EOL
fe_ret  rts

* FFIRST: the first entry matching FILE_P and scan
* to dentry, its directory open in file_id; FNEXT: the next one. N=1 at the
* end of the directory.
ffirst  jsr ffname             ; (the name for a 170 later, found or not)
        jsr u_gefina
        ldy #10                ; kd_first
        bne fn_k
fnext   ldy #6                 ; kd_next
fn_k    jsr jkernel
        bpl fn_ok
        cmp #E_EOF
        jne failfp
        lda #E_EOF             ; N=1
fn_ok   rts

* U_GEPATH (5.12): FILE_P to device and the whole path in path
u_gepath jsr u_gefina
        ldx #0
gp_c    lda ge_rawp,x          ; the path as given, name included
        sta path,x
        inx
        cmp #EOL
        bne gp_c
        dex
        lda #0
        sta path,x
        rts

* RENAME: "old new" at FILE_P (a space or comma between them)
* RENDIR (12.2): RENAME for a directory
rendir  lda #$08
        sta scan
rename  jsr u_gefina
        jsr rn0
        jmi failfp
        rts
* renm: RENAME with the status in A (N=1 an error) instead of failing
renm    jsr gefina
        bcc rn0
        ora #0
        rts
rn0     lda FILE_P             ; the new name follows the first one
        sta fadr
        lda FILE_P+1
        sta fadr+1
        ldy ge_stop
rn1     lda (fadr),y
        cmp #' '
        beq rn2
        cmp #','
        bne rn3
rn2     iny
        bne rn1
rn3     ldx #10                ; to x_name as U_GEFINA makes a name
        lda #' '
rn4     sta x_name,x
        dex
        bpl rn4
        ldx #0
        lda #8
        sta ge_lim
rn5     lda (fadr),y
        cmp #EOL
        beq rn_end
        cmp #' '
        beq rn_end
        cmp #','
        beq rn_end
        iny
        cmp #'.'
        beq rn_dot
        cmp #'*'
        beq rn_star
        cpx ge_lim
        bcs rn5
        sta x_name,x
        inx
        bne rn5
rn_star lda #'?'
rn_s1   cpx ge_lim
        bcs rn5
        sta x_name,x
        inx
        bne rn_s1
rn_dot  lda ge_lim
        cmp #8
        bne rn_end
        ldx #8
        lda #11
        sta ge_lim
        bne rn5
rn_end  ldy #11                ; kd_rename
        jmp jkernel

* ---- PUTC: a character to standard output (COMTAB+6); keeps A, X, Y and
* the page 7 parameters ------------------------------------------------------
putc    sta pc_a
        lda COMTAB+6
        jmp pc_go
* fputc_: the character in A to the file file_id
fputc_  sta pc_a
        lda file_id
pc_go   stx pc_x
        sty pc_y
        cmp #100               ; the magic handle: through PUT_V
        bne pc_k
        lda pc_a
        jsr pc_vec
        lda #1
        sta pc_st
        rts
pc_vec  jmp (PUT_V)
pc_k
        ldx file_id
        stx pc_fid
        sta file_id
        ldx #4
pc1     lda addpos,x           ; addpos, bytbuf, memreix
        sta pc_save,x
        dex
        bpl pc1
        lda #<pc_a
        sta addpos
        lda #>pc_a
        sta addpos+1
        lda #1
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        ldy #1                 ; kd_write
        jsr jkernel
        sta pc_st
        ldx #4
pc2     lda pc_save,x
        sta addpos,x
        dex
        bpl pc2
        lda pc_fid
        sta file_id
        ldy pc_y
        ldx pc_x
        lda pc_a
        rts

* ---- S_LOOKUP, S_ADD, S_NEXT live in the loader bank; S_ADDIZ -------------
u_unload jsr farcall
        dta b(BK_LD),a(LD_UNLOAD)
        rts
s_clear jsr farcall
        dta b(BK_LD),a(LD_SCLEAR)
        rts
fdopen  jsr farcall            ; FDOPEN, FDGETC, FDCLOSE: in bank 6
        dta b(BK_LIB2),a(L2_FDOPEN)
        rts
fdgetc  jsr farcall
        dta b(BK_LIB2),a(L2_FDGETC)
        rts
fdclose jsr farcall
        dta b(BK_LIB2),a(L2_FDCLOSE)
        rts
s_lookup jsr farcall
        dta b(BK_LD),a(LD_SLOOKUP)
        rts
s_add   jsr farcall
        dta b(BK_LD),a(LD_SADD)
        rts
s_next  jsr farcall
        dta b(BK_LD),a(LD_SNEXT)
        rts

* S_ADDIZ: AX = a routine to run after a RESET;
* C=1 when the queue (5) is full
s_addiz ldy iz_n
        cpy #NIZ
        bcs sa_ret
        sta iz_lo,y
        txa
        sta iz_hi,y
        lda SYSLEVEL
        sta iz_lv,y
        inc iz_n
        clc
sa_ret  rts

* ---- GETENV, NUMENV, PUTENV: in lib2 (env.icl: the environment under the
* OS ROM or, after ENV.SYS, in a bank of its own) ------------------------
getenv  jsr farcall
        dta b(BK_LIB2),a(L2_ENGET)
        rts
numenv  jsr farcall
        dta b(BK_LIB2),a(L2_ENNUM)
        rts
putenv  jsr farcall
        dta b(BK_LIB2),a(L2_ENPUT)
        rts

* ---- DIVIO, XDIVIO ----------------------------------
* DIVIO: FILE_P becomes standard output (Y=0, written anew; Y=2, appended)
* or standard input (Y=1); file_id = its handle. XDIVIO: Y=0 or 1, the file
* is closed and the console is back. Input that reaches its end, and the
* end of the level that opened the file, undo it too.
divio   sty dv_t
        ldx dv_mode,y
        stx mode
        lda #0
        sta scan
        sta attr
        tya                    ; 0 output, 1 input
        and #1
        tay
        jsr xdivio             ; one at a time
        jsr fopen
        ldx dv_t
        lda dv_idx,x
        tax
        lda COMTAB+6,x
        sta dv_sv,x
        lda file_id
        sta COMTAB+6,x
        lda #$FF
        sta dv_on,x
        cpx #1                 ; input: E: reads it too (k_ehand)
        bne dv_r
        jsr e_wrap
dv_r    rts
xdivio  lda dv_on,y
        beq xd_ret
        lda #0
        sta dv_on,y
        cpy #1
        bne xd0
        jsr e_unwrap
xd0
        lda file_id
        pha
        lda COMTAB+6,y
        sta file_id
        lda dv_sv,y
        sta COMTAB+6,y
        tya
        pha
        ldy #7                 ; kd_close
        jsr jkernel
        pla
        tay
        pla
        sta file_id
xd_ret  rts
* e_wrap / e_unwrap (kernel.asm k_ehand): the wrapper in and out of HATABS (DIVIO, XDIVIO for
* standard input). Keep A, X, Y.
e_wrap  jsr ke_find
        bcs kw_ret
        lda HATABS+2,x
        cmp #>k_ehand
        bne kw1
        lda HATABS+1,x
        cmp #<k_ehand
        beq kw_ret
kw1     lda HATABS+1,x
        sta ke_old
        sta fadr
        lda HATABS+2,x
        sta ke_old+1
        sta fadr+1
        ldy #15
kw_rd   lda (fadr),y
        sta ke_tab,y
        dey
        bpl kw_rd
        lda #<k_ehand
        sta HATABS+1,x
        lda #>k_ehand
        sta HATABS+2,x
kw_ret  jmp ke_pop
e_unwrap jsr ke_find
        bcs ku_ret
        lda HATABS+2,x
        cmp #>k_ehand
        bne ku_ret
        lda HATABS+1,x
        cmp #<k_ehand
        bne ku_ret
        lda ke_old
        sta HATABS+1,x
        lda ke_old+1
        sta HATABS+2,x
ku_ret  jmp ke_pop
* ke_find: X = E:'s place in HATABS, C=1 none; A, X, Y saved for ke_pop
ke_find sta ke_sa
        stx ke_sx
        sty ke_sy
        ldx #0
kf1     lda HATABS,x
        cmp #'E'
        beq kf2
        inx
        inx
        inx
        cpx #36
        bcc kf1
        rts
kf2     clc
        rts
ke_pop  lda ke_sa
        ldx ke_sx
        ldy ke_sy
        rts

dv_mode dta b($08,$04,$09)
dv_idx  dta b(0,1,0)

* ---- MALLOC --------------------------------------
* bytbuf = size, X = memory index ($00 main, $02 system extended, $04
* program extended; +$40 page aligned). N=0: addpos = the block, X = the
* index granted. N=1 (X=0): out of memory. The block is freed when the
* program ends (unless it stays resident). The system extended area
* ($02) comes from main memory as on SDX without a USE in EOSSYS.SYS; with
* USE OSRAM or BANKED from sx_ptr (boot.asm applyuse), granted as $02.
* Program extended
* memory ($04): as SDX, from the highest bank down; a block that does not
* fit in the rest of the bank in use takes the next one; 16K at most.
malloc  stx ga_op
        txa
        and #$3F
        cmp #$04
        bne ma_main
        jsr xalloc
        bcs ma_xno
        lda #0
        rts
ma_xno  lda bytbuf+1           ; more than 16K: X=$04, as SDX returns
        cmp #$40
        bcc ma_no
        bne ma_x4
        lda bytbuf
        beq ma_no
ma_x4   ldx #$04
        lda #E_NOMEM
        rts
ma_main cmp #$02               ; system extended with a USE: its own area
        bne ma_m0
        lda sx_ptr+1
        beq ma_m0
        lda #$FF
        sta ma_lim
        lda sx_lim
        sta ma_lim+1
        lda #<sx_ptr
        ldx #>sx_ptr
        jsr ma_take
        bcs ma_no
        ldx #$02
        lda #0
        rts
ma_m0   lda MEMTOP             ; main memory: from MEMLO up to MEMTOP
        sta ma_lim
        lda MEMTOP+1
        sta ma_lim+1
        lda #<MEMLO
        ldx #>MEMLO
        jsr ma_take
        bcs ma_no
        ldx #$00
        lda #0
        rts
ma_no   ldx #0
        lda #E_NOMEM           ; N=1
        rts

* xalloc: bytbuf bytes of program extended memory (ga_op $40: page
* aligned): C=0, addpos, X = the bank's index; C=1 none. As on SDX, NBANKS
* (COMTAB+$1D) counts the banks not used yet; a new bank is the highest of
* them, index NBANKS+3 (programs find their bank as NBANKS+4 after it).
* xb_cur: the bank in use, 0 none.
xalloc  lda bytbuf+1           ; at most 16K
        cmp #$40
        bcc xa1
        bne xa_no
        lda bytbuf
        bne xa_no
xa1     lda xb_cur
        bne xa1a
        jsr xb_new
        bcs xa_no
xa1a    bit ga_op
        bvc xa2
        lda xb_ptr             ; page aligned
        beq xa2
        lda #0
        sta xb_ptr
        inc xb_ptr+1
xa2     clc                    ; the end: at most $8000
        lda xb_ptr
        adc bytbuf
        tay
        lda xb_ptr+1
        adc bytbuf+1
        cmp #$80
        bcc xa4
        bne xa3
        cpy #0
        beq xa4
xa3     jsr xb_new             ; does not fit: a new bank
        bcs xa_no
        jmp xa1a
xa4     tax
        lda xb_ptr
        sta addpos
        lda xb_ptr+1
        sta addpos+1
        sty xb_ptr
        stx xb_ptr+1
        ldx xb_cur
        clc
        rts
xa_no   sec
        rts
* xb_new: the next bank in use, empty; C=1 when there is none
xb_new  lda COMTAB+$1D
        beq xn_no
        dec COMTAB+$1D
        clc
        adc #3
        sta xb_cur
        lda #<$4000
        sta xb_ptr
        lda #>$4000
        sta xb_ptr+1
        clc
        rts
xn_no   sec
        rts

* ma_take: bytbuf bytes from the pointer at AX (MEMLO or sx_ptr), page
* aligned when ga_op has $40, up to ma_lim:
* addpos = the block, the pointer moved on; C=1 when it does not fit
ma_take sta fadr
        stx fadr+1
        ldy #0
        lda (fadr),y
        sta ma_t
        iny
        lda (fadr),y
        sta ma_t+1
        bit ga_op
        bvc mt1
        lda ma_t               ; page aligned
        beq mt1
        lda #0
        sta ma_t
        inc ma_t+1
mt1     clc                    ; the end
        lda ma_t
        adc bytbuf
        sta addpos+2
        lda ma_t+1
        adc bytbuf+1
        bcs mt_no
        tax                    ; up to the limit
        cpx ma_lim+1
        bcc mt_ok
        bne mt_no
        lda addpos+2
        cmp ma_lim
        bcc mt_ok
        beq mt_ok
mt_no   sec
        rts
mt_ok   lda ma_t
        sta addpos
        lda ma_t+1
        sta addpos+1
        ldy #0
        lda addpos+2
        sta (fadr),y
        iny
        txa
        sta (fadr),y
        lda #0
        sta addpos+2
        lda fadr               ; MEMLO: as EOS set it
        cmp #<MEMLO
        bne mt_r
        jsr k_ownml
mt_r    clc
        rts

* ---- FCLOSEAL, FCLEVEL ------------------------------
* FCLOSEAL: close the files opened at the current SYSLEVEL or above
fcloseal ldx #15
fa1     lda dev_index,x
        cmp #$FF
        beq fa2
        lda f_level,x
        cmp SYSLEVEL
        bcc fa2
        stx file_id
        stx fs_y
        ldy #7                 ; kd_close
        jsr jkernel
        ldx fs_y
fa2     dex
        bpl fa1
        inx                    ; X = 0 (MD5.COM passes it to U_FAIL)
        rts

* FCLEVEL: A = the level of file file_id ($FF: FCLOSEAL keeps it)
fclevel ldx file_id
        sta f_level,x
        rts

* ---- text records --------------------------
* FGETS: AX = buffer, Y = its length; Y = bytes read (with the EOL), A = 0,
* N=0. End of file: A = 0, N=1. A longer line: as on SDX, the first
* length-1 bytes and an EOL, the rest of the line skipped, A = $FF, Y =
* the length (N=0).
fgets   sta fadr
        stx fadr+1
        sty fs_len
        dec fs_len             ; room for the EOL
        ldy #0
fs1     cpy fs_len
        bcs fs_over
        jsr fgetc              ; keeps Y
        bmi fs_eof
        sta (fadr),y
        iny
        cmp #EOL
        bne fs1
        lda #0
        rts
fs_eof  lda #0
        ldx #$FF               ; N=1
        rts
fs_over lda #EOL
        sta (fadr),y
fs_skip jsr fgetc              ; the rest of the line
        bmi fs_sk1
        cmp #EOL
        bne fs_skip
fs_sk1  lda #$FF
        ldy fs_len
        iny
        rts

* FPUTS: AX = text, Y = its length; up to and with an EOL
fputs   sta fadr
        stx fadr+1
        sty fs_len
        ldy #0
fp1     cpy fs_len
        bcs fp2
        lda (fadr),y
        jsr fputc
        iny
        cmp #EOL
        bne fp1
fp2     rts

* GETC, GETS, PUTS: FGETC, FGETS, FPUTS on standard input or output;
* file_id is kept, PUTS keeps Y
getc    jsr std_in
        jsr fgetc
        bpl std_end
        jsr dv_eof
std_end php                    ; keeps A, X, Y and the flags
        pha
        lda fs_fid
        sta file_id
        pla
        plp
        rts
gets    jsr std_in
        jsr fgets
        bpl std_end
        cmp #0                 ; the end of the input (not too long a line)
        bne std_e1
        jsr dv_eof
        lda #0
        ldx #$FF               ; N=1
std_e1  jmp std_end
* dv_eof: redirected input ends at its end; keeps A
dv_eof  pha
        tya
        pha
        ldy #1
        jsr xdivio
        pla
        tay
        pla
        rts
puts    sty fs_y
        pha
        lda file_id
        sta fs_fid
        lda COMTAB+6
        sta file_id
        pla
        jsr fputs
        lda fs_fid
        sta file_id
        ldy fs_y
        rts
std_in  pha
        lda file_id
        sta fs_fid
        lda COMTAB+7
        sta file_id
        pla
        rts

* ---- U_GETKEY ----------------------------------------
* A = the key's code, X = bit 7 Control, bit 6 Shift; N=0, Z=0. Break:
* A = 128, N=1.
u_getkey jsr gk_get            ; the OS keyboard handler's get-byte routine
        cpy #128
        bcc gk1
        tya
        rts
gk1     sta gk_a
        lda KBCODE
        and #$C0
        tax
        lda gk_a
        php
        pla
        and #$7D               ; N=0, Z=0
        pha
        lda gk_a
        plp
        rts
gk_get  lda KEYBDV+5
        pha
        lda KEYBDV+4
        pha
        rts

* ---- MUL_32, DIV_32 ---------------------------------
* COMTAB+$FF and COMTAB+$103 (MSB first) multiplied or divided, the result
* (MSB first) to COMTAB+$107. As on SDX the operands serve as work space:
* MUL_32 leaves the first one 0 and returns C=0 (the low 32 bits, overflow
* or not); DIV_32 leaves the remainder and the divisor both shifted left
* until the divisor's bit 31 is set, and returns C=1 only for a divisor 0
* (result 0).
mul_32  jsr md_get
        ldy #32
mu1     lsr md_b+3
        ror md_b+2
        ror md_b+1
        ror md_b
        bcc mu2
        clc
        lda md_r
        adc md_a
        sta md_r
        lda md_r+1
        adc md_a+1
        sta md_r+1
        lda md_r+2
        adc md_a+2
        sta md_r+2
        lda md_r+3
        adc md_a+3
        sta md_r+3
mu2     asl md_a
        rol md_a+1
        rol md_a+2
        rol md_a+3
        dey
        bne mu1
        ldx #3                 ; the first operand: shifted out
        lda #0
mu3     sta COMTAB+$FF,x
        dex
        bpl mu3
md_put  ldx #3
        ldy #0
mp1     lda md_r,x
        sta COMTAB+$107,y
        iny
        dex
        bpl mp1
        clc
        rts
div_32  jsr md_get
        lda md_b               ; dividing by 0: C=1, result 0
        ora md_b+1
        ora md_b+2
        ora md_b+3
        bne dv0
        jsr md_put
        sec
        rts
dv0     ldy #32
dv1     asl md_a               ; quotient bits come in at the right
        rol md_a+1
        rol md_a+2
        rol md_a+3
        rol md_r               ; remainder
        rol md_r+1
        rol md_r+2
        rol md_r+3
        ldx #0
        sec
dv2     lda md_r,x
        sbc md_b,x
        sta md_t,x
        inx
        txa                    ; keeps C
        eor #4
        bne dv2
        bcc dv4
        ldx #3
dv3     lda md_t,x
        sta md_r,x
        dex
        bpl dv3
        inc md_a
dv4     dey
        bne dv1
dv5     bit md_b+3             ; remainder and divisor shifted together
        bmi dv6
        asl md_b
        rol md_b+1
        rol md_b+2
        rol md_b+3
        asl md_r
        rol md_r+1
        rol md_r+2
        rol md_r+3
        jmp dv5
dv6     ldx #3
        ldy #0
dv7     lda md_r,x             ; the operands as they are left
        sta COMTAB+$FF,y
        lda md_b,x
        sta COMTAB+$103,y
        lda md_a,x
        sta md_r,x
        iny
        dex
        bpl dv7
        jmp md_put
md_get  ldx #3
        ldy #0
md1     lda COMTAB+$FF,y
        sta md_a,x
        lda COMTAB+$103,y
        sta md_b,x
        lda #0
        sta md_r,x
        iny
        dex
        bpl md1
        rts

* ---- PRINTF / FPRINTF ---------
*       jsr PRINTF
*       dta c'pattern',0
*       dta a(argument, ...)
* Keeps A, X, Y, file_id and device. FPRINTF writes to the file file_id.
printf  sta pf_a
        lda #0
        beq pf0
fprintf sta pf_a
        lda #$80
        bne pf0
vprintf sta pf_a               ; FPRINTF to handle 100, then file_id back
        lda file_id
        sta pf_vfid
        lda #100
        sta file_id
        lda #$C0
pf0     sta pf_file
        stx pf_x
        sty pf_y
        lda #0
        sta pf_inv
        sta pf_bn
        pla                    ; the pattern follows the jsr
        clc
        adc #1
        sta pf_ptr
        pla
        adc #0
        sta pf_ptr+1
        sta fadr+1             ; the arguments follow its 0
        lda pf_ptr
        sta fadr
        ldy #0
pf1     lda (fadr),y
        beq pf2
        iny
        bne pf1
        inc fadr+1
        bne pf1
pf2     tya
        sec
        adc fadr
        sta pf_arg
        lda fadr+1
        adc #0
        sta pf_arg+1
pf_loop jsr pf_get
        beq pf_end
        cmp #'%'
        beq pf_spec
        cmp #BSLASH
        beq pf_esc
pf_lit  jsr pf_outv
        jmp pf_loop
pf_end  jsr pf_flush
        bit pf_file
        bvc pf_end1
        lda pf_vfid
        sta file_id
pf_end1 lda pf_arg             ; return after the arguments
        sec
        sbc #1
        tax
        lda pf_arg+1
        sbc #0
        pha
        txa
        pha
        ldy pf_y
        ldx pf_x
        lda pf_a
        rts

* backslash sequences
pf_esc  jsr pf_get
        beq pf_end
        ldx #pf_escn-pf_escs-1
pe1     cmp pf_escs,x
        beq pe2
        dex
        bpl pe1
        pha                    ; unknown: both characters as they are
        lda #BSLASH
        jsr pf_outv
        pla
        jmp pf_lit
pe2     lda pf_escv,x
        cpx #pf_inx-pf_escs
        bne pf_lit2
        lda pf_inv             ; i: inverse video on or off
        eor #$80
        sta pf_inv
        jmp pf_loop
pf_lit2 jsr pf_out             ; the code as it is, no inverse
        jmp pf_loop
pf_escs dta c'abefnrtz'
pf_inx  dta c'i'
        dta b(BSLASH)
pf_escn
pf_escv dta b($FD,$7E,$1B,$7D,EOL,EOL,$7F,$00,0,BSLASH)

* % sequences: [0][width|*]type
pf_spec lda #0
        sta pf_zero
        sta pf_w
        jsr pf_get
        cmp #'0'
        bne ps1
        dec pf_zero
        jsr pf_get
ps1     cmp #'*'
        bne ps2
        jsr pf_nextarg         ; the width from a variable
        ldy #0
        lda (fadr),y
        sta pf_w
        jsr pf_get
        jmp ps3
ps2     cmp #'0'
        bcc ps3
        cmp #'9'+1
        bcs ps3
        and #$0F
        pha
        lda pf_w
        asl @
        asl @
        adc pf_w
        asl @
        sta pf_w
        pla
        adc pf_w
        sta pf_w
        jsr pf_get
        jmp ps2
ps3     cmp #0
        jeq pf_end
        ldx #pf_typn-pf_typs-1
ps4     cmp pf_typs,x
        beq ps5
        dex
        bpl ps4
        jmp pf_loop            ; unknown type: dropped, no argument used
ps5     lda pf_typh,x
        pha
        lda pf_typl,x
        pha
        rts
pf_typs dta c'%csxpbdeltX'           ; (%X as %x: SDX's PERCONF uses it)
pf_typn
pf_typl dta l(pt_pc-1,pt_c-1,pt_s-1,pt_x-1,pt_p-1,pt_b-1,pt_d-1,pt_e-1,pt_l-1,pt_t-1,pt_x-1)
pf_typh dta h(pt_pc-1,pt_c-1,pt_s-1,pt_x-1,pt_p-1,pt_b-1,pt_d-1,pt_e-1,pt_l-1,pt_t-1,pt_x-1)

pt_pc   lda #'%'
        jmp pf_lit
pt_c    jsr pf_nextarg
        ldy #0
        lda (fadr),y
        jsr pf_out
        jmp pf_loop
pt_p    jsr pf_nextarg         ; a pointer to the string
        ldy #0
        lda (fadr),y
        tax
        iny
        lda (fadr),y
        stx fadr
        sta fadr+1
        jmp pt_s1
pt_s    jsr pf_nextarg
pt_s1   lda fadr               ; up to EOL or 0; width: cut or pad
        sta pf_sp
        lda fadr+1
        sta pf_sp+1
        lda #0
        sta pf_n
ps_s2   lda pf_sp
        sta fadr
        lda pf_sp+1
        sta fadr+1
        ldy pf_n
        lda (fadr),y
        beq ps_s4
        cmp #EOL
        beq ps_s4
        ldx pf_w
        beq ps_s3
        cpy pf_w
        bcs ps_s5
ps_s3   jsr pf_out
        inc pf_n
        bne ps_s2
ps_s4   lda pf_n               ; pad with spaces
        cmp pf_w
        bcs ps_s5
        lda #' '
        jsr pf_out
        inc pf_n
        bne ps_s4
ps_s5   jmp pf_loop

pt_x    jsr pf_val4            ; hex: width digits (default 6, at most 8)
        lda pf_w
        bne px1
        lda #6
px1     cmp #9
        bcc px2
        lda #8
px2     sta pf_n
px3     dec pf_n
        bmi px5
        lda pf_n
        lsr @
        tax
        lda pf_v,x
        bcc px4                ; even digit: low nibble
        lsr @
        lsr @
        lsr @
        lsr @
px4     and #$0F
        tax
        lda hexdig,x
        jsr pf_out
        jmp px3
px5     jmp pf_loop

pt_b    lda #1
        bne pt_dec
pt_d    lda #2
        bne pt_dec
pt_e    lda #3
        bne pt_dec
pt_l    lda #4
pt_dec  pha
        jsr pf_val4
        pla
        tax                    ; keep only the value's bytes
        lda #0
pd_clr  cpx #4
        bcs pd_go
        sta pf_v,x
        inx
        bne pd_clr
pd_go   jsr dec32              ; digits to pf_dig, count in pf_n
        lda pf_w
        beq pd_all
        cmp #11
        bcc pd_w
        lda #10
pd_w    sta pf_w
        cmp pf_n
        bcs pd_pad
        sec                    ; wider than the field: its last digits
        lda pf_n
        sbc pf_w
        tax
        jmp pd_out
pd_pad  sec
        sbc pf_n
        tax
pd_p1   txa
        beq pd_all
        lda #' '
        bit pf_zero
        bpl pd_p2
        lda #'0'
pd_p2   jsr pf_out
        dex
        jmp pd_p1
pd_all  ldx #0
pd_out  cpx pf_n
        bcs pd_end
        lda pf_dig,x
        jsr pf_out
        inx
        bne pd_out
pd_end  jmp pf_loop

pt_t    jsr pf_nextarg         ; entry number pf_w of a 0 terminated table;
        lda fadr               ; an entry ends at EOL or at a character with
                               ; bit 7 set, shown without it (FASC's text)
        sta pf_sp
        lda fadr+1
        sta pf_sp+1
        ldx pf_w
pt_t1   lda pf_sp
        sta fadr
        lda pf_sp+1
        sta fadr+1
        ldy #0
        lda (fadr),y
        beq pt_t4
        cpx #0
        beq pt_t3
pt_t2   lda (fadr),y           ; skip an entry
        iny
        cmp #$80
        bcc pt_t2
        tya
        clc
        adc pf_sp
        sta pf_sp
        bcc pt_t2a
        inc pf_sp+1
pt_t2a  dex
        jmp pt_t1
pt_t3   lda (fadr),y
        cmp #EOL
        beq pt_t4
        cmp #$80
        bcs pt_t5
        jsr pf_out
        iny
        bne pt_t3
pt_t4   jmp pf_loop
pt_t5   and #$7F               ; the last character
        jsr pf_out
        jmp pf_loop

* pf_get: the next pattern character; Z=1 at its end
pf_get  lda pf_ptr
        sta fadr
        lda pf_ptr+1
        sta fadr+1
        ldy #0
        lda (fadr),y
        beq pg_ret
        inc pf_ptr
        bne pg_ret
        inc pf_ptr+1
pg_ret  cmp #0
        rts

* pf_nextarg: fadr = the next argument (an address)
pf_nextarg lda pf_arg
        sta fadr
        lda pf_arg+1
        sta fadr+1
        ldy #0
        lda (fadr),y
        tax
        iny
        lda (fadr),y
        stx fadr
        sta fadr+1
        clc
        lda pf_arg
        adc #2
        sta pf_arg
        bcc pn1
        inc pf_arg+1
pn1     rts

* pf_val4: the 4 bytes at the next argument to pf_v
pf_val4 jsr pf_nextarg
        ldy #3
pv1     lda (fadr),y
        sta pf_v,y
        dey
        bpl pv1
        rts

* pf_out, pf_outv: a character to the console or the file; pf_outv
* applies the inverse video switch. Keep X and Y.
* pf_out: A to PRINTF's output, kept in pf_buf and written 16 characters at
* a time (pf_flush: at the end); keeps X and Y
pf_outv eor pf_inv
pf_out  stx pf_sx
        ldx pf_bn
        sta pf_buf,x
        inx
        stx pf_bn
        cpx #16
        bcc po_r
        jsr pf_flush
po_r    ldx pf_sx
        rts
pf_flush lda pf_bn
        beq pfl_r
        sty pf_y2
        lda COMTAB+6           ; PRINTF: standard output, FPRINTF: file_id
        bit pf_file
        bpl pfl_1
        lda file_id
pfl_1   cmp #100               ; the magic handle: a character at a time
        bne pfl_k
        ldx #0
pfl_v   stx pf_x2
        lda pf_buf,x
        jsr pc_vec
        ldx pf_x2
        inx
        cpx pf_bn
        bcc pfl_v
        bcs pfl_e
pfl_k   ldx file_id
        stx pc_fid
        sta file_id
        ldx #4
pfl_s   lda addpos,x           ; addpos, bytbuf, memreix
        sta pc_save,x
        dex
        bpl pfl_s
        lda #<pf_buf
        sta addpos
        lda #>pf_buf
        sta addpos+1
        lda pf_bn
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        ldy #1                 ; kd_write
        jsr jkernel
        ldx #4
pfl_r2  lda pc_save,x
        sta addpos,x
        dex
        bpl pfl_r2
        lda pc_fid
        sta file_id
pfl_e   lda #0
        sta pf_bn
        ldy pf_y2
pfl_r   rts

* dec32: pf_v (32 bits) in decimal to pf_dig, pf_n digits (at least 1)
dec32   ldx #10
        lda #0
        sta pf_n
d32_1   lda #0                 ; pf_v /= 10, remainder in A
        ldy #32
d32_2   asl pf_v
        rol pf_v+1
        rol pf_v+2
        rol pf_v+3
        rol @
        cmp #10
        bcc d32_3
        sbc #10
        inc pf_v
d32_3   dey
        bne d32_2
        dex
        ora #'0'
        sta pf_dig,x
        inc pf_n
        lda pf_v
        ora pf_v+1
        ora pf_v+2
        ora pf_v+3
        bne d32_1
        txa                    ; move the digits to the start
        beq d32_5
        ldy #0
d32_4   lda pf_dig,x
        sta pf_dig,y
        inx
        iny
        cpx #10
        bcc d32_4
d32_5   rts

hexdig  dta c'0123456789ABCDEF'

* ---- U_GETNUM: the next parameter as a decimal or $hex number ----------------
* Z=1: none, or not a number (BUFOFF unchanged). Else A, X = low word and
* COMTAB-6 ... COMTAB-3 (divend) the whole 32-bit value.
u_getnum lda BUFOFF
        sta gn_off
        jsr u_getpar
        beq gnm_no
        ldy #0
        jsr numat
        bcs gnm_bad
        lda COMFNAM,y
        cmp #EOL
        bne gnm_bad
        lda COMTAB-6
        ldx COMTAB-5
        ldy #1                 ; Z=0
        rts
gnm_bad lda gn_off
        sta BUFOFF
gnm_no  lda #0
        rts

* numat: the decimal or $hex number at COMFNAM+Y to divend, Y after it;
* C=1 when there are no digits
numat   lda #0
        ldx #3
na1     sta COMTAB-6,x
        dex
        bpl na1
        lda COMFNAM,y
        cmp #'$'
        beq na_hex
        jsr isdigit
        bcs na_ret
na_d    and #$0F               ; decimal: value = value * 10 + digit
        sta gn_d
        jsr mul10
        jsr adddig
        iny
        lda COMFNAM,y
        jsr isdigit
        bcc na_d
        clc
na_ret  rts
na_hex  iny                    ; hex: value = value * 16 + digit
        lda COMFNAM,y
        jsr hexval
        bcs na_ret
na_h1   sta gn_d
        ldx #4
na_h2   asl COMTAB-6
        rol COMTAB-5
        rol COMTAB-4
        rol COMTAB-3
        dex
        bne na_h2
        jsr adddig
        iny
        lda COMFNAM,y
        jsr hexval
        bcc na_h1
        clc
        rts

* ---- U_GETADR ---------------------------------------
* The next parameter as an address: [index:]number or symbol, then an
* optional +n or -n on the low word. Z=1: none or not an address. C=0: AX
* the address, Y the memory index; C=1: AX the low word, Y bits 16-23.
* As SDX 4.50: a symbol with +n or -n right after a symbol alone (PARSE A
* COMTAB COMTAB+3) is not an address, and is left for U_GETPAR.
u_getadr lda ga_sym
        sta ga_prev
        lda #0
        sta ga_sym
        lda BUFOFF
        sta gn_off
        jsr u_getpar
        jeq gnm_no
        lda #0
        sta ga_idx
        sta ga_hasi
        ldy #0
        jsr numat              ; index:
        bcs gad1
        lda COMFNAM,y
        cmp #':'
        bne gad1
        lda COMTAB-6
        sta ga_idx
        dec ga_hasi
        iny
        bne gad2
gad1    ldy #0
gad2    lda COMFNAM,y
        cmp #'$'
        beq gad_n
        jsr isdigit
        bcs gad_sym
gad_n   jsr numat
        jcs gnm_bad
        bcc gad_ofs
gad_sym ldx #0                 ; a symbol name, space padded
gs1     lda COMFNAM,y
        cmp #EOL
        beq gs2
        cmp #'+'               ; +n or -n after the name
        beq gs2
        cmp #'-'
        beq gs2
        cpx #8
        jcs gnm_bad
        sta ld_name,x
        iny
        inx
        bne gs1
gs2     cpx #0
        jeq gnm_bad
        lda #' '
gs3     cpx #8
        bcs gs4
        sta ld_name,x
        inx
        bne gs3
gs4     lda COMFNAM,y          ; an offset right after a symbol alone: no
        cmp #'+'
        beq gs4a
        cmp #'-'
        bne gs4b
gs4a    bit ga_prev
        jmi gnm_bad
        bpl gs4c
gs4b    lda #$80               ; a symbol alone
        sta ga_sym
gs4c    sty ga_y
        jsr farcall
        dta b(BK_LD),a(LD_LOOKUP)
        jcs gnm_no             ; no such symbol: the parameter is used up
        ldy ga_y
        lda ld_val
        sta COMTAB-6
        lda ld_val+1
        sta COMTAB-5
        lda #0
        sta COMTAB-4
        sta COMTAB-3
gad_ofs lda COMFNAM,y          ; +n, -n on the low word; anything else
        cmp #'+'               ; after the number is ignored (SDX: PEEK 1X
        beq gad_o1             ; is PEEK 1)
        cmp #'-'
        bne gad_ok
gad_o1  sta ga_op
        lda COMTAB-6
        pha
        lda COMTAB-5
        pha
        lda COMTAB-4
        pha
        iny
        jsr numat
        lda COMTAB-6
        sta ga_n
        lda COMTAB-5
        sta ga_n+1
        pla
        sta COMTAB-4
        lda #0
        sta COMTAB-3
        pla
        sta COMTAB-5
        pla
        sta COMTAB-6
        jcs gnm_bad
        lda COMFNAM,y
        cmp #EOL
        jne gnm_bad
        lda ga_op
        cmp #'+'
        bne gad_sub
        clc
        lda COMTAB-6
        adc ga_n
        sta COMTAB-6
        lda COMTAB-5
        adc ga_n+1
        sta COMTAB-5
        jmp gad_ok
gad_sub sec
        lda COMTAB-6
        sbc ga_n
        sta COMTAB-6
        lda COMTAB-5
        sbc ga_n+1
        sta COMTAB-5
gad_ok  ldy ga_idx             ; C: above 64K without an index
        lda #0
        bit ga_hasi
        bmi gad_c
        lda COMTAB-4
        ora COMTAB-3
        beq gad_c
        ldy COMTAB-4
        lda #1
gad_c   sta ga_op
        sty ga_y
        php
        pla
        and #$FC               ; Z=0, C from ga_op
        ora ga_op
        pha
        lda COMTAB-6
        ldx COMTAB-5
        ldy ga_y
        plp
        rts

* ---- _CRUNCH, ZCRNAME at COMTAB+3 ----
* The next parameter from LBUF to COMFNAM as Dd:rest, the device given or
* the current one (D1:FOO, D2:X for B:X, DJ: for drive 10, DCAR1:W, D4: for
* D:), FILLEN its length. Z=1 when nothing follows the device (also when no
* parameter is left: COMFNAM is the current drive alone). BUFOFF stays at a
* following space, a comma is passed, as on SDX.
crunch  ldy BUFOFF
cr1     lda LBUF,y
        cmp #' '
        beq cr2
        cmp #','
        bne cr3
cr2     iny
        bne cr1
cr3     ldx #0                 ; the parameter to ge_rawp
cr4     lda LBUF,y
        cmp #' '
        beq cr5
        cmp #','
        beq cr5
        cmp #EOL
        beq cr5
        sta ge_rawp,x
        iny
        inx
        cpx #26
        bcc cr4
cr5     cmp #','
        bne cr6
        iny
cr6     sty BUFOFF
        lda #EOL
        sta ge_rawp,x
        lda #<ge_rawp          ; a device before a colon?
        sta fadr
        lda #>ge_rawp
        sta fadr+1
        ldy #0
cr7     lda ge_rawp,y
        jsr isalnum
        bcs cr8
        iny
        cpy #6
        bcc cr7
cr8     cmp #':'
        bne cr_cur
        jsr parsedev
        bcc cr9
cr_cur  lda CURDEV             ; none (or not a device): the current one
        ldy #$FF
cr9     sta ga_op              ; the device, Y at its colon
        sty ga_y
        lda #'D'
        sta COMFNAM
        ldx #1
        lda ga_op
        cmp #$10
        bcs cr_dev
        and #$0F               ; a drive: 1-9, J-O
        cmp #10
        bcc cr_dig
        adc #'A'-2             ; C=1: 10 is J
        bne cr_put
cr_dev  lsr @                  ; another device: its name and unit, but
        lsr @                  ; PRN and CON become P and E (the CIO
        and #$3C               ; devices: P1:, E1:)
        tay
        sty ga_n
        ldx #3
cr_m1   lda DEVNAME,y
        cmp cr_map,x
        bne cr_m3
        lda DEVNAME+1,y
        cmp cr_map+1,x
        bne cr_m3
        lda DEVNAME+2,y
        cmp cr_map+2,x
        bne cr_m3
        txa                    ; found: one letter, at COMFNAM+0
        lsr @
        tax
        lda cr_one,x
        ldx #0
        sta COMFNAM,x
        inx
        bne cr_unit
cr_m3   dex
        dex
        dex
        bpl cr_m1
        ldx #1
cr10    lda DEVNAME,y
        sta COMFNAM,x
        inx
        iny
        tya
        and #3
        cmp #3
        bne cr10
cr_unit lda ga_op
        and #$0F
cr_dig  ora #'0'
cr_put  sta COMFNAM,x
        inx
        lda #':'
        sta COMFNAM,x
        inx
        ldy ga_y               ; the rest after the colon
        iny
        stx ga_n
cr11    lda ge_rawp,y
        sta COMFNAM,x
        cmp #EOL
        beq cr12
        iny
        inx
        bne cr11
cr12    stx FILLEN
        cpx ga_n               ; Z=1: nothing after the device
        rts

cr_map  dta c'PRNCON'
cr_one  dta c'P',c'E'

* ---- U_PARAM (5.17): the next parameter, as typed, to copybuf (COMTAB+$BF,
* EOL ended, empty when there is none); BUFOFF past the spaces and commas
* after it. Z=0.
u_param ldy BUFOFF
ua1     lda LBUF,y
        cmp #' '
        beq ua2
        cmp #','
        bne ua3
ua2     iny
        bne ua1
ua3     ldx #0
ua4     lda LBUF,y
        cmp #' '
        beq ua5
        cmp #','
        beq ua5
        cmp #EOL
        beq ua5
        sta COMTAB+$BF,x
        iny
        inx
        cpx #63
        bcc ua4
ua5     lda #EOL
        sta COMTAB+$BF,x
ua6     lda LBUF,y             ; past the separators
        cmp #' '
        beq ua7
        cmp #','
        bne ua8
ua7     iny
        bne ua6
ua8     sty BUFOFF
        lda #1                 ; Z=0
        rts

* ---- PRO_NAME (6.2): the name at (bufadr)+Y+1 to name, 8+3 ('*' fills with
* '?', longer parts cut); it ends at EOL, a space, a comma or a path
* separator. A = that character, Y = its offset; Z=1 when name is blank.
pro_name ldx #10
        lda #' '
pq1     sta name,x
        dex
        bpl pq1
        ldx #0
        lda #8
        sta ge_lim
pq2     iny
        lda (fadr),y
        cmp #EOL
        beq pq_end
        cmp #' '
        beq pq_end
        cmp #','
        beq pq_end
        jsr ckspec
        beq pq_end
        cmp #'.'
        beq pq_dot
        cmp #'*'
        beq pq_star
        cpx ge_lim
        bcs pq2
        sta name,x
        inx
        bne pq2
pq_star lda #'?'
pq_s1   cpx ge_lim
        bcs pq2
        sta name,x
        inx
        bne pq_s1
pq_dot  ldx #8                 ; the extension
        lda #11
        sta ge_lim
        bne pq2
pq_end  pha
        ldx #10                ; Z: name blank
pq3     lda name,x
        cmp #' '
        bne pq4
        dex
        bpl pq3
pq4     inx                    ; X+1 = 0 when blank
        stx ge_n
        pla
        ldx ge_n
        rts

* ---- U_GETFLG (5.16): FLAG from the next parameter, which is used up, as
* on SDX: a number (C=1); S A I N, $00 $40 $C0 $80, anything else $04 (C=0).
* No parameter: FLAG = A (C=1). A = FLAG on return.
u_getflg sta FLAG
        jsr u_getpar
        beq gf_end
        ldy #0
        jsr numat
        bcs gf_let
        lda COMFNAM,y
        cmp #EOL
        bne gf_let
        lda COMTAB-6           ; a number: N=0, Z=0, C=1
        sta FLAG
        php
        pla
        and #$7D
        ora #$01
        pha
        lda FLAG
        plp
        rts
gf_end  lda FLAG
        sec
        rts
gf_let  lda COMFNAM+1          ; one of the letters alone: C=1
        cmp #EOL
        bne gf_no
        ldx #3
        lda COMFNAM
gf1     cmp gf_lets,x
        beq gf2
        dex
        bpl gf1
gf_no   lda #$04               ; anything else: $04, C=0
        sta FLAG
        clc
        rts
gf2     lda gf_val,x
        sta FLAG
        sec
        rts
gf_lets dta c'SAIN'
gf_val  dta b($00,$40,$C0,$80)

* ---- U_GONOFF (5.7): the next parameter ON (C=1) or OFF (C=0), else 156 ---
u_gonoff jsr u_getpar
        beq go_bad
        ldx #2
go1     lda COMFNAM,x          ; ON
        cmp go_on,x
        bne go2
        dex
        bpl go1
        sec
        rts
go2     ldx #3
go3     lda COMFNAM,x          ; OFF
        cmp go_off,x
        bne go_bad
        dex
        bpl go3
        clc
        rts
go_bad  lda #156
        jmp u_fail
go_on   dta c'ON',b(EOL)
go_off  dta c'OFF',b(EOL)

* ---- U_TOKEN (5.9): COMFNAM in the keyword table at AX (last character of
* each with bit 7, $00 at the end): C=1, A = its number; C=0 none (A = the
* number of keywords, as on SDX)
u_token sta fadr
        stx fadr+1
        lda #0
        sta ga_n
        ldy #0
tk1     ldx #0
        lda (fadr),y
        beq tk_no
tk2     lda (fadr),y
        and #$7F
        cmp COMFNAM,x
        bne tk_skip
        lda (fadr),y
        iny
        inx
        asl @
        bcc tk2
        lda COMFNAM,x          ; the whole parameter
        cmp #EOL
        bne tk_next
        lda ga_n
        sec
        rts
tk_skip lda (fadr),y           ; to the end of this keyword
        iny
        asl @
        bcc tk_skip
tk_next inc ga_n
        bne tk1
tk_no   lda ga_n
        clc
        rts

hexval  jsr isdigit
        bcc hv_dig
        cmp #'A'
        bcc hv_no
        cmp #'F'+1
        bcs hv_no
        sbc #'A'-11            ; C=0: -('A'-10)
        clc
        rts
hv_dig  and #$0F
        clc
        rts
hv_no   sec
        rts

* mul10: divend *= 10
mul10   ldx #3
m10_1   lda COMTAB-6,x
        sta gn_t,x
        dex
        bpl m10_1
        jsr shl_dv             ; * 2
        jsr shl_dv             ; * 4
        clc
        ldx #0
        php
m10_2   plp
        lda COMTAB-6,x         ; * 5
        adc gn_t,x
        sta COMTAB-6,x
        php
        inx
        cpx #4
        bcc m10_2
        plp
shl_dv  asl COMTAB-6
        rol COMTAB-5
        rol COMTAB-4
        rol COMTAB-3
        rts

* adddig: divend += gn_d
adddig  clc
        lda COMTAB-6
        adc gn_d
        sta COMTAB-6
        bcc ad_ret
        inc COMTAB-5
        bne ad_ret
        inc COMTAB-4
        bne ad_ret
        inc COMTAB-3
ad_ret  rts

* ---- U_SLASH: /options of the command line -------------------------------
* AX: table of (flag, character) pairs, Y: its size in bytes. Every flag is
* set to 0, then decremented for each time its option is given. An option
* not in the table fails with 156.
u_slash sta fadr
        stx fadr+1
        sty sl_n
        lda #0
        tay
sl0     cpy sl_n
        bcs sl1
        sta (fadr),y
        iny
        iny
        bne sl0
sl1     ldx BUFOFF             ; the next parameter
sl2     lda LBUF,x
        cmp #' '
        beq sl3
        cmp #','
        bne sl4
sl3     inx
        bne sl2
sl4     cmp #'/'               ; /X...: letters up to a blank, a comma or the
        bne sl_ret             ; EOL; a / alone is nothing (SDX: /W/C, //W
        inx                    ; and /W/ fail with 156)
        lda LBUF,x
        jsr sl_sep
        beq sl_end
        bne sl5a
sl5     inx
        lda LBUF,x
        jsr sl_sep
        beq sl_end
sl5a    cmp #'/'
        beq sl_bad
        jsr toupper
        ldy #1
sl6     cpy sl_n
        bcs sl_bad
        cmp (fadr),y
        beq sl7
        iny
        iny
        bne sl6
sl7     dey
        pha
        lda (fadr),y
        sec
        sbc #1
        sta (fadr),y
        pla
        jmp sl5
sl_end  stx BUFOFF
        jmp sl1
sl_ret  stx BUFOFF             ; (past the blanks: the next parameter)
        rts
sl_bad  lda #156
        jmp u_fail
sl_sep  cmp #' '               ; Z=1: a blank, a comma or the EOL
        beq sp_ret
        cmp #','
        beq sp_ret
        cmp #EOL
sp_ret  rts

* toupper: a-z to A-Z
toupper cmp #'a'
        bcc tu_ret
        cmp #'z'+1
        bcs tu_ret
        and #$DF
tu_ret  rts

* CKSPEC (14.3): Z=1 when A is a path separator : > backslash <
ckspec  cmp #':'
        beq ck_ret
        cmp #'>'
        beq ck_ret
        cmp #BSLASH
        beq ck_ret
        cmp #'<'
ck_ret  rts

* U_FSPEC (5.14): a parameter in COMFNAM that ends with a separator gets
* the mask *.*, FILLEN follows
u_fspec ldx FILLEN
        beq fsp_ret
        lda COMFNAM-1,x
        jsr ckspec
        bne fsp_ret
        ldy #0
fsp1    lda fsp_all,y
        sta COMFNAM,x
        inx
        iny
        cpy #4
        bcc fsp1
        dex
        stx FILLEN
fsp_ret rts
fsp_all dta c'*.*',b(EOL)

* U_PATH (6.4): device and path back to text at AX+Y, EOL ended; Y = the
* EOL's offset. The device: a drive's name (A: ... O:, or Dn: when CIO has
* a device with its letter: drvname), else, as on SDX, the first letter
* of the device's name (C: for CAR:). $FF is left out.
u_path  sta fadr
        stx fadr+1
        lda device
        cmp #$FF
        beq up_path
        cmp #$10
        bcs up_dev
        jsr drvname            ; a drive: its letter, or Dn: (drvname)
        ldx #0
up_dn   lda dv_nm,x
        cmp #EOL
        beq up_path
        sta (fadr),y
        iny
        inx
        bne up_dn
up_dev  lsr @                  ; another device: its name's first letter
        lsr @
        and #$3C
        tax
        lda DEVNAME,x
        cmp #' '
        bne up_col
        lda #E_NODEV
        jmp u_fail
up_col  sta (fadr),y
        iny
        lda #':'
        sta (fadr),y
        iny
up_path ldx #0
up1     lda path,x
        beq up2
        cmp #EOL
        beq up2
        sta (fadr),y
        inx
        iny
        cpx #64
        bcc up1
up2     lda #EOL
        sta (fadr),y
        rts

* U_PERROR (4.4): the message for the error Y, EOL ended, to AX
u_perror sta fadr
        stx fadr+1
        tya
        pha
        lda fadr
        pha
        lda fadr+1
        pha
        tya
        jsr err_gmsg           ; to uf_buf, 0 ended
        pla
        sta fadr+1
        pla
        sta fadr
        ldy #0
pe_1    lda uf_buf,y
        beq pe_2
        sta (fadr),y
        iny
        cpy #63
        bcc pe_1
pe_2    lda #EOL
        sta (fadr),y
        pla
        tay
        rts

* XRWMEM (3.7.2): a byte at addpos+Y of memory X, C=0 read to A, C=1 write
* A; keeps X and Y (and A when writing). Memory 0 is main RAM, 2 the RAM
* under the OS ROM, 4 and up the banks. C=1: no such memory.
xrwmem  sta xr_a
        stx xr_x
        php
        lda addpos
        sta fadr
        lda addpos+1
        sta fadr+1
        txa
        beq xr_in
        cmp #2
        beq xr_on
        cmp #4
        bcc xr_bad
        sbc #4                 ; C=1
        cmp xb_n
        bcs xr_bad
        txa
xr_on   jsr k_setme
xr_in   plp
        bcs xr_w
        lda (fadr),y
        sta xr_a
        bcc xr_end
xr_w    lda xr_a
        sta (fadr),y
xr_end  lda xr_x
        beq xr_e1
        jsr k_popme
xr_e1   ldx xr_x
        lda xr_a
        clc
        rts
xr_bad  plp
        ldx xr_x
        lda xr_a
        sec
        rts

* ---- U_FAIL: print the error message, back to the command processor -------
u_fail  sta uf_err
        ldx tr_n               ; a trap set: back to the program's handler
        beq uf_msg
        dex
        stx uf_t
uf_lv   lda SYSLEVEL           ; set at a lower level: end the levels above
        beq uf_tr              ; (their traps were set from ld_trap on)
        tay
        lda ld_trap-1,y
        cmp uf_t
        beq uf_tr
        bcc uf_tr
        jsr farcall
        dta b(BK_LD),a(LD_UNLOAD)
        jmp uf_lv
uf_tr   ldx uf_t
        stx tr_n
        lda tr_lo,x
        sta ke_adr
        lda tr_hi,x
        sta ke_adr+1
        lda tr_bank,x
        pha
        lda tr_sp,x
        tax
        pla
        txs
        jmp k_trap
uf_msg  cmp #2                 ; ERRNO: the last error or exit code (2 and
        bcc uf_e0              ; up) that no trap caught, never cleared
        sta ERRNO
uf_e0   cmp #128               ; a code below 128 is a status for the
        bcs uf_err1            ; parent: the program ends as by an RTS
        ldx SYSLEVEL
        beq uf_quit
        sta STATUS
        ldx ke_sp
        txs
        jmp k_ret
uf_err1 sta cp_fail            ; for the command processor (batch files)
        pha
        ldy #0                 ; messages go to the screen, not to a
        jsr xdivio             ; redirected output (SDX)
        pla
        cmp #170               ; a program from the command line fails with
        bne uf_e3              ; 170: SDX names it first ("File X.COM")
        ldx SYSLEVEL
        beq uf_e3
        jsr cmdfile
        lda #170
uf_e3   jsr u_error
uf_quit jmp (DOSVEC)

* cmdfile: "File " and CMDNAME (taken: it is printed once)
cmdfile jsr k_romoff
        ldx #0
cf1     lda CMDNAME,x
        sta uf_buf,x
        inx
        cmp #EOL
        bne cf1
        lda #EOL
        sta CMDNAME
        jsr k_romon
        lda uf_buf
        cmp #EOL
        beq cf_ret
        lda #EOL               ; on a line of its own, a blank line after it
        jsr putc               ; (u_error's EOL)
        ldx #0
cf2     lda ld_file5,x
        jsr putc
        inx
        cpx #5
        bcc cf2
        ldx #0
cf3     lda uf_buf,x
        cmp #EOL
        beq cf_eol
        stx uf_x
        jsr putc
        ldx uf_x
        inx
        bne cf3
cf_eol  jmp putc
cf_ret  rts
ld_file5 dta c'File '

* U_ERROR: EOL, the message for error A, EOL
u_error pha
        lda #EOL
        jsr putc
        pla
        jsr err_dmsg
        lda #EOL
        jmp putc

* ERR_DMSG: the message for error A ("170 File not found"), no EOLs
err_dmsg jsr err_gmsg
        stx fadr
        sty fadr+1
        ldy #0
ed1     lda (fadr),y
        beq ed2
        jsr putc
        iny
        bne ed1
ed2     rts

* ERR_GMSG: the message for error A to a buffer, 0 terminated; its address
* in X (low) and Y (high)
err_gmsg sta uf_err
        ldx #0
        jsr gm_dec
        lda #' '
        sta uf_buf,x
        inx
        stx uf_x
        lda #<errtab           ; find the message: code, text, 0
        sta fadr
        lda #>errtab
        sta fadr+1
        ldy #0
uf1     lda (fadr),y
        beq uf_none
        cmp uf_err
        beq uf3
uf2     jsr uf_inc
        lda (fadr),y
        bne uf2
        jsr uf_inc
        jmp uf1
uf_none lda #<syserr
        sta fadr
        lda #>syserr
        sta fadr+1
        bne uf3a               ; (always)
uf3     jsr uf_inc
uf3a    ldx uf_x
uf4     lda (fadr),y
        sta uf_buf,x
        beq uf5
        inx
        jsr uf_inc
        jmp uf4
uf5     ldx #<uf_buf
        ldy #>uf_buf
        rts
uf_inc  inc fadr
        bne uf_i1
        inc fadr+1
uf_i1   rts

* gm_dec: uf_err in decimal to uf_buf+X
gm_dec  lda uf_err
        ldy #0
gd1     cmp #100
        bcc gd2
        sbc #100
        iny
        bne gd1
gd2     pha
        tya
        beq gd3
        ora #'0'
        sta uf_buf,x
        inx
gd3     pla
        ldy #0
gd4     cmp #10
        bcc gd5
        sbc #10
        iny
        bne gd4
gd5     pha
        tya                    ; no leading zero: 1, 99, 105
        bne gd6
        lda uf_err
        cmp #100
        bcc gd7
        lda #0
gd6     ora #'0'
        sta uf_buf,x
        inx
gd7     pla
        ora #'0'
        sta uf_buf,x
        inx
        rts

* U_SFAIL: a trap at AX, for errors in what follows the call
u_sfail stx uf_x
        ldx tr_n
        cpx #NTRAP
        bcs us_ret             ; too many: the oldest stay
        sta tr_lo,x
        lda uf_x
        sta tr_hi,x
        lda curbank
        sta tr_bank,x
        stx uf_x
        tsx                    ; the caller's stack after the return
        inx
        inx
        txa
        ldx uf_x
        sta tr_sp,x
        inc tr_n
us_ret  rts

* XCOMLI: the command line in LBUF run by the command processor as if
* typed at the prompt, then back to the caller (XT, Sparta Commander's batch
* manager: SDX 4.4x has it, XCOMLI.SYS gives it to older ones). A = Y = 1;
* an error: its code, N=1 (128 and up shown, as at the prompt)
xcomli  lda cp_xone            ; an XCOMLI line running already (XT XT
        pha                    ; ECHO): its state kept on the stack, below
        lda cp_osp             ; the trap, and back when this one ends
        pha
        lda cp_olv
        pha
        lda #<xc_err
        ldx #>xc_err
        jsr u_sfail
        jsr farcall
        dta b(BK_CP),a(CARTLO+$0C)
        jsr u_xfail
        lda #1
        bne xc_back
xc_err  jsr farcall            ; (the trap is gone, the levels above ended)
        dta b(BK_CP),a(CARTLO+$0F)
        lda uf_err
        cmp #128
        bcc xc_back
        sta cp_fail
        jsr u_error
        lda uf_err
xc_back tay                    ; (A = Y: the status)
        pla
        sta cp_olv
        pla
        sta cp_osp
        pla
        sta cp_xone
        tya
        rts

* VALIDATE: the date and time at $077B (day, month, year; hour, minute,
* second) checked, A bit 0 the date, bit 1 the time: C=1 when one is not
* valid (ARCLOCK.SYS: a clock that lost its setting is set to 1-1-2000)
validate pha
        lsr @
        bcc va_t
        ldx date+1             ; the month, 1-12
        beq va_bad
        cpx #13
        bcs va_bad
        lda date               ; the day, 1 up to the month's days
        beq va_bad
        cmp va_days-1,x
        bcs va_bad
        cpx #2                 ; February 29th: a leap year (2000-2099)
        bne va_t
        cmp #29
        bne va_t
        lda date+2
        and #3
        bne va_bad
va_t    pla
        and #2
        beq va_ok
        lda date+3             ; hour, minute, second
        cmp #24
        bcs va_no
        lda date+4
        cmp #60
        bcs va_no
        lda date+5
        cmp #60
        bcs va_no
va_ok   clc
        rts
va_bad  pla
va_no   sec
        rts
va_days dta b(32,30,32,31,32,31,32,32,31,32,31,32) ; (days + 1)

* U_XFAIL: remove the trap set last; keeps A, X, Y and the flags
u_xfail php
        pha
        lda tr_n
        beq ux1
        dec tr_n
ux1     pla
        plp
        rts

* ---- U_EXPAND: name (8+3) as NAME.EXT and EOL at AX + Y; Y = the EOL.
* ?s up to the end of the name or of the extension come out as one * (as
* on SDX: Sparta Commander shows its mask ????????.??? as *.*) ----
u_expand sta fadr
        stx fadr+1
        ldx #0
        lda #8
        jsr ue_fld
        lda name+8
        cmp #' '
        beq ue4
        lda #'.'
        sta (fadr),y
        iny
        ldx #8
        lda #11
        jsr ue_fld
ue4     lda #EOL
        sta (fadr),y
        rts
* ue_fld: name+X .. name+A-1 without its blanks; trailing ?s as *
ue_fld  sta ue_end
        stx ue_st
        tax
uef1     cpx ue_st
        beq uef2
        lda name-1,x
        cmp #'?'
        bne uef2
        dex
        jmp uef1
uef2     stx ue_q
        ldx ue_st
uef3     cpx ue_q
        bcs uef4
        lda name,x
        cmp #' '
        beq uef3a
        sta (fadr),y
        iny
uef3a    inx
        bne uef3
uef4     lda ue_q
        cmp ue_end
        beq uef5
        lda #'*'
        sta (fadr),y
        iny
uef5     rts

* ---- U_GETATR: +X / -X attribute parameters, then a file name ------------
* A: the default search mask; out: scan, and the name as U_GETPAR gives it
* (Z=1: no name). P H A S are bits 0-3 (only) and 4-7 (not).
u_getatr sta scan
ga1     ldy BUFOFF
ga2     lda LBUF,y
        cmp #' '
        beq ga3
        cmp #','
        bne ga4
ga3     iny
        bne ga2
ga4     cmp #'+'
        beq ga5
        cmp #'-'
        bne ga_name
ga5     sta ga_sign
ga6     iny
        lda LBUF,y
        jsr toupper
        ldx #3
ga7     cmp ga_letters,x
        beq ga8
        dex
        bpl ga7
        sty BUFOFF             ; the end of this parameter
        jmp ga1
ga8     lda ga_bits,x          ; +: set "only", clear "not"; -: the opposite
        ldx ga_sign
        cpx #'+'
        beq ga9
        asl @
        asl @
        asl @
        asl @
ga9     sta ga_set
        ora scan
        sta scan
        lda ga_set             ; the other half of the pair
        cpx #'+'
        bne ga10
        asl @
        asl @
        asl @
        asl @
        jmp ga11
ga10    lsr @
        lsr @
        lsr @
        lsr @
ga11    eor #$FF
        and scan
        sta scan
        jmp ga6
ga_name jmp u_getpar
ga_letters dta c'PHAS'
ga_bits dta b($01,$02,$04,$08)

* ---- jmisc ($0709): the misc_ interface -----
* A = function
misc    cmp #4
        bne mi1
        jsr farcall            ; 4 misc_formdir
        dta b(BK_LIB2),a(L2_FORM)
        rts
mi1     cmp #1
        bne mi_ret
* 1 misc_gefina: U_GEFINA on copybuf (COMTAB+$BF); device = $FF on error
        lda FILE_P
        pha
        lda FILE_P+1
        pha
        lda #<(COMTAB+$BF)
        sta FILE_P
        lda #>(COMTAB+$BF)
        sta FILE_P+1
        jsr gefina
        bcc mg1
        lda #$FF
        sta device
mg1     pla
        sta FILE_P+1
        pla
        sta FILE_P
mi_ret  rts

* prdec: A in decimal
prdec   ldx #0
pd1     cmp #100
        bcc pd2
        sbc #100
        inx
        bne pd1
pd2     pha
        txa
        beq pd3
        ora #'0'
        jsr putc
pd3     pla
        ldx #0
pd4     cmp #10
        bcc pd5
        sbc #10
        inx
        bne pd4
pd5     pha
        txa
        ora #'0'
        jsr putc
        pla
        ora #'0'
        jmp putc

* error messages
errtab  dta 128,c'User break abort',0
        dta 129,c'File already open',0
        dta 130,c'Nonexistent device',0
        dta 131,c'File is write-only',0
        dta 132,c'No device handler installed',0
        dta 133,c'File not open',0
        dta 134,c'Bad file handle',0
        dta 135,c'File is read-only',0
        dta 136,c'End Of File',0
        dta 137,c'Truncated record',0
        dta 138,c'Device does not respond',0
        dta 139,c'Device NAK',0
        dta 140,c'SIO framing error',0
        dta 141,c'Cursor out of range',0
        dta 142,c'SIO overrun',0
        dta 143,c'SIO checksum error',0
        dta 144,c'Write protected or bad sector',0
        dta 146,c'Function not implemented',0
        dta 148,c'Unknown filesystem',0
        dta 150,c'Path not found',0
        dta 151,c'File exists',0
        dta 152,c'Not binary file',0
        dta 154,c'Symbol not defined',0
        dta 156,c'Bad parameter',0
        dta 158,c'Out of memory',0
        dta 161,c'Too many channels open',0
        dta 162,c'Disk full',0
        dta 163,c'Illegal wildcard in name',0
        dta 165,c'Bad filename',0
        dta 166,c'Range error',0
        dta 167,c'Directory not empty',0
        dta 169,c'Directory full',0
        dta 170,c'File not found',0
        dta 176,c'Access denied',0
        dta 179,c'Memory conflict',0
        dta 181,c'File system corrupt',0
        dta 182,c'Path too long',0
        dta 183,c'Environment full',0
        dta 184,c'Wrong architecture',0
        dta 185,c'Bad symlink',0
        dta 0
syserr  dta c'System error',0

        icl 'tail.icl'
