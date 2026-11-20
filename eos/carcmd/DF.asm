; EOS CAR: DF, free space on all drives
;   DF [/A]
; Drives A: up to the one $MAXDRV names (O: without it; a drive whose
; letter is a CIO device's shown as Dn:): the total and
; free KiB, the free part in per cent and the volume name, then the sums.
; Drives that give an error are left out; with /A they are listed with
; the error message.
U_GETPAR smb 'U_GETPAR'
GETDFREE smb 'GETDFREE'
GETENV   smb 'GETENV'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
ERR_DMSG smb 'ERR_DMSG'
U_FAIL   smb 'U_FAIL'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'
_DRVNAME smb '_DRVNAME'
_DRVNM   smb '_DRVNM'

path     equ $07A0
LBUFF    equ $0580
EOL      equ $9B

        blk reloc main
start   lda #0
        sta opt_a
        ldx #5
s0      sta sum_t,x            ; sum_t, sum_f
        dex
        bpl s0
p1      jsr U_GETPAR           ; /A
        beq p_end
        lda COMTAB+$21
        cmp #'/'
        bne p1
        ldx #1
p2      lda COMTAB+$21,x
        cmp #EOL
        beq p1
        cmp #'A'
        beq p3
        lda #156               ; another switch
        jmp U_FAIL
p3      sta opt_a
        inx
        bne p2
p_end   lda #15                ; the last drive: $MAXDRV, else O:
        sta last
        lda mxa
        ldx mxa+1
        jsr GETENV
        bmi s1
        lda LBUFF
        cmp #'A'
        bcc s1
        cmp #'O'+1
        bcs s1
        sbc #'A'-2             ; (C=0: A is 1)
        sta last
s1      jsr PRINTF
        dta c'Drv   Total    Free  %% Volume',EOL
        dta c'=== ======= ======= == ========',EOL,0
        lda spa
        sta FILE_P
        lda spa+1
        sta FILE_P+1
        lda #1
        sta drv
d1      lda drv                ; its name: _DRVNAME
        jsr _DRVNAME
        lda trapv
        ldx trapv+1
        jsr U_SFAIL
        jsr GETDFREE
        jsr U_XFAIL
        jsr drive
        jmp next
trap    ldx opt_a              ; an error: listed with /A only
        beq next
        pha
        jsr PRINTF
        dta c'%4s',0
        dta a(_DRVNM)
        pla
        jsr ERR_DMSG
        lda #EOL
        jsr PUTC
next    inc drv
        lda last
        cmp drv
        bcs d1
        lda sum_t              ; the sums
        sta kt
        lda sum_t+1
        sta kt+1
        lda sum_t+2
        sta kt+2
        lda sum_f
        sta kf
        lda sum_f+1
        sta kf+1
        lda sum_f+2
        sta kf+2
        jsr percent
        jsr PRINTF
        dta c'=== ======= ======= == ========',EOL
        dta c'All %7e %7e %2b',EOL,0
        dta a(kt,kf,pc)
        rts

* drive: the line of the drive GETDFREE has read, added to the sums.
* KiB as SDX's DF counts them: the bytes / 1024, plus 1.
drive   lda path+2
        sta kt
        lda path+3
        sta kt+1
        lda path+4
        sta kf
        lda path+5
        sta kf+1
        lda #0
        sta kt+2
        sta kf+2
        lda path+1             ; sector size code: $80 128 bytes, else
        bmi dr3                ; 256 shifted left by the code
        and #$0F
        tax
        beq dr2
dr1     asl kt
        rol kt+1
        rol kt+2
        asl kf
        rol kf+1
        rol kf+2
        dex
        bne dr1
dr2     ldx #2                 ; sectors of 256 bytes: / 4
        bne dr4
dr3     ldx #3                 ; of 128 bytes: / 8
dr4     lsr kt+2
        ror kt+1
        ror kt
        lsr kf+2
        ror kf+1
        ror kf
        dex
        bne dr4
        inc kt
        bne dk5
        inc kt+1
        bne dk5
        inc kt+2
dk5     inc kf
        bne dk6
        inc kf+1
        bne dk6
        inc kf+2
dk6
        clc
        lda sum_t
        adc kt
        sta sum_t
        lda sum_t+1
        adc kt+1
        sta sum_t+1
        lda sum_t+2
        adc kt+2
        sta sum_t+2
        clc
        lda sum_f
        adc kf
        sta sum_f
        lda sum_f+1
        adc kf+1
        sta sum_f+1
        lda sum_f+2
        adc kf+2
        sta sum_f+2
        ldx #7                 ; the volume name
dr5     lda path+6,x
        sta vol,x
        dex
        bpl dr5
        jsr percent
        jsr PRINTF
        dta c'%4s%7e %7e %2b %s',EOL,0
        dta a(_DRVNM,kt,kf,pc,vol)
        rts

* percent: pc = kf * 100 / kt (0 when kt is 0)
percent ldx #3
pe1     lda kf,x               ; v = kf * 100: kf * (4 + 32 + 64)
        sta v,x
        dex
        bpl pe1
        lda #0
        sta v+3
        jsr v2
        jsr v2
        ldx #3
pe2     lda v,x
        sta w,x
        dex
        bpl pe2
        jsr v2
        jsr v2
        jsr v2
        jsr vadd
        jsr v2
        jsr vadd2
        lda #0                 ; v / kt, restoring division
        sta r
        sta r+1
        sta r+2
        ldx #32
pe3     asl v
        rol v+1
        rol v+2
        rol v+3
        rol r
        rol r+1
        rol r+2
        sec
        lda r
        sbc kt
        sta t
        lda r+1
        sbc kt+1
        sta t+1
        lda r+2
        sbc kt+2
        bcc pe4
        sta r+2
        lda t+1
        sta r+1
        lda t
        sta r
        inc v
pe4     dex
        bne pe3
        lda v                  ; the quotient, at most 255
        ldx v+1
        bne pe5
        ldx v+2
        bne pe5
        ldx v+3
        beq pe6
pe5     lda #255
pe6     ldx kt
        bne pe7
        ldx kt+1
        bne pe7
        ldx kt+2
        bne pe7
        lda #0
pe7     sta pc
        rts
* v2: v * 2
v2      asl v
        rol v+1
        rol v+2
        rol v+3
        rts
* vadd: w = w + v; vadd2: v = w + v
vadd    clc
        ldx #0
va1     lda w,x
        adc v,x
        sta w,x
        inx
        txa
        eor #4
        bne va1
        rts
vadd2   clc
        ldx #0
va2     lda w,x
        adc v,x
        sta v,x
        inx
        txa
        eor #4
        bne va2
        rts

trapv   dta a(trap)
spa     dta a(_DRVNM)
mxa     dta a(mxname)
opt_a   dta 0
last    dta 0
pc      dta 0,0
kt      dta 0,0,0,0
kf      dta 0,0,0,0
sum_t   dta 0,0,0
sum_f   dta 0,0,0
v       dta 0,0,0,0
w       dta 0,0,0,0
r       dta 0,0,0
t       dta 0,0
drv     dta 0
vol     :8 dta 0
        dta EOL
mxname  dta c'MAXDRV',EOL

        blk update address
        blk update symbols
