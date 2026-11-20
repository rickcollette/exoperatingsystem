"""Small subprocess wrapper for the mkatrgo ``atr`` command.

The build and emulator tools stage the exact files they want in a directory.
``create`` collapses a listed directory and its listed children to the
directory because atr imports directories recursively.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _executable():
    configured = os.environ.get('ATR')
    if configured:
        return configured
    installed = shutil.which('atr')
    if installed:
        return installed
    sibling = ROOT.parent / 'mkatrgo' / 'atr'
    return str(sibling) if sibling.is_file() else 'atr'


ATR = _executable()


def _run(args, **kwargs):
    try:
        return subprocess.run(args, **kwargs)
    except FileNotFoundError:
        sys.exit('atrtool: atr not found; build/install mkatrgo or set ATR=/path/to/atr')


def _inputs(tree, files):
    """Return listed roots; children of a listed directory are implicit."""
    tree = Path(tree)
    paths = [Path(name) for name in files]
    directories = [path for path in paths if (tree / path).is_dir()]
    roots = []
    for path in paths:
        if any(path != directory and directory in path.parents
               for directory in directories):
            continue
        if path not in roots:
            roots.append(path)
    return [str(path) for path in roots]


def create(path, tree, files, *, size=None, sectors=None, sector_size=None,
           profile='bwdos', boot=None, volume=None):
    """Create an ATR from paths relative to ``tree`` with mkatrgo."""
    args = [ATR, 'create', '--profile', profile]
    if size is not None:
        args += ['--size', str(size)]
    if sectors is not None or sector_size is not None:
        if sectors is None or sector_size is None:
            raise ValueError('sectors and sector_size must be given together')
        args += ['--sectors', str(sectors), '--sector-size', str(sector_size)]
    if boot is not None:
        args += ['--boot', str(boot)]
    if volume is not None:
        args += ['--volume', volume]
    args += [str(Path(path).resolve()), *_inputs(tree, files)]
    _run(args, cwd=tree, check=True, capture_output=True)
    Path(path).chmod(0o644)


def get(path, name, destination):
    """Extract one ATR file, returning False when it does not exist."""
    destination = Path(destination).resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    result = _run(
        [ATR, 'get', str(Path(path).resolve()), name, str(destination)],
        capture_output=True)
    return result.returncode == 0
