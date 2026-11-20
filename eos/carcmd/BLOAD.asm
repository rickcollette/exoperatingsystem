; EOS CAR: BLOAD, a file loaded as raw data
;   BLOAD [d:][path]fname[.ext] [[$]index:][$]address
; The whole file goes to memory from the address on (memory index as for
; PEEK; FREAD writes into other memory itself through memreix), up to
; $FFFF at most. Nothing is checked: the caller knows what is there. An
; index with no memory does nothing (as SDX).
U_GETPAR smb 'U_GETPAR'
U_GETADR smb 'U_GETADR'
U_FAIL   smb 'U_FAIL'
XRWMEM   smb 'XRWMEM'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
PRINTF   smb 'PRINTF'
PUTC     smb 'PUTC'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR           ; the file
        jeq bad
        ldx #0
b1      lda COMTAB+$21,x
        sta fname,x
        inx
        cmp #EOL
        bne b1
        jsr getadr             ; the address
        jeq bad
        lda ad                 ; is there memory with this index?
        sta addpos
        lda ad+1
        sta addpos+1
        ldx ad_ix
        ldy #0
        clc
        jsr XRWMEM
        bcc b0
        rts                    ; no such memory: nothing (SDX)
b0      lda fna
        sta FILE_P
        lda fna+1
        sta FILE_P+1
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda file_id
        sta fid
        lda ad                 ; all of it, up to $FFFF
        sta addpos
        lda ad+1
        sta addpos+1
        sec
        lda #0
        sbc ad
        sta bytbuf
        lda #0
        sbc ad+1
        sta bytbuf+1
        ora bytbuf
        bne b2
        dec bytbuf             ; from 0: $FFFF bytes
        dec bytbuf+1
b2      lda ad_ix
        sta memreix
        jsr FREAD
        lda #0
        sta memreix
        lda fid
        sta file_id
        jmp FCLOSE
bad     lda #156
        jmp U_FAIL

fid     dta 0
fna     dta a(fname)
fname   :64 dta 0

        icl 'MEMlib.icl'

        blk update address
        blk update symbols
