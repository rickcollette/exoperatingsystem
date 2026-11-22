; EOS CAR: MENU, the file manager
;   MENU
; The upper left window lists the logged directory (.) and its
; subdirectories, the upper right one the file specification and the
; counts, the lower one the files. Commands are typed as keys; RETURN
; switches between the file and the directory commands, ESC goes to the
; extra commands (Q quits).
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
REMOVE   smb 'REMOVE'
RENAME   smb 'RENAME'
MKDIR    smb 'MKDIR'
RMDIR    smb 'RMDIR'
GETDFREE smb 'GETDFREE'
U_GETKEY smb 'U_GETKEY'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
ERR_GMSG smb 'ERR_GMSG'
MALLOC   smb 'MALLOC'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
dentry   equ $0789
path     equ $0640
LMARGN   equ $52
ROWCRS   equ $54
COLCRS   equ $55
CRSINH   equ $02F0
ICCOM    equ $0342
ICBAL    equ $0344
ICBLL    equ $0348
CIOV     equ $E456
EOL      equ $9B
BSLASH   equ $5C
ESC      equ $1B
TAGCH    equ $60               ; the diamond

* zero page
ze       equ $80               ; an entry
zs       equ $82               ; strings
zm1      equ $84               ; moving entries
zm2      equ $86

ESIZE    equ 21                ; a file: status, size (3), name (11),
E_ST     equ 0                 ; date (d m y), time (h m), tag
E_SIZE   equ 1
E_NAME   equ 4
E_DATE   equ 15
E_TIME   equ 18
E_TAG    equ 20
MAXF     equ 245
MAXD     equ 48
FROW     equ 10                ; the file window: rows 10-20
FLINES   equ 11
DROW     equ 2                 ; the directory window: rows 2-8
DLINES   equ 7
MROW     equ 21                ; messages and questions

        blk reloc main
start   lda #<[MAXF*ESIZE+MAXD*11]
        sta bytbuf
        lda #>[MAXF*ESIZE+MAXD*11]
        sta bytbuf+1
        ldx #0
        ldy #0
        jsr MALLOC
        bpl st1
        lda #158
        jmp nomem
st1     lda addpos
        sta fbase
        clc
        adc #<[MAXF*ESIZE]
        sta dbase
        lda addpos+1
        sta fbase+1
        adc #>[MAXF*ESIZE]
        sta dbase+1
        ldx #4                 ; the copy buffer: as much as there is
st2     stx st_k
        lda #0
        sta bytbuf
        lda cbsz,x
        sta bytbuf+1
        ldx #0
        ldy #0
        jsr MALLOC
        bpl st3
        ldx st_k
        dex
        bpl st2
        lda #158
nomem   jmp nomem2
st3     lda addpos
        sta cbuf
        lda addpos+1
        sta cbuf+1
        ldx st_k
        lda cbsz,x
        sta cbsize+1
        lda LMARGN
        sta lmsave
        lda CRSINH
        sta cisave
        lda #0
        sta LMARGN
        sta curp
        sta logp
        lda #1
        sta CRSINH
        jsr reload
        jsr drawall
loop    jsr U_GETKEY
        sta key
        jsr docmd
        lda quit
        beq loop
        lda lmsave             ; Q: the screen as it was
        sta LMARGN
        lda cisave
        sta CRSINH
        lda #$7D
        jsr cput
        rts
nomem2  sta key                ; not even the lists: as U_FAIL does
        jsr ERR_GMSG
        stx zs
        sty zs+1
        ldy #0
nm1     lda (zs),y
        beq nm2
        jsr cput
        iny
        bne nm1
nm2     lda #EOL
        jmp cput

* docmd: the key's command, errors caught and shown on the message line
docmd   lda trapa
        ldx trapa+1
        jsr U_SFAIL
        jsr dispat
        jsr U_XFAIL
        rts
dc_err  sta key                ; the trap: an error
        jsr closeall
        lda #1
        sta CRSINH
        jsr sreload
        jsr drawall
        lda key
        jsr ERR_GMSG
        stx zs
        sty zs+1
        jsr lclr
        ldy #0
        jsr lstrz
        jsr msgout
        jmp showmsg

* sreload: reload; when that fails too, the current directory
sreload lda trap2a
        ldx trap2a+1
        jsr U_SFAIL
        jsr reload
        jmp U_XFAIL
sr_err  lda #0
        sta logp
        sta curp
        sta dcur
        sta dtop
        jmp reload

* dispat: by the menu
dispat  lda key
        ldx mmode
        cpx #2
        jeq xtra
        cmp #EOL
        bne dp1
        txa                    ; RETURN: file or directory commands
        eor #1
        sta mmode
        jmp drawall
dp1     cmp #ESC
        bne dp2
        stx pmode
        lda #2
        sta mmode
        jmp drawmenu
dp2     cpx #1
        jeq dircmd
* ---- file commands ------------------------------------------------------
        ldx #fkn-fks-1
fc1     cmp fks,x
        beq fc2
        dex
        bpl fc1
        rts
fc2     txa
        asl @
        tax
        lda fkv+1,x
        pha
        lda fkv,x
        pha
        rts
fks     dta b($1C,'-',$1D,'=',$1E,'+',$1F,'*')
        dta c'TU',b($14,$15),c'D',b($04),c'C',b($03),c'RP',b($10),c'VFLES',b($13)
fkn
fkv     dta a(k_up-1,k_up-1,k_dn-1,k_dn-1,k_pu-1,k_pu-1,k_pd-1,k_pd-1)
        dta a(k_tag-1,k_untag-1,k_tagall-1,k_untall-1,k_del-1,k_delt-1)
        dta a(k_copy-1,k_copyt-1,k_ren-1,k_prn-1,k_prnt-1,k_view-1)
        dta a(k_spec-1,k_log-1,k_na-1,k_na-1,k_na-1)

k_up    lda cur
        beq ku_r
        dec cur
        jmp drawfiles
ku_r    rts
k_dn    ldx cur
        inx
        cpx nf
        bcs ku_r
        stx cur
        jmp drawfiles
k_pu    lda cur
        sec
        sbc perpage
        bcs kp1
        lda #0
kp1     sta cur
        jmp drawfiles
