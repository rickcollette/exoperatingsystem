; EOS CAR: TAR, a small streaming POSIX USTAR utility
;   tar c archive.tar file ...   create
;   tar t archive.tar            list
;   tar v archive.tar            verbose list
;   tar x archive.tar            extract files/directories
; Creation writes exact EOSFS trees and timestamps. Extraction reads USTAR
; and V7, refuses collisions, and rejects unsafe or malformed input.
U_ARGC   smb 'U_ARGC'
U_ARGV   smb 'U_ARGV'
U_GEFINA smb 'U_GEFINA'
U_PATH   smb 'U_PATH'
TOLOWER  smb 'TOLOWER'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
U_FAIL   smb 'U_FAIL'
MKDIR    smb 'MKDIR'
FILE_P   smb 'FILE_P'

file_id equ $0760
mode    equ $0778
scan    equ $0779
attr    equ $077A
addpos  equ $0782
bytbuf  equ $0785
memreix equ $0787
dentry  equ $0789
date    equ $077B
dateset equ $0781
EOL     equ $9B

zp      equ $80

        blk reloc main
start   jsr U_ARGC
        sta argc
        cmp #3
        jcc usage
        lda #1
        jsr arg
        ldy #0
        lda (zp),y
        jsr TOLOWER
        sta command
        lda #2
        jsr copyarg
        lda command
        cmp #'c'
        beq create
        cmp #'t'
        jeq readarc
        cmp #'v'
        jeq verbose
        cmp #'x'
        jeq readarc
usage   jsr PRINTF
        dta c'Use: tar c archive file ...',EOL
        dta c'     tar t|v|x archive',EOL,0
        rts
verbose lda #1
        sta verb
        jne readarc

; ---- create ---------------------------------------------------------------
create  lda argc
        cmp #4
        bcc usage
        lda a_archive
        ldx a_archive+1
        jsr setfp
        lda #8
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta arid
        lda #3
        sta argno
cr_arg  lda argno
        cmp argc
        jcs cr_end
        jsr copyarg
        lda a_archive
        ldx a_archive+1
        jsr setfp
        jsr U_GEFINA
        lda #0                 ; exact files or directories
        sta scan
        lda #0
        sta attr
        jsr FFIRST
        jmi cr_next
        jsr names
        jsr snapentry
        jsr FCLOSE
        lda #0
        sta depth
        jsr cr_entry
cr_next inc argno
        jne cr_arg
cr_end  jsr clearbuf
        lda arid
        sta file_id
        jsr buf512
        jsr FWRITE
        jsr FWRITE              ; two zero end blocks
        lda arid
        sta file_id
        jmp FCLOSE

; Archive the snapped entry, then walk a directory.  Re-scanning by ordinal
; avoids keeping directory handles or entry lists alive across recursion.
cr_entry
        jsr memberok
        bcs cr_namelong
        jsr mkhead
        lda arid
        sta file_id
        jsr buf512
        jsr FWRITE
        lda entattr
        and #$20
        jne cr_walk
        lda a_full
        ldx a_full+1
        jsr setfp
        lda #4
        sta mode
        jsr FOPEN
        lda file_id
        sta srcid
cr_data jsr clearbuf
        lda srcid
        sta file_id
        jsr buf512
        jsr FREAD
        php
        lda bytbuf
        ora bytbuf+1
        beq cr_eof
        lda arid               ; buffer was cleared, so a short last read
        sta file_id            ; is already padded to a complete tar block
        jsr buf512
        jsr FWRITE
cr_eof  plp
        bpl cr_data
        lda srcid
        sta file_id
        jsr FCLOSE
        rts
cr_namelong
        jsr PRINTF
        dta c'Skipping overlong member: %s',EOL,0
        dta a(member)
        rts

cr_walk lda depth
        cmp #16
        jcs cr_depth
        tax
        ldy #0
cw_fl   lda full,y
        cmp #EOL
        beq cw_fld
        iny
        bne cw_fl
cw_fld  tya
        sta full_len,x
        ldy #0
cw_ml   lda member,y
        cmp #EOL
        beq cw_mld
        iny
        bne cw_ml
cw_mld  tya
        sta member_len,x
        lda #0
        sta walk_index,x
cw_next ldx depth
        ldx #0
cw_spec lda full,x
        cmp #EOL
        beq cw_tail
        sta spec,x
        inx
        bne cw_spec
