; EOS Toolkit: SHUFFLE, a directory's entries put in random order
;   SHUFFLE [d:][path]
; The reverse of SORTDIR: the directory is read into memory (direct
; directory access), its entries are shuffled and it is written back.
; Not on DOS 2 disks (their own DOS would no longer find the files). A
; file name given, or nothing: the usage line.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
GETDFREE smb 'GETDFREE'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FSEEK    smb 'FSEEK'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'

name     equ $0762             ; (U_GEFINA: the name, 8+3)
ext      equ $076A
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
path     equ $07A0             ; (GETDFREE: the file system type first)
MEMTOP   equ $02E5
MEMLO    equ $02E7
RANDOM   equ $D20A
EOL      equ $9B

pa       equ $80               ; the entry being placed
pb       equ $82               ; the one it changes places with
pe       equ $84               ; the end of the entries

        blk reloc main
start   jsr U_GETPAR
        jeq usage
        jsr GETDFREE
        lda path               ; DOS 2 ($0x): no
        and #$F0
        jeq dos2
        jsr U_GEFINA           ; a directory, not a file
        lda name
        ora ext
        cmp #' '
        jne usage
        lda #$1C               ; the directory itself, to read and write
        sta mode
        lda #8
        sta scan
        lda #0
        sta attr
        jsr FOPEN
        jsr setbuf             ; its entries after the first (the
        sec                    ; directory's own) into free memory
        lda MEMTOP
        sbc MEMLO
        sta bytbuf
        lda MEMTOP+1
        sbc MEMLO+1
        sta bytbuf+1
        jsr FREAD
        bmi got                ; (the end reached: they all fit)
        jsr PRINTF
        dta b(EOL),c'Directory too long!',b(EOL),0
        jmp FCLOSE
got     lda bytbuf
        sta len
        lda bytbuf+1
        sta len+1
        jsr shuffle
        lda #23                ; back after the first entry
        sta addpos
        lda #0
        sta addpos+1
        sta addpos+2
        jsr FSEEK
        jsr setbuf
        lda len
        sta bytbuf
        lda len+1
        sta bytbuf+1
        ora bytbuf
        beq wr
        jsr FWRITE
wr      jsr PRINTF
        dta b(EOL),c'Completed!',b(EOL),0
        jmp FCLOSE
dos2    jsr PRINTF
        dta b(EOL),c'DOS 2 directories cannot be reordered',b(EOL),0
        rts
usage   jsr PRINTF
        dta b(EOL),c'Use: SHUFFLE d:[path]',b(EOL),0
        rts

* setbuf: the transfer at MEMLO, in main memory
setbuf  lda MEMLO
        sta addpos
        lda MEMLO+1
        sta addpos+1
        lda #0
        sta memreix
        rts

* shuffle: each entry in turn (up to one that was never used) changes
* places with one picked at random
shuffle lda #0                 ; n = len / 23, the number of entries
        sta n
        sta n+1
        lda len
        sta pe
        lda len+1
        sta pe+1
sf1     lda pe
        sec
        sbc #23
        tax
        lda pe+1
        sbc #0
        bcc sf2
        sta pe+1
        stx pe
        inc n
        bne sf1
        inc n+1
        bne sf1
sf2     lda n+1
        bne sf3
        lda n
        cmp #2
        bcc sf_ret
sf3     lda n+1                ; the masks: as many bits as n has
        jsr smear
        sta mhi
        lda #$FF
        ldx n+1
        bne sf3a
        lda n
        jsr smear
sf3a    sta mlo
        clc                    ; pe: the end (a 0 there ends the entries)
        lda MEMLO
        adc len
        sta pe
        lda MEMLO+1
        adc len+1
        sta pe+1
        lda #0
        tay
        sta (pe),y
        lda MEMLO
        sta pa
        lda MEMLO+1
        sta pa+1
sf4     ldy #0
        lda (pa),y
        beq sf_ret
        jsr pick
        lda pb
        cmp pa
        bne sf5
        lda pb+1
        cmp pa+1
        beq sf7
sf5     ldy #22
sf6     lda (pa),y
        tax
        lda (pb),y
        sta (pa),y
        txa
        sta (pb),y
        dey
        bpl sf6
sf7     clc
        lda pa
        adc #23
        sta pa
        bcc sf4
        inc pa+1
        bcs sf4
sf_ret  rts

* pick: pb at entry r, r random below n (random bits under the masks
* until it is)
pick    lda RANDOM
        and mlo
        sta r
        lda RANDOM
        and mhi
        sta r+1
        lda r
        cmp n
        lda r+1
        sbc n+1
        bcs pick
        lda r                  ; pb = MEMLO + r * 23 (r * 24 - r)
        sta pb
        lda r+1
        sta pb+1
        asl pb                 ; r * 8
        rol pb+1
        asl pb
        rol pb+1
        asl pb
        rol pb+1
        lda pb                 ; r * 24 = r * 8 * 3
        ldx pb+1
        asl pb
        rol pb+1
        clc
        adc pb
        sta pb
        txa
        adc pb+1
        sta pb+1
        sec                    ; - r
        lda pb
        sbc r
        sta pb
        lda pb+1
        sbc r+1
        sta pb+1
        clc
        lda pb
        adc MEMLO
        sta pb
        lda pb+1
        adc MEMLO+1
        sta pb+1
        rts

* smear: A with every bit below its highest one set
smear   sta t
        lsr @
        ora t
        sta t
        lsr @
        lsr @
        ora t
        sta t
        lsr @
        lsr @
        lsr @
        lsr @
        ora t
        rts

len     dta a(0)
n       dta a(0)
r       dta a(0)
mlo     dta 0                  ; the masks for r
mhi     dta 0
t       dta 0

        blk update address
        blk update symbols
