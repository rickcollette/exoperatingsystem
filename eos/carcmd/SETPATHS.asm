; EOS CAR: SETPATHS, current directories of the drives
;   SETPATHS [d:][path] | fname[.ext]
; A parameter ending in ':', '>', '<' or a backslash is a directory: it
; becomes the current one of its drive (an error as any other). Anything
; else is a directory when there is one of that name, else a text file
; with a directory on each line; those that exist become current, the
; others are skipped. A file that cannot be opened: "Setpaths: " and
; the error message. No parameter: 156.
U_GETPAR smb 'U_GETPAR'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
FGETC    smb 'FGETC'
CHDIR    smb 'CHDIR'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
U_FAIL   smb 'U_FAIL'
ERR_DMSG smb 'ERR_DMSG'
PUTC     smb 'PUTC'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'
FILE_P   smb 'FILE_P'

file_id  equ $0760
mode     equ $0778
scan     equ $0779
attr     equ $077A
BSLASH   equ $5C
EOL      equ $9B

        blk reloc main
start   jsr U_GETPAR
        bne s0
        lda #156               ; no parameter
        jmp U_FAIL
s0      lda COMTAB+$20,x       ; its last character (X = its length)
        cmp #':'
        beq s_dir
        cmp #'/'
        beq s_dir
        cmp #'<'
        beq s_dir
        cmp #BSLASH
        bne s_file
s_dir   jmp CHDIR              ; FILE_P is the parameter
s_file  lda trdv               ; an existing directory, else a file
        ldx trdv+1
        jsr U_SFAIL
        jsr CHDIR
        jmp U_XFAIL
trapd   lda trfv               ; the file: "Setpaths: " and the error
        ldx trfv+1             ; when it cannot be opened
        jsr U_SFAIL
        lda #4
        sta mode
        lda #0
        sta scan
        sta attr
        jsr FOPEN
        jsr U_XFAIL
        lda file_id
        sta hnd
f1      ldx #0                 ; a line, in capitals
        stx eof
f2      stx lx
        lda hnd
        sta file_id
        jsr FGETC
        bpl f3
        inc eof                ; the end of the file
        lda #EOL
f3      ldx lx
        cmp #'a'
        bcc f4
        cmp #'z'+1
        bcs f4
        and #$DF
f4      cmp #' '               ; blanks are left out
        beq f2
        sta line,x
        cmp #EOL
        beq f5
        cpx #63
        bcs f2
        inx
        bne f2
f5      txa                    ; an empty line
        beq f6
        lda lna
        sta FILE_P
        lda lna+1
        sta FILE_P+1
        lda trapv              ; a directory that is not there: skipped
        ldx trapv+1
        jsr U_SFAIL
        jsr CHDIR
        jsr U_XFAIL
trap
f6      lda eof
        beq f1
        lda hnd
        sta file_id
        jmp FCLOSE

* trapf: the file could not be opened
trapf   pha
        jsr PRINTF
        dta c'Setpaths: ',0
        pla
        jsr ERR_DMSG
        lda #EOL
        jmp PUTC

trapv   dta a(trap)
trdv    dta a(trapd)
trfv    dta a(trapf)
lna     dta a(line)
hnd     dta 0
eof     dta 0
lx      dta 0
line    :65 dta 0

        blk update address
        blk update symbols
