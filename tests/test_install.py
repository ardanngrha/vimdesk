import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[1]


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='workbench install ')
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name).resolve()
        self.config = self.home / "config user's files"
        self.bin = self.home / 'bin directory'
        self.config.mkdir()
        self.bin.mkdir()
        self.default = self.config / 'nvim'
        self.default.mkdir()
        (self.default / 'init.lua').write_text('-- original\n')

    def run_install(self, *args, ok=True):
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/install.py'), *args,
                                 '--config-home', str(self.config), '--bin-dir', str(self.bin)],
                                text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def backup(self, result):
        return Path(next(line.split(': ', 1)[1] for line in result.stdout.splitlines() if line.startswith('Backup: ')))

    def test_isolated_install_quotes_and_update_restore(self):
        self.run_install()
        target = self.config / 'vimdesk'
        self.assertEqual((self.default / 'init.lua').read_text(), '-- original\n')
        (target / 'personal.lua').write_text('-- keep me\n')
        previous_launcher = (self.bin / 'vimdesk').read_bytes()
        update = self.run_install()
        backup = self.backup(update)
        self.assertEqual((backup / 'config/personal.lua').read_text(), '-- keep me\n')
        self.assertFalse((target / 'personal.lua').exists())
        self.run_install('restore', '--backup', str(backup))
        self.assertEqual((target / 'personal.lua').read_text(), '-- keep me\n')
        self.assertEqual((self.bin / 'vimdesk').read_bytes(), previous_launcher)
        # A fake nvim confirms the shell wrapper passes quoting, flags and profile variables intact.
        fake = self.home / 'fake'; fake.mkdir()
        executable = fake / 'nvim'
        executable.write_text('#!/bin/sh\nprintf "%s\\n" "$NVIM_APPNAME" "$XDG_CONFIG_HOME" "$@"\n')
        executable.chmod(0o755)
        env = {**os.environ, 'PATH': str(fake) + os.pathsep + os.environ['PATH']}
        result = subprocess.run([str(self.bin / 'vimdesk'), 'workspace with spaces', '--headless'],
                                env=env, text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.splitlines(), ['vimdesk', str(self.config), 'workspace with spaces', '--headless'])

    def test_default_requires_explicit_flag_and_backs_up(self):
        self.run_install('--appname', 'nvim', ok=False)
        self.assertEqual((self.default / 'init.lua').read_text(), '-- original\n')
        result = self.run_install('--appname', 'nvim', '--replace-default')
        self.assertEqual((self.backup(result) / 'config/init.lua').read_text(), '-- original\n')
        self.assertFalse((self.bin / 'nvim').exists(), 'must never shadow the real nvim binary')
        self.run_install('restore', '--appname', 'nvim', '--replace-default', '--backup', str(self.backup(result)))
        self.assertEqual((self.default / 'init.lua').read_text(), '-- original\n')

    def test_symlink_backup_and_uninstall_ownership(self):
        target = self.config / 'vimdesk'
        target.symlink_to(self.default, target_is_directory=True)
        self.run_install('uninstall', ok=False)
        result = self.run_install()
        backup = self.backup(result)
        self.assertTrue((backup / 'config').is_symlink())
        self.assertEqual((self.default / 'init.lua').read_text(), '-- original\n')
        self.run_install('uninstall')
        self.assertFalse(target.exists())
        self.run_install('restore', '--backup', str(backup))
        self.assertTrue(target.is_symlink())
        self.assertEqual(target.resolve(), self.default)

    def test_unsafe_names_and_external_restore_refused(self):
        for name in ['../nvim', '.hidden', 'nvim/workbench', 'vimdesk-backups']:
            self.run_install('--appname', name, ok=False)
        self.run_install('restore', '--backup', str(self.home), ok=False)

    def test_failed_config_swap_restores_previous_installation(self):
        self.run_install()
        target = self.config / 'vimdesk'
        (target / 'personal.lua').write_text('-- preserved on failure\n')
        original_launcher = (self.bin / 'vimdesk').read_bytes()
        spec = importlib.util.spec_from_file_location('installer_under_test', ROOT / 'scripts/install.py')
        installer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(installer)
        rename = Path.rename

        def fail_swap(path, destination):
            if path.name == 'config' and path.parent.name.startswith('vimdesk-temp-'):
                raise OSError('simulated interrupted config swap')
            return rename(path, destination)

        with patch.object(sys, 'argv', ['install.py', '--config-home', str(self.config), '--bin-dir', str(self.bin)]):
            with patch.object(Path, 'rename', fail_swap):
                with self.assertRaises(OSError):
                    installer.main()
        self.assertEqual((target / 'personal.lua').read_text(), '-- preserved on failure\n')
        self.assertEqual((self.bin / 'vimdesk').read_bytes(), original_launcher)

    def test_legacy_profile_and_backup_remain_manageable(self):
        legacy = self.config / 'nvim-workbench'
        legacy.mkdir()
        (legacy / '.nvim-workbench.json').write_text(json.dumps({'appname': 'nvim-workbench', 'format': 1}))
        (legacy / 'init.lua').write_text('-- previous profile\n')
        self.run_install('uninstall', '--appname', 'nvim-workbench')
        self.assertFalse(legacy.exists())
        old_backup = self.config / 'nvim-workbench-backups/nvim-workbench-previous'
        (old_backup / 'config').mkdir(parents=True)
        (old_backup / 'config/init.lua').write_text('-- recovered legacy backup\n')
        self.run_install('restore', '--appname', 'nvim-workbench', '--backup', str(old_backup))
        self.assertEqual((legacy / 'init.lua').read_text(), '-- recovered legacy backup\n')


if __name__ == '__main__':
    unittest.main()
