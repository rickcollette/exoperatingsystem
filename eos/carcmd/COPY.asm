; EOS CAR: COPY, files from one place to another
;   COPY [/BCDIKMNQRSV] [+|-][A|H|P] [source] [destination][/A]
; The command processor's COPY runs this with the parameters in LBUF.
; Source: a file specification with wildcards (default *.* in the current
; directory); empty places can be left with commas (COPY,,C:).
; Destination: a directory and an optional name pattern; '?' and '*' keep
; the source name's characters (as RENAME). A character device (CON: NUL:
; PRN:) as the source gives one file; as the destination it takes them all.
; Date and time go with the copy unless /D.
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FFIRST   smb 'FFIRST'
FNEXT    smb 'FNEXT'
U_GEFINA smb 'U_GEFINA'
U_FAIL   smb 'U_FAIL'
CHMOD    smb 'CHMOD'
REMOVE   smb 'REMOVE'
MKDIR    smb 'MKDIR'
RMDIR    smb 'RMDIR'
PRINTF   smb 'PRINTF'
PUTC     smb 'PUTC'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

jkernel  equ $0703
file_id  equ $0760
device   equ $0761
name     equ $0762
mode     equ $0778
scan     equ $0779
attr     equ $077A
date     equ $077B
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
dentry   equ $0789
MEMTOP   equ $02E5
MEMLO    equ $02E7
SDMCTL   equ $022F
CIOV     equ $E456
EOL      equ $9B
BSLASH   equ $5C
MAXLV    equ 16                ; directory levels (the path limit is lower)
LVSZ     equ 9                 ; bytes kept per level

ptr      equ $80               ; zero page work pointers
ptr2     equ $82
cur      equ $84               ; the list entry in hand

        blk reloc main
start   lda #$20               ; -H unless attributes are given
        sta sscan
        lda #0
        sta anyarg
        ldx #0
st0     sta opts,x
        inx
        cpx #NOPT
        bcc st0
        sta given
        sta nf
        sta depth
        sta nfiles
        sta nfiles+1
        sta ndirs
        sta ndirs+1
        sta f0
        sta f1
        lda SDMCTL
        sta dmasave

* ---- the parameters, from LBUF (U_GETPAR loses empty places) ----
        ldy #0
pa0     lda COMTAB+$3F,y       ; blanks before the command word
        cmp #' '
        bne pa1
        iny
        bne pa0
pa1     lda COMTAB+$3F,y       ; the command word itself
        cmp #EOL
        jeq pa_end
        cmp #' '
        beq pa2
        cmp #','
        beq pa2
        iny
        bne pa1
pa2     lda #1                 ; a token was last (the command word)
        sta lasttok
pa3     lda COMTAB+$3F,y
        cmp #EOL
        jeq pa_end
        cmp #' '
        bne pa4
        iny
        bne pa3
pa4     sta anyarg             ; something follows the command word
        cmp #','
        bne pa6
        iny
        lda lasttok            ; a comma after a comma: an empty place
        bne pa5
        lda #0
        sta tok
        sty ysave
        jsr field
        ldy ysave
pa5     lda #0
        sta lasttok
        jmp pa3
pa6     ldx #0                 ; a token, in capitals
pa7     lda COMTAB+$3F,y
        cmp #EOL
        beq pa8
        cmp #' '
        beq pa8
        cmp #','
        beq pa8
        cmp #'a'
        bcc pa7a
        cmp #'z'+1
        bcs pa7a
        and #$DF
pa7a    sta tok,x
        iny
        inx
        cpx #79
        bcc pa7
pa8     lda #0
        sta tok,x
        sty ysave
        lda #1
        sta lasttok
        jsr token
        ldy ysave
        jmp pa3

* token: a switch, attributes, or a place (that may end with /switches)
token   lda tok
        cmp #'/'
        bne tk1
        ldx #1
        jmp sw
tk1     cmp #'+'
        beq tk_at
        cmp #'-'
        beq tk_at
        ldx #0                 ; a place: up to a '/'
tk2     lda tok,x
        beq field
        cmp #'/'
        beq tk3
        inx
        bne tk2
