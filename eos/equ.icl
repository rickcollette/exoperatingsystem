* EOS (Extendable Operating System): shared equates
*
* Fixed addresses follow SpartaDOS X 4.5 (the measurements in EOS_PLAN.md).
* Everything else is ours.

* ---- OS ----------------------------------------------------------------
WARMST  equ $08
BOOT    equ $09
DOSVEC  equ $0A
DOSINI  equ $0C
RTCLOK  equ $12
PALNTS  equ $62
COLDSV  equ $E477               ; the OS cold start
RANDOM  equ $D20A               ; POKEY random number
ICHIDZ  equ $20
ICDNOZ  equ $21
ICCOMZ  equ $22
ICSTAZ  equ $23
ICBALZ  equ $24
ICBAHZ  equ $25
ICPTLZ  equ $26
ICBLLZ  equ $28
ICBLHZ  equ $29
ICAX1Z  equ $2A
ICAX2Z  equ $2B
ICIDNO  equ $2E
CIOCHR  equ $2F
LMARGN  equ $52
RAMTOP  equ $6A
SAVMSC  equ $58
LBUFF   equ $0580
ENVBUF  equ $C000               ; environment, 256 bytes under the OS ROM
CMDNAME equ $C100               ; the program the command processor runs (32)
PIPEBUF equ CMDNAME+32         ; pipes (cp.asm): the commands still to run (64)
P_N     equ CMDNAME+96         ; the command running, 1 up; 0 no pipe
P_MORE  equ CMDNAME+97         ; not 0: another command follows it
P_TMP   equ CMDNAME+98         ; $TEMP's value (32)
COLDST  equ $244
RUNAD   equ $2E0
INITAD  equ $2E2
RAMSIZ  equ $2E4
MEMTOP  equ $2E5
MEMLO   equ $2E7
DVSTAT  equ $2EA
DDEVIC  equ $300
DUNIT   equ $301
DCOMND  equ $302
DSTATS  equ $303
DBUFLO  equ $304
DBUFHI  equ $305
DTIMLO  equ $306
DBYTLO  equ $308
DBYTHI  equ $309
DAUX1   equ $30A
DAUX2   equ $30B
HATABS  equ $31A
IOCB0   equ $340
ICAX4Z  equ $2D
ICHID   equ $00
ICDNO   equ $01
ICCOM   equ $02
ICSTA   equ $03
ICBAL   equ $04
ICBAH   equ $05
ICPTL   equ $06
ICPTH   equ $07
ICBLL   equ $08
ICBLH   equ $09
ICAX1   equ $0A
ICAX2   equ $0B
ICAX3   equ $0C
ICAX4   equ $0D
ICAX5   equ $0E
ICAX6   equ $0F
BASICF  equ $3F8
GINTLK  equ $3FA
TRIG3   equ $D013
PORTB   equ $D301
NMIEN   equ $D40E
fadr    equ $15                ; library pointer
CIOV    equ $E456
KEYBDV  equ $E420               ; K: handler table (get-byte vector at +4)
KBCODE  equ $D209
SIOV    equ $E459
PDVMSK  equ $0247              ; the OS: enabled PBI devices
VSERIN  equ $020A               ; serial interrupt vectors: VSERIN VSEROR VSEROC
POKMSK  equ $10
IRQEN   equ $D20E
SSKCTL  equ $0232
SKCTL   equ $D20F

* CIO commands
C_OPEN  equ $03
C_GETR  equ $05
C_GETB  equ $07
C_PUTR  equ $09
C_PUTB  equ $0B
C_CLOSE equ $0C

