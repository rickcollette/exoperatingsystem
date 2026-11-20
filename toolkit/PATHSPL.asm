; EOS Toolkit: PATHSPL, a file specification split into environment
; variables (for batch files)
;   PATHSPL [d:][path]filename.ext [d],[p],[f],[b],[x]
; The variables named get the device (C:), the path (>FOO>), the file
; name (BAR.EXE), its base name (BAR) and its extension (EXE). A name
; left out (PATHSPL C:>FOO>BAR.EXE,,,,,%X) sets nothing. No file
; specification: 156.
; The parameters are read here rather than with U_GETPAR: a comma with
; nothing before it is an empty parameter.
U_GEFINA smb 'U_GEFINA'
U_EXPAND smb 'U_EXPAND'
U_PATH   smb 'U_PATH'
U_FAIL   smb 'U_FAIL'
PUTENV   smb 'PUTENV'
FILE_P   smb 'FILE_P'
COMTAB   smb 'COMTAB'

BUFOFF   equ $0A               ; (COMTAB+)
LBUF     equ $3F
ext      equ $076A             ; (U_GEFINA: the extension and the path)
path     equ $07A0
EOL      equ $9B

        blk reloc main
start   lda COMTAB+BUFOFF
        sta pos
        ldx #5                 ; the file specification, then the variables
        stx vi
        jsr scan
        ldx #0
sc1     stx vi
        jsr scan
        ldx vi
        inx
        cpx #5
        bcc sc1
        lda vl+5
        bne spec
        lda #156
        jmp U_FAIL
spec    ldx #5                 ; it to buf for U_GEFINA
        jsr name
        dey                    ; (the = becomes the end)
        lda #EOL
        sta buf,y
        lda pbuf
        sta FILE_P
        lda pbuf+1
        sta FILE_P+1
        jsr U_GEFINA
        ldx #2                 ; f: NAME.EXT
        jsr name
        beq do_x
        jsr expand
do_x    ldx #4                 ; x: the extension
        jsr name
        beq do_b
        ldx #0
dx1     lda ext,x
        cmp #' '
        bne dx2
        lda #EOL
dx2     sta buf,y
        iny
        inx
        cpx #3
        bcc dx1
        jsr put
do_b    ldx #2                 ; b: the name without the extension
        lda #' '
db1     sta ext,x
        dex
        bpl db1
        ldx #3
        jsr name
        beq do_p
        jsr expand
do_p    ldx #1                 ; p: the path
        jsr name
        beq do_d
        ldx #0
dp1     lda path,x
        beq dp2
        sta buf,y
        iny
        inx
        cpx #63
        bcc dp1
dp2     jsr put
do_d    ldx #0                 ; d: the device alone
        jsr name
        beq done
        lda #0
        sta path
        lda pbuf
        ldx pbuf+1
        jsr U_PATH
        lda pbuf
        ldx pbuf+1
        jmp PUTENV
done    rts

* expand: the name (8+3) as NAME.EXT at buf+Y, then put
expand  lda pbuf
        ldx pbuf+1
        jsr U_EXPAND
* put: buf (EOL ended at Y) to the environment
put     lda #EOL
        sta buf,y
        lda pbuf
        ldx pbuf+1
        jmp PUTENV

* scan: the next parameter at pos in LBUF: blanks before it skipped, up
* to a blank, a comma or the end; then blanks and one comma skipped. Its
* start and length in vs and vl, for parameter number vi (5 first)
scan    ldy pos
sn1     lda COMTAB+LBUF,y
        cmp #' '
        bne sn2
        iny
        bne sn1
sn2     ldx vi
        tya
        sta vs,x
sn3     lda COMTAB+LBUF,y
        cmp #' '
        beq sn4
        cmp #','
        beq sn4
        cmp #EOL
        beq sn4
        iny
        bne sn3
sn4     tya
        sec
        sbc vs,x
        sta vl,x
sn5     lda COMTAB+LBUF,y
        cmp #' '
        bne sn6
        iny
        bne sn5
sn6     cmp #','
        bne sn7
        iny
sn7     sty pos
        rts

* name: parameter X in capitals and = to buf, Y after them; Z=1 when
* the parameter is empty
name    lda vl,x
        beq nm_ret
        sta cnt
        ldy vs,x
        ldx #0
nm1     lda COMTAB+LBUF,y
        cmp #'a'
        bcc nm2
        cmp #'z'+1
        bcs nm2
        and #$DF
nm2     sta buf,x
        iny
        inx
        dec cnt
        bne nm1
        lda #'='
        sta buf,x
        inx
        txa
        tay
nm_ret  rts

pbuf    dta a(buf)             ; (an address in the program: a word, which
                               ; the loader relocates)
pos     dta 0
vi      dta 0
cnt     dta 0
vs      :6 dta 0               ; the parameters: d p f b x, the file
vl      :6 dta 0
buf     :130 dta 0

        blk update address
        blk update symbols
