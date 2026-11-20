# XEP80.SYS

CAR:XEP80.SYS is Altirra's replacement XEP80 handler for SpartaDOS X, by
Avery Lee, from the Altirra source tree (`src/Kernel/source/Additions`:
`xep80-sdx.s`, `xep80handler.s`, `xep80config.inc`; `src/Kernel/source/Shared`:
`cio.inc`, `sio.inc`, `kerneldb.inc`, `hardware.inc`). The files are copied
unchanged with their copyright notices. Each carries this permission:

> Copying and distribution of this file, with or without modification,
> are permitted in any medium without royalty provided the copyright
> notice and this notice are preserved. This file is offered as-is,
> without any warranty.

The Makefile assembles `xep80-sdx.s` four times (at $2800, $2801 and $A800,
and at $2800 with HIBUILD=1) and `tools/sdxreloc4.py` turns the four into an
SDX relocatable program, as Altirra's own build does with its tools. Test:
`tools/eos_test.py xep80` (Altirra's XEP80 on joystick port 2).
