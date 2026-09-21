"""SYNTHETIC schema-grounded analyzer fixtures; NOT live acceptance."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from death_respawn import analyze, load

CLI = Path(__file__).with_name('death_respawn.py')


def fixture():
    """Minimal relevant-field projection of delta=0 capture schema, synthetic."""
    frames = [
        {'type': 'welcome', 'peerId': 1, 'roomId': 'SYNTHETIC'},
        {'type': 'start', 'roundRevision': 1},
        {'type': 'lobby', 'roomId': 'SYNTHETIC', 'roundRevision': 1, 'players': [{'peerId': 1, 'actorId': 0, 'connected': True, 'spectate': False}]},
        {'type': 'snapshot', 'seq': 1, 'state': {'time': 1, 'over': False, 'actors': [{'id': 0, 'health': 100, 'dead': 0}]}},
        {'type': 'events', 'items': [{'id': 1, 'time': 2, 'type': 'death', 'actor': 0}]},
        {'type': 'snapshot', 'seq': 2, 'state': {'time': 2.1, 'over': False, 'actors': [{'id': 0, 'health': 0, 'dead': 1.9}]}},
        {'type': 'events', 'items': [{'id': 2, 'time': 4, 'type': 'spawn', 'actor': 0}]},
        {'type': 'snapshot', 'seq': 3, 'state': {'time': 4.1, 'over': False, 'actors': [{'id': 0, 'health': 100, 'dead': 0}]}}
    ]
    return {'classification': 'synthetic', 'frames': [{'direction': 'server', 'client': 1, 'frame': f} for f in frames]}


class EvidenceTests(unittest.TestCase):
    def test_valid(self):
        r = analyze(fixture())
        self.assertEqual(r['status'], 'established')
        self.assertEqual(r['transitions'][0]['level'], 'event_corroborated')
        self.assertEqual(r['camera_reseeding'], 'unobserved')

    def test_lobby_before_start(self):
        d = fixture(); d['frames'][1], d['frames'][2] = d['frames'][2], d['frames'][1]
        self.assertEqual(analyze(d)['status'], 'established')

    def test_unsupported_transport_and_delta(self):
        for kind in ('snapshot-delta', 'snapshot_delta', 'disconnect'):
            d = fixture(); d['frames'].append({'direction': 'server', 'client': 1, 'frame': {'type': kind}})
            self.assertEqual(analyze(d)['status'], 'invalid')

    def test_snapshot_only(self):
        d = fixture(); d['frames'] = [r for r in d['frames'] if r['frame']['type'] != 'events']
        self.assertEqual(analyze(d)['transitions'][0]['level'], 'snapshot_observed')

    def test_sparse_event_only(self):
        d = fixture(); del d['frames'][5]
        self.assertEqual(analyze(d)['status'], 'incomplete')

    def test_boundaries(self):
        for kind in ('replacement', 'revocation', 'disconnect', 'round', 'welcome', 'results', 'missing', 'other_connection'):
            with self.subTest(kind=kind):
                d = fixture()
                if kind in ('replacement', 'revocation', 'disconnect'):
                    r = copy.deepcopy(d['frames'][2]); p = r['frame']['players'][0]
                    if kind == 'replacement': p['actorId'] = 5
                    elif kind == 'revocation': p['actorId'] = None
                    else: p['connected'] = False
                    d['frames'].insert(6, r)
                elif kind == 'round':
                    r = copy.deepcopy(d['frames'][1]); r['frame']['roundRevision'] = 2; d['frames'].insert(6, r)
                elif kind == 'welcome': d['frames'].insert(6, copy.deepcopy(d['frames'][0]))
                elif kind == 'results': d['frames'].insert(6, {'direction': 'server', 'client': 1, 'frame': {'type': 'results'}})
                elif kind == 'missing': d['frames'][5]['frame']['state']['actors'] = []
                else: d['frames'][-1]['client'] = 2
                self.assertNotEqual(analyze(d)['status'], 'established')

    def test_ambiguous(self):
        d = fixture(); d['frames'][5]['frame']['state']['actors'][0]['dead'] = 0
        self.assertEqual(analyze(d)['status'], 'incomplete')

    def test_duplicate(self):
        d = fixture(); d['frames'].append(copy.deepcopy(d['frames'][-1]))
        self.assertEqual(analyze(d)['counts']['duplicates'], 1)
        self.assertEqual(analyze(d)['status'], 'established')
        d['frames'][-1]['frame']['state']['time'] = 9
        self.assertIn('conflicting duplicate', analyze(d)['errors'][0])

    def test_out_of_order(self):
        d = fixture(); d['frames'][-1]['frame']['seq'] = 0
        self.assertIn('out-of-order', analyze(d)['errors'][0])
        d = fixture(); d['frames'][-1]['frame']['state']['time'] = 1
        self.assertIn('simulation time', analyze(d)['errors'][0])
        d = fixture(); d['frames'][6]['frame']['items'][0]['id'] = 0
        self.assertIn('out-of-order event', analyze(d)['errors'][0])

    def test_no_round_or_mapping(self):
        for index in (0, 1, 2):
            d = fixture(); del d['frames'][index]
            self.assertNotEqual(analyze(d)['status'], 'established')

    def test_malformed(self):
        for d in (None, [], {}, {'frames': [None]}, {'frames': [{}]}):
            self.assertEqual(analyze(d)['status'], 'invalid')
        d = fixture(); d['frames'][5]['frame']['state']['actors'][0]['health'] = True
        self.assertIn('health/dead', analyze(d)['errors'][0])

    def test_events_wrong_time_or_actor(self):
        for field, value in (('actor', 7), ('time', 0)):
            d = fixture(); d['frames'][4]['frame']['items'][0][field] = value
            self.assertEqual(analyze(d)['transitions'][0]['level'], 'snapshot_observed')

    def test_cli_codes_and_immutable_input(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'capture.json'
            good = fixture(); sparse = fixture(); del sparse['frames'][5]
            for content, code in ((json.dumps(good), 0), (json.dumps(sparse), 1), ('{"frames":[', 2), ('{"frames":[],"frames":[]}', 2)):
                p.write_text(content)
                before = p.read_bytes()
                a = subprocess.run([sys.executable, '-B', str(CLI), str(p), '--json'], capture_output=True, text=True)
                b = subprocess.run([sys.executable, '-B', str(CLI), str(p), '--json'], capture_output=True, text=True)
                self.assertEqual(a.returncode, code, a.stdout + a.stderr)
                self.assertEqual(a.stdout, b.stdout)
                self.assertEqual(p.read_bytes(), before)
                self.assertIn('status', json.loads(a.stdout))
            p.write_text(json.dumps(good))
            a = subprocess.run([sys.executable, '-B', str(CLI), str(p)], capture_output=True, text=True)
            self.assertEqual(a.returncode, 0); self.assertIn('ESTABLISHED', a.stdout)
            self.assertEqual(load(Path(tmp) / 'missing')['status'], 'invalid')


if __name__ == '__main__':
    unittest.main()
