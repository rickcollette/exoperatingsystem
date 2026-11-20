; U1MB pre-lock boot stub for EOS's emulator test (tools/u1mb_test.py).
; This is not the U1MB BIOS. At reset it does only what booting the SDX
; slot needs: SDX module on at bank 0 (u_sdx), VBXE/sound/flash writes off
; (u_aux), then the configuration locked with 1088K memory (u_ctl $83: the
; OS from the OS banks) and the OS's reset vector. It sits in the U1MB flash at $50000,
; the bank the hardware runs before the configuration is locked; the test
; puts EOS_U1MB.rom at $00000 and an OS at $70000. -d:EXTCART=1: SDX off
; and the cartridge port on (an EOS cartridge starts instead); this
; assumes a U1MB does not pass its $D5E0 write on to the cartridge.
u_ctl   equ $D380
u_aux   equ $D381
u_coldf equ $D383
u_sdx   equ $D5E0

        opt h-f+
        org $C000
reset   sei
        cld
        lda #0
        sta u_coldf            ; (the cold start flag: seen)
.ifdef PROTECT
        lda #$80               ; flash writes protected (u1mb_test protected)
.endif
        sta u_aux
        lda #0
.ifdef EXTCART
        lda #$80               ; SDX off, the cartridge port on
.endif
        sta u_sdx              ; SDX on, bank 0
        ldx #thunk_e-thunk-1   ; the lock switches this ROM out: from RAM
cp      lda thunk,x
        sta $01FA,x
        dex
        bpl cp
        ldx #$83               ; locked, 1088K (bits 0-1: 64K 320K 576K 1088K)
        jmp $01FA
thunk   stx u_ctl
.ifdef EXTCART
        lda #0                 ; (Altirra passes $D5E0 to the cartridge port,
        sta $D500              ; where it switches a Maxflash off: bank 0
.endif                         ; again, once the U1MB passes $D5xx on)
        jmp ($FFFC)
thunk_e
nmi     rti

        org $FFFA
        dta a(nmi),a(reset),a(nmi)
