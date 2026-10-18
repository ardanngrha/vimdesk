#!/usr/bin/env python3
"""Install a standalone workbench, preserving previous configs and launchers."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MARKER = '.vimdesk.json'
LEGACY_MARKER = '.nvim-workbench.json'

if sys.version_info < (3, 9):
    sys.exit('Python 3.9 or newer is required.')


def exists(path):
    return path.exists() or path.is_symlink()


def run_doctor():
    required = ['nvim', 'git', 'lazygit', 'rg', 'fd']
    missing = []
    for tool in required + ['python3', 'tree-sitter', 'cc', 'gopls',
                            'typescript-language-server', 'rust-analyzer', 'pyright', 'ruff', 'codex', 'claude']:
        found = shutil.which(tool)
        print(('[ok] ' if found else '[--] ') + tool)
        if not found and tool in required:
            missing.append(tool)
    if shutil.which('nvim'):
        result = subprocess.run(['nvim', '--version'], text=True, capture_output=True, check=True)
        version = re.search(r'NVIM v(\d+)\.(\d+)', result.stdout)
        if not version or tuple(map(int, version.groups())) < (0, 12):
            missing.append('Neovim >=0.12')
    if missing:
        print('Required: ' + ', '.join(missing))
        return 1
    print('Core tools ready. LSP servers, syntax parser tools, and AI agents are optional.')
    return 0


def write_launcher(path, appname, config_home):
    path.write_text('#!/bin/sh\nexport NVIM_APPNAME=' + shlex.quote(appname)
                    + '\nexport XDG_CONFIG_HOME=' + shlex.quote(str(config_home))
                    + '\nexec nvim "$@"\n')
    path.chmod(0o755)


def backup_dir(config_home, appname):
    parent = config_home / 'vimdesk-backups'
    parent.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    result = parent / (appname + '-' + stamp)
    result.mkdir(mode=0o700)
    return result


def move_out(target, launcher, backup):
    moved = []
    try:
        for source, name in [(target, 'config'), (launcher, 'launcher')]:
            if exists(source):
                shutil.move(str(source), str(backup / name))
                moved.append((backup / name, source))
    except Exception:
        for source, destination in reversed(moved):
            shutil.move(str(source), str(destination))
        raise


def rollback(target, launcher, backup):
    # Only remove the new files owned by this installation, never arbitrary state/data.
    if exists(target):
        if target.is_symlink():
            target.unlink()
        else:
            shutil.rmtree(target)
    if exists(launcher):
        launcher.unlink()
    for name, destination in [('config', target), ('launcher', launcher)]:
        if exists(backup / name):
            shutil.move(str(backup / name), str(destination))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', nargs='?', choices=['install', 'doctor', 'uninstall', 'restore'], default='install')
    parser.add_argument('--appname', default='vimdesk', help='separate Neovim profile (default: vimdesk)')
    parser.add_argument('--replace-default', action='store_true', help='required with --appname nvim')
    parser.add_argument('--config-home', type=Path, default=Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config'))
    parser.add_argument('--bin-dir', type=Path, default=Path.home() / '.local/bin')
    parser.add_argument('--backup', type=Path, help='backup directory printed by install, restore or uninstall')
    args = parser.parse_args()
    if args.action == 'doctor':
        return run_doctor()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', args.appname):
        parser.error('--appname must be a single directory name containing letters, digits, _ or -')
    if args.appname in {'vimdesk-backups', 'vimdesk-temp', 'nvim-workbench-backups', 'nvim-workbench-temp'}:
        parser.error('reserved app name')
    if args.appname == 'nvim' and not args.replace_default:
        parser.error('use --replace-default to explicitly replace your default config (it will be backed up)')
    config_home = args.config_home.expanduser().resolve()
    bin_dir = args.bin_dir.expanduser().resolve()
    target = config_home / args.appname
    launcher = bin_dir / ('vimdesk' if args.appname == 'nvim' else args.appname)
    if target == launcher or target in launcher.parents or launcher in target.parents:
        parser.error('config and launcher paths must not overlap')
    if target == ROOT or target in ROOT.parents or ROOT in target.parents:
        parser.error('installation must not overlap the source checkout')
    config_home.mkdir(parents=True, exist_ok=True)
    bin_dir.mkdir(parents=True, exist_ok=True)
    if args.action == 'uninstall':
        marker = next((target / name for name in [MARKER, LEGACY_MARKER]
                       if (target / name).is_file()), target / MARKER)
        if target.is_symlink() or not marker.is_file() or json.loads(marker.read_text()).get('appname') != args.appname:
            parser.error('refusing to uninstall a config not installed by vimdesk')
        backup = backup_dir(config_home, args.appname)
        move_out(target, launcher, backup)
        print('Uninstalled to backup: ' + str(backup))
        print('Plugin data, sessions, caches and language tools were preserved.')
        return 0
    if args.action == 'restore':
        if not args.backup:
            parser.error('restore requires --backup DIRECTORY')
        old = args.backup.expanduser().absolute()
        expected_parents = {config_home / 'vimdesk-backups', config_home / 'nvim-workbench-backups'}
        if old.is_symlink() or old.parent.resolve() not in expected_parents or not old.name.startswith(args.appname + '-'):
            parser.error('backup must belong to this app under the config backup directory')
        if not exists(old / 'config') and not exists(old / 'launcher'):
            parser.error('backup is empty or has already been restored')
        backup = backup_dir(config_home, args.appname)
        move_out(target, launcher, backup)
        try:
            for name, destination in [('config', target), ('launcher', launcher)]:
                if exists(old / name):
                    shutil.move(str(old / name), str(destination))
        except Exception:
            # Preserve any partially restored content before putting the current config back.
            failed = backup_dir(config_home, args.appname)
            move_out(target, launcher, failed)
            for name, destination in [('config', target), ('launcher', launcher)]:
                if exists(backup / name):
                    shutil.move(str(backup / name), str(destination))
            raise
        print('Restored: ' + str(old))
        print('Previous installation saved to: ' + str(backup))
        return 0
    # Stage a complete copy before moving anything currently installed.
    with tempfile.TemporaryDirectory(prefix='vimdesk-temp-', dir=config_home) as temp:
        staged = Path(temp) / 'config'
        shutil.copytree(ROOT / 'config/nvim', staged)
        (staged / MARKER).write_text(json.dumps({'appname': args.appname, 'format': 1}) + '\n')
        staged_launcher = Path(temp) / 'launcher'
        write_launcher(staged_launcher, args.appname, config_home)
        backup = backup_dir(config_home, args.appname)
        # The launcher can be on a different filesystem. Stage it in bin_dir for atomic rename.
        fd, launcher_tmp = tempfile.mkstemp(prefix='.vimdesk-', dir=bin_dir)
        os.close(fd)
        launcher_tmp = Path(launcher_tmp)
        try:
            shutil.copy2(staged_launcher, launcher_tmp)
            move_out(target, launcher, backup)
            try:
                staged.rename(target)
                launcher_tmp.rename(launcher)
            except Exception:
                rollback(target, launcher, backup)
                raise
        finally:
            launcher_tmp.unlink(missing_ok=True)
    print('Installed: ' + str(target))
    print('Backup: ' + str(backup))
    print('Launch: ' + str(launcher) + ' /path/to/parent-workspace')
    print('Add ' + str(bin_dir) + ' to PATH if needed. First launch downloads the locked plugins.')
    print('Run :WorkbenchParsers after installing a compiler and tree-sitter CLI.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('Install: ' + str(error), file=sys.stderr)
        sys.exit(1)
