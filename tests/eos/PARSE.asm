; EOS oracle test: command line parsers. The first parameter picks what
; the rest is given to:
;   A  U_GETADR on each      T  U_TOKEN on each     F  U_FSPEC on each
;   P  U_GEFINA, U_PATH      O  U_GONOFF on each    E  U_PERROR, CKSPEC
PRINTF   smb 'PRINTF'
U_GETPAR smb 'U_GETPAR'
U_GETADR smb 'U_GETADR'
U_TOKEN  smb 'U_TOKEN'
U_FSPEC  smb 'U_FSPEC'
U_GEFINA smb 'U_GEFINA'
U_PATH   smb 'U_PATH'
U_GONOFF smb 'U_GONOFF'
U_PERROR smb 'U_PERROR'
CKSPEC   smb 'CKSPEC'
COMTAB   smb 'COMTAB'

EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR
        bne s1
        rts
s1      lda COMTAB+$21
        cmp #'A'
        jeq m_adr
        cmp #'T'
        jeq m_tok
        cmp #'F'
        jeq m_fsp
        cmp #'P'
        jeq m_path
        cmp #'O'
        jeq m_onoff
        cmp #'E'
        jeq m_err
        rts

* A: U_GETADR on each parameter
m_adr   jsr U_GETADR
        beq a2
        sta v
        stx v+1
        sty vy
        lda #0
        rol @
        sta vc
        jsr PRINTF
        dta c'a %4x y%2x c%d',EOL,0
        dta a(v,vy,vc)
        jmp m_adr
a2      jsr U_GETPAR           ; not an address: show it, go on
        beq a3
        jsr cpf
        jsr PRINTF
        dta c'a no [%s]',EOL,0
        dta a(nbuf)
        jmp m_adr
a3      rts

* T: U_TOKEN on each parameter
m_tok   jsr U_GETPAR
        beq t2
        lda tokadr
        ldx tokadr+1
        jsr U_TOKEN
        sta v
        lda #0
        rol @
        sta vc
        jsr cpf
        jsr PRINTF
        dta c't [%s] c%d a%2x',EOL,0
        dta a(nbuf,vc,v)
        jmp m_tok
t2      rts

* F: U_FSPEC on each parameter
m_fsp   jsr U_GETPAR
        beq f2
        jsr U_FSPEC
        jsr cpf
        jsr PRINTF
        dta c'f [%s] %d',EOL,0
        dta a(nbuf,fl)
        jmp m_fsp
f2      rts

* P: U_GEFINA, then U_PATH at offset 2 of buf
m_path  jsr U_GETPAR
        beq p2
        jsr U_GEFINA
        lda #'<'
        sta buf
        sta buf+1
        lda bufadr
        ldx bufadr+1
        ldy #2
        jsr U_PATH
        sty vy
        jsr PRINTF
        dta c'p [%s] y%2x',EOL,0
        dta a(buf,vy)
        jmp m_path
p2      rts

* O: U_GONOFF on each parameter (one that is neither ends the program)
m_onoff jsr U_GONOFF
        lda #0
        rol @
        sta vc
        jsr PRINTF
        dta c'o c%d',EOL,0
        dta a(vc)
        jmp m_onoff

* E: U_PERROR for some codes, CKSPEC for some characters
m_err   ldx #0
e1      stx vi
        lda codes,x
        tay
        lda bufadr
        ldx bufadr+1
        jsr U_PERROR
        jsr PRINTF
        dta c'e [%s]',EOL,0
        dta a(buf)
        ldx vi
        inx
        cpx #4
        bne e1
        ldx #0
e2      stx vi
        lda chars,x
        sta v
        jsr CKSPEC
        php
        pla
        lsr @
        and #1
        sta vc
        jsr PRINTF
        dta c'k %c z%d',EOL,0
        dta a(v,vc)
        ldx vi
        inx
        cpx #7
        bne e2
        rts

* cpf: COMFNAM to nbuf, FILLEN to fl
cpf     ldx #0
cp1     lda COMTAB+$21,x
        sta nbuf,x
        inx
        cmp #EOL
        beq cp2
        cpx #30
        bcc cp1
cp2     lda COMTAB+$1A
        sta fl
        rts

fl      dta 0,0
nbuf    :32 dta 0
v       dta 0,0,0,0
vy      dta 0,0
vc      dta 0,0
vi      dta 0
codes   dta 170,130,1,250
chars   dta c':>',$5C,c'<A.*'
tokadr  dta a(toks)
toks    dta c'ON',c'E'*,c'TW',c'O'*,c'THRE',c'E'*,c'X'*,0
bufadr  dta a(buf)
buf     :80 dta 0

        blk update address
        blk update symbols
