; EOS Toolkit: DU, the space a directory tree takes
;   DU [/Q] [+|-][AHPS] [d:path]
; Every directory below the one given is counted and entered; files count
; when they match the name given (none: all). Attributes choose among the
; entries of the first directory only, deeper ones are taken whole. Each
; entry is shown as it is counted (A:SUB>X.DAT, a directory with > after
; it); /Q shows directories only, /QQ nothing. At the end the bytes (and
; kilobytes, rounded) and the numbers of directories and files, and the
; sum of both. The sizes of directories are those of their entries.
U_SLASH  smb 'U_SLASH'
U_ARGV   smb 'U_ARGV'
U_GETATR smb 'U_GETATR'
U_FSPEC  smb 'U_FSPEC'
U_GEFINA smb 'U_GEFINA'
U_PATH   smb 'U_PATH'
U_FAIL   smb 'U_FAIL'
FFIRST   smb 'FFIRST'
FOPEN    smb 'FOPEN'
FNEXT    smb 'FNEXT'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

COMFNAM  equ $21               ; (COMTAB+: the parameter)
mode     equ $0778
scan     equ $0779
dentry   equ $0789             ; status, node, size, name
LMARGN   equ $52
RMARGN   equ $53
MEMTOP   equ $02E5
MEMLO    equ $02E7
EOL      equ $9B
ESZ      equ 36                ; status, 24-bit size, name length and 31 bytes
MAXLV    equ 16

cur      equ $80               ; the entry in hand
top      equ $82               ; the end of the lists

        blk reloc main
start   lda #$FF
        jsr U_ARGV
        lda a_opts
        ldx a_opts+1
        ldy #2
        jsr U_SLASH
        lda #0
        ldx #sums_n-1
s0      sta dbytes,x
        dex
        bpl s0
        sta depth
        jsr U_GETATR           ; (all entries unless attributes are given)
        bne s1
        ldx #1                 ; no name: *
s0a     lda all,x
        sta COMTAB+COMFNAM,x
        dex
        bpl s0a
        lda a_comfn
        sta FILE_P
        lda a_comfn+1
        sta FILE_P+1
        jmp s1a
s1      jsr U_FSPEC
s1a     jsr U_GEFINA           ; resolve the path to show
        lda a_disp
        ldx a_disp+1
        ldy #0
        jsr U_PATH
        sty displ
        ldx #0                 ; the directory as typed: up to the last
        ldy #0                 ; separator
s3      lda COMTAB+COMFNAM,x
        cmp #EOL
        beq s5
        sta spec,x
        inx
        cmp #':'
        beq s4
        cmp #'/'
        beq s4
        bne s3
s4      txa
        tay
        jmp s3
s5      sty specl
        lda a_end              ; the lists from the program's end or MEMLO
        sta top
        lda a_end+1
        sta top+1
        lda MEMLO+1
        cmp top+1
        bcc s6
        bne s5a
        lda MEMLO
        cmp top
        bcc s6
s5a     lda MEMLO
        sta top
        lda MEMLO+1
        sta top+1
s6      jsr level

        clc                    ; the sum, then each in kilobytes
        ldx #0
s7      lda dbytes,x
        adc fbytes,x
        sta tbytes,x
        inx
        txa
        eor #4
        bne s7
        ldy #0                 ; (dirs, files, total, in this order)
        ldx #0
s8      jsr kbytes
        iny
        iny
        iny
        iny
        inx
        inx
        inx
        cpx #9
        bcc s8
        lda RMARGN             ; a narrow screen: B for bytes
        sec
        sbc LMARGN
        cmp #48
        ldx #0
        bcc s9
        ldx #2
s9      lda units,x
        sta unit
        lda units+1,x
        sta unit+1
        jsr PRINTF
        dta b(EOL),c'%l%p%ek) in %d directories',b(EOL)
        dta c'%l%p%ek) in %d files',b(EOL)
        dta c'%l%p%ek) total',b(EOL,0)
        dta a(dbytes,unit,kb,ndirs,fbytes,unit,kb+3,nfiles,tbytes,unit,kb+6)
        rts

* kbytes: the 32 bits at dbytes+Y in kilobytes, rounded, to kb+X (24 bits)
kbytes  lda dbytes+3,y
        sta kb+2,x
        lda dbytes+2,y
        sta kb+1,x
        lda dbytes+1,y
        lsr kb+2,x
        ror kb+1,x
        ror @
        lsr kb+2,x
        ror kb+1,x
        ror @
        adc #0                 ; the last bit out: half a kilobyte
        sta kb,x
        bcc kb1
        inc kb+1,x
        bne kb1
        inc kb+2,x
kb1     rts

* level: the directory spec (specl long) with disp (displ long) shown for
* it: its entries listed in memory, then each counted, a directory entered
level   ldx specl              ; spec + *.*
        ldy #0
lv0     lda all,y
        sta spec,x
        inx
        iny
        cpy #2
        bcc lv0
        lda a_spec
        sta FILE_P
        lda a_spec+1
        sta FILE_P+1
        lda #0                 ; walk every entry; filtering is transient-side
lv1     sta scan
        lda top
        sta base
        lda top+1
        sta base+1
        lda #0
        sta cnt
        sta cnt+1
        jsr FFIRST
        bmi lv5
lv2     clc                    ; room for one more?
        lda top
        adc #ESZ
        tax
        lda top+1
        adc #0
        cmp MEMTOP+1
        bcc lv3
        bne lv2m
        cpx MEMTOP
        bcc lv3
lv2m    jsr FCLOSE
        lda #158
        jmp U_FAIL
lv3     ldy #0
        lda dentry
        sta (top),y
        ldx #3                 ; size and name length
