#!/usr/bin/env python3
"""docs/BENCHMARKS.md and its charts (docs/bench/*.svg: fs, drive, printf,
summary) from build/bench.json (tools/bench.py): EOS on EOSFS against SDX on
SDFS, EOS on SDFS for reference, and PRINTF (the Toolkit's PFTEST).

usage: benchmd.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs' / 'BENCHMARKS.md'
SVG = ROOT / 'docs' / 'bench'
JOBS = [('copy', 'Copy a 40 KB file'), ('dir', 'List 60 files (DIR)'),
        ('seek', '120 seeks in a 300 KB file'), ('open', 'Open 3 files of 300')]
COLORS = {'sdx': '#c0392b', 'sdfs': '#95a5a6', 'eosfs': '#2471a3', 'eos': '#2471a3',
          'dos25': '#7d3c98', 'mydos': '#b9770e'}
PF_TESTS = ['Simple text', 'Substring s', 'Substring p', '8/16/24-bit', '32-bit long',
            'Hex strings', 'Average']


def bars(path, title, groups, series, unit='frames (1/60 s)'):
    """A horizontal grouped bar chart: groups (label, {series: frames}),
    series [(key, label)]. Each bar is its time against SDX's (the first
    series) for the same job, 100% at the dashed line; the frames beside it."""
    width, left, bar, gap = 780, 230, 18, 14
    n = len(series)
    ref = series[0][0]
    height = 88 + len(groups) * (n * bar + gap) + 20
    top = max(v / d[ref] for _, d in groups for v in d.values() if v and d.get(ref))
    scale = (width - left - 120) / max(top, 1.0)
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
           'font-family="Helvetica, Arial, sans-serif" font-size="13">' % (width, height),
           '<rect width="100%" height="100%" fill="white"/>',
           '<text x="10" y="24" font-size="16" font-weight="bold">%s</text>' % title,
           '<text x="10" y="44" fill="#555">time against SDX\'s for the same job '
           '(SDX = 100%%, shorter is faster); %s at each bar</text>' % unit]
    lx = 10
    for key, label in series:              # the legend
        out.append('<rect x="%d" y="56" width="12" height="12" fill="%s"/>' % (lx, COLORS[key]))
        out.append('<text x="%d" y="67">%s</text>' % (lx + 16, label))
        lx += 30 + 7 * len(label)
    y = 88
    x100 = left + scale
    out.append('<line x1="%.1f" y1="80" x2="%.1f" y2="%d" stroke="#999" '
               'stroke-dasharray="4 3"/>' % (x100, x100, height - 18))
    out.append('<text x="%.1f" y="%d" fill="#777" text-anchor="middle">100%%</text>' % (
        x100, height - 4))
    for glabel, d in groups:
        out.append('<text x="%d" y="%d" text-anchor="end">%s</text>' % (
            left - 8, y + n * bar / 2 + 2, glabel))
        for key, _ in series:
            v = d.get(key)
            if v is not None and d.get(ref):
                w = max(1, v / d[ref] * scale)
                out.append('<rect x="%d" y="%d" width="%.1f" height="%d" fill="%s"/>' % (
                    left, y, w, bar - 3, COLORS[key]))
                out.append('<text x="%.1f" y="%d" fill="#222">%d (%d%%)</text>' % (
                    left + w + 5, y + bar - 6, round(v), round(100 * v / d[ref])))
            y += bar
        y += gap
    out.append('</svg>')
    path.write_text('\n'.join(out) + '\n')


BJOBS = [('PUTBYTE', 'PUT 4 KB, a byte at a time'), ('GETBYTE', 'GET them back'),
         ('BLKWRITE', 'Write 16 KB in one CIO call'), ('BLKREAD', 'Read it in one call'),
         ('RECWRITE', 'PRINT # 200 lines'), ('RECREAD', 'INPUT # them'),
         ('CREATE', 'Create 30 files'), ('DIR', 'Directory listing (OPEN mode 6)'),
         ('OPEN', 'Open the 30th file 20 times'), ('SEEK', '64 NOTE/POINT seeks, a byte each'),
         ('RENAME', 'Rename 30 files'), ('DELETE', 'Delete 30 files')]
BPAIRS = [('dos2', 'dos25', 'Atari DOS 2.5'), ('mydos', 'mydos', 'MyDOS 4.53/4'),
          ('sdfs', 'sdx', 'SpartaDOS X 4.50')]


def basic_section():
    """BENCHMARKS.md's section for tools/basbench.py (build/basbench.json)."""
    path = ROOT / 'build' / 'basbench.json'
    if not path.exists():
        return []
    res = json.loads(path.read_text())
    md = ['', '## From BASIC, against Atari DOS 2.5, MyDOS and SpartaDOS X', '',
          'The same Atari BASIC program, tests/bench/BENCH.BAS, on each DOS, with EOS',
          'beside it on the same kind of disk: an Atari DOS 2 disk (720 x 128) against',
          'DOS 2.5, a MyDOS disk (720 x 256) against MyDOS 4.53/4, an SDFS disk',
          '(720 x 256) against SpartaDOS X (whose ATARIDOS.SYS only reads DOS 2 disks).',
          'BENCH.BAS and its files are in D2:; each DOS boots as it does (DOS 2.5 and',
          'MyDOS from their own disks in D1:, EOS and SDX from their cartridges) and',
          'runs BASIC (the emulator\'s Altirra BASIC 1.59, the same for all). Times are',
          'frames from the frame counter, around each job; shorter is faster; a',
          'negative number is the error the job stopped with. Made by',
          '`tools/basbench.py`.', '',
          'Two timings: **DOS** has Altirra\'s SIO patch, with EOS and SDX set to the',
          'OS\'s SIO (SIOSET 2 NORMAL), so every DOS\'s transfers take no time and the',
          'DOS\'s own work is what is measured; **drive** is a US Doubler with accurate',
          'timing, each DOS as it is: EOS and SDX use its Ultra Speed, DOS 2.5 and MyDOS',
          'the standard speed (they have no high speed SIO), as a user would have it.']
    for fmt, other, oname in BPAIRS:
        for timing, tname in (('fs', 'DOS'), ('drive', 'drive')):
            a = res.get('%s-%s-%s' % (other, fmt, timing), {})
            b = res.get('eos-%s-%s' % (fmt, timing), {})
            if not a or not b or 'error' in a or 'error' in b:
                continue
            md += ['', '### %s, %s timing' % (oname, tname), '']
            if timing == 'fs':
                svg = 'basic-%s.svg' % other
                bars(SVG / svg, 'BENCH.BAS: EOS against %s (DOS time)' % oname,
                     [(label, {other: a.get(j) if (a.get(j) or 0) > 0 else None,
                               'eos': b.get(j) if (b.get(j) or 0) > 0 else None})
                      for j, label in BJOBS if (a.get(j) or 0) > 0 and (b.get(j) or 0) > 0],
                     [(other, oname), ('eos', 'EOS')])
                md += ['![EOS against %s](bench/%s)' % (oname, svg), '']
            md += ['| job | %s | EOS | EOS vs %s |' % (oname, oname), '|---|---|---|---|']
            won = n = 0
            for j, label in BJOBS:
                x, y = a.get(j), b.get(j)
                ratio = ('%.1fx' % (x / y)) if x and y and x > 0 and y > 0 else '-'
                md.append('| %s | %s | %s | %s |' % (label, x if x is not None else '-',
                                                     y if y is not None else '-', ratio))
                if x and y and x > 0 and y > 0:
                    n += 1
                    won += y < x
            md += ['', 'EOS is faster on %d of the %d jobs.' % (won, n)]
    return md


