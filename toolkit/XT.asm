; EOS Toolkit: XT, how long a command takes
;   XT command [parameters]
; The command line after XT runs through the command processor (XCOMLI),
; then its time is printed as "Time: h:mm:ss.hh", counted in video frames
; (50 a second on PAL, 60 on NTSC): loading a program counts too, and a
; command that stops the frame counter is timed wrong.
U_GETPAR smb 'U_GETPAR'
XCOMLI   smb 'XCOMLI'
PRINTF   smb 'PRINTF'
COMTAB   smb 'COMTAB'

BUFOFF   equ $0A               ; (COMTAB+)
LBUF     equ $3F
RTCLOK   equ $12               ; the frame counter, high byte first
PAL      equ $D014             ; bits 1-3 0: PAL
EOL      equ $9B

        blk reloc main
start   ldx COMTAB+BUFOFF      ; the command line from the command on
        ldy #0
        sty COMTAB+BUFOFF
sh1     lda COMTAB+LBUF,x
        sta COMTAB+LBUF,y
        inx
        iny
        cpy #64
        bcc sh1
        jsr U_GETPAR
        bne go
        jsr PRINTF
        dta b(EOL),c'Use: xt cmd [parms]',b(EOL),0
        rts
go      lda #0
        sta COMTAB+BUFOFF
        jsr frame              ; the start
        stx t0
        sty t0+1
        sta t0+2
        jsr XCOMLI
        jsr frame              ; frames since: t = now - start
        sta t+2
        sec
        txa
        sbc t0
        sta t
        tya
        sbc t0+1
        sta t+1
        lda t+2
        sbc t0+2
        sta t+2
        lda #50
        ldx PAL
        txa
        and #$0E
        beq fps
        lda #60
fps     sta rate
        jsr div                ; t = seconds, A = frames over
        tax                    ; hundredths = frames * 100 / rate
        lda #0
        sta cs
        sta cs+1
cs0     dex
        bmi cs1
        lda cs
        clc
        adc #100
        sta cs
        bcc cs0
        inc cs+1
        bcs cs0
cs1     ldx #0
cs1a    lda cs
        sec
        sbc rate
        tay
        lda cs+1
        sbc #0
        bcc cs2
        sta cs+1
        sty cs
        inx
        bne cs1a
cs2     stx hund
        lda #60
        sta rate
        jsr div                ; t = minutes
        sta sec
        jsr div                ; t = hours
        sta min
        lda t
        sta hour
        jsr PRINTF
        dta b(EOL),c'Time: %b:%02b:%02b.%02b',b(EOL),0
        dta a(hour,min,sec,hund)
        rts

* frame: the frame counter once it has just changed: X low, Y middle,
* A high
frame   lda RTCLOK+2
fr1     cmp RTCLOK+2
        beq fr1
        ldx RTCLOK+2
        ldy RTCLOK+1
        lda RTCLOK
        rts

* div: t (24 bits) = t / rate, A the remainder
div     lda #0
        ldx #24
dv1     asl t
        rol t+1
        rol t+2
        rol @
        bcs dv2                ; (rate < 128: never)
        cmp rate
        bcc dv3
dv2     sbc rate
        inc t
dv3     dex
        bne dv1
        rts

t0      dta 0,0,0
t       dta 0,0,0
rate    dta 0
cs      dta a(0)
hour    dta 0
min     dta 0
sec     dta 0
hund    dta 0

        blk update address
        blk update symbols