k_pd    lda nf
        beq ku_r
        lda cur
        clc
        adc perpage
        bcs kp2
        cmp nf
        bcc kp3
kp2     ldx nf
        dex
        txa
kp3     sta cur
        jmp drawfiles

k_tag   lda #TAGCH
        bne kt1
k_untag lda #' '
kt1     ldx nf
        beq ku_r
        pha
        lda cur
        jsr eptr
        pla
        ldy #E_TAG
        sta (ze),y
        jmp k_dn2
k_dn2   ldx cur
        inx
        cpx nf
        bcs kt2
        stx cur
kt2     jsr drawstats
        jmp drawfiles

k_tagall lda #TAGCH
        bne ka1
k_untall lda #' '
ka1     sta ka_v
        ldx #0
ka2     cpx nf
        bcs kt2
        txa
        jsr eptr
        lda ka_v
        ldy #E_TAG
        sta (ze),y
        inx
        bne ka2
        beq kt2

* D: the file deleted, after a question
k_del   lda nf
        beq kd_r
        lda cur
        jsr eptr
        jsr fname
        jsr msgclr
        lda #m_del
        jsr askyn
        bne kd_r
        jsr fspec
        jsr REMOVE
        jsr reload
        jmp drawall
kd_r    jmp msgclr

* ^D: the tagged files deleted, with or without a question each
k_delt  jsr ntagged
        beq kd_r
        jsr msgclr
        lda #0                 ; Y: a question for each
        sta fnbuf
        sta kd_ask
        lda #m_delc
        jsr askyn
        bne kd0
        inc kd_ask
kd0     lda #0
        sta kd_i
kd1     lda kd_i
        cmp nf
        bcs kd_end
        jsr eptr
        ldy #E_TAG
        lda (ze),y
        cmp #TAGCH
        bne kd3
        jsr fname
        lda kd_ask
        beq kd2
        jsr msgclr
        lda #m_del
        jsr askyn
        bne kd3
kd2     jsr fspec
        jsr REMOVE
kd3     inc kd_i
        bne kd1
kd_end  jsr reload
        jmp drawall

* C / ^C: copies to a drive and directory asked for
k_copy  lda nf
        jeq kc_r
        lda #1
        sta cp_one
        bne kc0
k_copyt jsr ntagged
        beq kc_r
        lda #0
        sta cp_one
kc0     jsr msgclr
        lda #m_cpto
        jsr askline
        lda inbuf
        cmp #EOL
        beq kc_r2
        ldx #0                 ; the destination, ended as a directory
kc1     lda inbuf,x
        sta dpath,x
        inx
        cmp #EOL
        bne kc1
        dex
        jsr dirend
        lda #0                 ; the same drive: ask about swapping disks
        sta swap
        jsr samedev
        bne kc2
        jsr msgclr
        lda #m_swap
        jsr askyn
        bne kc2
        lda #1
        sta swap
kc2     lda cp_one
        beq kc4
        lda cur
        jsr cp_ent
        jmp kc_end
kc4     lda #0
        sta kd_i
kc5     lda kd_i
        cmp nf
        bcs kc_end
        jsr eptr
        ldy #E_TAG
        lda (ze),y
        cmp #TAGCH
        bne kc6
        lda kd_i
        jsr cp_ent
kc6     inc kd_i
        bne kc5
kc_end  jsr reload
        jmp drawall
kc_r2   jmp msgclr
kc_r    rts

* cp_ent: entry A copied to dpath
cp_ent  jsr eptr
        jsr fname
        jsr msgclr
        jsr lclr
        lda #m_cping
        jsr lstr
        lda fna
        ldy fna+1
        jsr lstrz
        jsr msgout
        jsr fspec              ; the source
        lda #4
        jsr openf
        sta h_in
        lda #8
        sta cp_md
cp1     lda h_in               ; a piece read
        sta file_id
        jsr cbset
        jsr FREAD
        php
        lda bytbuf
        sta cp_n
        lda bytbuf+1
        sta cp_n+1
        plp
        bpl cp2
        lda #1
        sta cp_eof
        bne cp3
cp2     lda #0
        sta cp_eof
cp3     lda swap
        beq cp4
        lda #m_ins_d
        jsr waitkey
cp4     ldx #0                 ; written: the first piece makes the file,
cp5     lda dpath,x            ; the others are added
        sta spec,x
        inx
        cmp #EOL
        bne cp5
        dex
        jsr addname
        lda cp_md
        jsr openf
        sta h_out
        lda cp_n
        ora cp_n+1
        beq cp6
        jsr cbset
        lda cp_n
        sta bytbuf
        lda cp_n+1
        sta bytbuf+1
        jsr FWRITE
cp6     lda h_out
        sta file_id
        lda #0
        sta h_out
        jsr FCLOSE
        lda #9
        sta cp_md
        lda swap
        beq cp7
        lda #m_ins_s
        jsr waitkey
cp7     lda cp_eof
        jeq cp1
        lda h_in
        sta file_id
        lda #0
        sta h_in
        jmp FCLOSE

* R: a new name for the file
k_ren   lda nf
        beq kr_r
        lda cur
        jsr eptr
        jsr fname
        jsr msgclr
        lda #m_ren
        jsr askline
        lda inbuf
        cmp #EOL
        beq kr_r2
        jsr fspec              ; "path\old new"
        ldx #0
kr1     lda spec,x
        cmp #EOL
        beq kr2
        inx
        bne kr1
kr2     lda #' '
        sta spec,x
        inx
        ldy #0
kr3     lda inbuf,y
        sta spec,x
        inx
        iny
        cmp #EOL
        bne kr3
        jsr spfp
        jsr RENAME
        jsr reload
        jmp drawall
kr_r2   jmp msgclr
kr_r    rts

* P / ^P: to the printer (^P: a form feed between files)
k_prn   lda nf
        beq kr_r
        lda cur
        jsr pr_ent
        jmp msgclr
k_prnt  jsr ntagged
        beq kr_r
        lda #0
        sta kd_i
        sta pr_ff
kp_1    lda kd_i
        cmp nf
        bcs kp_e
        jsr eptr
        ldy #E_TAG
        lda (ze),y
        cmp #TAGCH
        bne kp_2
        lda kd_i
        jsr pr_ent
        lda #1
        sta pr_ff
