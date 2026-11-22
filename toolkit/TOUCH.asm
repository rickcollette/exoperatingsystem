; EOS Toolkit: TOUCH, a new empty file or a new date for one
;   TOUCH [/C|/H] [d:][path]filename.ext
; The file is opened for update and closed: a missing one is made empty,
; an existing one (or directory) gets the date and time of now. /C: a
; missing file is not made. /H: a symbolic link itself, not its target.
; A device without directories (error 146 on the search) is opened as it
; is. No name: error 156.
U_SLASH  smb 'U_SLASH'
U_GETPAR smb 'U_GETPAR'
U_ARGV   smb 'U_ARGV'
U_FAIL   smb 'U_FAIL'
U_SFAIL  smb 'U_SFAIL'
U_XFAIL  smb 'U_XFAIL'
FFIRST   smb 'FFIRST'
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'

mode     equ $0778
scan     equ $0779
attr     equ $077A
dentry   equ $0789
EOL      equ $9B

        blk reloc main
start   lda #$FF
        jsr U_ARGV
        lda a_opts
        ldx a_opts+1
        ldy #4
        jsr U_SLASH
        jsr U_GETPAR
        bne s1
        lda #156
fail    jmp U_FAIL
nodir   cmp #146               ; the search failed: only "no directory"
        bne fail               ; goes on, as for a file that is there
        lda #$80
        sta found
        bne s2
s1      lda #0
        sta found
        sta status
        sta scan
        lda a_nodir
        ldx a_nodir+1
        jsr U_SFAIL
        jsr FFIRST
        jsr U_XFAIL
        php
        jsr FCLOSE
        pla
        eor #$80               ; N=1 from FFIRST: not there
        sta found
        lda dentry
        sta status
s2      bit found
        bpl s3
        lda status             ; a link and /H: the link itself
        and #$40
        beq s3
        bit opt_h
        bpl s3
        lda #$44
        sta scan
s3      lda #0
        sta attr
        bit opt_c
        bpl s4
        bit found
        bpl s5
s4      lda #$0C               ; open for update, then close
        sta mode
        jsr FOPEN
        jmp FCLOSE
s5      rts

a_opts  dta a(opt_c)
a_nodir dta a(nodir)
opt_c   dta b(0),c'C'
opt_h   dta b(0),c'H'
found   dta 0                  ; bit 7: the file is there
status  dta 0

        blk update address
        blk update symbols
