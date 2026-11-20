; EOS Toolkit: DPOKE, a word (or 1 to 4 bytes) into memory
;   DPOKE [[$]index:][$]location [$]value [amount]
; The value's bytes, low byte first, from the location up; amount is how
; many (2 when not given, 1 for 0). The location may be a symbol, and a
; memory index before a colon selects extended memory. Anything missing
; or not a number: nothing is done.
U_GETADR smb 'U_GETADR'
U_GETNUM smb 'U_GETNUM'
XRWMEM   smb 'XRWMEM'
COMTAB   smb 'COMTAB'

addpos   equ $0782             ; (XRWMEM: the address, 3 bytes)

        blk reloc main
start   jsr U_GETADR
        beq done
        sta adr
        stx adr+1
        sty mem
        lda #0                 ; above 64K: Y is the address's bank
        bcc st1
        tya
st1     sta addpos+2
        jsr U_GETNUM
        beq done
        sta val
        stx val+1
        lda COMTAB-4           ; (U_GETNUM: the whole 32-bit number)
        sta val+2
        lda COMTAB-3
        sta val+3
        jsr U_GETNUM           ; the amount: Y the last byte's offset
        php
        ldy #1
        plp
        beq wr
        tay
        beq wr
        cpx #5
        bcs wr
        dey
wr      lda #0                 ; the bytes from the last one down
        cpy #4
        bcs wr1
        lda val,y
wr1     jsr poke
        dey
        cpy #$FF
        bne wr
done    rts

* poke: A to the location + Y in memory mem; keeps Y
poke    pha
        lda adr
        sta addpos
        lda adr+1
        sta addpos+1
        ldx mem
        pla
        sec
        jmp XRWMEM

adr     dta a(0)
mem     dta 0
val     dta 0,0,0,0

        blk update address
        blk update symbols