kp_2    inc kd_i
        bne kp_1
kp_e    jmp msgclr

* pr_ent: entry A to P: (a form feed first when pr_ff)
pr_ent  jsr eptr
        jsr fname
        jsr fspec
        lda #4
        jsr openf
        sta h_in
        ldx #2
pe1     lda prn,x
        sta spec,x
        dex
        bpl pe1
        lda #EOL
        sta spec+3
        lda #8
        jsr openf
        sta h_out
        lda pr_ff
        beq pe2
        lda #$0C
        sta inbuf
        jsr ibset
        lda #1
        sta bytbuf
        jsr FWRITE
pe2     lda h_in
        sta file_id
        jsr cbset
        jsr FREAD
        php
        lda h_out
        sta file_id
        lda bytbuf
        ora bytbuf+1
        beq pe3
        lda cbuf
        sta addpos
        lda cbuf+1
        sta addpos+1
        jsr FWRITE
pe3     plp
        bpl pe2
        jmp closeall

* V: the file shown, a screen at a time
k_view  lda nf
        jeq kv_r
        lda cur
        jsr eptr
        jsr fname
        jsr fspec
        lda #4
        jsr openf
        sta h_in
        lda #$7D
        jsr cput
        lda #0
        sta kv_l
kv1     lda h_in
        sta file_id
        jsr cbset
        jsr FREAD
        php
        lda bytbuf
        sta cp_n
        lda bytbuf+1
        sta cp_n+1
        lda cbuf
        sta zm1
        lda cbuf+1
        sta zm1+1
kv2     lda cp_n
        ora cp_n+1
        beq kv5
        ldy #0
        lda (zm1),y
        jsr cput
        cmp #EOL
        bne kv3
        inc kv_l
        lda kv_l
        cmp #22
        bcc kv3
        lda #0
        sta kv_l
        jsr U_GETKEY
        cmp #ESC
        beq kv6
        lda #$7D
        jsr cput
kv3     inc zm1
        bne kv4
        inc zm1+1
kv4     lda cp_n
        bne kv4a
        dec cp_n+1
kv4a    dec cp_n
        jmp kv2
kv5     plp
        bpl kv1
        jsr U_GETKEY
        jmp kv7
kv6     plp
kv7     jsr closeall
        jmp drawall
kv_r    rts

* F: the file specification
k_spec  jsr msgclr
        lda #m_spec
        jsr askline
        lda inbuf
        cmp #EOL
        beq ks_r
        ldx #0
ks1     lda inbuf,x
        sta mask,x
        inx
        cpx #12
        bcs ks2
        cmp #EOL
        bne ks1
ks2     lda #EOL
        sta mask-1,x
        jsr loadf
        jmp drawall
ks_r    jmp msgclr

* L: the drive and directory logged
k_log   jsr msgclr
        lda #m_log
        jsr askline
        lda inbuf
        cmp #EOL
        beq ks_r
        ldx #0
kl1     lda inbuf,x
        sta logp,x
        inx
        cpx #60
        bcs kl2
        cmp #EOL
        bne kl1
kl2     dex
        lda #0
        sta logp,x
        lda #0
        sta dcur
        sta dtop
        jsr logdir
        jsr reload
        jmp drawall

* logdir: logp ended as a directory (':', '>' or backslash)
logdir  ldx #0
ld1     lda logp,x
        beq ld2
        inx
        bne ld1
ld2     txa
        beq ld_r
        lda logp-1,x
        cmp #':'
        beq ld_r
        cmp #'/'
        beq ld_r
        cmp #BSLASH
        beq ld_r
        lda #'/'
        sta logp,x
        lda #0
        sta logp+1,x
ld_r    rts

k_na    jsr msgclr             ; E, S, ^S
        jsr lclr
        lda #m_na
        jsr lstr
        jmp msgout

* ---- directory commands -------------------------------------------------
dircmd  ldx #dkn-dks-1
dc1     cmp dks,x
        beq dc2
        dex
        bpl dc1
        rts
dc2     txa
        asl @
        tax
        lda dkv+1,x
        pha
        lda dkv,x
        pha
        rts
dks     dta b($1C,'-',$1D,'='),c'ADFLMPTU',b($14,$15,$13)
dkn
dkv     dta a(d_up-1,d_up-1,d_dn-1,d_dn-1,d_avail-1,d_del-1,k_spec-1,k_log-1)
        dta a(d_mk-1,k_na-1,k_tagall-1,k_untall-1,k_tagall-1,k_untall-1,k_na-1)

d_up    lda dcur
        beq du_r
        dec dcur
        jmp d_go
d_dn    ldx dcur
        inx
        cpx nd
        bcs du_r
        stx dcur
d_go    jsr setcurp
        jsr loadf
        jmp drawall
du_r    rts

* A: the free space of a drive
d_avail jsr msgclr
        lda #m_drv
        jsr askline
        lda inbuf
        cmp #EOL
        jeq da_r
        ldx #0                 ; a number alone: Dn:
        cmp #'0'
        bcc da1
        cmp #'9'+1
        bcs da1
        lda #'D'
        sta spec
        inx
da1     ldy #0
da2     lda inbuf,y
        cmp #EOL
        beq da3
        sta spec,x
        inx
        iny
        bne da2
da3     lda spec-1,x
        cmp #':'
        beq da4
        lda #':'
        sta spec,x
        inx
da4     lda #EOL
        sta spec,x
        jsr spfp
        jsr GETDFREE
        lda path+4             ; free sectors times the sector size
        sta nv
        lda path+5
        sta nv+1
        lda #0
        sta nv+2
        lda path+1
        cmp #$80
        beq da5
        lda nv+1               ; 256
        sta nv+2
        lda nv
        sta nv+1
        lda #0
        sta nv
        beq da6
da5     lsr nv+1               ; 128
        ror nv
        ror nv+2
        lda nv+2
        pha
        lda nv+1
        sta nv+2
        lda nv
        sta nv+1
        pla
        sta nv
da6     jsr msgclr
        jsr lclr
        lda #8
        jsr lnum
        lda #m_free
        jsr lstr
        jmp msgout
da_r    jmp msgclr

* D: the directory under the selector removed
d_del   lda dcur
        beq da_r
        jsr logspec            ; its name to fnbuf, for the question
        stx dl_x
        jsr dirsp1
        ldy #0
        ldx dl_x
