; EOS Toolkit: SL, the system's symbols
;   SL [name [[$]address]]
; Lists the symbols (S_NEXT: the ones added in RAM, then the system's
; table) with their addresses and levels; with a name, only those that
; start with it. With a name and an address the symbol is added first
; (S_ADD), and the program stays in memory so that it is kept.
U_GETPAR smb 'U_GETPAR'
U_GETADR smb 'U_GETADR'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
SYMBOL   smb 'SYMBOL'
S_NEXT   smb 'S_NEXT'
S_ADD    smb 'S_ADD'
EXTENDED smb 'EXTENDED'
INSTALL  smb 'INSTALL'

BUFOFF   equ $0A               ; (COMTAB+: the command line position,
FILLEN   equ $1A               ; the parameter's length, the parameter)
COMFNAM  equ $21
EOL      equ $9B

        blk reloc main
start   jsr PRINTF
        dta EOL,c'Name     Address Level',EOL
        dta c'======== ======= =====',EOL,0
        lda COMTAB+BUFOFF      ; the name is read again for the list
        sta sv_off
        jsr U_GETPAR
        beq list
        ldy #0                 ; the name, space padded, to SYMBOL+2
n1      lda COMTAB+COMFNAM,y
        cpy COMTAB+FILLEN
        bcc n2
        lda #' '
n2      sta SYMBOL+2,y
        iny
        cpy #8
        bcc n1
        jsr U_GETADR           ; an address: the symbol is added
        beq n3
        sta SYMBOL+$0B
        stx SYMBOL+$0C
        sty EXTENDED
        jsr S_ADD
        lda #$FF               ; this program and the symbol stay
        sta INSTALL
n3      lda sv_off
        sta COMTAB+BUFOFF
        jsr U_GETPAR           ; (none: COMFNAM is empty, all match)

list    lda #0                 ; from the first symbol
        sta SYMBOL+2
l1      jsr S_NEXT
        beq done
        ldy #0                 ; does its name start with the parameter?
l2      lda COMTAB+COMFNAM,y
        cmp #EOL
        beq l3
        cmp SYMBOL+2,y
        bne l1
        iny
        cpy #8
        bcc l2
l3      lda SYMBOL+$0A         ; level bits 7, 6: a 24-bit address
        and #$C0
        cmp #$C0
        bne l4
        jsr PRINTF
        dta c'%8s $%6x',0
        dta a(SYMBOL+2,SYMBOL+$0B)
        jmp l5
l4      jsr PRINTF
        dta c'%8s   $%4x',0
        dta a(SYMBOL+2,SYMBOL+$0B)
l5      jsr PRINTF
        dta c' $%2x',EOL,0
        dta a(SYMBOL+$0A)
        jmp l1
done    rts

sv_off  dta 0

        blk update address
        blk update symbols
