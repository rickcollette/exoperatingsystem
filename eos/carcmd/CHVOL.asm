; EOS CAR: CHVOL, a disk's volume name
;   CHVOL [d:]volname
; The name is the rest of the command line as typed (spaces, lower case
; and inverse characters kept, leading blanks skipped), after the last
; '>', '<' or backslash, up to 8 characters; it is space padded and may
; be empty when a drive is given. No parameter at all is 156. The
; kernel's volume name call (20) writes it.
U_GEFINA smb 'U_GEFINA'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

jkernel  equ $0703
name     equ $0762
BSLASH   equ $5C
EOL      equ $9B

        blk reloc main
start   ldy COMTAB+$0A         ; the rest of the line (LBUF from BUFOFF)
s0      lda COMTAB+$3F,y
        cmp #' '
        bne s1
        iny
        bne s0
s1      cmp #EOL               ; no parameter
        bne s1a
        lda #156
        jmp U_FAIL
s1a     sty pos
        ldx #0                 ; a device: up to 5 letters and digits, ':'
s2      lda COMTAB+$3F,y
        cmp #':'
        beq s_dev
        jsr upper
        cmp #'0'
        bcc s_nodev
        cmp #'9'+1
        bcc s3
        cmp #'A'
        bcc s_nodev
        cmp #'Z'+1
        bcs s_nodev
s3      sta spec,x
        iny
        inx
        cpx #6
        bcc s2
s_nodev ldx #0                 ; none: the current drive
        ldy pos
        jmp s_dv2
s_dev   lda #':'
        sta spec,x
        inx
        iny
s_dv2   lda #EOL
        sta spec,x
        sty pos                ; a path before the name is left out
s_p1    lda COMTAB+$3F,y
        cmp #EOL
        beq s_p3
        iny
        cmp #'>'
        beq s_p2
        cmp #'<'
        beq s_p2
        cmp #BSLASH
        bne s_p1
s_p2    sty pos
        jmp s_p1
s_p3    ldy pos
        ldx #0                 ; the name, up to 8 characters
s4      lda COMTAB+$3F,y
        cmp #EOL
        beq s5
        sta vol,x
        iny
        inx
        cpx #8
        bcc s4
s5      stx vlen
        lda #EOL
        sta vol,x
        lda spa
        sta FILE_P
        lda spa+1
        sta FILE_P+1
        jsr U_GEFINA           ; device
        ldx #10                ; name: the volume name, space padded
        lda #' '
s7      sta name,x
        dex
        bpl s7
        ldx vlen
s8      dex
        bmi s9
        lda vol,x
        sta name,x
        jmp s8
s9      ldy #20                ; the kernel's volume name call
        jsr jkernel
        bpl s10
        jmp U_FAIL
s10     jsr PRINTF
        dta c'Volume Name changed to %s',EOL,0
        dta a(vol)
        rts

* upper: A in capitals
upper   cmp #'a'
        bcc up1
        cmp #'z'+1
        bcs up1
        and #$DF
up1     rts

spa     dta a(spec)
pos     dta 0
vlen    dta 0
spec    :8 dta 0
vol     :9 dta 0

        blk update address
        blk update symbols
