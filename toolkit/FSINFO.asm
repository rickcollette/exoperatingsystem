; EOS Toolkit: FSINFO, identify a disk without mounting its filesystem.
;   fsinfo Dn:
; Reads raw sectors through jblock_io. This transient program is the first
; foreign-media boundary: no DOS2/SDFS parser or state is installed resident.
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
FOPEN    smb 'FOPEN'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
FFIRST   smb 'FFIRST'
MKDIR    smb 'MKDIR'
FILE_P   smb 'FILE_P'
COMTAB   smb 'COMTAB'

SIOV     equ $E459
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUFLO   equ $0304
DBUFHI   equ $0305
DTIMLO   equ $0306
DBYTLO   equ $0308
DBYTHI   equ $0309
DAUX1    equ $030A
DAUX2    equ $030B
EOL      equ $9B
ptr      equ $80
file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787

        blk reloc main
start   jsr U_GETPAR
        jeq usage
        lda #0
        sta checking
        sta importing
        jsr is_check
        bcc try_import
        dec checking
        jsr U_GETPAR
        jeq usage
        jmp have_drive
try_import jsr is_import
        bcc have_drive
        dec importing
        jsr U_GETPAR
        jeq usage
have_drive
        jsr drive
        jcs usage
        bit importing
        bpl no_dest
        jsr U_GETPAR
        jeq usage
        ldx #0
id_cp   lda COMTAB+$21,x
        sta destroot,x
        inx
        cmp #EOL
        bne id_cp
no_dest
        jsr geometry
        jsr U_GETPAR
        jne usage
        lda #1
        ldx #0
        jsr readsec
        jmi ioerr
        lda buf+32
        cmp #$47
        jeq eosfs
        cmp #$48
        jeq eosfs
        cmp #$20
        jeq sdfs
        cmp #$21
        jeq sdfs
        lda #<360
        ldx #>360
        jsr readsec
        jmi ioerr
        lda buf
        sta vtcode
        lda buf+1
        sta vttotal
        lda buf+2
        sta vttotal+1
        lda buf+3
        sta vtfree
        lda buf+4
        sta vtfree+1
        clc
        lda vttotal
        adc #12
        sta maxsec
        lda vttotal+1
        adc #0
        sta maxsec+1
        jsr check_init
        jsr check_dos_system
        jsr check_init
        lda vtcode
        cmp #2
        jcc unknown
        cmp #10
        jcs unknown
        cmp #3
        bcs mydos
        jsr probe_mydos        ; code 2 can also be a small MyDOS volume
        bcc dos2
mydos
        jsr PRINTF
        dta c'MyDOS, VTOC revision %b',EOL,0
        dta a(vtcode)
        jmp dlist
dos2    jsr PRINTF
        dta c'Atari DOS 2: %d sectors, %d free',EOL,0
        dta a(vttotal,vtfree)
dlist   lda #<361
        sta sec
        lda #>361
        sta sec+1
        lda #0
        sta depth
        sta pathlen
        jsr dl_dir
        jsr check_result
        rts

* C=1 when a revision-2 directory contains a MyDOS directory entry or a
* 16-bit-link file.  A flat revision-2 disk with only DOS-compatible files is
* intentionally reported as DOS 2 because the two encodings are identical.
probe_mydos lda #<361
        sta sec
        lda #>361
        sta sec+1
        lda #8
        sta nsec
pm_sec  lda sec
        ldx sec+1
        jsr readsec
        bmi pm_no
        ldx #0
pm_ent  lda buf,x
        beq pm_no
        and #$94               ; deleted, subdirectory, or 16-bit links
        cmp #$10
        beq pm_yes
        cmp #$04
        beq pm_yes
        txa
        clc
        adc #16
        txa
        clc
        adc #16
        tax
        bpl pm_ent
        inc sec
        bne pm_s1
        inc sec+1
pm_s1   dec nsec
        bne pm_sec
pm_no   clc
        rts
pm_yes  sec
        rts

* dl_dir: recursively list an eight-sector DOS2/MyDOS directory at sec.
* Sixteen levels are enough for every native 127-byte import path, and the
* ancestor table makes a malformed directory loop terminate deterministically.
dl_dir  lda depth
        cmp #16
        jcs dl_deep
        bit checking
        bpl dl_unmarked
        lda sec
        sta markcur
        lda sec+1
        sta markcur+1
        lda #8
        sta markcount
