; EOS Toolkit: RPM, a drive's rotation speed
;   RPM [d:]
; Sector 1 is read again and again: each read waits for the sector to
; come round, so five reads take five turns of the disk. The time they
; take, in scan lines (frames from RTCLOK, the line from VCOUNT), gives
; the turns a minute; the number shown is the mean of it and the one
; before. Until a key is pressed. The reads go through jblock_io, so that
; the sector's size is the disk's.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
MUL_32   smb 'MUL_32'
DIV_32   smb 'DIV_32'

jblock_io equ $0706
device   equ $0761
MEMLO    equ $02E7
RTCLOK   equ $12
CH       equ $02FC
DDEVIC   equ $0300
DUNIT    equ $0301
DBUFLO   equ $0304
DAUX1    equ $030A
VCOUNT   equ $D40B
PAL      equ $D014
MDA      equ $FF               ; (COMTAB+: MUL_32's and DIV_32's operands
MDB      equ $103              ; and result, MSB first)
MDR      equ $107
EOL      equ $9B
UP       equ $1C               ; cursor up

        blk reloc main
start   jsr U_GETPAR           ; the drive: given or the current one
        jsr U_GEFINA
        lda #$31
        sta DDEVIC
        lda device
        and #$0F
        sta DUNIT
        lda MEMLO              ; the sector to MEMLO
        sta DBUFLO
        lda MEMLO+1
        sta DBUFLO+1
        lda #1
        sta DAUX1
        lda #0
        sta DAUX1+1
        ldy #4                 ; bm_fread: the disk's sector size
        jsr jblock_io
        bmi fail
        lda PAL                ; the scan lines in a frame and in a
        and #$0E               ; minute times five (five turns): PAL
        bne r0
        lda #<312
        ldx #>312
        ldy #0
        beq r0a
r0      lda #<262              ; NTSC
        ldx #>262
        ldy #3
r0a     sta lines
        stx lines+1
        ldx #0
r0b     lda rates,y
        sta rate,x
        iny
        inx
        cpx #3
        bcc r0b

r1      jsr read               ; in step with the disk
        jsr now
        ldx #3
r2      lda t,x
        sta t0,x
        dex
        bpl r2
        ldx #5                 ; five turns
r3      jsr read
        dex
        bne r3
        jsr now
        jsr turns
        jsr PRINTF
        dta c'  Drive RPM is %d',EOL,UP,0
        dta a(rpm)
        lda CH                 ; until a key
        cmp #$FF
        beq r1
        lda #$FF
        sta CH
        jsr PRINTF
        dta EOL,EOL,0
        rts
fail    jmp U_FAIL

* read: sector 1 (bm_read); keeps X
read    txa
        pha
        ldy #0
        jsr jblock_io
        bmi fail
        pla
        tax
        rts

* now: t = the time in scan lines: frames * lines + VCOUNT * 2 (the
* frame counter read again when it moved meanwhile)
now     lda RTCLOK+2
        sta fr
        lda RTCLOK+1
        sta fr+1
        lda VCOUNT
        sta vc
        lda RTCLOK+2
        cmp fr
        bne now
        lda RTCLOK
        sta COMTAB+MDA+1
        lda #0                 ; frames * lines
        sta COMTAB+MDA
        sta COMTAB+MDB
        sta COMTAB+MDB+1
        lda fr+1
        sta COMTAB+MDA+2
        lda fr
        sta COMTAB+MDA+3
        lda lines+1
        sta COMTAB+MDB+2
        lda lines
        sta COMTAB+MDB+3
        jsr MUL_32
        lda vc                 ; + VCOUNT * 2
        asl @
        sta vc
        lda #0
        rol @
        sta vc+1
        clc
        lda COMTAB+MDR+3
        adc vc
        sta t
        lda COMTAB+MDR+2
        adc vc+1
        sta t+1
        lda COMTAB+MDR+1
        adc #0
        sta t+2
        lda COMTAB+MDR
        adc #0
        sta t+3
        rts

* turns: rpm = (rate / (t - t0) + rpm) / 2, both rounded (rate * 2 is
* divided, the result is one more and halved)
turns   sec
        ldx #0
        ldy #3
tu1     lda t,x
        sbc t0,x
        sta COMTAB+MDB,y       ; (MSB first)
        inx
        dey
        bpl tu1
        lda #0
        sta COMTAB+MDA
        ldx #2
tu2     lda rate,x
        sta COMTAB+MDA+1,x
        dex
        bpl tu2
        asl COMTAB+MDA+3
        rol COMTAB+MDA+2
        rol COMTAB+MDA+1
        rol COMTAB+MDA
        jsr DIV_32
        sec
        lda COMTAB+MDR+3       ; (C=1: + 1)
        adc #0
        sta n
        lda COMTAB+MDR+2
        adc #0
        lsr @
        ror n
        tax
        sec                    ; the mean: (n + rpm + 1) / 2
        lda n
        adc rpm
        sta rpm
        txa
        adc rpm+1
        ror @
        sta rpm+1
        ror rpm
        rts

lines   dta a(0)
n       dta 0
rates   dta $47,$36,$56        ; 1773447 / 114 * 300 (PAL), MSB first
        dta $47,$DE,$28        ; 1789773 / 114 * 300 (NTSC)
rate    dta 0,0,0              ; (MSB first)
rpm     dta a(288)             ; the first mean: with the usual speed
fr      dta a(0)
vc      dta a(0)
t       dta 0,0,0,0
t0      dta 0,0,0,0

        blk update address
        blk update symbols