def main():
    res = json.loads((ROOT / 'build' / 'bench.json').read_text())
    SVG.mkdir(parents=True, exist_ok=True)
    fs = {'sdx': res['sdx-fs'], 'sdfs': res['sdfs-fs'], 'eosfs': res['eosfs-fs']}
    dr = {'sdx': res['sdx-drive'], 'sdfs': res['sdfs-drive'], 'eosfs': res['eosfs-drive']}
    s_fs = [('sdx', 'SDX 4.50, SDFS'), ('sdfs', 'EOS, SDFS'), ('eosfs', 'EOS, EOSFS')]
    s_dr = s_fs
    bars(SVG / 'fs.svg', 'The DOS\'s own time (Altirra\'s standard drive, no rotation timing)',
         [(label, {k: fs[k].get(j) for k, _ in s_fs}) for j, label in JOBS], s_fs)
    bars(SVG / 'drive.svg', 'With a real drive\'s timing (US Doubler)',
         [(label, {k: dr[k].get(j) for k, _ in s_dr}) for j, label in JOBS], s_dr)

    def table(d, series, best):
        md = ['| job | %s | %s vs SDX |' % (' | '.join(l for _, l in series), dict(series)[best]),
              '|---' * (len(series) + 2) + '|']
        for j, label in JOBS:
            x, y = d['sdx'].get(j), d[best].get(j)
            md.append('| %s | %s | %s |' % (label, ' | '.join(str(d[k].get(j, '-')) for k, _ in series),
                                           ('%.1fx' % (x / y)) if x and y else '-'))
        return md

    md = ['# EOS benchmarks: EOSFS against SDX\'s SDFS', '',
          'EOS on its own file system (EOSFS, docs/EOSFS.md) against SpartaDOS X 4.50 on',
          'SDFS, with EOS on SDFS for reference. Each system runs the same jobs on the same',
          'disk (720 KB, 2880 sectors of 256 bytes) in the same emulated machine (Altirra,',
          'NTSC, a US Doubler drive). Times are frames (1/60 s) between two readings of',
          'the frame counter (tests/eos/TCK.COM); shorter is faster. The charts show each',
          'time against SDX\'s for the same job. Made by `tools/bench.py` (the runs, to',
          'build/bench.json) and `tools/benchmd.py` (this page).', '',
          'The jobs:', '',
          '- **Copy**: COPY of a 40 KB file to a new one (read and write).',
          '- **DIR**: the listing of a directory of 60 files (to NUL:).',
          '- **Seek**: 120 seeks to positions spread over a 300 KB file, one byte read at',
          '  each (tests/eos/SKT.COM, with its loading): positioning inside a big file.',
          '- **Open**: TYPE of the last 3 files of a directory of 300 files: finding a',
          '  name in a big directory.',
          '- **PRINTF**: the Toolkit\'s PFTEST, the library\'s PRINTF to the screen',
          '  (its own timing; section PRINTF).', '',
          '## The DOS\'s own time', '',
          'Altirra\'s standard drive, with no rotation timing: it takes the XF551\'s',
          'high speed commands, so both systems use them (SDX\'s SIO.SYS and EOS',
          'try them when a drive does not answer the Ultra Speed question) and the',
          'drive answers at once and takes or sends bytes as fast as the computer',
          'handles them. What is measured is the DOS itself (its code, its cache',
          'and its look-ups) and how fast its SIO driver moves the bytes.', '',
          '![the DOS\'s own time](bench/fs.svg)', '']
    md += table(fs, s_fs, 'eosfs')
    md += ['', '## With a real drive\'s timing', '',
           'Without the SIO patch and with accurate disk timing, the drive\'s rotation',
           'and the serial transfers count, as on a real machine. Both systems ask the',
           'US Doubler for its Ultra Speed rate (`?`) and use it.', '',
           '![drive time](bench/drive.svg)', '']
    md += table(dr, s_dr, 'eosfs')

    if 'eosfs-fs-320K' in res and 'eosfs-drive-320K' in res:
        md += ['', '## With extended memory: the second-level cache', '',
               'On a machine with more than 128K, EOS keeps a second-level sector cache',
               'in one 16 KB bank (docs/EOSFS.md 6): sectors its cache drops are kept',
               'there, a later miss is a memory copy instead of a disk read. The same',
               'jobs, EOS on EOSFS, on 64K and on 320K (RAMBO):', '',
               '| job | 64K, Altirra\'s drive | 320K | 64K, real drive timing | 320K |',
               '|---|---|---|---|---|']
        for j, label in JOBS:
            md.append('| %s | %s | %s | %s | %s |' % (
                label, res['eosfs-fs'].get(j, '-'), res['eosfs-fs-320K'].get(j, '-'),
                res['eosfs-drive'].get(j, '-'), res['eosfs-drive-320K'].get(j, '-')))
        md += ['', 'Directories and big directories gain most; a copy streams past it (sectors',
               'read or written to their end are not kept); random seeks cost a little: the',
               'partly read data sectors are copied into the bank and seldom read again.']

    pf = {'sdx': res.get('pftest-sdx', {}), 'eos': res.get('pftest-eos', {})}
    s_pf = [('sdx', 'SDX 4.50'), ('eos', 'EOS')]
    have_pf = all(k in pf[x] for x in pf for k in PF_TESTS)
    if have_pf:
        bars(SVG / 'printf.svg', 'PRINTF (the Toolkit\'s PFTEST)',
             [(t, {k: pf[k][t] for k, _ in s_pf}) for t in PF_TESTS], s_pf,
             unit='PFTEST\'s own count')
        md += ['', '## PRINTF', '',
               'PFTEST, the PRINTF benchmark on the SDX Toolkit disk, prints lines through',
               'the library\'s PRINTF in six ways (plain and inverse text, %s and %p',
               'substrings, 8/16/24-bit and 32-bit numbers, hex) and times each test with',
               'the frame counter. The numbers are the ones it prints (its own count,',
               'shorter is faster; the percentages it prints after them compare with',
               'its own reference and are left out). The screen output is part of',
               'each time.', '',
               '![PRINTF](bench/printf.svg)', '',
               '| test | SDX 4.50 | EOS | EOS vs SDX |', '|---|---|---|---|']
        for t in PF_TESTS:
            a, b = pf['sdx'][t], pf['eos'][t]
            md.append('| %s | %g | %g | %.2fx |' % (t, a, b, a / b))

    # every job in one chart: EOS on EOSFS against SDX
    groups = [('%s (DOS)' % label, {'sdx': fs['sdx'].get(j), 'eosfs': fs['eosfs'].get(j)})
              for j, label in JOBS]
    groups += [('%s (drive)' % label, {'sdx': dr['sdx'].get(j), 'eosfs': dr['eosfs'].get(j)})
               for j, label in JOBS]
    s_sum = [('sdx', 'SDX 4.50'), ('eosfs', 'EOS (EOSFS; PRINTF: EOS)')]
    if have_pf:
        groups.append(('PRINTF average', {'sdx': pf['sdx']['Average'],
                                          'eosfs': pf['eos']['Average']}))
    bars(SVG / 'summary.svg', 'Every benchmark: EOS against SDX', groups, s_sum,
         unit='frames or count')

    md += ['', '## Every benchmark', '',
           'EOS (on EOSFS) against SDX in every job, with both timings, and PRINTF.', '',
           '![every benchmark](bench/summary.svg)', '',
           'All the runs, in frames (1/60 s; seconds in brackets):', '',
           '| job | timing | SDX 4.50, SDFS | EOS, SDFS | EOS, EOSFS |', '|---|---|---|---|---|']
    for tname, d in (('DOS only', fs), ('drive', dr)):
        for j, label in JOBS:
            md.append('| %s | %s | %s |' % (label, tname, ' | '.join(
                ('%d (%.1f s)' % (d[k][j], d[k][j] / 60.0)) if d[k].get(j) else '-'
                for k in ('sdx', 'sdfs', 'eosfs'))))
    md += ['', 'The runs\' raw results are in build/bench.json (tools/bench.py).']
    md += ['', '## Why', '',
           '- EOS does less work per sector: a larger cache (9 buffers), writes kept',
           '  until a file is closed or the cache needs the buffer, and a directory',
           '  read without per-entry overhead.',
           '- EOSFS keeps a file as extents (runs of sectors), so positioning is',
           '  arithmetic on the extent list instead of a walk through SDFS\'s sector maps.',
           '- EOSFS directories have a name index: opening a file reads the index, then',
           '  only the entries whose name hash matches, not the whole directory.',
           '- With a real drive, the disk\'s rotation and the serial transfers take most',
           '  of the time, so the differences are smaller.',
           '- EOS keeps a disk\'s cached sectors from one command to the next while the',
           '  disk stays the same (its sequence number and random id), and when the cache',
           '  needs a changed buffer, it writes it together with the changed sectors',
           '  right after it, in one pass of the disk.',
           '- A file\'s data sector, once read or written to its end, is the first to',
           '  leave the cache. A copy streams through one or two buffers while the',
           '  bitmap, the extent lists and the directories stay, so the head does not',
           '  go back and forth across the disk for them.',
           '- A whole new sector goes to the disk straight from the program\'s buffer,',
           '  and with Ultra Speed the cache\'s sectors go to and from the drive without',
           '  a copy through main memory: EOS is ready for the next sector before the',
           '  disk has turned past it, also at a track change.',
           '- Both systems ask the drive for its Ultra Speed rate on first use; EOS',
           '  then does its transfers with its own polled SIO at that rate.',
           '- PRINTF keeps what it prints and writes it 16 characters at a time: one',
           '  call through the kernel and CIO for each 16 characters instead of one for',
           '  each character. DIR and other commands print through it as well.']
    slow = [label for j, label in JOBS
            if dr['eosfs'].get(j, 0) > dr['sdx'].get(j, 1 << 30)]
    if slow:
        md += ['- Where EOS is slower than SDX with a real drive (%s), it is still faster'
               % ', '.join(s[0].lower() + s[1:] for s in slow),
               '  in the DOS\'s own time, so the DOS\'s code is not the cause. What remains',
               '  is the sectors it reads or writes, and in what order, against the disk\'s',
               '  rotation. This is not worked out yet.']
    md += basic_section()
    DOC.write_text('\n'.join(md) + '\n')
    print('wrote', DOC)


if __name__ == '__main__':
    main()
