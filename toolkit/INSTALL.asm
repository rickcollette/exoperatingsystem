; EOS Toolkit: INSTALL, programs kept in memory for good
;   INSTALL file ...
; Each file is loaded and not run (U_LOAD, FLAG $80), as LOAD does, and
; INSTALL is set, so that when this program ends the loader keeps what
; was loaded: an unload (LOAD alone) does not free it. This program is
; at a fixed address below the free memory, so that it takes none of it.
U_GETPAR smb 'U_GETPAR'
U_LOAD   smb 'U_LOAD'
FLAG     smb 'FLAG'
INSTALL  smb 'INSTALL'

        blk sparta $0400
start   jsr U_GETPAR
        beq done
        lda #$80               ; load only
        sta FLAG
        jsr U_LOAD
        lda #$FF               ; and keep it
        sta INSTALL
        bne start
done    rts

        blk update symbols
