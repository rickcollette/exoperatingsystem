; EOS test: U_EXPAND. Each parameter through U_GEFINA, then U_EXPAND at
; offset 1 of a buffer: printed as [name].
PRINTF   smb 'PRINTF'
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
U_EXPAND smb 'U_EXPAND'

EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR
        beq s_end
        jsr U_GEFINA
        lda #'['
        sta buf
        lda bufadr
        ldx bufadr+1
        ldy #1
        jsr U_EXPAND
        lda #']'               ; over the EOL
        sta buf,y
        lda #EOL
        sta buf+1,y
        jsr PRINTF
        dta c'%s',EOL,0
        dta a(buf)
        jmp start
s_end   rts

bufadr  dta a(buf)
buf     :20 dta 0

        blk update address
        blk update symbols