tk3     lda #0
        sta tok,x
        inx
        stx xsave
        jsr field
        ldx xsave
        jmp sw
tk_at   sta sign               ; +/- attributes, as DIR takes them
        lda given
        bne ta0
        lda #0
        sta sscan
        lda #1
        sta given
ta0     ldx #1
ta1     lda tok,x
        beq ta_end
        ldy #3
ta2     cmp atrch,y
        beq ta3
        dey
        bpl ta2
        lda #156
        jmp U_FAIL
ta3     lda atrbit,y
        ldy sign
        cpy #'-'
        bne ta4
        asl @
        asl @
        asl @
        asl @
ta4     ora sscan
        sta sscan
        inx
        bne ta1
ta_end  rts

* sw: the switch letters at tok+X
sw      lda tok,x
        beq sw_end
        ldy #NOPT-1
sw1     cmp optch,y
        beq sw2
        dey
        bpl sw1
        lda #156               ; not a switch of COPY
        jmp U_FAIL
sw2     lda #$FF
        sta opts,y
        inx
        bne sw
sw_end  rts

* field: tok is the next place (source, destination)
field   lda nf
        cmp #2
        bcs fd_ret
        inc nf
        asl @
        tay
        lda fdtab,y
        sta ptr
        lda fdtab+1,y
        sta ptr+1
        ldy #0
fd1     lda tok,y
        sta (ptr),y
        beq fd_ret
        iny
        cpy #79
        bcc fd1
        lda #0
        sta (ptr),y
fd_ret  rts

* ---- what the parameters ask for ----
pa_end  lda anyarg             ; nothing at all: how to use it
        bne pa_e1
        jsr PRINTF
        dta c'COPY [/BCDIKLMNQRSV] [+AHP] src [dst[/A]]',EOL,0
        rts
pa_e1   lda o_a                ; /A anywhere: append
        sta app
        lda o_m                ; /B, /K and /M are on the source files
        ora o_k
        ora o_b
        sta srcatr
        jsr memory
* the source: the directory part and the name (*.* when none)
        lda a_f0
        ldx a_f0+1
        jsr split
        sta slen0
        lda f0,x
        bne pe1
        ldy #0                 ; no name: *.*
pe0     lda wild,y
        sta f0,x
        inx
        iny
        cpy #4
        bcc pe0
pe1     ldy #0                 ; snm = the name as typed
pe2     lda f0,x
        sta snm,y
        beq pe3
        inx
        iny
        bne pe2
pe3     ldx slen0              ; srcpath = the directory part
        stx slen
        lda #EOL
        sta srcpath,x
        dex
        bmi pe5
pe4     lda f0,x
        sta srcpath,x
        dex
        bpl pe4
* the destination: its directory part, and the name as a pattern
pe5     lda a_f1
        ldx a_f1+1
        jsr split
        sta dlen
        sta dlen0
        tax
        lda #EOL
        sta dstpath,x
        dex
        bmi pe7
pe6     lda f1,x
        sta dstpath,x
        dex
        bpl pe6
pe7     jsr fp_f1              ; dpat from U_GEFINA's name
        jsr U_GEFINA
        ldx #10
        lda #' '
pe8     cmp name,x
        bne pe9
        dex
        bpl pe8
        lda #0                 ; no name: every character kept
        sta dnamed
        ldx #10
        lda #'?'
pe8a    sta dpat,x
        dex
        bpl pe8a
        bmi pe10
pe9     lda #$FF
        sta dnamed
        ldx #10
pe9a    lda name,x
        sta dpat,x
        dex
        bpl pe9a
pe10    lda o_m                ; /M: the destination has no name
        beq pe11
        lda dnamed
        beq pe11
        jsr PRINTF
        dta c'The destination must be a directory',EOL,0
        lda #156
        jmp U_FAIL
* is the destination a character device?
pe11    lda a_dstpath
        ldx a_dstpath+1
        jsr isdev
        sta dchar
* and the source?
        lda a_f0
        ldx a_f0+1
        jsr isdev
        sta schar
        beq dsksrc
        jmp chrsrc

* ---- files from a file device ----
dsksrc  lda o_s
        beq ds1
        lda #0                 ; /S: the screen off while copying
        sta SDMCTL
