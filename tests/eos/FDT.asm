; EOS oracle test: FDOPEN/FDGETC/FDCLOSE. Parameters: the mode (a number),
; the output file, the directory specification (last: on SDX FDGETC
; builds its lines in LBUF). The listing is collected
; in memory and written to the file after FDCLOSE (so that the free sector
; count it shows is the same as before).
FDOPEN   smb 'FDOPEN'
FDGETC   smb 'FDGETC'
FDCLOSE  smb 'FDCLOSE'
FOPEN    smb 'FOPEN'
FWRITE   smb 'FWRITE'
FCLOSE   smb 'FCLOSE'
U_GETNUM smb 'U_GETNUM'
U_GETPAR smb 'U_GETPAR'
FILE_P   smb 'FILE_P'
COMTAB   smb 'COMTAB'

mode     equ $0778
scan     equ $0779
attr     equ $077A
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
zp       equ $80
MEMLO    equ $02E7
EOL      equ $9B

        blk reloc main
start   jsr U_GETNUM
        sta md
        jsr U_GETPAR           ; the output file, kept
        ldx #15
o1      lda COMTAB+$21,x
        sta oname,x
        dex
        bpl o1
        jsr U_GETPAR
        lda md
        sta mode
        lda #0
        sta scan
        jsr FDOPEN
        lda #$00               ; collected at $7000 (SDX's FDOPEN works
        sta zp                 ; above MEMLO)
        sta bufa
        lda #$70
        sta zp+1
        sta bufa+1
f1      jsr FDGETC
        bmi f2
        ldy #0
        sta (zp),y
        inc zp
        bne f1
        inc zp+1
        bne f1
f2      jsr FDCLOSE
        sec                    ; its length
        lda zp
        sbc bufa
        sta len
        lda zp+1
        sbc bufa+1
        sta len+1
        lda onadr              ; the output file
        sta FILE_P
        lda onadr+1
        sta FILE_P+1
        lda #8
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda bufa
        sta addpos
        lda bufa+1
        sta addpos+1
        lda #0
        sta memreix
        lda len
        sta bytbuf
        lda len+1
        sta bytbuf+1
        ora len
        beq f3
        jsr FWRITE
f3      jmp FCLOSE

md      dta 0
len     dta a(0)
bufa    dta a(0)
onadr   dta a(oname)
oname   :16 dta 0

        blk update address
        blk update symbols