dl_mark lda markcur
        ldx markcur+1
        jsr mark_sector
        inc markcur
        bne dl_m1
        inc markcur+1
dl_m1   dec markcount
        bne dl_mark
dl_unmarked
        asl @
        tay
        lda sec
        sta dirbase,y
        lda sec+1
        sta dirbase+1,y
        inc depth
        lda #8
        sta nsec
dl_sec lda sec
        ldx sec+1
        jsr readsec
        jmi ioerr
        ldx #0
dl_ent lda buf,x
        jeq dl_done
        sta status
        lda status
        and #$80
        jne dl_next
        lda status
        and #$10
        bne dl_show
        lda status
        and #$40
        jeq dl_next
dl_show jsr dl_mkname
        ldy #0
dl_pref cpy pathlen
        beq dl_np
        lda path,y
        jsr PUTC
        iny
        bne dl_pref
dl_np   ldy #0
dl_put  lda ename,y
        cmp #EOL
        beq dl_kind
        jsr PUTC
        iny
        bne dl_put
dl_kind lda status
        and #$10
        beq dl_file
        lda #'/'
        jsr PUTC
dl_file lda #EOL
        jsr PUTC
        lda status
        and #$10
        bne dl_recurse
        bit importing
        bpl dl_noimport
        txa
        pha
        jsr import_dos_file
        pla
        tax
dl_noimport
        bit checking
        jpl dl_next
        txa
        pha
        jsr dos_check_file
        pla
        tax
        jmp dl_next
dl_recurse
        bit importing
        bpl dl_recgo
        txa
        pha
        jsr import_directory
        pla
        tax
dl_recgo
        lda buf+3,x            ; remember the child before its read replaces buf
        sta child
        lda buf+4,x
        sta child+1
        lda pathlen
        pha
        txa
        pha
        lda sec
        pha
        lda sec+1
        pha
        lda nsec
        pha
        ldx pathlen
        ldy #0
dl_ap   lda ename,y
        cmp #EOL
        beq dl_slash
        cpx #126
        bcs dl_apdone
        sta path,x
        inx
        iny
        bne dl_ap
dl_slash lda #'/'
        sta path,x
        inx
dl_apdone stx pathlen
        lda child
        sta sec
        lda child+1
        sta sec+1
        jsr dl_ancestor
        bcs dl_loop
        jsr dl_dir
        jmp dl_restore
dl_loop jsr PRINTF
        dta c'  [directory loop]',EOL,0
dl_restore pla
        sta nsec
        pla
        sta sec+1
        pla
        sta sec
        pla
        tax
        pla
        sta pathlen
dl_next txa
        clc
        adc #16
        tax
        jpl dl_ent             ; eight 16-byte entries in the DOS directory page
        inc sec
        bne dl_s1
        inc sec+1
dl_s1   dec nsec
        jne dl_sec
dl_done dec depth
        rts
dl_deep jsr PRINTF
        dta c'  [directory depth exceeds 16]',EOL,0
        rts

* C=1 when child occurs in the active ancestor chain.
dl_ancestor ldy #0
dl_an1  tya
        cmp depth
        bcs dl_anok
        tya
        asl @
        tax
        lda dirbase,x
        cmp child
        bne dl_an2
        lda dirbase+1,x
        cmp child+1
        beq dl_anbad
dl_an2  iny
        bne dl_an1
dl_anok clc
        rts
dl_anbad sec
        rts

* ename = the entry at X as a trimmed DOS 8.3 name.
dl_mkname stx savex
        txa
        clc
        adc #5
        tay
        ldx #0
        lda #8
        sta count
dl_mn1 lda buf,y
        cmp #' '
        beq dl_mn2
        sta ename,x
        inx
dl_mn2 iny
        dec count
        bne dl_mn1
        lda buf,y
        cmp #' '
        beq dl_mn5
        lda #'.'
        sta ename,x
        inx
        lda #3
        sta count
dl_mn3 lda buf,y
        cmp #' '
        beq dl_mn4
        sta ename,x
        inx
dl_mn4 iny
        dec count
        bne dl_mn3
dl_mn5 lda #EOL
        sta ename,x
        ldx savex
        rts

eosfs  jsr PRINTF
        dta c'EOSFS v2',EOL,c'%d bytes/sector, %d total, %d free',EOL,0
        dta a(buf+33,buf+11,buf+13)
        rts
