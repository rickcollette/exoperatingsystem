* Tail of every cartridge bank: the cartridge trailer and the run entry.
*
* The OS may find any bank selected at a reset, so every bank carries the
* same trailer. tail_run selects the boot bank; the next instruction comes
* from the boot bank's identical copy of this code, which enters the boot
* code through its jump table.

        org $BFF0
tail_run
.ifdef SIDE
        lda #BK_BOOT|$40
        sta BANKLATCH
.elseif .def MYIDE2
        lda #BK_BOOT
        sta $D508
.elseif .def SIDE3
        lda #BK_BOOT|$C0
        sta $D5F9
.elseif .def BANKLATCH
        lda #BK_BOOT
        sta BANKLATCH
.else
        sta MAXBANK+BK_BOOT
.endif
        jmp CARTLO
tail_init rts

        org $BFFA
        dta a(tail_run)        ; run address
        dta b(0)               ; cartridge present
        dta b($04)             ; run the cartridge, no disk boot
        dta a(tail_init)       ; init address
