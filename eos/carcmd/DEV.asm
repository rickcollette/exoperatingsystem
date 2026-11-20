; EOS CAR: DEV, the kernel devices
;   DEV
; Each entry of DEVNAME in use: its number, name, the address in
; dev_vector and On when the library micro-buffers its I/O (a bit per
; device at COMTAB2-1). Then the number of free entries.
PRINTF   smb 'PRINTF'
DEVNAME  smb 'DEVNAME'
DEVSPEC  smb 'DEVSPEC'
COMTAB2  smb 'COMTAB2'

dev_vector equ $0750
EOL      equ $9B

        blk reloc main
start   jsr PRINTF
        dta c'Id Name Addr  uBufs',EOL
        dta c'-- ---- ----- -----',EOL,0
        lda #0
        sta id
        sta nfree
        lda COMTAB2-1
        sta bufs
d1      lda id                 ; X = 4 * id: its DEVNAME entry
        asl @
        asl @
        tax
        lda DEVNAME,x
        cmp #' '
        beq d_free
        sta dname
        lda DEVNAME+1,x
        sta dname+1
        lda DEVNAME+2,x
        sta dname+2
        lda id
        asl @
        tax
        lda dev_vector,x
        sta addr
        lda dev_vector+1,x
        sta addr+1
        jsr PRINTF
        dta c'%b  %s: $%4x',0
        dta a(id,dname,addr)
        lsr bufs
        bcc d2
        jsr PRINTF
        dta c' On',0
d2      jsr PRINTF
        dta b(EOL),0
        jmp d_next
d_free  inc nfree
        lsr bufs
d_next  inc id
        lda id
        cmp DEVSPEC-1
        bcc d1
        jsr PRINTF
        dta b(EOL),c'%b slots free',EOL,0
        dta a(nfree)
        rts

id      dta 0
nfree   dta 0
bufs    dta 0
addr    dta a(0),a(0)
dname   dta c'   ',0

        blk update address
        blk update symbols
