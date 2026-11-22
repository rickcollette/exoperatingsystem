; EOS Toolkit: FSEXPORT, explicitly copy one EOSFS file to the root of a
; pre-existing DOS2/MyDOS-compatible or SDFS 2.x disk.
;   fsexport source Dn:
; The compact writer deliberately supports 128-byte foreign media only. It
; reports the exact 8.3 export name before changing allocation metadata and
; refuses a collision. Foreign filesystems remain unmounted and transient.
U_ARGC  smb 'U_ARGC'
U_ARGV  smb 'U_ARGV'
U_FAIL  smb 'U_FAIL'
PRINTF  smb 'PRINTF'
FOPEN   smb 'FOPEN'
FREAD   smb 'FREAD'
FCLOSE  smb 'FCLOSE'
FILELENG smb 'FILELENG'
FILE_P  smb 'FILE_P'

SIOV    equ $E459
DDEVIC  equ $0300
DUNIT   equ $0301
DCOMND  equ $0302
DSTATS  equ $0303
DBUFLO  equ $0304
DBUFHI  equ $0305
DTIMLO  equ $0306
DBYTLO  equ $0308
DBYTHI  equ $0309
DAUX1   equ $030A
DAUX2   equ $030B
file_id equ $0760
mode    equ $0778
scan    equ $0779
attr    equ $077A
addpos  equ $0782
bytbuf  equ $0785
memreix equ $0787
EOL     equ $9B
ptr     equ $80

        blk reloc main
start   jsr U_ARGC
        cmp #3
        jne usage
        lda #1
        jsr getarg
        jsr export_name
        lda #2
        jsr getdrive
        jcs usage
        jsr geometry
        lda seclen
        cmp #128
        jne density
        lda seclen+1
        jne density
        lda srca
        sta FILE_P
        lda srca+1
        sta FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta infid
        jsr FILELENG
        lda addpos
        sta flen
        lda addpos+1
        sta flen+1
        lda addpos+2
        sta flen+2
        lda #1
        ldx #0
        jsr readbuf
        jmi ioerr
        lda secbuf+32
        cmp #$20
        beq sdfs
        cmp #$21
        beq sdfs
        cmp #$47
        beq native
        cmp #$48
        beq native
        lda #<360
        ldx #>360
        jsr readvtoc
        jmi ioerr
        lda vtoc
        cmp #2
        jcc unknown
        cmp #10
        jcs unknown
        jsr PRINTF
        dta c'Export as %s to DOS2/MyDOS',EOL,0
        dta a(nameout)
        jsr export_dos
        jmp close
sdfs   jsr PRINTF
        dta c'Export as %s to SDFS',EOL,0
        dta a(nameout)
        jsr export_sdfs
close   lda infid
        sta file_id
        jmp FCLOSE

native  jsr PRINTF
        dta c'Refusing EOSFS destination; use cp',EOL,0
        jmp close
unknown jsr PRINTF
        dta c'Unknown foreign filesystem',EOL,0
        jmp close
density jsr PRINTF
        dta c'Only 128-byte foreign media can be exported',EOL,0
        rts
usage   jsr PRINTF
        dta c'Usage: fsexport source Dn:',EOL,0
        rts
ioerr   jmp U_FAIL

* ---- command arguments and 8.3 mapping -----------------------------------
getarg  jsr U_ARGV
        sta ptr
        stx ptr+1
        sty arglen
        ldy #0
ga1     cpy arglen
        beq ga2
        lda (ptr),y
        sta src,y
        iny
        bne ga1
ga2     lda #EOL
        sta src,y
        rts

getdrive jsr U_ARGV
        sta ptr
        stx ptr+1
        sty arglen
        ldy #0
        lda (ptr),y
        cmp #'D'
        beq gd0
        cmp #'d'
        bne gd_bad
gd0     iny
        lda #0
        sta unit
gd1     cpy arglen
        bcs gd_bad
        lda (ptr),y
        cmp #':'
        beq gd_end
        cmp #'0'
        bcc gd_bad
        cmp #'9'+1
        bcs gd_bad
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
        iny
        bne gd1
gd_end  iny
        cpy arglen
        bne gd_bad
        lda unit
        beq gd_bad
        cmp #16
        bcs gd_bad
        clc
        rts
gd_bad  sec
        rts

* Map the final source component to uppercase 8.3 and make printable nameout.
export_name ldx #0
        stx basepos
en_find lda src,x
        cmp #EOL
        beq en_clear
        cmp #'/'
        beq en_base
        cmp #':'
        bne en_next
