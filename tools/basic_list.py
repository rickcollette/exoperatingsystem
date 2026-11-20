#!/usr/bin/env python3
"""List a tokenized Atari BASIC program (SAVEd file).

usage: basic_list.py FILE [first [last]]
"""
import struct
import sys

STMTS = ['REM', 'DATA', 'INPUT', 'COLOR', 'LIST', 'ENTER', 'LET', 'IF', 'FOR', 'NEXT',
         'GOTO', 'GO TO', 'GOSUB', 'TRAP', 'BYE', 'CONT', 'COM', 'CLOSE', 'CLR', 'DEG',
         'DIM', 'END', 'NEW', 'OPEN', 'LOAD', 'SAVE', 'STATUS', 'NOTE', 'POINT', 'XIO',
         'ON', 'POKE', 'PRINT', 'RAD', 'READ', 'RESTORE', 'RETURN', 'RUN', 'STOP', 'POP',
         '?', 'GET', 'PUT', 'GRAPHICS', 'PLOT', 'POSITION', 'DOS', 'DRAWTO', 'SETCOLOR',
         'LOCATE', 'SOUND', 'LPRINT', 'CSAVE', 'CLOAD', '', 'ERROR-']
OPS = {0x12: ',', 0x13: '$', 0x14: ':', 0x15: ';', 0x16: '', 0x17: ' GOTO ', 0x18: ' GOSUB ',
       0x19: ' TO ', 0x1A: ' STEP ', 0x1B: ' THEN ', 0x1C: '#', 0x1D: '<=', 0x1E: '<>',
       0x1F: '>=', 0x20: '<', 0x21: '>', 0x22: '=', 0x23: '^', 0x24: '*', 0x25: '+', 0x26: '-',
       0x27: '/', 0x28: ' NOT ', 0x29: ' OR ', 0x2A: ' AND ', 0x2B: '(', 0x2C: ')', 0x2D: '=',
       0x2E: '=', 0x2F: '<=', 0x30: '<>', 0x31: '>=', 0x32: '<', 0x33: '>', 0x34: '=',
       0x35: '+', 0x36: '-', 0x37: '(', 0x38: '(', 0x39: '(', 0x3A: '(', 0x3B: '(', 0x3C: ',',
       0x3D: 'STR$', 0x3E: 'CHR$', 0x3F: 'USR', 0x40: 'ASC', 0x41: 'VAL', 0x42: 'LEN',
       0x43: 'ADR', 0x44: 'ATN', 0x45: 'COS', 0x46: 'PEEK', 0x47: 'SIN', 0x48: 'RND',
       0x49: 'FRE', 0x4A: 'EXP', 0x4B: 'LOG', 0x4C: 'CLOG', 0x4D: 'SQR', 0x4E: 'SGN',
       0x4F: 'ABS', 0x50: 'INT', 0x51: 'PADDLE', 0x52: 'STICK', 0x53: 'PTRIG', 0x54: 'STRIG'}


def bcd(b):
    """Atari BCD floating point (6 bytes)."""
    if b[0] == 0:
        return '0'
    exp = (b[0] & 0x7F) - 64
    digits = ''.join('%02X' % x for x in b[1:])
    val = int(digits) * 100 ** (exp - 4)
    if b[0] & 0x80:
        val = -val
    s = ('%.10f' % val).rstrip('0').rstrip('.')
    return s


def listing(data, first=0, last=32767):
    lomem, vntp, vntd, vvtp, stmtab, stmcur, starp = struct.unpack('<7H', data[:14])
    base = 14 - vntp     # file offset = address + base
    names = []
    p = vntp + base
    while p < vntd + base:
        n = ''
        while True:
            c = data[p]
            p += 1
            n += chr(c & 0x7F)
            if c & 0x80:
                break
        names.append(n)
    p = stmtab + base
    end = stmcur + base
    out = []
    while p < end:
        line, llen = struct.unpack('<HB', data[p:p + 3])
        if line >= 32768:
            break
        text = []
        q = p + 3
        while q < p + llen:
            slen = data[q]
            tok = data[q + 1]
            r = q + 2
            name = STMTS[tok] if tok < len(STMTS) else 'STMT%d' % tok
            if tok in (0, 1):            # REM, DATA: text to the end
                s = data[r:p + llen].split(b'\x9b')[0].decode('latin-1')
                text.append(name + ' ' + s)
                q = p + llen
                continue
            if tok == 55:                # implied LET
                name = ''
            st = [name + ' ' if name else '']
            while r < p + slen:
                t = data[r]
                r += 1
                if t == 0x0E:
                    st.append(bcd(data[r:r + 6]))
                    r += 6
                elif t == 0x0F:
                    n = data[r]
                    st.append('"' + data[r + 1:r + 1 + n].decode('latin-1') + '"')
                    r += 1 + n
                elif t >= 0x80:
                    st.append(names[t - 0x80] if t - 0x80 < len(names) else 'V%d' % t)
                elif t in OPS:
                    st.append(OPS[t])
                else:
                    st.append('{%02X}' % t)
            text.append(''.join(st).rstrip())
            q = p + slen
        if first <= line <= last:
            out.append('%d %s' % (line, ':'.join(text)))
        p += llen
    return out


def main():
    data = open(sys.argv[1], 'rb').read()
    first = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    last = int(sys.argv[3]) if len(sys.argv) > 3 else (first if len(sys.argv) > 2 else 32767)
    print('\n'.join(listing(data, first, last)))


if __name__ == '__main__':
    main()
