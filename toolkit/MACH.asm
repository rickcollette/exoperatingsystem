; EOS Toolkit: MACH, the machine as the system sees it
;   MACH
; The computer (800FLG), the CPU (_816FLG) and its address space, the
; clock speed, and the memory: main, extended (with its type) and the
; 65816's high memory. Nothing is tested: the values are the ones the
; system found at its start (COMTAB, COMTAB2).
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
COMTAB2  smb 'COMTAB2'

F800     equ $1B               ; (COMTAB+: bit 7 a 400/800; COMTAB2+0:
EOL      equ $9B               ; the CPU; COMTAB2-6 the clock in 100%,
                               ; -5 the first high bank, -4 the high
                               ; banks, -3 the extended ones, -2 bit 7 Axlon)

        blk reloc main
start   jsr PRINTF
        dta EOL,c'Hardware type: ',0
        bit COMTAB+F800
        bpl m1
        jsr PRINTF
        dta c'400/800',EOL,0
        jmp m2
m1      jsr PRINTF
        dta c'XL/XE',EOL,0
m2      jsr PRINTF
        dta c'Installed CPU: ',0
        lda COMTAB2            ; 0 6502, 2 65C02, bit 7 65C816
        beq c6502
        bmi c816
        cmp #2
        beq c02
        jsr unknown
        lda #0
        beq m3
c02     jsr PRINTF
        dta c'65C02',EOL,0
        lda #1
        bne m3
c816    jsr PRINTF
        dta c'65C816',EOL,0
        lda #2
        bne m3
c6502   jsr PRINTF
        dta c'6502',EOL,0
        lda #1
m3      sta space
        jsr PRINTF
        dta c'Address space: ',0
        lda space
        beq m5
        cmp #1
        beq m4
        jsr PRINTF
        dta c'16 MB',EOL,0
        jmp m6
m4      jsr PRINTF
        dta c'64 KB',EOL,0
        jmp m6
m5      jsr unknown
m6      jsr PRINTF
        dta c'Clock speed %%: %b00',EOL,EOL,0
        dta a(COMTAB2-6)
        jsr PRINTF
        dta c'Available RAM:',EOL,EOL,0
        lda #64                ; main memory: 48K on a 400/800
        bit COMTAB+F800
        bpl m7
        lda #48
m7      sta kb
        jsr PRINTF
        dta c'- %bk conventional',EOL,0
        dta a(kb)
        lda COMTAB2-3          ; extended: 16K a bank
        ldy #4
        jsr times
        jsr PRINTF
        dta c'- %dk extended',0
        dta a(kb)
        lda COMTAB2-3
        beq m9
        lda COMTAB2-2
        beq m8
        bmi m7a
        jsr unknown
        jmp m9
m7a     jsr PRINTF
        dta c' (Axlon)',0
        jmp m9
m8      jsr PRINTF
        dta c' (PORTB)',0
m9      jsr PRINTF
        dta EOL,0
        lda COMTAB2-4          ; high memory: 64K a bank
        beq m10
        ldy #6
        jsr times
        jsr PRINTF
        dta c'- %dk high ($%02x0000)',EOL,0
        dta a(kb,COMTAB2-5)
m10     rts

unknown jsr PRINTF
        dta c'unknown',EOL,0
        rts

* times: kb = A * 2^Y
times   ldx #0
        stx kb+1
t1      asl @
        rol kb+1
        dey
        bne t1
        sta kb
        rts

space   dta 0
kb      dta a(0)

        blk update address
        blk update symbols
