; EOS Toolkit: CIODEV, the OS's CIO devices
;   CIODEV [dev]
; Without a parameter: each device in the OS handler table (HATABS), its
; name, its id (the offset in the table) in decimal and in hex and the
; address of its handler table, then the free entries. With a device
; name: the vectors of its handler table.
U_GETPAR smb 'U_GETPAR'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'

HATABS   equ $031A
NHAT     equ 11                ; entries of 3 bytes
EOL      equ $9B
ptr      equ $80               ; zero page scratch

        blk reloc main
start   jsr U_GETPAR
        jeq list
        lda FILE_P             ; the device: the parameter's first letter
        sta ptr
        lda FILE_P+1
        sta ptr+1
        ldy #0
        lda (ptr),y
        sta dname
        ldx #0
f1      lda HATABS,x           ; the table ends at its first empty entry
        beq nfound
        cmp dname
        beq found
        inx
        inx
        inx
        cpx #NHAT*3
        bcc f1
nfound  jsr PRINTF
        dta EOL,c'%c: device not found',EOL,0
        dta a(dname)
        rts
found   lda HATABS+1,x
        sta ptr
        sta tadr
        lda HATABS+2,x
        sta ptr+1
        sta tadr+1
        jsr PRINTF
        dta EOL,c'Id Addr OPEN CLS  GET  PUT  STAT SPEC',EOL
        dta c'-- ---- ---- ---- ---- ---- ---- ----',EOL
        dta c'%c: %04x ',0
        dta a(dname,tadr)
        ldy #0                 ; the six vectors
v1      lda (ptr),y
        sta vec
        iny
        lda (ptr),y
        sta vec+1
        iny
        jsr PRINTF
        dta c'%04x ',0
        dta a(vec)
        cpy #12
        bcc v1
        jsr PRINTF
        dta EOL,0
        rts

* list: every device in the table, then the free entries
list    jsr PRINTF
        dta EOL,c'Id Num Id   Addr',EOL
        dta c'-- -------- -----',EOL,0
        ldx #0
        stx count
l1      lda HATABS,x
        beq l2
        sta dname
        stx did
        lda HATABS+1,x
        sta tadr
        lda HATABS+2,x
        sta tadr+1
        jsr PRINTF
        dta c'%c: %2b ($%02x) $%04x',EOL,0
        dta a(dname,did,did,tadr)
        inc count
        inx
        inx
        inx
        cpx #NHAT*3
        bcc l1
l2      sec
        lda #NHAT
        sbc count
        sta count
        jsr PRINTF
        dta EOL,c'%b slots free',EOL,0
        dta a(count)
        rts

dname   dta 0
did     dta 0
count   dta 0
tadr    dta a(0)
vec     dta a(0)

        blk update address
        blk update symbols
