; EOS CAR:SORTDIR.OVL: loading it puts the sorting routines (SORTDIRp.asm:
; do_sort at $A000, move_entry at $A003) in the RAM under the cartridge,
; as Sparta Commander and SORTDIR users expect. The payload is assembled
; first (Makefile) and included here.
jhwctrl  equ $070F
src      equ $80
dst      equ $82

        blk reloc main
start   lda srca
        sta src
        lda srca+1
        sta src+1
        lda #<$A000
        sta dst
        lda #>$A000
        sta dst+1
        ldx #1                 ; the RAM under the cartridge
        jsr jhwctrl
        ldx #>(plen+255)
        ldy #0
cp1     lda (src),y
        sta (dst),y
        iny
        bne cp1
        inc src+1
        inc dst+1
        dex
        bne cp1
        ldx #0                 ; the library again
        jmp jhwctrl

srca    dta a(pay)
pay     ins '../../build/eos/car/SORTDIRp.bin'
plen    equ *-pay
        :256 dta 0             ; (whole pages are copied)

        blk update address
