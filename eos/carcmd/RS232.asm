; EOS CAR: RS232, load the R: handler from an Atari 850 or a P:R: Connection
;   RS232 [/R|F|E]
; The interface is polled (device $50, command '?'): its 12-byte answer is
; the SIO block that loads its bootstrap, which is then called at its
; address +6 and loads the handler above MEMLO. The program stays resident
; so that MEMLO keeps the handler. A beep follows a successful load.
; When HATABS has an R: already, nothing is loaded (/F loads anyway). /E
; loads nothing and says COM: installed, as SDX does (EOS has no COM:
; device yet). /R first sends the poll reset, so an interface that was
; loaded from before answers again. Words that are not switches are
; ignored.
U_GETPAR smb 'U_GETPAR'
U_FAIL   smb 'U_FAIL'
INSTALL  smb 'INSTALL'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

SIOV     equ $E459
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUFLO   equ $0304
DTIMLO   equ $0306
DBYTLO   equ $0308
DAUX1    equ $030A
HATABS   equ $031A
WARMST   equ $08
DOSINI   equ $0C
EOL      equ $9B
E_BADPAR equ 156

        blk reloc main
start   lda #0
        sta o_r
        sta o_f
        sta o_e
p1      jsr U_GETPAR
        beq p_end
        lda COMTAB+$21         ; other words are ignored
        cmp #'/'
        bne p1
        ldx #1                 ; R, F, E, several in one switch too
p2      lda COMTAB+$21,x
        cmp #EOL
        beq p1
        ldy #2
p3      cmp swch,y
        beq p4
        dey
        bpl p3
        bmi bad
p4      sta o_r,y
        inx
        bne p2
bad     lda #E_BADPAR
        jmp U_FAIL

p_end   lda o_e                ; /E: the R: there (if any) for COM:
        bne com
        lda o_f                ; an R: there already: kept
        bne load
        jsr hasr
        bcc h_have
        jmp load
com     jsr PRINTF
        dta c'COM: installed',EOL,0
h_have  rts

; hasr: C=0 when HATABS has R:
hasr    ldx #0
hr1     lda HATABS,x
        cmp #'R'
        beq hr2
        inx
        inx
        inx
        cpx #36
        bcc hr1
        rts
hr2     clc
        rts

load    lda o_r
        beq l1
        ldx #11                ; poll reset (no answer expected)
r1      lda rstdcb,x
        sta DDEVIC,x
        dex
        bpl r1
        jsr SIOV
l1      ldx #11                ; poll the interface
l2      lda polldcb,x
        sta DDEVIC,x
        dex
        bpl l2
        lda p_ans
        sta DBUFLO
        lda p_ans+1
        sta DBUFLO+1
        jsr SIOV
        bmi err
        ldx #11                ; its answer loads the bootstrap
l3      lda ans,x
        sta DDEVIC,x
        dex
        bpl l3
        jsr SIOV
        bmi err
        clc                    ; and the bootstrap loads the handler
        lda ans+4
        adc #6
        sta l_jsr+1
        lda ans+5
        adc #0
        sta l_jsr+2
l_jsr   jsr $FFFF
        bcs err0               ; the bootstrap could not load the handler
        lda WARMST             ; its init only hooks DOSINI; run that hook
        pha                    ; as a cold init so it installs R: without
        lda #0                 ; chaining into EOS's DOS initialization
        sta WARMST
        jsr init
        pla
        sta WARMST
        jsr hasr               ; loaded when R: is in HATABS now
        bcs err0
        dec INSTALL            ; MEMLO stays above the handler
        lda #$FD               ; the beep
        jmp PUTC
err0    lda #138
        bne err1
err     tya
err1    jmp U_FAIL

init    jmp (DOSINI)

o_r     dta 0
o_f     dta 0
o_e     dta 0
swch    dta c'RFE'
p_ans   dta a(ans)
ans     :12 dta 0
polldcb dta b($50,1,'?',$40),a(0),b(5,0),a(12),b(0,0)
rstdcb  dta b($4F,1,'O',$00),a(0),b(1,0),a(0),b($4F,$4F)

        blk update address
        blk update symbols
