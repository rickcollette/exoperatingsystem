#!/usr/bin/env python3
"""Disassemble an SDX binary (Toolkit programs: allowed by the clean-room
rules, see docs/history/EOS_PLAN.md). Relocatable blocks are shown at offset 0 of
their block, words fixed up by the loader are marked with the block or
symbol they are relative to.

usage: dis6502.py file.com
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sdxbin  # noqa: E402

MODES = {
    'imp': 0, 'acc': 0, 'imm': 1, 'zp': 1, 'zpx': 1, 'zpy': 1, 'izx': 1, 'izy': 1, 'rel': 1,
    'abs': 2, 'abx': 2, 'aby': 2, 'ind': 2,
}
OPS = {}


def _ops():
    t = '''
00 brk imp 01 ora izx 05 ora zp 06 asl zp 08 php imp 09 ora imm 0a asl acc 0d ora abs 0e asl abs
10 bpl rel 11 ora izy 15 ora zpx 16 asl zpx 18 clc imp 19 ora aby 1d ora abx 1e asl abx
20 jsr abs 21 and izx 24 bit zp 25 and zp 26 rol zp 28 plp imp 29 and imm 2a rol acc 2c bit abs
2d and abs 2e rol abs 30 bmi rel 31 and izy 35 and zpx 36 rol zpx 38 sec imp 39 and aby 3d and abx
3e rol abx 40 rti imp 41 eor izx 45 eor zp 46 lsr zp 48 pha imp 49 eor imm 4a lsr acc 4c jmp abs
4d eor abs 4e lsr abs 50 bvc rel 51 eor izy 55 eor zpx 56 lsr zpx 58 cli imp 59 eor aby 5d eor abx
5e lsr abx 60 rts imp 61 adc izx 65 adc zp 66 ror zp 68 pla imp 69 adc imm 6a ror acc 6c jmp ind
6d adc abs 6e ror abs 70 bvs rel 71 adc izy 75 adc zpx 76 ror zpx 78 sei imp 79 adc aby 7d adc abx
7e ror abx 81 sta izx 84 sty zp 85 sta zp 86 stx zp 88 dey imp 8a txa imp 8c sty abs 8d sta abs
8e stx abs 90 bcc rel 91 sta izy 94 sty zpx 95 sta zpx 96 stx zpy 98 tya imp 99 sta aby 9a txs imp
9d sta abx a0 ldy imm a1 lda izx a2 ldx imm a4 ldy zp a5 lda zp a6 ldx zp a8 tay imp a9 lda imm
aa tax imp ac ldy abs ad lda abs ae ldx abs b0 bcs rel b1 lda izy b4 ldy zpx b5 lda zpx b6 ldx zpy
b8 clv imp b9 lda aby ba tsx imp bc ldy abx bd lda abx be ldx aby c0 cpy imm c1 cmp izx c4 cpy zp
c5 cmp zp c6 dec zp c8 iny imp c9 cmp imm ca dex imp cc cpy abs cd cmp abs ce dec abs d0 bne rel
d1 cmp izy d5 cmp zpx d6 dec zpx d8 cld imp d9 cmp aby dd cmp abx de dec abx e0 cpx imm e1 sbc izx
e4 cpx zp e5 sbc zp e6 inc zp e8 inx imp e9 sbc imm ea nop imp ec cpx abs ed sbc abs ee inc abs
f0 beq rel f1 sbc izy f5 sbc zpx f6 inc zpx f8 sed imp f9 sbc aby fd sbc abx fe inc abx'''.split()
    for i in range(0, len(t), 3):
        OPS[int(t[i], 16)] = (t[i + 1], t[i + 2])


_ops()


def relocs(d):
    """{block: {offset: label}} of words the loader fixes up."""
    blocks, out = {}, {}
    for kind, f, p in sdxbin.blocks(d):
        if kind == 'reloc':
            blocks[f['num']] = f
        if kind in ('fixup', 'xref'):
            what = 'blk%d' % f['num'] if kind == 'fixup' else f['name']
            tgt, pos, i = f.get('num', 0), 0, 0
            while i < len(p):
                b = p[i]
                i += 1
                if b == 0xFC:
                    break
                if b == 0xFE:
                    tgt, pos = p[i], 0
                    i += 1
                elif b == 0xFD:
                    out.setdefault('abs', {})[p[i] | p[i + 1] << 8] = what
                    i += 2
                elif b == 0xFF:
                    pos += 250
                else:
                    pos += b
                    out.setdefault(tgt, {})[pos] = what
    return blocks, out


def fmt(mode, arg, fix):
    a = ('%s+$%04X' % (fix, arg)) if fix else '$%04X' % arg if mode in ('abs', 'abx', 'aby', 'ind') \
        else '$%02X' % arg
    return {'imp': '', 'acc': 'a', 'imm': '#' + a, 'zp': a, 'zpx': a + ',x', 'zpy': a + ',y',
            'izx': '(%s,x)' % a, 'izy': '(%s),y' % a, 'abs': a, 'abx': a + ',x', 'aby': a + ',y',
            'ind': '(%s)' % a, 'rel': a}[mode]


def dis(code, fixes, base=0):
    i = 0
    while i < len(code):
        op = code[i]
        name, mode = OPS.get(op, ('.byte', 'imp'))
        n = MODES[mode]
        raw = code[i:i + 1 + n]
        if name == '.byte' or len(raw) < 1 + n:
            print('%04X  %02X        .byte $%02X' % (base + i, op, op))
            i += 1
            continue
        arg = raw[1] if n == 1 else (raw[1] | raw[2] << 8) if n == 2 else 0
        if mode == 'rel':
            arg = (base + i + 2 + (arg - 256 if arg & 0x80 else arg)) & 0xFFFF
            mode_s = '$%04X' % arg
        else:
            mode_s = fmt(mode, arg, fixes.get(i + 1))
        print('%04X  %-9s %s %s' % (base + i, raw.hex(' '), name, mode_s))
        i += 1 + n


def main():
    d = open(sys.argv[1], 'rb').read()
    blocks, fixes = relocs(d)
    for kind, f, p in sdxbin.blocks(d):
        if kind == 'reloc' and not f['ctl'] & 0x80:
            print('; block %d, %d bytes, control $%02X' % (f['num'], f['size'], f['ctl']))
            dis(p, fixes.get(f['num'], {}))
        elif kind == 'abs':
            print('; segment $%04X-$%04X' % (f['start'], f['end']))
            dis(p, fixes.get('abs', {}), f['start'])
        elif kind == 'reloc':
            print('; BSS block %d, %d bytes' % (f['num'], f['size']))
        elif kind == 'xdef':
            print('; defines %s = block %d + $%04X' % (f['name'], f['num'], f['off']))


if __name__ == '__main__':
    main()