dl1     cpx dl_x+1
        bcs dl2
        lda spec,x
        sta fnbuf,y
        inx
        iny
        bne dl1
dl2     lda #0
        sta fnbuf,y
        jsr msgclr
        lda #m_rd
        jsr askyn
        bne da_r
        jsr dirspec
        jsr spfp
        jsr RMDIR
        lda #0
        sta dcur
        jsr setcurp
        jsr reload
        jmp drawall

* M: a new directory in the one logged
d_mk    jsr msgclr
        lda #m_md
        jsr askline
        lda inbuf
        cmp #EOL
        beq da_r
        jsr logspec
        ldy #0
dm1     lda inbuf,y
        sta spec,x
        inx
        iny
        cmp #EOL
        bne dm1
        jsr spfp
        jsr MKDIR
        lda #0
        sta dcur
        sta dtop
        jsr setcurp
        jsr reload
        jmp drawall

* ---- extra commands -------------------------------------------------------
xtra    cmp #ESC
        beq xt_back
        and #$5F
        cmp #'Q'
        bne xt1
        lda #1
        sta quit
        rts
xt1     cmp #'D'
        bne xt2
        lda disp
        eor #1
        sta disp
        lda #FLINES
        ldx disp
        beq xt1a
        asl @
xt1a    sta perpage
        lda #0
        sta top
        jmp xt_back
xt2     cmp #'S'
        bne xt_r
        jsr msgclr
        jsr lclr
        lda #m_sort
        jsr lstr
        jsr msgout
        jsr U_GETKEY
        and #$5F
        ldx #3
xs1     cmp sortk,x
        beq xs2
        dex
        bpl xs1
        bmi xt_back
xs2     stx sortm
        jsr loadf
xt_back lda pmode
        sta mmode
        jmp drawall
xt_r    rts

* ---- the lists ------------------------------------------------------------

* reload: the directories of logp and the files of curp
reload  jsr loadd
* loadf: the files of curp matching mask, sorted
loadf   lda #0
        sta nf
        sta cur
        sta top
        jsr curspec
        ldy #0
lf1     lda mask,y
        sta spec,x
        inx
        iny
        cmp #EOL
        bne lf1
        jsr spfp
        lda #$80               ; files, not directories
        sta scan
        jsr FFIRST
        bmi lf_r
lf2     lda nf
        cmp #MAXF
        bcs lf3
        ldx #E_TAG-1           ; size, name, date, time; status
lf2a    lda dentry+2,x
        sta ent,x
        dex
        bne lf2a
        lda dentry
        sta ent
        lda #' '
        sta ent+E_TAG
        jsr finsert
lf3     jsr FNEXT
        bpl lf2
        jsr FCLOSE
lf_r    rts

* loadd: the subdirectories of logp
loadd   lda #1
        sta nd
        jsr logspec
        ldy #0
ldd1    lda star,y
        sta spec,x
        inx
        iny
        cpy #4
        bcc ldd1
        jsr spfp
        lda #$08
        sta scan
        jsr FFIRST
        bmi ldd_r
ldd2    lda nd
        cmp #MAXD
        bcs ldd4
        jsr dptr
        ldy #10
ldd3    lda dentry+6,y
        sta (ze),y
        dey
        bpl ldd3
        inc nd
ldd4    jsr FNEXT
        bpl ldd2
        jsr FCLOSE
ldd_r   lda dcur
        cmp nd
        bcc ldd5
        lda #0
        sta dcur
ldd5    rts

* finsert: ent into the file list at its place in the sort order
finsert lda #0
        sta fi_i
fi1     lda fi_i
        cmp nf
        bcs fi_new
        jsr eptr
        ldx sortm
        lda sko,x
        tax
fi2     lda skeys,x            ; the key bytes, most significant first
        bmi fi_nx
        tay
        lda ent,y
        cmp (ze),y
        bcc fi_new
        bne fi_nx
        inx
        bne fi2
fi_nx   inc fi_i
        bne fi1
fi_new  lda nf                 ; entries from fi_i on move up one
        jsr eptr
        lda ze
        sta zm1
        clc
        adc #ESIZE
        sta zm2
        lda ze+1
        sta zm1+1
        adc #0
        sta zm2+1
        lda fi_i
        jsr eptr
        ldy #0
fi3     lda zm1
        cmp ze
        bne fi4
        lda zm1+1
        cmp ze+1
        beq fi5
fi4     lda zm1
        bne fi4a
        dec zm1+1
fi4a    dec zm1
        lda zm2
        bne fi4b
        dec zm2+1
fi4b    dec zm2
        lda (zm1),y
        sta (zm2),y
        jmp fi3
fi5     ldy #ESIZE-1
fi6     lda ent,y
        sta (ze),y
        dey
        bpl fi6
        inc nf
        rts

* eptr: ze at file entry A (keeps X); dptr: ze at directory nd
eptr    sta ep_i
        stx ep_x
        lda #0
        sta ze+1
        lda ep_i               ; * 21 = * 16 + * 4 + 1
        asl @
        rol ze+1
        asl @
        rol ze+1
        sta ze
        lda ze+1
        sta ep_h
        lda ze
        asl @
        rol ze+1
        asl @
        rol ze+1
        clc
        adc ze
        sta ze
        lda ze+1
        adc ep_h
        sta ze+1
        lda ze
        clc
        adc ep_i
        sta ze
        bcc ep1
        inc ze+1
ep1     clc
        lda ze
        adc fbase
        sta ze
        lda ze+1
        adc fbase+1
        sta ze+1
        ldx ep_x
        rts
dptr    lda nd
dptra   sta ep_i
        lda #0
        sta ze+1
        lda ep_i               ; * 11 = * 8 + * 2 + 1
        asl @
        rol ze+1
        sta ze
        lda ze+1
        sta ep_h
        lda ze
        asl @
        rol ze+1
        asl @
        rol ze+1
        clc
        adc ze
        sta ze
        lda ze+1
        adc ep_h
        sta ze+1
        lda ze
        clc
        adc ep_i
        sta ze
        bcc dp_1
        inc ze+1
dp_1    clc
        lda ze
        adc dbase
        sta ze
        lda ze+1
        adc dbase+1
        sta ze+1
        rts

