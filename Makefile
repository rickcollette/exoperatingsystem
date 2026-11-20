# EOS (Extendable Operating System): a SpartaDOS X 4.5 drop-in for an
# AtariMax cartridge, built with MADS
#
#   make            AtariMax, U1MB and SIC! images, test programs, Toolkit ATR
#   make u1mb       the raw 320 KiB U1MB SDX-slot image
#   make sic        SIC! (512 KiB) and SIC!+ (1024 KiB) cartridge images
#   make carttest   boot EOS.car and both SIC! images in Altirra
#   make maint      build/EOSMAINT.atr, the maintenance disk (mainttest: run it)
#   make eosfsboot  build/EOSFSBOOT.bin, the native EOSFS disk boot loader
#                   (eosfsboottest: host-side loader tests)
#   make handbook   docs/EOS_HANDBOOK.md, all documents in one (handbook-pdf: PDF)
#   make u1mbtest   image layout and U1MB bank-select checks
#   make u1mbemu    boot EOS_U1MB.rom from the SDX slot of Altirra's U1MB
#   make ideplusemu IDE2.0PLUS startup and warm-reset checks in Altirra
#   make ideplustest IDE2.0PLUS BIOS flash/export, partition I/O and APT
#   make helpemu    MAN page checks for U1MB, IDEPLUS and APT
#   make atari800test Atari800 (XL, 130XE, PAL, Rambo): batch, files, programs,
#                   CAR:, warm reset
#   make tkx        unpack the SDX Toolkit (media/toolkit.atr, local test media)
#                   for the tests (build/tk, build/tkx)
#   make quick      a few minutes of emulator tests
#   make eostest    EOS's tests (SDX 4.50 as the oracle: SDX_CART)
#   make eostest-eosfs cartest fmttest eosall mutineer: the other suites
#   make xbtest     exBASIC programs (tests/exbasic) against SDX
#   make toolkit    EOS's own Toolkit (toolkit/): build/etk/*.COM and the
#                   disk build/EOSTK.atr
#   make tktest     each of them against the SDX Toolkit's (make tkx first)
#   make release    clean build, DISTRIBUTE/, tag and GitHub release (v0.1;
#                   RELEASE_VERSION=0.2 for another version)
#
# The emulator tests need wine, xvfb, xdotool, ImageMagick's import, Altirra
# (ALTIRRA_EXE) and the SDX 4.50 cartridge (SDX_CART): see tools/emu.py.

MADS    ?= mads
PYTHON  ?= python3
MFLAGS  := -s
B       := build

.PHONY: all eos eosfsboot eosfsboottest u1mb sic flash sidetest carttest maint mainttest handbook handbook-pdf u1mbtest u1mbemu ideplusemu ideplustest helpemu apttest atari800test tkx toolkit tktest eostest xbtest eostest-eosfs cartest fmttest mutineer quick eosall release release-dist clean
.SECONDARY:
all: eos u1mb sic flash toolkit maint

# ---- EOS -----------------------------------------------------
# the RAM kernel is assembled first; its labels become an include for the
# cartridge banks (bank order: equ.icl BK_*)
XD      := eos
XB      := $(B)/eos
UB      := $(B)/u1mb
XBANKS  := boot lib fms cp dev ld lib2 dos2 car
# the CAR: device's commands (eos/carcmd), packed into the banks after the code
CARCMDS := DIR DIRS APPEND BLOAD CAR CHKDSK CHTD CHVOL COMMAND COMP CON COPY \
           DATE DELTREE DEV DF DUMP ED FIND FMT FORMAT KEY LESS MAN MAP MDUMP MEM \
           PEEK POKE PWD RS232 SAVE SETPATHS SIOSET SORTDIR TD TIME UNERASE X ARC MENU APT
