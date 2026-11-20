; EOS CAR: SIOSET, SIO speed control
;   SIOSET [unit [type [usindex]]]
;   SIOSET REFRESH [value]
;   SIOSET WAITACK [[$]value]
; EOS's high speed SIO driver (_HSDRV, in sio_vector from the start) asks
; each drive for its speed index ('?') on the unit's first R, P, W or S
; and uses it when there is one. US asks again, or takes usindex, and
; puts _HSDRV back in sio_vector when a program took it out. XF and INDUS
; use the XF551's high speed commands (the command's bit 7 on, the frame
; at the normal rate, the rest at about 38400 baud: divisor $10, the
; Indus GT's $11). A drive that does not answer '?' is tried with the
; XF551's commands ($CE), as SDX does: XF when it takes them. RESET asks
; again on the next use; NORMAL takes a unit back to the OS's SIO for good.
; Any other word just shows the drive. A drive shows US and its index, XF,
; INDUS, NORMAL, else '-'. A unit that is not 1-15 (or A-O, Dn:) shows
; them all. REFRESH and WAITACK are kept by the driver (0 and 2 after a
; cold start): WAITACK is the ACK wait in frames, twice; with REFRESH 128
; a drive whose transfer fails is asked again on its next use. US without
; usindex takes the drive's, else $28 (the normal rate), as SDX. After
; DEVICE SIO /A or /C (the OS's SIO only) SIOSET answers 154, as SDX's.
U_GETPAR smb 'U_GETPAR'
_DRVLET  smb '_DRVLET'
U_GETNUM smb 'U_GETNUM'
U_FAIL   smb 'U_FAIL'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
_HSDRV   smb '_HSDRV'

EOL      equ $9B
E_TOOMANY equ 161
sio_vector equ $0718
lsio     equ $0A2F
DDEVIC   equ $0300
DUNIT    equ $0301
DCOMND   equ $0302
DSTATS   equ $0303
DBUF     equ $0304
DTIMLO   equ $0306
DBYT     equ $0308
DAUX     equ $030A
DAUX1    equ $030A
DAUX2    equ $030B

        blk reloc main
start   lda #0                 ; DEVICE SIO /A or /C: not there (SDX:
        sta DUNIT              ; SIO.SYS's symbols are not defined)
        sta DAUX2
        lda #$FD
        sta DDEVIC
        jsr _HSDRV
        bpl st1
        lda #154
        jmp U_FAIL
st1     lda #0                 ; all drives unless one is given
        sta unit
        jsr U_GETNUM
        beq s_word
        cpx #0
        jne table
        cmp #16
        jcs table
        sta unit
        jmp s_type
s_word  jsr U_GETPAR           ; not a number: a word, or none
        jeq table
        jsr kw                 ; REFRESH / WAITACK
        bcs s_drv
        cmp #5
        jeq refresh
        cmp #6
        jeq waitack
s_drv   jsr drive              ; A-O or Dn:
        jcs table
        sta unit
s_type  jsr U_GETPAR           ; the protocol
        jeq table
        jsr kw
        jcs table              ; not one: the drive as it is
        cmp #1                 ; NORMAL
        bne s_t1
        lda #$81
        bne s_set
s_t1    cmp #0                 ; RESET: asked again on the next use
        bne s_t2
        lda #$FF
        bne s_set
s_t2    cmp #4                 ; US
        jeq s_us
        cmp #5
        jcs table
        ldx unit               ; XF $50, INDUS $51: XF551 commands at
        jeq table              ; divisor $10 or $11
        adc #$50-2             ; (C=0)
s_set1  pha
        jsr install
        pla
        jmp s_set
s_set   jsr setdiv
        jmp table
s_us    lda unit
        jeq table
        jsr U_GETNUM           ; usindex, else the drive's
        bne s_us2
        lda #$31               ; '?': the drive's index, at the normal rate
        sta DDEVIC
        lda unit
        sta DUNIT
        lda #'?'
        sta DCOMND
        lda #$40
        sta DSTATS
        lda bufa
        sta DBUF
        lda bufa+1
        sta DBUF+1
        lda #7
        sta DTIMLO
        lda #1
        sta DBYT
        lda #0
        sta DBYT+1
        sta DAUX
        sta DAUX+1
        jsr lsio
        bmi s_us0
        lda buf
        beq s_us0
        cmp #$28
        bcc s_us2
s_us0   lda #$28               ; none: the normal rate
s_us2   jmp s_set1

; install: _HSDRV in sio_vector (the last free entry) unless it is there
install ldx #0
in1     lda sio_vector,x
        cmp hsa
        bne in2
        lda sio_vector+1,x
        cmp hsa+1
        beq in_ret
in2     inx
        inx
        cpx #8
        bcc in1
        ldx #6
in3     lda sio_vector+1,x
        beq in4
        dex
        dex
        bpl in3
        lda #E_TOOMANY
        jmp U_FAIL
in4     lda hsa
        sta sio_vector,x
        lda hsa+1
        sta sio_vector+1,x
in_ret  rts
; setdiv: unit's divisor = A (0: none); getdiv: A = unit row's
setdiv  sta DAUX
        lda #$FF
        ldx unit
        bne hscall
        rts
getdiv  lda #$FE
        ldx row
hscall  sta DDEVIC
        stx DUNIT
        jmp _HSDRV

refresh lda #1                 ; the driver's value (DUNIT 1, 2), set
        bne rw                 ; when one is given
waitack lda #2
rw      sta DUNIT
        lda #0
        sta DAUX2
        jsr U_GETNUM
        beq rw1
        sta DAUX1
        inc DAUX2
rw1     lda #$FD
        sta DDEVIC
        jsr _HSDRV
        sta val
        jsr PRINTF
        dta EOL,c'Value: $%2x=%b',EOL,0
        dta a(val,val)
        rts

; table: the drive in unit, all of them when 0
table   jsr PRINTF           ; (a blank line first, as SDX)
        dta EOL,c'Unit Type   USidx',EOL
        dta c'---- ------ -----',EOL,0
        ldx unit
        bne t1
        inx
t1      stx row
        jsr getdiv             ; Ultra Speed: US and its index
        beq t1a
        cmp #$80               ; none
        beq t1a
        cmp #$81
        bne t1e
        jsr PRINTF
        dta c'%3b  NORMAL',EOL,0
        dta a(row)
        jmp t1b
t1e     cmp #$50               ; XF551 commands: XF or INDUS
        bne t1c
        jsr PRINTF
        dta c'%3b  XF',EOL,0
        dta a(row)
        jmp t1b
t1c     cmp #$51
        bne t1d
        jsr PRINTF
        dta c'%3b  INDUS',EOL,0
        dta a(row)
        jmp t1b
t1d     sta val
        jsr PRINTF
        dta c'%3b  US     $%2x',EOL,0
        dta a(row,val)
        jmp t1b
t1a     jsr PRINTF
        dta c'%3b  -',EOL,0
        dta a(row)
t1b
        lda unit
        bne t2
        ldx row
        inx
        cpx #16
        jcc t1
t2      rts

; kw: C=0 and A = the number of the word at COMFNAM in kwtab
; (0 RESET 1 NORMAL 2 XF 3 INDUS 4 US 5 REFRESH 6 WAITACK); C=1 none
kw      ldy #0                 ; the table position
        lda #0
        sta kwn
kw1     ldx #0
kw2     lda kwtab,y
        beq kw_no
        cmp COMTAB+$21,x
        bne kw3
        iny
        inx
        cmp #EOL
        bne kw2
        lda kwn
        clc
        rts
kw3     lda kwtab,y            ; the next word
        iny
        cmp #EOL
        bne kw3
        inc kwn
        bne kw1
kw_no   sec
        rts

; drive: C=0 and A = the unit of A-O, Dn or Dn: at COMFNAM; C=1 not one
drive   lda COMTAB+$21
        ldx COMTAB+$22
        cpx #EOL
        beq dr_l
        cpx #':'
        bne dr_d
        ldx COMTAB+$23
        cpx #EOL
        bne dr_no
dr_l    jmp _DRVLET            ; a letter: D is D1, a CIO device's not a drive
dr_d    cmp #'D'               ; Dn, Dnn, with or without a colon
        bne dr_no
        lda #0
        sta kwn
        ldx #1
dr1     lda COMTAB+$21,x
        cmp #'0'
        bcc dr2
        cmp #'9'+1
        bcs dr2
        and #$0F
        pha
        lda kwn
        asl @
        asl @
        adc kwn
        asl @
        sta kwn
        pla
        adc kwn
        sta kwn
        inx
        cpx #4
        bcc dr1
        bcs dr_no
dr2     cpx #1
        beq dr_no
        cmp #':'
        bne dr3
        inx
        lda COMTAB+$21,x
dr3     cmp #EOL
        bne dr_no
        lda kwn
        beq dr_no
        cmp #16
        bcs dr_no
        clc
        rts
dr_no   sec
        rts

unit    dta 0
row     dta 0
kwn     dta 0
val     dta 0
hsa     dta a(_HSDRV)
bufa    dta a(buf)
buf     dta 0
kwtab   dta c'RESET',EOL,c'NORMAL',EOL,c'XF',EOL,c'INDUS',EOL,c'US',EOL
        dta c'REFRESH',EOL,c'WAITACK',EOL,0

        blk update address
        blk update symbols
