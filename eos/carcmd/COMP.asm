; EOS CAR: COMP, two files compared byte by byte
;   COMP [d:][path]fname1.ext [d:][path]fname2.ext [offset1 [offset2]]
; Each difference is shown as ?dif at position:byte & position:byte (hex);
; when one file ends before the other, "NAME EOF" names it.
; The offsets (decimal or $hex, 24 bits) are where each file starts.
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FREAD    smb 'FREAD'
FSEEK    smb 'FSEEK'
U_GETPAR smb 'U_GETPAR'
U_ARGV   smb 'U_ARGV'
U_GETNUM smb 'U_GETNUM'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
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
BUFSZ    equ 1024              ; bytes read at a time from each file

        blk reloc main
start   lda #$FF
        jsr U_ARGV             ; native quoted/127-byte command contract
        jsr U_GETPAR           ; the two names (a missing one: 170)
        jeq nofile
        ldx #0
s1      lda COMTAB+$21,x
        sta nm1,x
        inx
        cmp #EOL
        bne s1
        jsr U_GETPAR
        jeq nofile
        ldx #0
s2      lda COMTAB+$21,x
        sta nm2,x
        inx
        cmp #EOL
        bne s2
        ldx #3                 ; the offsets, 0 when not given
        lda #0
s3      sta pos1,x
        sta pos2,x
        dex
        bpl s3
        jsr U_GETNUM
        beq s5
        ldx #2
s4      lda COMTAB-6,x
        sta pos1,x
        dex
        bpl s4
        jsr U_GETNUM
        beq s5
        ldx #2
s4a     lda COMTAB-6,x
        sta pos2,x
        dex
        bpl s4a
s5      lda a_nm1              ; both files open, at their offsets
        ldx a_nm1+1
        ldy #0
        jsr open
        sta h1
        lda a_nm2
        ldx a_nm2+1
        ldy #4
        jsr open
        sta h2
        lda #0
        sta n1
        sta n1+1
        sta n2
        sta n2+1
        sta i1
        sta i1+1
        sta i2
        sta i2+1
        sta e1
        sta e2
c1      ldx #0                 ; a byte of each
        jsr getb
        ror end1
        sta b1
        ldx #2
        jsr getb
        bcs c1a
        bit end1
        bmi eof1               ; only the first ended
        sta b2
        jmp c1b
c1a     bit end1               ; both ended: nothing to say
        bmi quiet
        jmp eof2
c1b
        cmp b1
        beq c2
        jsr PRINTF
        dta c'?dif at %6x:%2x & %6x:%2x',EOL,0
        dta a(pos1,b1,pos2,b2)
c2      ldx #0
        jsr inc3
        ldx #4
        jsr inc3
        jmp c1
eof1    lda a_nm1
        ldx a_nm1+1
        jmp done
eof2    lda a_nm2
        ldx a_nm2+1
done    sta enm
        stx enm+1
        jsr PRINTF
        dta EOL,c'%p EOF',EOL,0
        dta a(enm)
quiet   lda h1
        sta file_id
        jsr FCLOSE
        lda h2
        sta file_id
        jmp FCLOSE

nofile  lda a_cfn              ; the empty name is looked for: 170, and
        sta FILE_P
        lda a_cfn+1
        sta FILE_P+1
        lda #4
        sta mode               ; no name to show (as on SDX)
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        lda #170
        jmp U_FAIL

* open: the file named at AX for reading, moved to pos1 (Y=0) or pos2
* (Y=4); A = its handle
open    sta FILE_P
        stx FILE_P+1
        sty yo
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        ldy yo
        lda pos1,y
        sta addpos
        lda pos1+1,y
        sta addpos+1
        lda pos1+2,y
        sta addpos+2
        jsr FSEEK
        lda file_id
        rts

* inc3: the position at pos1+X one up
inc3    inc pos1,x
        bne i3
        inc pos1+1,x
        bne i3
        inc pos1+2,x
i3      rts

* getb: the next byte of file 1 (X=0) or 2 (X=2) in A; C=1 at its end
getb    lda i1,x               ; bytes left in the buffer?
        cmp n1,x
        bne gb2
        lda i1+1,x
        cmp n1+1,x
        bne gb2
        lda e1,x               ; the file ended already
        bne gb_eof
        stx xo
        lda h1,x
        sta file_id
        lda bufs,x
        sta addpos
        lda bufs+1,x
        sta addpos+1
        lda #<BUFSZ
        sta bytbuf
        lda #>BUFSZ
        sta bytbuf+1
        lda #0
        sta memreix
        jsr FREAD
        txa
        ldx xo
        sta e1,x
        lda bytbuf
        sta n1,x
        lda bytbuf+1
        sta n1+1,x
        lda #0
        sta i1,x
        sta i1+1,x
        lda n1,x               ; nothing more (an empty file too: "NAME
        ora n1+1,x             ; EOF", as SDX)
        beq gb_eof
gb2     clc                    ; the byte at buffer + index
        lda bufs,x
        adc i1,x
        sta $80
        lda bufs+1,x
        adc i1+1,x
        sta $81
        ldy #0
        lda ($80),y
        inc i1,x
        bne gb3
        inc i1+1,x
gb3     clc
        rts
gb_eof  sec
        rts

a_nm1   dta a(nm1)
a_cfn   dta a(COMTAB+$21)
a_nm2   dta a(nm2)
bufs    dta a(buf1,buf2)
enm     dta a(0)
yo      dta 0
end1    dta 0
xo      dta 0
h1      dta 0
        dta 0
h2      dta 0
        dta 0
n1      dta a(0)               ; bytes in each buffer
n2      dta a(0)
i1      dta a(0)               ; the next one to take
i2      dta a(0)
e1      dta 0                  ; the file's end was read
        dta 0
e2      dta 0
        dta 0
b1      dta 0,0,0,0
b2      dta 0,0,0,0
pos1    dta 0,0,0,0
pos2    dta 0,0,0,0
nm1     :66 dta 0
nm2     :66 dta 0
buf1    equ *                  ; the buffers: the free memory after the program
buf2    equ *+BUFSZ

        blk update address
        blk update symbols
