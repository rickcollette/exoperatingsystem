; EOS CAR: POKE, change a memory location
;   POKE symbol | [[$]index:][$]address [$]value
; The value's low byte is written through XRWMEM, so any memory index
; works. As on SDX nothing is ever reported: without parameters, without a
; value, with one that is not a number or an index with no memory POKE
; does nothing.
U_GETADR smb 'U_GETADR'
U_GETNUM smb 'U_GETNUM'
XRWMEM   smb 'XRWMEM'
PRINTF   smb 'PRINTF'
PUTC     smb 'PUTC'
COMTAB   smb 'COMTAB'

addpos   equ $0782
EOL      equ $9B

        blk reloc main
start   jsr getadr
        bne p1
        rts
p1      jsr U_GETNUM
        beq p_bad
        pha
        lda ad
        sta addpos
        lda ad+1
        sta addpos+1
        pla
        ldx ad_ix
        ldy #0
        sec
        jmp XRWMEM
p_bad   rts

        icl 'MEMlib.icl'

        blk update address
        blk update symbols
