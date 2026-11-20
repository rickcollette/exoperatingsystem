; EOS side of tools/interop_test.py --eos: what BW-DOS does in step 2,
; through the library. Results go to D1:TEST.LOG, then D1:DONE.LOG is made.
PRINTF   smb 'PRINTF'
FPRINTF  smb 'FPRINTF'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
FWRITE   smb 'FWRITE'
FILE_P   smb 'FILE_P'
REMOVE   smb 'REMOVE'
RENAME   smb 'RENAME'
MKDIR    smb 'MKDIR'
RMDIR    smb 'RMDIR'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
zp       equ $80               ; string pointers

        blk reloc main
start   lda s_log              ; the log
        ldx s_log+1
        jsr setspec
        lda #8
        jsr open
        lda file_id
        sta log

* compare D2:>name with D1:>DATA>name for the fixtures
        ldx #0
cmpl    stx idx
        lda d2root
        ldy d2root+1
        jsr spec1
        jsr addname
        jsr keep1
        lda d1data
        ldy d1data+1
        jsr spec1
        ldx idx
        jsr addname
        jsr compare
        ldx idx
        inx
        inx
        cpx #nfix*2
        bcc cmpl
        lda d2deep             ; D2:>SUB>DEEP>TEXT.TXT and D1:>DATA>TEXT.TXT
        ldy d2deep+1
        jsr spec1
        ldx #ntext*2
        jsr addname
        jsr keep1
        lda d1data
        ldy d1data+1
        jsr spec1
        ldx #ntext*2
        jsr addname
        jsr compare

* type D2:>MANY>F130.TXT to the log
        lda s_f130
        ldx s_f130+1
        jsr setspec
        lda #4
        jsr open
        lda file_id
        sta fin
ty1     lda fin
        sta file_id
        jsr rd
        php
        lda log
        sta file_id
        lda bytbuf
        beq ty2
        jsr wr
ty2     plp
        bpl ty1
        lda fin
        sta file_id
        jsr FCLOSE

* MD D2:>BW, copy every fixture and NEW.DAT there
        lda s_bw
        ldx s_bw+1
        jsr setspec
        jsr MKDIR
        ldx #0
cpl     stx idx
        lda d1data
        ldy d1data+1
        jsr spec1
        jsr addname
        jsr keep1
        lda d2bw
        ldy d2bw+1
        jsr spec1
        ldx idx
        jsr addname
        jsr copy
        ldx idx
        inx
        inx
        cpx #nall*2
        bcc cpl
* NEW.DAT over three more places
        ldx #0
cpn     stx idx
        lda d1data
        ldy d1data+1
        jsr spec1
        ldx #nnew*2
        jsr addname
        jsr keep1
        ldx idx
        lda newdst,x
        ldy newdst+1,x
        jsr spec1
        jsr copy
        ldx idx
        inx
        inx
        cpx #6
        bcc cpn

* DEL, REN, MD, MD, RD
        ldx #0
ops     stx idx
        lda opstr,x
        pha
        lda opstr+1,x
        tax
        pla
        jsr setspec
        ldx idx
        lda opjmp,x
        sta jop+1
        lda opjmp+1,x
        sta jop+2
jop     jsr $FFFF
        ldx idx
        inx
        inx
        cpx #10
        bcc ops

        lda log
        sta file_id
        jsr FPRINTF
        dta c'done',$9B,0
        jsr FCLOSE
        lda s_done             ; the marker
        ldx s_done+1
        jsr setspec
        lda #8
        jsr open
        jsr FCLOSE
        rts

* compare the file at spec1 (kept in spec2) with the one in spec: log a line
compare lda spec2p
        ldx spec2p+1
        jsr setspec
        lda #4
        jsr open
        lda file_id
        sta fin
        lda spec1p
        ldx spec1p+1
        jsr setspec
        lda #4
        jsr open
        lda file_id
        sta fout
        lda #0
        sta bad
cm1     lda fin
        sta file_id
        lda bufp
        ldx bufp+1
        jsr rdat
        php
        lda bytbuf
        sta cnt1
        lda bytbuf+1
        sta cnt1+1
        lda fout
        sta file_id
        lda buf2p
        ldx buf2p+1
        jsr rdat
        php
        lda bytbuf
        cmp cnt1
        bne cm_bad
        lda bytbuf+1
        cmp cnt1+1
        bne cm_bad
        ldy #0
cm2     cpy cnt1
        bne cm3
        lda cnt1+1
        beq cm4
cm3     lda buf,y
        cmp buf2,y
        bne cm_bad
        iny
        bne cm2
cm4     plp
        plp
        bpl cm1
        bmi cm_end
cm_bad  plp
        plp
        dec bad
cm_end  lda fin
        sta file_id
        jsr FCLOSE
        lda fout
        sta file_id
        jsr FCLOSE
        lda log
        sta file_id
        bit bad
        bmi cm_dif
        jsr FPRINTF
        dta c'same %s',$9B,0
        dta a(spec)
        rts