cw_tail lda #'/'
        sta spec,x
        inx
        lda #'*'
        sta spec,x
        inx
        lda #EOL
        sta spec,x
        lda a_spec
        ldx a_spec+1
        jsr setfp
        lda #0                 ; enumerate files and subdirectories
        sta scan
        lda #0
        sta attr
        jsr FFIRST
        bmi cw_done
        ldx depth
        lda walk_index,x
        sta seekn
cw_seek lda seekn
        beq cw_found
        jsr FNEXT
        bmi cw_close_done
        dec seekn
        jmp cw_seek
cw_found jsr childnames
        bcs cw_skipchild
        jsr snapentry
        jsr FCLOSE
        ldx depth
        inc walk_index,x
        inc depth
        jsr cr_entry
        dec depth
        ldx depth
        ldy full_len,x
        lda #EOL
        sta full,y
        ldy member_len,x
        sta member,y
        jmp cw_next
cw_skipchild
        jsr FCLOSE
        ldx depth
        inc walk_index,x
        jsr PRINTF
        dta c'Skipping overlong path',EOL,0
        jmp cw_next
cw_close_done
        jsr FCLOSE
cw_done rts
cr_depth
        jsr PRINTF
        dta c'Skipping tree deeper than 16: %s',EOL,0
        dta a(member)
        rts

snapentry
        lda dentry
        sta entattr
        ldx #2
se1     lda dentry+3,x
        sta entsize,x
        dex
        bpl se1
        ldx #5
se2     lda dentry+38,x
        sta entdate,x
        dex
        bpl se2
        rts

childnames
        ldx depth
        ldy full_len,x
        tya
        sec
        adc dentry+6
        cmp #160
        bcs cn_bad
        lda member_len,x
        sec
        adc dentry+6
        cmp #128
        bcs cn_bad
        ldy full_len,x
        lda #'/'
        sta full,y
        iny
        stx tmpdepth
        ldx #0
cn1     cpx dentry+6
        bcs cn2
        lda dentry+7,x
        sta full,y
        iny
        inx
        bne cn1
cn2     lda #EOL
        sta full,y
        ldx tmpdepth
        ldy member_len,x
        lda #'/'
        sta member,y
        iny
        ldx #0
cn3     cpx dentry+6
        bcs cn4
        lda dentry+7,x
        sta member,y
        iny
        inx
        bne cn3
cn4     lda #EOL
        sta member,y
        clc
        rts
cn_bad  sec
        rts

memberok
        ldx #0
mo1     lda member,x
        cmp #EOL
        beq mo_end
        inx
        cpx #100
        bcc mo1
        lda member,x
        cmp #EOL
        bne mo_bad
        lda entattr             ; directories need one byte for trailing '/'
        and #$20
        bne mo_bad
mo_end  clc
        rts
mo_bad  sec
        rts

; names: exact entry name to member, and device/path/name to full
names   ldx #0
nm1     cpx dentry+6
        bcs nm2
        lda dentry+7,x
        sta member,x
        inx
        bne nm1
nm2     lda #EOL
        sta member,x
        lda a_full
        ldx a_full+1
        ldy #0
        jsr U_PATH
        ldx #0
nm3     cpx dentry+6
        bcs nm4
        lda dentry+7,x
        sta full,y
        iny
        inx
        bne nm3
nm4     lda #EOL
        sta full,y
        rts

; mkhead: POSIX ustar header in buffer, using dentry's 24-bit length
mkhead  jsr clearbuf
        ldx #0
mh1     lda member,x
        cmp #EOL
        beq mh1e
        sta buffer,x
        inx
        cpx #100
        bcc mh1
mh1e    lda entattr
        and #$20
        beq mh2
        cpx #99
        bcs mh2
        lda #'/'
        sta buffer,x
mh2     ldx #0
mh3     lda mode644,x
        sta buffer+100,x
        inx
        cpx #8
        bcc mh3
        ldx #0
mh4     lda zeros7,x
        sta buffer+108,x
        sta buffer+116,x
        inx
        cpx #8
        bcc mh4
        lda entsize
        sta number
        lda entsize+1
        sta number+1
        lda entsize+2
        sta number+2
        lda #0
        sta number+3
        lda entattr
        and #$20
        beq mh_size
        lda #0
        sta number
        sta number+1
        sta number+2
