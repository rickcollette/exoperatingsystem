#!/usr/bin/env python3
"""Read the EOS VERSION file and make its assembler include."""
import re
import sys
from pathlib import Path


VERSION_RE = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]?)')


def parse_version(value):
    value = value.strip()
    match = VERSION_RE.fullmatch(value)
    if not match:
        raise ValueError('version must be MAJOR.MINOR, with MINOR from 0 through 99')
    return value, int(match.group(1)), int(match.group(2))


def read_version(path):
    return parse_version(Path(path).read_text())[0]


def next_version(value):
    _, major, minor = parse_version(value)
    if minor == 99:
        return '%d.0' % (major + 1)
    return '%d.%d' % (major, minor + 1)


def write_asm(version_file, output):
    version = read_version(version_file)
    text = "        dta c'%s'\n" % version
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    if not output.exists() or output.read_text() != text:
        output.write_text(text)


def main():
    try:
        if len(sys.argv) == 4 and sys.argv[1] == 'asm':
            write_asm(sys.argv[2], sys.argv[3])
        elif len(sys.argv) == 3 and sys.argv[1] == 'next':
            print(next_version(read_version(sys.argv[2])))
        else:
            raise ValueError('usage: eosversion.py asm VERSION OUTPUT | next VERSION')
    except (OSError, ValueError) as error:
        sys.exit('eosversion: ' + str(error))


if __name__ == '__main__':
    main()
