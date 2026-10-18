#!/usr/bin/env python3
"""Open two disposable local Git repositories for a first workbench session."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def create_demo():
    parent = Path(tempfile.mkdtemp(prefix='nvim-workbench-demo-')).resolve()
    for name, filename, before, after in [
        ('backend', 'app.py', 'def greeting():\n    return "Hello"\n', 'def greeting():\n    return "Hello from the backend"\n'),
        ('frontend', 'app.js', 'export const title = "Hello";\n', 'export const title = "Hello from the frontend";\n'),
    ]:
        repo = parent / name; repo.mkdir()
        def git(*args):
            subprocess.run(['git', '-C', str(repo), '-c', 'core.hooksPath=/dev/null',
                            '-c', 'commit.gpgsign=false', '-c', 'user.name=Workbench Demo',
                            '-c', 'user.email=demo@example.invalid', *args], check=True, capture_output=True)
        git('init', '--template=', '-b', 'main')
        (repo / filename).write_text(before)
        (repo / 'README.md').write_text('# ' + name + '\n\nA local practice repository. No remote is configured.\n')
        git('add', '.'); git('commit', '-m', 'feat: add example')
        (repo / filename).write_text(after)
    return parent


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--print-only', action='store_true', help='create fixtures without opening Neovim')
    args = cli.parse_args()
    if not shutil.which('git'):
        cli.error('Install Git first (brew install git).')
    launcher = Path.home() / '.local/bin/nvim-workbench'
    executable = str(launcher) if launcher.is_file() else shutil.which('nvim-workbench')
    if not args.print_only and not executable:
        cli.error('Run ./install.sh first, or put your custom launcher on PATH.')
    parent = create_demo()
    print(str(parent), flush=True)
    if args.print_only:
        return 0
    print('Two local practice repos; they have no remotes. Press Space q q to quit.', flush=True)
    result = subprocess.run([executable, str(parent)])
    print('Open this practice folder again: ' + str(parent))
    print('It is temporary; use a real project folder to keep your work long term.')
    return result.returncode


if __name__ == '__main__':
    sys.exit(main())
