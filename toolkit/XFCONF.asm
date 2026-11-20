; EOS Toolkit: XFCONF, a floppy drive's density
;   XFCONF [d: [/12345]]
; The drive's PERCOM block (N) tells whether it can be set: no PERCOM
; (NAK) "not configurable", an error status from it "rejected", one
; track "not a floppy". Then a density is sent as a whole PERCOM block
; (O), read back, and the two compared by sectors (tracks * sectors a
; track, twice for two sides), flags and sector size.
; Without a parameter: menus for the drive (1-4) and the density.
; A drive alone: whether it is configurable; /1 to /5: that density.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_SLASH  smb 'U_SLASH'
U_GETKEY smb 'U_GETKEY'
U_FAIL   smb 'U_FAIL'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

device   equ $0761
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUFLO   equ $0304
DTIMLO   equ $0306
DBYTLO   equ $0308
DAUX1    equ $030A
EOL      equ $9B
NAK      equ 139
DERROR   equ 144               ; the drive's error status
ptr      equ $80               ; zero page: a PERCOM block

        blk reloc main
start   jsr U_GETPAR
        beq menu
        jsr U_GEFINA
        lda device             ; D1: to D15:
        cmp #$10
        bcc s1
        lda #156               ; bad parameter
        jmp U_FAIL
s1      sta unit
        jsr check
        lda optp
        ldx optp+1
        ldy #10
        jsr U_SLASH
        ldy #8                 ; /1 to /5: the highest given
s2      lda opts,y
        bne s3
        dey
        dey
        bpl s2
        jsr PRINTF
        dta EOL,c'Drive D%b: is configurable',EOL,0
        dta a(unit)
        rts
s3      tya
        lsr @
        jmp set

* the menus
menu    jsr PRINTF
        dta EOL,c'Floppy drive density selector',EOL
        dta c'-----------------------------',EOL,EOL
        dta c'Select drive number (1-4)',EOL
        dta c'or press <0> to quit: ',0
m1      jsr U_GETKEY
        and #$7F
        cmp #'0'
        jeq quit
        cmp #'1'
        bcc m1
        cmp #'4'+1
        bcs m1
        jsr PUTC
        and #$0F
        sta unit
        lda #EOL
        jsr PUTC
        jsr check
        jsr PRINTF
        dta EOL,EOL,c'Select density:',EOL,EOL
        dta c'<1> 40 tracks SS SD (90k)',EOL
        dta c'<2> 40 tracks SS ED (130k)',EOL
        dta c'<3> 40 tracks SS DD (180k)',EOL
        dta c'<4> 40 tracks DS DD (360k)',EOL
        dta c'<5> 80 tracks DS DD (720k)',EOL,EOL
        dta c'or press <0> to quit',EOL,0
m2      jsr U_GETKEY
        and #$7F
        cmp #'0'
        beq quit
        cmp #'1'
        bcc m2
        cmp #'5'+1
        bcs m2
        jsr PUTC
        and #$0F
        sec
        sbc #1

* set: density A (0-4): its block out, read back, compared
set     asl @
        asl @
        asl @
        asl @
        clc
        adc tmplp
        sta ptr
        lda tmplp+1
        adc #0
        sta ptr+1
        lda ptr
        ldx ptr+1
        jsr dbuf
        lda #'O'
        ldx #$80
        jsr sio
        jsr rperc
        ldx #0                 ; what was sent, what the drive has
        jsr summary
        lda pcp
        sta ptr
        lda pcp+1
        sta ptr+1
        ldx #4
        jsr summary
        ldx #3
st1     lda sum,x
        cmp sum+4,x
        bne st2
        dex
        bpl st1
        jsr PRINTF
        dta EOL,c'Drive configured OK',0
quit    lda #EOL
        jmp PUTC
st2     jsr PRINTF
        dta EOL,c'Drive cannot do this density',0
        jmp quit

* check: the drive's PERCOM block; one it cannot be set by ends the
* program here
check   jsr rperc
        bmi ck2
        lda pc                 ; one track: a hard disk or a RAM disk
        cmp #1
        bne ck1
        jsr PRINTF
        dta EOL,c'Drive D%b: is not a floppy!',EOL,0
        dta a(unit)
        pla
        pla
ck1     rts
ck2     cmp #NAK
        beq ck3
        cmp #DERROR
        beq ck4
        jmp U_FAIL
ck3     jsr PRINTF
        dta EOL,c'Drive not configurable',0
        jmp ck5
ck4     jsr PRINTF
        dta EOL,c'Drive rejected the config',0
ck5     pla
        pla
        jmp quit

* summary: the PERCOM block at ptr to sum+X: sectors (word), flags, the
* sector size's high byte
summary ldy #5
        lda (ptr),y
        sta sum+2,x
        iny
        lda (ptr),y
        sta sum+3,x
        lda #0
        sta sum,x
        sta sum+1,x
        ldy #0                 ; tracks * sectors a track
        lda (ptr),y
        beq su2
        sta n
su1     ldy #3
        lda (ptr),y
        clc
        adc sum,x
        sta sum,x
        dey
        lda (ptr),y
        adc sum+1,x
        sta sum+1,x
        dec n
        bne su1
su2     ldy #4                 ; two sides
        lda (ptr),y
        beq su3
        asl sum,x
        rol sum+1,x
su3     rts

* rperc: the PERCOM block to pc; sio: command A, DSTATS X; A the status,
* N=1 an error
rperc   lda pcp
        ldx pcp+1
        jsr dbuf
        lda #'N'
        ldx #$40
sio     sta DCOMND
        stx DSTATS
        lda #$31
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #7
        sta DTIMLO
        lda #0
        sta DTIMLO+1
        sta DAUX1
        sta DAUX1+1
        jmp COMTAB-11          ; (SIO to main memory)
dbuf    sta DBUFLO
        stx DBUFLO+1
        lda #12
        sta DBYTLO
        lda #0
        sta DBYTLO+1
        rts

* the densities' PERCOM blocks: tracks, step, sectors a track (high,
* low), sides-1, flags (4: MFM), bytes a sector (high, low), control
tmplp   dta a(tmpl)
tmpl    dta 40,1,0,18,0,0,0,128,$FF,0,0,0,0,0,0,0
        dta 40,1,0,26,0,4,0,128,$FF,0,0,0,0,0,0,0
        dta 40,1,0,18,0,4,1,0,$FF,0,0,0,0,0,0,0
        dta 40,1,0,18,1,4,1,0,$FF,0,0,0,0,0,0,0
        dta 80,1,0,18,1,4,1,0,$FF,0,0,0,0,0,0,0
optp    dta a(opts)
opts    dta 0,c'1',0,c'2',0,c'3',0,c'4',0,c'5'
pcp     dta a(pc)
unit    dta 0
n       dta 0
sum     dta 0,0,0,0,0,0,0,0
pc      :12 dta 0

        blk update address
        blk update symbols
