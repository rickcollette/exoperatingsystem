; EOS CAR: ARC, the archiver (the SEA ARC format)
;   ARC command[options] [d:][path]arcname[.ext] [filelist]
; Commands A M U F D X E P L V, options B S W N H G(password).
; Members are read stored (1, 2), packed (3), squeezed (4) or crunched (8);
; files are added stored, packed, squeezed or crunched, whichever comes
; out smallest (S: stored).
FOPEN    smb 'FOPEN'
_DRVNAME smb '_DRVNAME'
_DRVNM   smb '_DRVNM'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
REMOVE   smb 'REMOVE'
RENAME   smb 'RENAME'
PRINTF   smb 'PRINTF'
PUTC     smb 'PUTC'
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
U_GETKEY smb 'U_GETKEY'
MALLOC   smb 'MALLOC'
COMTAB   smb 'COMTAB'
CURDEV   smb 'CURDEV'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
dentry   equ $0789
date     equ $077B               ; date, then time ($077E)
dateset  equ $0781
LMARGN   equ $52
RMARGN   equ $53
SDMCTL   equ $022F
EOL      equ $9B
BSLASH   equ $5C
DLE      equ $90               ; the run marker of packing

* zero page
zabuf    equ $80               ; archive input buffer
zsbuf    equ $82               ; source file buffer
zobuf    equ $84               ; output buffer
zp1      equ $8A
zp2      equ $8C
zp3      equ $8E
zsp      equ $90               ; decoder stack
zs       equ $92               ; string pointers
zd       equ $94
zhn      equ $96               ; the name field of headers written

* the work area: pages from mbase
PG_AB    equ 0                 ; archive input buffer
PG_SB    equ 1                 ; source buffer
PG_OB    equ 2                 ; output buffer
PG_T     equ 3                 ; the tables (64 pages):
* crunching: child low 0, child high 16 (4 bits each), next low 24,
*   next high 40 (4 bits each), last byte 48
* uncrunching: prefix low 0, prefix high 16 (4 bits each), last byte 24,
*   stack 40
* unsqueezing: the nodes from 0
* after the tables: 13 bytes, the name field of the headers written
PG_ALL   equ 67

* the member header after its $1A
H_SIZE   equ 14
H_DATE   equ 18
H_TIME   equ 20
H_CRC    equ 22
H_LEN    equ 24

* list entries (A M U F): name 13, the filelist item (bit 7: added),
* date 2, time 2
L_SPEC   equ 13
L_DATE   equ 14
L_TIME   equ 16
L_SIZE   equ 18

MAXSPEC  equ 16

        blk reloc main
start   jsr U_GETPAR
        jeq usage
        lda COMTAB+$21
        ldx #cmdn-cmdch-1
c1      cmp cmdch,x
        beq c2
        dex
        bpl c1
        sta cu_c               ; not a command
        jsr PRINTF
        dta c'Unknown command %c',EOL,0
        dta a(cu_c)
        lda #156
        jmp U_FAIL
c2      sta cmd
        ldx #1
o1      lda COMTAB+$21,x
        cmp #EOL
        beq o_end
        inx
        cmp #'G'
        beq o_pw
        ldy #optn-optch-1
o2      cmp optch,y
        beq o3
        dey
        bpl o2
        bmi o1                 ; an unknown letter is ignored
o3      sta opt_b,y
        jmp o1
o_pw    ldy #0                 ; G: the rest is the password
o4      lda COMTAB+$21,x
        sta pw,y
        cmp #EOL
        beq o5
        inx
        iny
        cpy #31
        bcc o4
        lda #EOL
        sta pw,y
o5      sty pw_on
o_end   jsr U_GETPAR           ; the archive (none: nothing done)
        bne o_e1
        rts
o_e1
        ldx #0
a1      lda COMTAB+$21,x
        sta arcspec,x
        inx
        cmp #EOL
        bne a1
        jsr arcext
        lda #0                 ; the filelist
        sta nspec
        sta sp_end
f1      jsr U_GETPAR
        beq f_end
        jsr addspec
        jmp f1
f_end   lda nspec
        bne f2
        lda cmd                ; D needs a list
        cmp #'D'
        bne f_e1
        jsr PRINTF
        dta c'You must specify files to delete!',EOL,0
        rts
f_e1
        ldx #2                 ; none: *.*
f3      lda star3,x
        sta COMTAB+$21,x
        dex
        bpl f3
        lda #EOL
        sta COMTAB+$24
        jsr addspec
f2      jsr mkmasks
        lda #<[PG_ALL*256+13]  ; the work area
        sta bytbuf
        lda #>[PG_ALL*256+13]
        sta bytbuf+1
        ldx #$40
        ldy #0
        jsr MALLOC
        bpl m1
        lda #158
        jmp U_FAIL
