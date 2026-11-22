; EOS CAR: DELTREE, a directory deleted with everything in it
;   DELTREE [/YV] [d:]path
; Asks first unless /Y. Each directory is shown as d:path> when it is
; entered, the one given as d:path when it goes at the end; /V shows the
; files too. With a final > only the contents go. A hidden or protected
; file is not deleted: 170 ends it there.
REMOVE   smb 'REMOVE'
RMDIR    smb 'RMDIR'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
FCLOSE   smb 'FCLOSE'
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
PUTC     smb 'PUTC'
U_GEFINA smb 'U_GEFINA'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'
_DRVNAME smb '_DRVNAME'
_DRVNM   smb '_DRVNM'

device   equ $0761
scan     equ $0779
dentry   equ $0789
MEMTOP   equ $02E5
MEMLO    equ $02E7
CIOV     equ $E456
EOL      equ $9B
BSLASH   equ $5C
ESZ      equ 12                ; a list entry: status and name
MAXLV    equ 16
LVSZ     equ 7

ptr      equ $80
cur      equ $82

        blk reloc main
start   lda #0
        sta o_y
        sta o_v
        sta plen
        sta sp
        jsr memory
p1      jsr U_GETPAR
        beq p_end
        lda COMTAB+$21
        cmp #'/'
        bne p_path
        ldx #1                 ; /Y, /V (together or apart)
p2      lda COMTAB+$21,x
        cmp #EOL
        beq p1
        cmp #'Y'
        bne p3
        sta o_y
        beq p4
p3      cmp #'V'
        bne p_bad
        sta o_v
p4      inx
        bne p2
p_bad   lda #156
        jmp U_FAIL
p_path  ldx #0                 ; the directory
p5      lda COMTAB+$21,x
        sta pth,x
        inx
        cmp #EOL
        bne p5
        dex
        stx plen
        jmp p1
p_end   lda plen
        jeq usage
        lda #0
        sta conly
        ldx plen               ; a final separator: the contents only
        lda pth-1,x
        cmp #'/'
        beq p6
        cmp #BSLASH
        bne p7
p6      dec plen
        dec conly
        lda plen
        jeq usage
p7      ldx plen
        lda #EOL
        sta pth,x
        lda a_pth              ; the drive letter shown, and where the
        sta FILE_P             ; path after the device starts
        lda a_pth+1
        sta FILE_P+1
        jsr U_GEFINA
        lda device             ; (the drive: its name shown, _DRVNAME)
        and #$0F
        sta dletter
        ldx #0
        stx devlen
p8      lda pth,x
        cmp #EOL
        beq p9
        inx
        cmp #':'
        bne p8
        stx devlen
p9      ldx plen
        lda #EOL
        sta pth,x
        lda o_y                ; sure?
        bne go
        jsr PRINTF
        dta c'Delete %s and all its contents (Y/N)? ',0
        dta a(pth)
        jsr yesno
        bcs go
        rts
usage   jsr PRINTF
        dta c'DELTREE [/YV] [d:]path',EOL,0
        rts
go      jsr level              ; the contents
        lda conly
        bne g1
        ldx plen               ; then the directory itself
        lda #0
        jsr shw
        jsr rmd
g1      rts

* shw: pth up to X as d:path, then the character A (0: none) and EOL
shw     sta sufx
        lda #EOL
        sta pth,x
        lda dletter            ; A:, or Dn: when a CIO device has the letter
        jsr _DRVNAME
        ldx #0
sh0     lda _DRVNM,x
        cmp #EOL
        beq sh0a
        stx shx
        jsr PUTC
        ldx shx
        inx
        bne sh0
sh0a    ldx devlen
sh1     lda pth,x
        cmp #EOL
        beq sh2
        jsr PUTC
        inx
        bne sh1
sh2     lda sufx
        beq sh3
        jsr PUTC
sh3     lda #EOL
        jmp PUTC

* rmd: the directory pth (plen long) removed
rmd     ldx plen
        lda #EOL
        sta pth,x
        lda a_pth
        sta FILE_P
        lda a_pth+1
        sta FILE_P+1
        jmp RMDIR

* level: everything in the directory pth deleted
level   lda top
        sta lbase
        lda top+1
        sta lbase+1
        lda #0
        sta cnt
        sta cnt+1
        ldx plen               ; pth>*.*
        lda #'/'
        sta pth,x
        inx
        ldy #0
lv0     lda wild,y
        sta pth,x
        inx
        iny
        cpy #4
        bcc lv0
        lda a_pth
        sta FILE_P
        lda a_pth+1
        sta FILE_P+1
        lda #0                 ; every entry
        sta scan
        jsr FFIRST
        bmi lv4
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

* entry: the entry at cur deleted (a directory: its contents first)
entry   ldx plen               ; pth>NAME.EXT
        lda #'/'
        sta pth,x
        inx
        jsr addnm
        lda #EOL
        sta pth,x
        cpx #64
        bcc en0
        lda #182
        jmp U_FAIL
en0     ldy #0
        lda (cur),y
        and #$20
        bne en_dir
        lda o_v                ; a file
        beq en1
        lda #0
        jsr shw
en1     lda a_pth
        sta FILE_P
        lda a_pth+1
        sta FILE_P+1
        lda #$20               ; not a hidden one (it stays: 170)
        sta scan
        jmp REMOVE
en_dir  lda sp                 ; a directory
        cmp #MAXLV*LVSZ
        bcc en2
        lda #182
        jmp U_FAIL
en2     jsr push
        stx plen
        lda #'/'               ; shown as it is entered
        jsr shw
        jsr level
        jsr rmd
        jmp pop

* addnm: the entry's name as NAME.EXT to pth+X; X = its end
addnm   ldy #1
an1     lda (cur),y
        cmp #' '
        beq an2
        sta pth,x
        inx
an2     iny
        cpy #9
        bcc an1
        lda (cur),y
        cmp #' '
        beq an4
        lda #'.'
        sta pth,x
        inx
an3     lda (cur),y
        cmp #' '
        beq an3a
        sta pth,x
        inx
an3a    iny
        cpy #12
        bcc an3
an4     rts

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

* push, pop: the level's place in its list, kept while a directory below
* is deleted (push keeps X)
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

a_pth   dta a(pth)
a_pend  dta a(pend)
a_inbuf dta a(inbuf)
wild    dta c'*.*',EOL
o_y     dta 0
o_v     dta 0
conly   dta 0
dletter dta 0
shx     dta 0
devlen  dta 0
sufx    dta 0
top     dta a(0)
mtop    dta a(0)
lbase   dta a(0)
cnt     dta a(0)
plen    dta 0
sp      dta 0
pth     :100 dta 0
inbuf   :40 dta 0
lstack  :MAXLV*LVSZ dta 0
pend    equ *

        blk update address
        blk update symbols