en_base inx
        stx basepos
        dex
en_next inx
        bne en_find
en_clear ldx #10
        lda #' '
en_c1   sta name83,x
        dex
        bpl en_c1
        lda #0
        sta lossy
        ldy basepos
        ldx #0
en_name lda src,y
        cmp #EOL
        beq en_done
        cmp #'.'
        beq en_ext0
        cpx #8
        bcs en_lossn
        jsr doschar
        sta name83,x
        inx
        iny
        bne en_name
en_lossn dec lossy
        iny
        bne en_name
en_ext0 iny
        ldx #8
en_ext  lda src,y
        cmp #EOL
        beq en_done
        cmp #'.'
        beq en_losse
        cpx #11
        bcs en_losse
        jsr doschar
        sta name83,x
        inx
        iny
        bne en_ext
en_losse dec lossy
        iny
        bne en_ext
en_done ldx #0
        ldy #0
en_o1   lda name83,x
        cmp #' '
        beq en_o2
        sta nameout,y
        iny
en_o2   inx
        cpx #8
        bcc en_o1
        lda name83+8
        cmp #' '
        beq en_oe
        lda #'.'
        sta nameout,y
        iny
en_o3   lda name83,x
        cmp #' '
        beq en_o4
        sta nameout,y
        iny
en_o4   inx
        cpx #11
        bcc en_o3
en_oe   lda #0
        sta nameout,y
        bit lossy
        bpl en_ret
        jsr PRINTF
        dta c'Lossy export name: %p -> %s',EOL,0
        dta a(srca,nameout)
en_ret  rts
doschar cmp #'a'
        bcc ul_ret
        cmp #'z'+1
        bcs dc_test
        dec lossy
        and #$DF
dc_test cmp #'A'
        bcc dc_digit
        cmp #'Z'+1
        bcc ul_ret
dc_digit cmp #'0'
        bcc dc_punct
        cmp #'9'+1
        bcc ul_ret
dc_punct cmp #'_'
        beq ul_ret
        cmp #'-'
        beq ul_ret
        dec lossy
        lda #'_'
ul_ret  rts

* ---- raw physical I/O -----------------------------------------------------
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
        bmi georet
        lda pcom+6
        sta seclen+1
        lda pcom+7
        sta seclen
georet  rts

readbuf sta DAUX1
        stx DAUX2
        lda secbufa
        sta DBUFLO
        lda secbufa+1
        sta DBUFHI
        jmp rawread
readvtoc sta DAUX1
        stx DAUX2
        lda vtoca
        sta DBUFLO
        lda vtoca+1
        sta DBUFHI
rawread lda #'R'
        ldx #$40
        bne rawio
writebuf sta DAUX1
        stx DAUX2
        lda secbufa
        sta DBUFLO
        lda secbufa+1
        sta DBUFHI
        lda #'P'
        ldx #$80
        bne rawio
writevtoc sta DAUX1
        stx DAUX2
        lda vtoca
        sta DBUFLO
        lda vtoca+1
        sta DBUFHI
        lda #'P'
        ldx #$80
rawio   sta DCOMND
        stx DSTATS
        lda #$31
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #128
        sta DBYTLO
        lda #0
        sta DBYTHI
        lda #8
        sta DTIMLO
        jsr SIOV
        tya
        rts

* ---- DOS2/MyDOS 128-byte root export -------------------------------------
export_dos jsr dos_dirslot
        jcs ex_ret
        jsr sector_need_125
        jcs ex_ret
        jsr dos_alloc_all
        jcs ex_ret
        jsr source_rewind
        lda #0
        sta listidx
ed_data lda listidx
        cmp need
        bcs ed_meta
        jsr clearsec
        jsr remaining_125
        jsr source_read
        lda listidx
        clc
        adc #1
        cmp need
        bcs ed_last
        tay
        jsr list_sector
        jmp ed_link
ed_last lda #0
        tax
ed_link sta nextsec
        stx nextsec+1
        lda fileno
        asl @
        asl @
        ora nextsec+1
        sta secbuf+125
        lda nextsec
        sta secbuf+126
        lda chunk
        sta secbuf+127
        ldy listidx
        jsr list_sector
        jsr writebuf
        jmi ioerr
        inc listidx
        jmp ed_data
ed_meta ldy #0
        jsr list_sector
        sta firstsec
        stx firstsec+1
        lda dirsec
        ldx dirsec+1
        jsr readbuf
        jmi ioerr
        ldx diroff
        lda #$42
        sta secbuf,x
        inx
        lda need
        sta secbuf,x
        inx
        lda #0
        sta secbuf,x
        inx
        lda firstsec
        sta secbuf,x
        inx
        lda firstsec+1
        sta secbuf,x
        inx
        ldy #0
