; EOS CAR: MDUMP, memory in hex and ATASCII
;   MDUMP symbol | [[$]index:][$]address [[$]len] [/R]
; Eight bytes a line, read through XRWMEM (any memory index); with an
; index given, "$II:" comes first on a line of its own. /R shows the
; addresses as offsets from the start; it goes after the length (SDX
; does not take a length after it). Without a length, or with 0, the dump
; goes on round memory until BREAK (128): SDX did not stop within 25 s
; there. Without an address (or with one that is not) the
; usage line, then 156; a byte that cannot be read (an index with no
; memory) ends the dump with 166, as on SDX.
U_GETADR smb 'U_GETADR'
U_GETNUM smb 'U_GETNUM'
U_SLASH  smb 'U_SLASH'
U_FAIL   smb 'U_FAIL'
XRWMEM   smb 'XRWMEM'
PRINTF   smb 'PRINTF'
PUTC     smb 'PUTC'
COMTAB   smb 'COMTAB'

addpos   equ $0782
EOL      equ $9B
BRKKEY   equ $11

        blk reloc main
start   jsr getadr
        bne m1
        jsr PRINTF
        dta c'MDUMP [bank:]address [count] [/R]',EOL,0
        lda #156
        jmp U_FAIL
m1      lda #0
        sta len
        sta len+1
        sta len+2
        jsr U_GETNUM
        beq m2
        sta len
        stx len+1
m2      lda len                ; none, or 0: until BREAK
        ora len+1
        bne m2a
        inc len+2
        lda #$FF
        sta endless
m2a     lda opta
        ldx opta+1
        ldy #2
        jsr U_SLASH
        lda ad
        sta ptr
        sta dl_a
        lda ad+1
        sta ptr+1
        sta dl_a+1
        lda optr               ; /R: offsets
        beq m3
        lda #0
        sta dl_a
        sta dl_a+1
m3      jsr dl_start
        lda ad_ixg
        beq lp
        jsr PRINTF
        dta c'$%2x:',EOL,0
        dta a(ad_ix)
lp      bit endless
        bpl lp1
        lda BRKKEY             ; BREAK: the end
        bne lp0
        lda #$FF
        sta BRKKEY
        lda #128
        jmp U_FAIL
lp0     lda #1                 ; and a line more
        sta len+2
lp1     lda len
        ora len+1
        ora len+2
        jeq done
        lda len+1              ; this line: up to 8 bytes
        ora len+2
        bne l1
        lda len
        cmp #8
        bcc l2
l1      lda #8
l2      sta want
        jsr dl_head
        lda #0
        sta idx
l3      lda ptr
        sta addpos
        lda ptr+1
        sta addpos+1
        ldx ad_ix
        ldy idx
        clc
        jsr XRWMEM
        bcs bad
        jsr dl_hex
        inc idx
        lda idx
        cmp want
        bcc l3
        jsr dl_tail
        sec
        lda len
        sbc want
        sta len
        lda len+1
        sbc #0
        sta len+1
        lda len+2
        sbc #0
        sta len+2
        clc
        lda ptr
        adc want
        sta ptr
        bcc l5
        inc ptr+1
l5      clc
        lda dl_a
        adc want
        sta dl_a
        jcc lp
        inc dl_a+1
        jmp lp
done    rts
bad     lda #166
        jmp U_FAIL
len     dta 0,0,0
endless dta 0
ptr     dta a(0)
want    dta 0
idx     dta 0
opta    dta a(optr)
optr    dta 0,c'R'

        icl 'MEMlib.icl'

        blk update address
        blk update symbols
