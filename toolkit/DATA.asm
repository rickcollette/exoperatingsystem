; EOS Toolkit: DATA, a file as Atari BASIC DATA lines
;   DATA [d:][path]fname[.ext] [[$]start [$]count] [/H$CNLS start_ln ln_step ln_sz]
; The bytes from start on up to the end (none when count is 0) as numbers
; in DATA lines, 7 to a line. Options: /H hex, /$ hex with a $, /C hex with
; no commas (10 to a line), /N no line numbers, /L the first line number
; and the step follow (10 and 1), /S the numbers to a line follows. No
; file name: standard input. An error while reading ends the lines.
U_GETATR smb 'U_GETATR'
U_GETNUM smb 'U_GETNUM'
U_SLASH  smb 'U_SLASH'
U_FAIL   smb 'U_FAIL'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
FOPEN    smb 'FOPEN'
FGETC    smb 'FGETC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

jkernel  equ $0703
file_id  equ $0760
mode     equ $0778
addpos   equ $0782
EOL      equ $9B
E_NOFUNC equ 146               ; the input cannot seek

        blk reloc main
start   lda #$A0
        jsr U_GETATR
        bne s1
        lda COMTAB+7           ; no name: standard input, from its start
        sta file_id
        jmp opts
s1      lda #4
        sta mode
        jsr FOPEN
        jsr U_GETNUM           ; start, count
        beq opts
        jsr num24
        sta pos
        stx pos+1
        sty pos+2
        jsr U_GETNUM
        beq opts
        jsr num24
        sta count
        stx count+1
        sty count+2
opts    lda a_opt
        ldx a_opt+1
        ldy #12
        jsr U_SLASH
        jsr nocomma            ; hex with no commas: 10 to a line
        bcc o1
        lda #10
        sta size
o1      bit opt_l              ; the numbers of the options, in this order
        bpl o2
        jsr U_GETNUM
        beq o2
        sta line
        stx line+1
        jsr U_GETNUM
        beq o2
        sta step
        stx step+1
o2      bit opt_s
        bpl o3
        jsr U_GETNUM
        beq o3
        sta size
o3      ldx #2                 ; (kernel FSEEK)
o4      lda pos,x
        sta addpos,x
        dex
        bpl o4
        ldy #2
        jsr jkernel
        bpl o5
        cmp #E_NOFUNC
        beq o5
        jmp U_FAIL
o5      lda a_end
        ldx a_end+1
        jsr U_SFAIL

* the numbers: a count of 0 shows none, any other all up to the end (as
* SDX's DATA does)
next    lda count
        ora count+1
        ora count+2
        jeq done
        jsr FGETC
        jmi done
        sta byte
        lda items              ; a new line: none yet, or this one full
        beq n3
        cmp size
        bcc n5
n3      jsr PRINTF
        dta EOL,0
        bit opt_n
        bmi n4
        jsr PRINTF
        dta c'%d ',0
        dta a(line)
n4      jsr PRINTF
        dta c'DATA ',0
        clc
        lda line
        adc step
        sta line
        lda line+1
        adc step+1
        sta line+1
        lda #0
        sta items
        beq n6
n5      jsr nocomma
        bcs n6
        jsr PRINTF
        dta c',',0
n6      bit opt_h
        bpl n8
        bit opt_dol
        bpl n7
        jsr PRINTF
        dta c'$',0
n7      jsr PRINTF
        dta c'%02x',0
        dta a(byte)
        jmp n9
n8      jsr PRINTF
        dta c'%b',0
        dta a(byte)
n9      inc items
        jmp next
done    jsr U_XFAIL
end     jsr PRINTF             ; (U_SFAIL: an error while reading)
        dta EOL,0
        rts

* nocomma: C=1 when both /H and /C are given
nocomma lda opt_h
        and opt_c
        asl @
        rts

* num24: the number just read by U_GETNUM in A, X, Y (24 bits; $FFFFFF
* when larger)
num24   ldy COMTAB-3
        beq nm1
        lda #$FF
        tax
        tay
        rts
nm1     ldy COMTAB-4
        rts

a_opt   dta a(opt_h)
a_end   dta a(end)
opt_h   dta 0,c'H'
opt_l   dta 0,c'L'
opt_n   dta 0,c'N'
opt_dol dta 0,c'$'
opt_c   dta 0,c'C'
opt_s   dta 0,c'S'
pos     dta 0,0,0
count   dta $FF,$FF,$FF
size    dta 7
items   dta 0
line    dta a(10)
step    dta a(1)
byte    dta 0,0

        blk update address
        blk update symbols
