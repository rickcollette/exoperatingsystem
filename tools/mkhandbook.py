#!/usr/bin/env python3
"""Merge EOS's documents into one Markdown book for PDF output.

usage: mkhandbook.py [out.md]         (default docs/EOS_HANDBOOK.md)

The chapters, in order: Why EOS (docs/WHY.md), the User Manual, EOS
Compatibility, the Hardware Test, EOSFS and the Benchmarks. Each document's
own title becomes its chapter heading (level 1, with a fixed identifier);
its other headings stay as they are. Links between these documents become
links inside the book; links to other files name the file. The benchmark
charts (SVG) are converted to PNG next to them (inkscape, else ImageMagick)
because pdflatex does not take SVG. A pandoc title block (title, table of
contents, page layout) starts the book:

  pandoc docs/EOS_HANDBOOK.md -o EOS_HANDBOOK.pdf --pdf-engine=pdflatex \\
      --resource-path=docs

(make handbook writes the Markdown, make handbook-pdf the PDF as well.)
The sources stay the documents to edit; this file is generated.
"""
import datetime
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs'
CHAPTERS = [               # file, chapter title, identifier
    ('WHY.md', 'Why EOS?', 'why-eos'),
    ('USER_MANUAL.md', 'User Manual', 'user-manual'),
    ('EOS_COMPATABILITY.md', 'Compatibility', 'compatibility'),
    ('HARDWARE_TEST.md', 'Hardware Test: Ultimate 1MB with an IDE2.0PLUS', 'hardware-test'),
    ('EOSFS.md', 'EOSFS: the EOS File System', 'eosfs-format'),
    ('BENCHMARKS.md', 'Benchmarks', 'benchmarks'),
]
IDS = {f: i for f, _, i in CHAPTERS}


def png_for(svg):
    """A PNG copy of svg (made when missing or older); its path or None."""
    png = svg.with_suffix('.png')
    if png.exists() and png.stat().st_mtime >= svg.stat().st_mtime:
        return png
    if shutil.which('inkscape'):
        cmd = ['inkscape', str(svg), '--export-type=png', '--export-dpi=200',
               '--export-filename=' + str(png)]
    elif shutil.which('convert'):
        cmd = ['convert', '-density', '200', str(svg), str(png)]
    else:
        return None
    r = subprocess.run(cmd, capture_output=True)
    return png if r.returncode == 0 and png.exists() else None


def link(m):
    """A Markdown link target: other chapters inside the book."""
    text, target = m.group(1), m.group(2)
    if re.match(r'[a-z]+://', target):
        return m.group(0)
    if target.startswith('#'):                # GitHub's "#4-startup-...": pandoc's
        return '[%s](#%s)' % (text, re.sub(r'^[\d-]+', '', target[1:]))   # ids lose numbers
    path, _, anchor = target.partition('#')
    name = Path(path).name
    if name in IDS:
        return '[%s](#%s)' % (text, re.sub(r'^[\d-]+', '', anchor) if anchor else IDS[name])
    if path.endswith('.md'):                  # a document not in the book
        return '%s (docs/%s)' % (text, name)
    return m.group(0)


def chapter(fname, title, ident):
    text = (DOCS / fname).read_text()
    lines = text.splitlines()
    if lines and lines[0].startswith('# '):
        lines = lines[1:]
    body = '\n'.join(lines).strip('\n')
    # images: SVG charts as PNG (paths relative to docs/)
    def image(m):
        alt, src = m.group(1), m.group(2)
        if src.endswith('.svg') and (DOCS / src).exists():
            png = png_for(DOCS / src)
            if png:
                src = str(png.relative_to(DOCS))
        return '![%s](%s)' % (alt, src)
    body = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', image, body)
    body = re.sub(r'(?<!!)\[([^\]]+)\]\(([^)]+)\)', link, body)
    # a section number written as "§11.4" reads the same in the book
    return '# %s {#%s}\n\n%s\n' % (title, ident, body)


def stale_pages():
    """The command pages in the User Manual that differ from their sources
    (eos/carfiles/man, toolkit/man)."""
    s = (DOCS / 'USER_MANUAL.md').read_text()
    stale = []
    for m in re.finditer(r'##### (\S+)\n\n```text\n(.*?)\n```', s, re.S):
        for src in (ROOT / 'eos/carfiles/man' / (m.group(1) + '.txt'),
                    ROOT / 'toolkit/man' / (m.group(1) + '.txt')):
            if src.exists():
                if src.read_text().rstrip('\n') != m.group(2):
                    stale.append(m.group(1))
                break
    return stale


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DOCS / 'EOS_HANDBOOK.md'
    stale = stale_pages()
    if stale:
        print('mkhandbook: warning: the User Manual\'s copies of %s differ from their '
              'MAN sources' % ', '.join(stale))
    head = '\n'.join([
        '---',
        'title: "EOS: the Extendable Operating System"',
        'subtitle: "User manual, compatibility, hardware test, file system and benchmarks"',
        'date: "%s"' % datetime.date.today().isoformat(),
        'documentclass: report',
        'toc: true',
        'toc-depth: 2',
        'numbersections: false',
        'fontsize: 10pt',
        'geometry: "a4paper,margin=2cm"',
        'colorlinks: true',
        'header-includes: |',
        '  \\usepackage{fvextra}',
        '  \\DefineVerbatimEnvironment{Highlighting}{Verbatim}{breaklines,commandchars=\\\\\\{\\}}',
        '  \\fvset{breaklines=true}',
        '---',
        '',
        '<!-- Generated by tools/mkhandbook.py from the documents in docs/:',
        '     edit those, then run make handbook. -->',
        ''])
    parts = [head] + [chapter(*c) for c in CHAPTERS]
    out.write_text('\n'.join(parts))
    print('mkhandbook: %s, %d chapters' % (out, len(CHAPTERS)))


if __name__ == '__main__':
    main()
