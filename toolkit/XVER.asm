; EOS Toolkit: XVER, the version and build of the DOS on the cartridge
;   XVER
; Two lines: EOS's version, the SpartaDOS X version it stands in for, and
; the date and time of CAR:COMMAND.COM (the build's); then the cartridge
; the kernel names and whether it passes another cartridge through:
;   EOS <VERSION> (SDX 4.50)  3-11-26 12:00:00
;   Build: EOS, not pass-through
; The date is day-month-year, month-day-year when DAYTIME is 1.
FOPEN    smb 'FOPEN'
FCLOSE   smb 'FCLOSE'
GETENV   smb 'GETENV'
PRINTF   smb 'PRINTF'
FILE_P   smb 'FILE_P'
COMTAB   smb 'COMTAB'

version  equ $0701             ; the SDX version (BCD) and revision
revision equ $0702
jhwctrl  equ $070F             ; X=4: the cartridge's type in A (bit 7:
                               ; pass-through), its name at COMTAB+$BF
mode     equ $0778
addpos   equ $0782
fdate    equ $079A             ; (FOPEN: the file's entry, its date and
                               ; time from here)
envval   equ $0580             ; (GETENV: the value)
EOL      equ $9B

        blk reloc main
start   lda version            ; 4.50: 4 and 5, then the revision
        lsr @
        lsr @
        lsr @
        lsr @
        sta vmaj
        lda version
        and #$0F
        sta vmin
        lda #$14               ; open to read, with the file's entry
        sta mode
        lda #0
        sta addpos
        lda pcmd
        sta FILE_P
        lda pcmd+1
        sta FILE_P+1
        jsr FOPEN
        jsr FCLOSE
        jsr daytime            ; DAYTIME 1: month first
        bne dmy
        lda pdate              ; (the day's and the month's arguments
        ldx pdate+2            ; change places)
        sta pdate+2
        stx pdate
        lda pdate+1
        ldx pdate+3
        sta pdate+3
        stx pdate+1
dmy     jsr PRINTF
        dta c'EOS '
        icl 'version.icl'
        dta c' (SDX %b.%b%b) %2b-%02b-%02b %2b:%02b:%02b',b(EOL),0
        dta a(vmaj,vmin,revision)
pdate   dta a(fdate,fdate+1,fdate+2,fdate+3,fdate+4,fdate+5)
        ldx #4
        jsr jhwctrl
        sta ctype
        jsr PRINTF
        dta c'Build: %s, ',0
        dta a(COMTAB+$BF)
        bit ctype
        bmi pass
        jsr PRINTF
        dta c'not ',0
pass    jsr PRINTF
        dta c'pass-through',b(EOL),0
        rts

* daytime: Z=1 when the variable DAYTIME is 1
daytime lda pday
        ldx pday+1
        jsr GETENV
        bmi dt_no
        lda envval
        cmp #'1'
        bne dt_ret
        lda envval+1
        cmp #EOL
dt_ret  rts
dt_no   lda #1                 ; (Z=0)
        rts

pcmd    dta a(cmd)             ; (addresses in the program: words, which
pday    dta a(day)             ; the loader relocates)
cmd     dta c'CAR:COMMAND.COM',b(EOL)
day     dta c'DAYTIME',b(EOL)
vmaj    dta 0
vmin    dta 0
ctype   dta 0

        blk update address
        blk update symbols
