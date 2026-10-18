"""Check the practice workspace and synchronized beginner documentation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class OnboardingTests(unittest.TestCase):
    def test_markdown_guides_match_website_steps(self):
        subprocess.run([sys.executable, str(ROOT / 'scripts/build_guide.py'), '--check'], check=True)
        guide = json.loads((ROOT / 'docs/assets/guide.json').read_text())
        self.assertEqual(len({step['id'] for step in guide['steps']}), 9)
        for step in guide['steps']:
            for block in step['blocks']:
                if block['where'] == 'terminal':
                    # Parse only: never install Homebrew or execute onboarding commands in tests.
                    subprocess.run(['/bin/bash', '-n'], input=block['code'], text=True, check=True)
                else:
                    self.assertTrue(block['code'].startswith(':'))

    def test_demo_has_two_changed_repos_and_preserves_global_identity(self):
        with tempfile.TemporaryDirectory(prefix='workbench-demo-test-') as temp:
            global_config = Path(temp) / 'gitconfig'
            global_config.write_text('[user]\n  name = Existing User\n  email = existing@example.invalid\n')
            before = global_config.read_bytes()
            env = {**os.environ, 'GIT_CONFIG_GLOBAL': str(global_config)}
            result = subprocess.run([sys.executable, str(ROOT / 'scripts/demo.py'), '--print-only'],
                                    env=env, text=True, capture_output=True, check=True)
            parent = Path(result.stdout.strip()).resolve()
            self.assertEqual(parent.parent, Path(tempfile.gettempdir()).resolve())
            self.assertTrue(parent.name.startswith('nvim-workbench-demo-'))
            try:
                self.assertEqual(sorted(path.name for path in parent.iterdir()), ['backend', 'frontend'])
                for repo in parent.iterdir():
                    def git(*args):
                        return subprocess.check_output(['git', '-C', str(repo), *args], text=True, env=env).strip()
                    self.assertTrue(git('status', '--porcelain').startswith('M '))
                    self.assertEqual(git('show', '-s', '--format=%an'), 'Workbench Demo')
                    self.assertEqual(git('remote'), '')
                self.assertEqual(global_config.read_bytes(), before)
            finally:
                shutil.rmtree(parent)


if __name__ == '__main__':
    unittest.main()
