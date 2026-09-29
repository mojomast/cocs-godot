"""Regression for losing the current verification report at the artifact cap."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class ArtifactCap(unittest.TestCase):
    def test_crew_failure_logs_survive_gate_report_cap_bounded(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            script = root / 'tools/godot-dev/ci_bootstrap.py'
            script.parent.mkdir(parents=True)
            shutil.copy2(Path(__file__).with_name('ci_bootstrap.py'), script)
            reports = root / 'port/reports'
            reports.mkdir(parents=True)
            state = root / 'state'
            state.mkdir()
            (state / 'started').touch()
            for i in range(90):
                (reports / f'gate-{i:03}.log').write_text('PASS\n')
            attempt = state / 'vehicle-evidence/attempt'
            attempt.mkdir(parents=True)
            (attempt / 'summary.json').write_text('{"status":"FAIL"}\n')
            (attempt / 'host.log').write_bytes(b'A' * (128 * 1024) + b'ERROR: host failure\n')
            (attempt / 'guest.log').write_bytes(b'guest\n')
            (attempt / 'wire.json.gz').write_bytes(b'Z' * (512 * 1024 + 1))
            subprocess.run([sys.executable, str(script), str(state)], check=True, capture_output=True)
            artifact = state / 'artifact'
            self.assertEqual((artifact / 'vehicle/summary.json').read_bytes(), (attempt / 'summary.json').read_bytes())
            self.assertEqual((artifact / 'vehicle/host.log.tail.txt').stat().st_size, 128 * 1024)
            self.assertTrue((artifact / 'vehicle/host.log.tail.txt').read_bytes().endswith(b'ERROR: host failure\n'))
            self.assertFalse((artifact / 'vehicle/wire.json.gz').exists())
            manifest = json.loads((artifact / 'manifest.json').read_text())
            self.assertEqual(manifest['vehicle_omitted'], [{'name': 'wire.json.gz', 'source_bytes': 512 * 1024 + 1}])

    def test_current_summary_survives_many_logs_and_history_is_excluded(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            script = root / 'tools/godot-dev/ci_bootstrap.py'
            script.parent.mkdir(parents=True)
            shutil.copy2(Path(__file__).with_name('ci_bootstrap.py'), script)
            reports = root / 'port/reports'
            reports.mkdir(parents=True)
            state = root / 'state'
            state.mkdir()
            (state / 'started').touch()
            since = (state / 'started').stat().st_mtime_ns
            for i in range(90):
                path = reports / f'gate-{i:03}.log'
                path.write_text('PASS\n')
                os.utime(path, ns=(since + 1, since + 1))
            summary = reports / 'verification.json'
            summary.write_text('{"status":"passed"}\n')
            os.utime(summary, ns=(since + 1, since + 1))
            old = reports / 'historical.json'
            old.write_text('{"status":"failed"}\n')
            os.utime(old, ns=(since - 1, since - 1))
            subprocess.run([sys.executable, str(script), str(state)], check=True, capture_output=True)
            artifact = state / 'artifact'
            self.assertEqual((artifact / 'reports/verification.json').read_bytes(), summary.read_bytes())
            self.assertFalse((artifact / 'reports/historical.json').exists())
            manifest = json.loads((artifact / 'manifest.json').read_text())
            self.assertEqual(len(manifest['files']), 80)
            self.assertEqual(manifest['omitted_files'], 11)


if __name__ == '__main__':
    unittest.main()
