#!/usr/bin/env python3
"""Where EOS spends its cycles: a profile of the BASIC benchmark's jobs.

A short Atari BASIC program (the jobs of tests/bench/BENCH.BAS, a few times
each) runs on EOS with Altirra's debugger logging every farcall (the
kernel's fc_jsr: the bank and address called, the CPU cycle counter @cclk,
and again at its return) and each job's start (the program POKEs the job's
number to $D7F2, nothing there on an 800XL). Every bank change in EOS goes through farcall, so the log
gives each banked function's cycles, with and without the farcalls it
makes, per job; what is left is BASIC's, CIO's and the kernel's own.

usage: fprof.py [dos2|mydos|sdfs] [job ...]
"""
import os
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import emu  # noqa: E402
import basbench as BB  # noqa: E402
import eos_test as T  # noqa: E402

OUT = emu.BUILD / 'fprof'
MARK = 0xD7F2
BANKS = {0: 'boot', 1: 'lib', 2: 'fms', 3: 'cp', 4: 'dev', 5: 'ld', 6: 'lib2', 7: 'dos2'}

USR = BB.BENCH.read_text().splitlines()[4:7]     # lines 50-70: the CIO routine
JOBS = [
    ('CREATE', ['FOR I=1 TO 30:F$="D2:F":F$(5)=STR$(I):OPEN #1,8,0,F$:PUT #1,65:CLOSE #1:NEXT I']),
    ('OPEN', ['FOR I=1 TO 20:OPEN #1,4,0,"D2:F30":CLOSE #1:NEXT I']),
    ('DIR', ['OPEN #1,6,0,"D2:*.*":TRAP 205', 'INPUT #1,D$:GOTO 204', 'TRAP 40000:CLOSE #1']),
    ('RENAME', ['FOR I=1 TO 30:F$="D2:F":F$(5)=STR$(I):F$(LEN(F$)+1)=",G":F$(LEN(F$)+1)=STR$(I):XIO 32,#1,0,0,F$:NEXT I']),
    ('DELETE', ['FOR I=1 TO 30:F$="D2:G":F$(5)=STR$(I):XIO 33,#1,0,0,F$:NEXT I']),
    ('PUTBYTE', ['OPEN #1,8,0,"D2:T1.DAT":FOR I=0 TO 499:PUT #1,65:NEXT I:CLOSE #1']),
    ('GETBYTE', ['OPEN #1,4,0,"D2:T1.DAT":FOR I=0 TO 499:GET #1,A:NEXT I:CLOSE #1']),
    ('RECWRITE', ['OPEN #1,8,0,"D2:T3.DAT":FOR I=1 TO 20:PRINT #1;L$:NEXT I:CLOSE #1']),
    ('RECREAD', ['OPEN #1,4,0,"D2:T3.DAT":FOR I=1 TO 20:INPUT #1,L$:NEXT I:CLOSE #1']),
    ('BLKWRITE', ['OPEN #1,8,0,"D2:T2.DAT":A=USR(1536,16,11,20480,4096):CLOSE #1']),
    ('BLKREAD', ['OPEN #1,4,0,"D2:T2.DAT":A=USR(1536,16,7,20480,4096):CLOSE #1']),
    ('SEEK', ['OPEN #1,8,0,"D2:T4.DAT":FOR I=1 TO 16:NOTE #1,SS,BB:S(I)=SS:T(I)=BB:PRINT #1;B$:NEXT I:CLOSE #1',
              'OPEN #1,4,0,"D2:T4.DAT"', 'FOR I=1 TO 16:K=17-I:SS=S(K):BB=T(K):POINT #1,SS,BB:GET #1,A:NEXT I:CLOSE #1']),
]


def program(names):
    lines = ['40 DIM S(64),T(64),B$(250),F$(20),L$(40),D$(120)'] + USR
    lines += ['80 B$="A":B$(250)="A":B$(2)=B$',
              '90 L$="0123456789012345678901234567890123456789"']
    lines.append('99 POKE %d,0' % (MARK - 2))
    n = 100
    for j, (name, body) in enumerate(JOBS, 1):
        if name not in names:
            continue
        lines.append('%d POKE %d,%d' % (n, MARK, j))
        for k, b in enumerate(body):
            b = b.replace('TRAP 205', 'TRAP %d' % (n + 3)).replace('GOTO 204', 'GOTO %d' % (n + 2))
            lines.append('%d %s' % (n + 1 + k, b))
        n += 10
    lines.append('%d POKE %d,255:POKE %d,0' % (n, MARK, MARK - 1))
    return lines