* ntagged: A = the number of tagged files, Z=1 none; tsize their bytes
ntagged lda #0
        sta nt
        sta tsize
        sta tsize+1
        sta tsize+2
        tax
nt1     cpx nf
        bcs nt3
        txa
        jsr eptr
        ldy #E_TAG
        lda (ze),y
        cmp #TAGCH
        bne nt2
        inc nt
        clc
        ldy #E_SIZE
        lda (ze),y
        adc tsize
        sta tsize
        iny
        lda (ze),y
        adc tsize+1
        sta tsize+1
        iny
        lda (ze),y
        adc tsize+2
        sta tsize+2
nt2     inx
        bne nt1
nt3     lda nt
        rts

* ---- specifications ------------------------------------------------------

* logspec / curspec: spec = logp / curp, X at its end
logspec ldx #0
ls1     lda logp,x
        sta spec,x
        beq ls_r
        inx
        bne ls1
ls_r    rts
curspec ldx #0
cs1     lda curp,x
        sta spec,x
        beq ls_r
        inx
        bne cs1

* setcurp: curp = logp, and the directory under the selector
setcurp jsr logspec
        lda dcur
        beq sc2
        jsr dirsp1
        lda #'/'
        sta spec,x
        inx
sc2     ldy #0
sc3     lda spec,y
        sta curp,y
        iny
        dex
        bpl sc3
        lda #0
        sta curp-1,y
        rts

* dirspec: spec = logp and the directory under the selector, EOL ended
dirspec jsr logspec
        jsr dirsp1
        lda #EOL
        sta spec,x
        rts
dirsp1  lda dcur
        jsr dptra
        jsr dirsp2
        stx dl_x+1
        rts
dirsp2
        ldy #0
ds1     lda (ze),y
        cmp #' '
        beq ds2
        sta spec,x
        inx
ds2     iny
        cpy #8
        bcc ds1
        ldy #8
        lda (ze),y
        cmp #' '
        beq ds_r
        lda #'.'
        sta spec,x
        inx
ds3     lda (ze),y
        cmp #' '
        beq ds4
        sta spec,x
        inx
ds4     iny
        cpy #11
        bcc ds3
ds_r    rts

* fname: fnbuf = NAME.EXT of entry ze (0 ended)
fname   ldx #0
        ldy #E_NAME
fn1     lda (ze),y
        cmp #' '
        beq fn2
        sta fnbuf,x
        inx
fn2     iny
        cpy #E_NAME+8
        bcc fn1
        lda (ze),y
        cmp #' '
        beq fn5
        lda #'.'
        sta fnbuf,x
        inx
fn3     lda (ze),y
        cmp #' '
        beq fn4
        sta fnbuf,x
        inx
fn4     iny
        cpy #E_NAME+11
        bcc fn3
fn5     lda #0
        sta fnbuf,x
        rts

* fspec: spec = curp and fnbuf, FILE_P at it
fspec   jsr curspec
* addname: fnbuf added to spec at X, EOL ended, FILE_P at spec
addname ldy #0
an1     lda fnbuf,y
        beq an2
        sta spec,x
        inx
        iny
        bne an1
an2     lda #EOL
        sta spec,x
* spfp: FILE_P at spec
spfp    lda spa
        sta FILE_P
        lda spa+1
        sta FILE_P+1
        rts

* dirend: dpath (EOL at X) ended as a directory
dirend  txa
        beq de_r
        lda dpath-1,x
        cmp #':'
        beq de_r
        cmp #'/'
        beq de_r
        cmp #BSLASH
        beq de_r
        lda #'/'
        sta dpath,x
        lda #EOL
        sta dpath+1,x
de_r    rts

* samedev: Z=1 when dpath names the drive of curp (or neither names one)
samedev ldx #0
sd1     lda dpath,x
        cmp #':'
        beq sd2
        cmp #EOL
        beq sd_none
        inx
        cpx #6
        bcc sd1
sd_none ldx #$FF               ; no device in dpath
sd2     stx sd_d
        ldx #0
sd3     lda curp,x
        cmp #':'
        beq sd4
        cmp #0
        beq sd_cn
        inx
        cpx #6
        bcc sd3
sd_cn   ldx #$FF
sd4     cpx sd_d
        bne sd_r
        cpx #$FF
        beq sd_r
        dex
        bmi sd_y
sd5     lda dpath,x
        cmp curp,x
        bne sd_r
        dex
        bpl sd5
sd_y    lda #0
sd_r    rts

* openf: FILE_P (spec) opened in mode A; A = the handle
openf   sta mode
        jsr spfp
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        rts

* closeall: the files open closed
closeall lda h_in
        beq ca1
        sta file_id
        lda #0
        sta h_in
        jsr FCLOSE
ca1     lda h_out
        beq ca2
        sta file_id
        lda #0
        sta h_out
        jsr FCLOSE
ca2     rts

* cbset: addpos/bytbuf at the copy buffer
cbset   lda cbuf
        sta addpos
        lda cbuf+1
        sta addpos+1
        lda #0
        sta bytbuf
        sta memreix
        lda cbsize+1
        sta bytbuf+1
        rts
ibset   lda ina
        sta addpos
        lda ina+1
        sta addpos+1
        lda #0
        sta bytbuf+1
        sta memreix
        rts

* ---- the screen ------------------------------------------------------------

drawall lda #$7D
        jsr cput
        jsr drawhead
        jsr drawdirs
        jsr drawstats
        jsr drawfiles
drawmenu lda mmode
        asl @
        tax
        lda mn_t,x
        sta zs
        lda mn_t+1,x
        sta zs+1
        lda #22
        ldx #0
        jsr at
        ldy #0
dmn1    lda (zs),y
        beq dmn2
        jsr cput
        iny
        bne dmn1
dmn2    lda #23
        ldx #0
        jsr at
        iny
dmn3    lda (zs),y
        beq dmn4
        jsr cput
        iny
        bne dmn3
dmn4    rts

* drawhead: row 0, the files' directory
drawhead jsr lclr
        lda #m_dir
        jsr lstr
        ldx #0
dh1     lda curp,x
        beq dh2
        stx dh_x
        ldx lx
        sta lb,x
        inc lx
        ldx dh_x
        inx
        cpx #32
        bcc dh1
