; EOS CAR: shared parts of PEEK, POKE, MDUMP, DUMP, BLOAD
; (included at the end of a program, after its code)
;   getadr  the next parameter as an address (U_GETADR)
;   dl_*    the lines of a dump, as SDX writes them
;   outch   one character as SDX shows it

; getadr: the next parameter as [index:]address or a symbol.
; A=0 (Z=1): there is none, or it is not an address. Else ad = the
; address, ad_ix = the memory index (for a 24-bit address its bits 16-23),
; ad_ixg <> 0 when an index was given.
getadr  jsr U_GETADR
        beq ga_no
        sta ad
        stx ad+1
        sty ad_ix
        lda #0
        rol @                  ; a 24-bit address: shown as an index
        sta ad_ixg
        ldx #0
ga1     lda COMTAB+$21,x       ; the parameter as typed: an index?
        cmp #EOL
        beq ga3
        cmp #':'
        bne ga2
        sta ad_ixg
ga2     inx
        bne ga1
ga3     lda #1
        rts
ga_no   lda #0
        rts

; A dump: dl_start once (an empty line first), then for each line dl_head
; (the address dl_a), dl_hex for each byte (A; kept for the characters),
; dl_tail (the columns of the missing bytes, a blank, the characters):
; AAAA- HH HH HH HH HH HH HH HH cccccccc
dl_start lda #0
        sta dl_n
        lda #EOL
        jmp PUTC
dl_head lda #0
        sta dl_n
        jsr PRINTF
        dta c'%4x-',0
        dta a(dl_a)
        rts
dl_hex  ldx dl_n
        sta dl_b,x
        sta dl_v
        inc dl_n
        jsr PRINTF
        dta c' %2x',0
        dta a(dl_v)
        rts
dl_tail ldx dl_n
dt1     cpx #8
        bcs dt2
        jsr PRINTF
        dta c'   ',0
        inx
        bne dt1
dt2     lda #' '
        jsr PUTC
        ldx #0
dt3     cpx dl_n
        bcs dt4
        stx dl_x
        lda dl_b,x
        jsr outch
        ldx dl_x
        inx
        bne dt3
dt4     lda #EOL
        jmp PUTC

; outch: the character A as SDX shows it, by dl_dot:
;  0 (MDUMP, DUMP) as it is, but EOL as ESC ($1B);
;  1 (DUMP /A) without inverse; $00-$1F, $7F and $80-$9F as dots, and
;    $7D, $7E too unless the output is the screen;
;  2 (PEEK) as it is, EOL too.
; On the screen (CON:) the screen editor's control characters get an ESC
; before them, so their symbols are shown as SDX shows them.
outch   ldx dl_dot
        beq oc0
        dex
        bne oc1
        cmp #$A0               ; DUMP /A
        bcs oc_inv
        cmp #$80
        bcs oc_dot
oc_inv  and #$7F
        cmp #$20
        bcc oc_dot
        cmp #$7D
        bcc oc1
        cmp #$7F               ; $7D, $7E: shown on the screen, dots in a
        beq oc_dot             ; file
        ldx COMTAB+6
        ldy $0740,x
        cpy #$30
        bcc oc_dot
        cpy #$40
        bcc oc1
oc_dot  lda #'.'
        jmp PUTC
oc0     cmp #EOL
        bne oc1
        lda #$1B
oc1     cmp #EOL
        beq oc3
        sta dl_c
        and #$7F
        cmp #$1B
        bcc oc2
        cmp #$20
        bcc oc_esc
        cmp #$7D
        bcc oc2
oc_esc  ldx COMTAB+6           ; to the screen: ESC first
        lda $0740,x
        and #$F0
        cmp #$30
        bne oc2
        lda #$1B
        jsr PUTC
oc2     lda dl_c
oc3     jmp PUTC

ad      dta a(0),0
ad_ix   dta 0,0,0
ad_ixg  dta 0
dl_a    dta a(0),0
dl_n    dta 0
dl_b    :8 dta 0
dl_x    dta 0
dl_v    dta 0,0,0
dl_c    dta 0
dl_dot  dta 0