sdfs   jsr PRINTF
        dta c'SDFS revision $%2x',EOL,c'%d sectors, %d free',EOL,0
        dta a(buf+32,buf+11,buf+13)
        lda buf+9
        sta dirmap
        lda buf+10
        sta dirmap+1
        lda buf+33
        sta seclen
        lda buf+34
        sta seclen+1
        lda #0
        sta depth
        sta pathlen
        lda buf+11
        sta maxsec
        lda buf+12
        sta maxsec+1
        lda buf+15
        sta bitmapcount
        lda buf+16
        sta bitmapsec
        lda buf+17
        sta bitmapsec+1
        jsr check_init
        jsr check_sdfs_system
        jsr sd_dir
        jsr check_result
        rts
unknown jsr PRINTF
        dta c'Unknown filesystem',EOL,0
        rts
ioerr   jmp U_FAIL
usage   jsr PRINTF
        dta c'Usage: fsinfo [--check] Dn:',EOL
        dta c'       fsinfo --import Dn: destination',EOL,0
        rts

* C=1 for the exact common long option --check in COMTAB.
is_check ldx #0
ic1     lda COMTAB+$21,x
        cmp checkopt,x
        bne ic_no
        cmp #EOL
        beq ic_yes
        inx
        cpx #8
        bcc ic1
ic_no   clc
        rts
ic_yes  sec
        rts
checkopt dta c'--check',EOL

is_import ldx #0
ii1     lda COMTAB+$21,x
        cmp importopt,x
        bne ii_no
        cmp #EOL
        beq ii_yes
        inx
        cpx #9
        bcc ii1
ii_no   clc
        rts
ii_yes  sec
        rts
importopt dta c'--import',EOL

* ---- bounded structural-check workspace -----------------------------------

check_init bit checking
        bpl ci_ret
        lda #0
        sta checkerrs
        sta ownercount
        sta ownercount+1
ci_ret  rts

check_result bit checking
        bpl cr_ret
        lda checkerrs
        bne cr_bad
        jsr PRINTF
        dta c'Filesystem OK',EOL,0
        rts
cr_bad  jsr PRINTF
        dta c'%b structural error(s)',EOL,0
        dta a(checkerrs)
cr_ret  rts

check_dos_system bit checking
        bpl cds_ret
        lda #1
        ldx #0
        jsr mark_sector
        lda #2
        ldx #0
        jsr mark_sector
        lda #3
        ldx #0
        jsr mark_sector
        lda #<360
        ldx #>360
        jsr mark_sector
cds_ret rts

check_sdfs_system bit checking
        bpl css_ret
        lda #1
        ldx #0
        jsr mark_sector
        lda seclen+1
        cmp #2
        beq css_bm
        lda #2
        ldx #0
        jsr mark_sector
        lda #3
        ldx #0
        jsr mark_sector
css_bm  lda bitmapcount
        beq css_ret
        lda bitmapsec
        ldx bitmapsec+1
        jsr mark_sector
        inc bitmapsec
        bne css_b1
        inc bitmapsec+1
css_b1  dec bitmapcount
        bne css_bm
css_ret rts

* Mark sector AX. C=1 and a diagnostic for zero, out-of-range, or an owner
* bit already set (loop or cross-link).
mark_sector sta marksec
        stx marksec+1
        ora marksec+1
        beq ms_bad
        lda marksec
        cmp maxsec
        lda marksec+1
        sbc maxsec+1
        bcc ms_rangeok
        bne ms_bad
        lda marksec
        cmp maxsec
        beq ms_rangeok
ms_bad  jsr check_sector_error
        sec
        rts
ms_rangeok lda ownera
        sta ptr
        lda ownera+1
        sta ptr+1
        lda ownercount
        sta ownerleft
        lda ownercount+1
        sta ownerleft+1
ms_find lda ownerleft
        ora ownerleft+1
        beq ms_add
        ldy #0
        lda (ptr),y
        cmp marksec
        bne ms_next
        iny
        lda (ptr),y
        cmp marksec+1
        beq ms_bad
ms_next clc
        lda ptr
        adc #2
        sta ptr
        bcc ms_n1
        inc ptr+1
ms_n1   lda ownerleft
        bne ms_n2
        dec ownerleft+1
ms_n2   dec ownerleft
        jmp ms_find
ms_add  lda ownercount+1
        cmp #8                 ; fixed 2048-sector ownership table
        bcs ms_limit
        ldy #0
        lda marksec
        sta (ptr),y
        iny
        lda marksec+1
        sta (ptr),y
        inc ownercount
        bne ms_ok
        inc ownercount+1