m1      lda addpos+1
        sta mbase
        jsr setzp
        lda gfail_a            ; errors from here on: tidy up first
        ldx gfail_a+1
        jsr U_SFAIL
        lda opt_h
        beq m2
        lda SDMCTL
        sta dmsave
        lda #0
        sta SDMCTL
m2      lda cmd
        cmp #'L'
        beq d_list
        cmp #'V'
        beq d_list
        cmp #'D'
        beq d_del
        cmp #'X'
        beq d_ext
        cmp #'E'
        beq d_ext
        cmp #'P'
        beq d_ext
        jsr do_add
        jmp done
d_list  jsr do_list
        jmp done
d_del   jsr do_del
        jmp done
d_ext   jsr do_ext
done    jsr U_XFAIL
        jsr scron
        rts

* gfail: an error: files closed, the temporary file removed, then U_FAIL
gfail   sta gf_err
        jsr scron
        lda h_out
        beq gf1
        sta file_id
        lda #0
        sta h_out
        jsr FCLOSE
gf1     lda h_src
        beq gf2
        sta file_id
        lda #0
        sta h_src
        jsr FCLOSE
gf2     lda h_ain
        beq gf3
        sta file_id
        lda #0
        sta h_ain
        jsr FCLOSE
gf3     lda tmp_on
        beq gf4
        lda #0
        sta tmp_on
        jsr sp_tmp
        jsr REMOVE
gf4     lda gf_err
        jmp U_FAIL

* scron: the screen back on after H
scron   lda opt_h
        beq sc1
        lda dmsave
        sta SDMCTL
        lda #0
        sta opt_h
sc1     rts

* usage: no parameters
usage   jsr PRINTF
        dta b(EOL),c'SpartaDOS X ARC v. 1.03',EOL,EOL
        dta c'Usage: ARC cmd[opt] arcfn [flist]',EOL,EOL
        dta c'Where "cmd" is one of:',EOL
        dta c' a  : add file(s) to archive',EOL
        dta c' m  : move file(s) to archive',EOL
        dta c' u  : update file(s) in archive',EOL
        dta c' f  : freshen file(s) in archive',EOL
        dta c' d  : delete file(s) from archive',EOL
        dta c' x,e: extract file(s) from archive',EOL
        dta c' p  : print file(s) to screen',EOL
        dta c' l  : list file(s) in archive',EOL
        dta c' v  : verbose list of file(s)',EOL,EOL,0
        jsr PRINTF
        dta c'Valid "opt" options are:',EOL
        dta c' b  : retain backup copy of archive',EOL
        dta c' s  : suppress compression',EOL
        dta c' w  : suppress warning messages',EOL
        dta c' n  : suppress notes and comments',EOL
        dta c' h  : high speed (screen off)',EOL
        dta c' g  : encrypt/decrypt archive entry',EOL
        dta c'      (followed by password - must be',EOL
        dta c'      last option)',EOL,EOL,0
        jsr PRINTF
        dta c'"arcfn" is archive filename',EOL
        dta c'(drive, path, and ext are optional).',EOL,EOL
        dta c'"flist" is list of files to extract,',EOL
        dta c'add, list, etc. in the archive.',EOL
        dta c'Wildcards are allowed in each',EOL
        dta c'filename. "*.*" is assumed, if no',EOL
        dta c'filename is given.',EOL,0
        rts

* arcext: .ARC added to the archive's name when it has no extension;
* arcname: its name part
arcext  jsr sp_arc
        jsr namepos
        sty an_pos
an1     lda arcspec,y
        cmp #EOL
        beq an2
        cmp #'.'
        beq an3
        iny
        bne an1
an2     ldx #0
an4     lda dotarc,x
        sta arcspec,y
        iny
        inx
        cpx #5
        bcc an4
an3     ldy an_pos
        ldx #0
an5     lda arcspec,y
        sta arcname,x
        iny
        inx
        cmp #EOL
        bne an5
        lda #0
        sta arcname-1,x
        ldx #0                 ; NAME.XAR: the temporary archive
an6     lda arcname,x
        beq an7
        cmp #'.'
        beq an7
        sta tmpname,x
        inx
        bne an6
an7     ldy #0
an8     lda dotxar,y
        sta tmpname,x
        inx
        iny
        cpy #5
        bcc an8
* dname: the archive's name as shown: the drive's name, then the rest
        ldx #0
        ldy #0
dn1     lda arcspec,y          ; a device given?
        cmp #EOL
        beq dn_cur
        cmp #':'
        beq dn_dev
        iny
        cpy #5
        bcc dn1
dn_cur  lda CURDEV             ; no: the current drive
        ldy #0
        beq dn_nm
