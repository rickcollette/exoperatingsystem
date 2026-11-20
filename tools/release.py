#!/usr/bin/env python3
"""Check and publish an EOS GitHub release. Called by make release."""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACCOUNT = 'rickcollette'
EMAIL = 'rcollet@gmail.com'
REPOSITORY = 'rickcollette/exoperatingsystem'
REMOTE = 'https://github.com/rickcollette/exoperatingsystem.git'


class ReleaseError(Exception):
    pass


def run(*args, check=True):
    p = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    if check and p.returncode:
        detail = (p.stderr or p.stdout).strip()
        raise ReleaseError('%s: %s' % (' '.join(args), detail))
    return p


def out(*args):
    return run(*args).stdout.strip()


def tag_for(version):
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){1,2}(?:[-._][0-9A-Za-z]+)*', version):
        raise ReleaseError('bad release version: ' + version)
    return 'v' + version


def check_identity():
    if out('git', 'config', '--get', 'user.name') != ACCOUNT:
        raise ReleaseError('git user.name must be ' + ACCOUNT)
    if out('git', 'config', '--get', 'user.email') != EMAIL:
        raise ReleaseError('git user.email must be ' + EMAIL)
    if out('git', 'remote', 'get-url', 'origin') != REMOTE:
        raise ReleaseError('origin must be ' + REMOTE)
    if out('gh', 'api', 'user', '--jq', '.login') != ACCOUNT:
        raise ReleaseError('gh must be logged in as ' + ACCOUNT)

    for commit in out('git', 'rev-list', '--all').splitlines():
        fields = out('git', 'show', '-s',
                     '--format=%an%x00%ae%x00%cn%x00%ce%x00%B', commit).split('\x00', 4)
        author, email, committer, cemail, body = fields
        if author != ACCOUNT or email != EMAIL or committer != ACCOUNT or cemail != EMAIL:
            raise ReleaseError('commit history contains another author or committer')
        if re.search(r'(?im)^co-authored-by:', body):
            raise ReleaseError('commit history contains a co-author trailer')


def check_tree():
    if out('git', 'branch', '--show-current') != 'main':
        raise ReleaseError('release must run from main')
    if out('git', 'status', '--porcelain', '--untracked-files=normal'):
        raise ReleaseError('worktree is not clean')
    run('git', 'fetch', '--quiet', '--tags', 'origin', 'main')
    if run('git', 'merge-base', '--is-ancestor', 'origin/main', 'HEAD', check=False).returncode:
        raise ReleaseError('main has diverged from origin/main')


def check_release(version):
    tag = tag_for(version)
    local = run('git', 'rev-parse', '-q', '--verify', 'refs/tags/' + tag, check=False)
    if local.returncode and run('git', 'ls-remote', '--exit-code', '--tags', 'origin',
                                'refs/tags/' + tag, check=False).returncode == 0:
        run('git', 'fetch', '--quiet', 'origin', 'refs/tags/' + tag + ':refs/tags/' + tag)
        local = run('git', 'rev-parse', '-q', '--verify', 'refs/tags/' + tag, check=False)
    if local.returncode == 0 and out('git', 'rev-list', '-n', '1', tag) != out('git', 'rev-parse', 'HEAD'):
        raise ReleaseError(tag + ' does not point at HEAD')
    if run('gh', 'release', 'view', tag, '--repo', REPOSITORY, check=False).returncode == 0:
        raise ReleaseError('release already exists: ' + tag)
    return tag


def check_all(version):
    check_identity()
    check_tree()
    tag = check_release(version)
    print('release check: %s, %s <%s>, github.com/%s' %
          (tag, ACCOUNT, EMAIL, REPOSITORY))
    return tag


def publish(version, names):
    tag = check_all(version)
    assets = [Path(n) for n in names]
    missing = [str(p) for p in assets if not (ROOT / p).is_file()]
    if missing:
        raise ReleaseError('missing release files: ' + ', '.join(missing))

    if run('git', 'rev-parse', '-q', '--verify', 'refs/tags/' + tag,
           check=False).returncode:
        run('git', 'tag', '-a', tag, '-m', 'EOS ' + version)

    remote_tag = run('git', 'ls-remote', '--exit-code', '--tags', 'origin',
                     'refs/tags/' + tag, check=False).returncode == 0
    if remote_tag:
        run('git', 'push', 'origin', 'main')
    else:
        run('git', 'push', '--atomic', 'origin', 'main', 'refs/tags/' + tag)

    run('gh', 'release', 'create', tag, *[str(p) for p in assets],
        '--repo', REPOSITORY, '--verify-tag', '--title', 'EOS ' + version,
        '--generate-notes')
    print('release: https://github.com/%s/releases/tag/%s' % (REPOSITORY, tag))


def main():
    try:
        if len(sys.argv) < 3 or sys.argv[1] not in ('check', 'publish'):
            raise ReleaseError('usage: release.py check VERSION | publish VERSION FILE...')
        if sys.argv[1] == 'check':
            if len(sys.argv) != 3:
                raise ReleaseError('usage: release.py check VERSION')
            check_all(sys.argv[2])
        else:
            if len(sys.argv) < 4:
                raise ReleaseError('no release files')
            publish(sys.argv[2], sys.argv[3:])
    except ReleaseError as e:
        sys.exit('release: ' + str(e))


if __name__ == '__main__':
    main()
