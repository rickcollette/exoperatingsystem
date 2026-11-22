; EOS CAR: KEY, the keyboard buffer
;   KEY [ON|OFF]
; The first call stays resident: a keyboard interrupt routine keeps the
; keys pressed while a key is still waiting in CH (up to 32 of them), and a
; deferred vertical blank routine hands them to CH one by one as it is
; emptied. The symbol @KEY (added with S_ADD) serves the later calls:
; A = 0 turns the buffer off, 1 on, $FF leaves it; A comes back as the
; state (0 or 1).
; The first call installs it off (unless ON is given); every call shows
; the state. Words other than ON and OFF are ignored, as is a second one.
; Auto-repeated keys go to CH as the OS makes them (not buffered).
; Control-1, Help and the 1200XL function keys go to the OS as they are.
PRINTF   smb 'PRINTF'
U_GETPAR smb 'U_GETPAR'
INSTALL  smb 'INSTALL'
S_ADDIZ  smb 'S_ADDIZ'
S_ADD    smb 'S_ADD'
SYMBOL   smb 'SYMBOL'
EXTENDED smb 'EXTENDED'
COMTAB   smb 'COMTAB'

jfsymbol equ $07EB
ATRACT   equ $4D
CRITIC   equ $42
VKEYBD   equ $0208
VVBLKD   equ $0224
SRTIMR   equ $022B
KEYDEL   equ $02F1
CH1      equ $02F2
CH       equ $02FC
KBCODE   equ $D209
EOL      equ $9B
NBUF     equ 32

        blk reloc main
start   lda #$FF               ; the parameter: $FF none, 1 ON, 0 OFF
        sta want
        jsr U_GETPAR
        beq s2
        lda #1                 ; ON or OFF; other words do nothing
        lda COMTAB+$21
        and #$DF
        tax
        lda COMTAB+$22
        and #$DF
        tay
        lda #1
        cpx #'O'
        bne s2
        cpy #'N'
        bne s1
        ldy COMTAB+$23
        cpy #EOL
        beq s1a
        bne s2
s1      tya
        and #$DF
        tay
        cpy #'F'
        bne s2
        lda COMTAB+$23
        and #$DF
        tay
        cpy #'F'
        bne s2
        ldy COMTAB+$24
        cpy #EOL
        bne s2
        lda #0
s1a     sta want
s2      lda p_name             ; installed already: through @KEY
        ldx p_name+1
        jsr jfsymbol
        beq inst
        sta s_jsr+1
        stx s_jsr+2
        lda want
s_jsr   jsr $FFFF
        jmp show

inst    lda want               ; installed off unless ON is given
        cmp #1
        beq i1
        lda #0
i1      sta kon
        jsr hook
        lda p_hook
        ldx p_hook+1
        jsr S_ADDIZ
        ldx #7                 ; the symbol @KEY
i2      lda s_name,x
        sta SYMBOL+2,x
        dex
        bpl i2
        lda p_ko
        sta SYMBOL+$0B
        lda p_ko+1
        sta SYMBOL+$0C
        lda #0
        sta EXTENDED
        jsr S_ADD
        dec INSTALL
        lda kon
show    cmp #0
        beq sh_off
        jsr PRINTF
        dta c'KEY is ON',EOL,0
        rts
sh_off  jsr PRINTF
        dta c'KEY is OFF',EOL,0
        rts

; ---- resident ---------------------------------------------------------------

; @KEY: A = 0 off, 1 on, $FF as it is; A = the state
keyon   cmp #$FF
        beq ko1
        sta kon
        lda #0                 ; switching empties the buffer
        sta khead
        sta ktail
ko1     lda kon
        rts

; hook: the interrupt and VBI routines in (again after a RESET)
hook    lda VKEYBD             ; not twice
        cmp p_kb
        bne h1
        lda VKEYBD+1
        cmp p_kb+1
        beq h_ret
h1      lda #0
        sta khead
        sta ktail
        sei
        lda VKEYBD
        sta k_os+1
        lda VKEYBD+1
        sta k_os+2
        lda p_kb
        sta VKEYBD
        lda p_kb+1
        sta VKEYBD+1
        cli
        lda CRITIC             ; no deferred VBI while the vector changes
        pha
        lda #1
        sta CRITIC
        lda VVBLKD
        sta v_os+1
        lda VVBLKD+1
        sta v_os+2
        lda p_vb
        sta VVBLKD
        lda p_vb+1
        sta VVBLKD+1
        pla
        sta CRITIC
h_ret   rts

; the keyboard interrupt (A is on the stack, as the OS calls it)
kbirq   lda kon
        beq k_os
        lda CH                 ; nothing waiting: the OS takes the key
        cmp #$FF
        beq k_os
        lda KBCODE
        cmp #$9F               ; Control-1
        beq k_os
        and #$3F
        cmp #$11               ; Help
        beq k_os
        cmp #$03               ; F1-F4
        beq k_os
        cmp #$04
        beq k_os
        cmp #$13
        beq k_os
        cmp #$14
        beq k_os
        lda KBCODE
        cmp CH1                ; the same key bouncing
        bne k1
        lda KEYDEL
        bne k_done
k1      lda KBCODE
        sta CH1
        txa
        pha
        lda ktail              ; into the buffer, unless it is full
        tax
        clc
        adc #1
        and #NBUF-1
        cmp khead
        beq k2
        sta ktail
        lda KBCODE
        sta kbuf,x
k2      pla
        tax
        lda #3
        sta KEYDEL
        lda #$30
        sta SRTIMR
        lda #0
        sta ATRACT
k_done  pla
        rti
k_os    jmp $FFFF              ; the old VKEYBD (set at install: a JMP () through
                               ; a vector at $xxFF would take the wrong high byte)

; the deferred VBI: the next key into CH once it is free
vbi     lda kon
        beq v_os
        lda CH
        cmp #$FF
        bne v_os
        ldx khead
        cpx ktail
        beq v_os
        lda kbuf,x
        sta CH
        inx
        txa
        and #NBUF-1
        sta khead
v_os    jmp $FFFF              ; the old VVBLKD (set at install)

want    dta 0
kon     dta 0
khead   dta 0
ktail   dta 0
p_kb    dta a(kbirq)
p_vb    dta a(vbi)
p_hook  dta a(hook)
p_name  dta a(s_name)
p_ko    dta a(keyon)
s_name  dta c'@KEY    '
kbuf    :NBUF dta 0

        blk update address
        blk update symbols
