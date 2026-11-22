; EOS Toolkit: STAT, all that the directory says about one entry
;   STAT [+AHP] [d:][path]filename.ext
; Name, type, attributes (LSAHP: link, subdirectory, archived, hidden,
; protected), node (the first sector), device, size in bytes and in
; sectors of the disk's size, date and time; for a symbolic link also its
; target. A directory's size is the one its own header gives. Without a
; name: the usage line; no such entry: error 170.
U_GETATR smb 'U_GETATR'
U_ARGV   smb 'U_ARGV'
U_FAIL   smb 'U_FAIL'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
GETDFREE smb 'GETDFREE'
FFIRST   smb 'FFIRST'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'
DEVNAME  smb 'DEVNAME'
FILE_P   smb 'FILE_P'

device   equ $0761
mode     equ $0778
scan     equ $0779
addpos   equ $0782
bytbuf   equ $0785
dentry   equ $0789             ; status, node, size, name, date, time
path     equ $0640
ptr      equ $80
EOL      equ $9B

        blk reloc main
start   lda #$FF
        jsr U_ARGV
        lda #0                 ; no attributes given: any entry
        jsr U_GETATR
        bne s1
        jsr PRINTF
        dta b(EOL),c'Use: STAT [+AHP] fname.ext',b(EOL,0)
        rts
linkerr cmp #170               ; a link to nothing: 146
        bne fail
        lda #146
        bne fail
notfnd  lda #170
fail    jmp U_FAIL

s1      jsr GETDFREE           ; the sector size: 128, or 256 times n+1
        ldx #2
        lda #0
s2      sta secsz,x
        sta mask+1,x
        dex
        bpl s2
        lda path+1
        cmp #$80
        bne s3
        sta secsz
        lda #$7F
        sta mask
        bne s4
s3      sta mask+1             ; the size less 1: the mask of a part
        clc
        adc #1
        sta secsz+1
        rol secsz+2
        lda #$FF
        sta mask
s4      jsr FFIRST
        php
        ldx #43
s5      lda dentry,x
        sta ent,x
        dex
        bpl s5
        lda device
        sta drv
        jsr FCLOSE
        plp
        bmi notfnd

        lda drv                ; the device's name and its unit as a digit
        lsr @                  ; (10 and up as a letter)
        lsr @
        and #$3C
        tax
        ldy #0
s6      lda DEVNAME,x
        sta devnm,y
        inx
        iny
        cpy #3
        bcc s6
        lda drv
        and #$0F
        cmp #10
        bcc s7
        ora #$40
        bne s8
s7      ora #'0'
s8      sta drv

        lda ent                ; the attribute letters, - for those not set
        ldx #0
s9      ldy shifts,x
s10     asl @
        dey
        bne s10
        pha
        lda #'-'
        bcc s11
        lda letters,x
s11     sta attrs,x
        pla
        inx
        cpx #5
        bcc s9
        ldx #0                 ; the type
        lda ent
        and #$60
        beq s12
        inx
        lda ent
        and #$20
        bne s12
        inx
s12     txa
        asl @
        tax
        lda types,x
        sta typep
        lda types+1,x
        sta typep+1
        jsr PRINTF
        dta b(EOL),c'Name: [%s]',b(EOL)
        dta c'Type: %p',b(EOL)
        dta c'Attr: %s',b(EOL)
        dta c'Node: $%04x/%d on %3s%c:',b(EOL)
        dta c'Size: ',0
        dta a(ent+7,typep,attrs,ent+1,ent+1,devnm,drv)

        lda ent                ; a directory: the size from its header
        and #$20
        beq s15
        lda FILE_P
        sta ptr
        lda FILE_P+1
        sta ptr+1
        lda a_dname
        sta FILE_P
        lda a_dname+1
        sta FILE_P+1
        ldy #0                 ; the name as given, with > after it
s13     lda (ptr),y
        sta dname,y
        cmp #EOL
        beq s14
        iny
        bne s13
s14     lda #'/'
        sta dname,y
        lda #EOL
        sta dname+1,y
        lda #$14
        sta mode
        jsr FOPEN
        jsr FCLOSE
        ldx #2
s14a    lda dentry+3,x
        sta ent+3,x
        dex
        bpl s14a

s15     ldx #2                 ; the sectors: the size shifted down by
s16     lda ent+3,x            ; the sector size, one more for a part
        sta secs,x
        dex
        bpl s16
        lda #0
        sta secs+3
s17     lda secsz
        cmp #1
        beq s18
        lsr secsz+2
        ror secsz+1
        ror secsz
        lsr secs+3
        ror secs+2
        ror secs+1
        ror secs
        jmp s17
s18     ldx #2
        lda #0
        sta part
s19     lda ent+3,x
        and mask,x
        ora part
        sta part
        dex
        bpl s19
        tax
        beq s20
        inc secs
        bne s20
        inc secs+1
        bne s20
        inc secs+2
s20     jsr PRINTF
        dta c'%e bytes (%e sectors)',b(EOL)
        dta c'Date: %2b-%02b-%02b Time: %02b:%02b:%02b',b(EOL,0)
        dta a(ent+3,secs,ent+38,ent+39,ent+40,ent+41,ent+42,ent+43)

        bit ent                ; a link: where it leads
        bvc s21
        lda #4
        sta mode
        lda #$44
        sta scan
        lda a_lerr
        ldx a_lerr+1
        jsr U_SFAIL
        jsr FOPEN
        jsr U_XFAIL
        lda a_link
        sta addpos
        lda a_link+1
        sta addpos+1
        lda #64
        sta bytbuf
        lda #0
        sta bytbuf+1
        jsr FREAD
        jsr FCLOSE
        ldx bytbuf
        lda #EOL
        sta link,x
        jsr PRINTF
        dta c'Link: -> %s',b(EOL,0)
        dta a(link)
s21     rts

shifts  dta 2,1,3,1,1          ; to the bits L S A H P one after the other
letters dta c'LSAHP'
types   dta a(t_reg,t_dir,t_link)
t_reg   dta c'regular file',0
t_dir   dta c'directory',0
t_link  dta c'symbolic link',0
a_dname dta a(dname)
a_lerr  dta a(linkerr)
a_link  dta a(link)
typep   dta a(0)
attrs   dta c'-----',0
devnm   dta c'   ',0
drv     dta 0
secsz   dta 0,0,0
mask    dta 0,0,0,0
secs    dta 0,0,0,0
part    dta 0
ent     :44 dta 0
dname   :66 dta 0
link    :65 dta 0

        blk update address
        blk update symbols
