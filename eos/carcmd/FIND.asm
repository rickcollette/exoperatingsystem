; EOS CAR: FIND, files looked for in every directory
;   FIND [d: | device][path]fname[.ext]
; With just a name every drive (A: to O:) that answers is searched from its
; main directory; with a device or a directory only there, from the
; directory given (the main one when none), shown as typed after the drive
; letter (A:SUB>X.DAT). Hidden files are found too;
; directories are searched, not matched. Each match is shown with its whole
; path, a blank line after each drive's matches, and the number of matches
; at the end. A drive or directory that is not there finds nothing.
jkernel  equ $0703
FNEXT    smb 'FNEXT'
FCLOSE   smb 'FCLOSE'
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'
_DRVNAME smb '_DRVNAME'
_DRVNM   smb '_DRVNM'

device   equ $0761
name     equ $0762
scan     equ $0779
dentry   equ $0789
path     equ $0640
MEMTOP   equ $02E5
MEMLO    equ $02E7
EOL      equ $9B
BSLASH   equ $5C
ESZ      equ 12                ; a list entry: status and name
MAXLV    equ 16
LVSZ     equ 7

ptr      equ $80
cur      equ $82

        blk reloc main
start   lda #0
        sta nmatch
        sta nmatch+1
        sta depth
        sta sp
        jsr memory
        jsr U_GETPAR
        bne s0
        lda #156
        jmp U_FAIL
s0      ldx #0                 ; the parameter: a device, a directory?
        stx hasdev
        stx hassep
s1      lda COMTAB+$21,x
        sta parm,x
        cmp #':'
        bne s1a
        stx hasdev
        inc hasdev
s1a     cmp #'/'
        beq s1b
        cmp #'<'
        beq s1b
        cmp #BSLASH
        bne s2
s1b     sta hassep
s2      inx
        cmp #EOL
        bne s1
        jsr U_GEFINA           ; the pattern
        ldx #10
s3      lda name,x
        sta pat,x
        dex
        bpl s3
        lda pat                ; no name: everything
        cmp #' '
        bne s3b
        ldx #10
        lda #'?'
s3a     sta pat,x
        dex
        bpl s3a
s3b     lda hasdev             ; a device or a directory: there only
        ora hassep
        bne one
* ---- every drive ----
        lda #1
        sta unit
dr1     jsr drvpfx             ; "Dn:" then ">"
        lda #'/'
        sta pfx,x
        inx
        stx plen
        jsr probe
        bcs dr2
        jsr drive
dr2     inc unit
        lda unit
        cmp #16
        bcc dr1
        jmp total
* ---- one device ----
one     lda device
        and #$F0
        bne o2
        lda device             ; a drive: its letter
        and #$0F
        sta unit
        jsr drvpfx
        jmp o3
o2      ldx #0                 ; another device: as typed
o2a     lda parm,x
        sta pfx,x
        inx
        cpx hasdev
        bcc o2a
o3      stx plen
        ldx hasdev             ; the directory part after the device
        ldy hasdev
o4      lda parm,x             ; (up to the name: the last separator)
        cmp #EOL
        beq o5
        inx
        cmp #'/'
        beq o4s
        cmp #BSLASH
        beq o4s
        cmp #'<'
        bne o4
o4s     stx dend
        jmp o4
o5      lda dend
        bne o6
        ldx plen               ; none: the main directory (CAR:> too)
        lda #'/'
        sta pfx,x
        inx
        stx plen
        jmp o9
o6      ldx plen               ; the directory part as typed
o8a     cpy dend
        bcs o8c
        lda parm,y
        sta pfx,x
        inx
        iny
        bne o8a
o8c     stx plen
o9      jsr drive
        jmp total

total   lda nmatch+1
        bne tt2
        lda nmatch
        bne tt1
        jsr PRINTF
        dta c'No match found!',EOL,0
        rts
tt1     cmp #1
        bne tt2
        jsr PRINTF
        dta c'1 match found!',EOL,0
        rts
tt2     jsr PRINTF
        dta c'%d matches found!',EOL,0
        dta a(nmatch)
        rts

* drvpfx: unit's name to pfx (A: ... O:, as drives above 9 are written;
* Dn: when a CIO device has its letter: _DRVNAME), X = its length
drvpfx  lda unit
        jsr _DRVNAME
        ldx #0
dp1     lda _DRVNM,x
        cmp #EOL
        beq dp2
        sta pfx,x
        inx
        bne dp1
dp2     rts

* probe: does the drive at pfx answer? C=1 no
probe   jsr pspec
        jsr U_GEFINA
        lda #0
        sta scan
        ldy #10                ; kd_first
        jsr jkernel
        bpl pr1
        cmp #136
        bne pr_no
pr1     ldy #7
        jsr jkernel
        clc
        rts
pr_no   sec
        rts

* pspec: FILE_P = pfx + *.* ended by EOL
pspec   ldx plen
        ldy #0
ps1     lda wild,y
        sta pfx,x
        inx
        iny
        cpy #4
        bcc ps1
        lda a_pfx
        sta FILE_P
        lda a_pfx+1
        sta FILE_P+1
        rts

