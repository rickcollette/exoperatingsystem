; EOS Toolkit: FSTRUCT, the structure of a binary file
;   FSTRUCT [d:][path]filename.ext
; The file's size, then each header ($FFFF, and SpartaDOS X's $FFF9 to
; $FFFE) and segment as found: addresses, lengths, run and init
; addresses, relocatable blocks, fixups and symbols. On a screen of 64
; columns or more each line starts with its offset in the file. Data
; that is no header and follows no segment: 152.
U_GETATR smb 'U_GETATR'
U_FAIL   smb 'U_FAIL'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
FILELENG smb 'FILELENG'
FTELL    smb 'FTELL'
FSEEK    smb 'FSEEK'
PRINTF   smb 'PRINTF'

RMARGN   equ $53
mode     equ $0778
addpos   equ $0782
bytbuf   equ $0785
EOL      equ $9B
E_NOBIN  equ 152

        blk reloc main
start   lda #$A0
        jsr U_GETATR
        lda #4
        sta mode
        jsr FOPEN
        jsr FILELENG
        jsr PRINTF
        dta EOL,c'Size: $%6x (%e) bytes',EOL,EOL,0
        dta a(addpos,addpos)

* a header, or the start of a segment after one
loop    jsr readw
        bmi eof
        lda hd+1
        cmp #$FF
        bne seg
        lda hd
        cmp #$F9
        bcc seg
        sbc #$F9               ; $FFF9-$FFFF: 0-6
        asl @
        sta kind
        tax
        lda names,x
        sta hname
        lda names+1,x
        sta hname+1
        lda #0
        sta seen
        jsr prefix
        jsr PRINTF
        dta c'Head: $%4x (%p)',EOL,0
        dta a(hd,hname)
        ldx kind
        jmp go
seg     lda #E_NOBIN           ; no header: only after a segment
        bit seen
        bpl fail
        lda hd
        sta b0
        lda hd+1
        sta b1
        ldx #14
go      lda hands,x
        sta call+1
        lda hands+1,x
        sta call+2
        jsr call
        beq loop
        bmi fail
eof     jsr FCLOSE             ; A = 1: the file ends
        jsr PRINTF
        dta EOL,c'End of file',EOL,0
        rts
fail    pha
        jsr FCLOSE
        pla
        jmp U_FAIL
call    jmp $FFFF              ; (the operand set above: no JMP () through a
                               ; vector that could sit at $xxFF)

* the handlers: A = 0 next header, 1 the end, else an error (N=1)
* std: $FFFF and $FFFA, start and end; with no header start in b0
std     ldx #0
        ldy #2
        jsr readx
        bmi st_bad
st0     ldx #2                 ; (no header: from here)
        ldy #2
        jsr readx
        bpl st1
st_bad  lda #E_NOBIN
        rts
st1     lda #$80
        sta seen
        sec                    ; len = end - start + 1
        lda b2
        sbc b0
        sta len
        lda b3
        sbc b1
        sta len+1
        inc len
        bne st2
        inc len+1
st2     jsr setoff
        jsr prefix
        jsr PRINTF
        dta c' Seg: $%4x-$%4x Len: $%4x (%d)',EOL,0
        dta a(b0,b2,len,len)
        lda b1                 ; at $02E0 or $02E2: the run, init address
        cmp #2
        bne skip
        lda b0
        cmp #$E0
        beq st3
        cmp #$E2
        bne skip
st3     jsr readw
        bmi end1
        lda b0
        cmp #$E2
        beq st4
        jsr prefix
        jsr PRINTF
        dta c' Run: $%4x',EOL,0
        dta a(hd)
        lda b2                 ; up to $02E3: the init address too
        cmp #$E3
        bcc skip
        jsr readw
        bmi end1
st4     jsr prefix
        jsr PRINTF
        dta c' Ini: $%4x',EOL,0
        dta a(hd)
* skip: past the rest of the segment (len bytes)
skip    jsr FTELL
        clc
        lda addpos
        adc len
        sta addpos
        lda addpos+1
        adc len+1
        sta addpos+1
        bcc sk1
        inc addpos+2
sk1     jsr FSEEK
* setoff: the offset for the next line; A = 0
setoff  jsr FTELL
        ldx #2
