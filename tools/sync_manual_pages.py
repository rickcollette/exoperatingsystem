#!/usr/bin/env python3
"""Synchronize the command-reference copies in docs/USER_MANUAL.md.

CAR command blocks already present in the manual are refreshed from
eos/carfiles/man.  The Toolkit subsection is rebuilt alphabetically from
toolkit/man so newly added transient tools cannot be omitted accidentally.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUAL = ROOT / 'docs' / 'USER_MANUAL.md'
CAR = ROOT / 'eos' / 'carfiles' / 'man'
TOOLKIT = ROOT / 'toolkit' / 'man'


def block(name, source):
    return '##### %s\n\n```text\n%s\n```' % (
        name, source.read_text().rstrip('\n'))


def main():
    text = MANUAL.read_text()

    def refresh(match):
        name = match.group(1)
        source = CAR / (name + '.txt')
        return block(name, source) if source.exists() else match.group(0)

    text = re.sub(r'##### (\S+)\n\n```text\n.*?\n```', refresh, text,
                  flags=re.S)
    start = text.index('### 12.2 EOS Toolkit command reference')
    end = text.index('\n## Hardware compatibility status', start)
    section = text[start:end]
    first = section.index('##### ')
    prefix = section[:first]
    sources = sorted(TOOLKIT.glob('*.txt'), key=lambda p: p.stem.upper())
    programs = len(list((ROOT / 'toolkit').glob('[A-Z]*.asm')))
    prefix = re.sub(r'The Toolkit has \d+ standalone programs\.',
                    'The Toolkit builds %d standalone programs and ships %d manual pages.' %
                    (programs, len(sources)), prefix)
    rebuilt = prefix + '\n\n'.join(block(p.stem.upper(), p) for p in sources) + '\n'
    MANUAL.write_text(text[:start] + rebuilt + text[end:])
    print('sync_manual_pages: %d Toolkit programs, %d pages, and current CAR pages' %
          (programs, len(sources)))


if __name__ == '__main__':
    main()
