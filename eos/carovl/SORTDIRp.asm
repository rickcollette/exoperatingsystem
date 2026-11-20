; EOS CAR:SORTDIR.OVL, the part in the RAM under the cartridge (SORTDIR.asm
; puts it there). Two entry points, called with that RAM switched in
; (jhwctrl 1); both switch the library back in (jhwctrl 0) before they
; return:
;   $A000 do_sort (JMP): on the stack, pushed in this order, the data
;         segment (0), the buffer's end (MSB first), its start (MSB first),
;         the mode ($0x name, $4x size, $8x time, $Cx extension; $x1 the
;         other way round, $x2 no sorting); A = the buffer's memory index.
;         Returns to whoever called the code that pushed these.
;   $A003 move_entry (JSR): on the stack the entry's address (segment, MSB,
;         LSB pushed in this order), A = the memory index; C=0 the entry to
;         (addpos), C=1 dentry ($0789) to the entry. 23 bytes.
; Directories come first, free entries last, whatever the mode. $80-$9D are
; kept.
jhwctrl  equ $070F
V_setme  equ $07F1
V_popme  equ $07F4
dentry   equ $0789
dst      equ $0782              ; addpos (Sparta Commander sets it)
ENT      equ 23
ZN       equ $1E               ; $80-$9D

pa       equ $80               ; the entries compared / swapped
pb       equ $82
pi       equ $84               ; entry i
pj       equ $86               ; entry j
gp       equ $88               ; the gap in bytes
cnt      equ $8A               ; entries left in this pass
ka       equ $8C               ; the keys' classes
kb       equ $8D

        opt h-
        org $A000
        jmp do_sort
        jmp move_entry

do_sort sta mx
        pla
        sta mode
        pla
        sta bot
        pla
        sta bot+1
        pla
        sta top
        pla
        sta top+1
        pla                    ; (the segment)
        jsr zsave
        lda mode
        and #3
        cmp #2
        beq ds_end
        lda mx
        jsr V_setme
        jsr count
        ldx #0                 ; the gaps, largest first: 1093 364 121 40 13 4 1
ds1     lda gaps+1,x
        cmp n+1
        bcc ds2
        bne ds3
        lda gaps,x
        cmp n
        bcs ds3
ds2     stx gx
        jsr pass
        ldx gx
ds3     inx
        inx
        cpx #14
        bcc ds1
        jsr V_popme
ds_end  jsr zrest
        ldx #0
        jmp jhwctrl            ; (and its RTS returns)

* count: n = (top - bot) / 23
count   lda #0
        sta n
        sta n+1
        lda top
        sec
        sbc bot
        sta pa
        lda top+1
        sbc bot+1
        sta pa+1
cn1     lda pa
        sec
        sbc #ENT
        tax
        lda pa+1
        sbc #0
        bcc cn_x
        stx pa
        sta pa+1
        inc n
        bne cn1
        inc n+1
        bne cn1
cn_x    rts

* pass: a Shell sort pass with the gap gaps[gx] (entries), gp its bytes
pass    lda gapb,x
        sta gp
        lda gapb+1,x
        sta gp+1
        lda n                  ; entries g .. n-1
        sec
        sbc gaps,x
        sta cnt
        lda n+1
        sbc gaps+1,x
        sta cnt+1
        lda bot                ; pi = bot + gp
        clc
        adc gp
        sta pi
        lda bot+1
        adc gp+1
        sta pi+1
ps1     lda pi
        sta pj
        lda pi+1
        sta pj+1
ps2     lda pj                 ; pb = pj, pa = pj - gp (j >= g)
        sta pb
        sec
        sbc gp
        sta pa
        lda pj+1
        sta pb+1
        sbc gp+1
        sta pa+1
        lda pa                 ; below the buffer: done
        cmp bot
        lda pa+1
        sbc bot+1
        bcc ps3
        jsr ecmp               ; in order: done
        bcc ps3
        jsr swap
        lda pa
        sta pj
        lda pa+1
        sta pj+1
        jmp ps2
ps3     lda pi
        clc
        adc #ENT
        sta pi
        bcc ps4
        inc pi+1
ps4     lda cnt
        bne ps5
        dec cnt+1
ps5     dec cnt
        lda cnt
        ora cnt+1
        bne ps1
        rts

* swap: the 23 bytes at pa and pb
swap    ldy #ENT-1
sw1     lda (pa),y
        tax
        lda (pb),y
        sta (pa),y
        txa
        sta (pb),y
        dey
        bpl sw1
        rts