dh2     lda #0
        ldx #0
        ldy #39
        jmp lout

* drawdirs: rows 2-8: the logged directory and its subdirectories
drawdirs lda dcur              ; the selector kept in the window
        cmp dtop
        bcs dd1
        sta dtop
dd1     sec
        sbc dtop
        cmp #DLINES
        bcc dd2
        lda dcur
        sbc #DLINES-1
        sta dtop
dd2     lda #0
        sta dd_r
dd3     jsr lclr
        lda dtop
        clc
        adc dd_r
        sta dd_i
        cmp nd
        bcs dd6
        cmp #0
        bne dd4
        lda #'.'
        sta lb
        bne dd5
dd4     jsr dptra
        ldy #0
dd4a    lda (ze),y
        sta lb+2,y
        iny
        cpy #8
        bcc dd4a
        ldy #8
        lda (ze),y
        cmp #' '
        beq dd5
        lda #'.'
        sta lb+10
        ldy #8
dd4b    lda (ze),y
        sta lb+3,y
        iny
        cpy #11
        bcc dd4b
dd5     lda mmode
        cmp #1
        bne dd6
        lda dd_i
        cmp dcur
        bne dd6
        ldy #16
        jsr linv
dd6     lda dd_r
        clc
        adc #DROW
        ldx #0
        ldy #16
        jsr lout
        inc dd_r
        lda dd_r
        cmp #DLINES
        bcc dd3
        rts

* drawstats: rows 1-8 right: the file specification and the counts
drawstats jsr lclr
        lda #m_fspec
        jsr lstr
        lda #1
        jsr stout
        jsr lclr
        ldx #0
dst1    lda mask,x
        cmp #EOL
        beq dst2
        sta lb,x
        inx
        cpx #12
        bcc dst1
dst2    lda #2
        jsr stout
        lda #0                 ; all the files
        sta nv
        sta nv+1
        sta nv+2
        ldx #0
dst3    cpx nf
        bcs dst4
        txa
        jsr eptr
        clc
        ldy #E_SIZE
        lda (ze),y
        adc nv
        sta nv
        iny
        lda (ze),y
        adc nv+1
        sta nv+1
        iny
        lda (ze),y
        adc nv+2
        sta nv+2
        inx
        bne dst3
dst4    lda nf
        ldx #m_total
        jsr stnum
        lda #5
        jsr stbyte
        jsr ntagged
        lda tsize
        sta nv
        lda tsize+1
        sta nv+1
        lda tsize+2
        sta nv+2
        lda nt
        ldx #m_tagged
        jsr stnum
        lda #8
* stbyte: "Byte" and nv on row A
stbyte  pha
        jsr lclr
        lda #m_byte
        jsr lstr
        lda #5
        sta lx
        lda #8
        jsr lnum
        pla
* stout: lb on row A, column 24
stout   ldx #24
        ldy #15
        jmp lout

* stnum: message X and the count A on row 4 (total) or 7 (tagged)
stnum   sta sn_v
        stx sn_m
        lda nv
        pha
        lda nv+1
        pha
        lda nv+2
        pha
        jsr lclr
        lda sn_m
        jsr lstr
        lda #6
        sta lx
        lda sn_v
        sta nv
        lda #0
        sta nv+1
        sta nv+2
        lda #7
        jsr lnum
        pla
        sta nv+2
        pla
        sta nv+1
        pla
        sta nv
        lda #4
        ldx sn_m
        cpx #m_total
        beq sn1
        lda #7
sn1     jmp stout

* drawfiles: rows 10-20, the selector kept in the window
drawfiles lda cur
        cmp top
        bcs df1
        sta top
df1     sec
        sbc top
        cmp perpage
        bcc df2
        lda cur
        sbc perpage
        clc
        adc #1
        sta top
df2     lda disp                ; two to a line: top even
        beq df3
        lda top
        and #$FE
        sta top
df3     lda #0
        sta df_r
df4     jsr lclr
        lda disp
        bne df5
        lda top                ; long: one file a line
        clc
        adc df_r
        ldx #0
        jsr fline
        jmp df6
df5     lda df_r               ; short: two files a line
        asl @
        clc
        adc top
        pha
        ldx #0
        jsr fshort
        pla
        clc
        adc #1
        ldx #20
        jsr fshort
df6     lda df_r
        clc
        adc #FROW
        ldx #0
        ldy #39
        jsr lout
        inc df_r
        lda df_r
        cmp #FLINES
        bcc df4
        rts

* fline: file A as a long line at lb+X (inverse under the selector)
fline   sta fl_i
        cmp nf
        jcs fl_r
        jsr eptr
        ldy #E_NAME            ; NAME    .EXT, the tag, the attributes
fl1     lda (ze),y
        sta lb-E_NAME,y
        iny
        cpy #E_NAME+8
        bcc fl1
        lda #'.'
        sta lb+8
fl2     lda (ze),y
        sta lb+1-E_NAME,y
        iny
        cpy #E_NAME+11
        bcc fl2
        ldy #E_TAG
        lda (ze),y
        sta lb+12
        jsr fattr
        ldx #13
        jsr putattr
        ldy #E_SIZE            ; the size
        lda (ze),y
        sta nv
        iny
        lda (ze),y
        sta nv+1
        iny
        lda (ze),y
        sta nv+2
        lda #16
        sta lx
        lda #8
        jsr lnum
        inc lx                 ; dd-mm-yy hh:mm
        ldy #E_DATE
        lda (ze),y
        ldx #' '
        jsr l2dig
        jsr ldash
        ldy #E_DATE+1
        lda (ze),y
        ldx #'0'
        jsr l2dig
        jsr ldash
        ldy #E_DATE+2
        lda (ze),y
        ldx #'0'
        jsr l2dig
        inc lx
        ldy #E_TIME
        lda (ze),y
        ldx #' '
        jsr l2dig
        lda #':'
        jsr lch
        ldy #E_TIME+1
        lda (ze),y
        ldx #'0'
        jsr l2dig
        lda fl_i
        cmp cur
        bne fl_r
        lda mmode
        bne fl_r
        ldy #39
        jsr linv
fl_r    rts