ds1     jsr level
        lda dmasave
        sta SDMCTL
        lda o_v                ; /V: what was copied
        beq ds2
        lda ndirs
        ora ndirs+1
        beq ds1b
        jsr PRINTF
        dta c'%d director',0
        dta a(ndirs)
        lda ndirs+1
        bne ds1a
        lda ndirs
        cmp #1
        bne ds1a
        jsr PRINTF
        dta c'y and ',0
        jmp ds1b
ds1a    jsr PRINTF
        dta c'ies and ',0
ds1b    jsr PRINTF
        dta c'%d file',0
        dta a(nfiles)
        lda nfiles+1
        bne ds1c
        lda nfiles
        cmp #1
        beq ds1d
ds1c    lda #'s'
        jsr PUTC
ds1d    jsr PRINTF
        dta c' copied',EOL,0
ds2     rts

* level: copy what matches in srcpath to dstpath (recursively with /R);
* depth 0 uses the name and pattern given, deeper levels everything
level   lda top                ; the entries go to the list at top
        sta lbase
        lda top+1
        sta lbase+1
        lda #0
        sta cnt
        sta cnt+1
        jsr samedir
        ldx slen               ; the specification: srcpath + name
        dex
        bmi lv0a
lv0     lda srcpath,x
        sta spec,x
        dex
        bpl lv0
lv0a    ldx slen
        ldy #0
lv1     lda depth
        bne lv1a
        lda snm,y
        jmp lv1b
lv1a    lda wild,y
lv1b    sta spec,x
        beq lv2
        inx
        iny
        cpx #80
        bcc lv1
        lda #182
        jmp U_FAIL
lv2     lda #EOL
        sta spec,x
        lda a_spec
        sta FILE_P
        lda a_spec+1
        sta FILE_P+1
        lda sscan              ; files only, unless /R
        ldx o_r
        bne lv3
        ora #$80
lv3     sta scan
        jsr FFIRST
        bmi lv6
lv4     lda top                ; room for one more entry?
        clc
        adc #23+1
        tax
        lda top+1
        adc #1                 ; (and 256 bytes of buffer)
        cmp mtop+1
        bcc lv4a
        bne lv4m
        cpx mtop
        bcc lv4a
lv4m    lda #158
        jmp U_FAIL
lv4a    lda top
        sta ptr
        lda top+1
        sta ptr+1
        ldy #22
lv5     lda dentry,y
        sta (ptr),y
        dey
        bpl lv5
        jsr top23
        inc cnt
        bne lv5a
        inc cnt+1
lv5a    jsr FNEXT
        bpl lv4
lv6     jsr FCLOSE
        lda depth              ; nothing at all: the source as given is
        bne lv7                ; opened, so that 170 names it
        lda cnt
        ora cnt+1
        bne lv7
        ldx #0
lv6a    lda f0,x
        sta sname,x
        beq lv6b
        inx
        bne lv6a
lv6b    lda #EOL
        sta sname,x
        lda a_sname
        ldx a_sname+1
        sta FILE_P
        stx FILE_P+1
        lda #4
        sta mode
        lda sscan              ; (files with the attributes asked for)
        ora #$80
        sta scan
        jsr FOPEN
        lda #170               ; (not reached when nothing is there)
        jmp U_FAIL
lv7     lda lbase              ; then each entry
        sta cur
        lda lbase+1
        sta cur+1
lv8     lda cnt
        ora cnt+1
        bne lv9
        lda lbase              ; done: the list goes
        sta top
        lda lbase+1
        sta top+1
        rts
lv9     lda cnt
        bne lv9a
        dec cnt+1
lv9a    dec cnt
        jsr entry
        clc
        lda cur
        adc #23
        sta cur
        bcc lv8
        inc cur+1
        bcs lv8

top23   clc
        lda top
        adc #23
        sta top
        bcc t23
        inc top+1
t23     rts

* entry: the list entry at cur (a file, or a directory with /R)
entry   jsr names              ; sname, dname, newnm
        ldy #0
        lda (cur),y
        and #$20
        bne en_dir
        jmp file
en_dir  lda o_n                ; /N: an existing directory is left
        beq ed1
        lda a_dname
        ldx a_dname+1
        jsr exists
        bcc ed1
        rts
