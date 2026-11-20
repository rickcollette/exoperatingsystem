#!/usr/bin/env python3
"""Make EOS's CAR: man pages.

Reads eos/carfiles/man/NAME.txt (plain text, normal newlines) and writes
eos/carfiles/NAME.MAN: ATASCII text, every line at most 38 characters and
ended with EOL ($9B).

Source text rules:
  - A line longer than 38 characters is wrapped at spaces. Its following
    lines are indented like the line itself, or, when the line starts
    with a short tag followed by two or more spaces (e.g. "/B  backup"),
    lined up with the text after the tag.
  - Blank lines are kept.
  - Only printable ASCII that ATASCII shows the same way is allowed
    (no ` { } ~ and no tabs).

It also writes the other CAR: text files into eos/carfiles:
  - each eos/carfiles/etc/NAME.EXT.txt as NAME.EXT (same text, lines
    ended with EOL, no wrapping): CONFIG.SYS, ALIASES.INI, RUNEXT.CFG;
  - SYSERR.MSG from the error table `errtab` in eos/lib.asm. Line n is
    the message of error 128+n ("NNN Message"); a code without a message
    gets an empty line, which means "System error".

Usage: mkmanpages.py [srcdir [outdir]]
  defaults: eos/carfiles/man and eos/carfiles (relative to the repo).
"""
import os
import re
import sys

WIDTH = 38
EOL = b'\x9b'
BAD = set('`{}~\t')


def wrap(line):
    """Split one source line into screen lines of at most WIDTH chars."""
    line = line.rstrip()
    if len(line) <= WIDTH:
        return [line]
    lead = len(line) - len(line.lstrip(' '))
    m = re.match(r'^(\s*\S+(?:\s\S+)?\s{2,})\S', line)
    hang = len(m.group(1)) if m and len(m.group(1)) <= 16 else lead
    out = []
    cur = line
    while len(cur) > WIDTH:
        cut = cur.rfind(' ', 0, WIDTH + 1)
        while cut > 0 and cur[cut - 1] == ' ':
            cut -= 1
        if cut <= hang or cut <= lead:
            cut = WIDTH                  # one long word: hard break
        out.append(cur[:cut].rstrip())
        rest = cur[cut:].lstrip(' ')
        cur = ' ' * hang + rest
    out.append(cur.rstrip())
    return out


def convert(text, name):
    lines = text.split('\n')
    while lines and lines[-1].strip() == '':
        lines.pop()
    out = []
    for n, line in enumerate(lines, 1):
        for ch in line:
            if ch in BAD or not (32 <= ord(ch) < 127):
                raise SystemExit('%s:%d: character %r not allowed'
                                 % (name, n, ch))
        out.extend(wrap(line))
    for l in out:
        assert len(l) <= WIDTH, (name, l)
    return b''.join(l.encode('ascii') + EOL for l in out)


def check(text, name):
    for n, line in enumerate(text.split('\n'), 1):
        for ch in line:
            if ch in BAD or not (32 <= ord(ch) < 127):
                raise SystemExit('%s:%d: character %r not allowed'
                                 % (name, n, ch))


def etc_files(src, dst):
    """Copy eos/carfiles/etc/NAME.EXT.txt to NAME.EXT with EOL line ends."""
    count = 0
    if not os.path.isdir(src):
        return 0
    for fn in sorted(os.listdir(src)):
        if not fn.endswith('.txt'):
            continue
        with open(os.path.join(src, fn), encoding='ascii') as f:
            text = f.read()
        check(text, fn)
        lines = text.rstrip('\n').split('\n')
        with open(os.path.join(dst, fn[:-4].upper()), 'wb') as f:
            f.write(b''.join(l.rstrip().encode('ascii') + EOL
                             for l in lines))
        count += 1
    return count


def syserr(libasm, dst):
    """SYSERR.MSG from errtab in eos/lib.asm."""
    msgs = {}
    intab = False
    with open(libasm, encoding='latin-1') as f:
        for line in f:
            if line.startswith('errtab'):
                intab = True
            if not intab:
                continue
            m = re.search(r"dta\s+(\d+)\s*,\s*c'([^']*)'", line)
            if m:
                msgs[int(m.group(1))] = m.group(2)
            elif re.search(r'dta\s+0\s*$', line.split(';')[0]):
                break
    if not msgs:
        raise SystemExit('mkmanpages: errtab not found in %s' % libasm)
    out = []
    for code in range(128, max(msgs) + 1):
        out.append('%d %s' % (code, msgs[code]) if code in msgs else '')
    check('\n'.join(out), 'SYSERR.MSG')
    with open(os.path.join(dst, 'SYSERR.MSG'), 'wb') as f:
        f.write(b''.join(l.encode('ascii') + EOL for l in out))
    return len(msgs)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = sys.argv[1] if len(sys.argv) > 1 else \
        os.path.join(root, 'eos', 'carfiles', 'man')
    dst = sys.argv[2] if len(sys.argv) > 2 else \
        os.path.join(root, 'eos', 'carfiles')
    count = 0
    for fn in sorted(os.listdir(src)):
        if not fn.endswith('.txt'):
            continue
        base = fn[:-4].upper()
        if not re.match(r'^[A-Z0-9_]{1,8}$', base):
            raise SystemExit('%s: not a valid 8-character name' % fn)
        with open(os.path.join(src, fn), encoding='ascii') as f:
            data = convert(f.read(), fn)
        with open(os.path.join(dst, base + '.MAN'), 'wb') as f:
            f.write(data)
        count += 1
    print('mkmanpages: %d pages written to %s' % (count, dst))
    if len(sys.argv) <= 1:
        n = etc_files(os.path.join(root, 'eos', 'carfiles', 'etc'), dst)
        e = syserr(os.path.join(root, 'eos', 'lib.asm'), dst)
        print('mkmanpages: %d other files, SYSERR.MSG with %d messages'
              % (n, e))


if __name__ == '__main__':
    main()
