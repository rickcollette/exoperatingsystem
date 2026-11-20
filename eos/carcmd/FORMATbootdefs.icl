; Loader workspace. Header bytes 42-47 are outside the volume header.
bl_nm    equ $302A             ; next map/list sector
bl_emp   equ $302C             ; data buffer empty
bl_sp    equ $302D             ; entry stack pointer
bl_cnt   equ $302E             ; sectors left in the extent
bl_ptr   equ $43               ; load address
bl_end   equ $45               ; segment end
bl_pos   equ $47               ; data-buffer position
bl_mapi  equ $48               ; map/list position
bl_slen  equ $49               ; $80 = 128 bytes, 0 = 256 bytes

BL_DATA  equ $2E               ; $2E00 data buffer
BL_MAP   equ $2F               ; $2F00 map/list buffer

SIOV_    equ $E459
COLDSV   equ $E477
RUNAD    equ $02E0
INITAD   equ $02E2
CH_      equ $02FC
SAVMSC_  equ $58
DDEVIC_  equ $0300
DBUF_    equ $0304
DBYT_    equ $0308
DAUX_    equ $030A