ed_name lda name83,y
        sta secbuf,x
        inx
        iny
        cpy #11
        bcc ed_name
        lda dirsec
        ldx dirsec+1
        jsr writebuf
        jmi ioerr
        lda #<360
        ldx #>360
        jsr writevtoc
        jmi ioerr
ex_ret  rts

* Find free root entry, reject an exact mapped-name collision.
dos_dirslot lda #<361
        sta dirsec
        lda #>361
        sta dirsec+1
        lda #0
        sta fileno
dd_sec  lda dirsec
        ldx dirsec+1
        jsr readbuf
        jmi ioerr
        ldx #0
dd_ent  lda secbuf,x
        beq dd_free
        and #$80
        bne dd_free
        txa
        clc
        adc #5
        tay
        lda #0
        sta cmpidx
dd_cmp  lda secbuf,y
        ldx cmpidx
        cmp name83,x
        bne dd_next
        iny
        inc cmpidx
        lda cmpidx
        cmp #11
        bcc dd_cmp
        jsr collision
        sec
        rts
dd_next ldx fileno
        inx
        stx fileno
        txa
        and #7
        asl @
        asl @
        asl @
        asl @
        tax
        bne dd_ent
        inc dirsec
        bne dd_s1
        inc dirsec+1
dd_s1   lda fileno
        cmp #64
        bcc dd_sec
        jsr PRINTF
        dta c'Foreign root directory full',EOL,0
        sec
        rts
dd_free stx diroff
        clc
        rts

sector_need_125 lda flen+2
        jne too_big
        lda flen
        sta tmpword
        lda flen+1
        sta tmpword+1
        lda #0
        sta need
sn_loop lda tmpword
        ora tmpword+1
        beq sn_done
        lda tmpword+1
        bne sn_sub
        lda tmpword
        cmp #126
        bcc sn_final
sn_sub  sec
        lda tmpword
        sbc #125
        sta tmpword
        lda tmpword+1
        sbc #0
        sta tmpword+1
        inc need
        beq too_big
        bne sn_loop
sn_final inc need
        bne sn_ret
        beq too_big
sn_done lda need
        bne sn_ret
        inc need                ; DOS keeps one sector for an empty file
sn_ret  clc
        rts
too_big jsr PRINTF
        dta c'Source too large for compact exporter',EOL,0
        sec
        rts

dos_alloc_all lda #0
        sta listidx
daa1    lda listidx
        cmp need
        bcs daa_ok
        jsr dos_alloc
        bcs daa_ret
        ldy listidx
        tya
        asl @
        tay
        lda allocsec
        sta seclist,y
        lda allocsec+1
        sta seclist+1,y
        inc listidx
        bne daa1
daa_ok  clc
daa_ret rts

dos_alloc lda #4
        sta allocsec
        lda #0
        sta allocsec+1
da_scan lda allocsec+1
        cmp #>720
        bcc da_try
        bne da_full
        lda allocsec
        cmp #<720
        bcs da_full
da_try  jsr vtoc_bit
        and bitval
        bne da_take
        inc allocsec
        bne da_scan
        inc allocsec+1
        bne da_scan
da_take jsr vtoc_bit
        lda (ptr),y
        eor bitval
        sta (ptr),y
        sec
        lda vtoc+3
        sbc #1
        sta vtoc+3
        lda vtoc+4
        sbc #0
        sta vtoc+4
        clc
        rts
da_full jsr PRINTF
        dta c'Foreign disk full',EOL,0
        sec
        rts

* ptr,Y and bitval for allocsec's DOS VTOC bitmap bit.
vtoc_bit lda allocsec
        and #7
        tax
        lda #$80
vb_mask cpx #0
        beq vb_mdone
        lsr @
        dex
        bne vb_mask
vb_mdone sta bitval
        lda allocsec
        sta tmpword
        lda allocsec+1
        sta tmpword+1
        ldx #3
vb_sh   lsr tmpword+1
        ror tmpword
        dex
        bne vb_sh
        clc
        lda vtoca
        adc #10
        adc tmpword
        sta ptr
        lda vtoca+1
        adc tmpword+1
        sta ptr+1
        ldy #0
        lda (ptr),y
        rts

