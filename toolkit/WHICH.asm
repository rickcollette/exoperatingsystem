; EOS Toolkit: WHICH, where a command is found
;   WHICH command ...
; For each command as the command processor looks for it: a built-in
; command, or the program NAME.COM (.COM unless the name has an
; extension), with a device or directory given only there, else in the
; current directory and then along $PATH. Shows "NAME: built-in", the
; file as it is opened (X.COM in the current directory, CAR:DIR.COM), or
; "NAME: not found". Programs run through COMEXE or RUNEXT are not
; looked for.
U_GETPAR smb 'U_GETPAR'
U_GEFINA smb 'U_GEFINA'
GETENV   smb 'GETENV'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

jkernel  equ $0703
mode     equ $0778
scan     equ $0779
attr     equ $077A
LBUFF    equ $0580
EOL      equ $9B
BSLASH   equ $5C
ptr      equ $80

        blk reloc main
start   jsr U_GETPAR
        bne w1
usage   jsr PRINTF
        dta c'Use: which command ...',EOL,0
        rts
w1      lda COMTAB+$21         ; (no switches)
        cmp #'-'
        beq usage
        ldx #0                 ; the name
w2      lda COMTAB+$21,x
        sta nm,x
        inx
        cmp #EOL
        bne w2
        jsr builtin
        bcs w3
        jsr PRINTF
        dta c'%s: built-in',EOL,0
        dta a(nm)
        jmp w_next
w3      jsr addext
        jsr search
        bcs w4
        jsr PRINTF
        dta c'%s',EOL,0
        dta a(spec)
        jmp w_next
w4      ldx nlen               ; the name as given
        lda #EOL
        sta nm,x
        jsr PRINTF
        dta c'%s: not found',EOL,0
        dta a(nm)
w_next  jsr U_GETPAR
        bne w1
        rts

* builtin: C=0 when nm is in the command processor's table
builtin lda a_btab
        sta ptr
        lda a_btab+1
        sta ptr+1
bi1     ldy #0
        lda (ptr),y
        beq bi_no
bi2     lda (ptr),y
        cmp nm,y
        bne bi3
        iny
        cmp #EOL
        bne bi2
        clc
        rts
bi3     lda (ptr),y            ; the next entry
        iny
        cmp #EOL
        bne bi3
        tya
        clc
        adc ptr
        sta ptr
        bcc bi1
        inc ptr+1
        bne bi1
bi_no   sec
        rts

* addext: .COM after nm when its name has no extension; nmdir set when
* nm has a device or directory
addext  ldx #0
        ldy #0                 ; Y: after the last dot of the name, 0 none
        sty nmdir
ae1     lda nm,x
        cmp #EOL
        beq ae3
        inx
        cmp #'.'
        bne ae2
        txa
        tay
ae2     cmp #':'
        beq ae2s
        cmp #'>'
        beq ae2s
        cmp #BSLASH
        bne ae1
ae2s    ldy #0
        dec nmdir
        bne ae1
ae3     stx nlen
        tya
        bne ae5
ae4     lda dotcom,y
        sta nm,x
        inx
        iny
        cmp #EOL
        bne ae4
ae5     rts

* search: C=0 when found (spec the file): as given, then (no device or
* directory given) after each $PATH entry
search  ldx #0
        jsr try
        bcc se_ret
        lda nmdir
        bne se_no
        lda a_pname
        ldx a_pname+1
        jsr GETENV
        bmi se_no
        ldx #0
se1     lda LBUFF,x            ; $PATH kept
        sta pbuf,x
        inx
        cmp #EOL
        bne se1
        ldy #0
se2     lda pbuf,y             ; the next entry
        cmp #EOL
        beq se_no
        ldx #0
se3     lda pbuf,y
        cmp #';'
        beq se4
        cmp #EOL
        beq se5
        sta spec,x
        inx
        iny
        cpx #24
        bcc se3
se4     iny
se5     sty pidx
        txa                    ; a > after a directory's name
        beq se6
        lda spec-1,x
        cmp #':'
        beq se6
        cmp #'>'
        beq se6
        cmp #BSLASH
        beq se6
        lda #'>'
        sta spec,x
        inx
se6     jsr try
        bcc se_ret
        ldy pidx
        jmp se2
se_no   sec
se_ret  rts

* try: spec+X = nm, opened for reading (files only, not hidden) and
* closed again: C=0 there
try     ldy #0
tr1     lda nm,y
        sta spec,x
        inx
        iny
        cmp #EOL
        bne tr1
        lda a_spec
        sta FILE_P
        lda a_spec+1
        sta FILE_P+1
        jsr U_GEFINA
        lda #4
        sta mode
        lda #$A0
        sta scan
        lda #0
        sta attr
        ldy #9                 ; kd_open
        jsr jkernel
        bmi tr_no
        ldy #7                 ; kd_close
        jsr jkernel
        clc
        rts
tr_no   sec
        rts

a_btab  dta a(btab)
a_spec  dta a(spec)
a_pname dta a(pname)
pname   dta c'PATH',EOL
dotcom  dta c'.COM',EOL
nmdir   dta 0
nlen    dta 0
pidx    dta 0
nm      :68 dta 0
spec    :100 dta 0
pbuf    :130 dta 0
* the command processor's built-in commands (eos/cp.asm cmdtab)
btab    dta c'TYPE',EOL,c'RUNEXT',EOL,c'CLS',EOL,c'ECHO',EOL,c'SET',EOL
        dta c'PATH',EOL,c'ERROR',EOL,c'CD',EOL,c'CHDIR',EOL,c'CWD',EOL
        dta c'MD',EOL,c'MKDIR',EOL,c'CREDIR',EOL,c'RD',EOL,c'RMDIR',EOL
        dta c'DELDIR',EOL,c'RENDIR',EOL,c'REN',EOL,c'RENAME',EOL,c'DEL',EOL
        dta c'DELETE',EOL,c'ERASE',EOL,c'ATR',EOL,c'ATTRIB',EOL,c'VERIFY',EOL
        dta c'REPORT',EOL,c'SETERRNO',EOL,c'SWAP',EOL,c'PROMPT',EOL,c'LOAD',EOL
        dta c'BOOT',EOL,c'CLR',EOL,c'COLD',EOL,c'BASIC',EOL,c'PAUSE',EOL
        dta c'MORE',EOL,c'VER',EOL,c'FI',EOL,c'COPY',EOL,0

        blk update address
        blk update symbols
