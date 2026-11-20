"""MEMINFO: on the harness's 64K machine, no extended memory (the banks
listed: see the agent report's scratch runs with more memory)."""
from tk_test import case

CASES = {
    'meminfo': case('UTILS/SYSUTIL/MEMINFO/MEMINFO.COM', ['MEMINFO']),
}
