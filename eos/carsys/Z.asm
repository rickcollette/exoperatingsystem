; EOS CAR: Z.SYS [/I|S]: a Z: device as SpartaDOS 3.2's ZHAND.COM, on EOS's
; clock (the CLK: kernel device). One stream at a time (else 161). XIO 33
; reads the time (H, M, S: three GETs), 35 the date (D, M, Y); 36 and 37
; set them (three PUTs). More than three bytes: 136. Setting is refused
; (139) unless /S; with /I it is ignored (status 1). XIO 32, 34, 38, 39
; need TD.COM's I_FMTTD: 139 here.
INSTALL  smb 'INSTALL'
U_GETPAR smb 'U_GETPAR'
COMTAB   smb 'COMTAB'

jkernel  equ $0703
device   equ $0761
date     equ $077B
time     equ $077E
HATABS   equ $031A
ICCOMZ   equ $22
CLK      equ $10               ; the CLK: device
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR           ; /I or /S
        beq s2
        lda COMTAB+$21
        cmp #'/'
        bne s2
        lda COMTAB+$22
        cmp #'I'
        beq s1
        cmp #'S'
        bne s2
s1      sta zmode
s2      ldx #0                 ; Z: already there, or a free slot
s3      lda HATABS,x
        cmp #'Z'
        beq s4
        cmp #0
        beq s4
        inx
        inx
        inx
        cpx #36
        bcc s3
        rts                    ; (the table is full)
s4      lda #'Z'
        sta HATABS,x
        lda ztaba
        sta HATABS+1,x
        lda ztaba+1
        sta HATABS+2,x
        dec INSTALL            ; stay
        rts

ztaba   dta a(ztab)
ztab    dta a(z_open-1,z_close-1,z_get-1,z_put-1,z_stat-1,z_xio-1)
        jmp z_rts

z_open  lda zopen
        bne z_many
        dec zopen
        lda #33                ; reading the time until an XIO says else
        jsr z_load
        ldy #1
        rts
z_many  ldy #161
        rts
z_close lda #0
        sta zopen
z_stat  ldy #1
z_rts   rts

z_xio   lda ICCOMZ
        cmp #33
        beq z_load1
        cmp #35
        beq z_load1
        cmp #36
        beq z_set
        cmp #37
        beq z_set
        ldy #139
        rts
z_load1 jsr z_load
        ldy #1
        rts
z_set   sta zfn
        lda #0
        sta zpos
        ldy #1
        rts
* z_load: function A (33 time, 35 date): the clock's three bytes to zbuf
z_load  sta zfn
        lda #0
        sta zpos
        jsr z_gettd
        ldx #2
        lda zfn
        cmp #35
        beq zl2
zl1     lda time,x
        sta zbuf,x
        dex
        bpl zl1
        rts
zl2     lda date,x
        sta zbuf,x
        dex
        bpl zl2
        rts
z_gettd lda #CLK
        sta device
        ldy #100
        jmp jkernel

z_get   ldx zpos
        cpx #3
        bcs z_eof
        lda zbuf,x
        inc zpos
        ldy #1
        rts
z_eof   ldy #136
        rts

z_put   ldy zmode
        cpy #'S'
        beq zp1
        ldy #1
        lda zmode
        cmp #'I'
        beq zp_x
        ldy #139
zp_x    rts
zp1     ldx zpos
        cpx #3
        bcs z_eof
        sta zbuf,x
        inc zpos
        cpx #2
        bne zp_ok
        jsr z_gettd            ; all three: into the clock
        ldx #2
        lda zfn
        cmp #37
        beq zp3
zp2     lda zbuf,x
        sta time,x
        dex
        bpl zp2
        bmi zp4
zp3     lda zbuf,x
        sta date,x
        dex
        bpl zp3
zp4     lda #CLK
        sta device
        ldy #101
        jsr jkernel
zp_ok   ldy #1
        rts

zmode   dta 0                  ; 'I', 'S' or 0
zopen   dta 0
zfn     dta 0
zpos    dta 0
zbuf    dta 0,0,0

        blk update address
        blk update symbols
