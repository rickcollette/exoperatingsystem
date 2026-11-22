* EOS (Extendable Operating System): bank 3, command processor
*
* As SDX 4.5's COMMAND.COM behaves (checked on real SDX, PROGRESS.md C1):
* - batch files: -NAME parms runs NAME.BAT; %0 is its name, %1-%9 the
*   parameters, kept in variables _01, _11 ... _91 (uppercase) until the
*   batch file ends; a line starting with ; (blanks before it allowed) is a
*   comment; a batch file called from another ends the first one; $BATCH,
*   looked at before every line, is run as a batch file and deleted;
* - $NAME and $NAME$ in a line are replaced by the variable's value (left
*   as typed when there is none), a backslash before $ makes it a $;
* - errors: an error of the command processor's own commands with code 130
*   or 156 ends the batch file, others do not, nor do programs' errors;
*   with ERROR ON any error ends it (and its message is shown again);
* - commands: the current directory first, then each $PATH entry (B0b:
*   SDX looks along $PATH first; EOS keeps the user's order).

        icl 'equ.icl'
        icl 'kernel.icl'

        opt h-f+

E_BADPARM equ 156
E_NODEV equ 130
E_NOTFOUND equ 170
E_PATHLEN equ 182

COMFNAM equ COMTAB+CT_COMFNAM
BUFOFF  equ COMTAB+CT_BUFOFF
LBUF    equ COMTAB+CT_LBUF
FILLEN  equ COMTAB+CT_FILLEN
        org CARTLO
        jmp cp_main            ; $A000 enter from DOSVEC (k_cp)
        jmp rdcmd              ; $A003 RAMDISK (_EOSDRV 3, CAR:RAMDISK.SYS)
        jmp clk_rt             ; $A006 RTIME8 (_EOSDRV 4, CAR:RTIME8.SYS)
        jmp clk_jf             ; $A009 JIFFY (_EOSDRV 5, CAR:JIFFY.SYS)
        jmp cp_one             ; $A00C XCOMLI: one line, back to the caller
        jmp cp_oend            ; $A00F XCOMLI: its line ended by an error

cp_main bit cp_xone           ; XCOMLI's line: a program of it ended
        bpl cm_n               ; with JMP (DOSVEC): the levels above the
cm_x1   lda SYSLEVEL           ; caller end, then back to it
        cmp cp_olv
        beq cm_x2
        bcc cm_x2
        jsr farcall
        dta b(BK_LD),a(LD_UNLOAD)
        jmp cm_x1
cm_x2   jmp cp_oret
cm_n    ldx #$FF
        txs
        jsr farcall            ; a program that ended with JMP (DOSVEC) or
        dta b(BK_LD),a(LD_RESET) ; failed: free what it had
        jsr closeall
        lda cp_fail            ; publish the completed command's status
        pha
                                ; an error: does it end the batch file?
        beq cm_ok
        jsr pp_abort           ; (and a pipe: its files go)
        ldx #0
        stx cp_fail
        bit cp_cfg             ; EOSSYS.SYS goes on after an error
        bmi cm_ok
        ldx cp_bat
        bmi cm_ok
        bit cp_erron           ; ERROR ON: any error, shown again
        bpl cm_e1
        jsr farcall
        dta b(BK_LIB),a(L_ERROR)
        jmp cm_end
cm_e1   ldx cp_inb             ; the command processor's own: 130, 156
        beq cm_ok              ; and 165 (REN B.TXT)
        cmp #E_NODEV
        beq cm_end
        cmp #165
        beq cm_end
        cmp #E_BADPARM
        bne cm_ok
cm_end  jsr batend
cm_ok   pla
        sta cp_d
        jsr nocmd
        lda #0
        sta cp_inb
        lda cp_cold
        beq cp_loop
        lda #0
        sta cp_cold
        jsr cfgopen            ; EOSSYS.SYS, read line by line from cp_loop
        bcc cp_loop
        jsr clk_rt             ; none: SDX's standard setup, the R-Time 8
        lda #EOL               ; driver and the default RAM disk (DEVICE
        sta LBUF               ; RAMDISK)
        lda #0
        sta BUFOFF
        lda #$80               ; (quiet: on a machine without the banks)
        sta rd_q
        jsr rdinst
        jsr cfgdone
cp_loop lda IOCB0+ICAX1        ; E: reads and writes again: a program may
        ora #$0C               ; have changed channel 0's AUX1 (exBASIC's or
        sta IOCB0+ICAX1        ; Atari BASIC's XIO #0), CIO would refuse
        lda MEMLO              ; what a reset puts back (resident programs
        sta res_ml             ; included)
        lda MEMLO+1
        sta res_ml+1
        ldy #0                 ; the last command's redirection ends
        jsr farcall
        dta b(BK_LIB),a(L_XDIVIO)
        ldy #1
        jsr farcall
        dta b(BK_LIB),a(L_XDIVIO)
        jsr pp_next            ; a pipe's next stage
        jcs cond_line
        bit cp_inb             ; a resident built-in returned directly
        bpl cond_next
        lda #0
        sta cp_d
cond_next
        jsr farcall
        dta b(BK_LIB2),a(L2_CONDNEXT)
        cmp #1
        jeq cond_line
        bit cp_xone            ; XCOMLI's line done: back to the caller
        jmi cp_oret
        bit cp_cfg
        jmi cfgline
        jsr chkbat
        lda #0
        sta cp_inb
        sta cp_pct
        lda cp_bat
        bmi cp_int
        jsr batline
        bcs cp_loop
        ldy #0                 ; a comment?
cl0     lda LBUF,y
        iny
        cmp #' '
        beq cl0
        cmp #';'
        beq cp_loop
        bit cp_echo            ; ECHO ON: the line as read
        bpl cl1
        ldy #0
        jsr prline
cl1     lda #$80
        sta cp_pct
        bne cp_sub
cp_int  jsr cspec              ; $COMSPEC: the shell instead of the prompt
cp_int2 jsr mkprompt
        stx IOCB0+ICBLL        ; X: its length
        ldx #0
        lda #C_PUTB
        sta IOCB0+ICCOM
        lda #<LBUFF
        sta IOCB0+ICBAL
        lda #>LBUFF
        sta IOCB0+ICBAH
        lda #0
        sta IOCB0+ICBLH
        jsr CIOV
        jsr k_prompt           ; stable prompt-ready hook before either editor
        bit dk_on              ; DOSKEY.SYS: its own command line
        bpl ci_e
        jsr farcall
        dta b(BK_LIB2),a(L2_DKLINE)
        jmp ci_y
ci_e    jsr k_getline
ci_y    tya
        jmi cp_loop
cp_sub  lda #0
        sta cp_cond
        jsr farcall
        dta b(BK_LIB2),a(L2_SUBST)
        jsr farcall
        dta b(BK_LIB2),a(L2_CONDSPLIT)
cond_line
        jsr pp_split           ; A | B: this stage, the rest waits
cp_line lda #0                 ; assume success; U_FAIL replaces this status
        sta cp_d
        lda #$80               ; errors from here on are the command processor's
        sta cp_inb
        jsr redir
        jsr arg_parse          ; publish the quote-aware sidecar for new tools
cl_parse lda #0
        sta BUFOFF
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        jeq cp_loop
        jsr keepcmd            ; fold for built-ins, but retain typed spelling
        jsr upname
        bit cp_front           ; the startup batch file's _01 goes to the end
        bpl cl2                ; with the first command that has parameters
        lda cp_ro              ; (as on SDX; a redirection counts)
        ora cp_ri
        bne cl1a
        ldy BUFOFF
        lda LBUF,y
        cmp #EOL
        beq cl2
cl1a    jsr mv01
cl2     lda COMFNAM            ; -NAME: a batch file
        cmp #'-'
        bne cl2a
        jsr rawcmd
        jmp c_bat
cl2a
        ldx FILLEN             ; a device alone (C:, D8:) makes it current
        lda COMFNAM-1,x
        cmp #':'
        bne cm0
        jsr farcall
        dta b(BK_LIB),a(L_GEFINA)
        lda device
        sta CURDEV
        jmp cp_loop
* find the command (the table is longer than 256 bytes: through fadr)
cm0     lda #<cmdtab
        sta fadr
        lda #>cmdtab
        sta fadr+1
cm1     ldy #0
cm2     lda (fadr),y
        beq cm_none
        cmp COMFNAM,y
        bne cm_skip
        iny
        cmp #EOL
        bne cm2
        iny                    ; found: run it
        lda (fadr),y
        pha
        dey
        lda (fadr),y
        pha
        rts
cm_skip lda (fadr),y           ; next entry: past the EOL and the address
        iny
        cmp #EOL
        bne cm_skip
        iny
        iny
        tya
        clc
        adc fadr
        sta fadr
        bcc cm1
        inc fadr+1
        bne cm1
* not a built-in command: load and run the program, NAME.COM when the name
* has no extension; the current directory, then $PATH
cm_none jsr rawcmd             ; external names are case-sensitive
        lda COMFNAM            ; +NAME: past COMEXE
        cmp #'+'
        bne cx0
        ldx #0
cxs     lda COMFNAM+1,x
        sta COMFNAM,x
        inx
        cmp #EOL
        bne cxs
        beq cx_com
cx0     jsr farcall            ; RUNEXT: an association?
        dta b(BK_LIB2),a(L2_RXFIND)
        bcs cx0a
        jmp cl_parse
cx0a    bit cx_on
        bpl cx_com
        jsr cx_exe
        bcs cx_com
        jmp cx_x
cx_com  lda #<dotcom
        ldx #>dotcom
        ldy #0
        sty cp_lflag
        jmp runprg2
