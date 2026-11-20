; EOS Toolkit: U1MBCHK, structural validation of an EOS U1MB slot image
;   U1MBCHK [d:][path]EOS_U1MB.ROM
; Requires exactly 40 raw 8 KiB banks (320 KiB) and checks the common reset
; tail at the end of all banks. It does not program flash.
U_GETPAR smb 'U_GETPAR'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FSEEK    smb 'FSEEK'
FCLOSE   smb 'FCLOSE'
PRINTF   smb 'PRINTF'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
dentry   equ $0789
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B
TAIL     equ $1FF0
STRIDE   equ $2000

        blk reloc main
start   jsr U_GETPAR
        bne s0
        jmp usage
s0
        lda #4
        sta mode
        lda #0
        sta scan
        jsr FOPEN
        ldx #2                 ; the length: 3 bytes (dentry+6: the name)
l0      lda dentry+3,x
        sta size,x
        dex
        bpl l0
        lda size
        ora size+1
        beq s1
        jmp bad_size
s1     lda size+2
        cmp #5
        beq s2
        jmp bad_size
s2
s3

        lda #<TAIL
        sta addpos
        lda #>TAIL
        sta addpos+1
        lda #0
        sta addpos+2
        sta addpos+3
        jsr FSEEK
        lda p_reference
        sta addpos
        lda p_reference+1
        sta addpos+1
        lda #16
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jsr FREAD
        lda bytbuf
        cmp #16
        beq t0
        jmp bad_tail
t0

        lda #1
        sta bank
        lda #<(TAIL+STRIDE)
        sta offset
        lda #>(TAIL+STRIDE)
        sta offset+1
        lda #0
        sta offset+2
        sta offset+3
next    lda offset
        sta addpos
        lda offset+1
        sta addpos+1
        lda offset+2
        sta addpos+2
        lda offset+3
        sta addpos+3
        jsr FSEEK
        lda p_actual
        sta addpos
        lda p_actual+1
        sta addpos+1
        lda #16
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jsr FREAD
        lda bytbuf
        cmp #16
t1      beq t2
        jmp bad_tail
t2
        ldx #15
c0      lda reference,x
        cmp actual,x
        beq c1
        jmp bad_tail
c1
        dex
        bpl c0
        inc bank
        lda bank
        cmp #40
        beq good
        clc
        lda offset
        adc #<STRIDE
        sta offset
        lda offset+1
        adc #>STRIDE
        sta offset+1
        lda offset+2
        adc #0
        sta offset+2
        lda offset+3
        adc #0
        sta offset+3
        jmp next

good    jsr FCLOSE
        jsr PRINTF
        dta c'U1MB image: 40 banks, common reset tail OK',EOL,0
        rts
bad_size
        jsr FCLOSE
        jsr PRINTF
        dta c'U1MB image must be exactly 320 KiB raw ROM',EOL,0
        rts
bad_tail
        jsr FCLOSE
        jsr PRINTF
        dta c'U1MB bank tail check failed',EOL,0
        rts
usage   jsr PRINTF
        dta EOL,c'Use: U1MBCHK [d:][path]EOS_U1MB.ROM',EOL,0
        dta c'Validates the raw 320 KiB image; does not flash it.',EOL,0
        rts

size    dta 0,0,0,0
bank    dta 0
offset  dta 0,0,0,0
reference :16 dta 0
actual    :16 dta 0

p_actual  dta a(actual)
p_reference dta a(reference)

        blk update address
        blk update symbols
