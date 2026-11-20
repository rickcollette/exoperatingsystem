; EOS oracle test: PRINTF formats. Each line is [tag:output].
PRINTF   smb 'PRINTF'

        blk reloc main
start   jsr PRINTF
        dta c'a[%x][%2x][%4x][%6x][%8x]',$9B,0
        dta a(v32,v32,v32,v32,v32)
        jsr PRINTF
        dta c'b[%x][%x][%3x]',$9B,0
        dta a(v8,v0,v8)
        jsr PRINTF
        dta c'c[%d][%2d][%10d][%010d][%d]',$9B,0
        dta a(v16,v16,v16,v16,v0)
        jsr PRINTF
        dta c'd[%b][%5b][%e][%l][%12l]',$9B,0
        dta a(v8,v8,v32,v32,v32)
        jsr PRINTF
        dta c'e[%s][%8s][%3s][%c][%%][%p]',$9B,0
        dta a(str,str,str,str,ptr)
        jsr PRINTF
        dta c'f[%*d][%0*d][%*s]',$9B,0
        dta a(w6,v16,w6,v16,w6,str)
        jsr PRINTF
        dta c'g[%5s][%0t][%1t][%*t][%3t]',$9B,0
        dta a(v0,toks,toks,w1,toks,toks)
        jsr PRINTF
        dta c'h[a\tb][c\\d][\z][\ie\i][\q]',$9B,0
        jsr PRINTF
        dta c'i[%5x][%05x][%-4d][%e][%l]',$9B,0
        dta a(v8,v8,v16,vbig)          ; %-4d takes no argument
        rts

v32     dta $78,$56,$34,$12
v8      dta $2A,0,0,0
v0      dta 0,0,0,0
v16     dta $AB,$98,0,0
vbig    dta $FF,$FF,$FF,$FF
w6      dta 6,0
w1      dta 1,0
str     dta c'HELLO',$9B
ptr     dta a(str)
toks    dta c'ONE',$9B,c'TWO',$9B,c'THREE',$9B,0

        blk update address
        blk update symbols
