; EOS Toolkit: FSCREATE, explicit logical creation of a foreign filesystem.
;   fscreate --dos2 Dn:
;   fscreate --sdfs Dn:
; Only the unambiguous 720 x 128-byte profile is accepted.  This is a
; transient utility: no foreign formatter or state is linked into EOS.
U_ARGC  smb 'U_ARGC'
U_ARGV  smb 'U_ARGV'
PRINTF  smb 'PRINTF'
U_FAIL  smb 'U_FAIL'

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
EOL     equ $9B
ptr     equ $80

        blk reloc main
start   jsr U_ARGC
        cmp #3
        jne usage
        lda #1
        jsr option
        jcs usage
        lda #2
        jsr drive
        jcs usage
        jsr geometry
        jcs geometry_bad
        lda kind
        beq make_dos
        jsr PRINTF
        dta c'Creating SDFS on D%d: (old contents are lost)',EOL,0
        dta a(unit)
        jsr sdfs_create
        jmp done
make_dos jsr PRINTF
        dta c'Creating DOS2/MyDOS on D%d: (old contents are lost)',EOL,0
        dta a(unit)
        jsr dos_create
done    jsr PRINTF
        dta c'Filesystem created',EOL,0
        rts
geometry_bad jsr PRINTF
        dta c'Refusing create: drive is not 720 x 128 bytes',EOL,0
        rts
usage   jsr PRINTF
        dta c'Usage: fscreate --dos2|--sdfs Dn:',EOL,0
        rts
ioerr   jmp U_FAIL

option  jsr U_ARGV
        sta ptr
        stx ptr+1
        sty arglen
        cpy #6
        bne op_bad
        ldy #0
        lda (ptr),y
        cmp #'-'
        bne op_bad
        iny
        lda (ptr),y
        cmp #'-'
        bne op_bad
        iny
        lda (ptr),y
        cmp #'d'
        beq op_dos_tail
        cmp #'s'
        bne op_bad
        iny
        lda (ptr),y
        cmp #'d'
        bne op_bad
        iny
        lda (ptr),y
        cmp #'f'
        bne op_bad
        iny
        lda (ptr),y
        cmp #'s'
        bne op_bad
        lda #1
        sta kind
        clc
        rts
op_dos_tail iny
        lda (ptr),y
        cmp #'o'
        bne op_bad
        iny
        lda (ptr),y
        cmp #'s'
        bne op_bad
        iny
        lda (ptr),y
        cmp #'2'
        bne op_bad
op_dos  lda #0
        sta kind
        clc
        rts
op_bad  sec
        rts

drive   jsr U_ARGV
        sta ptr
        stx ptr+1
        sty arglen
        ldy #0
        lda (ptr),y
        cmp #'D'
        beq dr0
        cmp #'d'
        bne dr_bad
dr0     iny
        lda #0
        sta unit
dr1     cpy arglen
        bcs dr_bad
        lda (ptr),y
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
        sta temp
        asl @
        asl @
        clc
        adc temp
        adc digit
        sta unit
        iny
        bne dr1
dr_end  iny
        cpy arglen
        bne dr_bad
        lda unit
        beq dr_bad
        cmp #16
        bcs dr_bad
        clc
        rts
dr_bad  sec
        rts

; Require a successful PERCOM response for exactly 40 tracks, 18 sectors,
; one side and 128-byte sectors.  Creation never relies on a fallback guess.
geometry lda #$31
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #'N'
        sta DCOMND
        lda #$40
        sta DSTATS
        lda pcoma
        sta DBUFLO
        lda pcoma+1
        sta DBUFHI
        lda #12
        sta DBYTLO
        lda #0
        sta DBYTHI
        sta DAUX1
        sta DAUX2
        lda #4
        sta DTIMLO
        jsr SIOV
        tya
        bmi ge_bad
        lda pcom
        cmp #40
        bne ge_bad
        lda pcom+2
        bne ge_bad
        lda pcom+3
        cmp #18
        bne ge_bad
        lda pcom+4
        bne ge_bad
        lda pcom+6
        bne ge_bad
        lda pcom+7
        cmp #128
        bne ge_bad
        clc
        rts
