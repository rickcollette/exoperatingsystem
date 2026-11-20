; EOS Toolkit: PERCONF, a floppy drive's geometry (the PERCOM block)
;   PERCONF d: [SIDES n] [TRK n] [SPT n] [BPS n] [STEP n] [FLG n]
; The drive's status (S) and its PERCOM block (N: 12 bytes) are read and
; shown with the disk's size worked out from them. A drive that does not
; know N (NAK) keeps the geometry its status implies, and is not
; configurable; nor is one of fewer than two tracks (a hard disk, a RAM
; disk). Then a key: C asks for each value (Return keeps it, a word that
; is no number starts again) and writes the block (O); R reads again;
; Q or Esc ends.
; With keywords (batch): the block read is changed as given, unchecked,
; written, read back and shown, and the program ends.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_GETNUM smb 'U_GETNUM'
U_TOKEN  smb 'U_TOKEN'
U_GETKEY smb 'U_GETKEY'
U_FAIL   smb 'U_FAIL'
FGETS    smb 'FGETS'
PUTC     smb 'PUTC'
TOUPPER  smb 'TOUPPER'
PRINTF   smb 'PRINTF'
MUL_32   smb 'MUL_32'
COMTAB   smb 'COMTAB'

device   equ $0761
file_id  equ $0760
DVSTAT   equ $02EA
CRSINH   equ $02F0
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUFLO   equ $0304
DTIMLO   equ $0306
DBYTLO   equ $0308
DAUX1    equ $030A
BUFOFF   equ $0A               ; (COMTAB+: the line position, the standard
STDIN    equ $07               ; input's handle, the line; MUL_32's
LBUF     equ $3F               ; operands and result, MSB first)
MDA      equ $FF
MDB      equ $103
MDR      equ $107
EOL      equ $9B
NAK      equ 139

        blk reloc main
start   jsr U_GETPAR
        bne s1
        jsr PRINTF
        dta EOL,c'Use: PERCONF d: [SIDES n] [TRK n] [SPT n] [BPS n] [STEP n] [FLG n]',EOL,0
        rts
s1      jsr U_GEFINA
        lda device             ; D1: to D15: only
        sta unit
        and #$F0
        beq s2
        jsr PRINTF
        dta EOL,c'Disk devices only!',EOL,0
        rts
s2      lda unit
        ora #$40
        sta letter

* the status, and the geometry it implies
again   jsr rstat
        jmi fail
        jsr stget
        lda #<720
        sta total
        lda #>720
        sta total+1
        lda #0
        sta total+2
        sta total+3
        sta flags
        sta step
        sta sides+1
        sta spt+2
        sta bps+1
        lda #128
        sta bps
        lda #18
        sta spt
        lda #0
        sta spt+1
        lda #40
        sta trk
        lda #1
        sta sides
        lda stbits+2           ; double: 256 bytes
        beq st2
        asl bps
        rol bps+1
        lda #4
        sta flags
st2     lda stbits+4           ; medium: 1040 sectors
        beq st3
        lda #<1040
        sta total
        lda #>1040
        sta total+1
        lda #4
        sta flags
st3     lda #0
        sta conf

* the keywords: batch mode
args    jsr U_GETPAR
        beq a3
        lda #$FF
        sta batch
        lda kwp
        ldx kwp+1
        jsr U_TOKEN
        jcc bad
        tay                    ; its value: a byte, or a word for SPT, BPS
        lda kwofs,y
        pha
        jsr U_GETNUM
        bne a1
        pla
        jmp bad
a1      sta num
        pla
        tay
        lda num
        sta a_val,y
        txa
        sta a_val+1,y
        lda #$FF
        sta a_set,y
        jmp args
a3      bit batch
        jmi rd0
        jsr PRINTF
        dta EOL,c'Drive %c: STATUS block:',EOL,EOL
        dta c'Write-protected: %b    Motor on: %b',EOL
        dta c' Double density: %b    Reserved: %b',EOL
        dta c' Medium density: %b  FDC status: $%02x',EOL,0
        dta a(letter,stbits,stbits+1,stbits+2,stbits+3,stbits+4,DVSTAT+1)

* the PERCOM block
rd0     jsr rperc
        bpl rd1
        cmp #NAK               ; no PERCOM: the status's geometry
        beq rd2
        jmp fail
rd1     dec conf
        jsr pget
        bit batch              ; (batch: shown once it is written)
        bmi rd2a
        jsr pshow
rd2     jsr totals
rd2a    bit conf               ; configurable: PERCOM and two tracks or
        bpl noconf             ; more
        lda trk
        cmp #2
        bcs rd3
noconf  jsr PRINTF
        dta EOL,c'Drive not configurable',EOL,0
        rts
rd3     bit batch
        jmi apply
        inc CRSINH
        jsr PRINTF
        dta EOL,$C3,c'onfig drive  ',$D2,c'eread config  ',$D1,c'uit',EOL,0
        dec CRSINH