ms_ok
        clc
        rts
ms_limit inc checkerrs
        jsr PRINTF
        dta c'Check: ownership limit (2048 sectors)',EOL,0
        sec
        rts

check_sector_error inc checkerrs
        jsr PRINTF
        dta c'Check: sector %d out of range, looped or cross-linked',EOL,0
        dta a(marksec)
        rts

check_chain_error inc checkerrs
        jsr PRINTF
        dta c'Check: invalid chain at sector %d',EOL,0
        dta a(chainsec)
        rts

* DOS2/MyDOS data chain for the directory entry at buf+X.
dos_check_file lda buf+1,x
        sta expected
        lda buf+2,x
        sta expected+1
        lda buf+3,x
        sta chainsec
        lda buf+4,x
        sta chainsec+1
        lda status
        sta chainstatus
        lda #0
        sta actual
        sta actual+1
dcf_loop lda chainsec
        ora chainsec+1
        beq dcf_end
        lda chainsec
        ldx chainsec+1
        jsr mark_sector
        bcs dcf_stop
        lda chainsec
        ldx chainsec+1
        jsr readmap
        bmi dcf_bad
        inc actual
        bne dcf_count
        inc actual+1
dcf_count sec
        lda seclen
        sbc #3
        sta linkoff
        lda seclen+1
        sbc #0
        sta linkoff+1
        jsr map_at
        sta linkhi
        inc linkoff
        bne dcf_l1
        inc linkoff+1
dcf_l1  jsr map_at
        sta chainsec
        lda chainstatus
        and #$04
        bne dcf_long
        lda linkhi
        and #3
        sta chainsec+1
        jmp dcf_loop
dcf_long lda linkhi
        sta chainsec+1
        jmp dcf_loop
dcf_end lda actual
        cmp expected
        bne dcf_bad
        lda actual+1
        cmp expected+1
        bne dcf_bad
        rts
dcf_bad jsr check_chain_error
dcf_stop
        rts

* A = mapbuf[linkoff].
map_at  ldx linkoff
        lda linkoff+1
        beq ma_lo
        lda mapbuf+256,x
        rts
ma_lo   lda mapbuf,x
        rts

* Check and own every map/data sector of the current SDFS directory.
sd_check_chain lda dirmap
        sta chainroot
        lda dirmap+1
        sta chainroot+1
sd_check_chain_root
        lda chainroot
        sta mapcur
        lda chainroot+1
        sta mapcur+1
        lda #0
        sta prevmap
        sta prevmap+1
scc_map lda mapcur
        ora mapcur+1
        jeq scc_done
        lda mapcur
        ldx mapcur+1
        jsr mark_sector
        jcs scc_done
        lda mapcur
        ldx mapcur+1
        jsr readmap
        jmi scc_bad
        lda mapbuf+2
        cmp prevmap
        jne scc_bad
        lda mapbuf+3
        cmp prevmap+1
        jne scc_bad
        lda seclen+1
        beq scc_62
        cmp #1
        beq scc_126
        lda #254
        bne scc_count
scc_126 lda #126
        bne scc_count
scc_62 lda #62
scc_count sta mapents
        lda #0
        sta mapindex
scc_ent lda mapindex
        cmp mapents
        bcs scc_next
        asl @
        clc
        adc #4
        sta linkoff
        lda #0
        rol @
        sta linkoff+1
        jsr map_at
        sta datasec
        inc linkoff
        bne scc_e1
        inc linkoff+1
scc_e1 jsr map_at
        sta datasec+1
        tax
        lda datasec
        ora datasec+1
        beq scc_e2
        lda datasec
        ldx datasec+1
        jsr mark_sector
scc_e2 inc mapindex
        bne scc_ent
scc_next lda mapcur
        sta prevmap
        lda mapcur+1
        sta prevmap+1
        lda mapbuf
        sta mapcur
        lda mapbuf+1
        sta mapcur+1
        jmp scc_map
scc_bad lda mapcur
        sta chainsec
        lda mapcur+1
        sta chainsec+1
        jsr check_chain_error
scc_done rts

* drive: COMTAB parameter D1:..D15: to DUNIT. C=1 on syntax/range error.
drive   lda COMTAB+$21
        cmp #'D'
        beq dr0
        cmp #'d'
        bne dr_bad
dr0     lda #0
        sta unit
        ldx #1