* ---- SDFS 2.x 128-byte root export ---------------------------------------
export_sdfs lda secbuf+15
        cmp #1
        jne sdfs_limit
        lda secbuf+16
        sta bitmapsec
        lda secbuf+17
        sta bitmapsec+1
        lda secbuf+11
        sta total
        lda secbuf+12
        sta total+1
        lda bitmapsec
        ldx bitmapsec+1
        jsr readvtoc
        jmi ioerr
        lda secbuf+9
        sta rootmap
        lda secbuf+10
        sta rootmap+1
        lda rootmap
        ldx rootmap+1
        jsr readbuf
        jmi ioerr
        lda secbuf+4
        sta dirsec
        lda secbuf+5
        sta dirsec+1
        lda dirsec
        ldx dirsec+1
        jsr readbuf
        jmi ioerr
        jsr sdfs_dirslot
        jcs ex_ret
        jsr sector_need_128
        jcs ex_ret
        lda need
        cmp #63
        jcs sdfs_limit
        clc
        adc #1                 ; one sector map
        sta allocneed
        jsr sdfs_alloc_all
        jcs ex_ret
        jsr source_rewind
        lda #0
        sta listidx
es_data lda listidx
        cmp need
        bcs es_map
        jsr clearsec
        jsr remaining_128
        jsr source_read
        ldy listidx
        jsr list_sector
        jsr writebuf
        jmi ioerr
        inc listidx
        bne es_data
es_map  jsr clearsec
        lda #4
        sta mapoff
        lda #0
        sta listidx
es_m1   lda listidx
        cmp need
        bcs es_mdone
        tay
        jsr list_sector
        sta tmpword
        stx tmpword+1
        ldx mapoff
        lda tmpword
        sta secbuf,x
        lda tmpword+1
        sta secbuf+1,x
        inx
        inx
        stx mapoff
        inc listidx
        jmp es_m1
es_mdone ldy need
        jsr list_sector        ; allocated map is last in seclist
        sta filemap
        stx filemap+1
        lda filemap
        ldx filemap+1
        jsr writebuf
        jmi ioerr
        lda dirsec
        ldx dirsec+1
        jsr readbuf
        jmi ioerr
        bit dirgrow
        bpl es_nogrow
        lda newdirlen
        sta secbuf+3
        lda newdirlen+1
        sta secbuf+4
        lda #0
        sta secbuf+5
es_nogrow ldx diroff
        lda #$08
        sta secbuf,x
        inx
        lda filemap
        sta secbuf,x
        inx
        lda filemap+1
        sta secbuf,x
        inx
        lda flen
        sta secbuf,x
        inx
        lda flen+1
        sta secbuf,x
        inx
        lda flen+2
        sta secbuf,x
        inx
        ldy #0
es_name lda name83,y
        sta secbuf,x
        inx
        iny
        cpy #11
        bcc es_name
        lda dirsec
        ldx dirsec+1
        jsr writebuf
        jmi ioerr
        lda bitmapsec
        ldx bitmapsec+1
        jsr writevtoc
        jmi ioerr
        lda #1
        ldx #0
        jsr readbuf
        jmi ioerr
        sec
        lda secbuf+13
        sbc allocneed
        sta secbuf+13
        lda secbuf+14
        sbc #0
        sta secbuf+14
        lda #1
        ldx #0
        jsr writebuf
        jmi ioerr
        rts
sdfs_limit jsr PRINTF
        dta c'SDFS export needs one 128-byte bitmap/map page',EOL,0
        rts

sdfs_dirslot lda #0
        sta dirgrow
        lda secbuf+3
        sta dirlen
        lda secbuf+4
        sta dirlen+1
        lda #23
        sta diroff
sds1    lda diroff
        cmp dirlen
        bcs sds_append
        tax
        lda secbuf,x
        beq sds_free
        and #$10
        bne sds_free
        txa
        clc
        adc #6
        tay
        lda #0
        sta cmpidx
sds_cmp lda secbuf,y
        ldx cmpidx
        cmp name83,x
        bne sds_next
        iny
        inc cmpidx
        lda cmpidx
        cmp #11
        bcc sds_cmp
        jsr collision
        sec
        rts
sds_next clc
        lda diroff
        adc #23
        sta diroff
        bcc sds1
sds_append clc
        lda dirlen
        adc #23
        cmp #129
        bcs sds_full
        sta newdirlen
        lda #0
        adc dirlen+1
        sta newdirlen+1
        lda #$80
        sta dirgrow
sds_free clc
        rts
sds_full jsr PRINTF
        dta c'Foreign root directory page full',EOL,0
        sec
        rts