mh_size
        jsr octsize
        jsr makemtime
        jsr octmtime
        lda #' '
        ldx #7
mh6     sta buffer+148,x
        dex
        bpl mh6
        lda #'0'
        sta buffer+156
        lda entattr
        and #$20
        beq mh_type
        lda #'5'
        sta buffer+156
mh_type
        ldx #0
mh7     lda magic,x
        sta buffer+257,x
        inx
        cpx #8
        bcc mh7
        jsr sumhead
        lda sum
        sta number
        lda sum+1
        sta number+1
        lda sum+2
        sta number+2
        lda #0
        sta number+3
        jsr octsum
        lda #0
        sta buffer+154
        lda #' '
        sta buffer+155
        rts

; fixed-width octal fields
; EOS keeps a two-digit year.  70..99 are 1970..1999 and 00..69 are
; 2000..2069, matching the conventional POSIX epoch window.
makemtime
        lda #0
        sta number
        sta number+1
        sta number+2
        sta number+3
        lda #70
        sta yr
mt_year lda yr
        cmp entdate+2
        beq mt_month0
        lda #$6D               ; 365 days
        ldx #1
        jsr addax
        jsr isleap
        bcc mt_ynext
        lda #1
        jsr addsmall
mt_ynext inc yr
        lda yr
        cmp #100
        bcc mt_year
        lda #0
        sta yr
        beq mt_year
mt_month0
        lda #1
        sta mon
mt_month lda mon
        cmp entdate+1
        beq mt_day
        tax
        dex
        lda mdays,x
        cmp #28
        bne mt_madd
        jsr isleap
        bcc mt_mload
        lda #29
        bne mt_madd
mt_mload lda #28
mt_madd jsr addsmall
        inc mon
        bne mt_month
mt_day  lda entdate
        beq mt_clock
        sec
        sbc #1
        jsr addsmall
mt_clock lda #24
        jsr mulconst
        lda entdate+3
        jsr addsmall
        lda #60
        jsr mulconst
        lda entdate+4
        jsr addsmall
        lda #60
        jsr mulconst
        lda entdate+5
        jmp addsmall

isleap lda yr
        and #3
        bne il_no
        sec
        rts
il_no   clc
        rts
addax   clc
        adc number
        sta number
        txa
        adc number+1
        sta number+1
        bcc as_ret
        inc number+2
        bne as_ret
        inc number+3
as_ret  rts
addsmall
        clc
        adc number
        sta number
        bcc as_ret
        inc number+1
        bne as_ret
        inc number+2
        bne as_ret
        inc number+3
        rts
mulconst
        sta mcount
        ldx #3
mc_cp   lda number,x
        sta work,x
        lda #0
        sta number,x
        dex
        bpl mc_cp
mc_loop lda mcount
        beq mc_ret
        clc
        ldx #0
mc_add  lda number,x
        adc work,x
        sta number,x
        inx
        cpx #4
        bcc mc_add
        dec mcount
        bne mc_loop
mc_ret  rts

octsize ldx #10
ocs1    lda number
        and #7
        ora #'0'
        sta buffer+124,x
        jsr shrnum
        dex
        bpl ocs1
        lda #0
        sta buffer+135
        rts
octsum  ldx #5
ocm1    lda number
        and #7
        ora #'0'
        sta buffer+148,x
        jsr shrnum
        dex
        bpl ocm1
        rts
octmtime ldx #10
omt1    lda number
        and #7
        ora #'0'
        sta buffer+136,x
        jsr shrnum
        dex
        bpl omt1
        lda #0
        sta buffer+147
        rts
shrnum  ldy #3
oc2     lsr number+3
        ror number+2
        ror number+1
        ror number
        dey
        bne oc2
        rts
sumhead lda #0
        sta sum
        sta sum+1
        sta sum+2
        lda a_buffer
        sta zp
        lda a_buffer+1
        sta zp+1
        ldx #2
        ldy #0
sh1     lda (zp),y
        clc
        adc sum
        sta sum
        bcc sh2
        inc sum+1
        bne sh2
        inc sum+2
sh2     iny
        bne sh1
        inc zp+1
        dex
        bne sh1
        rts

