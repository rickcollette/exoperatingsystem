; Snapshot helper for tools/sdxprobe.py: copies the RAM under the OS ROM
; ($C000-$CFFF, $D800-$FFFF) to $4000-$7FFF, then spins at 'done', where an
; Altirra breakpoint writes all 64K to the host.
PORTB   equ $D301
NMIEN   equ $D40E

        opt h+
        org $8000
start   sei
        lda #$00
        sta NMIEN
        lda PORTB
        pha
        and #$FE
        sta PORTB
        ldy #$C0
page    cpy #$D0
        bcc copy
        cpy #$D8
        bcc next
copy    sty src+2
        tya
        sec
        sbc #$80
        sta dst+2
        ldx #$00
src     lda $C000,X
dst     sta $4000,X
        inx
        bne src
next    iny
        bne page
        pla
        sta PORTB
        lda #$40
        sta NMIEN
        cli
done    jmp done

        run start
