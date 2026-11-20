"""APETIME: no PC side answering on the harness (the date and time from
Altirra's SIO clock: see the report's scratch runs)."""
from tk_test import case

CASES = {
    'apetime': case('UTILS/SYSUTIL/APETIME/APETIME.COM', ['APETIME', 'APETIME /Q', 'APETIME /X']),
}
