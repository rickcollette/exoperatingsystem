#!/usr/bin/env python3
"""Boot the real SDX 4.5 cartridge headless and dump its runtime memory.

D1 holds AUTOEXEC.BAT, which runs SDXPROBE.COM (tools/probe). The probe copies
the RAM under the OS ROM to $4000-$7FFF and spins. An Altirra breakpoint on
the spin loop writes the 64K CPU view to build/sdxprobe/mem.bin. The script
then rebuilds a flat RAM image (ram.bin: $0000-$BFFF main RAM as seen with the
cartridge, $C000-$FFFF from under the ROM) and prints the system layout:
memlo, DOSVEC, COMTAB and the symbol list.

usage: sdxprobe.py [extra AUTOEXEC lines before the probe ...]
"""
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402

OUT = emu.BUILD / 'sdxprobe'
PROBE = Path(__file__).resolve().parent / 'probe' / 'SDXPROBE.COM'
DONE = 0x803B                       # 'done' in probe/sdxprobe.asm


def run(pre=(), files=(), memsize='64K'):
    """files: host paths copied to D1 (run them from pre)."""
    emu.ensure_display()
    OUT.mkdir(parents=True, exist_ok=True)
    tree = OUT / 'tree'
    tree.mkdir(exist_ok=True)
    (tree / 'AUTOEXEC.BAT').write_bytes(emu.atascii(list(pre) + ['SDXPROBE']))
    (tree / 'SDXPROBE.COM').write_bytes(PROBE.read_bytes())
    for f in files:
        (tree / Path(f).name).write_bytes(Path(f).read_bytes())
    atr = OUT / 'probe.atr'
    emu.mkatr(atr, tree, ['AUTOEXEC.BAT', 'SDXPROBE.COM'] + [Path(f).name for f in files], 92160)
    mem = OUT / 'mem.bin'
    mem.unlink(missing_ok=True)
    cmds = ['bp $%04X ".writemem %s 0 L10000"' % (DONE, emu.win(mem))]
    with emu.Session(OUT, [atr], cart=emu.SDX_CART, name='probe', turbo=True,
                     debugcmds=cmds, memsize=memsize):
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline and not (mem.exists() and mem.stat().st_size == 0x10000):
            time.sleep(1)
        time.sleep(1)
        emu.screenshot(OUT / 'probe.png')
    if not mem.exists():
        sys.exit('sdxprobe: no memory dump (see %s)' % OUT)
    cpu = mem.read_bytes()
    ram = bytearray(cpu[:0xC000]) + bytearray(0x4000)
    for page in list(range(0xC0, 0xD0)) + list(range(0xD8, 0x100)):
        src = (page - 0x80) << 8
        ram[page << 8:(page + 1) << 8] = cpu[src:src + 256]
    (OUT / 'ram.bin').write_bytes(ram)
    return cpu, ram


def word(m, a):
    return m[a] | m[a + 1] << 8


def symbols(cpu):
    """Addresses SYMDUMP.COM (probe/symdump.asm) left at $9000."""
    names = (emu.BUILD / 'survey' / 'names.txt').read_text().split()
    return {n: word(cpu, 0x9000 + 2 * k) for k, n in enumerate(names)}


def report(cpu, ram):
    print('MEMLO  $%04X  MEMTOP $%04X  DOSVEC $%04X  DOSINI $%04X' % (
        word(cpu, 0x2E7), word(cpu, 0x2E5), word(cpu, 0x0A), word(cpu, 0x0C)))
    # symbol records: 2 link, 8 name, 1 level, 2-3 address
    seen = {}
    for a in range(0x0700, 0x10000 - 13):
        name = ram[a + 2:a + 10]
        if name[:6] == b'PRINTF' and name[6:] == b'  ':
            seen[a] = name
    for a in seen:
        print('PRINTF record at $%04X: level $%02X target $%04X link $%04X' % (
            a, ram[a + 10], word(ram, a + 11), word(ram, a)))


if __name__ == '__main__':
    if sys.argv[1:2] == ['symbols']:
        mem = sys.argv[2] if len(sys.argv) > 2 else '64K'
        cpu, ram = run(['SYMDUMPW'], [PROBE.parent / 'SYMDUMPW.COM'], mem)
        report(cpu, ram)
        out = OUT / ('symbols.txt' if mem == '64K' else 'symbols-%s.txt' % mem)
        out.write_text(''.join('%-8s $%04X\n' % kv for kv in sorted(symbols(cpu).items(), key=lambda kv: kv[1])))
        print('symbols:', out)
    else:
        report(*run(sys.argv[1:]))
