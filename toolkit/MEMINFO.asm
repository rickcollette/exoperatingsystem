; EOS Toolkit: MEMINFO, the extended memory banks
;   MEMINFO
; The type of the extended memory, the banks in all and the free ones,
; then each bank by its memory index with the value its register takes.
; The free banks are the indices 4 up to NBANKS+3 (a new one is taken
; from the top of them), the rest are in use.
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
COMTAB2  smb 'COMTAB2'
T_       smb 'T_'

NBANKS   equ $1D               ; (COMTAB+: the banks not used yet; COMTAB2-3:
                               ; the banks found, COMTAB2-2: bit 7 Axlon)
RMARGN   equ $53
COLCRS   equ $55
EOL      equ $9B

        blk reloc main
start   lda COMTAB2-3
        bne s1
        jsr PRINTF
        dta EOL,c'No ext RAM available',EOL,0
        rts
s1      jsr PRINTF
        dta EOL,c'Ext memory information:',EOL,EOL
        dta c'HWRegister: ',0
        bit COMTAB2-2
        bpl s2
        jsr PRINTF
        dta c'Axlon',EOL,0
        jmp s3
s2      jsr PRINTF
        dta c'PORTB',EOL,0
s3      lda COMTAB2-3
        jsr kbytes
        jsr PRINTF
        dta c'Bank count: %b (%d KB)',EOL,0
        dta a(COMTAB2-3,kb)
        lda COMTAB+NBANKS
        jsr kbytes
        jsr PRINTF
        dta c'Free banks: %b (%d KB)',EOL,0
        dta a(COMTAB+NBANKS,kb)
        lda #4                 ; the free ones: index 4 up
        sta idx
        clc
        adc COMTAB+NBANKS
        sta last
        lda #0
        sta count
        lda COMTAB+NBANKS
        beq s5
        jsr PRINTF
        dta EOL,c'List of free%s',EOL,EOL,0
        dta a(bnames)
s4      lda idx
        jsr bank
        inc count
        inc idx
        lda idx
        cmp last
        bcc s4
        jsr newline
s5      lda count              ; then the ones in use
        cmp COMTAB2-3
        beq s7
        jsr PRINTF
        dta EOL,c'Occupied%s',EOL,EOL,0
        dta a(bnames)
s6      lda idx
        jsr bank
        inc count
        inc idx
        lda count
        cmp COMTAB2-3
        bcc s6
newline jsr PRINTF
        dta EOL,0
s7      rts

* bank: "index=$value" for memory index A, on a new line when the line
* has no room for it
bank    sta num
        bit COMTAB2-2
        bpl b1
        sec                    ; Axlon: the bank number, from 1
        sbc #3
        jmp b2
b1      pha                    ; PORTB: the bank bits for index / 4,
        lsr @                  ; the index's low bits in bits 2-3
        lsr @
        tax
        pla
        and #3
        asl @
        asl @
        ora T_+7,x
b2      sta reg
        lda COLCRS
        clc
        adc #8
        cmp RMARGN
        bcc b3
        jsr newline
b3      jsr PRINTF
        dta c'%3b=$%2x ',0
        dta a(num,reg)
        rts

* kbytes: kb = A * 16
kbytes  ldx #0
        stx kb+1
        ldx #4
k1      asl @
        rol kb+1
        dex
        bne k1
        sta kb
        rts

bnames  dta c' banks (index=regvalue):',0
idx     dta 0
last    dta 0
count   dta 0
num     dta 0
reg     dta 0
kb      dta a(0)

        blk update address
        blk update symbols