ed1     lda o_q
        bne ed2
        jsr PRINTF
        dta c'%s>',EOL,0
        dta a(sname)
ed2     lda a_dname            ; the directory is made (or is there)
        sta FILE_P
        lda a_dname+1
        sta FILE_P+1
        jsr U_GEFINA
        ldy #14                ; kd_credir
        jsr jkernel
        bpl ed3
        cmp #151
        beq ed3
        jmp U_FAIL
ed3     jsr push               ; one level down
        ldx slen
        ldy #6
        jsr addnm              ; srcpath + NAME>
        stx slen
        ldx dlen
        jsr addnew             ; dstpath + NEW>
        stx dlen
        inc depth
        jsr level
        dec depth
        jsr pop
        inc ndirs
        bne ed4
        inc ndirs+1
ed4     lda o_m                ; /M: the emptied directory goes too
        beq ed5
        jsr names
        lda a_sname
        sta FILE_P
        lda a_sname+1
        sta FILE_P+1
        jsr U_GEFINA
        ldy #15                ; kd_deldir
        jsr jkernel
ed5     rts

* addnm: the name at (cur)+Y as NAME.EXT> to srcpath+X; X = the new end
addnm   lda a_srcpath
        sta ptr2
        lda a_srcpath+1
        sta ptr2+1
        lda cur
        sta ptr
        lda cur+1
        sta ptr+1
        jsr expand
        jmp addsep
* addnew: newnm as NAME.EXT> to dstpath+X
addnew  lda a_dstpath
        sta ptr2
        lda a_dstpath+1
        sta ptr2+1
        lda a_newnmm6
        sta ptr
        lda a_newnmm6+1
        sta ptr+1
        ldy #6
        jsr expand
addsep  txa
        tay
        lda #'>'
        sta (ptr2),y
        iny
        lda #EOL
        sta (ptr2),y
        cpy #64
        bcs as_long
        tya
        tax
        rts
as_long lda #182
        jmp U_FAIL

* expand: the 8+3 name at (ptr)+6 as NAME.EXT to (ptr2)+X, EOL after it;
* X = the EOL's place
expand  ldy #6
ex1     lda (ptr),y
        cmp #' '
        beq ex2
        jsr exput
ex2     iny
        cpy #6+8
        bcc ex1
        ldy #6+8
        lda (ptr),y
        cmp #' '
        beq ex4
        lda #'.'
        jsr exput
ex3     lda (ptr),y
        cmp #' '
        beq ex3a
        jsr exput
ex3a    iny
        cpy #6+11
        bcc ex3
ex4     sty ysave
        txa
        tay
        lda #EOL
        sta (ptr2),y
        ldy ysave
        rts
exput   sty ysave
        pha
        txa
        tay
        pla
        sta (ptr2),y
        inx
        ldy ysave
        rts

* names: for the entry at cur, sname = srcpath + NAME.EXT, newnm = the
* name the pattern makes, dname = dstpath + NEW.EXT
names   ldy #6+10              ; newnm: '?' keeps the source's character
nm1     lda dpat-6,y
        ldx depth
        beq nm1a
        lda #'?'
nm1a    cmp #'?'
        bne nm2
        lda (cur),y
nm2     sta newnm-6,y
        dey
        cpy #6
        bcs nm1
        ldx slen               ; sname
        dex
        bmi nm4
nm3     lda srcpath,x
        sta sname,x
        dex
        bpl nm3
nm4     lda a_sname
        sta ptr2
        lda a_sname+1
        sta ptr2+1
        lda cur
        sta ptr
        lda cur+1
        sta ptr+1
        ldx slen
        jsr expand
        ldx dlen               ; dname
        dex
        bmi nm6
nm5     lda dstpath,x
        sta dname,x
        dex
        bpl nm5
nm6     lda a_dname
        sta ptr2
        lda a_dname+1
        sta ptr2+1
        lda a_newnmm6
        sta ptr
        lda a_newnmm6+1
        sta ptr+1
        ldx dlen
        jmp expand

* file: copy the file at cur
file    lda dchar              ; to a device: the name as given
        beq fi0
        ldx #0