sector_need_128 lda flen+2
        jne too_big
        lda flen
        sta tmpword
        lda flen+1
        sta tmpword+1
        lda #0
        sta need
sn128_loop lda tmpword
        ora tmpword+1
        beq sn128_done
        lda tmpword+1
        bne sn128_sub
        lda tmpword
        cmp #129
        bcc sn128_final
sn128_sub sec
        lda tmpword
        sbc #128
        sta tmpword
        lda tmpword+1
        sbc #0
        sta tmpword+1
        inc need
        bne sn128_loop
        jmp too_big
sn128_final inc need
sn128_done clc
        rts

sdfs_alloc_all lda #0
        sta listidx
saa1    lda listidx
        cmp allocneed
        bcs saa_ok
        jsr sdfs_alloc
        bcs saa_ret
        ldy listidx
        tya
        asl @
        tay
        lda allocsec
        sta seclist,y
        lda allocsec+1
        sta seclist+1,y
        inc listidx
        bne saa1
saa_ok  clc
saa_ret rts

sdfs_alloc lda #4
        sta allocsec
        lda #0
        sta allocsec+1
sa_scan lda allocsec
        cmp total
        lda allocsec+1
        sbc total+1
        jcs da_full
        jsr sdfs_bit
        and bitval
        bne sa_take
        inc allocsec
        bne sa_scan
        inc allocsec+1
        bne sa_scan
sa_take jsr sdfs_bit
        lda (ptr),y
        eor bitval
        sta (ptr),y
        clc
        rts
sdfs_bit lda allocsec
        and #7
        tax
        lda #$80
sb_mask cpx #0
        beq sb_done
        lsr @
        dex
        bne sb_mask
sb_done sta bitval
        lda allocsec
        sta tmpword
        lda allocsec+1
        sta tmpword+1
        ldx #3
sb_sh   lsr tmpword+1
        ror tmpword
        dex
        bne sb_sh
        clc
        lda vtoca
        adc tmpword
        sta ptr
        lda vtoca+1
        adc tmpword+1
        sta ptr+1
        ldy #0
        lda (ptr),y
        rts

* ---- source and list helpers ---------------------------------------------
source_rewind lda infid
        sta file_id
        lda #0
        sta addpos
        sta addpos+1
        sta addpos+2
        ; reopening is the compact reliable rewind
        jsr FCLOSE
        lda srca
        sta FILE_P
        lda srca+1
        sta FILE_P+1
        lda #4
        sta mode
        jsr FOPEN
        lda file_id
        sta infid
        lda flen
        sta remain
        lda flen+1
        sta remain+1
        rts
remaining_125 lda #125
        bne remaining_common
remaining_128 lda #128
remaining_common sta chunk
        lda remain+1
        bne rem_ret
        lda remain
        cmp chunk
        bcs rem_ret
        sta chunk
rem_ret rts
source_read lda secbufa
        sta addpos
        lda secbufa+1
        sta addpos+1
        lda chunk
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        lda infid
        sta file_id
        jsr FREAD
        sec
        lda remain
        sbc chunk
        sta remain
        lda remain+1
        sbc #0
        sta remain+1
        rts
clearsec ldx #0
        lda #0
cs1     sta secbuf,x
        inx
        cpx #128
        bcc cs1
        rts
* Y is a sector-list index; AX is its sector.
list_sector tya
        asl @
        tay
        lda seclist,y
        ldx seclist+1,y
        rts
collision jsr PRINTF
        dta c'Export collision: %s',EOL,0
        dta a(nameout)
        rts

arglen dta 0
unit dta 0
digit dta 0
tmp dta 0
lossy dta 0
basepos dta 0
infid dta 0
fileno dta 0
diroff dta 0
dirsec dta a(0)
bitmapsec dta a(0)
rootmap dta a(0)
filemap dta a(0)
firstsec dta a(0)
total dta a(0)
flen dta 0,0,0
remain dta a(0)
need dta 0
allocneed dta 0
listidx dta 0
allocsec dta a(0)
nextsec dta a(0)
tmpword dta a(0)
dirlen dta a(0)
newdirlen dta a(0)
bitval dta 0
chunk dta 0
cmpidx dta 0
dirgrow dta 0
mapoff dta 0
seclen dta a(128)
pcom :12 dta 0
name83 :11 dta 0
nameout :13 dta 0
src :128 dta 0
seclist :1440 dta 0
secbuf :128 dta 0
vtoc :128 dta 0
srca dta a(src)
secbufa dta a(secbuf)
vtoca dta a(vtoc)
pcoma dta a(pcom)

        blk update address
        blk update symbols