* runprg: COMFNAM (extension AX when it has none) loaded and run (cp_lflag:
* the loader's FLAG; runprg runs it); runnm: the same for CP_NAME
runprg  ldy #0
        sty cp_lflag
runprg2 pha
        txa
        pha
        ldx #0
cn1     lda COMFNAM,x
        sta CP_NAME,x
        inx
        cmp #EOL
        bne cn1
        pla
        tax
        pla
runnm   jsr addext
        jsr find
        bcs cn_nf
        ldy #7                 ; there: closed, then loaded by its full name
        jsr jkernel
        jsr k_romoff           ; its name as typed, for U_FAIL: a program
        ldx #0                 ; that fails with 170 is named first (SDX)
cn1a    lda CP_NAME,x
        sta CMDNAME,x
        inx
        cmp #EOL
        beq cn1b
        cpx #31
        bcc cn1a
        lda #EOL
        sta CMDNAME,x
cn1b    jsr k_romon
        jmp cn_ld
cn_nf   ldx #0                 ; not there: as given (the loader's error)
cn2     lda CP_NAME,x
        sta COMFNAM,x
        inx
        cmp #EOL
        bne cn2
cn_ld   ldx #0                 ; FILLEN: the name's length (SDX: CT.COM 6)
cl3     lda COMFNAM,x
        cmp #EOL
        beq cl4
        inx
        bne cl3
cl4     stx FILLEN
        lda #<COMFNAM
        sta FILE_P
        lda #>COMFNAM
        sta FILE_P+1
        lda cp_lflag
        sta FLAG
        lda #0
        sta cp_inb             ; the program's errors are its own
        jsr farcall
        dta b(BK_LD),a(LD_LOAD)
        lda #0                 ; (a $COMSPEC shell ended well)
        sta cs_try
        jsr nocmd
        jmp cp_loop
* cp_one (XCOMLI): the line in LBUF run as one typed at the prompt; when
* the command processor would read the next line, back to the caller
* (lib's xcomli) with its stack. cp_oend: that mode and its redirections
* end.
cp_one  tsx
        stx cp_osp
        lda SYSLEVEL
        sta cp_olv
        lda #$80
        sta cp_xone
        jmp cp_sub
cp_oret jsr cp_oend
        ldx cp_osp
        txs
        rts
cp_oend lda #0
        sta cp_xone
        sta cp_inb
        tay
        jsr farcall
        dta b(BK_LIB),a(L_XDIVIO)
        ldy #1
        jsr farcall
        dta b(BK_LIB),a(L_XDIVIO)
        jmp nocmd

* ---- pipes: A | B | C, each command's output the next one's input -------
* As SDX 4.42 on: through files in $TEMP (the current directory when it is
* not set), PIPE1.TMP, PIPE2.TMP ..., deleted after the last command; a
* parameter - is the stream coming in. The rest of the line and the state
* wait under the OS ROM.
* (PIPEBUF, P_N, P_MORE, P_TMP: equ.icl; boot clears P_N and P_MORE)

* pp_split: a | in LBUF ends this command there, the rest goes to PIPEBUF;
* the first one takes $TEMP
pp_split ldy #0
        sty cp_fl              ; quote state: 0 plain, 1 single, 2 double
pips1  lda LBUF,y
        cmp #EOL
        beq pipsnone
        ldx cp_fl
        beq pipsplain
        cpx #1
        beq pipssq
        cmp #'"'
        beq pipsqend
        cmp #BSLASH
        beq pipsesc
        bne pipsnext
pipssq  cmp #39
        beq pipsqend
        bne pipsnext
pipsplain cmp #39
        beq pipssq0
        cmp #'"'
        beq pipsdq0
        cmp #BSLASH
        beq pipsesc
        cmp #'|'
        beq pips2
pipsnext
        iny
        bne pips1
pipssq0 lda #1
        sta cp_fl
        bne pipsnext
pipsdq0 lda #2
        sta cp_fl
        bne pipsnext
pipsqend lda #0
        sta cp_fl
        beq pipsnext
pipsesc iny                    ; the escaped byte is never an operator
        lda LBUF,y
        cmp #EOL
        beq pipsnone
        bne pipsnext
pipsnone jsr k_romoff
        lda #0
        sta P_MORE
        jmp k_romon
pips2     sty cp_y
        lda #EOL               ; this command ends there, without the blanks
        sta LBUF,y             ; before the |
pips3     dey
        bmi pips4
        lda LBUF,y
        cmp #' '
        bne pips4
        lda #EOL
        sta LBUF,y
        bne pips3
pips4     ldy cp_y               ; the rest, past the | and the blanks after
pips4a    iny
        lda LBUF,y
        cmp #' '
        beq pips4a
        ldx #0
        jsr k_romoff
pips5     lda LBUF,y
        sta PIPEBUF,x
        inx
        iny
        cmp #EOL
        bne pips5
        lda #1
        sta P_MORE
        lda P_N
        bne pips8
        inc P_N                ; the first command: where the files go
        jsr k_romon
        lda #<pp_temp
        ldx #>pp_temp
        jsr farcall
        dta b(BK_LIB2),a(L2_ENGET)
        tay                    ; (N=1: not set, nothing)
        ldx #0
        jsr k_romoff
        tya
        bmi pips7
pips6     lda LBUFF,x
        cmp #EOL
        beq pips7
        sta P_TMP,x
        inx
        cpx #31
        bcc pips6
pips7     lda #EOL
        sta P_TMP,x
pips8     jmp k_romon

* pp_redir: a pipe's command writes to the next file (but the last) and
* reads the one before (but the first), unless it has >> or << itself; a
* parameter - becomes that file's name
pp_redir jsr k_romoff
        lda P_N
        beq piproff
        lda P_MORE
        beq piprin
        lda cp_ro
        bne piprin
        ldx #0                 ; output: PIPEn
        lda P_N
        jsr pp_name
        lda #$80
        sta cp_ro
piprin   lda P_N
        cmp #2
        bcc piproff
        lda cp_ri
        bne piproff
        ldx #32                ; input: PIPEn-1
        lda P_N
        sec
        sbc #1
        jsr pp_name
        lda #$80
        sta cp_ri
        jsr k_romon
        jmp pp_dash
piproff  jmp k_romon
* pp_dash: the first parameter - in LBUF becomes the name at LBUFF+32.
* CP_ARGBUF is safe temporary storage here: arg_parse has not published the
* current command yet.  This avoids the old pair of 32-byte slices in LBUFF.
pp_dash ldy #1
pipd1     lda LBUF,y
        cmp #EOL
        beq pipdret
        cmp #'-'
        bne pipd2
        lda LBUF-1,y           ; a word of its own?
        cmp #' '
        bne pipd2
        lda LBUF+1,y
        cmp #' '
        beq pipd3
        cmp #EOL
        beq pipd3
pipd2     iny
        bne pipd1
pipdret  rts
pipd3     sty cp_y               ; keep the rest under ROM
        jsr k_romoff
        ldx #0
pipd4     lda LBUF+1,y
        sta CP_ARGBUF,x
        iny
        inx
        cmp #EOL
        bne pipd4
        ldy cp_y               ; the name in its place
        ldx #32
pipd5     lda LBUFF,x
        cmp #EOL
        beq pipd6
        cpy #127
        bcs pipdlong
        sta LBUF,y
        inx
        iny
        bne pipd5
pipd6     ldx #0                 ; then the rest
pipd7     lda CP_ARGBUF,x
        cmp #EOL
        beq pipdok
        cpy #127
        bcs pipdlong
        sta LBUF,y
        inx
        iny
        bne pipd7
pipdok   sta LBUF,y
        jmp k_romon
pipdlong lda #EOL               ; expanded line exceeds its public limit
        sta LBUF,y
        jsr k_romon
        lda #E_PATHLEN
        jmp fail
* pp_name: the file of command A ($TEMP, PIPEn.TMP) to LBUFF+X, with
* the ROM off (P_TMP)
pp_name sta cp_d
        ldy #0
pipn1     lda P_TMP,y
        cmp #EOL
        beq pipn2
        sta LBUFF,x
        inx
        iny
        bne pipn1
pipn2     ldy #0
pipn3     lda pp_pipe,y
        sta LBUFF,x
        inx
        iny
        cpy #4
        bcc pipn3
        lda cp_d
        ora #'0'
        sta LBUFF,x
        inx
        ldy #0
pipn4     lda pp_ext,y
        sta LBUFF,x
        inx
        iny
        cmp #EOL
        bne pipn4
        rts

* pp_next: when the command processor would read a line: C=1 and the
* pipe's next command in LBUF; after the last one its files go (C=0)
pp_next jsr k_romoff
        lda P_N
        beq pipnxno
        lda P_MORE
        beq pipnxend
        ldx #0
pipnx1    lda PIPEBUF,x
        sta LBUF,x
        inx
        cmp #EOL
        bne pipnx1
        inc P_N
        jsr k_romon
        sec
        rts
pipnxend jsr k_romon
        jsr pp_del
pipnxno  jsr k_romon
        clc
        rts
* pp_abort: an error: the pipe ends, its files go (keeps A: the error)
pp_abort pha
        jsr pp_ab
        pla
        rts
pp_ab   jsr k_romoff
        lda P_N
        beq pipnxno
        lda #1                 ; (the one running wrote its file too)
        sta P_MORE
        jsr k_romon
* pp_del: the pipe's files deleted (1 to P_N-1, or P_N with P_MORE), the
* pipe over
pp_del  jsr k_romoff
        lda P_N
        ldx P_MORE
        bne pipdl0
        sec
        sbc #1
pipdl0    sta cp_pct             ; (how many, counted down)
        lda #0
        sta P_N
        sta P_MORE
pipdl1    lda cp_pct
        beq pipdlend
        ldx #32
        jsr pp_name
        jsr k_romon
        ldx #32
        jsr rd_cp
        jsr gefina
        lda #0
        sta scan
        ldy #12                ; kd_delete (no file: nothing)
        jsr jkernel
        jsr k_romoff
        dec cp_pct
        jmp pipdl1
pipdlend jmp k_romon
pp_temp dta c'TEMP',b(EOL)
pp_pipe dta c'PIPE'
pp_ext  dta c'.tmp',b(EOL)

* nocmd: no program's name for U_FAIL
nocmd   jsr k_romoff
        lda #EOL
        sta CMDNAME
        jmp k_romon
dotcom  dta c'.com',b(EOL)
dotexe  dta c'.exe',b(EOL)

* cx_exe (COMEXE): C=0 when COMFNAM is a NAME.EXE to run through X (no
* extension: NAME.COM first, then NAME.EXE: cx_add $80, .EXE to add).
* C=1: COMFNAM as it was. (find changes COMFNAM: the line's first word is
* read again.)
cx_exe  lda #0
        sta cx_add
        ldx #0                 ; its extension: after the last dot of the name
        ldy #0
cxe2    lda COMFNAM,x
        cmp #EOL
        beq cxe3
        inx
        cmp #'.'
        bne cxe2a
        txa
        tay
cxe2a   cmp #'/'
        beq cxe2b
        cmp #':'
        beq cxe2b
        bne cxe2
cxe2b   ldy #0
        beq cxe2
cxe3    tya
        beq cxe_no
        lda COMFNAM,y          ; .EXE given
        cmp #'E'
        bne cx_no
        lda COMFNAM+1,y
        cmp #'X'
        bne cx_no
        lda COMFNAM+2,y
        cmp #'E'
        bne cx_no
        lda COMFNAM+3,y
        cmp #EOL
        bne cx_no
        clc
        rts
cxe_no  lda #<dotcom           ; NAME.COM there: as usual
        ldx #>dotcom
        jsr cx_try
        bcc cx_keep
        lda #<dotexe
        ldx #>dotexe
        jsr cx_try
        bcs cx_keep
        jsr cx_rest
        lda #$80
        sta cx_add
        clc
        rts
cx_keep jsr cx_rest
cx_no   sec
        rts
* cx_rest: COMFNAM (and BUFOFF) as the line's first word again
cx_rest lda #0
        sta BUFOFF
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        jmp upname
* cx_try: COMFNAM with extension AX found? C=0 (closed again)
cx_try  pha
        txa
        pha
        jsr cx_rest
        ldx #0
cxt1    lda COMFNAM,x
        sta CP_NAME,x
        inx
        cmp #EOL
        bne cxt1
        pla
        tax
        pla
        jsr addext
        jsr find
        bcs cxt_ret
        ldy #7
        jsr jkernel
        clc
cxt_ret rts
* cx_x: the line again as "X NAME.EXE parameters"
cx_x    lda #'X'
        sta LBUFF
        lda #' '
        sta LBUFF+1
        ldx #2
        ldy #0
cxx1    lda COMFNAM,y
        cmp #EOL
        beq cxx1a
        sta LBUFF,x
        inx
        iny
        bne cxx1
cxx1a   bit cx_add
        bpl cxx2
        ldy #0
cxx1b   lda dotexe,y
        cmp #EOL
        beq cxx2
        sta LBUFF,x
        inx
        iny
        bne cxx1b
cxx2    ldy BUFOFF
cxx3    lda LBUF,y
        sta LBUFF,x
        cmp #EOL
        beq cxx4
        iny
        inx
        cpx #127
        bcc cxx3
        lda #EOL
        sta LBUFF,x
cxx4    ldx #0
cxx5    lda LBUFF,x
        sta LBUF,x
        inx
        cmp #EOL
        bne cxx5
        jmp cl_parse
dotbat  dta c'.bat',b(EOL)
dotsys  dta c'.sys',b(EOL)
dotcfg  dta c'.cfg',b(EOL)

fail    jsr farcall
        dta b(BK_LIB),a(L_FAIL)

* built-in commands: name, EOL, address-1
cmdtab  dta c'TYPE',b(EOL),a(c_type-1)
        dta c'CAT',b(EOL),a(c_cat-1)
        dta c'RUNEXT',b(EOL),a(c_runext-1)
        dta c'CLS',b(EOL),a(c_cls-1)
        dta c'CLEAR',b(EOL),a(c_cls-1)
        dta c'ECHO',b(EOL),a(c_echo-1)
        dta c'SET',b(EOL),a(c_set-1)
        dta c'PATH',b(EOL),a(c_path-1)
        dta c'ERROR',b(EOL),a(c_error-1)
        dta c'CD',b(EOL),a(c_cd-1)
        dta c'CHDIR',b(EOL),a(c_cd-1)
        dta c'CWD',b(EOL),a(c_cd-1)
        dta c'MD',b(EOL),a(c_md-1)
        dta c'MKDIR',b(EOL),a(c_md-1)
        dta c'CREDIR',b(EOL),a(c_md-1)
        dta c'RD',b(EOL),a(c_rd-1)
        dta c'RMDIR',b(EOL),a(c_rd-1)
        dta c'DELDIR',b(EOL),a(c_rd-1)
        dta c'RENDIR',b(EOL),a(c_rendir-1)
        dta c'REN',b(EOL),a(c_ren-1)
        dta c'RENAME',b(EOL),a(c_ren-1)
        dta c'DEL',b(EOL),a(c_del-1)
        dta c'RM',b(EOL),a(c_del-1)
        dta c'DELETE',b(EOL),a(c_del-1)
        dta c'ERASE',b(EOL),a(c_del-1)
        dta c'ATR',b(EOL),a(c_atr-1)
        dta c'ATTRIB',b(EOL),a(c_atr-1)
        dta c'VERIFY',b(EOL),a(c_vfy-1)
        dta c'REPORT',b(EOL),a(c_report-1)
        dta c'SETERRNO',b(EOL),a(c_seterr-1)
        dta c'SWAP',b(EOL),a(c_swap-1)
        dta c'PROMPT',b(EOL),a(c_prompt-1)
        dta c'LOAD',b(EOL),a(c_load-1)
        dta c'BOOT',b(EOL),a(c_boot-1)
        dta c'CLR',b(EOL),a(c_clr-1)
        dta c'COLD',b(EOL),a(c_cold-1)
        dta c'BASIC',b(EOL),a(c_basic-1)
        dta c'PAUSE',b(EOL),a(c_pause-1)
        dta c'MORE',b(EOL),a(c_more-1)
        dta c'VER',b(EOL),a(c_ver-1)
        dta c'FI',b(EOL),a(cp_loop-1)
        dta c'COPY',b(EOL),a(c_copy-1)
        dta c'CP',b(EOL),a(c_cp-1)
        dta b(0)

* upname: COMFNAM in capitals
upname  ldx #0
un1     lda COMFNAM,x
        cmp #EOL
        beq un2
        jsr upper
        sta COMFNAM,x
        inx
        bne un1
un2     rts
upper   cmp #'a'
        bcc up1
        cmp #'z'+1
        bcs up1
        and #$DF
up1     rts

* Retain the command exactly as typed while COMFNAM is used for the built-in
* command table. CP_NAME is free at this point and runprg replaces it later.
keepcmd ldx #0
kc_cmd1 lda COMFNAM,x
        sta CP_NAME,x
        inx
        cmp #EOL
        bne kc_cmd1
        rts
rawcmd  ldx #0
rc_cmd1 lda CP_NAME,x
        sta COMFNAM,x
        inx
        cmp #EOL
        bne rc_cmd1
        rts

* arg_parse: publish this command as argc plus offset/length argv entries.
* The old COMTAB line is unchanged; new programs use U_ARGC/U_ARGV. Parsing is
* bounded in CP_ARGBUF: quotes are removed, quoted blanks retained,
* and backslash quotes the following byte. Operators have already been taken
* by the command processor. A maximum of 16 words and 127 output bytes keeps
* all storage fixed.
arg_parse jsr k_romoff
        lda #0
        sta CP_ARGC
        sta cp_y               ; input offset
        ldx #0                 ; output offset
ap_skip ldy cp_y
        lda LBUF,y
        cmp #' '
        jeq ap_sk1
        cmp #','               ; retain the inexpensive legacy separator
        jeq ap_sk1
        cmp #EOL
        jeq ap_done
        lda CP_ARGC
        cmp #16
        bcs ap_bad
        tay
        txa
        sta CP_ARGOFF,y
        sta cp_d               ; this word's output start
        lda #0
        sta cp_fl              ; 0 plain, 1 single quote, 2 double quote
ap_char ldy cp_y
        lda LBUF,y
        cmp #EOL
        beq ap_eol
        lda cp_fl
        beq ap_plain
        cmp #1
        beq ap_single
* double quoted
        lda LBUF,y
        cmp #'"'
        beq ap_qend
        cmp #BSLASH
        beq ap_escape
        bne ap_copy
ap_single lda LBUF,y
        cmp #39                ; single quote
        beq ap_qend
        bne ap_copy
ap_plain lda LBUF,y
        cmp #' '
        beq ap_word
        cmp #','
        beq ap_word
        cmp #39
        beq ap_sq
        cmp #'"'
        beq ap_dq
        cmp #BSLASH
        beq ap_escape
ap_copy cpx #127
        bcs ap_bad
        sta CP_ARGBUF,x
        inx
ap_next inc cp_y
        bne ap_char
ap_bad lda #E_PATHLEN
        jsr k_romon
        jmp fail
ap_sq   lda #1
        sta cp_fl
        bne ap_next
ap_dq   lda #2
        sta cp_fl
        bne ap_next
ap_qend lda #0
        sta cp_fl
        beq ap_next
ap_escape inc cp_y
        ldy cp_y
        lda LBUF,y
        cmp #EOL
        beq ap_bad
        bne ap_copy
ap_eol  lda cp_fl
        bne ap_bad
ap_word lda #EOL
        sta CP_ARGBUF,x
        txa
        sec
        sbc cp_d
        ldy CP_ARGC
        sta CP_ARGLEN,y
        inc CP_ARGC
        ldy cp_y
        lda LBUF,y
        cmp #EOL
        beq ap_done
        cpx #127
        bcs ap_bad
        inx
ap_sk1  inc cp_y
        jmp ap_skip
ap_done lda #EOL
        sta CP_ARGBUF,x
        jmp k_romon

* ---- CLS -----------------------------------------------------------------------
* ---- RUNEXT: the associations RUNEXT.SYS read --------------------------------
c_runext jsr farcall
        dta b(BK_LIB2),a(L2_RXSHOW)
        jmp cp_loop

c_cls   lda #$7D
        jsr putc
        jmp cp_loop

* ---- ECHO ON|OFF, ECHO [/N] text -------------------------------------------------
c_echo  ldy BUFOFF
        lda LBUF,y
        cmp #EOL
        bne ce0
ce_bad  lda #E_BADPARM
        jmp fail
ce0     jsr onoff
        bcs ce1
        sta cp_echo
        jmp cp_loop
ce1     lda #0                 ; print the parsed argv, joining words once
        sta cp_fl              ; (/N: no EOL at the end)
        lda #1
        sta cp_i
        cmp CP_ARGC
        bcs ce3
        jsr cp_argv
        cpy #2
        bne ce_loop
        lda path
        cmp #'/'
        bne ce_loop
        lda path+1
        jsr upper
        cmp #'N'
        bne ce_loop
        lda #$80
        sta cp_fl
        inc cp_i
ce_loop lda cp_i
        cmp CP_ARGC
        bcs ce3
        jsr cp_argv
        ldx #0
ce_chars cpx cp_lim
        beq ce_next
        lda path,x
        jsr putc
        inx
        bne ce_chars
ce_next inc cp_i
        lda cp_i
        cmp CP_ARGC
        bcs ce3
        lda #' '
        jsr putc
        jmp ce_loop
ce3
        bit cp_fl
        bmi ce4
        lda #EOL
        jsr putc
ce4     jmp cp_loop

* cp_argv: native argument A copied from the under-ROM sidecar to path;
* cp_lim is its length.  The sidecar is known valid after arg_parse.
cp_argv tay
        lda CP_ARGOFF,y
        clc
        adc #<CP_ARGBUF
        sta fadr
        lda #>CP_ARGBUF
        adc #0
        sta fadr+1
        lda CP_ARGLEN,y
        sta cp_lim
        jsr k_romoff
        ldy #0
cav1    cpy cp_lim
        beq cav2
        lda (fadr),y
        sta path,y
        iny
        bne cav1
cav2    jsr k_romon
        ldy cp_lim
        rts

* argvcom: native argument A copied to COMFNAM and EOL-terminated.  Filesystem
* built-ins use this after arg_parse instead of reparsing the legacy LBUF.
argvcom jsr cp_argv
        ldx #0
avc1    cpx cp_lim
        beq avc2
        lda path,x
        sta COMFNAM,x
        inx
        bne avc1
avc2    lda #EOL
        sta COMFNAM,x
        rts

* onoff: ON or OFF (any case) alone at LBUF+Y: C=0, A = $80 or 0; keeps Y
onoff   lda LBUF,y
        jsr upper
        cmp #'O'
        bne oo_no
        lda LBUF+1,y
        jsr upper
        cmp #'N'
        bne oo_off
        lda LBUF+2,y
        jsr oo_end
        bne oo_no
        lda #$80
        clc
        rts
oo_off  cmp #'F'
        bne oo_no
        lda LBUF+2,y
        jsr upper
        cmp #'F'
        bne oo_no
        lda LBUF+3,y
        jsr oo_end
        bne oo_no
        lda #0
        clc
        rts
oo_no   sec
        rts
oo_end  cmp #' '               ; Z=1: the end of the word
        beq oe1
        cmp #EOL
oe1     rts

* ---- ERROR ON|OFF ----------------------------------------------------------------
c_error ldy BUFOFF
        jsr onoff
        jcs ce_bad
        sta cp_erron
        jmp cp_loop

* ---- SET [var[=value]] ---------------------------------------------------------
c_set   ldy BUFOFF
        lda LBUF,y
        cmp #EOL
        bne st2
        lda #0                 ; all of them, NAME=VALUE each on a line
        sta cp_d
st1     lda cp_d
        jsr farcall
        dta b(BK_LIB),a(L_NUMENV)
        cmp #0
        bne st_end
        ldx #0
st1a    lda LBUFF,x
        stx cp_x
        jsr putc
        ldx cp_x
        inx
        cmp #EOL
        bne st1a
        inc cp_d
        bne st1
st_end  jmp cp_loop
st2     cmp #'='               ; no name: nothing
        beq st_end
        ldx #0
st3     jsr upcopy             ; the rest in capitals, to PUTENV
        lda #<LBUFF
        ldx #>LBUFF
        jsr putenv
        jmp cp_loop

* upcopy: LBUF+Y to the end, in capitals, to LBUFF+X (trailing blanks
* dropped)
upcopy  lda LBUF,y
        cmp #EOL
        beq uc2
        jsr upper
        sta LBUFF,x
        inx
        iny
        cpx #120
        bcc upcopy
uc2     dex
        bmi uc3
        lda LBUFF,x
        cmp #' '
        beq uc2
uc3     inx
        lda #EOL
        sta LBUFF,x
        rts

* ---- PATH [path] ---------------------------------------------------------------
c_path  ldy BUFOFF
        lda LBUF,y
        cmp #EOL
        bne pa2
        jsr nm_path            ; show it
        ldx #0
        jsr envget
        bcs pa1
        lda #EOL
        sta LBUFF,x
        ldx #0
pa0     lda LBUFF,x
        stx cp_x
        jsr putc
        ldx cp_x
        inx
        cmp #EOL
        bne pa0
pa1     jmp cp_loop
pa2     ldx #4                 ; SET PATH=...
pa3     lda nmpath,x
        sta LBUFF,x
        dex
        bpl pa3
        ldx #5
        jmp st3
nmpath  dta c'PATH='
nm_path ldx #4
np1     lda nmpath,x
        sta cp_nm,x
        dex
        bpl np1
        lda #EOL
        sta cp_nm+4
        rts

* ---- EOSSYS.SYS (C3) -------------------------------------------------------------
* As SDX reads CONFIG.SYS: D1:EOSSYS.SYS, else D1:CONFIG.SYS, at a cold
* start unless OPTION is held. Lines: USE OSRAM|BANKED|NONE, SET, DEVICE
* driver [parms], ECHO, MERGE file (.CFG; the rest of this file is not
* read); ; comments; ? before a line (SDX asks, EOS does it). Other lines
* and errors do not stop it. DEVICE with one of SDX's drivers that EOS has
* built in does nothing; another is loaded as a program (.SYS). After it:
* BOOT=A:/, the banner, then $BATCH or the startup batch file.

* cfgopen: C=0 the file is open (cp_bat), cp_cfg set; C=1 none
cfgopen lda CONSOL
        and #$04
        beq co_no
        ldx #0
co1     stx cp_i
        ldy #0
co2     lda cfgnames,x
        sta CP_NAME,y
        inx
        iny
        cmp #EOL
        bne co2
        jsr find
        bcc co3
        ldx cp_i
co4     inx
        lda cfgnames-1,x
        cmp #EOL
        bne co4
        lda cfgnames,x
        bne co1
co_no   sec
        rts
co3     lda file_id
        sta cp_bat
        lda #$80
        sta cp_cfg
        clc
        rts
cfgnames dta c'D1:eossys.sys',b(EOL)
        dta c'D1:config.sys',b(EOL)
        dta b(0)

* cfgdone: after EOSSYS.SYS (or none)
cfgdone lda #0
        sta cp_cfg
        lda #$FF
        sta cp_bat
        ldx #8                 ; (PUTENV reads RAM: this bank is not in then)
cd0     lda nmboot,x
        sta LBUFF,x
        dex
        bpl cd0
        lda #<LBUFF
        ldx #>LBUFF
        jsr putenv
        ldx #0
cd1     lda cpbanner,x
        jsr putc
        inx
        cpx #cpbanner_end-cpbanner
        bcc cd1
        ldx #5                 ; $BATCH set: it runs instead
cd2     lda nmbatch,x
        sta cp_nm,x
        dex
        bpl cd2
        ldx #64
        jsr envget
        jcc cd3
        jsr autoexec
cd3     rts
nmboot  dta c'BOOT=A:/',b(EOL)
cpbanner dta b(EOL)
        dta c'EOS v'
        icl 'version.icl'
        dta c' (c)2026 Rick Collette',b(EOL)
cpbanner_end equ *

* cfgline: the next line of EOSSYS.SYS
cfgline jsr batline
        bcc cg1
        jsr cfgdone
        jmp cp_loop
cg1     ldy #0
cg2     lda LBUF,y
        cmp #' '
        beq cg3
        cmp #'?'
        bne cg4
cg3     iny
        bne cg2
cg4     cmp #';'
        jeq cp_loop
        sty BUFOFF
        lda #$80
        sta cp_inb
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        jeq cp_loop
        jsr upname
        ldx #0
cg5     ldy #0
cg6     lda cfgtab,x
        jeq cp_loop            ; another word: not used
        cmp COMFNAM,y
        bne cg7
        inx
        iny
        cmp #EOL
        bne cg6
        lda cfgtab+1,x
        pha
        lda cfgtab,x
        pha
        rts
cg7     inx
        lda cfgtab-1,x
        cmp #EOL
        bne cg7
        inx
        inx
        bne cg5
cfgtab  dta c'USE',b(EOL),a(c_use-1)
        dta c'SET',b(EOL),a(c_set-1)
        dta c'DEVICE',b(EOL),a(c_dev-1)
        dta c'ECHO',b(EOL),a(c_echo-1)
        dta c'MERGE',b(EOL),a(c_merge-1)
        dta b(0)

* USE OSRAM|BANKED|NONE
c_use   jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        jsr upname
        ldx #2
cu1     lda COMFNAM
        cmp usech,x
        beq cu2
        dex
        bpl cu1
        jmp cp_loop
cu2     txa
        sta cfg_use
        jsr farcall
        dta b(BK_BOOT),a(BOOT_USE)
        jmp cp_loop
usech   dta c'NOB'             ; NONE 0, OSRAM 1, BANKED 2 (first letters)

* DEVICE driver [parameters]
c_dev   jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        jeq cp_loop
        jsr upname
        ldx #7                 ; RAMDISK: built in (rdinst)
cvr     lda COMFNAM,x
        cmp rdname,x
        bne cv0
        dex
        bpl cvr
        jsr rdcmd
        jmp cp_loop
cv0     ldx #0                 ; the clock drivers: built in
        jsr cmpnm
        bne cv0a
        jsr clk_rt
        jmp cp_loop
cv0a    ldx #7
        jsr cmpnm
        bne cv0b
        jsr clk_jf
        jmp cp_loop
cv0b
        ldx #0                 ; built into EOS?
cv1     ldy #0
cv2     lda drvtab,x
        beq cv5
        cmp COMFNAM,y
        bne cv3
        inx
        iny
        cmp #EOL
        bne cv2
        cpx #4                 ; SIO: /A or /C
        bne cv2x
        jsr sio_a
cv2x    jmp cp_loop
cv3     inx
        lda drvtab-1,x
        cmp #EOL
        bne cv3
        beq cv1
cv5     lda #<dotsys
        ldx #>dotsys
        jmp runprg
* sio_a: DEVICE SIO /A or /C: the OS's SIO only, as SDX's: the high
* speed driver out of sio_vector and off (SIOSET answers 154)
sio_a   jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq sa_x
        lda COMFNAM
        cmp #'/'
        bne sio_a
        ldx #1
sa1     lda COMFNAM,x
        cmp #EOL
        beq sio_a
        inx
        and #$DF
        cmp #'A'
        beq sa_off
        cmp #'C'
        bne sa1
sa_off  lda #0
        sta sio_vector+6
        sta sio_vector+7
        sta DUNIT
        lda #$80
        sta DAUX1
        sta DAUX2
        lda #$FD
        sta DDEVIC
        jmp k_hsdrv
sa_x    rts
drvtab  dta c'SIO',b(EOL)
        dta b(0)
clknm   dta c'RTIME8',b(EOL),c'JIFFY',b(EOL)
* cmpnm: Z=1 when COMFNAM is the name at clknm+X (EOL ended)
cmpnm   ldy #0
cpn1    lda clknm,x
        cmp COMFNAM,y
        bne cpn2
        inx
        iny
        cmp #EOL
        bne cpn1
cpn2    rts

* clk_rt: the R-Time 8 clock driver on (DEVICE RTIME8): as SDX's, it says
* so when there is no R-Time 8
clk_rt  lda #1
        jsr farcall
        dta b(BK_DEV),a(CARTLO+$1E)
        bcc ck_ret
        ldx #0
ckr1    lda rtnone,x
        jsr putc
        inx
        cpx #rtnone_end-rtnone
        bcc ckr1
        ldx #5                 ; none: the soft clock runs, as SDX's does,
ckr2    lda COMTAB+$0D,x       ; from DATER and TIMER (1-01-25 0:00:00)
        sta date,x
        dex
        bpl ckr2
        jmp clk_jf
ck_ret  rts
rtnone  dta c'R-Time 8 not present',b(EOL)
rtnone_end equ *
* clk_jf: the soft clock (DEVICE JIFFY)
clk_jf  lda #2
        jsr farcall
        dta b(BK_DEV),a(CARTLO+$1E)
        rts

* MERGE file: EOSSYS.SYS goes on in file (.CFG)
c_merge jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        ldx #0
cmg1    lda COMFNAM,x
        sta CP_NAME,x
        inx
        cmp #EOL
        bne cmg1
        ldx cp_bat             ; this one is done
        stx file_id
        ldy #7
        jsr jkernel
        lda #$FF
        sta cp_bat
        lda COMFNAM
        cmp #EOL
        beq cmg2
        lda #<dotcfg
        ldx #>dotcfg
        jsr addext
        jsr find
        bcs cmg2
        lda file_id
        sta cp_bat
        jmp cp_loop
cmg2    jsr cfgdone
        jmp cp_loop

* ---- batch files ---------------------------------------------------------------

* c_bat: -NAME [parm1 ... parm9]: the batch file running now ends; _01 is
* NAME (no device, path or extension), _11 ... _91 the parameters; then
* NAME.BAT (another extension when given) is opened, from the current
* directory or along $PATH
c_bat   ldx #0
cb1     lda COMFNAM+1,x
        sta CP_NAME,x
        inx
        cmp #EOL
        bne cb1
        jsr batend
        lda #'0'               ; _01
        sta cp_d
        jsr givenm
        jsr setpar
cb2     inc cp_d               ; _11 ... _91
        lda cp_d
        cmp #'9'+1
        bcs cb3
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq cb3
        ldx #0                 ; the parameter, in capitals
cb2a    lda COMFNAM,x
        jsr upper
        sta LBUFF+4,x
        inx
        cmp #EOL
        bne cb2a
        jsr setpar
        jmp cb2
cb3     jsr batopen
        bcc cb4
        jmp fail
cb4     jmp cp_loop

* batopen: CP_NAME (.BAT added when it has no extension) opened as the batch
* file: C=1, A = 170 when it is not found
batopen lda #<dotbat
        ldx #>dotbat
        jsr addext
        jsr find
        bcs bo_no
        lda file_id
        sta cp_bat
        clc
        rts
bo_no   lda #E_NOTFOUND
        rts

* givenm: CP_NAME as given, in capitals, to LBUFF+4 (SDX's _01 for -NAME
* and $BATCH: `B.BAT` stays `B.BAT`)
givenm  ldx #0
gn1     lda CP_NAME,x
        jsr upper
        sta LBUFF+4,x
        inx
        cmp #EOL
        bne gn1
        rts

* basenm: CP_NAME without device, path and extension, in capitals, to
* LBUFF+4 (the startup batch file's _01: AUTOEXEC)
basenm  ldy #0
        ldx #0
bn1     lda CP_NAME,y
        cmp #EOL
        beq bn4
        iny
        cmp #':'
        beq bn2
        cmp #'/'
        bne bn3
bn2     ldx #0                 ; a separator: the name starts again
        beq bn1
bn3     cmp #'.'
        bne bn3a
        stx cp_x               ; the extension: not taken
        lda #EOL
        sta LBUFF+4,x
bn3b    lda CP_NAME,y          ; until a separator restarts it
        cmp #EOL
        beq bn5
        iny
        cmp #':'
        beq bn2
        cmp #'/'
        beq bn2
        bne bn3b
bn3a    jsr upper
        sta LBUFF+4,x
        inx
        jmp bn1
bn4     lda #EOL
        sta LBUFF+4,x
bn5     rts

* setpar: _d1=LBUFF+4 to the environment (d = cp_d)
setpar  lda #'_'
        sta LBUFF
        lda cp_d
        sta LBUFF+1
        lda #'1'
        sta LBUFF+2
        lda #'='
        sta LBUFF+3
        lda #<LBUFF
        ldx #>LBUFF
        jmp putenv

* batend: the batch file ends: closed, its parameters deleted
batend  lda #0
        sta cp_front
        ldx cp_bat
        bmi be1
        stx file_id
        ldy #7                 ; kd_close
        jsr jkernel
        lda #$FF
        sta cp_bat
be1     lda #'0'
        sta cp_d
be2     lda #'_'
        sta cp_nm
        lda cp_d
        sta cp_nm+1
        lda #'1'
        sta cp_nm+2
        lda #EOL
        sta cp_nm+3
        lda #<cp_nm
        ldx #>cp_nm
        jsr putenv
        inc cp_d
        lda cp_d
        cmp #'9'+1
        bcc be2
        rts

* chkbat: $BATCH set: it is deleted and run as a batch file (no parameters)
chkbat  ldx #5
cb_1    lda nmbatch,x
        sta cp_nm,x
        dex
        bpl cb_1
        ldx #0
        jsr envget
        jcs ck_ret
        ldy #0
cb_2    lda LBUFF,y
        sta CP_NAME,y
        iny
        cmp #EOL
        bne cb_2
        lda #<cp_nm            ; deleted
        ldx #>cp_nm
        jsr putenv
        jsr batend
        lda #'0'
        sta cp_d
        jsr givenm
        jsr setpar
        jsr batopen
        bcc rtc_ret
        lda #$80               ; not there: 170, as the command processor's
        sta cp_inb
        lda #E_NOTFOUND
        jmp fail
rtc_ret rts
nmbatch dta c'BATCH',b(EOL)

* autoexec: start D1:EOSAUTO.BAT, or D1:AUTOEXEC.BAT when there is none;
* _01 is its name, first in the environment (as SDX has it)
autoexec ldx #0
ae1     stx cp_i
        ldy #0
ae0     lda autonames,x
        sta CP_NAME,y
        inx
        iny
        cmp #EOL
        bne ae0
        jsr batopen
        bcs ae2
        lda #'0'
        sta cp_d
        jsr basenm
        jsr setpar
        lda rd_unit            ; first in the environment only when the
        bne ae_r               ; start changed nothing else in it (no RAM
        lda #$80               ; disk: SDX lists _01 last after RAMDISK's
        sta cp_front           ; variables)
        jmp envfront
ae_r    rts
ae2     ldx cp_i               ; next name
ae3     inx
        lda autonames-1,x
        cmp #EOL
        bne ae3
        lda autonames,x
        bne ae1
        rts
autonames dta c'D1:eosauto.bat',b(EOL)
        dta c'D1:autoexec.bat',b(EOL)
        dta b(0)

* mv01: _01 deleted and set again (now the last variable)
mv01    lda #0
        sta cp_front
        lda #'_'
        sta cp_nm
        lda #'0'
        sta cp_nm+1
        sta cp_d
        lda #'1'
        sta cp_nm+2
        lda #EOL
        sta cp_nm+3
        ldx #4
        jsr envget
        bcs mv_ret
        lda #EOL
        sta LBUFF,x
        jmp setpar
mv_ret  rts

* envfront: the environment's last variable moved to the front (lib2)
envfront jsr farcall
        dta b(BK_LIB2),a(L2_ENFRONT)
        rts

* batline: the next line of the batch file to LBUF; C=1 at its end (the
* batch file has ended then)
batline lda cp_bat
        sta file_id
        lda #0
        sta cp_i
        sta bytbuf+1
        sta memreix
bl1     jsr bl_x               ; (too long: the start kept, the rest read
bl2     txa                    ; into the last place up to its EOL)
        clc
        adc #<LBUF
        sta addpos
        lda #>LBUF
        adc #0
        sta addpos+1
        lda #1
        sta bytbuf
        ldy #0                 ; kd_read
        jsr jkernel
        bmi bl_end
        jsr bl_x               ; the byte just read
        lda LBUF,x
        cmp #EOL
        beq bl_ok
        cpx #127
        bcs bl1
        inc cp_i
        bne bl1
bl_end  ldx cp_i               ; a last line without EOL still counts
        beq bl_eof
        lda #EOL
        sta LBUF,x
bl_ok   clc
        rts
bl_eof  jsr batend
        sec
        rts
* bl_x: X = where the next byte of the line goes: cp_i, at most 127
bl_x    ldx cp_i
        cpx #127
        bcc blx1
        ldx #127
blx1    rts

* ---- the command line ------------------------------------------------------------

* redir: >NAME (truncate), >>NAME (append), <NAME and the old <<NAME input
* alias, at the start of a word. Quoted or escaped markers are ordinary
* bytes. The first of each kind wins; an empty name is an error.
redir   lda #0
        sta cp_ro
        sta cp_ri
        sta cp_fl              ; quote state
        ldy #0
rd1     lda LBUF,y
        cmp #EOL
        jeq rd_go
        ldx cp_fl
        beq rd_plain
        cpx #1
        beq rd_sq
        cmp #'"'
        beq rd_qend
        cmp #BSLASH
        beq rd_esc
        bne rd_nx
rd_sq   cmp #39
        beq rd_qend
        bne rd_nx
rd_plain cmp #39
        beq rd_sq0
        cmp #'"'
        beq rd_dq0
        cmp #BSLASH
        beq rd_esc
        cmp #'>'
        beq rd_mark
        cmp #'<'
        bne rd_nx
rd_mark sta cp_d               ; marker and its width
        cpy #0                 ; a word's start?
        beq rd2
        ldx LBUF-1,y
        cpx #' '
        bne rd_nx
rd2     lda #1
        sta cp_lim
        lda LBUF+1,y
        cmp cp_d
        bne rd3
        inc cp_lim
rd3     sty cp_y               ; the word: Y ... its end
        ldx #0                 ; > : LBUFF, < : LBUFF+32
        lda cp_d
        cmp #'>'
        beq rd4
        ldx #32
rd4     stx cp_x
        jmp rd_w
rd_sq0  lda #1
        sta cp_fl
        bne rd_nx
rd_dq0  lda #2
        sta cp_fl
        bne rd_nx
rd_qend lda #0
        sta cp_fl
        beq rd_nx
rd_esc  iny
        lda LBUF,y
        cmp #EOL
        beq rd_go
rd_nx   iny
        jmp rd1
rd_go   jsr pp_redir           ; (a pipe stage: its files)
        lda cp_ro              ; output first
        beq rd_in
        cmp #$40               ; explicit output was opened while parsing
        beq rd_in
        lda LBUFF
        cmp #EOL
        bne rd_o1
        lda #163
        jmp fail
rd_o1   ldx #0
        jsr rd_cp
        ldy #0
        lda cp_ro
        cmp #2
        bne rd_omode
        ldy #2
rd_omode
        jsr farcall
        dta b(BK_LIB),a(L_DIVIO)
rd_in   lda cp_ri
        beq rd_ret
        cmp #$40               ; explicit input was opened while parsing
        beq rd_ret
        lda LBUFF+32
        cmp #EOL
        bne rd_i1
        lda #E_NOTFOUND
        jmp fail
rd_i1   ldx #32
        jsr rd_cp
        ldy #1
        jsr farcall
        dta b(BK_LIB),a(L_DIVIO)
rd_ret  rts
* rd_cp: the name at LBUFF+X to COMFNAM, FILE_P at it
rd_cp   ldy #0
rc1     lda LBUFF,x
        sta COMFNAM,y
        inx
        iny
        cmp #EOL
        bne rc1
        lda #<COMFNAM
        sta FILE_P
        lda #>COMFNAM
        sta FILE_P+1
        rts
* rd_w: parse and open the redirection operand immediately.  U_GETPAR
* removes quotes and escapes into the full 128-byte COMFNAM, so redirection
* names have the same 127-byte path limit as ordinary arguments.  $40 marks
* an explicit stream already opened; $80 remains a pending pipeline stream.
rd_w    ldx cp_x               ; 0 output, 32 input
        stx cp_d
        lda #0
        sta cp_i               ; bit 7: this is the first of its direction
        cpx #0
        bne rw_i
        lda cp_ro
        bne rw_parse
        lda #$80
        sta cp_i
        lda #1                 ; truncate, or append for a double >
        ldy cp_lim
        cpy #2
        bne rw_os
        lda #2
rw_os   sta cp_ro
        bne rw_parse
rw_i    lda cp_ri
        bne rw_parse
        lda #$80
        sta cp_i
        lda #1
        sta cp_ri
rw_parse ldy cp_y              ; parse immediately after the marker(s)
rw_m    iny
        dec cp_lim
        bne rw_m
        sty BUFOFF
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq rw_bad
        bit cp_i
        bpl rw_remove          ; later redirect of this kind is just dropped
        ldx cp_d
        bne rw_openi
        lda cp_ro
        ldy #0
        cmp #2
        bne rw_open
        ldy #2
        bne rw_open
rw_openi ldy #1
rw_open jsr farcall
        dta b(BK_LIB),a(L_DIVIO)
        lda #$40
        ldx cp_d
        bne rw_marki
        sta cp_ro
        bne rw_remove
rw_marki sta cp_ri
rw_remove ldy BUFOFF           ; remove marker and operand
        ldx cp_y
        lda LBUF,y             ; at end, remove its preceding blank too;
        cmp #EOL               ; before another word that blank separates it
        bne rw_mv
        cpx #0
        beq rw_mv
        lda LBUF-1,x
        cmp #' '
        bne rw_mv
        dex
rw_mv   lda LBUF,y
        sta LBUF,x
        inx
        iny
        cmp #EOL
        bne rw_mv
        lda #0                 ; rescan quote state after the edit
        sta cp_fl
        ldy #0
        jmp rd1
rw_bad  lda #163
        jmp fail

* envget: the value of variable cp_nm (EOL ended) to LBUFF+X: C=0, X past
* it; C=1 none (X kept). It stops at LBUFF+63 when X starts below 64 (to
* keep CP_NAME), else at LBUFF+127.
envget  stx cp_x
        txa
        ora #127
        sta cp_lim
        jsr farcall            ; (lib2: env.icl)
        dta b(BK_LIB2),a(L2_ENGETX)
        rts

* addext: the extension at AX added to CP_NAME when its name has none
addext  sta fadr
        stx fadr+1
        ldx #0
        ldy #0                 ; Y: after the last dot of the name, 0 none
ad1     lda CP_NAME,x
        cmp #EOL
        beq ad3
        cmp #'.'
        bne ad2
        txa
        tay
        iny
ad2     cmp #'/'
        beq ad2s
        cmp #':'
        bne ad2n
ad2s    ldy #0
ad2n    inx
        bne ad1
ad3     tya
        bne ad5
ad4     lda (fadr),y
        sta CP_NAME,x
        inx
        iny
        cmp #EOL
        bne ad4
ad5     rts

* find: CP_NAME opened for reading: as given, then (a name without device
* or directory) after each $PATH entry. C=0: file_id, COMFNAM the name
* that was found; C=1 none
find    ldy #0                 ; device or directory given?
        sty cp_fl
fi0     lda CP_NAME,y
        cmp #EOL
        beq fi1
        iny
        cmp #':'
        beq fi0a
        cmp #'/'
        beq fi0a
        bne fi0
fi0a    dec cp_fl
        bne fi0
fi1     ldx #0                 ; as given
        jsr try
        bcc fi_ret
        lda cp_fl
        bne fi_no
        jsr nm_path
        ldx #0
        jsr envget
        bcs fi_no
        lda #EOL
        sta LBUFF,x
        lda #0
        sta cp_d               ; the next entry
fi2     ldy cp_d
        lda LBUFF,y
        cmp #EOL
        beq fi_no
        ldx #0                 ; the entry to COMFNAM
fi3     lda LBUFF,y
        cmp #';'
        beq fi4
        cmp #EOL
        beq fi5
        sta COMFNAM,x
        inx
        iny
        cpx #24
        bcc fi3
fi4     iny
fi5     sty cp_d
        txa                    ; a separator after a directory name
        beq fi6
        lda COMFNAM-1,x
        cmp #':'
        beq fi6
        cmp #'/'
        beq fi6
        lda #'/'
        sta COMFNAM,x
        inx
fi6     jsr try
        bcs fi2
fi_ret  rts
fi_no   sec
        rts

* try: COMFNAM+X = CP_NAME, opened for reading: C=0 file_id; C=1 not there
try     ldy #0
tr1     lda CP_NAME,y
        cmp #EOL
        beq tr1a
        bit cp_fl              ; bare command names use the lowercase default;
        bmi tr1a               ; an explicit device/path remains exact-case
        jsr farcall
        dta b(BK_LIB),a(L_TOLOWER)
tr1a
        sta COMFNAM,x
        inx
        iny
        cmp #EOL
        beq tr2
        cpx #29
        bcc tr1
        lda #EOL
        sta COMFNAM,x
tr2     lda #<COMFNAM
        sta FILE_P
        lda #>COMFNAM
        sta FILE_P+1
        jsr farcall
        dta b(BK_LIB),a(L_GEFINA2)
        bcs tr_no
        lda #$04
        sta mode
        lda #$A0               ; files only
        sta scan
        lda #0
        sta attr
        ldy #9                 ; kd_open
        jsr jkernel
        bmi tr_no
        clc
        rts
tr_no   sec
        rts

* putenv: PUTENV of AX
putenv  jsr farcall
        dta b(BK_LIB),a(L_PUTENV)
        rts

* putc: A to standard output; keeps A, X, Y
putc    stx cp_x
        sty cp_y
        pha
        jsr farcall
        dta b(BK_LIB),a(L_PUTC)
        pla
        ldx cp_x
        ldy cp_y
        rts

* prline: LBUF from Y and an EOL to standard output; prtext: without the EOL
prline  jsr prtext
        lda #EOL
        jmp putc
prtext  lda LBUF,y
        cmp #EOL
        beq pt1
        jsr putc
        iny
        bne prtext
pt1     rts

* closeall: close every file but the batch file (after a command or an error)
closeall ldx #15
ca1     lda dev_index,x
        cmp #$FF
        beq ca2
        cpx cp_bat
        beq ca2
        cpx COMTAB+6           ; standard output and input stay
        beq ca2
        cpx COMTAB+7
        beq ca2
        stx file_id
        stx cp_i
        ldy #7                 ; kd_close
        jsr jkernel
        ldx cp_i
ca2     dex
        bpl ca1
        rts

* ===========================================================================
* C4: the other internal commands of SDX's COMMAND.COM (outputs measured on
* SDX, PROGRESS.md C4)

* fsone: kernel function Y on native argv[1]; fsone2: on COMFNAM as it is.
fsone   sty cp_d
        lda CP_ARGC
        cmp #2
        bne fs_bad
        lda #1
        jsr argvcom
fsone2  jsr gefina
        ldy cp_d
        jsr jkernel
        jmi fail
        jmp cp_loop
fs_bad  lda #E_BADPARM
        jmp fail
* gefina: U_GEFINA of COMFNAM (an empty one: the current directory)
gefina  lda #<COMFNAM
        sta FILE_P
        lda #>COMFNAM
        sta FILE_P+1
        jsr farcall
        dta b(BK_LIB),a(L_GEFINA)
        rts

* ---- CD [path]: alone, the current directory (backslash SUB; nothing for the main)
c_cd    lda CP_ARGC
        cmp #1
        beq cw1
        cmp #2
        bne fs_bad
        lda #1
        jsr argvcom
        ldy #16                ; kd_chdir
        sty cp_d
        jmp fsone2
cw1     jsr gefina
        ldy #17                ; kd_cwd
        jsr jkernel
        jmi fail
        ldx #0
cw2     lda path,x
        jeq cw3
        jsr putc
        inx
        bne cw2
cw3     lda #EOL
        jsr putc
        jmp cp_loop

* ---- MD, RD, BOOT --------------------------------------------------------------
c_md    lda CP_ARGC
        cmp #2
        beq md1
        lda #163               ; no name (SDX)
        jmp fail
md1     ldy #14                ; kd_credir
        jmp fsone
c_rd    ldy #15                ; kd_deldir
        jmp fsone
c_boot  ldy #18                ; kd_boot
        jmp fsone

* ---- REN old new, RENDIR old new: 165 without the new name ---------------------
* Parse both words separately.  The old packed "old new" library interface
* cannot represent spaces in either EOSFS name.
c_ren   lda #$80               ; files
        sta scan
        jsr twonm
        jsr farcall
        dta b(BK_LIB),a(L_RENAME)
        jmp cp_loop
c_rendir lda #$08              ; directories
        sta scan
        jsr twonm
        jsr farcall
        dta b(BK_LIB),a(L_RENDIR)
        jmp cp_loop

* twonm: the next two dequoted parameters as OLD,NEW at LBUFF.  Native
* RENAME uses comma as its unambiguous separator, leaving spaces available
* inside either exact EOSFS name.
twonm   lda CP_ARGC
        cmp #3
        bne ren_bad
        lda #1
        jsr argvcom
        ldx #0
tn1     lda COMFNAM,x
        sta LBUFF,x
        inx
        cmp #EOL
        bne tn1
        stx cp_x
        lda #2
        jsr argvcom
        ldx cp_x
        lda #','
        sta LBUFF-1,x
        ldy #0
tn2     lda COMFNAM,y
        sta LBUFF,x
        inx
        iny
        cmp #EOL
        bne tn2
        lda #<LBUFF
        sta FILE_P
        lda #>LBUFF
        sta FILE_P+1
        rts
ren_bad
        lda #165               ; no new name (SDX)
        jmp fail

* ---- DEL name: all wild cards ask first ---------------------------------------
c_del   lda CP_ARGC
        cmp #2
        beq dl_arg
        lda #E_NOTFOUND
        jmp fail
dl_arg  lda #1
        jsr argvcom
dl0     jsr gefina
        ldx #10
dl1     lda name,x
        cmp #'?'
        bne dl3
        dex
        bpl dl1
        ldx #0                 ; ERASE ALL: Are you sure? (a line; Y erases)
dl2     lda erall,x
        jsr putc
        inx
        cpx #erall_end-erall
        bcc dl2
        jsr k_getline
        lda LBUF
        jsr upper
        cmp #'Y'
        jne cp_loop
dl3     lda #0
        sta scan
        ldy #12                ; kd_delete
        jsr jkernel
        jmi fail
        jmp cp_loop
erall   dta c'ERASE ALL: Are you sure? '
erall_end equ *

* ---- ATR [+|-][A|H|P] ... name: the attributes set or cleared ----------------
c_atr   lda #0
        sta attr
at1     jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        bne at2
        lda #E_NOTFOUND        ; no name
        jmp fail
at2     jsr atrtok
        bcc at1
        jsr gefina             ; the name: every entry matching it
        lda #0
        sta scan
        ldy #13                ; kd_setatr
        jsr jkernel
        jmi fail
        jmp cp_loop
* atrtok: COMFNAM a +X / -X word (P, H, A, S): C=0, attr (set: bits,
* cleared: bits << 4) and scan (with: bits, without: bits << 4) and cp_fl
* (the letters seen) updated; C=1 not such a word
atrtok  lda COMFNAM
        cmp #'+'
        beq ak1
        cmp #'-'
        bne ak_no
ak1     sta cp_y
        ldx #1
ak2     lda COMFNAM,x
        cmp #EOL
        beq ak_ok
        ldy #3
ak3     cmp atrch,y
        beq ak4
        dey
        bpl ak3
ak_no   sec
        rts
ak4     lda atrbit,y
        pha
        ora cp_fl
        sta cp_fl
        pla
        ldy cp_y
        cpy #'-'
        bne ak5
        asl @
        asl @
        asl @
        asl @
ak5     pha
        ora attr
        sta attr
        pla
        ora cp_scan
        sta cp_scan
        inx
        bne ak2
ak_ok   clc
        rts
atrch   dta c'PHAS'
atrbit  dta b($01,$02,$04,$08)

* ---- TYPE [+|-attributes] name [/P], MORE name (TYPE /P) ---------------------
c_more  lda #$80
        dta b($2C)
c_type  lda #0
        sta cp_pg
        lda #0
        sta cp_fl
        sta cp_scan
ty0     jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        bne ty1
        lda #E_NOTFOUND        ; no name (SDX)
        jmp fail
ty1     jsr atrtok
        bcc ty0
        lda cp_fl              ; -H and -S unless given
        and #$02
        bne ty1a
        lda cp_scan
        ora #$20
        sta cp_scan
ty1a    lda cp_fl
        and #$08
        bne ty1b
        lda cp_scan
        ora #$80
        sta cp_scan
ty1b    ldx #0                 ; the name, then /P
ty1c    lda COMFNAM,x
        sta CP_NAME,x
        inx
        cmp #EOL
        bne ty1c
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq ty1e
        lda COMFNAM
        cmp #'/'
        bne ty1e
        lda COMFNAM+1
        cmp #'P'
        bne ty1e
        lda #$80
        sta cp_pg
ty1e    ldx #0
ty1f    lda CP_NAME,x
        sta COMFNAM,x
        inx
        cmp #EOL
        bne ty1f
        jsr gefina
        lda #$04
        sta mode
        lda cp_scan
        sta scan
        lda #0
        sta attr
        sta cp_n
        ldy #9                 ; kd_open
        jsr jkernel
        jmi fail
        lda file_id
        sta cp_fid
        lda #0                 ; standard output the screen (CON:)?
        sta cp_col
        sta cp_con
        ldx COMTAB+6
        lda dev_index,x
        and #$F0
        cmp #$30
        bne ty2
        dec cp_con
ty2     lda cp_fid
        sta file_id
        jsr farcall
        dta b(BK_LIB),a(L_FGETC)
        bmi ty3
        jsr putc
        cmp #EOL
        beq ty2b
        bit cp_con             ; on the screen a line breaks after 37
        bpl ty2                ; characters, as SDX's TYPE does it
        inc cp_col
        lda cp_col
        cmp #37
        bcc ty2
        lda #EOL
        jsr putc
ty2b    lda #0
        sta cp_col
        bit cp_pg              ; /P: after 23 lines
        bpl ty2
        inc cp_n
        lda cp_n
        cmp #23
        bcc ty2
        lda #0
        sta cp_n
        jsr presret
        jmp ty2
ty3     lda cp_fid
        sta file_id
        jsr farcall
        dta b(BK_LIB),a(L_FCLOSE)
        jmp cp_loop

* presret: "   Press <RETURN> to continue " and a line from the keyboard
presret ldx #0
ps1     lda prret,x
        jsr putc
        inx
        cpx #prret_end-prret
        bcc ps1
        jmp k_getline
prret   dta c'   Press <RETURN> to continue '
prret_end equ *

* ---- PAUSE [seconds] -----------------------------------------------------------
c_pause jsr farcall
        dta b(BK_LIB),a(L_GETNUM)
        bne pz1
        jsr presret
        jmp cp_loop
pz1     sta cp_n               ; seconds (50 frames each)
        stx cp_n+1
pz2     lda cp_n
        ora cp_n+1
        jeq cp_loop
        ldx #50
pz3     lda RTCLOK+2
pz4     cmp RTCLOK+2
        beq pz4
        dex
        bne pz3
        lda cp_n
        bne pz5
        dec cp_n+1
pz5     dec cp_n
        jmp pz2

* ---- VERIFY [ON|OFF] -----------------------------------------------------------
c_vfy   ldy BUFOFF
        jsr onoff
        bcs vf1
        tax
        lda #'P'
        cpx #0
        beq vf0
        lda #'W'
vf0     sta k_wrtcmd
vf1     ldx #0
vf2     lda vfytx,x
        jsr putc
        inx
        cpx #10
        bcc vf2
        ldx #3                 ; ON or OFF
        lda k_wrtcmd
        cmp #'W'
        bne vf3
        ldx #0
vf3     lda vfyon,x
        jsr putc
        inx
        cmp #EOL
        bne vf3
        jmp cp_loop
vfytx   dta c'VERIFY is '
vfyon   dta c'ON',b(EOL),c'OFF',b(EOL)

* ---- REPORT [code], SETERRNO code ------------------------------------------------
c_report jsr farcall
        dta b(BK_LIB),a(L_GETNUM)
        bne rp1
        lda ERRNO
rp1     cmp #0
        jeq cp_loop
        cmp #128
        bcs rp2
        pha                    ; 1-127: Exit code N
        ldx #0
rp1a    lda exitc,x
        jsr putc
        inx
        cpx #10
        bcc rp1a
        pla
        jsr prdec
        lda #EOL
        jsr putc
        jmp cp_loop
rp2     jsr farcall            ; the system's message
        dta b(BK_LIB),a(L_ERROR)
        jmp cp_loop
exitc   dta c'Exit code '
c_seterr jsr farcall
        dta b(BK_LIB),a(L_GETNUM)
        bne se1
        lda #E_BADPARM
        jmp fail
se1     sta ERRNO
        jmp cp_loop
* prdec: A in decimal, no leading zeros; keeps nothing
prdec   ldy #0
        sty cp_lz
pd0     ldx #0
pd1     cmp pdtab,y
        bcc pd2
        sbc pdtab,y
        inx
        bne pd1
pd2     pha
        txa
        bne pd3
        lda cp_lz
        beq pd4
pd3     txa
        ora #'0'
        jsr putc
        sta cp_lz
pd4     pla
        iny
        cpy #2
        bcc pd0
        ora #'0'
        jmp putc
pdtab   dta b(100,10)

* ---- SWAP [d d]: alone, the drive map ----------------------------------------
c_swap  jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq sw_ls
        jsr swdrv
        stx cp_x
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq sw_bad
        jsr swdrv
        ldy cp_x               ; the two entries change places
        lda COMTAB2+2,x
        pha
        lda COMTAB2+2,y
        sta COMTAB2+2,x
        pla
        sta COMTAB2+2,y
        jmp cp_loop
sw_bad  lda #E_BADPARM
        jmp fail
* swdrv: COMFNAM a drive letter A-O or digit 1-9 alone: X = 0-14
swdrv   lda COMFNAM+1
        cmp #EOL
        bne sw_bad
        lda COMFNAM
        cmp #'1'
        bcc sw_bad
        cmp #'9'+1
        bcs sw1
        and #$0F
        bne sw2
sw1     cmp #'A'
        bcc sw_bad
        cmp #'O'+1
        bcs sw_bad
        sbc #'A'-2
sw2     tax
        dex
        rts
* A: = drive 1 ... O: = drive 15
sw_ls   ldx #0
sw3     stx cp_d
        txa
        clc
        adc #'A'
        jsr putc
        ldx #0
sw4     lda swtx,x
        jsr putc
        inx
        cpx #swtx_end-swtx
        bcc sw4
        ldx cp_d
        lda COMTAB2+2,x
        jsr prdec
        lda #EOL
        jsr putc
        ldx cp_d
        inx
        cpx #15
        bcc sw3
        jmp cp_loop
swtx    dta c': = drive '
swtx_end equ *

* ---- PROMPT [text]: alone, $PROMPT (PROMPT= when there is none) ----------------
c_prompt ldy BUFOFF
        lda LBUF,y
        cmp #EOL
        bne pm3
        jsr nm_prm
        ldx #0
        jsr envget
        bcc pm1
        ldx #6                 ; none: PROMPT= (SDX)
pm0     lda nmprm,x
        sta LBUFF,x
        dex
        bpl pm0
        ldx #7
pm1     lda #EOL
        sta LBUFF,x
        ldx #0
pm2     lda LBUFF,x
        jsr putc
        inx
        cmp #EOL
        bne pm2
        jmp cp_loop
pm3     ldx #6                 ; SET PROMPT=...
pm4     lda nmprm,x
        sta LBUFF,x
        dex
        bpl pm4
        ldx #7
        jmp st3
nmprm   dta c'PROMPT='
nmcsp   dta c'COMSPEC'

* cspec: $COMSPEC set: that program runs (FLAG $02: as the shell, which
* SC's SCMAIN.OVL wants) and the loop comes back here when it ends. When
* the last one failed (U_FAIL), the prompt this once.
cspec   bit cs_try
        bpl cs1
        lda #0
        sta cs_try
cs_no   rts
cs1     ldx #6
cs2     lda nmcsp,x
        sta cp_nm,x
        dex
        bpl cs2
        lda #EOL
        sta cp_nm+7
        ldx #0
        jsr envget
        bcs cs_no
        txa
        beq cs_no
        ldx #0                 ; the command line: its name alone
cs3     lda LBUFF,x
        sta LBUF,x
        inx
        cmp #EOL
        beq cs4
        cpx #127
        bcc cs3
        lda #EOL
        sta LBUF,x
cs4     pla                    ; (not back to cp_int)
        pla
        lda #0
        sta BUFOFF
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq cs5
        lda #$80
        sta cs_try
        ldy #2
        sty cp_lflag
        lda #<dotcom
        ldx #>dotcom
        jmp runprg2
cs5     jmp cp_int2
nm_prm  ldx #5
np2     lda nmprm,x
        sta cp_nm,x
        dex
        bpl np2
        lda #EOL
        sta cp_nm+6
        rts

* ---- LOAD [name]: loaded, not run (no extension added); alone: unload --------
c_load  jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        bne lo1
        jsr farcall
        dta b(BK_LD),a(LD_RESET)
        jmp cp_loop
lo1     lda #$80               ; FLAG: no execution
        sta cp_lflag
        lda #<noext
        ldx #>noext
        jmp runprg2
noext   dta b(EOL)

* ---- COPY: $COPY, or CAR:COPY.COM, with the parameters ---------------------------
c_cp    ldx #10
cpnative1 lda carcp,x
        sta CP_NAME,x
        dex
        bpl cpnative1
        lda #0
        sta cp_lflag
        lda #<dotcom
        ldx #>dotcom
        jmp runnm
carcp   dta c'CAR:cp.com',b(EOL)

c_cat   ldx #11
catn1   lda carcat,x
        sta CP_NAME,x
        dex
        bpl catn1
        lda #0
        sta cp_lflag
        lda #<dotcom
        ldx #>dotcom
        jmp runnm
carcat  dta c'CAR:cat.com',b(EOL)

c_copy  ldx #4
cy1     lda nmcopy,x
        sta cp_nm,x
        dex
        bpl cy1
        ldx #64
        jsr envget
        bcc cy3
        ldx #12
cy2     lda carcopy,x
        sta CP_NAME,x
        dex
        bpl cy2
        bmi cy4
cy3     lda #EOL
        sta LBUFF,x
cy4     lda #0
        sta cp_lflag
        lda #<dotcom
        ldx #>dotcom
        jmp runnm
nmcopy  dta c'COPY',b(EOL)
carcopy dta c'CAR:copy.com',b(EOL)

* ---- CLR: the variables starting with _ deleted ---------------------------------
c_clr   lda #0
        sta cp_d
cr1     lda cp_d
        jsr farcall
        dta b(BK_LIB),a(L_NUMENV)
        cmp #0
        jne cp_loop
        lda LBUFF
        cmp #'_'
        bne cr3
        ldx #0                 ; NAME alone: PUTENV deletes it
cr2     inx
        lda LBUFF,x
        cmp #'='
        bne cr2
        lda #EOL
        sta LBUFF,x
        lda #<LBUFF
        ldx #>LBUFF
        jsr putenv
        jmp cr1
cr3     inc cp_d
        jmp cr1

* ---- BASIC [/I|N] -----------------------------------------------------------
* The internal BASIC (k_basic: EOS's cartridge off, BASIC on, its cold
* start). /I (no memory save file) and /N are accepted. Redirected input
* stays on: BASIC <<file reads the file's lines through E: (k_ehand) and
* then the keyboard.
c_basic jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq cb_go
        lda COMFNAM
        cmp #'/'
        bne cb_bad
        lda COMFNAM+2
        cmp #EOL
        bne cb_bad
        lda COMFNAM+1
        cmp #'I'
        beq c_basic
        cmp #'N'
        beq c_basic
cb_bad  lda #E_BADPARM
        jmp fail
cb_go   jmp k_basic

* ---- COLD, VER ---------------------------------------------------------------------
c_cold  jsr farcall             ; /N (and /C: no cartridge rides on
        dta b(BK_LIB),a(L_GETPAR) ; EOS's): as if no cartridges were present
        beq cc_go
        lda COMFNAM
        cmp #'/'
        bne cb_bad
        lda COMFNAM+2
        cmp #EOL
        bne cb_bad
        lda COMFNAM+1
        cmp #'N'
        beq cc_n
        cmp #'C'
        bne cb_bad
cc_n    jmp k_coldn
cc_go   jmp COLDSV
c_ver   ldx #0
vr1     lda cpbanner,x
        jsr putc
        inx
        cpx #cpbanner_end-cpbanner
        bcc vr1
        jmp cp_loop

* mkprompt: the prompt from $PROMPT to LBUFF, X = its length (an EOL
* first). The rendered prompt is always enclosed in []: $L the drive letter
* and a colon, $N its number (J-O above 9; for
* another device its name and unit), $P its directory, $R an EOL, _ a
* blank; $D and $T (date and time) show nothing yet (no clock). No
* $PROMPT: >.
mkprompt jsr nm_prm
        ldx #64
        jsr envget
        bcc mk0
        ldx #64
        lda #'>'
        sta LBUFF,x
        inx
mk0     lda #EOL
        sta LBUFF,x
        sta LBUFF
        lda #'['
        sta LBUFF+1
        ldy #64
        ldx #2
mk1     lda LBUFF,y
        cmp #EOL
        beq mk_end
        iny
        cmp #'_'
        bne mk2
        lda #' '
        bne mk_put
mk2     cmp #'$'
        bne mk_put
        lda LBUFF,y
        cmp #EOL
        beq mk_end
        iny
        cmp #'L'
        beq mk_l
        cmp #'N'
        beq mk_n
        cmp #'P'
        jeq mk_p
        cmp #'R'
        bne mk3
        lda #EOL
        bne mk_put
mk3     cmp #'D'
        beq mk1
        cmp #'T'
        beq mk1
mk_put  cpx #127
        bcs mk1
        sta LBUFF,x
        inx
        jmp mk1
mk_end  cpx #127
        bcs mk_done
        lda #']'
        sta LBUFF,x
        inx
mk_done rts
mk_l    lda CURDEV             ; a drive: its name (A:, or Dn: when CIO
        cmp #$10               ; has a device with its letter)
        bcs mk_dev
        stx cp_x
        sty cp_y
        jsr farcall
        dta b(BK_LIB),a(L_DRVNAME)
        ldx cp_x
        ldy #0
mk_l1   lda dv_nm,y
        cmp #EOL
        beq mk_l2
        cpx #127
        bcs mk_l2
        sta LBUFF,x
        inx
        iny
        bne mk_l1
mk_l2   ldy cp_y
        jmp mk1
mk_n    lda CURDEV
        cmp #$10
        bcs mk_dev
        and #$0F
        cmp #10
        bcc mk_n1
        adc #'A'-2             ; C=1: 10 is J
        bne mk_col
mk_n1   ora #'0'
mk_col  sta LBUFF,x
        inx
        lda #':'
        bne mk_put
mk_dev  sty cp_y               ; DEVNAME's name and the unit
        lsr @
        lsr @
        and #$3C
        tay
        lda #3
        sta cp_d
mk_d1   lda DEVNAME,y
        sta LBUFF,x
        inx
        iny
        dec cp_d
        bne mk_d1
        ldy cp_y
        lda CURDEV
        and #$0F
        ora #'0'
        bne mk_col
mk_p    sty cp_y               ; the current directory of the current drive
        stx cp_x
        lda CURDEV
        sta device
        ldy #17                ; kd_cwd
        jsr jkernel
        php
        ldx cp_x
        ldy cp_y
        plp
        jmi mk1
        sty cp_y
        ldy #0
mk_p1   lda path,y
        beq mk_p2
        sta LBUFF,x
        inx
        iny
        cpx #60
        bcc mk_p1
mk_p2   ldy cp_y
        jmp mk1


* ==========================================================================
* RAMDISK [drive[,nbanks]] [/S]: a RAM disk in the extended banks, as SDX's
* RAMDISK.SYS: drive O: and all banks but four (kept for 130XE programs)
* unless given; the top free banks, taken from NBANKS. Its sectors (256
* bytes, 64 to a bank) are read and written by the FMS (rdio). One RAM
* disk (SDX allows three). An EOSFS v2 disk ("X Disk O") is built in it,
* unless one of the same size is there already ("Ramdisk preserved",
* after COLD). $RAMDISK, $BASIC, $CAR and $TEMP are set when not set.
rdcmd   lda #0                 ; RAMDISK.SYS, DEVICE RAMDISK: with messages
        sta rd_q
rdinst  lda #15
        sta rd_u
        lda #0
        sta rd_want
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq ri2
        lda COMFNAM
        cmp #'/'
        beq ri2
        jsr rd_drv
        bcs ri_bad
        sta rd_u
        jsr farcall
        dta b(BK_LIB),a(L_GETPAR)
        beq ri2
        lda COMFNAM
        cmp #'/'
        beq ri2
        jsr rd_num
        sta rd_want
ri2     ldx #0                 ; a free entry, the first: three RAM disks,
ri2a    lda rd_unit,x          ; as SDX
        beq ri2b
        inx
        cpx #NRD
        bcc ri2a
        ldx #rdno_f-rdno       ; none: "SIO table full!"
        bne ri_msg
ri_bad  ldx #rdno_x-rdno       ; not a drive: "No extended RAM"
ri_msg  bit rd_q               ; "Ramdisk not installed" and the reason
        bmi ri_r
        txa
        pha
        ldx #0
ri_b1   lda rdno,x
        jsr putc
        inx
        cpx #rdno_x-rdno
        bcc ri_b1
        pla
        tax
ri_b2   lda rdno,x
        jsr putc
        inx
        cmp #EOL
        bne ri_b2
ri_r    rts
ri2b    stx rd_cx
ri3     lda COMTAB+$1D         ; the banks: given (at most all), else all
        ldx rd_want            ; but four; an invalid count (0, too many):
        beq ri4                ; the default
        cpx COMTAB+$1D
        bcs ri4
        txa
        jmp ri5
ri4     ldx l2_pb              ; (the second-level cache's bank is one of
        beq ri4a               ; the four left: the RAM disk as on SDX)
        clc
        adc #1
ri4a    sec
        sbc #4
        jcc ri_none
ri5     cmp #0
        beq ri_none
        sta rd_cn
        sec                    ; the top free banks
        lda COMTAB+$1D
        sbc rd_cn
        sta COMTAB+$1D
        ldx SYSLEVEL           ; also in the counts kept for the levels
ri5a    dex                    ; below (RAMDISK.SYS: the loader puts the
        bmi ri5b               ; caller's back when it ends)
        sec
        lda ld_xbn,x
        sbc rd_cn
        bcs ri5c
        lda #0
ri5c    sta ld_xbn,x
        jmp ri5a
ri5b    lda COMTAB+$1D
        clc
        adc #4
        sta rd_cf
        ldx rd_cx
        sta rd_first,x
        lda rd_cn
        sta rd_n,x
        lda rd_u
        sta rd_unit,x
        lda rd_cn              ; 64 sectors a bank
        sta rd_tot
        lda #0
        sta rd_tot+1
        ldx #6
ri6     asl rd_tot
        rol rd_tot+1
        dex
        bne ri6
        lda rd_cn              ; bitmap sectors: (n + 32) / 32
        clc
        adc #32
        lsr @
        lsr @
        lsr @
        lsr @
        lsr @
        sta rd_bm
        jsr rd_old
        bcs ri7
        jsr rd_fmt
        jmp ri8
ri7     ldx #0                 ; Ramdisk preserved
ri7a    lda rdkept,x
        jsr putc
        inx
        cpx #rdkept_end-rdkept
        bcc ri7a
ri8     jmp rd_env
ri_none ldx #rdno_x-rdno       ; no banks: "No extended RAM" when a size
        lda rd_want            ; was given, else what is kept for XE
        jne ri_msg             ; programs
        ldx #rdno_4-rdno
        jmp ri_msg

* rd_drv: COMFNAM a drive (letter A-O, digits 1-15, with or without ':')
* in A; C=1 not one
rd_drv  lda COMFNAM
        cmp #'A'
        bcc rv1
        cmp #'O'+1
        bcs rv_no
        sbc #'A'-2             ; C=0: - ('A'-1)
        clc
        rts
rv1     jsr rd_num
        cmp #1
        bcc rv_no
        cmp #16
        bcs rv_no
        clc
        rts
rv_no   sec
        rts
* rd_num: the decimal number at COMFNAM (to 255) in A
rd_num  ldx #0
        lda #0
        sta cp_d
rn1     lda COMFNAM,x
        cmp #'0'
        bcc rn2
        cmp #'9'+1
        bcs rn2
        and #$0F
        sta cp_x
        lda cp_d               ; * 10 + digit
        asl @
        asl @
        adc cp_d
        asl @
        adc cp_x
        sta cp_d
        inx
        bne rn1
rn2     lda cp_d
        rts

* rd_sec: fadr = sector rd_k's 256 bytes in its bank, which is selected
* (the OS ROM on); rd_end selects main memory again
rd_sec  lda rd_k
        sec
        sbc #1
        sta fadr+1
        lda rd_k+1
        sbc #0
        sta cp_x
        lda fadr+1             ; bank (s-1) / 64
        asl @
        rol cp_x
        asl @
        rol cp_x
        lda fadr+1
        and #$3F
        ora #$40
        sta fadr+1
        lda #0
        sta fadr
        lda cp_x
        clc
        adc rd_cf
        jsr k_tconv
        sta PORTB
        rts
rd_end  lda #$FF
        sta PORTB
        rts

* rd_old: C=1 the banks hold this RAM disk already (EOSFS v2 header,
* its size, its volume name)
rd_old  lda #1
        sta rd_k
        lda #0
        sta rd_k+1
        jsr rd_sec
        ldy #32
        lda (fadr),y
        cmp #$47
        beq ro_ver
        cmp #$48
        bne ro_no
ro_ver
        ldy #11
        lda (fadr),y
        cmp rd_tot
        bne ro_no
        iny
        lda (fadr),y
        cmp rd_tot+1
        bne ro_no
        jsr rd_vol
        ldy #22+7
ro1     lda (fadr),y
        cmp LBUFF-22,y
        bne ro_no
        dey
        cpy #22
        bcs ro1
        jsr rd_end
        sec
        rts
ro_no   jsr rd_end
        clc
        rts
* rd_vol: "X Disk O" (the drive's letter) at LBUFF
rd_vol  ldx #7
rv2     lda rdvol,x
        sta LBUFF,x
        dex
        bpl rv2
        lda rd_u
        clc
        adc #'A'-1
        sta LBUFF+7
        rts

* rd_fmt: an empty EOSFS v2 disk: boot sectors 1-3 (the header), the
* bitmap from 4, the main directory's extent list, then its data sector
rd_fmt  lda #1                 ; the first sectors cleared
        sta rd_k
        lda #0
        sta rd_k+1
rf1     jsr rd_sec
        ldy #0
        tya
rf2     sta (fadr),y
        iny
        bne rf2
        inc rd_k
        lda rd_k
        cmp #7
        bcc rf1
        lda rd_bm
        clc
        adc #5
        cmp rd_k
        bcs rf1
        lda #1                 ; the header
        sta rd_k
        jsr rd_sec
        ldy #8
rf3     lda rdboot,y
        sta (fadr),y
        dey
        bpl rf3
        lda rd_bm              ; map: 4 + bitmap sectors
        clc
        adc #4
        sta rd_dm
        ldy #9
        sta (fadr),y
        ldy #11
        lda rd_tot
        sta (fadr),y
        iny
        lda rd_tot+1
        sta (fadr),y
        sec                    ; free: total - 3 - bitmap - 2
        lda rd_tot
        sbc #5
        sta cp_n
        lda rd_tot+1
        sbc #0
        sta cp_n+1
        sec
        lda cp_n
        sbc rd_bm
        ldy #13
        sta (fadr),y
        iny
        lda cp_n+1
        sbc #0
        sta (fadr),y
        iny
        lda rd_bm
        sta (fadr),y
        iny
        lda #4                 ; the bitmap's first sector
        sta (fadr),y
        ldy #18                ; the next free sector to look at
        lda rd_dm
        clc
        adc #2
        sta (fadr),y
        jsr rd_vol
        ldy #29
rf4     lda LBUFF-22,y
        sta (fadr),y
        dey
        cpy #22
        bcs rf4
        ldy #30
        lda #1                 ; tracks 1, 256-byte sectors, EOSFS v2
        sta (fadr),y
        ldy #32
        lda #$47
        sta (fadr),y
        ldy #34
        lda #1
        sta (fadr),y
        iny
        lda #63                ; (256 - 4) / 4 extents
        sta (fadr),y
        ldy #37
        lda #1
        sta (fadr),y
        ldy #39
        lda RANDOM
        sta (fadr),y
        lda rd_dm              ; extent list: one run of one directory sector
        sta rd_k
        jsr rd_sec
        ldy #4
        lda rd_dm
        clc
        adc #1
        sta (fadr),y
        ldy #6
        lda #1
        sta (fadr),y
        inc rd_k               ; the directory: its own entry
        jsr rd_sec
        ldy #10
rf5     lda rddir,y
        sta (fadr),y
        dey
        bpl rf5
        ldy #38                ; created now (the date and time registers)
        ldx #0
rf6     lda $077B,x
        sta (fadr),y
        iny
        inx
        cpx #6
        bcc rf6
        lda rd_dm              ; the bitmap: the sectors after it free
        clc
        adc #2
        sta rd_k
        lda #0
        sta rd_k+1
rf7     lda rd_k               ; byte k / 8 of the bitmap (sector 4 on)
        sta cp_n
        lda rd_k+1
        lsr @
        ror cp_n
        lsr @
        ror cp_n
        lsr @
        ror cp_n
        clc
        adc #4                 ; (cp_n: the byte in its sector)
        sta cp_x
        lda rd_k
        pha
        lda rd_k+1
        pha
        lda cp_x
        sta rd_k
        lda #0
        sta rd_k+1
        jsr rd_sec
        pla
        sta rd_k+1
        pla
        sta rd_k
        and #7
        tax
        lda #$80
rf8     dex
        bmi rf9
        lsr @
        bne rf8
rf9     ldy cp_n
        ora (fadr),y
        sta (fadr),y
        inc rd_k
        bne rf10
        inc rd_k+1
rf10    lda rd_k+1             ; to the last sector
        cmp rd_tot+1
        bcc rf7
        bne rf11
        lda rd_tot
        cmp rd_k
        bcs rf7
rf11    jmp rd_end

* rd_env: $RAMDISK, $BASIC, $CAR and $TEMP, where not set
rd_env  ldx #0
re1     stx cp_y
        ldy #0                 ; the name, to cp_nm
re2     lda rdenv,x
        cmp #'='
        beq re3
        sta cp_nm,y
        inx
        iny
        bne re2
re3     lda #EOL
        sta cp_nm,y
        stx cp_d               ; (X at the =)
        ldx #0
        jsr envget
        bcc re6                ; set: kept
        ldx cp_y               ; NAME=d:... to LBUFF
        ldy #0
re4     lda rdenv,x
        cmp #'?'
        bne re5
        stx cp_x               ; the drive's name without its colon
        sty cp_i
        lda rd_u
        jsr farcall
        dta b(BK_LIB),a(L_DRVNAME)
        ldy cp_i
        ldx #0
re4a    lda dv_nm,x
        cmp #':'
        beq re4b
        sta LBUFF,y
        iny
        inx
        bne re4a
re4b    ldx cp_x
        inx
        jmp re4
re5     sta LBUFF,y
        inx
        iny
        cmp #EOL
        bne re4
        lda #<LBUFF
        ldx #>LBUFF
        jsr putenv
re6     ldx cp_y               ; the next
re7     lda rdenv,x
        inx
        cmp #EOL
        bne re7
        lda rdenv,x
        bne re1
        rts

rdname  dta c'RAMDISK',b(EOL)
rdvol   dta c'X Disk O'
rdboot  dta b($00,$03,$00,$30,$E0,$07,$4C,$80,$30)
rddir   dta b($28,0,0,44,0,0,4),c'main'
rdenv   dta c'RAMDISK=?:/',b(EOL),c'BASIC=?:/basic.sav',b(EOL)
        dta c'CAR=?:/car.sav',b(EOL),c'TEMP=?:/',b(EOL),b(0)
rdkept  dta c'Ramdisk preserved',b(EOL)
rdkept_end equ *
rdno    dta c'Ramdisk not installed',b(EOL)
rdno_x  dta c'No extended RAM',b(EOL)
rdno_4  dta c'64k left for XE programs',b(EOL)
rdno_f  dta c'SIO table full!',b(EOL)

        icl 'tail.icl'
