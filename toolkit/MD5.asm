; EOS Toolkit: MD5, the MD5 hash of files, or files checked against hashes
;   MD5 [/H] [+|-][A|H|P] file ...
;   MD5 [/H] /C [+|-][A|H|P] hashfile
; Each file's hash as "MD5 (NAME) = hex". With /C each line of the hash
; file names a file and its hash, as MD5 writes them or as md5sum does
; ("hex  name", "hex *name"); lines may end with EOL, LF or CR LF, others
; are skipped. Each file named is hashed and "name: OK" or "name: BAD"
; shown. /H turns the screen off meanwhile. A parameter that starts with
; a / ends the list.
U_SLASH  smb 'U_SLASH'
U_GETATR smb 'U_GETATR'
U_FAIL   smb 'U_FAIL'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
FOPEN    smb 'FOPEN'
FREAD    smb 'FREAD'
FGETC    smb 'FGETC'
FCLOSE   smb 'FCLOSE'
FCLOSEAL smb 'FCLOSEAL'
TOUPPER  smb 'TOUPPER'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

COMFNAM  equ $21               ; (COMTAB+: the parameter)
BRKKEY   equ $11
RTCLOK   equ $14
SDMCTL   equ $022F
file_id  equ $0760
mode     equ $0778
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
EOL      equ $9B
E_BREAK  equ 128
E_LONG   equ 137               ; a hash file line too long

* zero page: the working variables a, b, c, d and t of a block
va       equ $80
vb       equ $84
vc       equ $88
vd       equ $8C
t        equ $90
ri       equ $94               ; the step, 0-63
rs       equ $95               ; its rotation

        blk reloc main
start   lda a_opt
        ldx a_opt+1
        ldy #4
        jsr U_SLASH
        bit opt_c              ; /C: the hash file opened first
        bpl s1
        lda #$A0
        jsr U_GETATR
        lda #4
        sta mode
        jsr FOPEN
        lda file_id
        sta hfile
s1      lda SDMCTL
        sta dma
        lda a_trap
        ldx a_trap+1
        jsr U_SFAIL
        bit opt_h              ; /H: the screen off, from the next frame
        bpl s2
        lda #0
        sta SDMCTL
        lda RTCLOK
s1a     cmp RTCLOK
        beq s1a
s2      bit opt_c
        bmi s3
        jsr list
        jmp s4
s3      jsr check
s4      jsr U_XFAIL
        lda dma
        sta SDMCTL
        jmp FCLOSEAL
trap    lda dma                ; (U_SFAIL: an error ends MD5 quietly, as
        sta SDMCTL             ; on SDX)
        jmp FCLOSEAL

* list: each file named; none at all: the usage lines
list    lda #$A0
        jsr U_GETATR
        beq l1
        lda COMTAB+COMFNAM
        cmp #'/'
        beq l1
        lda a_cfn
        sta FILE_P
        lda a_cfn+1
        sta FILE_P+1
        jsr hashf
        jsr PRINTF
        dta c'MD5 (%s) = %s',EOL,0
        dta a(COMTAB+COMFNAM,hexs)
        sec
        ror shown
        jmp list
l1      bit shown
        bmi l2
        jsr PRINTF
        dta EOL,c'Use:',EOL,EOL
        dta c'MD5 [/H] [d:][path]filename.ext ...',EOL,EOL
        dta c'or',EOL,EOL
        dta c'MD5 [/H] /C [d:][path]hashfile.ext',EOL,EOL
        dta c'/H screen off (ANTIC DMA off)',EOL,0
l2      rts

* check: the hash file, line by line
check   lda hfile
        sta file_id
        jsr getline
        bpl c1
        jmp FCLOSE
c1      ldy #0
        jsr skipsp
        beq check
        sty mark
        ldx #0                 ; MD5 (name) = hex?
c2      lda line,y
        jsr TOUPPER
        cmp t_md5,x
        bne c3
        iny
        beq check
        inx
        cpx #3
        bcc c2
        bcs c4
