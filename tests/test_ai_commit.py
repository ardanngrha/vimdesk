import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'config/nvim/scripts/ai_commit.py'


class AIDraftTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='workbench-ai-test-')
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name) / 'repo'; self.repo.mkdir()
        self.bin = Path(self.tmp.name) / 'bin'; self.bin.mkdir()
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Workbench Test')
        self.git('config', 'user.email', 'test@example.invalid')
        (self.repo / 'file.txt').write_text('before\n')
        self.git('add', '.'); self.git('commit', '-m', 'initial')
        self.head = self.git('rev-parse', 'HEAD')
        (self.repo / 'file.txt').write_text('after\n')
        self.git('add', 'file.txt')
        self.env = {**os.environ, 'PATH': str(self.bin) + os.pathsep + os.environ['PATH'],
                    'MOCK_REPO': str(self.repo), 'MOCK_SUBJECT': 'fix: improve example output',
                    'MOCK_LOG': str(Path(self.tmp.name) / 'invocation.json')}
        for agent in ['codex', 'claude']:
            fake = self.bin / agent
            fake.write_text('#!' + sys.executable + '\n' + '''import json, os, pathlib, subprocess, sys
args = sys.argv[1:]
prompt = sys.stdin.read()
pathlib.Path(os.environ['MOCK_LOG']).write_text(json.dumps({'args': args, 'cwd': os.getcwd(), 'prompt': prompt}))
if os.environ.get('MOCK_MUTATE'):
    repo = pathlib.Path(os.environ['MOCK_REPO'])
    (repo / 'file.txt').write_text('changed while generating\\n')
    subprocess.run(['git', '-C', str(repo), 'add', 'file.txt'], check=True)
payload = {'subject': os.environ['MOCK_SUBJECT']}
if '--output-last-message' in args:
    pathlib.Path(args[args.index('--output-last-message') + 1]).write_text(json.dumps(payload))
else:
    print(json.dumps({'structured_output': payload}))
''')
            fake.chmod(0o755)

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args], check=True, text=True, capture_output=True).stdout.strip()

    def generate(self, agent='codex', ok=True):
        result = subprocess.run([sys.executable, str(SCRIPT), '--agent', agent], cwd=self.repo,
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, ok, result.stderr)
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.head, 'generation must never commit')
        return result

    def test_both_providers_and_read_only_invocation(self):
        for agent in ['codex', 'claude']:
            with self.subTest(agent=agent):
                before = self.git('write-tree')
                result = self.generate(agent)
                self.assertEqual(result.stdout.strip(), self.env['MOCK_SUBJECT'])
                self.assertEqual(before, self.git('write-tree'))
                invocation = json.loads(Path(self.env['MOCK_LOG']).read_text())
                self.assertNotEqual(invocation['cwd'], str(self.repo))
                self.assertIn('+after', invocation['prompt'])
                self.assertIn('untrusted data', invocation['prompt'])
                flags = invocation['args']
                if agent == 'codex':
                    self.assertIn('--ignore-user-config', flags)
                    self.assertIn('--ignore-rules', flags)
                    self.assertIn('--ephemeral', flags)
                    self.assertEqual(flags[flags.index('--sandbox') + 1], 'read-only')
                else:
                    self.assertEqual(flags[flags.index('--tools') + 1], '')
                    self.assertIn('--strict-mcp-config', flags)
                    self.assertIn('--no-session-persistence', flags)
                    self.assertIn('{"disableAllHooks":true}', flags)

    def test_invalid_subject_and_stale_snapshot_are_rejected(self):
        for subject in ['not conventional', 'fix: one\nfix: two', 'fix: ' + 'x' * 80]:
            self.env['MOCK_SUBJECT'] = subject
            self.generate(ok=False)
        self.env['MOCK_SUBJECT'] = 'fix: valid subject'
        self.env['MOCK_MUTATE'] = '1'
        result = self.generate(ok=False)
        self.assertIn('changed during generation', result.stderr)
        self.assertEqual(result.stdout, '')

    def test_no_staged_changes_and_conflicts_do_not_call_agent(self):
        self.git('reset', 'HEAD', '--', 'file.txt')
        self.generate(ok=False)
        self.assertFalse(Path(self.env['MOCK_LOG']).exists())
        self.git('checkout', '--', 'file.txt')
        self.git('switch', '-c', 'incoming')
        (self.repo / 'file.txt').write_text('incoming\n'); self.git('add', '.'); self.git('commit', '-m', 'incoming')
        self.git('switch', 'main')
        (self.repo / 'file.txt').write_text('current\n'); self.git('add', '.'); self.git('commit', '-m', 'current')
        self.head = self.git('rev-parse', 'HEAD')
        subprocess.run(['git', '-C', str(self.repo), 'merge', 'incoming'], capture_output=True, check=False)
        result = self.generate(ok=False)
        self.assertIn('conflicts', result.stderr)
        self.assertFalse(Path(self.env['MOCK_LOG']).exists())


if __name__ == '__main__':
    unittest.main()