dr1     lda COMTAB+$21,x
        cmp #':'
        beq dr_end
        cmp #'0'
        bcc dr_bad
        cmp #'9'+1
        bcs dr_bad
        sec
        sbc #'0'
        sta digit
        lda unit
        asl @
        sta tmp
        asl @
        asl @
        clc
        adc tmp
        adc digit
        sta unit
        inx
        cpx #4
        bcc dr1
dr_bad sec
        rts
dr_end lda COMTAB+$22,x
        cmp #EOL
        bne dr_bad
        lda unit
        beq dr_bad
        cmp #16
        bcs dr_bad
        sta DUNIT
        clc
        rts

* geometry: physical drive PERCOM.  A drive without N support is treated as
* 128-byte media, which is the safe DOS 2 fallback.  Logical Dn: mapping is
* intentionally bypassed: EOSFS mount refusal must not turn foreign media off
* before this transient inspector can read it.
geometry lda #128
        sta seclen
        lda #0
        sta seclen+1
        lda #$31
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #'N'
        sta DCOMND
        lda #$40
        sta DSTATS
        lda #12
        sta DBYTLO
        lda #0
        sta DBYTHI
        sta DAUX1
        sta DAUX2
        lda pcoma
        sta DBUFLO
        lda pcoma+1
        sta DBUFHI
        lda #4
        sta DTIMLO
        jsr SIOV
        tya
        bmi geo_ret
        lda pcom+6
        ora pcom+7
        beq geo_ret
        lda pcom+6
        sta seclen+1
        lda pcom+7
        sta seclen
geo_ret rts

* ---- SDFS 2.x read-only recursive directory traversal ---------------------

* sd_dir: dirmap is the first sector-map page. Directory records are 23
* bytes; the first is the directory header and supplies the byte length.
sd_dir  lda depth
        cmp #16
        jcs dl_deep
        bit checking
        bpl sd_nocheck
        jsr sd_check_chain
sd_nocheck
        asl @
        tay
        lda dirmap
        sta dirbase,y
        lda dirmap+1
        sta dirbase+1,y
        inc depth
        lda #0
        sta doff
        sta doff+1
        lda #$FF
        sta lastord
        sta lastord+1
        jsr sd_readent
        jcs sd_bad
        lda entry+3
        sta dirlen
        lda entry+4
        sta dirlen+1
sd_next lda doff+1
        cmp dirlen+1
        bcc sd_have
        jne sd_done
        lda doff
        cmp dirlen
        jcs sd_done
sd_have jsr sd_readent
        jcs sd_bad
        lda entry
        jeq sd_done
        and #$18               ; used and not deleted
        cmp #$08
        bne sd_next
        jsr sd_mkname
        ldy #0
sd_pref cpy pathlen
        beq sd_np
        lda path,y
        jsr PUTC
        iny
        bne sd_pref
sd_np   ldy #0
sd_put  lda ename,y
        cmp #EOL
        beq sd_kind
        jsr PUTC
        iny
        bne sd_put
sd_kind lda entry
        and #$20
        beq sd_file
        lda #'/'
        jsr PUTC
sd_file lda #EOL
        jsr PUTC
        lda entry
        and #$60               ; recurse into real directories, not symlinks
        cmp #$20
        beq sd_recurse
        bit importing
        bpl sd_noimport
        jsr import_sdfs_file
sd_noimport
        bit checking
        bpl sd_next
        lda entry+1
        ora entry+2
        beq sd_next
        lda entry+1
        sta chainroot
        lda entry+2
        sta chainroot+1
        jsr sd_check_chain_root
        jmp sd_next
sd_recurse
        bit importing
        bpl sd_recgo
        jsr import_directory
sd_recgo
        lda entry+1
        sta child
        lda entry+2
        sta child+1
        jsr sd_ancestor
        bcs sd_loop
        lda doff
        pha
        lda doff+1
        pha
        lda dirmap
        pha
        lda dirmap+1
        pha
        lda pathlen
        pha
        ldx pathlen
        ldy #0
sd_ap   lda ename,y
        cmp #EOL
        beq sd_slash
        cpx #126
        bcs sd_apdone
        sta path,x
        inx
        iny
        bne sd_ap
sd_slash lda #'/'
        sta path,x
        inx