so1     lda addpos,x
        sta off,x
        dex
        bpl so1
        lda #0
        rts
end1    lda #1
        rts

* rel: $FFFE, a relocatable block: number, memory, address, length
rel     ldy #6
        jsr read0
        bmi end1
        jsr blkline
        jsr PRINTF
        dta c' Off: $%4x',EOL,0
        dta a(b2)
rl1     lda b1                 ; (bit 7: no data in the file)
        bpl skip
        lda #0
        rts

* ext: $FFF9, as $FFFE; when the address is not 0 address and length change
* places
ext     ldy #6
        jsr read0
        bmi end1
        lda b2
        ora b3
        beq ex2
        ldx #1
ex1     lda len,x
        ldy b2,x
        sta b2,x
        tya
        sta len,x
        dex
        bpl ex1
ex2     jsr blkline
        jsr PRINTF
        dta c' Buf: %d',EOL,0
        dta a(b2)
        jmp rl1

* blkline: the block's number, memory and length
blkline jsr setoff
        jsr prefix
        jsr PRINTF
        dta c' Blk: %b, Mem: $%2x Len: $%4x (%d)',0
        dta a(b0,b1,len,len)
        lda RMARGN
        cmp #63
        bcs bl1
        jsr PRINTF
        dta EOL,0
bl1     rts

* fix: $FFFD, fixups of a block
fix     ldy #3
        jsr read0
        bmi end2
        jsr setoff
        jsr prefix
        jsr PRINTF
        dta c' Blk: %b,          Len: $%4x (%d)',EOL,0
        dta a(b0,b1,b1)
* fixdat: the fixup bytes up to $FC; $FD has an address after it
fixdat  jsr FGETC
        bmi end2
        cmp #$FD
        beq fd1
        cmp #$FC
        bne fixdat
        jmp setoff
fd1     jsr FGETC
        bmi end2
        jsr FGETC
        bpl fixdat
end2    lda #1
        rts

* sref: $FFFB, a symbol's references
sref    jsr setoff
        ldy #10
        jsr read0
        bmi end2
        jsr prefix
        jsr PRINTF
        dta c' Sym: [%8s]  Len: $%4x (%d)',EOL,0
        dta a(b0,b8,b8)
        jmp fixdat

* sdef: $FFFC, a symbol defined
sdef    jsr setoff
        ldy #11
        jsr read0
        bmi end2
        jsr prefix
        jsr PRINTF
        dta c' Sym: [%8s]  Blk: %b, Off: $%4x',EOL,0
        dta a(b3,b0,b1)
        jmp setoff

* prefix: the offset, on a screen of 64 columns or more
prefix  lda RMARGN
        cmp #63
        bcc pr1
        jsr PRINTF
        dta c'$%06x ',0
        dta a(off)
pr1     rts

* readw: 2 bytes to hd, len 2 less; N=1 at the end of the file
readw   ldx #6
        ldy #2
        jsr readx
        bmi rw1
        sec
        lda len
        sbc #2
        sta len
        bcs rw0
        dec len+1
rw0     lda #0
rw1     rts

* read0, readx: Y bytes to b0 + X; N=1 at the end of the file
read0   ldx #0
readx   clc
        txa
        adc a_b0
        sta addpos
        lda a_b0+1
        adc #0
        sta addpos+1
        sty bytbuf
        lda #0
        sta bytbuf+1
        jmp FREAD

a_b0    dta a(b0)
hands   dta a(ext,std,sref,sdef,fix,rel,std,st0)
names   dta a(n_ext,n_abs,n_sref,n_sdef,n_fix,n_rel,n_std)
n_ext   dta c'RelExt',0
n_abs   dta c'AbsBlk',0
n_sref  dta c'SymRef',0
n_sdef  dta c'SymDef',0
n_fix   dta c'Fixups',0
n_rel   dta c'RelBlk',0
n_std   dta c'StdBin',0
hname   dta a(0)
kind    dta 0
seen    dta 0                  ; bit 7: after a segment
off     dta 0,0,0,0
b0      dta 0                  ; what was read: b0-b11
b1      dta 0
b2      dta 0
b3      dta 0
len     dta 0,0                ; (b4, b5: the length)
hd      dta 0,0                ; (b6, b7: a header or an address)
b8      dta 0,0,0,0

        blk update address
        blk update symbols