fi_d    lda f1,x
        sta dname,x
        beq fi_d1
        inx
        bne fi_d
fi_d1   lda #EOL
        sta dname,x
        jmp fi1
fi0     lda #0                 ; onto itself? (fails once it is shown)
        sta self
        lda same
        beq fi1
        ldy #6+10
fi0a    lda (cur),y
        cmp newnm-6,y
        bne fi1
        dey
        cpy #6
        bcs fi0a
        dec self
fi1     lda dchar
        bne fi3
        lda o_n                ; /N: an existing file is left; /I asks
        ora o_i
        beq fi3
        lda a_dname
        ldx a_dname+1
        jsr exists
        bcc fi3
        lda o_n
        beq fi2
        rts
fi2     jsr PRINTF
        dta c'Overwrite %s (Y/N)? ',0
        dta a(dname)
        jsr yesno
        bcs fi3
        rts
fi3     lda o_c                ; /C: each file confirmed
        beq fi4
        jsr PRINTF
        dta c'Copy %s (Y/N)? ',0
        dta a(sname)
        jsr yesno
        bcs fi4
        rts
fi4     lda o_q
        bne fi5
        jsr PRINTF
        dta c'%s',EOL,0
        dta a(sname)
fi5     lda self               ; the source is open: 129, as on SDX
        beq fi5a
        lda #129
        jmp U_FAIL
fi5a    lda a_sname
        ldx a_sname+1
        jsr opensrc
        lda a_dname
        ldx a_dname+1
        jsr opendst
        jsr pump
        lda o_d                ; the date and time of the source
        bne fi7
        ldy #17
        lda (cur),y
        iny
        ora (cur),y
        iny
        ora (cur),y
        beq fi7                ; none: the current ones
        ldx #5
fi6     lda date,x
        sta dtsave,x
        dex
        bpl fi6
        ldy #17+5
        ldx #5
fi6a    lda (cur),y
        sta date,x
        dey
        dex
        bpl fi6a
        lda #$FF
        sta dtset
fi7     lda hout
        sta file_id
        jsr FCLOSE
        lda dtset
        beq fi8
        ldx #5
fi7a    lda dtsave,x
        sta date,x
        dex
        bpl fi7a
        lda #0
        sta dtset
fi8     lda hin
        sta file_id
        jsr FCLOSE
        inc nfiles
        bne fi9
        inc nfiles+1
fi9     lda srcatr
        beq fi_ret
        lda a_sname            ; the source after the copy
        sta FILE_P
        lda a_sname+1
        sta FILE_P+1
        lda o_m
        bne fi10
        lda #$04               ; /B, /K: archived
        sta attr
        lda #$80
        sta scan
        jmp CHMOD
fi10    lda #$80               ; /M: deleted
        sta scan
        jmp REMOVE
fi_ret  rts

* ---- one file from a character device ----
chrsrc  lda #$FF               ; only /A /C /I /N /Q mean something here
        sta o_q
        lda o_n
        bne cs0
        lda #$FF               ; /I unless /N
        sta o_i
cs0     ldx #0                 ; the destination as given
cs1     lda f1,x
        sta dname,x
        beq cs2
        inx
        bne cs1
cs2     lda #EOL
        sta dname,x
        lda dchar
        bne cs5
        lda dnamed             ; a file needs a name without wildcards
        bne cs3
        lda #165
        jmp U_FAIL
cs3     ldx #10
        lda #'?'
cs3a    cmp dpat,x
        beq cs3b
        dex
        bpl cs3a
        bmi cs4
cs3b    lda #163
        jmp U_FAIL
cs4     lda a_dname
        ldx a_dname+1
        jsr exists
        bcc cs5
        lda o_n
        beq cs4a
        rts
cs4a    jsr PRINTF
        dta c'Overwrite %s (Y/N)? ',0
        dta a(dname)
        jsr yesno
        bcs cs5
        rts
cs5     ldx #0                 ; the source as given
cs5a    lda f0,x
        sta sname,x
        beq cs5b
        inx
        bne cs5a
