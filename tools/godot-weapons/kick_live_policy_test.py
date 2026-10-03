"""Lock/cleanup negatives using temporary locks and tiny Python processes only."""
import importlib.util
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('kick_live', Path(__file__).with_name('kick-live.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class ExecutionPolicy(unittest.TestCase):
    def test_lock_refuses_without_wait_and_releases(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as folder:
            path = Path(folder) / 'slot.lock'
            with runner.acceptance_lock(path):
                start = time.monotonic()
                with self.assertRaisesRegex(RuntimeError, 'nothing launched'):
                    with runner.acceptance_lock(path):
                        self.fail('contended slot acquired')
                self.assertLess(time.monotonic()-start, .5)
            with runner.acceptance_lock(path):
                pass

    def test_auditor_finds_descendant_without_leader_and_counts_zombies(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as folder:
            proc = Path(folder)
            for pid, state, group in [(22, 'S', 20), (23, 'Z', 20), (24, 'S', 99)]:
                entry = proc / str(pid)
                entry.mkdir()
                (entry / 'stat').write_text(f'{pid} (a tricky ) name) {state} 1 {group} 20 0 0\n')
            self.assertEqual(runner.group_members(20, proc), [{'pid':22,'state':'S'}, {'pid':23,'state':'Z'}])
            evidence = {'empty':False,'survivors':[{'pid':23,'state':'Z'}], 'returncode':0,'escalated':False}
            self.assertFalse(runner.clean_stop(evidence, 'authority'))
            self.assertFalse(runner.clean_stop(evidence, 'display'))

    def synthetic(self, code):
        process = subprocess.Popen([sys.executable, '-u', '-c', code], stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, start_new_session=True, text=True)
        self.addCleanup(process.stdout.close)
        self.addCleanup(process.stderr.close)
        self.addCleanup(lambda: runner.stop_group(process, grace=.2, audit=.5))
        self.assertTrue(select.select([process.stdout], [], [], 3)[0], 'synthetic readiness deadline')
        self.assertEqual(process.stdout.readline().strip(), 'ready')
        return process

    def test_graceful_group_shutdown_reaps_child_and_leader(self):
        process = self.synthetic('''
import subprocess, signal, sys, time
child = subprocess.Popen([sys.executable, '-c', 'import time;time.sleep(30)'])
def stop(*args):
    child.terminate()
    child.wait(timeout=2)
    sys.exit(0)
signal.signal(signal.SIGTERM, stop)
print('ready', flush=True)
time.sleep(30)
''')
        self.assertGreaterEqual(len(runner.group_members(process.pid)), 2)
        result = runner.stop_group(process, grace=2, audit=.5)
        self.assertFalse(result['escalated'])
        self.assertEqual(result['survivors'], [])
        self.assertTrue(runner.clean_stop(result, 'authority'))

    def test_forced_authority_cannot_be_clean_even_after_zero_survivors(self):
        process = self.synthetic('''
import signal, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
print('ready', flush=True)
time.sleep(30)
''')
        result = runner.stop_group(process, grace=.05, audit=.5)
        self.assertTrue(result['escalated'])
        self.assertEqual(result['survivors'], [])
        self.assertFalse(runner.clean_stop(result, 'authority'))
        self.assertTrue(runner.clean_stop(result, 'display'))

    def test_source_policy_requires_grant_and_one_thread(self):
        source = Path(runner.__file__).read_text()
        self.assertEqual(runner.RENDER_THREADS, 1)
        self.assertEqual(str(runner.ACCEPTANCE_LOCK), '/tmp/opencode/cocs-finish-acceptance.lock')
        self.assertIn("parser.add_argument('--grant', required=True", source)
        self.assertIn('with acceptance_lock():\n            run(args)', source)
        self.assertIn("'LP_NUM_THREADS': str(RENDER_THREADS)", source)
        self.assertIn("'git', 'ls-files', '-z', '--', 'godot'", source)

    def test_staging_excludes_ignored_or_untracked_injection(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as folder:
            root = Path(folder) / 'source'
            (root / 'godot').mkdir(parents=True)
            (root / 'godot/tracked.gd').write_text('tracked source')
            (root / 'godot/ignored.gd').write_text('injected source')
            destination = Path(folder) / 'stage'
            with patch.object(runner, 'ROOT', root), patch.object(runner.subprocess, 'check_output', return_value=b'godot/tracked.gd\0'):
                runner.copy_tracked_project(destination)
            self.assertEqual((destination / 'tracked.gd').read_text(), 'tracked source')
            self.assertFalse((destination / 'ignored.gd').exists())


if __name__ == '__main__':
    unittest.main()
