; EOS Toolkit: MV, rename one EOSFS entry within its filesystem.
;   mv source destination
; This compact frontend uses the native argv interface.  Cross-filesystem
; moves are deliberately rejected by the filesystem rename operation.
U_ARGC smb 'U_ARGC'
U_ARGV smb 'U_ARGV'
RENAME smb 'RENAME'
PRINTF smb 'PRINTF'
FILE_P smb 'FILE_P'

EOL equ $9B
ptr equ $80

        blk reloc main
start   jsr U_ARGC
        cmp #2
        beq helpq
        cmp #3
        bne usage
        ldx #0
        lda #1
        jsr append
        lda #','
        sta pair,x
        inx
        lda #2
        jsr append
        lda #EOL
        sta pair,x
        lda a_pair
        sta FILE_P
        lda a_pair+1
        sta FILE_P+1
        jmp RENAME
helpq   lda #1
        jsr U_ARGV
        cpy #6
        bne usage
        sta ptr
        stx ptr+1
        ldy #0
hq1     lda (ptr),y
        cmp help,y
        bne usage
        iny
        cpy #6
        bcc hq1
usage   jsr PRINTF
        dta c'Use: mv source destination',EOL,0
        rts

append  sta argi
        stx out
        lda argi
        jsr U_ARGV
        sta ptr
        stx ptr+1
        sty len
        ldx out
        ldy #0
ap1     cpy len
        beq ap2
        lda (ptr),y
        sta pair,x
        inx
        iny
        bne ap1
ap2     rts

help dta c'--help'
out  dta 0
argi dta 0
len  dta 0
a_pair dta a(pair)
pair :256 dta 0

        blk update address
        blk update symbols