ge_bad  sec
        rts

readbuf sta DAUX1
        stx DAUX2
        lda bufa
        sta DBUFLO
        lda bufa+1
        sta DBUFHI
        lda #'R'
        ldx #$40
        bne rawio
writebuf sta DAUX1
        stx DAUX2
        lda bufa
        sta DBUFLO
        lda bufa+1
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

clear   ldx #0
        lda #0
cl1     sta buf,x
        inx
        bpl cl1
        rts

; DOS 2.0 compatible VTOC and empty eight-sector root directory.
dos_create jsr clear
        lda #2
        sta buf
        lda #<708
        sta buf+1
        sta buf+3
        lda #>708
        sta buf+2
        sta buf+4
        ldx #89
        lda #$ff
dc_bits sta buf+10,x
        dex
        bpl dc_bits
        lda #$0f              ; sectors 0..3 reserved
        sta buf+10
        lda #0                ; sectors 360..367 reserved
        sta buf+10+45
        lda #$7f              ; sector 368 reserved
        sta buf+10+46
        lda #$80              ; sector 720 is the first bit in byte 90
        sta buf+10+90
        lda #<360
        ldx #>360
        jsr writebuf
        jmi ioerr
        jsr clear
        lda #<361
        sta sector
        lda #>361
        sta sector+1
dc_dir  lda sector
        ldx sector+1
        jsr writebuf
        jmi ioerr
        inc sector
        lda sector
        cmp #<369
        bne dc_dir
        lda sector+1
        cmp #>369
        bne dc_dir
        lda #1
        sta sector
dc_boot lda sector
        ldx #0
        jsr writebuf
        jmi ioerr
        inc sector
        lda sector
        cmp #4
        bcc dc_boot
        rts

; SDFS 2.1: boot header 1, bitmap 4, directory data 5, root map 6.
sdfs_create jsr clear
        ldx #0
sc_hdr  lda sdfs_header,x
        sta buf,x
        inx
        cpx #42
        bcc sc_hdr
        lda #1
        ldx #0
        jsr writebuf
        jmi ioerr
        jsr clear
        lda #2
        ldx #0
        jsr writebuf
        jmi ioerr
        lda #3
        ldx #0
        jsr writebuf
        jmi ioerr
        jsr clear
        lda #1
        sta buf
        ldx #1
        lda #$ff
sc_bm   sta buf,x
        inx
        cpx #90
        bcc sc_bm
        lda #$80              ; sector 720
        sta buf+90
        lda #4
        ldx #0
        jsr writebuf
        jmi ioerr
        jsr clear
        ldx #0
sc_dir  lda sdfs_dir,x
        sta buf,x
        inx
        cpx #23
        bcc sc_dir
        lda #5
        ldx #0
        jsr writebuf
        jmi ioerr
        jsr clear
        lda #5
        sta buf+4
        lda #6
        ldx #0
        jsr writebuf
        jmi ioerr
        rts

; Standard SDFS 2.1 720-sector header through boot-map high byte.
sdfs_header dta $00,$03,$00,$30,$e0,$07,$4c,$80,$30
        dta $06,$00,$d0,$02,$ca,$02,$01,$04,$00,$06,$00,$00,$00
        dta c'EOS     '
        dta $28,$80,$21,$80,$00,$3e,$00,$01,$01,$5a,$00,$00
sdfs_dir dta $28,$00,$00,$17,$00,$00,c'main       ',$01,$01,$19,$0c,$00,$00

arglen dta 0
kind dta 0
unit dta a(0)
digit dta 0
temp dta 0
sector dta a(0)
pcom :12 dta 0
buf :128 dta 0
pcoma dta a(pcom)
bufa dta a(buf)

        blk update address
        blk update symbols