sd_apdone stx pathlen
        lda child
        sta dirmap
        lda child+1
        sta dirmap+1
        jsr sd_dir
        pla
        sta pathlen
        pla
        sta dirmap+1
        pla
        sta dirmap
        pla
        sta doff+1
        pla
        sta doff
        lda #$FF               ; recursive reads invalidated both caches
        sta lastord
        sta lastord+1
        jmp sd_next
sd_loop jsr PRINTF
        dta c'  [directory loop]',EOL,0
        jmp sd_next
sd_bad  jsr PRINTF
        dta c'  [invalid map %d byte %d, data %d, step %b status %b]',EOL,0
        dta a(dirmap,doff,datasec,failstep,failstatus)
sd_done dec depth
        rts

sd_ancestor ldy #0
sda1    tya
        cmp depth
        bcs sda_ok
        tya
        asl @
        tax
        lda dirbase,x
        cmp child
        bne sda2
        lda dirbase+1,x
        cmp child+1
        beq sda_bad
sda2    iny
        bne sda1
sda_ok  clc
        rts
sda_bad sec
        rts

* Read the 23-byte record at doff and advance doff. C=1 on a broken map.
sd_readent ldx #0
sdr1    stx recidx
        jsr sd_byte
        bcs sdr_bad
        ldx recidx
        sta entry,x
        inc doff
        bne sdr2
        inc doff+1
sdr2    inx
        cpx #23
        bcc sdr1
        clc
sdr_bad rts

* A = byte at doff. Data-sector reads are cached by logical sector number;
* map pages use a separate 512-byte buffer so locating a sector never
* destroys the data being consumed.
sd_byte lda doff
        sta inoff
        lda doff+1
        sta inoff+1
        lda seclen+1
        beq sdb128
        cmp #1
        beq sdb256
* 512-byte sector
        lda inoff+1
        and #1
        sta inoff+1
        lda doff+1
        lsr @
        sta ordinal
        lda #0
        sta ordinal+1
        jmp sdb_ord
sdb256 lda #0
        sta inoff+1
        lda doff+1
        sta ordinal
        lda #0
        sta ordinal+1
        jmp sdb_ord
sdb128 lda inoff
        and #$7F
        sta inoff
        lda doff
        sta ordinal
        lda doff+1
        sta ordinal+1
        ldx #7
sdb_sh lsr ordinal+1
        ror ordinal
        dex
        bne sdb_sh
sdb_ord lda ordinal
        cmp lastord
        bne sdb_load
        lda ordinal+1
        cmp lastord+1
        beq sdb_got
sdb_load jsr sd_lookup
        bcs sdb_ret
        lda ordinal
        sta lastord
        lda ordinal+1
        sta lastord+1
sdb_got ldx inoff
        lda inoff+1
        beq sdb_lo
        lda buf+256,x
        clc
        rts
sdb_lo  lda buf,x
        clc
sdb_ret rts

* Locate ordinal in the SDFS map chain rooted at dirmap, then read its data
* sector to buf. C=1 for a zero/out-of-range/overlong map chain.
sd_lookup lda dirmap
        sta mapcur
        lda dirmap+1
        sta mapcur+1
        lda ordinal
        sta remain
        lda ordinal+1
        sta remain+1
        lda #0
        sta mapcount
sdl_map inc mapcount
        jeq sdl_bad
        lda mapcur
        ldx mapcur+1
        ldy #1
        sty failstep
        jsr readmap
        sta failstatus
        jmi sdl_bad
        lda seclen+1
        beq sdl_62
        cmp #1
        beq sdl_126
        lda #254
        bne sdl_havecnt
sdl_126 lda #126
        bne sdl_havecnt
sdl_62 lda #62
sdl_havecnt sta mapents
        lda remain+1
        bne sdl_sub
        lda remain
        cmp mapents
        bcc sdl_ent
sdl_sub sec
        lda remain
        sbc mapents
        sta remain
        lda remain+1
        sbc #0
        sta remain+1
        lda mapbuf
        sta mapcur
        lda mapbuf+1
        sta mapcur+1
        ora mapcur
        bne sdl_map
        beq sdl_bad
sdl_ent lda remain
        asl @
        clc
        adc #4
        sta mapoff
        lda #0
        rol @
        sta mapoff+1
        ldx mapoff
        lda mapoff+1
        beq sdl_lo
        lda mapbuf+256,x
        sta datasec
        inx
        lda mapbuf+256,x
        jmp sdl_ds2
sdl_lo  lda mapbuf,x
        sta datasec
        inx
        lda mapbuf,x