; ---- list/extract ---------------------------------------------------------
readarc lda a_archive
        ldx a_archive+1
        jsr setfp
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta arid
rd_head lda arid
        sta file_id
        jsr buf512
        jsr FREAD
        lda bytbuf+1
        cmp #2
        jne badarc
        lda bytbuf
        jne badarc
        jsr iszero
        jcs rd_zero
        jsr validhead
        jcs badarc
        jsr getsize
        jcs badarc
        jsr getmtime
        jcs badarc
        jsr getname
        lda namebad
        jne badarc
        lda command
        cmp #'v'
        bne rd_t
        jsr PRINTF
        dta c'%e %s',EOL,0
        dta a(size,member)
        jmp rd_kind
rd_t    cmp #'t'
        bne rd_kind
        jsr PRINTF
        dta c'%s',EOL,0
        dta a(member)
rd_kind lda buffer+156
        beq rd_reg
        cmp #'0'
        beq rd_reg
        cmp #'5'
        beq rd_dir
        lda #0
        sta extracting
        jmp rd_blocks
rd_zero lda arid
        sta file_id
        jsr buf512
        jsr FREAD
        lda bytbuf+1
        cmp #2
        jne badarc
        lda bytbuf
        jne badarc
        jsr iszero
        jcc badarc
        jmp rd_done
rd_dir  lda command
        cmp #'x'
        bne rd_skip
        jsr safename
        jcs unsafe
        jsr exists
        jcc collision_dir
        lda a_member
        ldx a_member+1
        jsr setfp
        jsr copydate
        jsr MKDIR
        lda #0
        sta extracting
        jmp rd_blocks
rd_reg  lda command
        cmp #'x'
        bne rd_skip
        jsr safename
        jcs unsafe
        jsr exists
        jcc collision_file
        lda a_member
        ldx a_member+1
        jsr setfp
        jsr copydate
        lda #1
        sta dateset
        lda #8
        sta mode
        jsr FOPEN
        lda file_id
        sta outid
        lda #1
        sta extracting
        bne rd_blocks
rd_skip lda #0
        sta extracting
rd_blocks lda size
        ora size+1
        ora size+2
        beq rd_close
        lda arid
        sta file_id
        jsr buf512
        jsr FREAD
        lda bytbuf+1
        cmp #2
        jne badarc
        lda extracting
        beq rb_sub
        lda outid
        sta file_id
        lda size+1
        ora size+2
        bne rb_full
        lda size
        sta bytbuf
        lda #0
        sta bytbuf+1
        beq rb_write
rb_full jsr buf512
rb_write jsr FWRITE
rb_sub  sec
        lda size
        sbc #0
        sta size
        lda size+1
        sbc #2
        sta size+1
        lda size+2
        sbc #0
        sta size+2
        bcs rd_blocks
        lda #0
        sta size
        sta size+1
        sta size+2
rd_close lda extracting
        jeq rd_head
        lda outid
        sta file_id
        jsr FCLOSE
        jmp rd_head
rd_done lda arid
        sta file_id
        jmp FCLOSE
unsafe  jsr PRINTF
        dta c'Skipping unsafe name: %s',EOL,0
        dta a(member)
        lda #0
        sta extracting
        jmp rd_blocks
collision_file
        jsr PRINTF
        dta c'Skipping existing file: %s',EOL,0
        dta a(member)
        lda #0
        sta extracting
        jmp rd_blocks
collision_dir
        jsr PRINTF
        dta c'Using existing directory: %s',EOL,0
        dta a(member)
        lda #0
        sta extracting
        jmp rd_blocks
badarc  jsr PRINTF
        dta c'Invalid tar archive',EOL,0
        lda arid
        sta file_id
        jmp FCLOSE

iszero ldx #0
iz1     lda buffer,x
        jne iz_no
        lda buffer+256,x
        jne iz_no
        inx
        bne iz1
        sec
        rts
iz_no   clc
        rts

validhead lda #0
        sta stored
        sta stored+1
        sta stored+2
        ldx #0
vh1     lda buffer+148,x
        cmp #' '
        beq vh2
        beq vh2
        cmp #0
        beq vh2
        cmp #'0'
        bcc vh_bad
        cmp #'8'
        bcs vh_bad
        sec
        sbc #'0'
        sta digit
        asl stored
        rol stored+1
        rol stored+2
        asl stored
        rol stored+1
        rol stored+2
        asl stored
        rol stored+1
        rol stored+2
        clc
        adc stored
        sta stored
        bcc vh2
        inc stored+1