* fshort: file A as NAME    .EXT tag attributes at lb+X
fshort  sta fl_i
        stx fs_x
        cmp nf
        bcs fs_r
        jsr eptr
        ldy #E_NAME
fs1     lda (ze),y
        sta lb,x
        inx
        iny
        cpy #E_NAME+8
        bcc fs1
        lda #'.'
        sta lb,x
        inx
fs2     lda (ze),y
        sta lb,x
        inx
        iny
        cpy #E_NAME+11
        bcc fs2
        ldy #E_TAG
        lda (ze),y
        sta lb,x
        inx
        jsr fattr
        jsr putattr
        lda fl_i
        cmp cur
        bne fs_r
        lda mmode
        bne fs_r
        ldx fs_x               ; inverse: 16 characters
        ldy #16
fs3     lda lb,x
        eor #$80
        sta lb,x
        inx
        dey
        bne fs3
fs_r    rts

* fattr: fa = the status of entry ze; putattr: P H A or '.' at lb+X
fattr   ldy #E_ST
        lda (ze),y
        sta fa
        rts
putattr ldy #0
pa1     lda fa
        and abit,y
        beq pa2
        lda achr,y
        bne pa3
pa2     lda #'.'
pa3     sta lb,x
        inx
        iny
        cpy #3
        bcc pa1
        rts

* ---- line building --------------------------------------------------------

* lclr: lb all spaces, lx = 0
lclr    ldx #39
        lda #' '
lc1     sta lb,x
        dex
        bpl lc1
        lda #0
        sta lx
        rts

* lstr: the message at msgs page offset A added (0 ended)
lstr    asl @
        tax
        lda msgtab,x
        sta zs
        lda msgtab+1,x
        sta zs+1
        ldy #0
* lstrz: the string at zs from Y added (0 ended)
lstrz   lda (zs),y
        beq lz_r
        jsr lch
        iny
        bne lstrz
lz_r    rts

* lch: A added; ldash: '-' added
ldash   lda #'-'
lch     stx lc_x
        ldx lx
        cpx #40
        bcs lch1
        sta lb,x
        inc lx
lch1    ldx lc_x
        rts

* l2dig: A in two digits, X the first one when below 10 (' ' or '0')
l2dig   ldy #0
l2a     cmp #10
        bcc l2b
        sbc #10
        iny
        bne l2a
l2b     pha
        tya
        beq l2c
        ora #'0'
        tax
l2c     txa
        jsr lch
        pla
        ora #'0'
        jmp lch

* lnum: nv (24 bits) right aligned in A characters
lnum    sta ln_w
        ldx #7                 ; 8 digits to dig
ln1     lda #0
        sta dig,x
        dex
        bpl ln1
        ldx #0
ln2     ldy #0                 ; how many times this power of ten
ln3     lda nv
        cmp p10a,x
        lda nv+1
        sbc p10b,x
        lda nv+2
        sbc p10c,x
        bcc ln4
        lda nv
        sbc p10a,x
        sta nv
        lda nv+1
        sbc p10b,x
        sta nv+1
        lda nv+2
        sbc p10c,x
        sta nv+2
        iny
        bne ln3
ln4     tya
        sta dig,x
        inx
        cpx #8
        bcc ln2
        ldx #0                 ; leading zeros as spaces
ln5     lda dig,x
        bne ln6
        lda #' '-'0'
        sta dig,x
        inx
        cpx #7
        bcc ln5
ln6     lda #8
        sec
        sbc ln_w
        tax
ln7     lda dig,x
        clc
        adc #'0'
        jsr lch
        inx
        cpx #8
        bcc ln7
        rts

* linv: the first Y characters of lb in inverse video
linv    dey
lv1     lda lb,y
        eor #$80
        sta lb,y
        dey
        bpl lv1
        rts

* lout: the first Y characters of lb at row A, column X
lout    sty lo_n
        jsr at
        lda #$0B
        sta ICCOM
        lda lba
        sta ICBAL
        lda lba+1
        sta ICBAL+1
        lda lo_n
        sta ICBLL
        lda #0
        sta ICBLL+1
        tax
        jmp CIOV

* at: the cursor to row A, column X
at      sta ROWCRS
        stx COLCRS
        lda #0
        sta COLCRS+1
        rts

* cput: A to the screen; keeps A, X, Y
cput    sta cp_a
        stx cp_x
        sty cp_y
        lda #$0B
        sta ICCOM
        lda #0
        sta ICBLL
        sta ICBLL+1
        tax
        lda cp_a
        jsr CIOV
        ldy cp_y
        ldx cp_x
        lda cp_a
        rts

* ---- the message line ------------------------------------------------------

msgclr  jsr lclr
msgout  lda #MROW
        ldx #0
        ldy #39
        jmp lout

* showmsg: the error shown until a key
showmsg jsr U_GETKEY
        jmp msgclr

* askyn: the message at offset A (with fnbuf after it when it ends in a
* space) and "(Y/N)?"; Z=1 for Y
askyn   pha
        jsr lclr
        pla
        jsr lstr
        lda fna
        sta zs
        lda fna+1
        sta zs+1
        lda #m_yn
        jsr lask
        jsr lstr
        jsr msgout
        jsr U_GETKEY
        and #$5F
        cmp #'Y'
        php
        jsr msgclr
        plp
        rts
lask    pha
        ldy #0
        jsr lstrz
        pla
        rts

* askline: the message at offset A, then a line from the keyboard to inbuf
askline jsr lclr
        jsr lstr
        jsr msgout
        lda #MROW
        ldx lx
        jsr at
        lda #0
        sta CRSINH
        lda #5
        sta ICCOM
        lda ina
        sta ICBAL
        lda ina+1
        sta ICBAL+1
        lda #38
        sta ICBLL
        lda #0
        sta ICBLL+1
        tax
        jsr CIOV
        lda #1
        sta CRSINH
        ldx #0                 ; in capitals
al1     lda inbuf,x
        cmp #EOL
        beq al3
        cmp #'a'
        bcc al2
        cmp #'z'+1
        bcs al2
        and #$DF
        sta inbuf,x
al2     inx
        cpx #38
        bcc al1
        lda #EOL
        sta inbuf,x
al3     jmp msgclr

* waitkey: the message at offset A until a key
waitkey jsr lclr
        jsr lstr
        jsr msgout
        jsr U_GETKEY
        jmp msgclr

