; EOS CAR: APT, the Atari Partition Table (APT) of a hard disk
;   APT [/n]                     show the table (n: 1 master, 2 slave)
;   APT [/n] MAP d p             map drive d (1-15, A-O, Dn:) to partition p
;   APT [/n] UNMAP d             take drive d's mapping away
;   APT [/n] BOOT d              the boot drive (0: none)
;   APT [/n] AUTO p ON|OFF       partition p mounted at start (the $40 flag)
;   APT [/n] WP p ON|OFF         partition p write protected (the $80 flag)
;   APT [/n] INIT [/F]           a new, empty table at LBA 0
;   APT [/n] NEW size            a partition after the last one: size in
;                                512-byte sectors, or nK / nM (16-65535;
;                                32M means 65535)
;   APT [/n] DEL p               remove partition p (not while mapped)
; INIT refuses a sector 0 that is in use (an APT table, a PC MBR, any
; data) unless /F is given. NEW takes the disk's size from DEVINFO ($20
; command $6E) and needs the table sector's next entry to be empty.
; The disk is the PBI BIOS's physical device ($20, unit n), read and
; written in 512-byte sectors by XDCB (32-bit sector numbers, device $A0)
; through jsector_io. The table is at LBA 0, or where a PC MBR's partition
; of type $7F starts. A change is made in the table sector in memory, then
; shown, and only written after a Y on standard input ("Y" and Return, or
; <<file); the sector is read back and compared. Only the table's first
; sector is used: its mapping slots (15, more with the header's low bits)
; and the partitions after them. Reserved entries (bit 7 of the first
; byte, a type other than 0 DOS or 3 external) are shown but never
; changed or mapped; a table revision other than 0, a table kept in the
; even bytes only (header bit 7) or mapping slots past the first sector
; are shown or refused, not changed. Every other byte of the sector is
; written back as it was read. FORMAT makes the file system; the BIOS
; reads the table when the computer starts.
U_GETPAR smb 'U_GETPAR'
_DRVLET  smb '_DRVLET'
U_GETNUM smb 'U_GETNUM'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
GETS     smb 'GETS'
COMTAB   smb 'COMTAB'

jsector_io equ $070C
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUF     equ $0304
DTIMLO   equ $0306
DBYT     equ $0308
DAUX     equ $030A             ; (and DAUXA/B: the high word of an XDCB)
DBFX     equ $030E
EOL      equ $9B
E_BADPAR equ 156

ptr      equ $80               ; an entry
pt2      equ $82               ; another

        blk reloc main
start   lda #1
        sta unit
        lda #0
        sta cmd
        jsr U_GETPAR
        jeq go
        lda COMTAB+$21         ; /1, /2: the unit
        cmp #'/'
        bne s1
        lda COMTAB+$23
        cmp #EOL
        jne bad
        lda COMTAB+$22
        cmp #'1'
        jcc bad
        cmp #'2'+1
        jcs bad
        and #$0F
        sta unit
        jsr U_GETPAR
        jeq go
s1      jsr kw                 ; MAP UNMAP BOOT AUTO WP INIT NEW DEL
        jcs bad
        clc
        adc #1
        sta cmd
        cmp #6
        jcs s_ext
        cmp #3
        beq s_boot
        bcs s_part
        jsr getdrv             ; MAP, UNMAP: the drive
        jcs bad
        cmp #0
        jeq bad
        sta arg1
        lda cmd
        cmp #2
        jeq go
        jsr U_GETNUM           ; MAP: the partition
        jeq bad
        cpx #0
        jne bad
        cmp #0
        jeq bad
        sta arg2
        jmp go
s_boot  jsr getdrv
        jcs bad
        sta arg1
        jmp go
s_part  jsr U_GETNUM           ; AUTO, WP: the partition, ON or OFF
        jeq bad
        cpx #0
        jne bad
        cmp #0
        jeq bad
        sta arg1
        jsr U_GETPAR
        jeq bad
        lda COMTAB+$21
        cmp #'O'
        jne bad
        lda COMTAB+$22
        ldx #1
        cmp #'N'
        beq sp1
        dex
        cmp #'F'
        jne bad
        lda COMTAB+$23
        cmp #'F'
        jne bad
        lda COMTAB+$24
        bne sp2
sp1     lda COMTAB+$23
sp2     cmp #EOL
        jne bad
        stx arg2
        jmp go
s_ext   bne s_x2               ; INIT [/F]
        jsr U_GETPAR
        jeq go
        lda COMTAB+$21
        cmp #'/'
        jne bad
        lda COMTAB+$22
        cmp #'F'
        jne bad
        lda COMTAB+$23
        cmp #EOL
        jne bad
        lda #1
        sta force
        jmp go
s_x2    cmp #7                 ; NEW size
        bne s_x3
        jsr U_GETPAR
        jeq bad
        jsr psz
        jcs bad
        jmp go
s_x3    jsr U_GETNUM           ; DEL p
        jeq bad
        cpx #0
        jne bad
        cmp #0
        jeq bad
        sta arg1
go      lda cmd
        cmp #6
        jeq c_init
        jsr load
        lda cmd
        bne edit
        jmp list
edit    lda rev
        beq e1
        jsr PRINTF
        dta c'APT revision %b: not changed',EOL,0
        dta a(rev)
        rts
e1      lda cmd
        cmp #1
        jeq c_map
        cmp #2
        jeq c_unmap
        cmp #3
        jeq c_boot
        cmp #7
        jeq c_new
        cmp #8
        jeq c_del
        jmp c_flag

bad     jsr PRINTF
        dta c'APT [/n] [MAP d p|UNMAP d|BOOT d|',EOL
        dta c'    AUTO p ON|OFF|WP p ON|OFF|',EOL
        dta c'    INIT [/F]|NEW size[K|M]|DEL p]',EOL,0
        lda #E_BADPAR
        jmp U_FAIL

; ---- the table -------------------------------------------------------------

* load: the table's first sector into sec; tlba its LBA, nslots, nparts,
* rev, chain (the next LBA, 0: none). Fails when there is none.
load    ldx #3
        lda #0
ld0     sta lba,x
        dex
        bpl ld0
        jsr rdsec
        jsr isapt
        bcc ld_ok
        lda sec+$1FE           ; a PC MBR: its partition of type $7F
        cmp #$55
        jne noapt
        lda sec+$1FF
        cmp #$AA
        jne noapt
        ldx #0
ld1     lda sec+$1C2,x
        cmp #$7F
        beq ld2
        txa
        clc
        adc #16
        tax
        cpx #64
        bcc ld1
        jcs noapt
ld2     ldy #0
ld3     lda sec+$1C6,x
        sta lba,y
        inx
        iny
        cpy #4
        bcc ld3
        lda lba
        ora lba+1
        ora lba+2
        ora lba+3
        beq noapt
        jsr rdsec
        jsr isapt
        bcs noapt
ld_ok   ldx #3
ld4     lda lba,x
        sta tlba,x
        lda sec+8,x
        sta chain,x
        dex
        bpl ld4
        lda sec
        bpl ld5
        jsr PRINTF
        dta c'Table in the even bytes only: not',EOL
        dta c'supported',EOL,0
        jmp quit
ld5     lsr @
        lsr @
        lsr @
        lsr @
        lsr @
        and #3
        sta rev
        lda sec
        and #$0F
        clc
        adc #15
        sta nslots
        lda sec+5              ; the entries in this sector (header too)
        beq badhdr
        cmp #33
        bcs badhdr
        sec
        sbc #1
        sec
        sbc nslots
        bcc slots
        sta nparts
        rts
noapt   jsr PRINTF
        dta c'No APT table on unit %b',EOL,0
        dta a(unit)
        jmp quit
badhdr  jsr PRINTF
        dta c'Bad APT header at LBA %l',EOL,0
        dta a(tlba)
        jmp quit
slots   jsr PRINTF
        dta c'Mapping slots go past the first',EOL
        dta c'table sector: not supported',EOL,0
quit    pla                    ; (from load: back to DOS)
        pla
        rts

* isapt: C=0 when sec starts with an APT header
isapt   lda sec+1
        cmp #'A'
        bne ia_no
        lda sec+2
        cmp #'P'
        bne ia_no
        lda sec+3
        cmp #'T'
        bne ia_no
        clc
        rts
ia_no   sec
        rts

* rdsec, wrsec: sector lba to/from sec; rdchk: to chk. An error fails.
rdchk   lda chka
        ldx chka+1
        ldy #'R'
        bne xio
rdsec   lda seca
        ldx seca+1
        ldy #'R'
        bne xio
wrsec   lda seca
        ldx seca+1
        ldy #'W'
xio     sta DBUF
        stx DBUF+1
        sty DCOMND
        lda #$40               ; read, or write ($80)
        cpy #'W'
        bne xi1
        asl @
xi1     sta DSTATS
        lda #$A0               ; an XDCB for the physical device $20
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #7
        sta DTIMLO
        lda #0
        sta DBYT
        sta DBFX
        sta DBFX+1
        lda #2
        sta DBYT+1
        ldx #3
xi2     lda lba,x
        sta DAUX,x
        dex
        bpl xi2
        jsr jsector_io
        bmi xi_err
        rts
xi_err  jmp U_FAIL

* entp: ptr = the entry A of sec (A*16 bytes on)
entp    ldx #0
        stx ptr+1
        asl @
        rol ptr+1
        asl @
        rol ptr+1
        asl @
        rol ptr+1
        asl @
        rol ptr+1
        clc
        adc seca
        sta ptr
        lda ptr+1
        adc seca+1
        sta ptr+1
        rts

* partp: ptr = partition A's entry (1-based); C=1 when there is none
partp   cmp #1
        bcc pp_no
        cmp nparts
        beq pp1
        bcs pp_no
pp1     clc
        adc nslots
        jsr entp
        clc
        rts
pp_no   sec
        rts

* usable: C=0 when the entry at ptr is a DOS (0) or external (3)
* partition: sector size bits set, not reserved
usable  ldy #0
        lda (ptr),y
        bmi us_no
        and #3
        beq us_no
        iny
        lda (ptr),y
        beq us_ok
        cmp #3
        bne us_no
us_ok   clc
        rts
us_no   sec
        rts

* which: A = the partition (1-based) whose type, start, size and ID
* (bytes 1-11) are those of the entry at ptr; 0 when none
which   lda ptr
        sta pt2
        lda ptr+1
        sta pt2+1
        lda #1
        sta wn
wh1     lda wn
        cmp nparts
        beq wh2
        bcs wh_no
wh2     jsr partp
        ldy #0
        lda (ptr),y
        and #3
        beq wh4
        ldy #11
wh3     lda (ptr),y
        cmp (pt2),y
        bne wh4
        dey
        bne wh3
        lda pt2                ; found: ptr back
        sta ptr
        lda pt2+1
        sta ptr+1
        lda wn
        rts
wh4     inc wn
        bne wh1
wh_no   lda pt2
        sta ptr
        lda pt2+1
        sta ptr+1
        lda #0
        rts

; ---- the listing -----------------------------------------------------------

list    jsr PRINTF
        dta c'APT on unit %b, table at LBA %l',EOL
        dta c'Revision %b, %b slots, %b partitions',EOL,0
        dta a(unit,tlba,rev,nslots,nparts)
        lda sec+4
        and #$0F
        sta bootd
        bne li1
        jsr PRINTF
        dta c'Boot drive: none',EOL,0
        jmp li2
li1     jsr PRINTF
        dta c'Boot drive: D%b:',EOL,0
        dta a(bootd)
li2     lda #1                 ; the mapped drives
        sta row
li3     lda row
        jsr entp
        ldy #0
        lda (ptr),y
        and #3
        beq li6
        lda (ptr),y
        bpl li4
        jsr PRINTF
        dta c'D%b: reserved entry',EOL,0
        dta a(row)
        jmp li6
li4     jsr which
        sta val
        bne li5
        jsr PRINTF
        dta c'D%b: not a listed partition',EOL,0
        dta a(row)
        jmp li6
li5     jsr PRINTF
        dta c'D%b: partition %b',EOL,0
        dta a(row,val)
li6     inc row
        lda row
        cmp #16
        bcs li7
        cmp nslots
        jeq li3
        jcc li3
li7     jsr PRINTF
        dta c' # Type      Start       Size Sec Fl',EOL,0
        lda #1
        sta row
li8     lda row
        cmp nparts
        beq li9
        jcs li_end
li9     jsr partp
        ldy #0
        lda (ptr),y
        and #3
        jeq li_end             ; the end of the list
        ldy #15
li10    lda (ptr),y
        sta cur,y
        dey
        bpl li10
        jsr usable
        bcc li11
        jsr PRINTF
        dta c'%2b reserved entry, type $%2x',EOL,0
        dta a(row,cur+1)
        jmp li12
li11    lda cur                ; the sector size
        and #3
        tax
        lda szlo,x
        sta val
        lda szhi,x
        sta val+1
        lda #'D'               ; DOS or EXT(ernal)
        ldx #'O'
        ldy #'S'
        lda cur+1
        beq li11a
        lda #'E'
        ldx #'X'
        ldy #'T'
        bne li11b
li11a   lda #'D'
li11b   sta tstr
        stx tstr+1
        sty tstr+2
        lda #'-'               ; the flags: A(uto) W(rite protected)
        sta fstr
        sta fstr+1
        lda cur+12
        and #$40
        beq li11c
        lda #'A'
        sta fstr
li11c   lda cur+12
        bpl li11d
        lda #'W'
        sta fstr+1
li11d   jsr PRINTF
        dta c'%2b %s %10l %10l %3d %s',EOL,0
        dta a(row,tstr,cur+2,cur+6,val,fstr)
li12    inc row
        jne li8
li_end  lda chain
        ora chain+1
        ora chain+2
        ora chain+3
        beq li_x
        jsr PRINTF
        dta c'More entries at LBA %l: not shown',EOL,0
        dta a(chain)
li_x    rts

; ---- the changes -----------------------------------------------------------

c_map   lda arg1               ; the drive's slot
        cmp nslots
        beq cm1
        jcs nodrv
cm1     lda arg2
        sta val
        jsr partp
        bcc cm2
        jmp nopart
cm2     jsr usable
        bcc cm3
        jsr PRINTF
        dta c'Partition %b cannot be mapped',EOL,0
        dta a(arg2)
        rts
cm3     lda ptr
        sta pt2
        lda ptr+1
        sta pt2+1
        lda arg1
        jsr entp
        ldy #0
        lda (ptr),y
        jmi resv
        jsr PRINTF
        dta c'Change: D%b: to partition %b',EOL,0
        dta a(arg1,arg2)
        ldy #15
cm4     lda (pt2),y
        sta (ptr),y
        dey
        bpl cm4
        jmp confirm

c_unmap lda arg1
        cmp nslots
        beq cu1
        jcs nodrv
cu1     jsr entp
        ldy #0
        lda (ptr),y
        jmi resv
        and #3
        bne cu2
        jsr PRINTF
        dta c'D%b: is not mapped',EOL,0
        dta a(arg1)
        rts
cu2     jsr PRINTF
        dta c'Change: D%b: unmapped',EOL,0
        dta a(arg1)
        lda #0                 ; (the slot's other bytes stay)
        tay
        sta (ptr),y
        jmp confirm

c_boot  lda sec+4
        and #$0F
        sta bootd
        cmp arg1
        jeq nochg
        jsr PRINTF
        dta c'Change: boot drive D%b: to D%b:',EOL,0
        dta a(bootd,arg1)
        lda sec+4
        and #$F0
        ora arg1
        sta sec+4
        jmp confirm

c_flag  lda arg1
        sta val
        jsr partp
        jcs nopart
        jsr usable
        jcs resv
        ldx #$40               ; AUTO, else WP
        lda cmd
        cmp #4
        beq cf1
        ldx #$80
cf1     stx mask
        ldy #12
        lda (ptr),y
        and mask
        beq cf2
        lda #1
cf2     cmp arg2
        jeq nochg
        lda (ptr),y
        eor mask
        sta (ptr),y
        lda arg2
        ldx p_on
        ldy p_on+1
        cmp #0
        bne cf3
        ldx p_off
        ldy p_off+1
cf3     stx onoff
        sty onoff+1
        lda p_auto
        ldx p_auto+1
        ldy mask
        bpl cf4
        lda p_wp
        ldx p_wp+1
cf4     sta what
        stx what+1
        jsr PRINTF
        dta c'Change: partition %b %p %p',EOL,0
        dta a(arg1,what,onoff)
        lda ptr                ; the slots mapping it: the same entry
        sta pt2
        lda ptr+1
        sta pt2+1
        lda #1
        sta row
cf5     lda row
        jsr entp
        ldy #0
        lda (ptr),y
        bmi cf8
        and #3
        beq cf8
        ldy #11
cf6     lda (ptr),y
        cmp (pt2),y
        bne cf8
        dey
        bne cf6
        ldy #15
cf7     lda (pt2),y
        sta (ptr),y
        dey
        bpl cf7
        jsr PRINTF
        dta c'Change: D%b: follows it',EOL,0
        dta a(row)
cf8     inc row
        lda row
        cmp #16
        bcs confirm
        cmp nslots
        beq cf5
        bcc cf5
        ; (fall through)

* confirm: the question; Y writes the table and reads it back
confirm jsr PRINTF
        dta c'Write the table to LBA %l of',EOL
        dta c'unit %b (Y/N)? ',0
        dta a(tlba,unit)
        lda ansa
        ldx ansa+1
        ldy #8
        jsr GETS
        php
        jsr PRINTF
        dta EOL,0
        plp
        jmi cn_no
        ldx #0
cn1     lda ans,x
        cmp #' '
        bne cn2
        inx
        cpx #8
        bcc cn1
cn2     and #$DF
        cmp #'Y'
        jne cn_no
        ldx #3
cn3     lda tlba,x
        sta lba,x
        dex
        bpl cn3
        jsr wrsec
        jsr rdchk
        ldx #0
cn4     lda sec,x
        cmp chk,x
        bne cn_bad
        lda sec+$100,x
        cmp chk+$100,x
        bne cn_bad
        inx
        bne cn4
        jsr PRINTF
        dta c'Table written and read back. The',EOL
        dta c'BIOS reads it when the computer',EOL
        dta c'starts.',EOL,0
        rts
cn_bad  jsr PRINTF
        dta c'The table read back differs!',EOL,0
        lda #144
        jmp U_FAIL
cn_no   jsr PRINTF
        dta c'Not written.',EOL,0
        rts

nochg   jsr PRINTF
        dta c'No change.',EOL,0
        rts
nodrv   jsr PRINTF
        dta c'No mapping slot for D%b:',EOL,0
        dta a(arg1)
        rts
nopart  jsr PRINTF
        dta c'No partition %b',EOL,0
        dta a(val)
        rts
resv    jsr PRINTF
        dta c'A reserved entry: not changed',EOL,0
        rts

; ---- making partitions ---------------------------------------------------

* c_init: a new table at LBA 0: the header and 15 empty mapping slots.
* Sector 0 in use (an APT table, a PC MBR, other data) only with /F.
c_init  ldx #3
        lda #0
ci0     sta lba,x
        sta tlba,x
        dex
        bpl ci0
        jsr rdsec
        jsr isapt
        jcs ci1
        lda force
        bne ci_a
        jsr PRINTF
        dta c'Sector 0 holds an APT table: APT INIT',EOL
        dta c'/F replaces it (the partitions are lost)',EOL,0
        rts
ci_a    jsr PRINTF
        dta c'Change: the APT table and its partitions',EOL
        dta c'are replaced',EOL,0
        jmp ci_new
ci1     lda sec+$1FE
        cmp #$55
        jne ci2
        lda sec+$1FF
        cmp #$AA
        jne ci2
        lda force
        bne ci_m
        jsr PRINTF
        dta c'Sector 0 holds a PC partition table',EOL
        dta c'(MBR): APT INIT /F replaces it',EOL,0
        rts
ci_m    jsr PRINTF
        dta c'Change: the PC partition table (MBR) is',EOL
        dta c'replaced',EOL,0
        jmp ci_new
ci2     ldx #0                 ; anything else in it?
ci3     lda sec,x
        ora sec+$100,x
        bne ci4
        inx
        bne ci3
        beq ci_new
ci4     lda force
        bne ci_new
        jsr PRINTF
        dta c'Sector 0 is in use: APT INIT /F',EOL
        dta c'replaces it',EOL,0
        rts
ci_new  ldx #0                 ; the header, 15 empty slots
        txa
ci5     sta sec,x
        sta sec+$100,x
        inx
        bne ci5
        lda #'A'
        sta sec+1
        lda #'P'
        sta sec+2
        lda #'T'
        sta sec+3
        lda #16
        sta sec+5
        jsr PRINTF
        dta c'Change: a new APT table at LBA 0, no',EOL
        dta c'partitions',EOL,0
        jmp confirm

* c_new: a partition of psize sectors after the end of every entry (and
* after the table), as entry count of the table sector
c_new   lda sec+5
        sta cnt
        cmp #32
        bcc cn_0
        jsr PRINTF
        dta c'The table sector is full',EOL,0
        rts
cn_0    jsr entp               ; that entry must be unused
        ldy #15
cn_1    lda (ptr),y
        jne cn_used
        dey
        bpl cn_1
        ldx #3                 ; the start: after the table ...
        lda #0
cn_2    sta nst,x
        sta nid,x
        dex
        bpl cn_2
        lda tlba
        clc
        adc #1
        sta nst
        lda tlba+1
        adc #0
        sta nst+1
        lda tlba+2
        adc #0
        sta nst+2
        lda tlba+3
        adc #0
        sta nst+3
        lda #1                 ; ... and after every entry; the IDs
        sta row
cn_3    lda row
        cmp cnt
        jcs cn_6
        jsr entp
        ldy #0
        lda (ptr),y
        and #3
        beq cn_5
        clc                    ; end = start + size (4 bytes)
        ldy #2
        lda (ptr),y
        ldy #6
        adc (ptr),y
        sta tmp
        ldy #3
        lda (ptr),y
        ldy #7
        adc (ptr),y
        sta tmp+1
        ldy #4
        lda (ptr),y
        ldy #8
        adc (ptr),y
        sta tmp+2
        ldy #5
        lda (ptr),y
        ldy #9
        adc (ptr),y
        sta tmp+3
        jsr tmp_ge             ; nst = max(nst, end)
        ldy #11                ; nid = max(nid, ID)
        lda (ptr),y
        cmp nid+1
        bcc cn_5
        bne cn_4a
        dey
        lda (ptr),y
        cmp nid
        bcc cn_5
cn_4a   ldy #10
        lda (ptr),y
        sta nid
        iny
        lda (ptr),y
        sta nid+1
cn_5    inc row
        jmp cn_3
cn_6    inc nid                ; the new ID: the highest + 1
        bne cn_7
        inc nid+1
cn_7    jsr devinfo            ; the disk's size: end <= it
        lda nst
        clc
        adc psize
        sta tmp
        lda nst+1
        adc psize+1
        sta tmp+1
        lda nst+2
        adc #0
        sta tmp+2
        lda nst+3
        adc #0
        sta tmp+3
        ldx #3
cn_8    lda dsize,x
        cmp tmp,x
        jcc cn_room
        bne cn_9
        dex
        bpl cn_8
cn_9    lda cnt                ; the entry
        jsr entp
        ldy #15
        lda #0
cn_10   sta (ptr),y
        dey
        bpl cn_10
        lda #3                 ; 512-byte sectors, a DOS partition
        ldy #0
        sta (ptr),y
        ldx #0
        ldy #2
cn_11   lda nst,x
        sta (ptr),y
        iny
        inx
        cpx #4
        bcc cn_11
        lda psize
        sta (ptr),y
        iny
        lda psize+1
        sta (ptr),y
        ldy #10
        lda nid
        sta (ptr),y
        iny
        lda nid+1
        sta (ptr),y
        iny
        lda #$40               ; automount
        sta (ptr),y
        inc sec+5
        lda nparts
        clc
        adc #1
        sta val
        jsr PRINTF
        dta c'Change: partition %b, LBA %l,',EOL
        dta c'%d sectors of 512 bytes',EOL,0
        dta a(val,nst,psize)
        jmp confirm
cn_used jsr PRINTF
        dta c'The table sector holds other data where',EOL
        dta c'the new entry goes: not changed',EOL,0
        rts
cn_room jsr PRINTF
        dta c'Not enough room: the disk has %l',EOL
        dta c'sectors, the partition would end at %l',EOL,0
        dta a(dsize,tmp)
        rts

* tmp_ge: nst = tmp when tmp > nst (4 bytes)
tmp_ge  ldx #3
tg1     lda tmp,x
        cmp nst,x
        bcc tg_x
        bne tg2
        dex
        bpl tg1
        rts
tg2     ldx #3
tg3     lda tmp,x
        sta nst,x
        dex
        bpl tg3
tg_x    rts

* c_del: partition arg1 removed, the entries after it moved up one
c_del   lda arg1
        sta val
        jsr partp
        jcs nopart
        jsr usable
        jcs resv
        lda ptr                ; a slot mapping it?
        sta pt2
        lda ptr+1
        sta pt2+1
        lda #1
        sta row
cd1     lda row
        jsr entp
        ldy #0
        lda (ptr),y
        bmi cd3
        and #3
        beq cd3
        ldy #11
cd2     lda (ptr),y
        cmp (pt2),y
        bne cd3
        dey
        bne cd2
        jsr PRINTF
        dta c'Partition %b is mapped to D%b:: UNMAP',EOL
        dta c'it first',EOL,0
        dta a(val,row)
        rts
cd3     inc row
        lda row
        cmp #16
        bcs cd4
        cmp nslots
        beq cd1
        bcc cd1
cd4     jsr PRINTF
        dta c'Change: partition %b removed (its data',EOL
        dta c'is lost); the ones after it move up one',EOL,0
        dta a(val)
        lda val                ; entry index of p
        clc
        adc nslots
        sta row
cd5     lda row                ; entry row+1 -> row
        clc
        adc #1
        cmp sec+5
        bcs cd7
        jsr entp
        lda ptr
        sta pt2
        lda ptr+1
        sta pt2+1
        lda row
        jsr entp
        ldy #15
cd6     lda (pt2),y
        sta (ptr),y
        dey
        bpl cd6
        inc row
        bne cd5
cd7     lda row                ; the last one cleared
        jsr entp
        ldy #15
        lda #0
cd8     sta (ptr),y
        dey
        bpl cd8
        dec sec+5
        jmp confirm

* devinfo: the physical disk's DEVINFO ($20 command $6E) to chk; dsize
* its sector count. An error fails.
devinfo lda #$20
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #$6E
        sta DCOMND
        lda #$40
        sta DSTATS
        lda chka
        sta DBUF
        lda chka+1
        sta DBUF+1
        lda #7
        sta DTIMLO
        lda #0
        sta DBYT
        sta DAUX
        sta DAUX+1
        lda #2
        sta DBYT+1
        jsr jsector_io
        jmi xi_err
        ldx #3
dv1     lda chk+8,x
        sta dsize,x
        dex
        bpl dv1
        rts

* psz: psize = the size at COMFNAM: decimal sectors, nK, nM; 16-65535.
* C=1 when it is not one
psz     lda #0
        sta tmp
        sta tmp+1
        sta tmp+2
        sta tmp+3
        ldx #0
        lda COMTAB+$21
        jsr isdig
        bcs pz_no
pz1     lda COMTAB+$21,x
        jsr isdig
        bcs pz3
        pha                    ; tmp = tmp * 10 + digit
        lda tmp+2
        cmp #$19
        bcs pz_no2
        jsr t2                 ; *2
        ldy #2
pz2     lda tmp,y
        sta tmp+4,y            ; (keep tmp*2 in tmp+4.. tmp+6)
        dey
        bpl pz2
        jsr t2                 ; *8
        jsr t2
        clc
        lda tmp
        adc tmp+4
        sta tmp
        lda tmp+1
        adc tmp+5
        sta tmp+1
        lda tmp+2
        adc tmp+6
        sta tmp+2
        pla
        and #$0F
        clc
        adc tmp
        sta tmp
        bcc pz2a
        inc tmp+1
        bne pz2a
        inc tmp+2
pz2a    inx
        cpx #10
        bcc pz1
        bcs pz_no
pz_no2  pla
pz_no   sec
        rts
pz3     ldy #0                 ; the unit: none, K (x2), M (x2048)
        cmp #EOL
        beq pz6
        cmp #'K'
        bne pz4
        ldy #1
        bne pz5
pz4     cmp #'M'
        bne pz_no
        ldy #11
pz5     lda COMTAB+$22,x
        cmp #EOL
        bne pz_no
pz5a    lda tmp+2              ; (it must still fit 24 bits)
        cmp #$80
        bcs pz_no
        jsr t2
        dey
        bne pz5a
pz6     lda tmp+2              ; 32M (65536) is taken as the largest, 65535
        cmp #1
        bne pz6a
        lda tmp+1
        ora tmp
        ora tmp+3
        bne pz_no
        lda #$FF
        sta tmp
        sta tmp+1
        bcs pz7                ; (C=1 from cmp)
pz6a    lda tmp+2
        ora tmp+3
        bne pz_no
        lda tmp+1
        bne pz7
        lda tmp
        cmp #16
        bcc pz_no
pz7     lda tmp
        sta psize
        lda tmp+1
        sta psize+1
        clc
        rts
t2      asl tmp
        rol tmp+1
        rol tmp+2
        rts
isdig   cmp #'0'
        bcc id_no
        cmp #'9'+1
        bcs id_no
        clc
        rts
id_no   sec
        rts

; ---- the parameters --------------------------------------------------------

* getdrv: C=0 and A = the drive in the next parameter: 0-15, A-O, Dn, Dn:
getdrv  jsr U_GETNUM
        beq gd1
        cpx #0
        bne gd_no
        cmp #16
        bcs gd_no
        clc
        rts
gd1     jsr U_GETPAR
        beq gd_no
        jmp drive
gd_no   sec
        rts

* kw: C=0 and A = the number of the word at COMFNAM in kwtab; C=1 none
kw      ldy #0
        lda #0
        sta kwn
kw1     ldx #0
kw2     lda kwtab,y
        beq kw_no
        cmp COMTAB+$21,x
        bne kw3
        iny
        inx
        cmp #EOL
        bne kw2
        lda kwn
        clc
        rts
kw3     lda kwtab,y
        iny
        cmp #EOL
        bne kw3
        inc kwn
        bne kw1
kw_no   sec
        rts

* drive: C=0 and A = the unit of A-O, Dn or Dn: at COMFNAM; C=1 not one
drive   lda COMTAB+$21
        ldx COMTAB+$22
        cpx #EOL
        beq dr_l
        cpx #':'
        bne dr_d
        ldx COMTAB+$23
        cpx #EOL
        bne dr_no
dr_l    jmp _DRVLET            ; a letter: D is D1, a CIO device's not a drive
dr_d    cmp #'D'               ; Dn, Dnn, with or without a colon
        bne dr_no
        lda #0
        sta kwn
        ldx #1
dr1     lda COMTAB+$21,x
        cmp #'0'
        bcc dr2
        cmp #'9'+1
        bcs dr2
        and #$0F
        pha
        lda kwn
        asl @
        asl @
        adc kwn
        asl @
        sta kwn
        pla
        adc kwn
        sta kwn
        inx
        cpx #4
        bcc dr1
        bcs dr_no
dr2     cpx #1
        beq dr_no
        cmp #':'
        bne dr3
        inx
        lda COMTAB+$21,x
dr3     cmp #EOL
        bne dr_no
        lda kwn
        beq dr_no
        cmp #16
        bcs dr_no
        clc
        rts
dr_no   sec
        rts

unit    dta 0
cmd     dta 0                  ; 0 show, 1 MAP, 2 UNMAP, 3 BOOT, 4 AUTO, 5 WP,
                               ; 6 INIT, 7 NEW, 8 DEL
arg1    dta 0
arg2    dta 0
rev     dta 0
nslots  dta 0
nparts  dta 0
bootd   dta 0
row     dta 0
wn      dta 0
kwn     dta 0
mask    dta 0
val     dta a(0)
lba     dta 0,0,0,0
tlba    dta 0,0,0,0
chain   dta 0,0,0,0
cur     :16 dta 0
what    dta a(0)
onoff   dta a(0)
szlo    dta 0,128,0,0          ; sector size by code: -, 128, 256, 512
szhi    dta 0,0,1,2
tstr    dta c'DOS',EOL
fstr    dta c'--',EOL
s_on    dta c'ON',EOL
s_off   dta c'OFF',EOL
s_auto  dta c'automount',EOL
s_wp    dta c'write protection',EOL
p_on    dta a(s_on)
p_off   dta a(s_off)
p_auto  dta a(s_auto)
p_wp    dta a(s_wp)
seca    dta a(sec)
chka    dta a(chk)
ansa    dta a(ans)
ans     :8 dta 0
kwtab   dta c'MAP',EOL,c'UNMAP',EOL,c'BOOT',EOL,c'AUTO',EOL,c'WP',EOL
        dta c'INIT',EOL,c'NEW',EOL,c'DEL',EOL,0
force   dta 0
cnt     dta 0
psize   dta a(0)
nst     dta 0,0,0,0
nid     dta 0,0,0,0
dsize   dta 0,0,0,0
tmp     dta 0,0,0,0,0,0,0
sec     :512 dta 0
chk     :512 dta 0

        blk update address
        blk update symbols