vh2     inx
        cpx #8
        bcc vh1
        lda #' '
        ldx #7
vh3     sta buffer+148,x
        dex
        bpl vh3
        jsr sumhead
        lda stored
        cmp sum
        bne vh_bad
        lda stored+1
        cmp sum+1
        bne vh_bad
        lda stored+2
        cmp sum+2
        bne vh_bad
        clc
        rts
vh_bad  sec
        rts

getsize lda #0
        sta size
        sta size+1
        sta size+2
        ldx #0
gs1     lda buffer+124,x
        beq gs_done
        cmp #' '
        beq gs_done
        cmp #'0'
        bcc gs_bad
        cmp #'8'
        bcs gs_bad
        sec
        sbc #'0'
        sta digit
        asl size
        rol size+1
        rol size+2
        asl size
        rol size+1
        rol size+2
        asl size
        rol size+1
        rol size+2
        clc
        adc size
        sta size
        bcc gs2
        inc size+1
gs2     inx
        cpx #12
        bcc gs1
gs_done clc
        rts
gs_bad  sec
        rts

getmtime
        lda #0
        ldx #3
gmt0    sta number,x
        dex
        bpl gmt0
        ldx #0
gmt1    lda buffer+136,x
        beq gmt_done
        cmp #' '
        beq gmt_done
        cmp #'0'
        jcc gmt_bad
        cmp #'8'
        jcs gmt_bad
        sec
        sbc #'0'
        sta digit
        ldy #3
gmt_sh  asl number
        rol number+1
        rol number+2
        rol number+3
        dey
        bne gmt_sh
        clc
        lda number
        adc digit
        sta number
        bcc gmt_n
        inc number+1
        bne gmt_n
        inc number+2
        bne gmt_n
        inc number+3
gmt_n   inx
        cpx #12
        bcc gmt1
gmt_done
        jsr div60
        lda divrem
        sta entdate+5
        jsr div60
        lda divrem
        sta entdate+4
        jsr div24
        lda divrem
        cmp #24
        bcs gmt_bad
        sta entdate+3
        lda #70
        sta yr
gmt_y   jsr yeardays
        jsr cmpdays
        bcc gmt_m0
        jsr yeardays
        jsr subdays
        inc yr
        lda yr
        cmp #100
        bcc gmt_y
        lda #0
        sta yr
        beq gmt_y
gmt_m0  lda yr
        sta entdate+2
        lda #1
        sta mon
gmt_m   ldx mon
        dex
        lda mdays,x
        sta daylen
        cmp #28
        bne gmt_mc
        jsr isleap
        bcc gmt_mc
        inc daylen
gmt_mc  lda daylen
        ldx #0
        jsr cmpdays
        bcc gmt_day
        lda daylen
        ldx #0
        jsr subdays
        inc mon
        bne gmt_m
gmt_day lda mon
        sta entdate+1
        lda number
        clc
        adc #1
        sta entdate
        clc
        rts
gmt_bad sec
        rts

; Divide the unsigned 32-bit number by 60, leaving quotient in number and
; remainder in divrem.
div60   lda #60
        bne divu
div24   lda #24
divu    sta divisor
        lda #0
        sta divrem
        ldx #3
dv0     sta divq,x
        dex
        bpl dv0
        ldx #32
dv1     asl number
        rol number+1
        rol number+2
        rol number+3
        rol divrem
        lda divrem
        cmp divisor
        bcc dv_bit0
        sbc divisor
        sta divrem
        sec
        bcs dv_q
dv_bit0 clc
dv_q    rol divq
        rol divq+1
        rol divq+2
        rol divq+3
        dex
        bne dv1
        ldx #3
dv_cp   lda divq,x
        sta number,x
        dex
        bpl dv_cp
        rts

yeardays
        jsr isleap
        lda #$6D
        ldx #1
        bcc yd_ret
        lda #$6E
yd_ret  rts
cmpdays
        sta daytmp
        stx daytmp+1
        lda number+3
        ora number+2
        bne cd_yes
        lda number
        cmp daytmp
        lda number+1
        sbc daytmp+1
        rts
cd_yes  sec
        rts
subdays
        sta daytmp
        stx daytmp+1
        sec
        lda number
        sbc daytmp
        sta number
        lda number+1
        sbc daytmp+1
        sta number+1
        lda number+2
        sbc #0
        sta number+2
        lda number+3
        sbc #0
        sta number+3
        rts

