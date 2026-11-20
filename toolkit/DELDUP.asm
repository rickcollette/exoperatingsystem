; EOS Toolkit: DELDUP, files of one directory that another one has too
;   DELDUP [d:]path1> [d:]path2> [/RV]
; For each file of path2 (in its order) every file of path1 with the
; same size is compared with it byte by byte; a copy is shown as
; "** Dup: path1>NAME" (the names need not be the same), with /R it is
; deleted ("** Del: ..."). /V shows both names before each comparison.
; Directories, hidden, protected files and links are left alone, and a
; file of path1 is found once. At the end the number found. Both paths
; must end with a separator, else the usage; the same directory twice
; is refused.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_SLASH  smb 'U_SLASH'
U_EXPAND smb 'U_EXPAND'
U_FAIL   smb 'U_FAIL'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FCLOSE   smb 'FCLOSE'
FCLOSEAL smb 'FCLOSEAL'
REMOVE   smb 'REMOVE'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

FILLEN   equ $1A               ; (COMTAB+: the parameter's length)
COMFNAM  equ $21               ; (COMTAB+: the parameter)
file_id  equ $0760
device   equ $0761
name     equ $0762
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
dentry   equ $0789             ; status, node, size, name
MEMTOP   equ $02E5
MEMLO    equ $02E7
EOL      equ $9B
ESZ      equ 15                ; a list entry: status, size, name
SC_PLAIN equ $B0               ; files that are not hidden or protected

ptr      equ $80
top      equ $82
bptr     equ $84

        blk reloc main
start   jsr U_GETPAR           ; two directories, names ending in > or :
        beq usage
        ldx #0
        jsr param
        stx len1
        jsr U_GETPAR
        beq usage
        ldx #64
        jsr param
        stx len2
        lda a_opts
        ldx a_opts+1
        ldy #4
        jsr U_SLASH
        lda #0
        sta dups
        sta dups+1
        ldx #0                 ; the same directory twice?
        jsr dirent
        ldx #64
        jsr dirent
        ldx #2
s1      lda where1,x
        cmp where2,x
        bne list
        dex
        bpl s1
        jsr PRINTF
        dta b(EOL),c'Same directory given twice',b(EOL,0)
        rts
usage   jsr PRINTF
        dta b(EOL),c'DELDUP [d:]dir1> [d:]dir2> [/RV]',b(EOL,EOL)
        dta c'/R remove dup files from dir1',b(EOL)
        dta c'/V verbose operation',b(EOL,0)
        rts

list    lda a_end              ; path1's files in memory, from the
        sta top                ; program's end or MEMLO
        lda a_end+1
        sta top+1
        lda MEMLO+1
        cmp top+1
        bcc l0
        bne l0a
        lda MEMLO
        cmp top
        bcc l0
l0a     lda MEMLO
        sta top
        lda MEMLO+1
        sta top+1
l0      lda top
        sta lbase
        lda top+1
        sta lbase+1
        ldx #0
        jsr spec
        jsr plain
        jsr FFIRST
        bmi l4
l1      bit dentry             ; (not links)
        bvs l3
        clc                    ; room for one more and the end mark?
        lda top
        adc #ESZ+1
        tax
        lda top+1
        adc #0
        cmp MEMTOP+1
        bcc l2
        bne l1m
        cpx MEMTOP
        bcc l2
l1m     lda #158
        jmp U_FAIL
l2      ldy #0
        lda dentry
        sta (top),y
        ldx #3                 ; the size, then the name
l2a     iny
        lda dentry,x
        sta (top),y
        inx
        cpx #17
        bcc l2a
        clc
        lda top
        adc #ESZ
        sta top
        bcc l3
        inc top+1
l3      jsr FNEXT
        bpl l1
l4      jsr FCLOSE
        ldy #0                 ; the end of the list
        tya
        sta (top),y

        ldx #64                ; path2's files, each against the list
        jsr spec
        jsr plain
        jsr FFIRST
        bmi done
f1      lda file_id
        sta dir2
        bit dentry
        bvs f9
        ldx #22
f2      lda dentry,x
        sta ent2,x
        dex
        bpl f2
        ldx #10
f3      lda ent2+6,x
        sta name,x
        dex
        bpl f3
        lda a_p1               ; (path2 is path1+64: len2 counts from path1)
        ldx a_p1+1
        ldy len2
        jsr U_EXPAND
        lda lbase
        sta ptr
        lda lbase+1
        sta ptr+1
f4      ldy #0
        lda (ptr),y
        beq f9
        and #$10               ; (found before)
        bne f8
        ldy #3                 ; the same size?
f5      lda (ptr),y
        cmp ent2+2,y
        bne f8
        dey
        bne f5
        jsr same
f8      clc
        lda ptr
        adc #ESZ
        sta ptr
        bcc f4
        inc ptr+1
        bcs f4
f9      lda dir2
        sta file_id
        jsr plain
        lda #'?'               ; the mask back in name
        ldx #10
f9a     sta name,x
        dex
        bpl f9a
        jsr FNEXT
        bpl f1
done    jsr PRINTF
        dta b(EOL),c'%d dups detected',b(EOL,0)
        dta a(dups)
        jmp FCLOSEAL

* same: the file at ptr compared with ent2; a copy shown or deleted
same    ldy #4
s2      lda (ptr),y
        sta name-4,y
        iny
        cpy #ESZ
        bcc s2
        lda a_p1
        ldx a_p1+1
        ldy len1
        jsr U_EXPAND
        bit opt_v
        bpl s3
        jsr PRINTF
        dta c'File 1: %s',b(EOL)
        dta c'File 2: %s',b(EOL,0)
        dta a(path1,path2)
s3      lda a_p1
        ldx a_p1+1
        jsr open
        sta fid1
        lda a_p2
        ldx a_p2+1
        jsr open
        sta fid2
s4      lda fid1               ; 256 bytes of each, as long as they agree
        sta file_id
        lda a_buf1
        ldx a_buf1+1
        jsr read
        clc
        lda bytbuf
        ora bytbuf+1
        beq s6                 ; the end: the same
        lda fid2
        sta file_id
        lda a_buf2
        ldx a_buf2+1
        jsr read
        ldx #0
s5      lda buf1,x
        cmp buf2,x
        bne s5a
        inx
        beq s4                 ; (256 bytes)
        cpx bytbuf
        bne s5
        beq s4
s5a     sec
s6      php
        lda fid1
        sta file_id
        jsr FCLOSE
        lda fid2
        sta file_id
        jsr FCLOSE
        plp
        bcs s8
        inc dups
        bne s6a
        inc dups+1
s6a     bit opt_r
        bmi s7
        jsr PRINTF
        dta c'** Dup: %s',b(EOL,0)
        dta a(path1)
        jmp s7a
s7      lda a_p1
        sta FILE_P
        lda a_p1+1
        sta FILE_P+1
        jsr PRINTF
        dta c'** Del: %s',b(EOL,0)
        dta a(path1)
        jsr REMOVE
s7a     ldy #0                 ; not to be found again
        lda (ptr),y
        ora #$10
        sta (ptr),y
s8      rts

* open: the file named at AX opened for reading; A = its handle
open    sta FILE_P
        stx FILE_P+1
        lda #4
        sta mode
        jsr plain
        jsr FOPEN
        lda file_id
        rts
* read: 256 bytes (as many as there are) to AX, the buffer cleared first
read    sta addpos
        stx addpos+1
        sta bptr
        stx bptr+1
        ldy #0
        tya
r1      sta (bptr),y
        iny
        bne r1
        sty bytbuf
        iny
        sty bytbuf+1
        jmp FREAD
* plain: the search for plain files
plain   lda #SC_PLAIN
        sta scan
        lda #0
        sta attr
        rts

* param: the parameter to path1+X, X = its end; usage when it names a
* file and not a directory
param   ldy #0
pa1     lda COMTAB+COMFNAM,y
        sta path1,x
        cmp #EOL
        beq pa2
        inx
        iny
        cpy #64
        bcc pa1
pa2     txa
        pha
        jsr U_GEFINA
        pla
        tax
        lda name
        ora name+8
        cmp #' '
        bne pa_bad
        rts
pa_bad  pla                    ; (not back to the caller)
        pla
        jmp usage

* spec: path1+X (path2 for 64) with *.* after it, at FILE_P
spec    ldy #0
sp1     lda path1,x
        cmp #EOL
        beq sp2
        sta spname,y
        inx
        iny
        bne sp1
sp2     ldx #0
sp3     lda all,x
        sta spname,y
        iny
        inx
        cpx #4
        bcc sp3
        lda a_sp
        sta FILE_P
        lda a_sp+1
        sta FILE_P+1
        rts

* dirent: where the directory path1+X (path2 for 64) is: its device and
* its first sector, from its entry in the directory above (0 when none)
dirent  stx dx
        ldy #0
de1     lda path1,x
        sta spname,y
        cmp #EOL
        beq de2
        inx
        iny
        bne de1
de2     dey                    ; without the > at its end
        bmi de3
        lda #EOL
        sta spname,y
de3     lda a_sp
        sta FILE_P
        lda a_sp+1
        sta FILE_P+1
        lda #$08               ; directories only
        sta scan
        jsr FFIRST
        php
        ldx dx
        beq de4
        ldx #where2-where1
de4     lda device
        sta where1,x
        lda #0
        sta where1+1,x
        sta where1+2,x
        plp
        bmi de5
        lda dentry+1
        sta where1+1,x
        lda dentry+2
        sta where1+2,x
de5     jmp FCLOSE

a_opts  dta a(opt_r)
a_p1    dta a(path1)
a_p2    dta a(path2)
a_sp    dta a(spname)
a_buf1  dta a(buf1)
a_buf2  dta a(buf2)
a_end   dta a(pend)
opt_r   dta b(0),c'R'
opt_v   dta b(0),c'V'
all     dta c'*.*',b(EOL)
len1    dta 0
len2    dta 0
dx      dta 0
dir2    dta 0
fid1    dta 0
fid2    dta 0
dups    dta a(0)
lbase   dta a(0)
where1  dta 0,0,0
where2  dta 0,0,0
ent2    :23 dta 0
path1   :64 dta 0
path2   :80 dta 0
spname  :80 dta 0
buf1    :256 dta 0
buf2    :256 dta 0
pend

        blk update address
        blk update symbols
