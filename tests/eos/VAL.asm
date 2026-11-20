; EOS test: VALIDATE on dates and times at $077B (day, month, year, hour,
; minute, second): one line of results, 0 valid, 1 not, for each case.
PRINTF   smb 'PRINTF'
VALIDATE smb 'VALIDATE'
EOL      equ $9B
date     equ $077B

        blk reloc main
start   ldx #0
        stx n
s1      ldy #0                 ; the case's six bytes, then what to check
s2      lda cases,x
        sta date,y
        inx
        iny
        cpy #6
        bcc s2
        lda cases,x
        inx
        stx x
        jsr VALIDATE
        lda #'0'
        adc #0                 ; (C)
        ldy n
        sta out,y
        inc n
        ldx x
        cpx #ncase*7
        bcc s1
        jsr PRINTF
        dta c'v %s',EOL,0
        dta a(out)
        rts
cases   dta b(1,1,0,0,0,0,3)      ; 1-1-2000 00:00:00
        dta b(31,12,99,23,59,59,3) ; the last second
        dta b(29,2,24,12,0,0,3)   ; leap day
        dta b(29,2,25,12,0,0,3)   ; not a leap year
        dta b(31,4,25,0,0,0,1)    ; April 31st
        dta b(0,1,25,0,0,0,1)     ; day 0
        dta b(1,13,25,0,0,0,1)    ; month 13
        dta b(1,1,25,24,0,0,2)    ; hour 24
        dta b(1,1,25,0,60,0,2)    ; minute 60
        dta b(255,255,255,0,0,0,2) ; a bad date, only the time asked
        dta b(1,1,25,99,99,99,1)  ; a bad time, only the date asked
ncase   equ 11
n       dta 0
x       dta 0
out     :12 dta 0

        blk update address
        blk update symbols