copydate
        ldx #5
cdt1    lda entdate,x
        sta date,x
        dex
        bpl cdt1
        rts

getname lda #0
        sta namebad
        ldx #0                 ; USTAR prefix is unsupported, never ignored
gnp     lda buffer+345,x
        bne gn_prefix
        inx
        cpx #155
        bcc gnp
        ldx #0
gn1     lda buffer,x
        beq gn2
        sta member,x
        inx
        cpx #100
        bcc gn1
        lda #1
        sta namebad
gn2     lda #EOL
        sta member,x
        cpx #0
        beq gn_ret
        lda member-1,x
        cmp #'/'
        bne gn_ret
        lda #EOL
        sta member-1,x
gn_ret
        rts
gn_prefix
        lda #1
        sta namebad
        lda #EOL
        sta member
        rts

; C=0 if the exact extraction target already exists, C=1 if it is new.
exists  lda a_member
        ldx a_member+1
        jsr setfp
        lda #0                 ; collisions include directories
        sta scan
        lda #0
        sta attr
        jsr FFIRST
        bmi ex_new
        jsr FCLOSE
        clc
        rts
ex_new  sec
        rts

; C=1 for absolute/device paths, '..' components, empty or overlong names
safename lda member
        cmp #EOL
        beq sf_bad
        cmp #'/'
        beq sf_bad
        ldx #0
sf1     lda member,x
        cmp #EOL
        beq sf_ok
        cmp #':'
        beq sf_bad
        cmp #'.'
        bne sf_next
        lda member+1,x
        cmp #'.'
        bne sf_next
        cpx #0
        beq sf_tail
        lda member-1,x
        cmp #'/'
        bne sf_next
sf_tail lda member+2,x
        cmp #EOL
        beq sf_bad
        cmp #'/'
        beq sf_bad
sf_next inx
        cpx #127
        bcc sf1
sf_bad  sec
        rts
sf_ok   clc
        rts

; ---- shared ---------------------------------------------------------------
arg     jsr U_ARGV             ; A index -> zp and Y length
        sta zp
        stx zp+1
        rts
copyarg jsr arg
        sty len
        ldx #0
        ldy #0
ca1     cpy len
        beq ca2
        lda (zp),y             ; preserve exact case
        sta archive,y
        iny
        bne ca1
ca2
        lda #EOL
        sta archive,y
        rts

setfp   sta FILE_P
        stx FILE_P+1
        rts
buf512  lda a_buffer
        sta addpos
        lda a_buffer+1
        sta addpos+1
        lda #0
        sta bytbuf
        lda #2
        sta bytbuf+1
        lda #0
        sta memreix
        rts
clearbuf ldx #0
        txa
cb1     sta buffer,x
        sta buffer+256,x
        inx
        bne cb1
        rts

a_archive dta a(archive)
a_member dta a(member)
a_full   dta a(full)
a_spec   dta a(spec)
a_buffer dta a(buffer)
mode644 dta c'0000644',b(0)
zeros7  dta c'0000000',b(0)
magic   dta c'ustar',b(0),c'00'
mdays   dta 31,28,31,30,31,30,31,31,30,31,30,31
argc    dta 0
argno   dta 0
command dta 0
verb    dta 0
len     dta 0
digits  dta 0
digit   dta 0
arid    dta 0
srcid   dta 0
outid   dta 0
dirid   dta 0
dirmode dta 0
extracting dta 0
entattr dta 0
entsize dta 0,0,0
entdate dta 1,1,70,0,0,0
depth   dta 0
tmpdepth dta 0
namebad dta 0
seekn   dta 0
yr      dta 0
mon     dta 0
daylen  dta 0
daytmp  dta a(0)
mcount  dta 0
work    dta 0,0,0,0
divq    dta 0,0,0,0
divrem  dta 0
divisor dta 0
walk_index :16 dta 0
full_len :16 dta 0
member_len :16 dta 0
number  dta 0,0,0,0
size    dta 0,0,0
sum     dta 0,0,0
stored  dta 0,0,0
archive :128 dta 0
member  :128 dta 0
full    :160 dta 0
spec    :164 dta 0
buffer  :512 dta 0

        blk update address
        blk update symbols