k1      jsr U_GETKEY
        and #$7F
        jsr TOUPPER
        cmp #'C'
        beq ask
        cmp #$1B
        beq k2
        cmp #'R'
        jeq again
        cmp #'Q'
        bne k1
k2      rts

* the questions; each value is checked, a wrong one asked again
ask     jsr newline
q1      jsr PRINTF
        dta c'Sides (1 or 2, now %b):',EOL,0
        dta a(sides)
        jsr input
        bcs q2
        cmp #1
        beq q1a
        cmp #2
        bne q1
q1a     sta sides
q2      jsr PRINTF
        dta c'Tracks/side (2-255, now %b):',EOL,0
        dta a(trk)
        jsr input
        bcs q3
        cmp #2
        bcc q2
        sta trk
q3      jsr PRINTF
        dta c'Sectors/track (1-65535, now %d):',EOL,0
        dta a(spt)
        jsr input
        bcs q4
        sta spt
        stx spt+1
        ldy #0
        sty spt+2
        ora spt+1
        beq q3
q4      jsr PRINTF
        dta c'Bytes/sector (128/256/512, now %d):',EOL,0
        dta a(bps)
        jsr input
        bcs q5
        cpx #0                 ; 128, 256 or 512
        beq q4a
        cmp #0
        bne q4
        cpx #1
        beq q4b
        cpx #2
        beq q4b
        bne q4
q4a     cmp #128
        bne q4
q4b     sta bps
        stx bps+1
        cpx #0                 ; more than 128: the double density flag
        beq q5
        lda #4
        ora flags
        sta flags
q5      jsr PRINTF
        dta c'Flag byte (0-255, now %b):',EOL,0
        dta a(flags)
        jsr input
        bcs q6
        sta flags
q6      jsr PRINTF
        dta c'Step rate (0-3, now %b):',EOL,0
        dta a(step)
        jsr input
        bcs q7
        cmp #4
        bcs q6
        sta step
q7      lda trk                ; into the block
        sta pc
        lda step
        sta pc+1
        lda spt+1
        sta pc+2
        lda spt
        sta pc+3
        ldx sides
        dex
        stx pc+4
        lda flags
        sta pc+5
        lda bps+1
        sta pc+6
        lda bps
        sta pc+7

* the block to the drive, its status shown
send    jsr PRINTF
        dta c'Sending configuration: ',0
        jsr wperc
        sta num
        jsr PRINTF
        dta c'status %b',EOL,0
        dta a(num)
        bit batch
        jpl rd0
        jsr rperc              ; batch: what the drive took, then the end
        jmi fail
        jsr pget
        jsr pshow
        jsr totals
newline jsr PRINTF
        dta EOL,0
        rts

* apply: the keywords given to the block read
apply   bit a_set+0            ; SIDES: the number of sides
        bpl ap1
        ldx a_val+0
        dex
        stx pc+4
ap1     bit a_set+3            ; TRK
        bpl ap2
        lda a_val+3
        sta pc
ap2     bit a_set+6            ; STEP
        bpl ap3
        lda a_val+6
        sta pc+1
ap3     bit a_set+9            ; FLG
        bpl ap4
        lda a_val+9
        sta pc+5
ap4     bit a_set+12           ; SPT
        bpl ap5
        lda a_val+12
        sta pc+3
        lda a_val+13
        sta pc+2
ap5     bit a_set+15           ; BPS
        bpl ap6
        lda a_val+15
        sta pc+7
        lda a_val+16
        sta pc+6
ap6     jsr newline
        jmp send

bad     lda #156               ; bad parameter
fail    jmp U_FAIL

* input: a number from the standard input: C=0 and AX; C=1 Return alone.
* A word that is no number: the questions end, the block is read again.
input   lda #0
        sta COMTAB+BUFOFF
        lda COMTAB+STDIN
        sta file_id
        lda lbufp
        ldx lbufp+1
        ldy #6
        jsr FGETS
        bmi input
        cpy #1
        beq in1
        jsr U_GETNUM
        beq in2
        clc
in1     rts
in2     pla
        pla
        jmp rd0

* pget: the geometry from the block
pget    lda pc+3               ; sectors a track (a third byte: below)
        sta spt
        lda pc+2
        sta spt+1
        lda #0
        sta spt+2
        lda pc+7
        sta bps
        lda pc+6
        sta bps+1
        lda pc+5
        sta flags
        lda pc+1
        sta step
        lda pc+4
        sta sides
        lda pc
        sta trk
        cmp #2                 ; a hard disk (under 2 tracks, flag bit 3):
        bcs pg1                ; the sides byte is the sector count's third
        lda flags
        and #8
        beq pg1
        lda sides
        sta spt+2
        lda #0
        sta sides
