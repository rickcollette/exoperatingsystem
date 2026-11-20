"""RPM: a drive that is not there (the measurement runs until a key is
pressed, which the harness cannot do: see the report)."""
from tk_test import case

CASES = {
    'rpm': case('UTILS/DISKUTIL/RPM/RPM.COM', ['RPM D9:']),
}