sdl_ds2
        sta datasec+1
        ora datasec
        beq sdl_zero
        lda datasec
        ldx datasec+1
        ldy #2
        sty failstep
        jsr readsec
        sta failstatus
        bmi sdl_bad
        clc
        rts
sdl_zero ldx #0
        lda #0
sdl_z1  sta buf,x
        sta buf+256,x
        inx
        bne sdl_z1
        clc
        rts
sdl_bad sec
        rts

sd_mkname ldx #0
        ldy #6
sdn1    lda entry,y
        cmp #' '
        beq sdn2
        sta ename,x
        inx
sdn2    iny
        cpy #14
        bcc sdn1
        lda entry+14
        cmp #' '
        beq sdn5
        lda #'.'
        sta ename,x
        inx
        ldy #14
sdn3    lda entry,y
        cmp #' '
        beq sdn4
        sta ename,x
        inx
sdn4    iny
        cpy #17
        bcc sdn3
sdn5    lda #EOL
        sta ename,x
        rts

* ---- explicit import into EOSFS -------------------------------------------

* destbuf = destination root + '/' + current foreign path + ename.
make_dest ldx #0
md_root lda destroot,x
        cmp #EOL
        beq md_sep
        sta destbuf,x
        inx
        bne md_root
md_sep  cpx #0
        beq md_path
        lda destbuf-1,x
        cmp #'/'
        beq md_path
        lda #'/'
        sta destbuf,x
        inx
md_path ldy #0
md_p1   cpy pathlen
        beq md_name
        lda path,y
        sta destbuf,x
        inx
        iny
        bne md_p1
md_name ldy #0
md_n1   lda ename,y
        cmp #EOL
        beq md_end
        sta destbuf,x
        inx
        iny
        bne md_n1
md_end  sta destbuf,x
        lda desta
        sta FILE_P
        lda desta+1
        sta FILE_P+1
        rts

import_directory jsr make_dest
        jsr MKDIR
        rts

import_open jsr make_dest
        lda #0
        sta scan
        sta attr
        jsr FFIRST
        php
        jsr FCLOSE
        plp
        bmi io_new
        jsr PRINTF
        dta c'Import collision: %p',EOL,0
        dta a(FILE_P)
        sec
        rts
io_new  lda #8
        sta mode
        jsr FOPEN
        lda file_id
        sta outfid
        clc
        rts

write_map sta bytbuf
        stx bytbuf+1
        lda mapa
        sta addpos
        lda mapa+1
        sta addpos+1
        jmp import_write
write_buf sta bytbuf
        stx bytbuf+1
        lda bufa
        sta addpos
        lda bufa+1
        sta addpos+1
import_write lda #0
        sta memreix
        lda outfid
        sta file_id
        jsr FWRITE
        rts

import_close lda outfid
        sta file_id
        jsr FCLOSE
        rts

* Import the DOS2/MyDOS file at buf+X.
import_dos_file lda buf+3,x
        sta chainsec
        lda buf+4,x
        sta chainsec+1
        lda status
        sta chainstatus
        jsr import_open
        jcs idf_skip
idf_loop lda chainsec
        ora chainsec+1
        beq import_close
        lda chainsec
        ldx chainsec+1
        jsr readmap
        jmi ioerr
        sec
        lda seclen
        sbc #3
        sta linkoff
        lda seclen+1
        sbc #0
        sta linkoff+1
        clc
        lda linkoff
        adc #2
        sta linkoff
        bcc idf_count
        inc linkoff+1
idf_count jsr map_at
        sta import_count
        lda #0
        sta import_count+1
        lda import_count
        ldx import_count+1
        jsr write_map
        sec
        lda linkoff
        sbc #2
        sta linkoff
        bcs idf_link
        dec linkoff+1
idf_link jsr map_at
        sta linkhi
        inc linkoff
        bne idf_l1
        inc linkoff+1
idf_l1  jsr map_at
        sta chainsec
        lda chainstatus
        and #$04
        bne idf_long
        lda linkhi
        and #3
        sta chainsec+1
        jmp idf_loop
idf_long lda linkhi
        sta chainsec+1
        jmp idf_loop
idf_skip rts

import_sdfs_file lda entry+1
        sta import_map
        lda entry+2
        sta import_map+1
        lda entry+3
        sta import_len
        lda entry+4
        sta import_len+1
        lda entry+5
        sta import_len+2
        jsr import_open
        jcs isf_skip
        lda dirmap
        sta savedmap
        lda dirmap+1
        sta savedmap+1
        lda import_map
        sta dirmap
        lda import_map+1
        sta dirmap+1
        lda #0
        sta ordinal
        sta ordinal+1
        lda #$FF
        sta lastord
        sta lastord+1
