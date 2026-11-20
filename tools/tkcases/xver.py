"""XVER: EOS's XVER says EOS where SDX's says SpartaDOS X, and the dates
(of CAR:COMMAND.COM) and cartridges differ, so only the shape is compared:
the version line with its date and time, the Build line (SDX's wraps at
40 columns), with and without DAYTIME=1 (month first; the order itself
is not compared), and parameters (ignored)."""
import re
from tk_test import case


def shape(lines):
    out = []
    for x in lines:
        if x == '-through':                 # (the rest of SDX's Build line)
            continue
        x = re.sub(r'^(SpartaDOS X 4\.50|EOS 0\.1 \(SDX 4\.50\)) +\d+-\d\d-\d\d +\d+:\d\d:\d\d$', 'VERSION', x)
        x = re.sub(r'^Build: .*', 'BUILD', x)
        out.append(x)
    return out


X = 'UTILS/SHELLUTL/XVER/XVER.COM'
CASES = {
    'xver': case(X, ['XVER', 'SET DAYTIME=1', 'XVER', 'SET DAYTIME=0', 'XVER', 'XVER /X 1', 'ECHO end'],
                 norm=shape),
}