* ecmp: C=1 when the entry at pa must come after the one at pb
ecmp    ldy #0
        lda (pa),y
        jsr class
        sta ka
        lda (pb),y
        jsr class
        sta kb
        lda kb
        cmp ka                 ; class b < class a: after
        bcc c_after
        bne c_before
        lda ka
        cmp #2                 ; free entries: as they are
        beq c_before
        lda mode
        lsr @
        bcs c_desc
        jsr key                ; C=1 when a > b
        rts
c_desc  jsr swpab
        jsr key
        php
        jsr swpab
        plp
        rts
c_after sec
        rts
c_before clc
        rts

swpab   ldx #1
sp1     lda pa,x
        ldy pb,x
        sta pb,x
        sty pa,x
        dex
        bpl sp1
        rts

* class: 0 a directory, 1 a file, 2 free (deleted or never used)
class   tax
        and #$08
        beq cl_free
        txa
        and #$10
        bne cl_free
        txa
        and #$20
        beq cl_file
        lda #0
        rts
cl_file lda #1
        rts
cl_free lda #2
        rts

* key: C=1 when entry pa's key is greater than pb's (mode bits 7-6); equal
* keys: then by name and extension
key     lda mode
        and #$C0
        beq k_name
        cmp #$40
        beq k_size
        cmp #$80
        beq k_time
        ldx #14                ; the extension, then the name
        ldy #16
        jsr cmpr
        bne k_ret
k_name  ldx #6
        ldy #16
        jsr cmpr
        bne k_ret
        clc
k_ret   rts
k_size  lda #5                 ; most significant byte first
        jsr cmpb
        bne k_ret
        lda #4
        jsr cmpb
        bne k_ret
        lda #3
        jsr cmpb
        bne k_ret
        beq k_name
k_time  ldx #0                 ; year, month, day, hour, minute, second
kt1     lda torder,x
        stx tx
        jsr cmpb
        bne k_ret
        ldx tx
        inx
        cpx #6
        bcc kt1
        bcs k_name

* cmpr: bytes X .. Y of the two entries, in order: Z=1 equal, else C=1 a > b
cmpr    sty last
cr1     txa
        tay
        lda (pa),y
        cmp (pb),y
        bne cr_x
        inx
        cpx last
        bcc cr1
        beq cr1
        lda #0                 ; Z=1
cr_x    rts

* cmpb: byte A of the two entries: Z=1 equal, else C=1 a > b
cmpb    tay
        lda (pa),y
        cmp (pb),y
        rts

move_entry sta mx
        php
        pla
        sta mc
        pla                    ; the return address
        sta ret
        pla
        sta ret+1
        pla
        sta ptr
        pla
        sta ptr+1
        pla                    ; (the segment)
        lda ret+1
        pha
        lda ret
        pha
        jsr zsave
        lda ptr
        sta pa
        lda ptr+1
        sta pa+1
        lda mc
        lsr @
        bcs me_w
        lda mx                 ; read: the entry to tmp, then to dst
        jsr V_setme
        ldy #ENT-1
mr1     lda (pa),y
        sta tmp,y
        dey
        bpl mr1
        jsr V_popme
        lda dst
        sta pb
        lda dst+1
        sta pb+1
        ldy #ENT-1
mr2     lda tmp,y
        sta (pb),y
        dey
        bpl mr2
        jmp me_x
me_w    lda mx                 ; write: dentry to the entry
        jsr V_setme
        ldy #ENT-1
mw1     lda dentry,y
        sta (pa),y
        dey
        bpl mw1
        jsr V_popme
me_x    jsr zrest
        ldx #0
        jmp jhwctrl

zsave   ldx #ZN-1
zs1     lda $80,x
        sta zbuf,x
        dex
        bpl zs1
        rts
zrest   ldx #ZN-1
zr1     lda zbuf,x
        sta $80,x
        dex
        bpl zr1
        rts

gaps    dta a(1093,364,121,40,13,4,1)
gapb    dta a(1093*ENT,364*ENT,121*ENT,40*ENT,13*ENT,4*ENT,1*ENT)
torder  dta b(19,18,17,20,21,22)
mx      dta 0
mode    dta 0
mc      dta 0
bot     dta a(0)
top     dta a(0)
n       dta a(0)
gx      dta 0
tx      dta 0
last    dta 0
ret     dta a(0)
ptr     dta a(0)
tmp     :ENT dta 0
zbuf    :ZN dta 0