* ---- data ------------------------------------------------------------------
trapa   dta a(dc_err)
trap2a  dta a(sr_err)
spa     dta a(spec)
fna     dta a(fnbuf)
ina     dta a(inbuf)
lba     dta a(lb)
cbsz    dta b(4,8,16,32,64)
mn_t    dta a(mn_f,mn_d,mn_x)
mn_f    dta c'File    ',c'^C'*,c'opy ',c'^D'*,c'el ',c'E'*,c'xec ',c'F'*,c'ilespec ',c'L'*,c'og',0
        dta c'Cmds: ',c'^P'*,c'rint ',c'R'*,c'ename ',c'^T'*,c'ag ',c'^U'*,c'ntag ',c'V'*,c'iew ',c'^S'*,0
mn_d    dta c'Dir     ',c'A'*,c'vail ',c'D'*,c'elDir ',c'F'*,c'ilespec ',c'L'*,c'og ',c'^S'*,0
        dta c'Cmds: ',c'M'*,c'akeDir ',c'P'*,c'rint ',c'^T'*,c'agDir ',c'^U'*,c'ntagDir',0
mn_x    dta c'Xtra    ',c'D'*,c'isplay ',c'S'*,c'ort ',c'Q'*,c'uit ',c'^S'*,c'hell cmd',0
        dta c'Cmds:',0
star    dta c'*.*',EOL
prn     dta c'P:',EOL
sortk   dta c'NEDS'
sko     dta b(0,12,24,31)
skeys   dta b(E_NAME,E_NAME+1,E_NAME+2,E_NAME+3,E_NAME+4,E_NAME+5,E_NAME+6)
        dta b(E_NAME+7,E_NAME+8,E_NAME+9,E_NAME+10,$FF)
        dta b(E_NAME+8,E_NAME+9,E_NAME+10,E_NAME,E_NAME+1,E_NAME+2,E_NAME+3)
        dta b(E_NAME+4,E_NAME+5,E_NAME+6,E_NAME+7,$FF)
        dta b(E_DATE+2,E_DATE+1,E_DATE,E_TIME,E_TIME+1,E_TIME+2,$FF)
        dta b(E_SIZE+2,E_SIZE+1,E_SIZE,$FF)
abit    dta b($01,$02,$04)
achr    dta c'PHA'
p10a    dta l(10000000,1000000,100000,10000,1000,100,10,1)
p10b    dta h(10000000,1000000,100000,10000,1000,100,10,1)
p10c    dta b(10000000>>16,1000000>>16,100000>>16,10000>>16,1000>>16,100>>16,10>>16,1>>16)
m_del    equ 0
m_delc   equ 1
m_yn     equ 2
m_cpto   equ 3
m_swap   equ 4
m_cping  equ 5
m_ins_d  equ 6
m_ins_s  equ 7
m_ren    equ 8
m_spec   equ 9
m_log    equ 10
m_na     equ 11
m_drv    equ 12
m_free   equ 13
m_rd     equ 14
m_md     equ 15
m_sort   equ 16
m_dir    equ 17
m_fspec  equ 18
m_total  equ 19
m_tagged equ 20
m_byte   equ 21
s_del    dta c'Delete ',0
s_delc   dta c'Delete tagged: confirm each',0
s_yn     dta c' (Y/N)?',0
s_cpto   dta c'Copy to (drive/path): ',0
s_swap   dta c'Swap disks',0
s_cping  dta c'Copying ',0
s_ins_d  dta c'Insert destination disk, any key',0
s_ins_s  dta c'Insert source disk, any key',0
s_ren    dta c'New name: ',0
s_spec   dta c'Filespec: ',0
s_log    dta c'Log (drive/path): ',0
s_na     dta c'Not available here',0
s_drv    dta c'Drive: ',0
s_free   dta c' bytes free',0
s_rd     dta c'Delete directory ',0
s_md     dta c'New directory: ',0
s_sort   dta c'Sort: Name Ext Date Size ?',0
s_dir    dta c'Dir: ',0
s_fspec  dta c'FileSpec',0
s_total  dta c'Total',0
s_tagged dta c'Tagged',0
s_byte   dta c'Byte',0
msgtab  dta a(s_del,s_delc,s_yn,s_cpto,s_swap,s_cping,s_ins_d,s_ins_s)
        dta a(s_ren,s_spec,s_log,s_na,s_drv,s_free,s_rd,s_md)
        dta a(s_sort,s_dir,s_fspec,s_total,s_tagged,s_byte)
lmsave  dta 0
cisave  dta 0
st_k    dta 0
key     dta 0
quit    dta 0
mmode   dta 0
pmode   dta 0
disp    dta 0
perpage dta FLINES
sortm   dta 0
nf      dta 0
cur     dta 0
top     dta 0
nd      dta 0
dcur    dta 0
dtop    dta 0
nt      dta 0
tsize   :3 dta 0
nv      :3 dta 0
dig     :8 dta 0
ln_w    dta 0
lx      dta 0
lc_x    dta 0
lo_n    dta 0
cp_a    dta 0
cp_x    dta 0
cp_y    dta 0
fl_i    dta 0
fs_x    dta 0
fa      dta 0
df_r    dta 0
dd_r    dta 0
dd_i    dta 0
dh_x    dta 0
sn_v    dta 0
sn_m    dta 0
ka_v    dta 0
kd_i    dta 0
kd_ask  dta 0
kv_l    dta 0
fi_i    dta 0
ep_i    dta 0
ep_x    dta 0
ep_h    dta 0
sd_d    dta 0
dl_x    dta 0,0
cp_one  dta 0
cp_md   dta 0
cp_eof  dta 0
cp_n    dta a(0)
swap    dta 0
pr_ff   dta 0
h_in    dta 0
h_out   dta 0
fbase   dta a(0)
dbase   dta a(0)
cbuf    dta a(0)
cbsize  dta a(0)
ent     :ESIZE dta 0
mask    dta c'*.*',EOL
        :9 dta 0
fnbuf   :14 dta 0
logp    :64 dta 0
curp    :80 dta 0
dpath   :64 dta 0
spec    :100 dta 0
inbuf   :40 dta 0
lb      :40 dta 0

        blk update address
        blk update symbols