cs5b    lda #EOL
        sta sname,x
        lda a_sname
        ldx a_sname+1
        jsr opensrc
        lda a_dname
        ldx a_dname+1
        jsr opendst
        jsr pump
        lda hout
        sta file_id
        jsr FCLOSE
        lda hin
        sta file_id
        jmp FCLOSE

* opensrc: AX for reading (any attributes), hin
opensrc sta FILE_P
        stx FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta hin
        rts
* opendst: AX written anew (appended with /A), hout
opendst sta FILE_P
        stx FILE_P+1
        lda dchar              ; a protected or hidden file is not
        bne od0                ; replaced: 151
        jsr U_GEFINA
        lda #0
        sta scan
        ldy #10                ; kd_first
        jsr jkernel
        sta ysave
        bpl od_c
        cmp #136
        bne od0
od_c    lda dentry
        sta xsave
        ldy #7
        jsr jkernel
        lda ysave
        bmi od0
        lda xsave
        and #$03
        beq od0
        lda #151
        jmp U_FAIL
od0     lda #8
        ldx app
        beq od1
        lda #9
od1     sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta hout
        rts

* pump: hin to hout through the buffer at top
pump    lda hin
        sta file_id
        jsr setbuf
        jsr FREAD
        stx eof
        lda bytbuf
        sta n
        lda bytbuf+1
        sta n+1
        ora n
        beq pu1
        lda hout
        sta file_id
        jsr setbuf
        lda n
        sta bytbuf
        lda n+1
        sta bytbuf+1
        jsr FWRITE
pu1     lda eof
        beq pump
        rts
setbuf  lda top
        sta addpos
        lda top+1
        sta addpos+1
        sec
        lda mtop
        sbc top
        sta bytbuf
        lda mtop+1
        sbc top+1
        sta bytbuf+1
        lda #0
        sta memreix
        rts

* ---- helpers ----
* memory: the list and the buffer go from the end of the program (or MEMLO,
* when higher) to MEMTOP
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

* split: the specification at AX; A = X = the length of its directory part
* (up to the last : > < or backslash; a final . or .. belongs to it)
split   sta ptr
        stx ptr+1
        ldy #0
        sty xsave
sp1     lda (ptr),y
        beq sp3
        iny
        cmp #':'
        beq sp2
        cmp #'>'
        beq sp2
        cmp #'<'
        beq sp2
        cmp #BSLASH
        bne sp1
sp2     sty xsave
        jmp sp1
sp3     ldy xsave              ; . and .. are directories
        lda (ptr),y
        cmp #'.'
        bne sp5
        iny
        lda (ptr),y
        beq sp4
        cmp #'.'
        bne sp5
        iny
        lda (ptr),y
        bne sp5
sp4     lda #'>'               ; X..: X..> then
        sta (ptr),y
        iny
        lda #0
        sta (ptr),y
        sty xsave
sp5     lda xsave
        tax
        rts

* isdev: the specification at AX: A = $FF for a character device (not
* DSK: or CAR:), 0 otherwise
isdev   sta ptr
        stx ptr+1
        ldy #0                 ; EOL ended copy of it
id1     lda (ptr),y
        beq id2
        cmp #EOL
        beq id2
        sta spec,y
        iny
        bne id1
id2     lda #EOL
        sta spec,y
        lda a_spec
        sta FILE_P
        lda a_spec+1
        sta FILE_P+1
        jsr U_GEFINA
        lda device
        and #$F0
        beq id3                ; DSK:
        cmp #$20
        bne id_chr             ; not CAR:
id3     lda #0
        rts
id_chr  lda #$FF
        rts

* fp_f1: FILE_P = f1 ended by EOL (in spec)
fp_f1   ldx #0
ff1     lda f1,x
        beq ff2
        sta spec,x
        inx
        bne ff1
ff2     lda #EOL
        sta spec,x
        lda a_spec
        sta FILE_P
        lda a_spec+1
        sta FILE_P+1
        rts

* exists: is there an entry named AX? C=1 yes
exists  sta FILE_P
        stx FILE_P+1
        jsr U_GEFINA
        lda #0
        sta scan
        ldy #10                ; kd_first
        jsr jkernel
        sta ysave
        bpl ex_c
        cmp #136
        bne ex_no
