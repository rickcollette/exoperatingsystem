; EOS CAR: CON, the console mode
;   CON 40|64|80
; Talks to the console drivers (CON64.SYS: 64 columns, CON.SYS: 80) through
; the screen editor on IOCB 0: XIO 64 / XIO 80 with aux2 128 turns a
; driver's mode on, 0 off. The other driver is turned off first; when the
; driver asked for is not there (the XIO fails), both stay off and the
; screen is the plain 40-column one.
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
COMTAB   smb 'COMTAB'

CIOV     equ $E456
ICCOM    equ $0342
ICBAL    equ $0344
ICBLL    equ $0348
ICAX1    equ $034A
ICAX2    equ $034B
EOL      equ $9B
E_BADPAR equ 156

        blk reloc main
start   jsr U_GETPAR
        beq bad
        lda COMTAB+$23         ; two digits
        cmp #EOL
        bne bad
        lda COMTAB+$21
        ldx COMTAB+$22
        cmp #'4'
        beq c40
        cmp #'6'
        beq c64
        cmp #'8'
        beq c80
bad     lda #E_BADPAR
        jmp U_FAIL
c40     cpx #'0'
        bne bad
        lda #64
        jsr off
        lda #80
        jmp off
c64     cpx #'4'
        bne bad
        lda #80
        jsr off
        lda #64
        bne on
c80     cpx #'0'
        bne bad
        lda #64
        jsr off
        lda #80
on      ldy #128
        jsr xio
        bpl o_ret
        lda #64                ; not there: 40 columns
        jsr off
        lda #80
        jmp off
o_ret   rts

off     ldy #0
; xio: XIO A,#0,12,Y,"E:"; N=1 on an error. IOCB 0 keeps its aux bytes.
xio     ldx ICAX1
        stx ax1
        ldx ICAX2
        stx ax2
        ldx #0
        sta ICCOM
        sty ICAX2
        lda #12
        sta ICAX1
        lda p_ename
        sta ICBAL
        lda p_ename+1
        sta ICBAL+1
        lda #0
        sta ICBLL
        sta ICBLL+1
        jsr CIOV
        lda ax1
        sta ICAX1
        lda ax2
        sta ICAX2
        tya
        rts

ax1     dta 0
ax2     dta 0

p_ename dta a(ename)
ename   dta c'E:',EOL

        blk update address
        blk update symbols