* ---- the cartridge's bank register -----------------------------------------
* AtariMax 1 MB (Maxflash 8 Mbit, CAR type 42): a write to $D500+n selects
* bank n (0-127), a write to $D580 switches the cartridge off.
* -D:U1MB=1, the U1MB SDX slot: the bank number is written to the SDX
* control latch $D5E0 (bit 7: SDX off).
* -D:SIC=1, SIC! and SIC!+: the value written to $D500 selects the 16K
* bank (bits 0-4; $A000-$BFFF shows its upper 8K), bit 6 switches
* $A000-$BFFF off; $8000-$9FFF (bit 5) stays off. tools/mksic.py puts EOS's
* bank n into the upper half of SIC! bank n.
* -D:SIDE=1 / -D:SIDE=2, SIDE and SIDE2 (512K flash, EOS at bank 0): the
* SDX bank register, $D5E0 / $D5E1: bits 0-5 the bank, bit 7 SDX off, bit
* 6 the top cartridge off (setbank sets it: EOS never shows it).
* -D:MYIDE2=1, MyIDE II (512K flash, EOS at page 0): the left window's
* page in $D508, the windows in $D50F ($3C: the left one flash, the right
* one and the keyhole off; $FC: all off).
* -D:SIDE3=1, SIDE3 (8M flash, EOS at $780000, where its SDX switch starts
* it): flash bank B ($A000) in $D5F9 (bank $C0 + n), $D5FA the windows
* ($E8: flash B on, its high bits $C0; $E0: off), written first.
.ifdef U1MB
BANKLATCH equ $D5E0
CARTOFF equ $80
.elseif .def SIDE
.if SIDE=2
BANKLATCH equ $D5E1
.else
BANKLATCH equ $D5E0
.endif
CARTOFF equ $80
IDE     equ 1                  ; EOS's own CompactFlash driver (ide.icl)
IDE_D   equ $D5F0              ; the ATA registers; $D5F8 bit 0: out of reset
.elseif .def MYIDE2
CARTOFF equ $80
IDE     equ 1
IDE_D   equ $D500              ; the ATA registers; $D50E power, reset
.elseif .def SIDE3
CARTOFF equ $80
IDE     equ 1                  ; the SD card, through ide.icl's drives
SD      equ 1                  ; (sd.icl: SPI at $D5F3-$D5F4)
IDE_D   equ $D5F0              ; (the ATA names unused)
.elseif .def SIC
BANKLATCH equ $D500
CARTOFF equ $40
.else
MAXBANK equ $D500
CARTOFF equ $80
.endif

* cartridge banks (eos/Makefile rules and tools/mkcarx.py agree on these)
BK_BOOT equ 0                  ; boot, reset, kernel image
BK_LIB  equ 1                  ; library: mapped while programs run
BK_FMS  equ 2                  ; DSK: file system
BK_CP   equ 3                  ; command processor
BK_DEV  equ 4                  ; character devices CON: PRN: NUL:
BK_LD   equ 5                  ; binary loader and the symbol table
BK_LIB2 equ 6                  ; more of the library, reached by farcall
BK_DOS2 equ 7                  ; the Atari DOS 2 file system (B9)
BK_CAR  equ 8                  ; the CAR: device (C5)
BK_CARD equ 9                  ; CAR:'s files, from this bank on
CARDLEN equ $1FF0              ; bytes of them per bank (the tail follows)

* every bank starts with a jump table at $A000 (3 bytes per entry) and ends
* with the same tail (eos/tail.icl)
CARTLO  equ $A000

* library entries for the other banks (lib.asm jump table)
L_GETPAR equ CARTLO+$00
L_GEFINA equ CARTLO+$03
L_FOPEN  equ CARTLO+$06
L_FCLOSE equ CARTLO+$09
L_FGETC  equ CARTLO+$0C
L_PUTC   equ CARTLO+$0F
L_FAIL   equ CARTLO+$12
L_FREAD  equ CARTLO+$15
L_PRINTF equ CARTLO+$18
L_GEFINA2 equ CARTLO+$1B       ; U_GEFINA, C=1 and A = status on error
L_CRUNCH equ CARTLO+$21        ; ZCRNAME
L_XALLOC equ CARTLO+$24        ; program extended memory: C=1 none
L_XBNEW  equ CARTLO+$27        ; a new bank for it: C=1 none
L_PUTENV equ CARTLO+$2A        ; PUTENV: AX = NAME=VALUE
L_NUMENV equ CARTLO+$2D        ; NUMENV: A = number, NAME=VALUE to LBUFF
L_ERROR  equ CARTLO+$30        ; EOL, the message for error A, EOL
L_DIVIO  equ CARTLO+$33        ; DIVIO: Y = 0 output, 1 input; FILE_P
L_XDIVIO equ CARTLO+$36        ; XDIVIO: Y
BOOT_USE equ CARTLO+$03        ; bank 0: the USE setting again (applyuse)
L_RENAME equ CARTLO+$39        ; RENAME: FILE_P = OLD NEW
L_RENDIR equ CARTLO+$3C        ; RENDIR
L_GETNUM equ CARTLO+$3F        ; U_GETNUM: Z=1 none; A, X the value
L_RENM   equ CARTLO+$42        ; RENAME: the status in A, N=1 an error
L_DRVNAME equ CARTLO+$45       ; drive A's name to dv_nm (A: or Dn:)

