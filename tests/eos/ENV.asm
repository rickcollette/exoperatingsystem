; EOS oracle test: GETENV, NUMENV, PUTENV. Variables starting with _ (the
; batch file's parameters) are not listed.
PRINTF   smb 'PRINTF'
GETENV   smb 'GETENV'
NUMENV   smb 'NUMENV'
PUTENV   smb 'PUTENV'
U_GETPAR smb 'U_GETPAR'
COMTAB   smb 'COMTAB'

LBUFF    equ $0580
zp       equ $80
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR           ; 1: the first steps, 2: the second ones
        lda COMTAB+$21
        cmp #'2'
        beq st2
        jsr list
        ldx #0                 ; the steps: GETENV or PUTENV on a string
        beq step
st2     ldx #steps2-steps
step    stx si
        lda steps,x
        jeq done
        sta op
        lda steps+1,x
        sta sp
        lda steps+2,x
        sta sp+1
        lda op
        cmp #'L'
        bne cs0
        jsr list
        jmp next
cs0     lda sp
        sta zp
        lda sp+1
        sta zp+1
        ldy #0                 ; a copy for PRINTF
cs      lda (zp),y
        sta sbuf,y
        iny
        cmp #EOL
        bne cs
        lda sp
        ldx sp+1
        ldy op
        cpy #'G'
        beq sg
        cpy #'P'
        beq sp1
sg      jsr GETENV
        sta ra
        lda #EOL
        bit ra
        bpl sg1
        sta LBUFF              ; no value
sg1     jsr PRINTF
        dta c'g %s a=%2x [%s]',EOL,0
        dta a(sbuf,ra,LBUFF)
        jmp next
sp1     jsr PUTENV
        sta ra
        jsr PRINTF
        dta c'p %s a=%2x',EOL,0
        dta a(sbuf,ra)
next    lda si
        clc
        adc #3
        tax
        jne step
done    rts

* list: every variable but _...
list    lda #0
        sta vn
l1      lda vn
        jsr NUMENV
        bmi l3
        lda LBUFF
        cmp #'_'
        beq l2
        jsr PRINTF
        dta c'n [%s]',EOL,0
        dta a(LBUFF)
l2      inc vn
        bne l1
l3      rts

sp      dta a(0)
sbuf    :24 dta 0
si      dta 0
op      dta 0
ra      dta 0,0
vn      dta 0,0

steps   dta c'G',a(s_path)
        dta c'G',a(s_nope)
        dta c'G',a(s_pat)
        dta c'P',a(s_foo)
        dta c'G',a(s_foon)
        dta c'L',a(0)
        dta 0
steps2  dta c'P',a(s_path2)
        dta c'G',a(s_path)
        dta c'P',a(s_fooe)
        dta c'G',a(s_foon)
        dta c'L',a(0)
        dta c'P',a(s_foon)
        dta c'G',a(s_foon)
        dta c'P',a(s_nope)
        dta c'L',a(0)
        dta 0

s_path  dta c'PATH',EOL
s_nope  dta c'NOPE',EOL
s_pat   dta c'PAT',EOL
s_foo   dta c'FOO=BAR BAZ',EOL
s_foon  dta c'FOO',EOL
s_path2 dta c'PATH=D1:>BIN;CAR:',EOL
s_fooe  dta c'FOO=',EOL

        blk update address
        blk update symbols
