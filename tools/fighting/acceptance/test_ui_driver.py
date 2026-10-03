"""Negative receipts/process/data tests only; no Godot, X11 or virtual devices."""
import copy
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib
from unittest.mock import patch

from ui_driver import REQUIRED_LABELS, STAGES, post_exit, validate_native
from ui_os_bridge import abs_setup, device_setup
from ui_source import audit


def process_result():
    return {'status': 'passed', 'exit_code': 0, 'failure_reason': None,
            'cleanup': {'signalled': [], 'remaining': []}}


def unit_report(directory):
    """Schema fixture, explicitly not an execution fallback or shipping asset."""
    checks = [{'label': label, 'passed': True} for label in REQUIRED_LABELS if label != 'disconnect releases BOTH actors']
    checks += [{'label': 'disconnect releases BOTH actors', 'passed': True, 'measured': {'disconnected_actor': actor}} for actor in (0, 1)]
    pairs = [('meta', 'mistral'), ('chatgpt', 'claude'), ('grok', 'gemini'), ('deepseek', 'kimi')]
    cases = []
    def chunk(kind, payload):
        return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind+payload)&0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(b'\0\xff\0\0\xff')) + chunk(b'IEND', b'')
    for stage, pair in zip(STAGES, pairs):
        for scale, profile in ((1., 'wide100'), (1.5, 'compact150')):
            name = f'{stage}-{profile}.png'
            (directory / name).write_bytes(png)
            cases.append({'id': f'{stage}-{profile}/neutral', 'stage': stage, 'scale': scale,
                          'operators': ['mistral', 'qwen'] if stage == STAGES[-1] and scale == 1.5 else list(pair),
                          'image': name, 'tick': 100, 'render_frame': 200, 'utc': 'unit-fixture',
                          'controls': [{'rect': [0, 0, 10, 10]}], 'window': [760, 520] if scale == 1.5 else [1280, 800],
                          'fullscreen': scale == 1., 'camera': {'inside': True, 'poses': [1, 2]}})
    return {'status': 'passed', 'executed': True, 'failures': [], 'unrun': [], 'checks': checks,
            'cases': cases, 'replay_frames': 40, 'contacts': [{'event': {'actor': actor, 'type': kind}}
               for actor in (0, 1) for kind in ('throw_start', 'throw_hit', 'throw_tech')],
            'camera_samples': [{'inside': True, 'sampling_usec': 10} for _ in range(51)],
            'not_claimed': ['physical controller unplug']}


class PostExitTests(unittest.TestCase):
    def test_late_error_after_success_marker_is_fatal(self):
        for error in ('SCRIPT ERROR: late callback', 'ERROR: resource load failed',
                      'WARNING: ObjectDB instances leaked at exit', 'resources still in use at exit',
                      'RID allocations leaked at exit'):
            with self.subTest(error=error), self.assertRaises(ValueError):
                post_exit(process_result(), 'FIGHTING_UI_JOURNEY_OK\n' + error)

    def test_signalled_child_is_failure_even_if_no_survivor(self):
        result = process_result()
        result['cleanup']['signalled'] = [123]
        with self.assertRaisesRegex(ValueError, 'leaked'):
            post_exit(result, '')

    def test_exit_and_cleanup_inventory_required(self):
        for delta in ({'exit_code': 1}, {'cleanup': {}}, {'failure_reason': 'timeout'}):
            with self.subTest(delta=delta), self.assertRaises(ValueError):
                post_exit({**process_result(), **delta}, '')


class UiEvidenceTests(unittest.TestCase):
    def test_full_schema_and_missing_observations(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            report = unit_report(directory)
            self.assertEqual(validate_native(report, directory)['stage_layouts'], 8)
            mutations = [lambda r: r['cases'].pop(), lambda r: r.update(executed=False),
                         lambda r: r.update(unrun=['focus']), lambda r: r.update(replay_frames=0),
                         lambda r: r['checks'].pop(), lambda r: r['contacts'].pop(),
                         lambda r: r['camera_samples'][0].update(inside=False),
                         lambda r: r['cases'][0].update(fullscreen=False)]
            for mutation in mutations:
                changed = copy.deepcopy(report)
                mutation(changed)
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    validate_native(changed, directory)

    def test_capture_and_physical_claim_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            report = unit_report(directory)
            (directory / report['cases'][0]['image']).unlink()
            with self.assertRaisesRegex(ValueError, 'PNG'):
                validate_native(report, directory)
            report = unit_report(directory)
            report['not_claimed'] = []
            with self.assertRaisesRegex(ValueError, 'physical'):
                validate_native(report, directory)

    def test_truncated_capture_cannot_pass_on_png_header(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            report = unit_report(directory)
            path = directory / report['cases'][0]['image']
            path.write_bytes(path.read_bytes()[:24])
            with self.assertRaisesRegex(ValueError, 'truncated PNG'):
                validate_native(report, directory)

    def test_no_native_work_without_matching_grant(self):
        from argparse import Namespace
        from ui_driver import native
        for grant in (None, 'ROBOT-ASSET-PRODUCTION-20261002-D'):
            with patch('ui_driver.finish.run_bounded') as launch:
                with self.assertRaises(ValueError):
                    native(Namespace(heavy_grant=grant))
                launch.assert_not_called()

    def test_receipt_cannot_promote_unanchored_execution(self):
        from argparse import Namespace
        from ui_driver import receipt
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'producer.json'
            path.write_text(json.dumps({'status': 'passed', 'executed': True}))
            with self.assertRaisesRegex(ValueError, 'not bound'):
                receipt(Namespace(producer=path))


class SourceContractTests(unittest.TestCase):
    def test_linux_uinput_layout_without_opening_device(self):
        self.assertEqual(len(device_setup('Unit-pad')), 92)
        self.assertEqual(len(abs_setup(0, -32768, 32767)), 28)
        with self.assertRaises(ValueError):
            device_setup('x' * 80)

    def test_production_ui_fixture_remains_input_driven(self):
        root = Path(__file__).resolve().parents[3]
        result = audit(root)
        self.assertEqual(len(result['exports']), 9)
        self.assertEqual(result['native_execution'], 'pending')


if __name__ == '__main__':
    unittest.main()