* drive: search from pfx; a blank line after its matches
drive   lda nmatch
        sta mstart
        lda nmatch+1
        sta mstart+1
        jsr level
        lda nmatch
        cmp mstart
        bne dv1
        lda nmatch+1
        cmp mstart+1
        beq dv2
dv1     jsr PRINTF
        dta EOL,0
dv2     rts

* level: the directory pfx; its entries listed, then each looked at
level   lda top
        sta lbase
        lda top+1
        sta lbase+1
        lda #0
        sta cnt
        sta cnt+1
        jsr pspec
        lda #0
        sta scan
        jsr U_GEFINA           ; (a drive or path that is not there:
        ldy #10                ; nothing found, no error)
        jsr jkernel
        bpl lv1
        cmp #136
        beq lv4
        rts
lv1     clc                    ; room for one more?
        lda top
        adc #ESZ
        tax
        lda top+1
        adc #0
        cmp mtop+1
        bcc lv2
        bne lv1m
        cpx mtop
        bcc lv2
lv1m    lda #158
        jmp U_FAIL
lv2     lda top
        sta ptr
        lda top+1
        sta ptr+1
        lda dentry
        ldy #0
        sta (ptr),y
        ldx #0
lv3     lda dentry+6,x
        iny
        sta (ptr),y
        inx
        cpx #11
        bcc lv3
        clc
        lda top
        adc #ESZ
        sta top
        bcc lv3a
        inc top+1
lv3a    inc cnt
        bne lv3b
        inc cnt+1
lv3b    jsr FNEXT
        bpl lv1
lv4     jsr FCLOSE
        lda lbase
        sta cur
        lda lbase+1
        sta cur+1
lv5     lda cnt
        ora cnt+1
        bne lv6
        lda lbase
        sta top
        lda lbase+1
        sta top+1
        rts
lv6     lda cnt
        bne lv6a
        dec cnt+1
lv6a    dec cnt
        jsr entry
        clc
        lda cur
        adc #ESZ
        sta cur
        bcc lv5
        inc cur+1
        bcs lv5

* entry: the entry at cur: shown when it matches, searched when a directory
entry   ldy #0                 ; files only match
        lda (cur),y
        and #$20
        bne en4
        ldy #11
en1     lda pat-1,y
        cmp #'?'
        beq en2
        cmp (cur),y
        bne en4
en2     dey
        bne en1
        ldx plen               ; a match: pfx + NAME.EXT
        jsr addnm
        lda #EOL
        sta pfx,x
        jsr PRINTF
        dta c'%s',EOL,0
        dta a(pfx)
        inc nmatch
        bne en4
        inc nmatch+1
en4     ldy #0
        lda (cur),y
        and #$20
        beq en_ret
        ldx plen               ; a directory: one level down
        jsr addnm
        lda #'/'
        sta pfx,x
        inx
        cpx #64+4
        bcs en_ret             ; too deep for a path
        lda depth
        cmp #MAXLV
        bcs en_ret
        jsr push
        stx plen
        inc depth
        jsr level
        dec depth
        jsr pop
en_ret  rts

* addnm: the entry's name as NAME.EXT to pfx+X; X = its end
addnm   ldy #1
an1     lda (cur),y
        cmp #' '
        beq an2
        sta pfx,x
        inx
an2     iny
        cpy #9
        bcc an1
        lda (cur),y
        cmp #' '
        beq an4
        lda #'.'
        sta pfx,x
        inx
an3     lda (cur),y
        cmp #' '
        beq an3a
        sta pfx,x
        inx
an3a    iny
        cpy #12
        bcc an3
an4     rts

* memory: the lists go from the end of the program (or MEMLO) to MEMTOP
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

push    ldy sp
        lda cur
        sta lstack,y
        lda cur+1
        sta lstack+1,y
        lda lbase
        sta lstack+2,y
        lda lbase+1
        sta lstack+3,y
        lda cnt
        sta lstack+4,y
        lda cnt+1
        sta lstack+5,y
        lda plen
        sta lstack+6,y
        tya
        clc
        adc #LVSZ
        sta sp
        rts
pop     sec
        lda sp
        sbc #LVSZ
        sta sp
        tay
        lda lstack,y
        sta cur
        lda lstack+1,y
        sta cur+1
        lda lstack+2,y
        sta lbase
        lda lstack+3,y
        sta lbase+1
        lda lstack+4,y
        sta cnt
        lda lstack+5,y
        sta cnt+1
        lda lstack+6,y
        sta plen
        rts

a_pfx   dta a(pfx)
a_pend  dta a(pend)
wild    dta c'*.*',EOL
nmatch  dta a(0)
mstart  dta a(0)
top     dta a(0)
mtop    dta a(0)
lbase   dta a(0)
cnt     dta a(0)
plen    dta 0
dend    dta 0
hasdev  dta 0
hassep  dta 0
unit    dta 0
depth   dta 0
sp      dta 0
ysave   dta 0
pat     :11 dta 0
parm    :66 dta 0
pfx     :100 dta 0
lstack  :MAXLV*LVSZ dta 0
pend    equ *

        blk update address
        blk update symbols
