; EOS CAR: CHKDSK, a disk's volume name, size and free space
;   CHKDSK [d:] [/X]
; From GETDFREE: the volume name with the disk's sequence and random
; numbers, the sector size, the capacity and free space in KB (rounded
; up). /X instead lists the file system and, on a SpartaDOS disk, what
; its boot sector (sector 1, read through SIO) tells, ending with the
; time the disk was formatted (its main directory's own entry) when
; there is one. Only the first drive given counts; another switch: 156.
U_GETPAR smb 'U_GETPAR'
GETDFREE smb 'GETDFREE'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

path     equ $0640
device   equ $0761
;lsio (COMTAB-11): jsector_io (the SIO drivers, the RAM disk, else the
;OS's SIOV) with memreix 0
SIOV     equ $0A2F
EOL      equ $9B

        blk reloc main
start   lda #0
        sta opt_x
        lda #EOL
        sta spec
p1      jsr U_GETPAR
        beq p_end
        lda COMTAB+$21
        cmp #'/'
        beq p_sw
        lda spec               ; the first drive only
        cmp #EOL
        bne p1
        ldx #0
p2      lda COMTAB+$21,x
        sta spec,x
        inx
        cmp #EOL
        bne p2
        beq p1
p_sw    ldx #1
p3      lda COMTAB+$21,x
        cmp #EOL
        beq p1
        cmp #'X'
        beq p4
        lda #156               ; another switch
        jmp U_FAIL
p4      sta opt_x
        inx
        bne p3
p_end   lda spa
        sta FILE_P
        lda spa+1
        sta FILE_P+1
        jsr GETDFREE
        ldx #$10               ; keep what it read
c1      lda path,x
        sta info,x
        dex
        bpl c1
        lda device
        sta dev
        ldx #7                 ; the volume name
c2      lda info+6,x
        sta vol,x
        dex
        bpl c2
        lda #0                 ; the sector size: $80 128, else 256
        sta ssize+1
        sta ssize              ; shifted left by the code
        sta ssize+2
        sta ssize+3
        lda #$80
        ldx info+1
        bmi c4
        txa
        and #$0F
        tax
        lda #1
        sta ssize+1
        lda #0
c3      dex
        bmi c4
        asl ssize+1
        jmp c3
c4      sta ssize
        lda opt_x
        bne c5
        jsr PRINTF
        dta EOL,c'     Volume: %s %2x %2x',EOL,0
        dta a(vol,info+$0E,info+$0F)
        jmp c6
c5      jsr PRINTF             ; /X: the labels are wider
        dta EOL,c'           Volume: %s %2x %2x',EOL,0
        dta a(vol,info+$0E,info+$0F)
        jmp xinfo
c6
        lda info+2             ; KB: sectors * size / 1024, rounded up
        ldx info+3
        jsr tokb
        sta kt
        stx kt+1
        sty kt+2
        lda info+4
        ldx info+5
        jsr tokb
        sta kf
        stx kf+1
        sty kf+2
        jsr PRINTF
        dta c'Sector size: %l bytes',EOL
        dta c'   Capacity: %e KB',EOL
        dta c' Free space: %e KB',EOL,0
        dta a(ssize,kt,kf)
        rts

* tokb: AX sectors to KB in AXY (rounded up)
tokb    sta v
        stx v+1
        lda #0
        sta v+2
        sta v+3
        sta r
        sta r+1
        sta r+2
        sta r+3
        ldx #16                ; r = v * ssize (16 bits by 16 bits)
tk1     asl r
        rol r+1
        rol r+2
        rol r+3
        asl v
        rol v+1
        bcc tk2
        clc
        lda r
        adc ssize
        sta r
        lda r+1
        adc ssize+1
        sta r+1
        bcc tk2
        inc r+2
        bne tk2
        inc r+3
tk2     dex
        bne tk1
        clc                    ; + 1023, / 1024
        lda r
        adc #$FF
        lda r+1
        adc #$03
        sta r+1
        bcc tk3
        inc r+2
        bne tk3
        inc r+3
tk3     ldx #2
tk4     lsr r+3
        ror r+2
        ror r+1
        dex
        bne tk4
        lda r+1
        ldx r+2
        ldy r+3
        rts

* /X: the extended information
xinfo   lda info
        and #$F0
        cmp #$20
        jeq xsd
        lda info
        cmp #$10
        bcs x2
        sta minor
        jsr PRINTF
        dta c'      File system: Atari DOS',EOL
        dta c'          Version: %b.0',EOL,0
        dta a(minor)
        jmp x5
x2      cmp #$11
        bne x3
        jsr PRINTF
        dta c'      File system: SpartaDOS',EOL
        dta c'          Version: 1.1',EOL,0
        jmp x5
x3      cmp #$FF
        bne x4
        jsr PRINTF
        dta c'      File system: MyDOS',EOL,0
        jmp x5
x4      jsr PRINTF
        dta c'      File system: $%2x',EOL,0
        dta a(info)
x5      jsr PRINTF
        dta EOL
        dta c'      Sector size: %l bytes',EOL
        dta c'         Capacity: %d sectors',EOL
        dta c'       Free space: %d sectors',EOL,0
        dta a(ssize,info+2,info+4)
        rts

* SpartaDOS: the boot sector
xsd     lda info
        and #$0F
        sta minor
        lda #1
        ldx #0
        jsr rdsec
        bcs x5
        lda sbuf+$1E           ; tracks, bit 7: both sides
        and #$7F
        sta trk
        lda #1
        ldx sbuf+$1E
        bpl xs1
        lda #2
xs1     sta sides
        lda sbuf+$25           ; sectors per cluster (0 taken as 1)
        bne xs2
        lda #1
xs2     sta spc
        lda #0
        sta csize+2
        sta csize+3
        lda ssize
        sta csize
        lda ssize+1
        sta csize+1
        ldx spc
xs3     dex
        beq xs4
        clc
        lda csize
        adc ssize
        sta csize
        lda csize+1
        adc ssize+1
        sta csize+1
        bcc xs3
        inc csize+2
        bne xs3
xs4     ldx #5                 ; what the date needs, before sbuf goes
xs5     lda sbuf+$09,x
        sta bs,x
        dex
        bpl xs5
        lda sbuf+$0F
        sta bs+6
        lda sbuf+$10
        sta bs+7
        lda sbuf+$11
        sta bs+8
        jsr PRINTF
        dta c'      File system: SpartaDOS',EOL
        dta c'          Version: 2.%b',EOL,EOL
        dta c'       Media type: disk',EOL
        dta c'  Number of sides: %b',EOL
        dta c' Number of tracks: %b',EOL
        dta c'      Sector size: %l bytes',EOL
        dta c'  Sectors/cluster: %b',EOL
        dta c'     Cluster size: %l bytes',EOL
        dta c'         Capacity: %d clusters',EOL
        dta c'       Free space: %d clusters',EOL,EOL
        dta c'   Root directory: $%4x',EOL
        dta c'VTOC sector count: %b',EOL
        dta c'VTOC first sector: $%4x',EOL,0
        dta a(minor,sides,trk,ssize,spc,csize,info+2,info+4,bs,bs+6,bs+7)
        lda bs                 ; the main directory: its map, its first
        ldx bs+1               ; sector, its own entry's date and time
        jsr rdsec
        bcs xs_end
        lda sbuf+4
        ldx sbuf+5
        jsr rdsec
        bcs xs_end
        ldx #5
xs6     lda sbuf+17,x
        sta dt,x
        dex
        bpl xs6
        lda dt                 ; no date: not shown
        beq xs_end
        jsr PRINTF
        dta EOL,c'  Formatting time: %b-%02b-%02b %02b:%02b',EOL,0
        dta a(dt,dt+1,dt+2,dt+3,dt+4)
xs_end  rts

* rdsec: sector AX of the drive to sbuf through SIO; C=1 on an error.
* Sectors 1-3 are 128 bytes unless the disk's sectors are 512 bytes.
rdsec   sta $030A
        stx $030B
        lda dev
        cmp #$10
        bcs rs_bad
        and #$0F
        sta $0301              ; DUNIT
        lda #$31
        sta $0300              ; DDEVIC
        lda #'R'
        sta $0302
        lda #$40
        sta $0303
        lda sba
        sta $0304
        lda sba+1
        sta $0305
        lda #7
        sta $0306
        lda ssize
        sta $0308
        lda ssize+1
        sta $0309
        cmp #2                 ; 512 bytes: all sectors that size
        bcs rs1
        lda $030B
        bne rs1
        lda $030A
        cmp #4
        bcs rs1
        lda #128
        sta $0308
        lda #0
        sta $0309
rs1     jsr SIOV
        bmi rs_bad
        clc
        rts
rs_bad  sec
        rts

spa     dta a(spec)
sba     dta a(sbuf)
opt_x   dta 0
dev     dta 0
minor   dta 0
trk     dta 0
sides   dta 0
spc     dta 0
ssize   dta 0,0,0,0
csize   dta 0,0,0,0
kt      dta 0,0,0,0
kf      dta 0,0,0,0
v       dta 0,0,0,0
r       dta 0,0,0,0
bs      :9 dta 0
dt      :6 dta 0
info    :17 dta 0
vol     :8 dta 0
        dta EOL
spec    :64 dta 0
sbuf    :512 dta 0

        blk update address
        blk update symbols