c3      ldy mark               ; hex  name?
        lda line,y
        jsr hexdig
        bcs check
        sec                    ; (md5sum's)
        bcs c8
c4      jsr nextwd
        bcs check
        lda line,y
        cmp #'('
        bne check
        sec                    ; the name after the (
        jsr setname
c5      iny
        beq c_skip
        lda line,y
        cmp #')'
        bne c5
        sty mark
        jsr nextwd
        lda line,y
        cmp #'='
        bne c_skip
        jsr nextwd
        bcs c_skip
c8      php                    ; C=1: md5sum's line
        ldx #0
c9      lda line,y             ; 32 hex digits
        jsr hexdig
        bcs c_skp1
        asl @
        asl @
        asl @
        asl @
        sta t
        lda line+1,y
        jsr hexdig
        bcs c_skp1
        ora t
        sta want,x
        iny
        iny
        inx
        cpx #16
        bcc c9
        plp
        bcs c10
        lda line,y             ; MD5's: no more hex, the name up to the )
        jsr hexdig
        bcc c_skip
        ldx mark
        lda #EOL
        sta line,x
        bne c12
c_skp1  plp
c_skip  jmp check
c10     lda line,y             ; md5sum's: a blank, then the name, after a *
        cmp #' '               ; when there is one
        bne c_skip
        jsr nextwd
        bcs c_skip
        lda line,y
        cmp #'*'
        beq c11
        clc
c11     jsr setname
c12     jsr PRINTF
        dta c'%p: ',0
        dta a(FILE_P)
        jsr hashf
        ldx #15
c13     lda h,x
        cmp want,x
        bne c14
        dex
        bpl c13
        jsr PRINTF
        dta c'OK',EOL,0
        jmp check
c14     jsr PRINTF
        dta c'\iBAD\i',EOL,0
        jmp check

* setname: FILE_P = line + Y + C
setname tya
        adc a_line
        sta FILE_P
        lda #0
        adc a_line+1
        sta FILE_P+1
        rts

* skipsp: Y past blanks; Z=1 at the line's end
skipsp  lda line,y
        cmp #' '
        bne ss1
        iny
        bne skipsp
ss1     cmp #EOL
        rts
* nextwd: Y past this word and the blanks after it; C=1 at the line's end
nextwd  lda line,y
        cmp #EOL
        beq nw2
        cmp #' '
        beq nw1
        iny
        bne nextwd
        beq nw2
nw1     jsr skipsp
        bne nw3
nw2     sec
        rts
nw3     clc
        rts

* hexdig: A a hex digit (either case): C=0 and A its value; else C=1
hexdig  jsr TOUPPER
        cmp #'0'
        bcc hd_no
        cmp #'9'+1
        bcc hd1
        cmp #'A'
        bcc hd_no
        cmp #'F'+1
        bcs hd_no
        sbc #6                 ; (C=0: A-F to $3A-$3F)
hd1     and #$0F
        clc
        rts
hd_no   sec
        rts

* getline: the next line of file_id to line, an EOL at its end (so the
* name in it ends as FOPEN wants); N=1 at the end of the file with nothing
* read
getline ldy #0
gl1     jsr FGETC
        bmi gl_eof
        cmp #EOL
        beq gl_end
        cmp #$0A
        beq gl_end
        cmp #$0D
        bne gl2
        jsr FGETC              ; CR LF; a CR alone stays
        cmp #$0A
        beq gl_end
        pha
        lda #$0D
        sta line,y
        iny
        pla
gl2     sta line,y
        iny
        bne gl1
        lda #E_LONG
        jmp U_FAIL
gl_eof  tya
        bne gl_end
        ldx #$FF
        rts
gl_end  lda #EOL
        sta line,y
        lda #0
        rts

* hashf: the hash of the file named at FILE_P to h, and as hex to hexs
hashf   lda #4
        sta mode
        jsr FOPEN
        lda file_id
        sta dfile
        ldx #15
hf1     lda h_init,x
        sta h,x
        dex
        bpl hf1
        lda #0
        ldx #3
hf2     sta cnt,x
        dex
        bpl hf2
hf3     lda dfile              ; 64 bytes at a time
        sta file_id
        lda a_blk
        sta addpos
        lda a_blk+1
        sta addpos+1
        lda #64
        sta bytbuf
        lda #0
        sta bytbuf+1
        sta memreix
        jsr FREAD
        lda bytbuf
        sta n
        clc
        adc cnt
        sta cnt
        bcc hf4
        inc cnt+1
        bne hf4
        inc cnt+2
        bne hf4
        inc cnt+3
hf4     lda n
        cmp #64
        bne hf5
        jsr md5blk
        jmp hf3
hf5     ldx n                  ; the end: $80, zeros, the length in bits
        lda #$80
        sta blk,x
        inx
        lda #0
hf6     cpx #64
        bcs hf7
        sta blk,x
        inx
        bne hf6
hf7     lda n
        cmp #56
        bcc hf9
        jsr md5blk             ; no room for the length in this block
        ldx #63
        lda #0
hf8     sta blk,x
        dex
        bpl hf8
hf9     ldx #0                 ; cnt * 8
        clc
hf10    lda cnt,x
        sta blk+56,x
        inx
        txa
        eor #4
        bne hf10
        lda #0
        sta blk+60
        ldx #3
hf11    asl blk+56
        rol blk+57
        rol blk+58
        rol blk+59
        rol blk+60
        dex
        bne hf11
        jsr md5blk
        lda dfile
        sta file_id
        jsr FCLOSE
        ldx #0                 ; the hex
        ldy #0
hf12    lda h,x
        lsr @
        lsr @
        lsr @
        lsr @
        jsr hexout
        lda h,x
        and #$0F
        jsr hexout
        inx
        cpx #16
        bcc hf12
        lda #0
        sta hexs,y
        rts
hexout  cmp #10
        bcc ho1
        adc #'A'-10-1-'0'      ; (C=1)
ho1     adc #'0'
        sta hexs,y
        iny
        rts

* md5blk: the 64-byte block at blk added to the hash h; Break: 128
md5blk  ldx #15
mb1     lda h,x
        sta va,x
        dex
        bpl mb1
        ldy #0
step    sty ri
        tya
        and #$30
        beq fun_f
        cmp #$20
        bcc fun_g
        beq fun_h
        ldx #3                 ; I = c ^ (b | ~d)
fi1     lda vd,x
        eor #$FF
        ora vb,x
        eor vc,x
        sta t,x
        dex
        bpl fi1
        bmi sum
fun_f   ldx #3                 ; F = d ^ (b & (c ^ d))
ff1     lda vc,x
        eor vd,x
        and vb,x
        eor vd,x
        sta t,x
        dex
        bpl ff1
        bmi sum
fun_g   ldx #3                 ; G = c ^ (d & (b ^ c))
fg1     lda vb,x
        eor vc,x
        and vd,x
        eor vc,x
        sta t,x
        dex
        bpl fg1
        bmi sum
fun_h   ldx #3                 ; H = b ^ c ^ d
fh1     lda vb,x
        eor vc,x
        eor vd,x
        sta t,x
        dex
        bpl fh1
sum     clc                    ; t = t + a + K[i] + M[g]
        lda t
        adc va
        sta t
        lda t+1
        adc va+1
        sta t+1
        lda t+2
        adc va+2
        sta t+2
        lda t+3
        adc va+3
        sta t+3
        clc
        lda t
        adc k0,y
        sta t
        lda t+1
        adc k1,y
        sta t+1
        lda t+2
        adc k2,y
        sta t+2
        lda t+3
        adc k3,y
        sta t+3
        ldx gtab,y
        clc
        lda t
        adc blk,x
        sta t
        lda t+1
        adc blk+1,x
        sta t+1
        lda t+2
        adc blk+2,x
        sta t+2
        lda t+3
        adc blk+3,x
        sta t+3
        tya                    ; t rotated left by s: whole bytes, then bits
        and #3
        sta rs
        tya
        lsr @
        lsr @
        and #$0C
        ora rs
        tax
        lda stab,x
        sta rs
        lsr @
        lsr @
        lsr @
        tax
        beq rot2
rot1    lda t+3
        ldy t+2
        sty t+3
        ldy t+1
        sty t+2
        ldy t
        sty t+1
        sta t
        dex
        bne rot1
rot2    lda rs
        and #7
        tax
        beq rot4
rot3    lda t+3
        asl @
        rol t
        rol t+1
        rol t+2
        rol t+3
        dex
        bne rot3
rot4    clc                    ; t = b + t; then a, b, c, d = d, t, b, c
        lda t
        adc vb
        sta t
        lda t+1
        adc vb+1
        sta t+1
        lda t+2
        adc vb+2
        sta t+2
        lda t+3
        adc vb+3
        sta t+3
        ldx #3
mv1     lda vd,x
        sta va,x
        lda vc,x
        sta vd,x
        lda vb,x
        sta vc,x
        lda t,x
        sta vb,x
        dex
        bpl mv1
        ldy ri
        iny
        cpy #64
        jcc step
        ldx #0                 ; h = h + a, b, c, d
mb2     clc
        ldy #4
mb3     lda h,x
        adc va,x
        sta h,x
        inx
        dey
        bne mb3
        cpx #16
        bcc mb2
        lda BRKKEY
        bne mb4
        dec BRKKEY
        lda #E_BREAK
        jmp U_FAIL
mb4     rts

a_opt   dta a(opt_h)
a_trap  dta a(trap)
a_cfn   dta a(COMTAB+COMFNAM)
a_line  dta a(line)
a_blk   dta a(blk)
opt_h   dta 0,c'H'
opt_c   dta 0,c'C'
t_md5   dta c'MD5'
h_init  dta $01,$23,$45,$67,$89,$AB,$CD,$EF,$FE,$DC,$BA,$98,$76,$54,$32,$10
stab    dta 7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21
gtab    dta 0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60
        dta 4,24,44,0,20,40,60,16,36,56,12,32,52,8,28,48
        dta 20,32,44,56,4,16,28,40,52,0,12,24,36,48,60,8
        dta 0,28,56,20,48,12,40,4,32,60,24,52,16,44,8,36
k0      dta $78,$56,$DB,$EE,$AF,$2A,$13,$01,$D8,$AF,$B1,$BE,$22,$93,$8E,$21
        dta $62,$40,$51,$AA,$5D,$53,$81,$C8,$E6,$D6,$87,$ED,$05,$F8,$D9,$8A
        dta $42,$81,$22,$0C,$44,$A9,$60,$70,$C6,$FA,$85,$05,$39,$E5,$F8,$65
        dta $44,$97,$A7,$39,$C3,$92,$7D,$D1,$4F,$E0,$14,$A1,$82,$35,$BB,$91
k1      dta $A4,$B7,$70,$CE,$0F,$C6,$46,$95,$98,$F7,$5B,$D7,$11,$71,$43,$08
        dta $25,$B3,$5A,$C7,$10,$14,$E6,$FB,$CD,$07,$0D,$14,$E9,$A3,$02,$4C
        dta $39,$F6,$61,$38,$EA,$CF,$4B,$BC,$7E,$27,$30,$1D,$D0,$99,$7C,$56
        dta $22,$FF,$23,$A0,$59,$CC,$F4,$5D,$7E,$E6,$43,$11,$7E,$F2,$D2,$D3
k2      dta $6A,$C7,$20,$BD,$7C,$87,$30,$46,$80,$44,$FF,$5C,$90,$98,$79,$B4
        dta $1E,$40,$5E,$B6,$2F,$44,$A1,$D3,$E1,$37,$D5,$5A,$E3,$EF,$6F,$2A
        dta $FA,$71,$9D,$E5,$BE,$DE,$BB,$BF,$9B,$A1,$EF,$88,$D4,$DB,$A2,$AC
        dta $29,$2A,$94,$93,$5B,$0C,$EF,$84,$A8,$2C,$01,$08,$53,$3A,$D7,$86
k3      dta $D7,$E8,$24,$C1,$F5,$47,$A8,$FD,$69,$8B,$FF,$89,$6B,$FD,$A6,$49
        dta $F6,$C0,$26,$E9,$D6,$02,$D8,$E7,$21,$C3,$F4,$45,$A9,$FC,$67,$8D
        dta $FF,$87,$6D,$FD,$A4,$4B,$F6,$BE,$28,$EA,$D4,$04,$D9,$E6,$1F,$C4
        dta $F4,$43,$AB,$FC,$65,$8F,$FF,$85,$6F,$FE,$A3,$4E,$F7,$BD,$2A,$EB
shown   dta 0                  ; bit 7: a hash was shown
dma     dta 0
hfile   dta 0
dfile   dta 0
mark    dta 0
n       dta 0
cnt     dta 0,0,0,0
h       :16 dta 0
want    :16 dta 0
hexs    :33 dta 0
blk     :64 dta 0
line    equ *                  ; the hash file's line: the free memory after
                               ; the program (257 bytes)

        blk update address
        blk update symbols
