; EOS CAR: command core of DIR and DIRS, written for
; EOS: the listing is FDOPEN's (lib2), in the modes SDX's DIR uses
; (measured: DIR $80, redirected $A1, /A $C8 and $E1; DIRS $03, /A $43).
;   DIR  [+|-][A|H|P|S] [d:][path][fname][.ext] [/A|C|P]
; Attributes as everywhere (+ alone: all entries; none given: -H).
; /C counts the entries, /P waits for RETURN after each 23 lines.
FDOPEN   smb 'FDOPEN'
FDGETC   smb 'FDGETC'
FDCLOSE  smb 'FDCLOSE'
U_GETPAR smb 'U_GETPAR'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

mode     equ $0778
scan     equ $0779
dev_index equ $0740
CIOV     equ $E456
EOL      equ $9B

        blk reloc main
start   lda #$20               ; -H unless attributes are given
        sta sc
        lda #0
        sta given
        sta opt_a
        sta opt_c
        sta opt_p
        sta sw_seen
        lda #EOL
        sta spec
p1      jsr U_GETPAR
        jeq p_end
        lda COMTAB+$21
        cmp #'+'
        beq p_att
        cmp #'-'
        beq p_att
        cmp #'/'
        beq p_sw
        lda sw_seen            ; after a switch: no specification (SDX)
        bne p1
        ldx #0                 ; the specification
p2      lda COMTAB+$21,x
        sta spec,x
        inx
        cmp #EOL
        bne p2
        jmp p1
p_att   sta sign
        lda given              ; the first attribute: the default goes
        bne pa0
        lda #0
        sta sc
        lda #1
        sta given
pa0     ldx #1
pa1     lda COMTAB+$21,x
        cmp #EOL
        beq p1
        ldy #3
pa2     cmp atrch,y
        beq pa3
        dey
        bpl pa2
        inx                    ; not an attribute letter: skipped
        bne pa1
pa3     lda atrbit,y
        ldy sign
        cpy #'-'
        bne pa4
        asl @
        asl @
        asl @
        asl @
pa4     ora sc
        sta sc
        inx
        bne pa1
p_sw    sta sw_seen
        ldx #1                 ; /A, /C, /P (several letters allowed)
ps1     lda COMTAB+$21,x
        cmp #EOL
        beq p1
        cmp #'A'
        bne ps2
        sta opt_a
ps2     cmp #'C'
        bne ps3
        sta opt_c
ps3     cmp #'P'
        bne ps4
        sta opt_p
ps4     inx
        bne ps1
p_end   ldy #0                 ; the mode: redirected output is listed as
        ldx COMTAB+6           ; for 80 columns
        lda dev_index,x
        and #$F0
        cmp #$30
        beq m0
        iny
m0      lda opt_a              ; /A: the modes with attributes
        beq m1
        iny
        iny
m1      lda modes,y
        sta mode
        lda sc
        sta scan
        lda spa
        sta FILE_P
        lda spa+1
        sta FILE_P+1
        jsr FDOPEN
        lda #0
        sta lines
        sta lines+1
        sta pg
l1      jsr FDGETC
        bmi l_end
        pha
        jsr PUTC
        pla
        cmp #EOL
        bne l1
        inc lines
        bne l2
        inc lines+1
l2      lda opt_p
        beq l1
        inc pg
        lda pg
        cmp #23
        bcc l1
        lda #0
        sta pg
        jsr PRINTF
        dta c'   Press <RETURN> to continue ',0
        ldx #0                 ; a line from the keyboard (E:, IOCB 0)
        lda #5
        sta $0342
        lda ina
        sta $0344
        lda ina+1
        sta $0345
        lda #40
        sta $0348
        lda #0
        sta $0349
        jsr CIOV
        jmp l1
l_end   jsr FDCLOSE
        lda opt_c
        beq done
        sec                    ; the entries: the lines less the others
        lda lines
        sbc #DOTHERS
        sta lines
        bcs c1
        dec lines+1
c1      jsr PRINTF
        dta c'%8d ENTRIES',EOL,0
        dta a(lines)
done    rts

sign    dta 0
sw_seen dta 0
given   dta 0
sc      dta 0
opt_a   dta 0
opt_c   dta 0
opt_p   dta 0
pg      dta 0
lines   dta a(0)
modes   dta b(DMODE,DMODE80,DMODEA,DMODE80A)
atrch   dta c'PHAS'
atrbit  dta b($01,$02,$04,$08)
spa     dta a(spec)
ina     dta a(inbuf)
spec    :64 dta 0
inbuf   :40 dta 0

        blk update address
        blk update symbols
