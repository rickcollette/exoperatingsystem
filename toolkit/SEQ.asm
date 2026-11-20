; EOS Toolkit: SEQ, a sequence of numbers
;   SEQ [first [step]] last
; The numbers from first (1 when not given) to last, step (1 when not
; given) apart, one per line to standard output. Numbers are 0 to
; 4294967295, decimal or $hex. With first above last the sequence counts
; down (SEQ with last alone and last 0: nothing). The last number shown
; is the last one not past last.
U_GETNUM smb 'U_GETNUM'
U_GETPAR smb 'U_GETPAR'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

EOL      equ $9B

        blk reloc main
start   ldx #0                 ; up to 3 numbers to nums
s1      stx cnt
        jsr U_GETNUM
        beq s3
        ldx cnt
        cpx #12
        jcs usage
        ldy #0
s2      lda COMTAB-6,y
        sta nums,x
        inx
        iny
        cpy #4
        bcc s2
        bcs s1
s3      jsr U_GETPAR           ; anything else: no
        jne usage
        ldx cnt
        jeq usage
        ldy #3
s4      lda #1                 ; first and step 1 unless given
        cpx #4
        bne s5
        sta cur                ; last only
        lda #0
        sta cur+1
        sta cur+2
        sta cur+3
        jsr s_last0
        lda #0                 ; (last below 1: nothing)
        sta down
        jsr diff
        bcs loop
        rts
s5      lda nums,y             ; first
        sta cur,y
        dey
        bpl s5
        cpx #8
        bne s6
        jsr s_last1            ; first, last
        jmp s7
s6      ldy #3                 ; first, step, last
s6a     lda nums+4,y
        sta step,y
        lda nums+8,y
        sta last,y
        dey
        bpl s6a
        lda step
        ora step+1
        ora step+2
        ora step+3
        beq usage
s7      lda #0                 ; down when first > last
        sta down
        jsr diff
        bcs loop
        dec down
loop    jsr PRINTF
        dta c'%l',EOL,0
        dta a(cur)
        jsr diff               ; the distance left, step or more?
        ldx #0
        sec
        ldy #4
l1      lda dist,x
        sbc step,x
        inx
        dey
        bne l1
        bcc l_end
        ldx #0                 ; cur = cur + step or - step
        ldy #4
        bit down
        bmi l3
        clc
l2      lda cur,x
        adc step,x
        sta cur,x
        inx
        dey
        bne l2
        beq loop
l3      sec
l4      lda cur,x
        sbc step,x
        sta cur,x
        inx
        dey
        bne l4
        beq loop
l_end   rts
usage   jsr PRINTF
        dta c'Use: seq [first [step]] last',EOL,0
        rts

* diff: dist = last - cur (counting up) or cur - last (down); C=0 when
* it is below 0
diff    ldx #0
        ldy #4
        sec
        bit down
        bmi df2
df1     lda last,x
        sbc cur,x
        sta dist,x
        inx
        dey
        bne df1
        rts
df2     lda cur,x
        sbc last,x
        sta dist,x
        inx
        dey
        bne df2
        rts
* s_last0, s_last1: last from the first or second number; step 1
s_last0 ldy #0
        dta b($2C)
s_last1 ldy #4
        ldx #0
sl1     lda nums,y
        sta last,x
        lda #0
        sta step,x
        iny
        inx
        cpx #4
        bcc sl1
        inc step
        rts

cnt     dta 0
down    dta 0
nums    :12 dta 0
cur     dta 0,0,0,0
step    dta 0,0,0,0
last    dta 0,0,0,0
dist    dta 0,0,0,0

        blk update address
        blk update symbols
