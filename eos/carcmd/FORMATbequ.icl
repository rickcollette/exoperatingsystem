; EOS CAR: FORMAT, the boot loaders' addresses (FORMATboot.icl).
; The loaders run at $3000, but their bytes are part of FORMAT's relocatable
; block. Both variants are assembled here with output disabled to establish
; their absolute LDR/LDRX labels, then again in the relocatable block. The
; absolute operands are already fixed; the loader bytes need no fixups.

        icl 'FORMATbootdefs.icl'

        opt o-
        org $3000
        .local ldr
        icl 'FORMATboot.icl'
        .endl
        org $3000
        .local ldrx
EOSFS_BOOT equ 1
        icl 'FORMATboot.icl'
        .endl
        opt o+
        .print 'boot loader: ',ldr.lend-ldr.booter,' bytes, main ',ldr.main
        .print 'EOSFS boot loader: ',ldrx.lend-ldrx.booter,' bytes, main ',ldrx.main
        ert ldr.lend-ldr.booter>384    ; three sectors
        ert ldrx.lend-ldrx.booter>384  ; three sectors