ex_c    ldy #7
        jsr jkernel
        lda ysave
        bmi ex_no
        sec
        rts
ex_no   clc
        rts

* samedir: same = $FF when srcpath and dstpath are one directory
samedir lda #0
        sta same
        lda dchar
        bne sd_ret
        lda a_srcpath
        ldx a_srcpath+1
        jsr dirhdr
        bcs sd_ret
        ldx #23
sd1     lda hdr,x
        sta hdr2,x
        dex
        bpl sd1
        lda a_dstpath
        ldx a_dstpath+1
        jsr dirhdr
        bcs sd_ret
        ldx #23
sd2     lda hdr,x
        cmp hdr2,x
        bne sd_ret
        dex
        bpl sd2
        dec same
sd_ret  rts
* dirhdr: the header of the directory at AX to hdr (+23: the drive); C=1
* when it cannot be read
dirhdr  sta FILE_P
        stx FILE_P+1
        jsr U_GEFINA
        lda #$14
        sta mode
        lda #0
        sta scan
        ldy #9                 ; kd_open
        jsr jkernel
        bmi dh_no
        ldx #22
dh1     lda dentry,x
        sta hdr,x
        dex
        bpl dh1
        lda device
        sta hdr+23
        ldy #7
        jsr jkernel
        clc
        rts
dh_no   sec
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

* push, pop: the level's variables kept while a directory below is copied
push    lda cur
        sta curv
        lda cur+1
        sta curv+1
        ldy sp
        ldx #0
pu2     lda lvars,x
        sta lstack,y
        iny
        inx
        cpx #LVSZ
        bcc pu2
        sty sp
        rts
pop     ldy sp
        ldx #LVSZ-1
po1     dey
        lda lstack,y
        sta lvars,x
        dex
        bpl po1
        sty sp
        lda curv
        sta cur
        lda curv+1
        sta cur+1
        rts

* ---- data ----
optch   dta c'ABCDIKLMNQRSV'
NOPT    equ 13
opts
o_a     dta 0
o_b     dta 0
o_c     dta 0
o_d     dta 0
o_i     dta 0
o_k     dta 0
o_l     dta 0                  ; (accepted, does nothing here)
o_m     dta 0
o_n     dta 0
o_q     dta 0
o_r     dta 0
o_s     dta 0
o_v     dta 0
atrch   dta c'PHAS'
atrbit  dta b($01,$02,$04,$08)
fdtab   dta a(f0,f1)
wild    dta c'*.*',0

a_f0      dta a(f0)
a_f1      dta a(f1)
a_dstpath dta a(dstpath)
a_spec    dta a(spec)
a_dname   dta a(dname)
a_sname   dta a(sname)
a_srcpath dta a(srcpath)
a_newnmm6 dta a(newnm-6)
a_pend    dta a(pend)
a_inbuf   dta a(inbuf)

lvars                          ; kept per level (LVSZ bytes)
lbase   dta a(0)
cnt     dta a(0)
curv    dta a(0)
slen    dta 0
dlen    dta 0
same    dta 0

sscan   dta 0
anyarg  dta 0
given   dta 0
sign    dta 0
nf      dta 0
lasttok dta 0
ysave   dta 0
xsave   dta 0
app     dta 0
srcatr  dta 0
dnamed  dta 0
dchar   dta 0
schar   dta 0
slen0   dta 0
dlen0   dta 0
depth   dta 0
sp      dta 0
hin     dta 0
hout    dta 0
eof     dta 0
self    dta 0
dtset   dta 0
dmasave dta 0
n       dta a(0)
top     dta a(0)
mtop    dta a(0)
nfiles  dta a(0)
ndirs   dta a(0)
dtsave  :6 dta 0
dpat    :11 dta 0
newnm   :11 dta 0
hdr     :24 dta 0
hdr2    :24 dta 0
tok     :80 dta 0
f0      :84 dta 0
f1      :84 dta 0
snm     :16 dta 0
srcpath :80 dta 0
dstpath :80 dta 0
sname   :96 dta 0
dname   :96 dta 0
spec    :96 dta 0
inbuf   :40 dta 0
lstack  :MAXLV*LVSZ dta 0
pend    equ *

        blk update address
        blk update symbols
