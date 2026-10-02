"""Source-only safety/acceptance tests. Fake children never stand in for Godot."""
import json
import hashlib
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from finish_runner import (MATRIX, accept_attestation, cleanup_children, dependency_inventory, input_identity,
                           isolated_environment, load_matrix, main, run_bounded, summarize)
from gate_runner import save_report


class FinishRunnerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='finish-runner-test-', dir='/tmp/opencode')
        self.root = Path(self.temp.name)
        self.lock_patch = patch('finish_runner.COHORT_LOCK', self.root / 'test-cohort.lock')
        self.lock_patch.start()

    def tearDown(self):
        cleanup_children()
        self.lock_patch.stop()
        self.temp.cleanup()

    def run_child(self, code, timeout=2):
        return run_bounded([sys.executable, '-c', code], self.root, dict(os.environ),
                           self.root / 'output.log', timeout)

    def test_watchdog_kills_detached_term_resistant_descendants(self):
        child = "import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(60)"
        code = ("import subprocess,sys,time,pathlib; p=subprocess.Popen([sys.executable,'-c',"
                + repr(child) + "],start_new_session=True); pathlib.Path('child.pid').write_text(str(p.pid)); time.sleep(60)")
        start = time.monotonic()
        result = self.run_child(code, .2)
        self.assertEqual(result['failure_reason'], 'timeout')
        self.assertLess(time.monotonic() - start, 4)
        self.assertFalse(result['cleanup']['remaining'])
        self.assertFalse(Path('/proc/' + (self.root / 'child.pid').read_text()).exists())

    def test_leader_exit_cannot_hide_detached_orphans(self):
        result = self.run_child("import subprocess,sys; subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)'],start_new_session=True)")
        self.assertEqual(result['failure_reason'], 'leaked-descendants')
        self.assertFalse(result['cleanup']['remaining'])

    def test_clean_exit_and_strict_errors(self):
        result = self.run_child("print('real synthetic test output')")
        self.assertEqual(result['status'], 'passed')
        (self.root / 'output.log').unlink()
        self.assertEqual(self.run_child("print('ERROR: resources still in use')")['failure_reason'], 'engine-error')

    def test_signal_interrupt_is_recorded_and_reaped(self):
        result = self.run_child("import os,signal,time; os.kill(os.getppid(),signal.SIGTERM); time.sleep(60)")
        self.assertEqual(result['failure_reason'], 'interrupted')
        self.assertFalse(result['cleanup']['remaining'])

    def test_missing_executable_is_a_failed_attempt(self):
        result = run_bounded(['/nonexistent/finish-test'], self.root, dict(os.environ), self.root / 'output.log', 1)
        self.assertEqual(result['failure_reason'], 'launch-error')

    def test_atomic_report_and_no_historical_overwrite(self):
        destination = self.root / 'report.json'
        save_report(destination, {'attempts': [{'status': 'failed'}]})
        before = destination.read_bytes()
        with patch('pathlib.Path.replace', side_effect=OSError('simulated interrupted rename')):
            with self.assertRaises(OSError):
                save_report(destination, {'attempts': []})
        self.assertEqual(destination.read_bytes(), before)

    def test_matrix_has_full_bounded_scope_without_native_claims(self):
        data = load_matrix()
        jobs = {j['id']: j for j in data['jobs']}
        self.assertEqual(len([j for j in jobs if j.startswith('spectator-') and j.endswith(('wide', 'compact'))]), 8)
        self.assertGreater(jobs['challenge-four-round-persistence']['timeout'], 290)
        self.assertGreater(jobs['horde-boss']['timeout'], 950)
        self.assertEqual(jobs['horde-boss']['grant'], 'horde-boss')
        self.assertEqual(jobs['horde-boss']['after'], ['horde-chain'])
        self.assertEqual(jobs['audio-source-wire-PCM']['cohort'], 'audio')
        for scenario in ['death', 'expiration', 'reconnect']:
            self.assertIn('gameplay-rope-' + scenario, jobs)
        report = {'attempts': {j: [{'status': 'passed'}] for j in jobs if jobs[j]['cohort'] == 'source'}}
        summarize(report, data['jobs'])
        self.assertFalse(report['release_ready'])
        self.assertEqual(report['status'], 'incomplete')
        self.assertIn('controls-physical-OS-assistive', report['incomplete_critical'])

    def test_dependency_resolution_is_real_not_lane_fallback(self):
        (self.root / 'entry.mjs').write_text("import './missing.mjs'; import {x} from 'ws'; new URL('./history.json',import.meta.url);")
        result = dependency_inventory(self.root, {'requires': ['entry.mjs']})
        self.assertEqual(result['missing'], ['missing.mjs'])
        self.assertEqual(result['node_packages'], ['ws'])

    def test_integrated_entrypoints_exist_in_this_checkout(self):
        root = Path(__file__).resolve().parents[2]
        matrix = load_matrix()
        generated = set(matrix['generated_prerequisites'])
        for job in matrix['jobs']:
            for path in job.get('requires', []):
                if path not in generated:
                    with self.subTest(gate=job['id'], path=path):
                        self.assertTrue((root / path).is_file(), 'Missing integrated entrypoint; no other-worktree fallback')
        by_id = {job['id']: job for job in matrix['jobs']}
        for name in ('caption-integration-native', 'home-replays-native', 'replay-bridge-negative-native'):
            self.assertEqual(by_id[name]['cohort'], 'engine')
            self.assertIn('native-import', by_id[name]['after'])

    def test_private_stores_and_grants_do_not_leak(self):
        with patch.dict(os.environ, {'COCS_SETTINGS_PATH': '/user/settings', 'CHALLENGE_ENGINE_GRANT': '1',
                                    'OPERATORS': 'wrong', 'COCS_CAREER_ROOT': '/user/career'}):
            env = isolated_environment(self.root)
        self.assertNotIn('CHALLENGE_ENGINE_GRANT', env)
        self.assertNotIn('OPERATORS', env)
        self.assertTrue(env['COCS_SETTINGS_PATH'].startswith(str(self.root)))
        self.assertEqual(env['PORT'], '0')

    def fixture_repo(self):
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        (self.root / 'input.txt').write_text('v1')
        subprocess.run(['git', 'add', 'input.txt'], cwd=self.root, check=True)
        data = {'schema': 1, 'dynamic_dependencies': [], 'jobs': [
            {'id': 'heavy', 'cohort': 'engine', 'timeout': 1, 'command': [sys.executable, '-c', "raise Exception('MUST NOT RUN')"],
             'evidence_kind': 'synthetic-runner-only', 'criteria': 'never native evidence'}]}
        path = self.root / 'matrix.json'
        path.write_text(json.dumps(data))
        return path, data

    def test_default_plan_and_run_without_grant_never_spawn_heavy(self):
        path, _ = self.fixture_repo()
        with patch('finish_runner.run_bounded', side_effect=AssertionError('engine started')):
            for flags in ([], ['--run']):
                self.assertEqual(main(['--root', str(self.root), '--matrix', str(path), '--evidence', str(self.root / 'evidence'), *flags]), 1)
        reports = list((self.root / 'evidence').glob('run-*/report.json'))
        self.assertEqual(len(reports), 2)
        for report in reports:
            data = json.loads(report.read_text())
            self.assertEqual(data['attempts']['heavy'][0]['status'], 'unrun')
            self.assertFalse(data['release_ready'])

    def test_changed_bytes_reject_resume_preserving_old_report(self):
        path, data = self.fixture_repo()
        first = input_identity(self.root, data, {})
        main(['--root', str(self.root), '--matrix', str(path), '--evidence', str(self.root / 'evidence')])
        report = next((self.root / 'evidence').glob('run-*/report.json'))
        before = report.read_bytes()
        (self.root / 'input.txt').write_text('v2')
        self.assertNotEqual(first, input_identity(self.root, data, {}))
        with self.assertRaises(SystemExit):
            main(['--root', str(self.root), '--matrix', str(path), '--resume', str(report), '--evidence', str(self.root / 'evidence')])
        self.assertEqual(report.read_bytes(), before)

    def test_resume_does_not_repeat_success_and_failed_retry_is_explicit(self):
        path, data = self.fixture_repo()
        job = data['jobs'][0]
        job.update(cohort='source', command=[sys.executable, '-c', 'print(42)'])
        path.write_text(json.dumps(data))
        base = ['--root', str(self.root), '--matrix', str(path), '--evidence', str(self.root / 'evidence'), '--run']
        self.assertEqual(main(base), 0)
        report = next((self.root / 'evidence').glob('run-*/report.json'))
        with patch('finish_runner.run_bounded', side_effect=AssertionError('passed gate rerun')):
            self.assertEqual(main([*base, '--resume', str(report)]), 0)
        self.assertEqual(len(json.loads(report.read_text())['attempts']['heavy']), 1)
        job['command'] = [sys.executable, '-c', 'raise SystemExit(3)']
        path.write_text(json.dumps(data))
        self.assertEqual(main(base), 1)
        failed = next(p for p in (self.root / 'evidence').glob('run-*/report.json') if p != report)
        self.assertEqual(main([*base, '--resume', str(failed)]), 1)
        self.assertEqual(len(json.loads(failed.read_text())['attempts']['heavy']), 1)
        self.assertEqual(main([*base, '--resume', str(failed), '--retry-failed']), 1)
        attempts = json.loads(failed.read_text())['attempts']['heavy']
        self.assertEqual(len(attempts), 2)
        self.assertTrue(all(a['status'] == 'failed' for a in attempts))
        self.assertNotEqual(attempts[0]['scope'], attempts[1]['scope'])

    def test_same_head_changed_ignored_dynamic_input_invalidates_resume(self):
        _, data = self.fixture_repo()
        data['dynamic_dependencies'] = ['generated']
        (self.root / 'generated').mkdir()
        file = self.root / 'generated' / 'resource.bin'
        file.write_bytes(b'one')
        first = input_identity(self.root, data, {})
        file.write_bytes(b'two')
        self.assertNotEqual(first['sha256'], input_identity(self.root, data, {})['sha256'])

    def test_audio_dummy_and_missing_audio_grant_cannot_pass(self):
        path, data = self.fixture_repo()
        data['jobs'][0]['cohort'] = 'audio'
        path.write_text(json.dumps(data))
        with patch.dict(os.environ, {'AUDIO_DRIVER': 'Dummy', 'GODOT_BIN': '/not/executed'}), \
                patch('finish_runner.run_bounded', side_effect=AssertionError('audio started')):
            self.assertEqual(main(['--root', str(self.root), '--matrix', str(path), '--evidence', str(self.root / 'evidence'),
                                   '--run', '--grant', 'engine', '--grant', 'audio']), 1)
        report = json.loads(next((self.root / 'evidence').glob('run-*/report.json')).read_text())
        self.assertIn('real AUDIO_DRIVER', report['attempts']['heavy'][-1]['skip_reason'])

    def test_exclusive_cohort_rejects_concurrent_invocation(self):
        path, _ = self.fixture_repo()
        with (self.root / 'test-cohort.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):
                main(['--root', str(self.root), '--matrix', str(path), '--evidence', str(self.root / 'evidence')])

    def test_owner_receipt_cannot_replace_native_or_changed_evidence(self):
        artifact = self.root / 'review.txt'
        artifact.write_text('Synthetic reviewer fixture, never a native result')
        receipt = {'gate': 'review', 'input_sha256': 'exact', 'reviewer': 'test-only', 'verdict': 'passed',
                   'notes': 'test fixture', 'evidence': [{'path': str(artifact), 'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest()}]}
        path = self.root / 'receipt.json'
        path.write_text(json.dumps(receipt))
        report = {'input_identity': {'sha256': 'exact'}, 'attempts': {}}
        job = {'id': 'review', 'cohort': 'engine', 'evidence_kind': 'test-only'}
        with self.assertRaises(ValueError):
            accept_attestation(path, report, [job])
        job['cohort'] = 'manual'
        accept_attestation(path, report, [job])
        self.assertEqual(report['attempts']['review'][0]['status'], 'passed')
        artifact.write_text('changed')
        with self.assertRaises(ValueError):
            accept_attestation(path, report, [job])


if __name__ == '__main__':
    unittest.main()