isf_loop lda import_len
        ora import_len+1
        ora import_len+2
        beq isf_done
        jsr sd_lookup
        jcs isf_bad
        lda seclen
        sta import_count
        lda seclen+1
        sta import_count+1
        lda import_len+2
        bne isf_write
        lda import_len+1
        cmp import_count+1
        bcc isf_short
        bne isf_write
        lda import_len
        cmp import_count
        bcs isf_write
isf_short lda import_len
        sta import_count
        lda import_len+1
        sta import_count+1
isf_write lda import_count
        ldx import_count+1
        jsr write_buf
        sec
        lda import_len
        sbc import_count
        sta import_len
        lda import_len+1
        sbc import_count+1
        sta import_len+1
        lda import_len+2
        sbc #0
        sta import_len+2
        inc ordinal
        bne isf_loop
        inc ordinal+1
        jmp isf_loop
isf_bad jsr check_chain_error
isf_done jsr import_close
        lda savedmap
        sta dirmap
        lda savedmap+1
        sta dirmap+1
        rts
isf_skip rts

* readsec: AX sector to buf through physical SIO.  Sectors 1-3 are always
* 128 bytes on Atari media; later sectors use the probed physical size.
* Status in A/N.
readsec sta DAUX1
        stx DAUX2
        lda bufa
        sta DBUFLO
        lda bufa+1
        sta DBUFHI
        jmp sio_read
readmap sta DAUX1
        stx DAUX2
        lda mapa
        sta DBUFLO
        lda mapa+1
        sta DBUFHI
sio_read
        lda seclen
        sta DBYTLO
        lda seclen+1
        sta DBYTHI
        lda DAUX2
        bne sr_size
        lda DAUX1
        cmp #4
        bcs sr_size
        lda #128
        sta DBYTLO
        lda #0
        sta DBYTHI
sr_size
        lda #$31
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #'R'
        sta DCOMND
        lda #$40
        sta DSTATS
        lda seclen
        sta DBYTLO
        lda seclen+1
        sta DBYTHI
        lda DAUX2
        bne rs_full
        lda DAUX1
        cmp #4
        bcs rs_full
        lda #128
        sta DBYTLO
        lda #0
        sta DBYTHI
rs_full lda #8
        sta DTIMLO
        jsr SIOV
        tya
        rts

unit    dta 0
digit   dta 0
tmp     dta 0
sec     dta a(0)
nsec    dta 0
status  dta 0
count   dta 0
vtcode  dta 0
vttotal dta a(0)
vtfree  dta a(0)
depth   dta 0
pathlen dta 0
savex   dta 0
child   dta a(0)
dirbase :32 dta 0
path    :127 dta 0
ename   :13 dta 0
pcoma   dta a(pcom)
seclen  dta a(128)
pcom    :12 dta 0
dirmap  dta a(0)
doff    dta a(0)
dirlen  dta a(0)
ordinal dta a(0)
lastord dta a(0)
inoff   dta a(0)
mapoff  dta a(0)
remain  dta a(0)
mapcur  dta a(0)
datasec dta a(0)
mapents dta 0
mapcount dta 0
recidx  dta 0
failstep dta 0
failstatus dta 0
checking dta 0
importing dta 0
checkerrs dta 0
maxsec  dta a(0)
marksec dta a(0)
markcur dta a(0)
markcount dta 0
ownercount dta a(0)
ownerleft dta a(0)
bitmapsec dta a(0)
bitmapcount dta 0
outfid dta 0
import_count dta a(0)
import_map dta a(0)
import_len dta 0,0,0
savedmap dta a(0)
destroot :128 dta 0
destbuf :128 dta 0
chainsec dta a(0)
chainroot dta a(0)
chainstatus dta 0
expected dta a(0)
actual   dta a(0)
linkoff dta a(0)
linkhi dta 0
prevmap dta a(0)
mapindex dta 0
entry   :23 dta 0
mapa    dta a(mapbuf)
bufa    dta a(buf)
ownera  dta a(owners)
desta   dta a(destbuf)
mapbuf  :512 dta 0
buf     :512 dta 0
owners  :4096 dta 0

        blk update address
        blk update symbols
