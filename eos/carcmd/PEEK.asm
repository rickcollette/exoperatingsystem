; EOS CAR: PEEK, a memory location
;   PEEK symbol | [[$]index:][$]address
; One line: the location in decimal and hex (with the index when one is
; given), its byte, the word at it, and the byte as a character:
;   1536 $0600, 65 $41, 39745 $9B41, "A"
;   2:16384 $02:$4000, 255 $FF, 255 $00FF, "."
; Memory other than main memory is read through XRWMEM. Without a
; parameter, with one that is not an address, or with an index that has
; no memory, PEEK prints nothing (as SDX).
U_GETADR smb 'U_GETADR'
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
p1      lda ad
        sta addpos
        lda ad+1
        sta addpos+1
        ldx ad_ix
        ldy #0
        clc
        jsr XRWMEM
        bcs p_ret
        sta b0
        sta w0
        iny
        clc
        jsr XRWMEM
        bcs p_ret
        sta w0+1
        lda ad_ixg
        beq p2
        jsr PRINTF
        dta c'%b:%d $%2x:$%4x, ',0
        dta a(ad_ix,ad,ad_ix,ad)
        jmp p3
p2      jsr PRINTF
        dta c'%d $%4x, ',0
        dta a(ad,ad)
p3      jsr PRINTF
        dta c'%b $%2x, %d $%4x, "',0
        dta a(b0,b0,w0,w0)
        lda #2
        sta dl_dot
        lda b0
        jsr outch
        jsr PRINTF
        dta c'"',EOL,0
p_ret   rts

b0      dta 0,0,0
w0      dta a(0),0

        icl 'MEMlib.icl'

        blk update address
        blk update symbols
