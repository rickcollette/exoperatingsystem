; EOS Toolkit: BSAVE, a memory area saved to a file
;   BSAVE [d:][path]fname[.ext] [$]address [$]length
; The bytes from address on, length of them, written as they are to the
; file (made anew). The address as the command processor takes one: a
; number, [index:]number or a symbol, then +n or -n. An address above 64K
; only with the 65816's linear memory. A missing or bad parameter: 156;
; past the end of memory: 179.
U_GETATR smb 'U_GETATR'
U_GETADR smb 'U_GETADR'
U_GETNUM smb 'U_GETNUM'
U_FAIL   smb 'U_FAIL'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
FOPEN    smb 'FOPEN'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
COMTAB   smb 'COMTAB'
COMTAB2  smb 'COMTAB2'

BUFOFF   equ $0A               ; (COMTAB+: the next parameter's offset)
mode     equ $0778
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
E_BADPAR equ 156
E_MEM    equ 179

        blk reloc main
start   lda COMTAB+BUFOFF      ; the name is taken again below
        sta off
        lda #$20
        jsr U_GETATR
        beq bad
        jsr U_GETADR
        beq bad
        sta adr
        stx adr+1
        sty adr+2              ; (the index, or bits 16-23)
        ror big                ; C=1: a 24-bit address
        bpl s1
        lda COMTAB2            ; (bit 7: a 65816, bit 1: no linear memory)
        bpl bad
        and #2
        bne bad
s1      jsr U_GETNUM
        bne s2
bad     lda #E_BADPAR
        jmp U_FAIL
s2      sta len
        stx len+1
        lda COMTAB-4
        sta len+2
        lda off                ; the name again, the file made
        sta COMTAB+BUFOFF
        lda #$20
        jsr U_GETATR
        lda #8
        sta mode
        jsr FOPEN
        lda adr
        sta addpos
        lda adr+1
        sta addpos+1
        lda adr+2
        bit big
        bpl s3
        sta addpos+2           ; 24 bits: in the linear memory (3)
        lda #3
s3      sta memreix

* up to 64K-1 bytes at a time
wr      lda #$FF
        tax
        ldy len+2
        bne w1
        lda len
        ldx len+1
w1      sta bytbuf
        stx bytbuf+1
        lda a_err
        ldx a_err+1
        jsr U_SFAIL
        jsr FWRITE
        jsr U_XFAIL
        sec                    ; len = len - written
        lda len
        sbc bytbuf
        sta len
        lda len+1
        sbc bytbuf+1
        sta len+1
        lda len+2
        sbc #0
        sta len+2
        bcc close
        ora len
        ora len+1
        beq close
        clc                    ; the address after them
        lda addpos
        adc bytbuf
        sta addpos
        lda addpos+1
        adc bytbuf+1
        sta addpos+1
        bcc wr
        bit big                ; past 64K: only in the linear memory
        bpl w2
        inc addpos+2
        bne wr
w2      lda #E_MEM
err     pha                    ; (U_SFAIL: an error while writing)
        jsr close
        pla
        jmp U_FAIL
close   lda #0
        sta memreix
        jmp FCLOSE

a_err   dta a(err)
off     dta 0
big     dta 0
adr     dta 0,0,0
len     dta 0,0,0

        blk update address
        blk update symbols