def run(fmt, names):
    OUT.mkdir(parents=True, exist_ok=True)
    name = 'fprof-' + fmt
    d2 = OUT / (name + '-d2.atr')
    BB.work_disk(d2, fmt)
    log = OUT / (name + '.log')
    if log.exists():
        log.unlink()
    fc = T.label('fc_jsr')
    par = T.label('fc_par')
    on = OUT / (name + '-on.txt')      # the breakpoints, set at the first job
    if os.environ.get('FPROF_RAW'):    # (raw debugger lines, ; between)
        bps = os.environ['FPROF_RAW'].split(';;')
    elif os.environ.get('FPROF_LABELS'):  # (bank:label,...: those, with curbank)
        bps = []
        for bl in os.environ['FPROF_LABELS'].split(','):
            b, l = bl.split(':')
            a = T.label(l, b)
            bps.append('bp $%04X ".printf B,%s,%%u,%%u db($%04X) @cclk; g"' % (a, l, T.label('curbank')))
    elif os.environ.get('FPROF_DSK'):    # (FPROF_DSK: only the FMS's calls, Y)
        bps = ['bp $%04X ".printf D,%%02X,%%u y @cclk; g"' % T.label('kd_dsk')]
    else:
        bps = ['bp $%04X ".printf C,%%02X,%%04X,%%u db($%04X) dw($%04X) @cclk; g"' % (fc, par, par + 1),
               'bp $%04X ".printf R,%%u @cclk; g"' % (fc + 3)]
    on.write_text('\r\n'.join(bps) + '\r\n')
    cmds = ['.logopen %s' % emu.win(log),
            'ba w $%04X ".printf M,0,%%u @cclk; g"' % MARK,
            'ba w $%04X ".batch %s; g"' % (MARK - 2, emu.win(on)),
            'ba w $%04X ".logclose; g"' % (MARK - 1)]
    go = program(names) + ['RUN']
    files = {'AUTOEXEC.BAT': emu.atascii(['SIOSET 2 NORMAL', 'BASIC /I <<D1:GO.TXT']),
             'GO.TXT': emu.atascii(go)}
    d1 = T.disk(name + '-d1', files)
    with emu.Session(OUT, [d1, d2], cart=T.CAR, name=name, turbo=True, debugcmds=cmds):
        deadline = time.monotonic() + 1800
        while time.monotonic() < deadline:
            time.sleep(5)
            if log.exists() and len(re.findall(r'^M,', log.read_text(errors='replace'),
                                               re.M)) > len(names):
                break
        emu.screenshot(OUT / (name + '.png'))
    return log


def analyse(log, names):
    """(the marks in order: names, then the end)"""
    jobs = defaultdict(lambda: {'incl': defaultdict(int), 'excl': defaultdict(int),
                                'n': defaultdict(int), 'top': 0, 'total': 0})
    cur = None
    t0 = None
    stack = []
    for line in log.read_text(errors='replace').splitlines():
        f = line.strip().split(',')
        if not f or f[0] not in ('C', 'R', 'M'):
            continue
        try:
            if f[0] == 'M':
                t = int(f[2])
                if cur is not None:
                    jobs[cur]['total'] = (t - t0) & 0xFFFFFFFF
                cur, t0 = (names.pop(0) if names else None), t
                stack = []
            elif f[0] == 'C':
                stack.append([(int(f[1], 16), int(f[2], 16)), int(f[3]), 0])
            elif stack:
                key, t, child = stack.pop()
                d = (int(f[1]) - t) & 0xFFFFFFFF
                if cur:
                    jb = jobs[cur]
                    jb['incl'][key] += d
                    jb['excl'][key] += d - child
                    jb['n'][key] += 1
                    if stack:
                        stack[-1][2] += d
                    else:
                        jb['top'] += d
        except (ValueError, IndexError):
            continue
    return jobs


def report(jobs):
    syms = sym_table()
    for name, jb in jobs.items():
        tot = jb['total'] or 1
        print('\n%s: %d cycles; outside any farcall %d (%.0f%%)' % (
            name, jb['total'], jb['total'] - jb['top'], 100.0 * (jb['total'] - jb['top']) / tot))
        for key, ex in sorted(jb['excl'].items(), key=lambda kv: -kv[1])[:12]:
            print('  %-24s %6d calls  excl %9d (%4.1f%%)  incl %9d' % (
                syms[key], jb['n'][key],
                ex, 100.0 * ex / tot, jb['incl'][key]))


def sym_table():
    """(bank, address) -> 'bank:label': a jump table's JMP followed, then
    the label at or below it in the bank's label table"""
    class T(dict):
        def __missing__(self, key):
            b, a = key
            nm = BANKS.get(b)
            if nm is None or not 0xA000 <= a < 0xC000:
                return '%s $%04X' % (nm or b, a)
            labs, img = tabs(nm)
            if img and img[a - 0xA000] == 0x4C:
                a = img[a - 0xA000 + 1] | img[a - 0xA000 + 2] << 8
            best = max((x for x in labs if x <= a), default=None)
            v = '%s:%s' % (nm, labs[best] + ('' if best == a else '+%d' % (a - best))
                           if best is not None else '$%04X' % a)
            self[key] = v
            return v
    return T()


_tabs = {}


def tabs(nm):
    if nm not in _tabs:
        labs = {}
        ext = set()                    # equates from elsewhere (kernel.icl, equ.icl)
        for f in (emu.BUILD / 'eos' / 'kernel.icl', emu.ROOT / 'eos' / 'equ.icl'):
            ext.update(w.split()[0].upper() for w in f.read_text().splitlines()
                       if re.match(r'\w+\s+equ\b', w, re.I))
        lab = emu.BUILD / 'eos' / (nm + '.lab')
        for line in lab.read_text().splitlines():
            p = line.split('\t')
            if len(p) == 3 and re.fullmatch(r'[0-9A-F]{4}', p[1]):
                a = int(p[1], 16)
                if 0xA000 <= a < 0xC000 and p[2].upper() not in ext:
                    labs.setdefault(a, p[2].lower())
        binf = emu.BUILD / 'eos' / (nm + '.bin')
        _tabs[nm] = (labs, binf.read_bytes() if binf.exists() else None)
    return _tabs[nm]


def main():
    args = sys.argv[1:]
    fmt = args.pop(0) if args and args[0] in ('dos2', 'mydos', 'sdfs') else 'dos2'
    names = [a.upper() for a in args] or [j[0] for j in JOBS]
    emu.ensure_display()
    names = [j[0] for j in JOBS if j[0] in names]
    log = OUT / ('fprof-%s.log' % fmt) if os.environ.get('FPROF_OLD') else run(fmt, names)
    report(analyse(log, list(names)))


if __name__ == '__main__':
    main()
