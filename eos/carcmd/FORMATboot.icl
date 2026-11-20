; EOS CAR: FORMAT, the SDFS/EOSFS boot loader for 128 or 256 byte sectors.
; The OS loads three 128 byte sectors at $3000. FORMAT fills bytes 9-41.
; Bytes 40-41 select the boot file's first sector map or extent list. The
; loader reads an Atari binary, calls INITAD after each segment, then calls
; RUNAD. It uses $2E00 and $2F00 for its data and map/list buffers.
; EOSFS_BOOT selects extent lists. The SDFS build prints ERROR - No DOS when
; no boot file is set; the smaller EOSFS build returns an OS boot error.

booter
; the boot record: 3 sectors to $3000, DOSINI $07E0, then the entry
        dta b(0,3),a($3000,$07E0)
.ifdef EOSFS_BOOT
        jmp ldrx.main
.else
        jmp ldr.main
.endif
        :33 dta 0              ; 9-41: the volume header
        :6 dta 0               ; 42-47: the variables

.ifndef EOSFS_BOOT
msg     dta d'ERROR - No DOS'      ; (screen codes)
.endif
dcb     dta b($31,1),c'R',b($40),a(0),b(7,0),a(0)

; rd: sector DAUX of drive 1 into page A; a read error ends the boot
rd      pha
        ldy #9
rd1
.ifdef EOSFS_BOOT
        lda ldrx.dcb,y
.else
        lda ldr.dcb,y
.endif
        sta DDEVIC_,y
        dey
        bpl rd1
        pla
        sta DBUF_+1
        lda bl_slen
        sta DBYT_
        bne rd2
        inc DBYT_+1            ; 256
rd2     jsr SIOV_
        bmi rd_err
        rts
rd_err  ldx bl_sp              ; back to the OS: boot error
        txs
        sec
retn    rts                    ; (INITAD and RUNAD until the file sets them)

; the start
main    tsx
        stx bl_sp
        lda #$60               ; DOSINI: an RTS
        sta $07E0
        lda $3000+40           ; the boot file
        sta bl_nm
        lda $3000+41
        sta bl_nm+1
.ifndef EOSFS_BOOT
        ora bl_nm
        beq none
.endif
        lda $3000+31           ; $80: 128 bytes, 0: 256
.ifndef EOSFS_BOOT
        beq m1
        cmp #$80
        bne none
m1      sta bl_slen
.else
        sta bl_slen            ; 128/256 only
.endif
        sta bl_mapi            ; (the map is read first)
        sta bl_emp
        inc bl_emp
.ifdef EOSFS_BOOT
        lda #<ldrx.retn
        sta RUNAD
        lda #>ldrx.retn
.else
        lda #<ldr.retn
        sta RUNAD
        lda #>ldr.retn
.endif
        sta RUNAD+1
seg     ldx #0                 ; a segment: start (after any $FFFF), end
hdr
.ifdef EOSFS_BOOT
        jsr ldrx.getb
.else
        jsr ldr.getb
.endif
        bcs done
        sta bl_ptr,x
        inx
        cpx #2
        bne hdr2
        and bl_ptr
        cmp #$FF
        beq seg
        lda bl_ptr
        ora bl_ptr+1
        beq done               ; zeros: past the end of the file
hdr2    cpx #4
        bne hdr
        lda bl_end
        cmp bl_ptr
        lda bl_end+1
        sbc bl_ptr+1
        bcc done               ; end below start: not a header
.ifdef EOSFS_BOOT
        lda #<ldrx.retn
        sta INITAD
        lda #>ldrx.retn
.else
        lda #<ldr.retn
        sta INITAD
        lda #>ldr.retn
.endif
        sta INITAD+1
byte
.ifdef EOSFS_BOOT
        jsr ldrx.getb
.else
        jsr ldr.getb
.endif
        bcs done
        ldy #0
        sta (bl_ptr),y
        lda bl_ptr
        cmp bl_end
        lda bl_ptr+1
        sbc bl_end+1
        bcs ini
        inc bl_ptr
        bne byte
        inc bl_ptr+1
        bne byte
ini
.ifdef EOSFS_BOOT
        jsr ldrx.goini
        jmp ldrx.seg
done    jsr ldrx.gorun
.else
        jsr ldr.goini
        jmp ldr.seg
done    jsr ldr.gorun
.endif
        clc
        rts
none
.ifndef EOSFS_BOOT
        ldy #13                ; the message on the first screen line,
nn1     lda ldr.msg,y          ; a key, a cold start
        sta (SAVMSC_),y
        dey
        bpl nn1
        lda #$FF
        sta CH_
key     lda CH_
        cmp #$FF
        beq key
        jmp COLDSV
.endif
goini   jmp (INITAD)
gorun   jmp (RUNAD)

; getb: the next byte of the file in A, C=0; C=1 at its end. Keeps X.
getb    lda bl_emp
        beq gb_hav
.ifdef EOSFS_BOOT
; EOSFS extent: first sector, count
        lda bl_cnt
        ora bl_cnt+1
        beq gb_ext
        inc DAUX_
        bne gb_read
        inc DAUX_+1
gb_read lda #BL_DATA
        jsr ldrx.rd
        lda bl_cnt
        bne gb_dec
        dec bl_cnt+1
gb_dec  dec bl_cnt
        lda #0
        sta bl_pos
        sta bl_emp
        beq gb_hav
gb_ext  ldy bl_mapi
        cpy bl_slen
        bne gb_ent
        lda bl_nm
        sta DAUX_
        lda bl_nm+1
        sta DAUX_+1
        ora DAUX_
        beq gb_end
        lda #BL_MAP
        jsr ldrx.rd
        lda BL_MAP*256
        sta bl_nm
        lda BL_MAP*256+1
        sta bl_nm+1
        ldy #4
gb_ent  lda BL_MAP*256,y
        sta DAUX_
        iny
        lda BL_MAP*256,y
        sta DAUX_+1
        iny
        lda BL_MAP*256,y
        sta bl_cnt
        iny
        lda BL_MAP*256,y
        sta bl_cnt+1
        iny
        sty bl_mapi
        lda bl_cnt
        ora bl_cnt+1
        beq gb_end
        jmp ldrx.gb_read
.else
        ldy bl_mapi            ; the next data sector from the map
        cpy bl_slen
        bne gb_ent
        lda bl_nm              ; the map is used up: the next one
        sta DAUX_
        ora bl_nm+1
        beq gb_end
        lda bl_nm+1
        sta DAUX_+1
        lda #BL_MAP
        jsr ldr.rd
        lda BL_MAP*256
        sta bl_nm
        lda BL_MAP*256+1
        sta bl_nm+1
        ldy #4
gb_ent  lda BL_MAP*256,y
        sta DAUX_
        lda BL_MAP*256+1,y
        sta DAUX_+1
        iny
        iny
        sty bl_mapi
        ora DAUX_
        beq gb_end             ; no more sectors
        lda #BL_DATA
        jsr ldr.rd
        lda #0
        sta bl_pos
        sta bl_emp
.endif
gb_hav  ldy bl_pos
        lda BL_DATA*256,y
        iny
        sty bl_pos
        cpy bl_slen            ; (256: Y is back at 0)
        bne gb_ok
        inc bl_emp
gb_ok   clc
        rts
gb_end  sec
        rts
lend