lv4     iny
        lda dentry,x
        sta (top),y
        inx
        cpx #7
        bcc lv4
        ldx #0                 ; exact name bytes
lv4n    iny
        lda dentry+7,x
        sta (top),y
        inx
        cpx #31
        bcc lv4n
        clc
        lda top
        adc #ESZ
        sta top
        bcc lv4a
        inc top+1
lv4a    inc cnt
        bne lv4b
        inc cnt+1
lv4b    jsr FNEXT
        bpl lv2
lv5     jsr FCLOSE
        lda base
        sta cur
        lda base+1
        sta cur+1
lv6     lda cnt
        ora cnt+1
        bne lv7
        lda base               ; the list is done with
        sta top
        lda base+1
        sta top+1
        rts
lv7     lda cnt
        bne lv7a
        dec cnt+1
lv7a    dec cnt
        jsr entry
        clc
        lda cur
        adc #ESZ
        sta cur
        bcc lv6
        inc cur+1
        bcs lv6

* entry: the entry at cur counted and shown; a directory entered
entry   ldy #0
        lda (cur),y
        and #$20
        bne en_dir
en_count
        ldx #fbytes-dbytes
        jsr addsz
        inc nfiles
        bne en3
        inc nfiles+1
en3     lda opt_q              ; shown without /Q
        bne en_ret
        ldx displ
        jsr addnm
        lda #EOL
        sta disp,x
        jsr PRINTF
        dta c'%s',b(EOL,0)
        dta a(disp)
en_ret  rts
en_dir  inc ndirs
        bne en4
        inc ndirs+1
en4     lda depth
        cmp #MAXLV*2
        bcs en_ret
        ldx displ              ; one level down: NAME> after both paths
        jsr addnm
        lda #'/'
        sta disp,x
        inx
        cpx #120
        bcs en_ret
        stx nd
        lda #EOL
        sta disp,x
        ldx opt_q              ; shown with /Q too, not /QQ
        inx
        bmi en5
        jsr PRINTF
        dta c'%s',b(EOL,0)
        dta a(disp)
en5     ldx specl
        jsr addnm2
        lda #'/'
        sta spec,x
        inx
        lda #EOL               ; its size: the one its own header gives
        sta spec,x
        stx nd2
        lda a_spec
        sta FILE_P
        lda a_spec+1
        sta FILE_P+1
        lda #$14
        sta mode
        lda #0
        sta scan
        jsr FOPEN
        jsr FCLOSE
        ldy #3
en6     lda dentry+2,y          ; (the size: dentry+3)
        sta (cur),y
        dey
        bne en6
        ldx #0
        jsr addsz
        ldx nd2
        ldy depth              ; what this level needs back
        lda cur
        sta st_cur,y
        lda cur+1
        sta st_cur+1,y
        lda cnt
        sta st_cnt,y
        lda cnt+1
        sta st_cnt+1,y
        lda base
        sta st_base,y
        lda base+1
        sta st_base+1,y
        lda specl
        sta st_spec,y
        lda displ
        sta st_disp,y
        stx specl
        lda nd
        sta displ
        iny
        iny
        sty depth
        jsr level
        ldy depth
        dey
        dey
        sty depth
        lda st_cur,y
        sta cur
        lda st_cur+1,y
        sta cur+1
        lda st_cnt,y
        sta cnt
        lda st_cnt+1,y
        sta cnt+1
        lda st_base,y
        sta base
        lda st_base+1,y
        sta base+1
        lda st_spec,y
        sta specl
        lda st_disp,y
        sta displ
        rts

* addsz: the entry's size to dbytes+X (32 bits)
addsz   ldy #1
        clc
as1     lda (cur),y
        adc dbytes,x
        sta dbytes,x
        inx
        iny
        tya
        eor #4
        bne as1
        lda dbytes,x
        adc #0
        sta dbytes,x
        rts

* addnm: the entry's exact name to disp+X; addnm2: to spec+X;
* X = its end
addnm   lda a_disp
        ldy a_disp+1
        bne an0
addnm2  lda a_spec
        ldy a_spec+1
an0     sta an_st+1
        sty an_st+2
        ldy #4
        lda (cur),y
        sta namelen
        clc
        adc #5
        sta nameend
        ldy #5
an1     cpy nameend
        bcs an4
        lda (cur),y
        jsr an_st
        iny
        bne an1
an4     rts
an_st   sta $FFFF,x            ; (the address set above)
        inx
        rts

a_opts  dta a(opt_q)
a_comfn dta a(COMTAB+COMFNAM)
a_disp  dta a(disp)
a_spec  dta a(spec)
a_end   dta a(pend)
opt_q   dta b(0),c'Q'
all     dta c'*',b(EOL)
units   dta a(u_b,u_bytes)
u_b     dta c' B (',0
u_bytes dta c' bytes (',0
unit    dta a(0)
depth   dta 0
specl   dta 0
displ   dta 0
nd      dta 0
nd2     dta 0
cnt     dta a(0)
base    dta a(0)
namelen dta 0
nameend dta 0
dbytes  dta 0,0,0,0
fbytes  dta 0,0,0,0
tbytes  dta 0,0,0,0
ndirs   dta a(0)
nfiles  dta a(0)
sums_n  equ *-dbytes
kb      :9 dta 0
st_cur  :MAXLV*2 dta 0
st_cnt  :MAXLV*2 dta 0
st_base :MAXLV*2 dta 0
st_spec :MAXLV*2 dta 0
st_disp :MAXLV*2 dta 0
spec    :128 dta 0
disp    :128 dta 0
pend

        blk update address
        blk update symbols
