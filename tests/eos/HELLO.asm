; EOS test program: prints HI and its parameters, one per line
; (relocatable SDX binary: MADS blk reloc)
PUTC     smb 'PUTC'
U_GETPAR smb 'U_GETPAR'
COMTAB   smb 'COMTAB'

        blk reloc main
start   ldx #0
msg     lda text,x
        beq par
        jsr PUTC
        inx
        bne msg
par     jsr U_GETPAR
        beq done
        ldx #0
p1      lda COMTAB+$21,x
        jsr PUTC
        inx
        cmp #$9B
        bne p1
        jmp par
done    rts
text    dta c'HI',$9B,0

        blk update address
        blk update symbols
