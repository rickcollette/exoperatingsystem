; EOS CAR: APPEND, a drive, directory or device at the end of $PATH
;   APPEND d: | pathname | device
; The rest of the command line, in capitals, is added to $PATH after a
; semicolon (also when $PATH is empty or missing: ";A:"). When $PATH
; has that entry already, nothing changes. No parameter: 156.
U_GETPAR smb 'U_GETPAR'
GETENV   smb 'GETENV'
PUTENV   smb 'PUTENV'
U_FAIL   smb 'U_FAIL'
COMTAB   smb 'COMTAB'

LBUFF    equ $0580
EOL      equ $9B

        blk reloc main
start   lda COMTAB+$0A         ; the parameter: the rest of the line
        sta es
        jsr U_GETPAR
        bne s0
        lda #156               ; no parameter
        jmp U_FAIL
s0      ldy es
        ldx #0
s0a     lda COMTAB+$3F,y
        cmp #' '
        bne s0b
        iny
        bne s0a
s0b     lda COMTAB+$3F,y
        cmp #'a'
        bcc s0c
        cmp #'z'+1
        bcs s0c
        and #$DF
s0c     sta ent,x
        cmp #EOL
        beq s0d
        iny
        inx
        cpx #127
        bcc s0b
        lda #EOL
        sta ent,x
s0d     ldx #4                 ; PATH=
s1      lda pname,x
        sta buf,x
        dex
        bpl s1
        lda #'='
        sta buf+4
        lda pna
        ldx pna+1
        jsr GETENV
        php
        ldy #5
        plp
        bmi s4                 ; no $PATH
        ldx #0                 ; the old value, each entry compared
s2      stx es                 ; an entry starts
        lda #0
        sta diff
s3      lda LBUFF,x
        cmp #';'
        beq s3e
        cmp #EOL
        beq s3e
        stx ex
        txa                    ; its character against ent
        sec
        sbc es
        tax
        lda ent,x
        ldx ex
        cmp LBUFF,x
        beq s3a
        inc diff
s3a     lda LBUFF,x
        sta buf,y
        iny
        inx
        cpy #250
        bcc s3
        bcs toolong
s3e     sta sep                ; the entry ends: the same as ent?
        stx ex
        txa
        sec
        sbc es
        tax
        lda ent,x
        ldx ex
        cmp #EOL
        bne s3f
        lda diff
        beq same
s3f     lda sep
        cmp #EOL
        beq s4
        sta buf,y
        iny
        inx
        bne s2
same    rts                    ; already there
s4      lda #';'
        sta buf,y
        iny
        ldx #0
s6      lda ent,x
        sta buf,y
        cmp #EOL
        beq s7
        iny
        inx
        cpy #255
        bcc s6
toolong lda #156
        jmp U_FAIL
s7      lda bfa
        ldx bfa+1
        jsr PUTENV
        bmi toolong
        rts

pna     dta a(pname)
bfa     dta a(buf)
pname   dta c'PATH',EOL
es      dta 0
ex      dta 0
diff    dta 0
sep     dta 0
ent     :128 dta 0
buf     :256 dta 0

        blk update address
        blk update symbols
