; EOS Toolkit: TAIL, the last lines of a file
;   TAIL [-n count | -count] [filename]
; The last count lines (10 when none is given) to standard output. Without
; a name standard input is read. The input is kept in memory from the end
; of the program to MEMTOP; when it is full only the last count lines stay
; (when they alone fill it, the lines in its first half go).
U_GETPAR smb 'U_GETPAR'
U_ARGV   smb 'U_ARGV'
TOLOWER  smb 'TOLOWER'
FOPEN    smb 'FOPEN'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

        icl 'UNIXH.icl'
src      equ $80
dst      equ $82
pe       equ $84               ; the end of what is kept

        blk reloc main
start   lda #10
        sta unnum
        lda #0
        sta unnum+1
        jsr unargs
        bcs usage
        jsr unin
        bcs usage
        lda unnum              ; -n 0: nothing
        ora unnum+1
        beq t_end
        jsr unmem
        lda unbot
        sta pe
        lda unbot+1
        sta pe+1
t1      jsr FGETC
        bmi t_out
        ldy pe                 ; full?
        cpy untop
        bne t2
        ldy pe+1
        cpy untop+1
        bne t2
        pha
        jsr room
        pla
t2      ldy #0
        sta (pe),y
        inc pe
        bne t1
        inc pe+1
        jmp t1
t_out   jsr last               ; the last lines out
t3      lda src
        cmp pe
        bne t4
        lda src+1
        cmp pe+1
        beq t_end
t4      ldy #0
        lda (src),y
        jsr PUTC
        jsr incsrc
        jmp t3
t_end   lda unfiles
        beq t5
        jmp FCLOSE
t5      rts
usage   jsr PRINTF
        dta c'Use: tail [-n count] [filename]',EOL,0
        rts

* last: src at the start of the last count lines (an EOL at the very end
* ends the last line)
last    lda pe
        sta src
        lda pe+1
        sta src+1
        lda #0
        sta k
        sta k+1
        jsr atbot
        beq l_ret
        jsr decsrc
        lda (src),y
        cmp #EOL
        beq l1
        jsr incsrc
l1      jsr atbot
        beq l_ret
        jsr decsrc
        lda (src),y
        cmp #EOL
        bne l1
        inc k
        bne l2
        inc k+1
l2      lda k
        cmp unnum
        bne l1
        lda k+1
        cmp unnum+1
        bne l1
        jmp incsrc
l_ret   rts

* room: memory full: what is before the last count lines dropped; when
* they fill it, the first half and the rest of the line in it
room    jsr last
        jsr atbot
        bne r1
        lda pe                 ; src = the middle
        sec
        sbc unbot
        sta src
        lda pe+1
        sbc unbot+1
        lsr @
        ror src
        sta src+1
        lda src
        adc unbot              ; (C: the bit shifted out, no matter)
        sta src
        lda src+1
        adc unbot+1
        sta src+1
r0      lda src                ; up to an EOL (all of it when none)
        cmp pe
        bne r0a
        lda src+1
        cmp pe+1
        beq r1
r0a     lda (src),y
        jsr incsrc
        cmp #EOL
        bne r0
r1      lda unbot              ; src ... pe moved to the start
        sta dst
        lda unbot+1
        sta dst+1
r2      lda src
        cmp pe
        bne r3
        lda src+1
        cmp pe+1
        beq r4
r3      ldy #0
        lda (src),y
        sta (dst),y
        jsr incsrc
        inc dst
        bne r2
        inc dst+1
        jmp r2
r4      lda dst
        sta pe
        lda dst+1
        sta pe+1
        rts

* atbot: Z=1 when src is at the start; Y = 0
atbot   ldy #0
        lda src
        cmp unbot
        bne ab1
        lda src+1
        cmp unbot+1
ab1     rts
* decsrc, incsrc: src - 1, src + 1; keep A, Y
decsrc  pha
        lda src
        bne ds1
        dec src+1
ds1     dec src
        pla
        rts
incsrc  inc src
        bne is1
        inc src+1
is1     rts

unsw    equ *                  ; (no switches but -n)
UNSWN   equ 0
unval   dta c'n'
k       dta a(0)

        icl 'UNIX.icl'
unend   equ *

        blk update address
        blk update symbols
