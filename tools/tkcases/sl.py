"""SL: symbols by the start of their names, one added with an address and
listed afterwards, a name that matches none."""
import re

from tk_test import case


def own(lines):
    """The system's symbols are at EOS's own addresses; a symbol added at
    the command line has the program level EOS gives it (SDX's batch runs
    deeper)."""
    out = []
    for x in lines:
        if not x.startswith('COVOX'):
            x = re.sub(r'\$[0-9A-F]{4} ', '$XXXX ', x)
        out.append(re.sub(r'\$(0[1-9A-F]|[1-9A-F][0-9A-F])$', '$LV', x))
    return out


CASES = {
    'sl': case('UTILS/SYSUTIL/SL/SL.COM',
               ['SL U_GET', 'SL COVOX $D600', 'SL COVOX', 'SL ZZZ'], norm=own),
}