cm_dif  jsr FPRINTF
        dta c'files differ %s',$9B,0
        dta a(spec)
        rts

* copy the file at spec2 to the one at spec1
copy    lda spec2p
        ldx spec2p+1
        jsr setspec
        lda #4
        jsr open
        lda file_id
        sta fin
        lda spec1p
        ldx spec1p+1
        jsr setspec
        lda #8
        jsr open
        lda file_id
        sta fout
co1     lda fin
        sta file_id
        jsr rd
        php
        lda fout
        sta file_id
        lda bytbuf
        ora bytbuf+1
        beq co2
        jsr wr
co2     plp
        bpl co1
        lda fin
        sta file_id
        jsr FCLOSE
        lda fout
        sta file_id
        jmp FCLOSE

* rd: up to 256 bytes into buf (N=1 at the end); rdat: into the buffer at XA
rd      lda bufp
        ldx bufp+1
rdat    sta addpos
        stx addpos+1
        lda #0
        sta bytbuf
        sta memreix
        lda #1
        sta bytbuf+1
        jmp FREAD
* wr: bytbuf bytes of buf
wr      lda bufp
        sta addpos
        lda bufp+1
        sta addpos+1
        lda #0
        sta memreix
        jmp FWRITE

setspec sta FILE_P
        stx FILE_P+1
        rts
open    sta mode
        lda #0
        sta scan
        sta attr
        jmp FOPEN

* spec1: spec = the prefix at YA (keeps X); addname: + names[X];
* keep1: spec2 = spec
spec1   sta zp
        sty zp+1
        ldy #0
sp1     lda (zp),y
        cmp #$9B
        beq sp2
        sta spec,y
        iny
        bne sp1
sp2     sty slen
        rts
addname lda names,x
        sta zp
        lda names+1,x
        sta zp+1
        ldy #0
        ldx slen
an1     lda (zp),y
        sta spec,x
        inx
        iny
        cmp #$9B
        bne an1
        rts
keep1   ldx #63
kp1     lda spec,x
        sta spec2,x
        dex
        bpl kp1
        rts

nfix    equ 11                 ; EMPTY.DAT ... BIG.DAT
nnew    equ 11
ntext   equ 12
nall    equ 13
names   dta a(n0,n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12)
n0      dta c'EMPTY.DAT',$9B
n1      dta c'T127.DAT',$9B
n2      dta c'T128.DAT',$9B
n3      dta c'T129.DAT',$9B
n4      dta c'T255.DAT',$9B
n5      dta c'T256.DAT',$9B
n6      dta c'T257.DAT',$9B
n7      dta c'T511.DAT',$9B
n8      dta c'T512.DAT',$9B
n9      dta c'T513.DAT',$9B
n10     dta c'BIG.DAT',$9B
n11     dta c'NEW.DAT',$9B
n12     dta c'TEXT.TXT',$9B
d2root  dta a(p_d2)
d1data  dta a(p_data)
d2deep  dta a(p_deep)
d2bw    dta a(p_bw)
p_d2    dta c'D2:>',$9B
p_data  dta c'D1:>DATA>',$9B
p_deep  dta c'D2:>SUB>DEEP>',$9B
p_bw    dta c'D2:>BW>',$9B
newdst  dta a(p_n1,p_n2,p_n3)
p_n1    dta c'D2:>MANY>NEW.DAT',$9B
p_n2    dta c'D2:>SUB>DEEP>NEW.DAT',$9B
p_n3    dta c'D2:>ARCH.TXT',$9B
opstr   dta a(o_del,o_ren,o_md1,o_md2,o_rd)
opjmp   dta a(REMOVE,RENAME,MKDIR,MKDIR,RMDIR)
o_del   dta c'D2:>T128.DAT',$9B
o_ren   dta c'D2:>T129.DAT T129.REN',$9B
o_md1   dta c'D2:>BW>EMPTY',$9B
o_md2   dta c'D2:>BW>GONE',$9B
o_rd    dta c'D2:>BW>GONE',$9B
s_log   dta a(t_log)
s_done  dta a(t_done)
s_f130  dta a(t_f130)
s_bw    dta a(t_bw)
t_log   dta c'D1:TEST.LOG',$9B
t_done  dta c'D1:DONE.LOG',$9B
t_f130  dta c'D2:>MANY>F130.TXT',$9B
t_bw    dta c'D2:>BW',$9B
spec1p  dta a(spec)
spec2p  dta a(spec2)
bufp    dta a(buf)
buf2p   dta a(buf2)
idx     dta 0
slen    dta 0
log     dta 0
fin     dta 0
fout    dta 0
bad     dta 0
cnt1    dta a(0)
spec    :64 dta 0
spec2   :64 dta 0
buf     :256 dta 0
buf2    :256 dta 0

        blk update address
        blk update symbols
