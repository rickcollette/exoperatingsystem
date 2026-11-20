#!/usr/bin/env python3
"""An SDX relocatable program from four assemblies of a source that relocates
its own byte operands (Altirra's XEP80 handler, eos/xep80): at $2800, $2801
and $A800, and at $2800 with HIBUILD=1 (each #> operand assembled as its
#< instead). The bytes that differ between them are the relocations:

  word      the low byte follows the base's low byte and the next byte its
            high one: an $FFFD fix-up for the SDX loader
  low byte  only the low byte follows (#<): the program's own table
  high byte only the high byte follows (#>): the program's own table, with
            the low byte (from the HIBUILD assembly) for its carry

The program's tables go after its code; its reference to __RELDAT gets
their address. The output: one relocatable block ($FFFE) assembled for
$0000, its symbol definitions ($FFFC), the word fix-ups ($FFFD) and the
symbol references ($FFFB).

usage: sdxreloc4.py base.obx plus1.obx high.obx hibuild.obx out.sys
"""
import sys

BASE = 0x2800
LOADS = (0x2800, 0x2801, 0xA800, 0x2800)


def parse(data, load):
    """(segments [(start, bytearray)], refs {name: [address]}, defs {name: value})"""
    segs, refs, defs = [], {}, {}
    i = 0
    while i < len(data):
        code = data[i] | data[i + 1] << 8
        i += 2
        if code == 0xFFFA:                     # absolute segment
            start = data[i] | data[i + 1] << 8
            end = data[i + 2] | data[i + 3] << 8
            i += 4
            if not segs and start != load:
                sys.exit('first segment at $%04X, not $%04X' % (start, load))
            segs.append((start, bytearray(data[i:i + end - start + 1])))
            i += end - start + 1
        elif code == 0xFFFB:                   # symbol reference
            name = bytes(data[i:i + 8])
            i += 10                            # (the name, a zero size)
            at = None
            offs = refs.setdefault(name, [])
            while True:
                c = data[i]
                i += 1
                if c == 0xFC:
                    break
                if c == 0xFD:
                    at = data[i] | data[i + 1] << 8
                    i += 2
                    offs.append(at)
                elif c == 0xFF:
                    at += 250
                elif c < 0xFA:
                    at += c
                    offs.append(at)
                else:
                    sys.exit('symbol reference: code $%02X' % c)
        elif code == 0xFFFC:                   # symbol definition
            defs[bytes(data[i:i + 8])] = data[i + 8] | data[i + 9] << 8
            i += 10
        else:
            sys.exit('unexpected block $%04X' % code)
    return segs, refs, defs


def fixups(offsets, rel):
    """The fix-up stream for addresses: in the relocatable block (rel: its
    range) by distance from its start, others by $FD address."""
    out = bytearray()
    last, inrel = None, None
    for off in sorted(offsets):
        isrel = rel[0] <= off < rel[1]
        if isrel:
            if inrel is not True:
                out += b'\xfe\x01'             # (block 1, from its start)
                last = rel[0]
        elif inrel is not False or off - last >= 500:
            out += bytes((0xFD, off & 0xFF, off >> 8))
            last, inrel = off, False
            continue
        inrel = isrel
        while off - last >= 250:
            out.append(0xFF)
            last += 250
        out.append(off - last)
        last = off
    return out + b'\xfc'


def table(entries, width):
    """A relocation table: per page from BASE, a count and the offsets (with
    one more byte each when width is 2); $FF ends it."""
    out = bytearray([0])
    page, count = BASE, 0
    for e in entries:
        off = e[0]
        while page + 0x100 <= off:             # (one count byte per page)
            page += 0x100
            count = len(out)
            out.append(0)
        out[count] += 1
        out.append(off - page)
        if width == 2:
            out.append(e[1])
    if out[count]:
        out.append(0xFF)
    else:
        out[count] = 0xFF
    return out


def main():
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    runs = [parse(open(f, 'rb').read(), load) for f, load in zip(sys.argv[1:5], LOADS)]
    for k, (segs, _, _) in enumerate(runs[1:], 1):
        if [len(d) for _, d in segs] != [len(d) for _, d in runs[0][0]]:
            sys.exit('%s: other segments than the base' % sys.argv[k + 1])
    segs, refs, defs = runs[0]
    base, plus1, high, hib = (r[0][0][1] for r in runs)
    lows, highs, words = [], [], []
    n = len(base)
    for i in range(n):
        nexthigh = i + 1 < n and (base[i + 1] ^ high[i + 1]) & 0x80
        if base[i] == plus1[i]:
            if nexthigh:
                highs.append((BASE + i + 1, hib[i + 1]))
        elif nexthigh:
            words.append(BASE + i)
        elif not (base[i] ^ high[i]) & 0x80:
            lows.append((BASE + i,))
    for w in words:                            # assembled for $0000
        base[w + 1 - BASE] = (base[w + 1 - BASE] - (BASE >> 8)) & 0xFF
    for h, _ in highs:
        base[h - BASE] = (base[h - BASE] - (BASE >> 8)) & 0xFF
    size = n
    defs[b'__RELDAT'] = BASE + size
    tabs = table(lows, 1) + table(highs, 2)
    if len(tabs) > 256:
        sys.exit('relocation tables over 256 bytes')
    base += tabs
    rel = (BASE, BASE + size)
    for name, offs in refs.items():            # the program's own __ symbols
        if not name.startswith(b'__') or name not in defs:
            continue
        val = defs[name]
        inside = rel[0] <= val <= rel[1]
        if inside:
            words.extend(offs)
        for off in offs:
            seg = next((s, d) for s, d in segs if s <= off < s + len(d) - 1)
            v = seg[1][off - seg[0]] | seg[1][off - seg[0] + 1] << 8
            v = (v + (val - BASE if inside else val)) & 0xFFFF
            seg[1][off - seg[0]] = v & 0xFF
            seg[1][off - seg[0] + 1] = v >> 8
    out = bytearray()
    for k, (start, data) in enumerate(segs):
        if k == 0:
            out += bytes((0xFE, 0xFF, 1, 0, 0, 0, len(data) & 0xFF, len(data) >> 8)) + data
        else:
            end = start + len(data) - 1
            out += bytes((0xFA, 0xFF, start & 0xFF, start >> 8, end & 0xFF, end >> 8)) + data
        last = start + len(data) - 1
        for name, val in defs.items():
            if not name.startswith(b'__') and start <= val <= last:
                off = val - start
                out += b'\xfc\xff' + name + bytes((off & 0xFF, off >> 8))
    if words:
        out += b'\xfd\xff\x01\x00\x00' + fixups(words, rel)
    for name, offs in refs.items():
        if name.startswith(b'__') or not offs:
            continue
        out += b'\xfb\xff' + name + b'\x00\x00' + fixups(offs, rel)
    open(sys.argv[5], 'wb').write(out)
    print('%s: %d low, %d word, %d high relocations' % (sys.argv[5], len(lows), len(words), len(highs)))


if __name__ == '__main__':
    main()