* loader entries (ld.asm jump table)
LD_LOAD  equ CARTLO+$00        ; U_LOAD
LD_LOOKUP equ CARTLO+$03       ; find the symbol ld_name: ld_val, C=1 none
LD_RESET equ CARTLO+$06        ; unload every program level (command processor)
LD_SLOOKUP equ CARTLO+$09      ; S_LOOKUP
LD_SADD  equ CARTLO+$0C        ; S_ADD
LD_SNEXT equ CARTLO+$0F        ; S_NEXT
LD_UNLOAD equ CARTLO+$12       ; U_UNLOAD
LD_SCLEAR equ CARTLO+$15       ; S_CLEAR
L2_FDOPEN equ CARTLO+$00       ; bank 6 (lib2)
L2_FDGETC equ CARTLO+$03
L2_FDCLOSE equ CARTLO+$06
L2_BWENTER equ CARTLO+$09      ; BW-DOS programs (bw.icl)
L2_BWLEAVE equ CARTLO+$0C
L2_BWOUT equ CARTLO+$0F
L2_BWIN equ CARTLO+$12
L2_BWCRN equ CARTLO+$15
L2_BWCONV equ CARTLO+$18
L2_BWGTD equ CARTLO+$1B
L2_BWSTD equ CARTLO+$1E
L2_FDOPEN6 equ CARTLO+$21
L2_FORM equ CARTLO+$24
L2_BLKIO equ CARTLO+$27
L2_RXLOAD equ CARTLO+$2A
L2_RXFIND equ CARTLO+$2D
L2_RXSHOW equ CARTLO+$30
L2_DKLOAD equ CARTLO+$33
L2_DKLINE equ CARTLO+$36
L2_EOSDRV equ CARTLO+$39
L2_ENGET equ CARTLO+$3C
L2_ENNUM equ CARTLO+$3F
L2_ENPUT equ CARTLO+$42
L2_ENGETX equ CARTLO+$45
L2_ENFRONT equ CARTLO+$48
L2_BWGO equ CARTLO+$4B

* ---- page 7 (fixed, SpartaDOS X 4.5) ------------------------------------
jkernel  equ $0703
jblock_io equ $0706
jmisc    equ $0709
jsector_io equ $070C
jhwctrl  equ $070F
sio_vector equ $0718
dev_index equ $0740
dev_vector equ $0750
file_id  equ $0760
device   equ $0761
name     equ $0762
x_name   equ $076D
mode     equ $0778
scan     equ $0779
attr     equ $077A
date     equ $077B
time     equ $077E
dateset  equ $0781
addpos   equ $0782
bytbuf   equ $0785
memreix  equ $0787
dentry   equ $0789
path     equ $07A0
vdos     equ $07E3
jfsymbol equ $07EB
V_setme  equ $07F1
V_popme  equ $07F4

* ---- COMTAB (fixed: DOSVEC points here on SDX 4.5) ----------------------
COMTAB_ADR equ $0A3A
* offsets as on SDX
CT_BUFOFF  equ $0A
CT_FILLEN  equ $1A
CT_800FLG  equ $1B
CT_PBMASK  equ $1C
CT_NBANKS  equ $1D
CT_BANKFLG equ $1E
CT_OSRMFLG equ $1F
CT_COMFNAM equ $21
CT_LBUF    equ $3F

CONSOL  equ $D01F               ; console keys: bit 2 0 = OPTION held
EOL     equ $9B
BSLASH  equ $5C                ; backslash: MADS reads the character literal as an escape
