; EOS CAR: UNERASE, erased files brought back
;   UNERASE [d:][path]fname[.ext]
; The directory is read as it is on the disk (direct directory access), and
; each erased entry matching the name whose sectors (sector maps and data)
; are all still free, and whose name is not in use again, is offered:
; "Restore NAME.EXT? ". On Y its sectors are taken in the bitmap again
; (sector I/O through SIO) and the entry is in use again.
; SpartaDOS (SDFS) disks only.
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FSEEK    smb 'FSEEK'
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

file_id  equ $0760
device   equ $0761
name     equ $0762
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
dentry   equ $0789
MEMTOP   equ $02E5
MEMLO    equ $02E7
CIOV     equ $E456
;lsio (COMTAB-11): jsector_io (the SIO drivers, the RAM disk, else the
;OS's SIOV) with memreix 0
SIOV     equ $0A2F
DCB      equ $0300
EOL      equ $9B
BSLASH   equ $5C
ST_USED  equ $08
ST_DEL   equ $10

ptr      equ $80
cur      equ $82
bp       equ $84

        blk reloc main
start   jsr U_GETPAR           ; a name is needed
        bne s1
        lda #156
        jmp U_FAIL
s1      ldx #0                 ; the parameter; the directory part ends
        stx dend               ; after the last : > < or backslash
s2      lda COMTAB+$21,x
        sta parm,x
        inx
        cmp #':'
        beq s3
        cmp #'>'
        beq s3
        cmp #'<'
        beq s3
        cmp #BSLASH
        bne s4
s3      stx dend
s4      cmp #EOL
        bne s2
        jsr U_GEFINA           ; the name pattern and the drive
        ldx #10
s5      lda name,x
        sta pat,x
        dex
        bpl s5
        lda pat
        cmp #' '
        bne s5b
        ldx #10
        lda #'?'
s5a     sta pat,x
        dex
        bpl s5a
s5b     lda device
        and #$F0               ; a drive only
        beq s6
        lda #146
        jmp U_FAIL
s6      lda device
        sta drvdev
        and #$0F
        sta unit
        ldx dend               ; the directory alone
        lda #EOL
        sta parm,x
        jsr memory
* the directory's entries, as they are
        jsr opendir
        lda #$14
        sta mode
        jsr FOPEN
        sec                    ; its length less the header
        lda dentry+3
        sbc #23
        sta dlen
        lda dentry+4
        sbc #0
        sta dlen+1
        lda dentry+5
        sbc #0
        beq r1
        lda #158
        jmp U_FAIL
r1      lda dlen
        sta dlen0
        lda dlen+1
        sta dlen0+1
        clc                    ; room?
        lda top
        adc dlen
        tax
        lda top+1
        adc dlen+1
        bcs r1m
        cmp mtop+1
        bcc r2
        bne r1m
        cpx mtop
        bcc r2
r1m     lda #158
        jmp U_FAIL
r2      lda top
        sta addpos
        lda top+1
        sta addpos+1
        lda dlen
        sta bytbuf
        lda dlen+1
        sta bytbuf+1
        lda #0
        sta memreix
        ora dlen
        ora dlen+1
        beq r3
        jsr FREAD
r3      jsr FCLOSE
* the disk: its header
        jsr rdboot
* each erased entry that matches
        lda top
        sta cur
        lda top+1
        sta cur+1
        lda #23                ; its place in the directory
        sta epos
        lda #0
        sta epos+1
e1      lda dlen
        ora dlen+1
        bne e2
        rts
e2      ldy #0
        lda (cur),y
        jeq e_done             ; the end of the used entries
        and #ST_USED|ST_DEL
        cmp #ST_DEL
        bne e_next
        ldy #6+10              ; the name
e3      lda pat-6,y
        cmp #'?'
        beq e4
        cmp (cur),y
        bne e_next
e4      dey
        cpy #6
        bcs e3
        jsr inuse              ; not when the name is taken again
        bcs e_next
        lda #0                 ; are its sectors free?
        sta marking
        jsr chain
        bcs e_next
        jsr fname
        jsr PRINTF
        dta c'Restore %s? ',0
        dta a(fnm)
        jsr yesno
        bcc e_next
        lda #$FF               ; take them
        sta marking
        lda #0
        sta taken
        sta taken+1
        jsr chain
        jsr bmflush
        jsr freecnt
        jsr setent
e_next  clc
        lda cur
        adc #23
        sta cur
        bcc e5
        inc cur+1
e5      clc
        lda epos
        adc #23
        sta epos
        bcc e6
        inc epos+1
e6      sec
        lda dlen
        sbc #23
        sta dlen
        lda dlen+1
        sbc #0
        sta dlen+1
        bcc e_done
        jmp e1
e_done  rts

* opendir: FILE_P = the directory part of the parameter
opendir lda a_parm
        sta FILE_P
        lda a_parm+1
        sta FILE_P+1
        lda #0
        sta scan
        sta attr
        rts

* inuse: C=1 when a live entry has the name of the one at cur
inuse   lda top
        sta ptr
        lda top+1
        sta ptr+1
        lda dlen0
        sta cnt
        lda dlen0+1
        sta cnt+1
iu1     lda cnt+1
        bne iu2
        lda cnt
        cmp #23
        bcc iu_no
iu2     ldy #0
        lda (ptr),y
        beq iu_no
        and #ST_USED|ST_DEL
        cmp #ST_USED
        bne iu4
        ldy #6+10
iu3     lda (ptr),y
        cmp (cur),y
        bne iu4
        dey
        cpy #6
        bcs iu3
        sec
        rts
iu4     clc
        lda ptr
        adc #23
        sta ptr
        bcc iu5
        inc ptr+1
iu5     sec
        lda cnt
        sbc #23
        sta cnt
        bcs iu1
        dec cnt+1
        jmp iu1
iu_no   clc
        rts

* chain: every sector of the file at cur (its maps and data): marking 0,
* C=1 unless all are free; marking $FF, all taken (counted in taken)
chain   ldy #1
        lda (cur),y
        sta msec
        iny
        lda (cur),y
        sta msec+1
        lda #0
        sta guard
        sta guard+1
ch1     lda msec
        ora msec+1
        bne ch2
        clc                    ; the end of the maps
        rts
ch2     lda msec
        sta ssec
        lda msec+1
        sta ssec+1
        jsr onesec
        bcs ch_ret
        lda msec               ; the map itself
        ldx msec+1
        ldy a_mapbuf
        sty sbuf
        ldy a_mapbuf+1
        sty sbuf+1
        ldy #$52
        jsr sio
        lda #4                 ; its data sectors
        sta mi
        lda #0
        sta mi+1
ch3     jsr mapent
        lda ssec
        ora ssec+1
        beq ch4                ; none here (sparse)
        jsr onesec
        bcs ch_ret
ch4     clc
        lda mi
        adc #2
        sta mi
        bcc ch4a
        inc mi+1
ch4a    lda mi
        cmp seclen
        lda mi+1
        sbc seclen+1
        bcc ch3
        ldy #0                 ; the next map
        jsr mapw
        sta msec
        stx msec+1
        inc guard              ; a loop in the maps: not a file
        jne ch1
        inc guard+1
        lda guard+1
        cmp #$40
        jcc ch1
        sec
ch_ret  rts

* mapent: ssec = the map's word at mi
mapent  clc
        lda a_mapbuf
        adc mi
        sta ptr
        lda a_mapbuf+1
        adc mi+1
        sta ptr+1
        ldy #0
        lda (ptr),y
        sta ssec
        iny
        lda (ptr),y
        sta ssec+1
        rts
* mapw: AX = the map's word at Y
mapw    lda mapbuf+1,y
        tax
        lda mapbuf,y
        rts

* onesec: the sector ssec: checked free (marking 0, C=1 when not) or taken
onesec  lda ssec+1             ; on the disk at all?
        cmp total+1
        bcc os1
        bne os_bad
        lda ssec
        cmp total
        bcs os_bad
os1     jsr bitpos
        ldy #0
        lda (bp),y
        and mask
        beq os_bad             ; in use
        bit marking
        bpl os_ok
        lda mask
        eor #$FF
        and (bp),y
        sta (bp),y
        lda #$FF
        sta bmdirty
        inc taken
        bne os_ok
        inc taken+1
os_ok   clc
        rts
os_bad  sec
        rts

* bitpos: bp = the bitmap byte of sector ssec (its sector read), mask = its bit
bitpos  lda ssec
        and #7
        tax
        lda bits,x
        sta mask
        lda ssec+1             ; byte = sector / 8
        sta bi+1
        lda ssec
        lsr bi+1
        ror @
        lsr bi+1
        ror @
        lsr bi+1
        ror @
        sta bi
        lda bi                 ; its offset in a bitmap sector
        and smask
        sta off
        lda bi+1
        and smask+1
        sta off+1
        lda bi                 ; and which sector: byte >> shift
        sta bs
        lda bi+1
        sta bs+1
        ldx shift
bp1     lsr bs+1
        ror bs
        dex
        bne bp1
        clc
        lda bs
        adc bmap
        tax
        lda bs+1
        adc bmap+1
        cmp bmsec+1
        bne bp2
        cpx bmsec
        beq bp3
bp2     pha                    ; another bitmap sector
        txa
        pha
        jsr bmflush
        pla
        sta bmsec
        pla
        sta bmsec+1
        lda a_bmbuf
        sta sbuf
        lda a_bmbuf+1
        sta sbuf+1
        lda bmsec
        ldx bmsec+1
        ldy #$52
        jsr sio
bp3     clc
        lda a_bmbuf
        adc off
        sta bp
        lda a_bmbuf+1
        adc off+1
        sta bp+1
        rts

* bmflush: the bitmap sector back to the disk when it was changed
bmflush lda bmdirty
        beq bf1
        lda #0
        sta bmdirty
        lda a_bmbuf
        sta sbuf
        lda a_bmbuf+1
        sta sbuf+1
        lda bmsec
        ldx bmsec+1
        ldy #$50
        jmp sio
bf1     rts

* freecnt: the header's free sectors less the ones taken
freecnt lda a_boot
        sta sbuf
        lda a_boot+1
        sta sbuf+1
        lda #1
        ldx #0
        ldy #$52
        jsr sio
        sec
        lda boot+13
        sbc taken
        sta boot+13
        lda boot+14
        sbc taken+1
        sta boot+14
        lda #1
        ldx #0
        ldy #$50
        jmp sio

* setent: the entry in use again, through the file system
setent  ldy #0
        lda #ST_USED
        sta (cur),y
        sta stbyte
        jsr opendir
        lda #$1C
        sta mode
        jsr FOPEN
        lda epos
        sta addpos
        lda epos+1
        sta addpos+1
        lda #0
        sta addpos+2
        jsr FSEEK
        lda a_stbyte
        sta addpos
        lda a_stbyte+1
        sta addpos+1
        lda #1
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jsr FWRITE
        jmp FCLOSE

* rdboot: the volume header (sector 1): sizes, bitmap, total
rdboot  lda #128               ; 128 bytes first, else a 512-byte disk
        sta seclen
        lda #0
        sta seclen+1
        lda a_boot
        sta sbuf
        lda a_boot+1
        sta sbuf+1
        lda #1
        ldx #0
        ldy #$52
        jsr sio_try
        bpl rb1
        lda #0
        sta seclen
        lda #2
        sta seclen+1
        lda #1
        ldx #0
        ldy #$52
        jsr sio
rb1     lda boot+32            ; SpartaDOS 2.0 or 2.1
        cmp #$20
        beq rb20
        cmp #$21
        beq rb21
        lda #148
        jmp U_FAIL
rb21    lda boot+33
        sta seclen
        lda boot+34
        sta seclen+1
        jmp rb3
rb20    lda #0
        sta seclen
        lda #1
        sta seclen+1
        lda boot+31
        cmp #$80
        bne rb3
        sta seclen
        lda #0
        sta seclen+1
rb3     lda boot+11
        sta total
        lda boot+12
        sta total+1
        inc total              ; (sectors 1 ... total: below total+1)
        bne rb3a
        inc total+1
rb3a    lda boot+16
        sta bmap
        lda boot+17
        sta bmap+1
        sec                    ; the offset mask and the shift
        lda seclen
        sbc #1
        sta smask
        lda seclen+1
        sbc #0
        sta smask+1
        ldx #7
        lda seclen+1
        beq rb4
        ldx #8
        cmp #1
        beq rb4
        ldx #9
rb4     stx shift
        lda #0
        sta bmsec
        sta bmsec+1
        sta bmdirty
        rts

* sio: sector AX, command Y ($52 read, $50 write) with the buffer sbuf;
* fails on an error. sio_try: N=1 on an error instead.
sio     jsr sio_try
        bpl si_ok
        jmp U_FAIL
si_ok   rts
sio_try sta DCB+$0A
        stx DCB+$0B
        sty DCB+$02
        lda #$31
        sta DCB+$00
        lda unit
        sta DCB+$01
        lda #$40
        cpy #$52
        beq si1
        lda #$80
si1     sta DCB+$03
        lda sbuf
        sta DCB+$04
        lda sbuf+1
        sta DCB+$05
        lda #7
        sta DCB+$06
        lda seclen             ; sectors 1-3 of a 256-byte disk: 128 bytes
        sta DCB+$08
        lda seclen+1
        sta DCB+$09
        cmp #1
        bne si2
        lda DCB+$0B
        bne si2
        lda DCB+$0A
        cmp #4
        bcs si2
        lda #128
        sta DCB+$08
        lda #0
        sta DCB+$09
si2     jsr SIOV
        lda DCB+$03
        rts

* fname: the name at cur as NAME.EXT to fnm
fname   ldx #0
        ldy #6
fn1     lda (cur),y
        cmp #' '
        beq fn2
        sta fnm,x
        inx
fn2     iny
        cpy #6+8
        bcc fn1
        lda (cur),y
        cmp #' '
        beq fn4
        lda #'.'
        sta fnm,x
        inx
fn3     lda (cur),y
        cmp #' '
        beq fn3a
        sta fnm,x
        inx
fn3a    iny
        cpy #6+11
        bcc fn3
fn4     lda #EOL
        sta fnm,x
        rts

* yesno: a line from the keyboard; C=1 when it starts with Y
yesno   ldx #0                 ; E:, IOCB 0
        lda #5
        sta $0342
        lda a_inbuf
        sta $0344
        lda a_inbuf+1
        sta $0345
        lda #40
        sta $0348
        lda #0
        sta $0349
        jsr CIOV
        ldx #0
yn1     lda inbuf,x
        cmp #' '
        bne yn2
        inx
        cpx #40
        bcc yn1
yn2     and #$DF
        cmp #'Y'
        beq yn3
        clc
        rts
yn3     sec
        rts

* memory: the directory goes after the program (or MEMLO), up to MEMTOP
memory  lda a_pend
        sta top
        lda a_pend+1
        sta top+1
        lda MEMLO+1
        cmp top+1
        bcc me1
        bne me0
        lda MEMLO
        cmp top
        bcc me1
me0     lda MEMLO
        sta top
        lda MEMLO+1
        sta top+1
me1     lda MEMTOP
        sta mtop
        lda MEMTOP+1
        sta mtop+1
        rts

a_parm  dta a(parm)
a_pend  dta a(pend)
a_inbuf dta a(inbuf)
a_boot  dta a(boot)
a_mapbuf dta a(mapbuf)
a_bmbuf dta a(bmbuf)
a_stbyte dta a(stbyte)
bits    dta b($80,$40,$20,$10,$08,$04,$02,$01)
dend    dta 0
unit    dta 0
drvdev  dta 0
marking dta 0
mask    dta 0
shift   dta 0
bmdirty dta 0
stbyte  dta 0
top     dta a(0)
mtop    dta a(0)
dlen    dta a(0)
dlen0   dta a(0)
cnt     dta a(0)
epos    dta a(0)
msec    dta a(0)
ssec    dta a(0)
mi      dta a(0)
guard   dta a(0)
taken   dta a(0)
seclen  dta a(0)
smask   dta a(0)
total   dta a(0)
bmap    dta a(0)
bmsec   dta a(0)
bi      dta a(0)
bs      dta a(0)
off     dta a(0)
sbuf    dta a(0)
pat     :11 dta 0
fnm     :14 dta 0
parm    :66 dta 0
inbuf   :40 dta 0
boot    :512 dta 0
mapbuf  :512 dta 0
bmbuf   :512 dta 0
pend    equ *

        blk update address
        blk update symbols