dn_dev  cpy #1                 ; A: or 1:, D1: or DA:
        beq dn_d1
        cpy #2
        bne dn_cp0
        lda arcspec
        cmp #'D'
        bne dn_cp0
        lda arcspec+1
        jmp dn_d2
dn_d1   lda arcspec
        cmp #'D'               ; D: is D1:
        bne dn_d2
        lda #'1'
dn_d2   cmp #'A'
        bcs dn_d3
        and #$0F               ; a digit
        bpl dn_d4
dn_d3   sbc #'A'-1             ; a letter (C=1)
dn_d4   iny
dn_nm   sty dn_y               ; the drive's name (_DRVNAME: A:, or Dn:
        jsr _DRVNAME           ; when a CIO device has the letter)
        ldx #0
dn_n1   lda _DRVNM,x
        cmp #EOL
        beq dn_n2
        sta dname,x
        inx
        bne dn_n1
dn_n2   ldy dn_y
        jmp dn_cp
dn_cp0  ldy #0                 ; another device: as given
dn_cp   lda arcspec,y
        sta dname,x
        inx
        iny
        cmp #EOL
        bne dn_cp
        rts

* addspec: COMFNAM to the filelist
addspec ldx nspec
        cpx #MAXSPEC
        bcs as_r
        lda sp_end
        sta specofs,x
        tay
        ldx #0
as1     lda COMTAB+$21,x
        sta specs,y
        iny
        beq as_r               ; no room
        inx
        cmp #EOL
        bne as1
        sty sp_end
        inc nspec
as_r    rts

* mkmasks: each filelist item's name part as 11 characters (no name: *.*)
mkmasks lda #0
        sta mk_i
mk0     ldx mk_i
        cpx nspec
        bcs mk_r
        jsr sp_spec
        jsr namepos
        jsr mk11
        lda mk_i
        asl @
        sta mk_t
        asl @
        asl @
        adc mk_t
        adc mk_i               ; 11 * i
        tay
        ldx #0
mk1     lda n11,x
        sta masks,y
        iny
        inx
        cpx #11
        bcc mk1
        inc mk_i
        bne mk0
mk_r    rts

* setzp: the pointers into the work area
setzp   ldx #4
sz1     lda tpg,x
        clc
        adc mbase
        sta e_cl,x
        dex
        bpl sz1
        ldx #0
        ldy #0
sz2     lda #0
        sta zabuf,y
        lda zpg,x
        clc
        adc mbase
        sta zabuf+1,y
        iny
        iny
        inx
        cpx #3
        bcc sz2
        lda #0                 ; the name field after the tables, not cleared:
        sta zhn                ; SDX's ARC keeps the bytes after the name's 0
        lda mbase              ; from the last header it wrote
        clc
        adc #PG_ALL
        sta zhn+1
        rts
zpg     dta b(PG_AB,PG_SB,PG_OB)
tpg     dta b(PG_T,PG_T+16,PG_T+24,PG_T+40,PG_T+48)
* the tables' pages
e_cl    dta 0                  ; crunching: child low
e_ch    dta 0                  ; child high
e_sl    dta 0                  ; next low
e_sh    dta 0                  ; next high
e_sf    dta 0                  ; last byte
d_pl    equ e_cl               ; uncrunching: prefix low
d_ph    equ e_ch               ; prefix high
d_sf    equ e_sl               ; last byte
d_st    equ e_sh               ; stack
tbase   equ e_cl

        icl 'ARCIO.icl'
        icl 'ARCLIST.icl'
        icl 'ARCDEC.icl'
        icl 'ARCENC.icl'
        icl 'ARCADD.icl'

* ---- data --------------------------------------------------------------
cmdch   dta c'AMUFDXEPLV'
cmdn
optch   dta c'BSWNH'
optn
opt_b   dta 0
opt_s   dta 0
opt_w   dta 0
opt_n   dta 0
opt_h   dta 0
cmd     dta 0
pw_on   dta 0
pwi     dta 0
pw      :32 dta 0
dmsave  dta 0
gf_err  dta 0
gfail_a dta a(gfail)
star3   dta c'*.*'
dotarc  dta c'.arc',EOL
dotxar  dta c'.xar',0
cu_c    dta 0
dname   :76 dta 0
dn_y    dta 0
tmpname :14 dta 0
an_pos  dta 0
nspec   dta 0
sp_end  dta 0
mk_i    dta 0
mk_t    dta 0
mbase   dta 0
h_ain   dta 0
h_src   dta 0
h_out   dta 0
tmp_on  dta 0
specofs :MAXSPEC dta 0
masks   :MAXSPEC*11 dta 0
n11     :11 dta 0
arcspec :72 dta 0
arcname :16 dta 0
pathbuf :80 dta 0
specs   :256 dta 0

        blk update address
        blk update symbols
