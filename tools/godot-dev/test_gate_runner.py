import json
from pathlib import Path
import sys
import tempfile
import unittest
from gate_runner import run_gate, save_report


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.log = Path(self.temp.name) / 'gate.log'

    def run_code(self, code, timeout=2):
        return run_gate('test', [sys.executable, '-u', '-c', code], self.log, timeout)

    def test_success(self):
        result, output = self.run_code("print('real output')")
        self.assertTrue(result['passed'])
        self.assertEqual(output, self.log.read_text())
        self.assertGreaterEqual(result['duration_seconds'], 0)

    def test_nonzero(self):
        result, _ = self.run_code('raise SystemExit(7)')
        self.assertEqual(result['exit_code'], 7)
        self.assertEqual(result['failure_reason'], 'nonzero-exit')

    def test_engine_error_even_zero(self):
        for marker in ['ERROR:', 'SCRIPT ERROR:']:
            result, _ = self.run_code(f'print({marker!r})')
            self.assertFalse(result['passed'])
            self.assertEqual(result['failure_reason'], 'engine-error')

    def test_timeout_preserves_output_and_kills_inherited_pipe_child(self):
        result, output = self.run_code("import subprocess,time,sys; subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); print('before timeout'); time.sleep(30)", 0.2)
        self.assertEqual(result['failure_reason'], 'timeout')
        self.assertIn('before timeout', output)
        self.assertLess(result['duration_seconds'], 3)

    def test_missing_executable(self):
        result, output = run_gate('missing', ['/nonexistent/orbit-test-binary'], self.log)
        self.assertEqual(result['failure_reason'], 'launch-error')
        self.assertTrue(output)

    def test_atomic_progress_replaces_old_success(self):
        path = Path(self.temp.name) / 'report.json'
        save_report(path, {'status': 'passed'})
        save_report(path, {'status': 'running', 'gates': []})
        self.assertEqual(json.loads(path.read_text())['status'], 'running')
        self.assertFalse(path.with_suffix('.json.tmp').exists())


if __name__ == '__main__':
    unittest.main()