# CAR:'s other files: EOS's man pages (eos/carfiles/man, tools/mkmanpages.py)
# and its data files
CARDATA := $(sort $(wildcard $(XD)/carfiles/*.MAN)) $(XD)/carfiles/SYSERR.MSG \
           $(XD)/carfiles/CONFIG.SYS $(XD)/carfiles/ALIASES.INI $(XD)/carfiles/RUNEXT.CFG
CARSYS  := SPARTA SIO ATARIDOS INDUS RTIME8 JIFFY RAMDISK Z COMEXE RUNEXT QUICKED ENV DOSKEY
# CAR:'s overlays (eos/carovl): SORTDIR.OVL
CAROVL  := SORTDIR
CARFS   := $(XB)/carfs.bin
XCAR    := $(B)/EOS.car
U1MBROM := $(B)/EOS_U1MB.rom
EOSFSBOOT := $(XB)/EOSFSBOOT.bin

eos: $(XCAR) $(EOSFSBOOT) $(XB)/PRINTF.COM $(XB)/HELLO.COM $(XB)/CIOD.COM $(XB)/FSW.COM $(XB)/IOP.COM $(XB)/FULL.COM $(XB)/CONIO.COM $(XB)/ENV.COM $(XB)/DIRTEST.COM $(XB)/PARSE.COM $(XB)/FAILN.COM $(XB)/MEMT.COM $(XB)/NEST.COM $(XB)/CHILD.COM $(XB)/RENT.COM $(XB)/GFLG.COM $(XB)/CRUNCH.COM $(XB)/DIVT.COM $(XB)/FDT.COM $(XB)/UPARM.COM $(XB)/SLEEPT.COM $(XB)/MEM2.COM $(XB)/PTH.COM $(XB)/SBT.COM $(XB)/DIRW.COM $(XB)/CPY.COM $(XB)/D2W.COM $(XB)/D2X.COM $(XB)/D2E.COM $(XB)/RIN.COM $(XB)/LB.COM $(XB)/CT.COM $(XB)/CIOB.COM $(XB)/CIOB2.COM $(XB)/SVT.COM $(XB)/RDT.COM $(XB)/UEX.COM $(XB)/BIO.COM $(XB)/MXT.COM $(XB)/HX.COM $(XB)/TCK.COM $(XB)/BLD.COM $(XB)/SKT.COM $(XB)/VAL.COM $(XB)/GETP.COM $(XB)/IDET.COM

eosfsboot: $(EOSFSBOOT)

eosfsboottest: $(EOSFSBOOT)
	$(PYTHON) -m unittest tests.test_eosfs_boot

$(EOSFSBOOT): $(XD)/carcmd/EOSFSBOOT.asm $(XD)/carcmd/FORMATboot.icl $(XD)/carcmd/FORMATbootdefs.icl
	@mkdir -p $(XB)
	cd $(XD)/carcmd && $(MADS) EOSFSBOOT.asm $(MFLAGS) -o:$(abspath $@)

u1mb: $(U1MBROM)

u1mbtest: $(U1MBROM) $(XB)/kernel.bin
	$(PYTHON) -m unittest tests.test_mku1mb

# EOS_U1MB.rom in the SDX slot of Altirra's U1MB flash (with a boot stub,
# tests/u1mb/boot.asm, and AltirraOS from ALTIRRA_SRC), booted and reset;
# the Toolkit's U1MBFLSH writing it (two flash chips, and from EOS.car with
# SDX off: the first installation), refusing, protected
u1mbemu: $(U1MBROM) $(B)/etk/U1MBFLSH.COM $(B)/etk/U1MBCHK.COM
	$(PYTHON) tools/u1mb_test.py

ideplusemu: $(XCAR)
	$(PYTHON) tools/prun.py eos boot-ideplus boot-ideplus-reset

apttest:
	$(PYTHON) -m unittest tests.test_apt

helpemu: $(XCAR)
	$(PYTHON) tools/prun.py eos man-u1mb man-ideplus man-apt

# IDE2.0PLUS in Altirra: EOS runs the BIOS 2.1 updater (media/IDE2.0PLUS/BIOS21.COM)
# on an erased device, the flash is saved and booted, a partition is used
# through it and APT edits the table (build/ideplus; disposable images)
ideplustest: $(XCAR) $(XB)/IDET.COM
	$(PYTHON) tools/ideplus_test.py

atari800test: $(XCAR) $(XB)/HELLO.COM
	$(PYTHON) tools/atari800_smoke.py

# test programs (relocatable SDX binaries) for tools/eos_test.py
$(XB)/%.COM: tests/eos/%.asm
	@mkdir -p $(XB)
	cd tests/eos && $(MADS) $(notdir $<) $(MFLAGS) -o:$(abspath $@)

$(XB)/kernel.bin: $(XD)/kernel.asm $(wildcard $(XD)/*.icl) tools/mads2icl.py
	@mkdir -p $(XB)
	cd $(XD) && $(MADS) kernel.asm $(MFLAGS) -o:$(abspath $@) -t:$(abspath $(XB))/kernel.lab
	$(PYTHON) tools/mads2icl.py $(XB)/kernel.lab $(XB)/kernel.icl $(XD)/equ.icl

$(XB)/%.bin: $(XD)/%.asm $(XD)/equ.icl $(XD)/tail.icl $(XB)/kernel.bin $(wildcard $(XD)/*.icl)
	cd $(XD) && $(MADS) $*.asm $(MFLAGS) -i:$(abspath $(XB)) -o:$(abspath $@) -t:$(abspath $(XB))/$*.lab

# the loader's symbol table needs the addresses of the other modules
$(XB)/symtab.icl: $(XD)/symbols.txt tools/mksymtab.py $(XB)/kernel.bin $(XB)/lib.bin
	$(PYTHON) tools/mksymtab.py $< $(XB) $@
$(XB)/ld.bin: $(XB)/symtab.icl

CARALL  = $(patsubst %,$(XB)/car/%.COM,$(CARCMDS)) $(patsubst %,$(XB)/car/%.SYS,$(CARSYS)) \
          $(XB)/car/XEP80.SYS $(patsubst %,$(XB)/car/%.OVL,$(CAROVL)) $(CARDATA)
$(CARFS): $(XB)/boot.bin $(CARALL) tools/mkcarfs.py
	$(PYTHON) tools/mkcarfs.py $@ $(XB)/boot.bin 9 $(CARALL)

$(XB)/car/%.SYS: $(XD)/carsys/%.asm
	@mkdir -p $(XB)/car
	cd $(XD)/carsys && $(MADS) $(notdir $<) $(MFLAGS) -o:$(abspath $@)

# XEP80.SYS: Altirra's XEP80 handler for SDX (eos/xep80, Avery Lee's files
# with their notices), assembled at $2800, $2801, $A800 and with HIBUILD,
# made relocatable by tools/sdxreloc4.py
XEPSRC  := $(XD)/xep80/xep80-sdx.s
$(XB)/car/XEP80.SYS: $(wildcard $(XD)/xep80/*) tools/sdxreloc4.py
	@mkdir -p $(XB)/car $(XB)/xep80
	$(MADS) -D:BASEADDR=10240 -D:HIBUILD=0 -s -p -i:$(XD)/xep80 -o:$(XB)/xep80/x1.obx $(XEPSRC)
	$(MADS) -D:BASEADDR=10241 -D:HIBUILD=0 -s -p -i:$(XD)/xep80 -o:$(XB)/xep80/x2.obx $(XEPSRC)
	$(MADS) -D:BASEADDR=43008 -D:HIBUILD=0 -s -p -i:$(XD)/xep80 -o:$(XB)/xep80/x3.obx $(XEPSRC)
	$(MADS) -D:BASEADDR=10240 -D:HIBUILD=1 -s -p -i:$(XD)/xep80 -o:$(XB)/xep80/x4.obx $(XEPSRC)
	$(PYTHON) tools/sdxreloc4.py $(patsubst %,$(XB)/xep80/x%.obx,1 2 3 4) $@

# an overlay: its part under the cartridge first (%p.asm), included
$(XB)/car/%.OVL: $(XD)/carovl/%.asm $(XD)/carovl/%p.asm
	@mkdir -p $(XB)/car
	cd $(XD)/carovl && $(MADS) $*p.asm $(MFLAGS) -o:$(abspath $(XB))/car/$*p.bin
	cd $(XD)/carovl && $(MADS) $*.asm $(MFLAGS) -o:$(abspath $@)

$(XB)/car/%.COM: $(XD)/carcmd/%.asm $(wildcard $(XD)/carcmd/*.icl)
	@mkdir -p $(XB)/car
	cd $(XD)/carcmd && $(MADS) $(notdir $<) $(MFLAGS) -o:$(abspath $@)

$(XCAR): $(patsubst %,$(XB)/%.bin,$(XBANKS)) $(CARFS) tools/mkcarx.py
	$(PYTHON) tools/mkcarx.py $@ $(patsubst %,$(XB)/%.bin,$(XBANKS)) $(CARFS)

# U1MB uses a different bank select register from AtariMax. Assemble the same
# EOS source with its fixed-address SDX latch, then package 40 raw 8K banks.
$(UB)/kernel.bin: $(XD)/kernel.asm $(wildcard $(XD)/*.icl) tools/mads2icl.py
	@mkdir -p $(UB)
	cd $(XD) && $(MADS) kernel.asm $(MFLAGS) -D:U1MB=1 -o:$(abspath $(UB))/kernel.bin -t:$(abspath $(UB))/kernel.lab
	$(PYTHON) tools/mads2icl.py $(UB)/kernel.lab $(UB)/kernel.icl $(XD)/equ.icl

$(UB)/%.bin: $(XD)/%.asm $(XD)/equ.icl $(XD)/tail.icl $(UB)/kernel.bin $(wildcard $(XD)/*.icl)
	cd $(XD) && $(MADS) $*.asm $(MFLAGS) -D:U1MB=1 -i:$(abspath $(UB)) -o:$(abspath $@) -t:$(abspath $(UB))/$*.lab

$(UB)/symtab.icl: $(XD)/symbols.txt tools/mksymtab.py $(UB)/kernel.bin $(UB)/lib.bin
	$(PYTHON) tools/mksymtab.py $< $(UB) $@
$(UB)/ld.bin: $(UB)/symtab.icl

$(UB)/carfs.bin: $(UB)/boot.bin $(CARALL) tools/mkcarfs.py
	$(PYTHON) tools/mkcarfs.py $@ $(UB)/boot.bin 9 $(CARALL)

$(U1MBROM): $(patsubst %,$(UB)/%.bin,$(XBANKS)) $(UB)/carfs.bin tools/mku1mb.py
	$(PYTHON) tools/mku1mb.py $@ $(patsubst %,$(UB)/%.bin,$(XBANKS)) $(UB)/carfs.bin

# SIC! (512 KiB) and SIC!+ (1024 KiB): the same EOS source with the bank
# number written to $D500 (-D:SIC=1), each 8K bank in the upper half of a
# 16K SIC! bank (tools/mksic.py)
SB      := $(B)/sic
SICCAR  := $(B)/EOS_SIC.car
SICPCAR := $(B)/EOS_SICP.car
sic: $(SICCAR) $(SICPCAR)

$(SB)/kernel.bin: $(XD)/kernel.asm $(wildcard $(XD)/*.icl) tools/mads2icl.py
	@mkdir -p $(SB)
	cd $(XD) && $(MADS) kernel.asm $(MFLAGS) -D:SIC=1 -o:$(abspath $(SB))/kernel.bin -t:$(abspath $(SB))/kernel.lab
	$(PYTHON) tools/mads2icl.py $(SB)/kernel.lab $(SB)/kernel.icl $(XD)/equ.icl

$(SB)/%.bin: $(XD)/%.asm $(XD)/equ.icl $(XD)/tail.icl $(SB)/kernel.bin $(wildcard $(XD)/*.icl)
	cd $(XD) && $(MADS) $*.asm $(MFLAGS) -D:SIC=1 -i:$(abspath $(SB)) -o:$(abspath $@) -t:$(abspath $(SB))/$*.lab

$(SB)/symtab.icl: $(XD)/symbols.txt tools/mksymtab.py $(SB)/kernel.bin $(SB)/lib.bin
	$(PYTHON) tools/mksymtab.py $< $(SB) $@
$(SB)/ld.bin: $(SB)/symtab.icl

$(SB)/carfs.bin: $(SB)/boot.bin $(CARALL) tools/mkcarfs.py
	$(PYTHON) tools/mkcarfs.py $@ $(SB)/boot.bin 9 $(CARALL)

$(SICCAR): $(patsubst %,$(SB)/%.bin,$(XBANKS)) $(SB)/carfs.bin tools/mksic.py
	$(PYTHON) tools/mksic.py $@ 512 $(patsubst %,$(SB)/%.bin,$(XBANKS)) $(SB)/carfs.bin
$(SICPCAR): $(patsubst %,$(SB)/%.bin,$(XBANKS)) $(SB)/carfs.bin tools/mksic.py
	$(PYTHON) tools/mksic.py $@ 1024 $(patsubst %,$(SB)/%.bin,$(XBANKS)) $(SB)/carfs.bin

# SIDE, SIDE2, MyIDE II, SIDE3: the same EOS source with each cartridge's
# bank register (eos/equ.icl), packed into a raw flash image at the offset
# the cartridge starts from (tools/mkflash.py): build/EOS_<NAME>.rom
FLASHES := side side2 myide2 side3
FLASH_side   := -D:SIDE=1
FLASH_side2  := -D:SIDE=2
FLASH_myide2 := -D:MYIDE2=1
FLASH_side3  := -D:SIDE3=1
ROM_side     := EOS_SIDE.rom
ROM_side2    := EOS_SIDE2.rom
ROM_myide2   := EOS_MYIDE2.rom
ROM_side3    := EOS_SIDE3.rom
define flash_rules
$(B)/$(1)/kernel.bin: $(XD)/kernel.asm $(wildcard $(XD)/*.icl) tools/mads2icl.py
	@mkdir -p $(B)/$(1)
	cd $(XD) && $(MADS) kernel.asm $(MFLAGS) $(FLASH_$(1)) -o:$(abspath $(B))/$(1)/kernel.bin -t:$(abspath $(B))/$(1)/kernel.lab
	$(PYTHON) tools/mads2icl.py $(B)/$(1)/kernel.lab $(B)/$(1)/kernel.icl $(XD)/equ.icl
$(B)/$(1)/%.bin: $(XD)/%.asm $(XD)/equ.icl $(XD)/tail.icl $(B)/$(1)/kernel.bin $(wildcard $(XD)/*.icl)
	cd $(XD) && $(MADS) $$*.asm $(MFLAGS) $(FLASH_$(1)) -i:$(abspath $(B))/$(1) -o:$$(abspath $$@) -t:$(abspath $(B))/$(1)/$$*.lab
$(B)/$(1)/symtab.icl: $(XD)/symbols.txt tools/mksymtab.py $(B)/$(1)/kernel.bin $(B)/$(1)/lib.bin
	$(PYTHON) tools/mksymtab.py $$< $(B)/$(1) $$@
$(B)/$(1)/ld.bin: $(B)/$(1)/symtab.icl
$(B)/$(1)/carfs.bin: $(B)/$(1)/boot.bin $(CARALL) tools/mkcarfs.py
	$(PYTHON) tools/mkcarfs.py $$@ $(B)/$(1)/boot.bin 9 $(CARALL)
$(B)/$(ROM_$(1)): $(patsubst %,$(B)/$(1)/%.bin,$(XBANKS)) $(B)/$(1)/carfs.bin tools/mkflash.py
	$(PYTHON) tools/mkflash.py $$@ $(1) $(patsubst %,$(B)/$(1)/%.bin,$(XBANKS)) $(B)/$(1)/carfs.bin
endef
$(foreach f,$(FLASHES),$(eval $(call flash_rules,$(f))))
FLASHROMS := $(foreach f,$(FLASHES),$(B)/$(ROM_$(f)))
flash: $(FLASHROMS)

# the EOS maintenance disk: the U1MB image, U1MBFLSH, U1MBCHK, APT, FORMAT
# and tools, EOS's startup files without a RAM disk (tools/mkmaint.py)
MAINT   := $(B)/EOSMAINT.atr
maint: $(MAINT)
$(MAINT): $(U1MBROM) $(XCAR) $(ETK) tools/mkmaint.py
	$(PYTHON) tools/mkmaint.py $@
mainttest: $(MAINT)
	$(PYTHON) tools/maint_test.py

# docs/EOS_HANDBOOK.md: the documents merged into one book (tools/mkhandbook.py);
# handbook-pdf also makes build/EOS_HANDBOOK.pdf (pandoc, pdflatex)
handbook:
	$(PYTHON) tools/mkhandbook.py
handbook-pdf: handbook
	@mkdir -p $(B)
	cd docs && pandoc EOS_HANDBOOK.md -o ../$(B)/EOS_HANDBOOK.pdf --pdf-engine=pdflatex --resource-path=.

# EOS.car (Maxflash 8 Mbit), EOS_SIC.car and EOS_SICP.car in Altirra: boot,
# batch, CAR:, warm reset
carttest: $(XCAR) $(SICCAR) $(SICPCAR)
	$(PYTHON) tools/carts_test.py

# SIDE, SIDE2, MyIDE II, SIDE3: EOS from each flash; their CF/SD cards'
# APT partitions through EOS's own driver (eos/ide.icl, eos/sd.icl)
sidetest: $(FLASHROMS) $(XB)/MST.COM
	$(PYTHON) tools/side_test.py

# the CAR: commands against SDX's outputs (tests/carref, made by tools/carref.py)
# the emulator suites run JOBS tests side by side (tools/prun.py: a Wine
# prefix and an X server per worker); SDX's results are cached in
# build/sdx-cache (EOS_FRESH=1 runs SDX again)
JOBS    ?= 3

cartest: $(XCAR)
	$(PYTHON) tools/prun.py -j $(JOBS) car

# the same tests with EOS on EOSFS disks (SDX on SDFS as the oracle)
eostest-eosfs: $(XCAR)
	EOS_EOSFS=1 $(PYTHON) tools/prun.py -j $(JOBS) eos

fmttest: $(XCAR)
	$(PYTHON) tools/prun.py -j $(JOBS) fmt

# the Mutineer BBS on SDX and EOS, every matrix cell (docs/history/MUTINEER_PROMPT.md;
# about 12 minutes a cell): build/mutineer-results/matrix.md
mutineer: $(XCAR)
	$(PYTHON) tools/prun.py -j $(JOBS) mutineer

# a smoke set for between steps (a few minutes); the full suites before a commit
quick: $(XCAR)
	$(PYTHON) tools/prun.py -j $(JOBS) eos boot-64K boot-320K reset type ciod ciob fsw fsw-512 dirs cfg ramdisk-320K use-banked-128K c4-files dos2-dd
	$(PYTHON) tools/prun.py -j $(JOBS) car dev:format-ram dev:ramdisk-three disk:chkdsk-1 files:copy-1

# T1: EOS inside itself, every CAR: command and driver in each
# configuration (64K/320K, SIO patch on/off, SD/ED/DD/QD): tools/eosall.py
eosall: $(XCAR)
	$(PYTHON) tools/eosall.py

eostest: $(XCAR)
	$(PYTHON) tools/prun.py -j $(JOBS) eos

# exBASIC programs (tests/exbasic) on EOS against SDX: the eostest cases
# named xb-*; EXBASIC is the exBASIC compiler (default ~/ExBASIC/exbasic)
xbtest: $(XCAR)
	$(PYTHON) tools/prun.py -j $(JOBS) eos 'xb-*'

# EOS's Toolkit: its own utilities (toolkit/NAME.asm), relocatable SDX
# programs like the CAR: commands
ETK     := $(patsubst toolkit/%.asm,$(B)/etk/%.COM,$(wildcard toolkit/[A-Z]*.asm))
toolkit: $(B)/EOSTK.atr
$(B)/EOSTK.atr: $(ETK) $(wildcard toolkit/man/*.txt) tools/mketk.py
	$(PYTHON) tools/mketk.py $@
$(B)/etk/%.COM: toolkit/%.asm $(wildcard toolkit/*.icl)
	@mkdir -p $(B)/etk
	cd toolkit && $(MADS) $(notdir $<) $(MFLAGS) -o:$(abspath $@)
tktest: $(XCAR) $(ETK)
	$(PYTHON) tools/prun.py -j $(JOBS) tk

tkx:
	$(PYTHON) tools/tkunpack.py media/toolkit.atr $(B)

RELEASE_VERSION ?= 0.1
RELEASE_FILES := EOS.car EOS_U1MB.rom EOS_SIC.car EOS_SICP.car EOS_SIDE.rom \
                 EOS_SIDE2.rom EOS_SIDE3.rom EOS_MYIDE2.rom EOSTK.atr \
                 EOSMAINT.atr EOS_HANDBOOK.pdf EOSFSBOOT.bin
RELEASE_ASSETS := $(addprefix DISTRIBUTE/,$(RELEASE_FILES)) DISTRIBUTE/SHA256SUMS.txt

release:
	$(PYTHON) tools/release.py check $(RELEASE_VERSION)
	$(MAKE) clean
	$(MAKE) all handbook-pdf
	$(MAKE) release-dist
	$(PYTHON) tools/release.py publish $(RELEASE_VERSION) $(RELEASE_ASSETS)

release-dist:
	rm -rf DISTRIBUTE
	mkdir -p DISTRIBUTE
	cp $(addprefix $(B)/,$(filter-out EOSFSBOOT.bin,$(RELEASE_FILES))) DISTRIBUTE/
	cp $(EOSFSBOOT) DISTRIBUTE/EOSFSBOOT.bin
	cd DISTRIBUTE && sha256sum $(RELEASE_FILES) > SHA256SUMS.txt

clean:
	rm -rf $(B)
