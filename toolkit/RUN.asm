; EOS Toolkit: RUN, call machine code at an address
;   RUN symbol|[[$]index:][$]address
; Asks "Jump to $ii:$aaaa (i:a)? "; Y calls the address (JSR, in the
; memory with that index, main memory when none is given), any other key
; does not. A symbol stands for its address. Addresses past $FFFF need a
; 65816: 184 here. No address: nothing is done.
U_GETADR smb 'U_GETADR'
U_GETKEY smb 'U_GETKEY'
TOUPPER  smb 'TOUPPER'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'

V_setme  equ $07F1             ; memory index A on
V_popme  equ $07F4             ; and back
EOL      equ $9B

        blk reloc main
start   jsr U_GETADR
        bne got
        rts
got     bcc ask
        lda #184
        jmp U_FAIL
ask     sta adr
        stx adr+1
        sta call+1             ; (the JMP's operand: no JMP () through a
        stx call+2             ; vector that could sit at $xxFF)
        sty idx
        jsr PRINTF
        dta b(EOL),c'Jump to $%02x:$%04x (%b:%d)? ',0
        dta a(idx,adr,idx,adr)
        jsr U_GETKEY
        jsr TOUPPER
        cmp #'Y'
        bne end
        lda idx
        jsr V_setme
        jsr call
        jsr V_popme
end     jsr PRINTF
        dta b(EOL),0
        rts
call    jmp $FFFF

adr     dta a(0)
idx     dta 0

        blk update address
        blk update symbols
