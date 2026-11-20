; EOS Toolkit: APETIME, the date and time from APE
;   APETIME [/Q]   (also as a driver: DEVICE APETIME [/Q])
; The PC side of the SIO bus (APE, AspeQt, RespeQt, Altirra's SIO clock)
; answers device $45, command $93 with AUX $A0EE: six bytes, day, month,
; year, hour, minute, second. They are shown (unless /Q) and set as the
; system's date and time (CLK: kernel function 101, kd_settd).
U_SLASH  smb 'U_SLASH'
PRINTF   smb 'PRINTF'

jkernel  equ $0703
device   equ $0761
date     equ $077B             ; date, then time: 6 bytes
SIOV     equ $E459
DDEVIC   equ $0300
EOL      equ $9B
CLK      equ $10               ; the clock's device byte
SETTD    equ 101

        blk reloc main
start   lda optp
        ldx optp+1
        ldy #2
        jsr U_SLASH
        ldx #11                ; the command
s1      lda dcb,x
        sta DDEVIC,x
        dex
        bpl s1
        lda tdp                ; to tdbuf
        sta DDEVIC+4
        lda tdp+1
        sta DDEVIC+5
        jsr SIOV
        bpl s2
        jsr PRINTF
        dta c'Cannot get DATE/TIME',EOL,0
        rts
s2      bit quiet
        bmi s3
        jsr PRINTF
        dta c'Date/time: %2b-%02b-%02b %2b:%02b:%02b',EOL,0
        dta a(tdbuf,tdbuf+1,tdbuf+2,tdbuf+3,tdbuf+4,tdbuf+5)
s3      ldx #5                 ; to the clock
s4      lda tdbuf,x
        sta date,x
        dex
        bpl s4
        lda #CLK
        sta device
        ldy #SETTD
        jmp jkernel

optp    dta a(quiet)
quiet   dta 0,c'Q'
tdp     dta a(tdbuf)
dcb     dta $45,1,$93,$40,0,0,6,0,6,0,$EE,$A0
tdbuf   dta 0,0,0,0,0,0

        blk update address
        blk update symbols
