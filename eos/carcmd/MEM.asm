; EOS CAR: MEM, the memory configuration
;   MEM [/X]
; Main: the lowest free address of main memory (MEMLO when MEM was
; started: this program is loaded there), Ext: the same for the system
; extended area (MALLOC $02 of no bytes gives where its next block would
; go), Use: the mode from COMTAB (BANKFLG, OSRMFLG), then the free banks
; (NBANKS). Each limit is given twice, as on SDX (drivers, then programs
; kept in memory); EOS has no programs kept in memory, so both are the same.
; /X adds the overlays (none), the type of extended memory, the tops and
; the free bytes of both areas, and the banks in all. The output starts
; with an empty line, as SDX's does.
U_SLASH  smb 'U_SLASH'
MALLOC   smb 'MALLOC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
T_       smb 'T_'

addpos   equ $0782
bytbuf   equ $0785
MEMTOP   equ $02E5
EOL      equ $9B

        blk reloc main
start   lda opta
        ldx opta+1
        ldy #2
        jsr U_SLASH
        lda here               ; main memory: where this program was loaded
        sta m_lo
        lda here+1
        sta m_lo+1
        lda MEMTOP
        sta m_top
        lda MEMTOP+1
        sta m_top+1
        lda #0                 ; the system extended area: MALLOC $02, no
        sta bytbuf             ; bytes
        sta bytbuf+1
        ldx #$02
        jsr MALLOC
        bmi e_main
        cpx #$02
        bne e_main
        lda addpos
        sta x_lo
        lda addpos+1
        sta x_lo+1
        lda #<$7FFF            ; its top: banked $4000-$7FFF, else under
        sta x_top              ; the OS ROM up to $FFBF
        lda #>$7FFF
        sta x_top+1
        bit COMTAB+$1E
        bmi e_ok
        lda #<$FFBF
        sta x_top
        lda #>$FFBF
        sta x_top+1
        jmp e_ok
e_main  lda m_lo               ; taken from main memory (no USE)
        sta x_lo
        lda m_lo+1
        sta x_lo+1
        lda m_top
        sta x_top
        lda m_top+1
        sta x_top+1
e_ok    lda usena              ; the mode
        sta usep
        lda usena+1
        sta usep+1
        bit COMTAB+$1E
        bmi u_ok
        lda useno
        sta usep
        lda useno+1
        sta usep+1
        bit COMTAB+$1F
        bmi u_ok
        lda usenn
        sta usep
        lda usenn+1
        sta usep+1
u_ok    lda COMTAB+$1D         ; free banks
        sta nfree
        sec                    ; immediately usable main-memory bytes
        lda m_top
        sbc m_lo
        sta m_free
        lda m_top+1
        sbc m_lo+1
        sta m_free+1
        lda #0                 ; free bank bytes = nfree * 16384
        sta bfree
        sta bfree+2
        sta bfree+3
        lda nfree
        and #$03
        ldx #6
bf1     asl @
        dex
        bne bf1
        sta bfree+1
        lda nfree
        lsr @
        lsr @
        sta bfree+2
        lda optx
        bne longf
        jsr PRINTF
        dta EOL,c'Main: $%4x,$%4x',EOL
        dta c' Ext: $%4x,$%4x',EOL
        dta c' Use: %p',EOL
        dta c'Free: %d main bytes',EOL
        dta c'%b Ext banks free (%l bytes)',EOL,EOL,0
        dta a(m_lo,m_lo,x_lo,x_lo,usep,m_free,nfree,bfree)
        rts

* MEM /X
longf   lda m_top              ; without a cartridge (X): $2000 more
        sta m_topx
        clc
        lda m_top+1
        adc #$20
        sta m_topx+1
        lda m_free
        sta m_freex
        clc
        lda m_free+1
        adc #$20
        sta m_freex+1
        sec
        lda x_top
        sbc x_lo
        sta x_free
        lda x_top+1
        sbc x_lo+1
        sta x_free+1
        lda COMTAB+$1C         ; banks in all: 2 to the number of PORTB bits
        and #$EF               ; in PBMASK, bit 4 aside
        ldx #0
        ldy #8
b1      asl @
        bcc b2
        inx
b2      dey
        bne b1
        lda #0
        sta ntot+1
        txa
        beq b4
        lda #1
b3      asl @
        rol ntot+1
        dex
        bne b3
b4      sta ntot
        lda T_+6               ; the PORTB value of memory $02
        sta pbv
        lda ntot               ; KB: 16 per bank
        sta ktot
        lda ntot+1
        sta ktot+1
        lda nfree
        sta kfree
        lda #0
        sta kfree+1
        ldx #4
b5      asl ktot
        rol ktot+1
        asl kfree
        rol kfree+1
        dex
        bne b5
        jsr PRINTF
        dta EOL,c'Main: $%4x,$%4x,$0000',EOL
        dta c' Ext: $%4x,$%4x,$0000',EOL,0
        dta a(m_lo,m_lo,x_lo,x_lo)
        jsr PRINTF
        dta c' Use: %p, PORTB $%2x',EOL
        dta c' Top: $%4x ($%4x),$%4x',EOL
        dta c'Free: %d (%d),%d',EOL,EOL,0
        dta a(usep,pbv,m_top,m_topx,x_top,m_free,m_freex,x_free)
        jsr PRINTF
        dta c'%d Ext banks total (%d KB)',EOL
        dta c'%b Ext banks free  (%d KB)',EOL,EOL,0
        dta a(ntot,ktot,nfree,kfree)
        rts

opta    dta a(optx)
optx    dta 0,c'X'
here    dta a(start)
usena   dta a(s_bank)
useno   dta a(s_osr)
usenn   dta a(s_none)
s_bank  dta c'BANKED',0
s_osr   dta c'OSRAM',0
s_none  dta c'NONE',0
usep    dta a(0)
m_lo    dta a(0),0
m_top   dta a(0),0
m_topx  dta a(0),0
m_free  dta a(0),0
m_freex dta a(0),0
x_lo    dta a(0),0
x_top   dta a(0),0
x_free  dta a(0),0
nfree   dta 0,0,0
ntot    dta a(0),0
ktot    dta a(0),0
kfree   dta a(0),0
bfree   dta 0,0,0,0
pbv     dta 0,0,0

        blk update address
        blk update symbols
