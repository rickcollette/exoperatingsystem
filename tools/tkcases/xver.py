"""XVER: EOS's XVER says EOS where SDX's says SpartaDOS X, and the dates
(of CAR:COMMAND.COM) and cartridges differ, so only the shape is compared:
the version line with its date and time, the Build line (SDX's wraps at
40 columns), with and without DAYTIME=1 (month first; the order itself
is not compared), and parameters (ignored)."""
import re
from pathlib import Path
from tk_test import case

EOS_VERSION = (Path(__file__).resolve().parents[2] / 'VERSION').read_text().strip()


def shape(lines):
    out = []
    for x in lines:
        if x == '-through':                 # (the rest of SDX's Build line)
            continue
        eos = r'EOS %s \(SDX 4\.50\)' % re.escape(EOS_VERSION)
        x = re.sub(r'^(SpartaDOS X 4\.50|%s) +\d+-\d\d-\d\d +\d+:\d\d:\d\d$' % eos,
                   'VERSION', x)
        x = re.sub(r'^Build: .*', 'BUILD', x)
        out.append(x)
    return out


X = 'UTILS/SHELLUTL/XVER/XVER.COM'
CASES = {
    'xver': case(X, ['XVER', 'SET DAYTIME=1', 'XVER', 'SET DAYTIME=0', 'XVER', 'XVER /X 1', 'ECHO end'],
                 norm=shape),
}
