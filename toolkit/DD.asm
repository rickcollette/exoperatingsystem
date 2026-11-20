; EOS Toolkit: DD, bytes from standard input to standard output
;   DD [skip [count]]
; Skips the first skip bytes of the input (by a seek, or by reading them
; where the input cannot seek), then copies count bytes, or all the rest
; when count is not given. The input ending before count bytes: 136.
; Numbers are decimal or $hex, at most 24 bits (larger ones: $FFFFFF).
U_GETNUM smb 'U_GETNUM'
U_FAIL   smb 'U_FAIL'
FGETC    smb 'FGETC'
GETC     smb 'GETC'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

jkernel  equ $0703
file_id  equ $0760
addpos   equ $0782
EOL      equ $9B
E_NOFUNC equ 146               ; the device cannot seek

        blk reloc main
start   jsr U_GETNUM
        bne s1
        jsr PRINTF
        dta c'Usage: DD [skip [count]]',EOL,0
        rts
s1      jsr num24
        sta skip
        stx skip+1
        sty skip+2
        lda #1                 ; no count: up to the end of the input
        sta all
        jsr U_GETNUM
        beq s2
        jsr num24
        sta count
        stx count+1
        sty count+2
        lda #0
        sta all
s2      lda COMTAB+7           ; the input skipped by a seek
        sta file_id
        ldx #2
s3      lda skip,x
        sta addpos,x
        dex
        bpl s3
        ldy #2                 ; (kernel FSEEK)
        jsr jkernel
        bpl copy
        cmp #E_NOFUNC
        beq s4
        jmp U_FAIL
s4      lda skip               ; or by reading it
        ora skip+1
        ora skip+2
        beq copy
        jsr FGETC
        jsr dec_skip
        jmp s4

copy    lda all                ; count bytes, or all of them
        bne c1
        lda count
        ora count+1
        ora count+2
        beq c_ret
        jsr dec_cnt
c1      jsr GETC
        bmi c_end
        jsr PUTC
        jmp copy
c_end   lda all
        bne c_ret
        lda #136
        jmp U_FAIL
c_ret   rts

* num24: the number just read by U_GETNUM in A, X, Y (24 bits; $FFFFFF
* when larger)
num24   ldy COMTAB-3
        beq n1
        lda #$FF
        tax
        tay
        rts
n1      ldy COMTAB-4
        rts

* dec_skip, dec_cnt: one off skip or count
dec_skip ldx #0
        beq dec3
dec_cnt ldx #3
dec3    lda skip,x
        bne d1
        lda skip+1,x
        bne d2
        dec skip+2,x
d2      dec skip+1,x
d1      dec skip,x
        rts

skip    dta 0,0,0
count   dta 0,0,0
all     dta 0

        blk update address
        blk update symbols
