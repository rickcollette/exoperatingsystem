"""CIODEV: the device list, one device's vectors (the OS's K:, and
D:, which is EOS's own), a device that is not there."""
import re

from tk_test import case


def d_addr(lines):
    """D: is the DOS's handler: its addresses are EOS's own."""
    return [re.sub(r'[0-9A-F]{4}', 'XXXX', x) if x.startswith('D:') else x for x in lines]


CASES = {
    'ciodev': case('UTILS/SYSUTIL/CIODEV/CIODEV.COM',
                   ['CIODEV', 'CIODEV K', 'CIODEV D:', 'CIODEV Q:'], norm=d_addr),
}
