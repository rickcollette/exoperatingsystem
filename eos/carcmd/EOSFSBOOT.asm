; Raw EOSFS loader for the host image builder. FORMAT embeds the same source.

        opt h-f+
        icl 'FORMATbootdefs.icl'

        org $3000
        .local ldrx
EOSFS_BOOT equ 1
        icl 'FORMATboot.icl'
        .endl
        :384-(ldrx.lend-ldrx.booter) dta 0
