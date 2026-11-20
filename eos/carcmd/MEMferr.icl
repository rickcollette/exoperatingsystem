; EOS CAR: an error that ends X or CAR the way SDX's X does it
; (included after the program's code). X looks for the program along
; $PATH; when it is nowhere SDX says only "170 File not found", while
; U_FAIL would name the last name tried ("File NONE.COM"). So the message
; is printed here. The program's start does: tsx / stx fe_sp.
;   fe_end  A = the error: its message (to the screen), ERRNO, the end

fe_end  sta fe_code
        ldy #0                 ; messages go to the screen
        jsr XDIVIO
        lda fe_code
        sta ERRNO
        jsr U_ERROR
        ldx fe_sp
        txs
        rts

fe_code dta 0
fe_sp   dta 0