pg1     inc sides
        rts

* pshow: the block
pshow   jsr PRINTF
        dta EOL,c'Drive %c: PERCOM block:',EOL,EOL
        dta c' Num of sides: %b',EOL
        dta c'  Tracks/side: %b',EOL
        dta c'Sectors/track: %e',EOL
        dta c' Bytes/sector: %d',EOL
        dta c'Stepping rate: %b',EOL
        dta c'    Flag byte: $%02x = %%',0
        dta a(letter,sides,trk,spt,bps,step,flags)
        lda flags
        jsr binary
        jsr PRINTF
        dta c' Control byte: $%02x = %%',0
        dta a(pc+8)
        lda pc+8
        jsr binary
        jsr PRINTF
        dta c'Miscellaneous: $%02x-$%02x-$%02x (%b-%b-%b)',EOL,0
        dta a(pc+9,pc+10,pc+11,pc+9,pc+10,pc+11)
        rts

* binary: A as eight digits, then a new line
binary  sta num
        ldx #8
bi1     lda #'0'
        asl num
        adc #0
        jsr PUTC
        dex
        bne bi1
        jmp newline

* totals: sectors = spt * tracks * sides (one or two), bytes = sectors *
* bytes a sector
totals  jsr mclear
        lda spt+2
        sta COMTAB+MDA+1
        lda spt+1
        sta COMTAB+MDA+2
        lda spt
        sta COMTAB+MDA+3
        lda trk
        sta COMTAB+MDB+3
        jsr MUL_32
        ldx sides              ; two sides: twice
        dex
        beq to1
        asl COMTAB+MDR+3
        rol COMTAB+MDR+2
        rol COMTAB+MDR+1
        rol COMTAB+MDR
to1     ldx #3
        ldy #0
to2     lda COMTAB+MDR,y
        sta total,x
        iny
        dex
        bpl to2
        jsr mclear
        ldx #3
to3     lda COMTAB+MDR,x
        sta COMTAB+MDA,x
        dex
        bpl to3
        lda bps
        sta COMTAB+MDB+3
        lda bps+1
        sta COMTAB+MDB+2
        jsr MUL_32
        ldx #3
        ldy #0
to4     lda COMTAB+MDR,y
        sta bytes,x
        iny
        dex
        bpl to4
        jsr PRINTF
        dta EOL,c' Total sectors: %l',EOL
        dta c'  Bytes/sector: %d',EOL
        dta c'Total capacity: %l bytes',EOL,0
        dta a(total,bps,bytes)
        rts
mclear  ldx #3
        lda #0
mc1     sta COMTAB+MDA,x
        sta COMTAB+MDB,x
        dex
        bpl mc1
        rts

* the SIO commands: rstat the status to DVSTAT, rperc the PERCOM block to
* pc, wperc pc to the drive; A the status, N=1 an error
rstat   lda dvstp
        ldx dvstp+1
        ldy #4
        jsr dbuf
        lda #'S'
        ldx #$40
        bne sio
rperc   jsr pcbuf
        lda #'N'
        ldx #$40
        bne sio
wperc   jsr pcbuf
        lda #'O'
        ldx #$80
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
        sta DAUX1+1
        lda #4
        sta DAUX1
        jmp COMTAB-11          ; (SIO to main memory)
pcbuf   lda pcp
        ldx pcp+1
        ldy #12
dbuf    sta DBUFLO
        stx DBUFLO+1
        sty DBYTLO
        lda #0
        sta DBYTLO+1
        rts

* stget: DVSTAT's bits 3 to 7 as 0 or 1 to stbits
stget   lda DVSTAT
        lsr @
        lsr @
        lsr @
        ldx #0
sg1     lsr @
        pha
        lda #0
        rol @
        sta stbits,x
        pla
        inx
        cpx #5
        bcc sg1
        rts

kwp     dta a(kwtab)
kwtab   dta c'SIDE',c'S'*,c'TR',c'K'*,c'STE',c'P'*,c'FL',c'G'*
        dta c'SP',c'T'*,c'BP',c'S'*,0
kwofs   dta 0,3,6,9,12,15      ; each keyword's value in a_val, a_set
lbufp   dta a(COMTAB+LBUF)
dvstp   dta a(DVSTAT)
pcp     dta a(pc)

unit    dta 0
letter  dta 0
batch   dta 0
conf    dta 0
num     dta 0
stbits  dta 0,0,0,0,0
sides   dta a(0)
trk     dta a(0)
step    dta a(0)
flags   dta a(0)
spt     dta 0,0,0
bps     dta a(0)
total   dta 0,0,0,0
bytes   dta 0,0,0,0
pc      :12 dta 0              ; the PERCOM block
a_val   :18 dta 0              ; the keywords' values: 2 bytes and a flag
a_set   equ a_val+2

        blk update address
        blk update symbols
