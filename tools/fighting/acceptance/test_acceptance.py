import copy
import json
from pathlib import Path
import struct
import tempfile
import unittest

from run import dependencies, judge
from source import IDS, MOVES, accessor, expand_trace, inspect, validate_data, validate_glb


def data_fixture():
    move = dict(name='unit fixture', kind='strike', startup=3, active=2, recovery=8,
                damage=50, hitstun=20, blockstun=10, hitstop=4, level='mid',
                animation='stand_l', effect='unit:stand_l', meter_cost=0,
                hitboxes=[dict(x=0, y=0, w=1, h=1, **{'from': 3, 'to': 4})], cancels=[])
    operators = []
    for oid in IDS:
        moves = {mid: copy.deepcopy(move) for mid in MOVES}
        moves['super']['meter_cost'] = 1000
        operators.append(dict(id=oid, name=oid, archetype='unit', resource={},
                              stats=dict(hp=1000, walk_speed=50, weight=100, jump_velocity=100),
                              moves=moves, combos=[dict(name=str(i), inputs=['stand_l', 'stand_m']) for i in range(3)]))
    rules = dict(version=1, tick_rate=60, units_per_meter=1000, round_seconds=99,
                 rounds_to_win=2, buffer_frames=6, throw_tech_frames=10, stage_half_width=8000)
    return dict(version=1, operators=operators), rules


def glb_fixture(weight=1.0):
    """Tiny binary parser fixture, never a production/test fallback asset."""
    binary = bytearray()
    doc = dict(asset={'version': '2.0'}, buffers=[], bufferViews=[], accessors=[],
               nodes=[{'name': 'bone'}, {'name': 'body', 'mesh': 0, 'skin': 0}],
               skins=[{'joints': [0]}], meshes=[], animations=[])

    def add(values, kind, fmt='f', component=5126):
        offset = len(binary)
        for row in values:
            binary.extend(struct.pack('<' + fmt * len(row), *row))
        size = len(binary) - offset
        binary.extend(b'\0' * (-len(binary) % 4))
        view = len(doc['bufferViews'])
        doc['bufferViews'].append(dict(buffer=0, byteOffset=offset, byteLength=size))
        doc['accessors'].append(dict(bufferView=view, componentType=component, count=len(values), type=kind))
        return len(doc['accessors']) - 1

    position = add([(0., 0., 0.)], 'VEC3')
    weights = add([(weight, 0., 0., 0.)], 'VEC4')
    joints = add([(0, 0, 0, 0)], 'VEC4', 'H', 5123)
    times = add([(0.,), (1.,)], 'SCALAR')
    rotations = add([(0., 0., 0., 1.), (0., .2, 0., .98)], 'VEC4')
    doc['meshes'] = [{'primitives': [{'attributes': {'POSITION': position, 'WEIGHTS_0': weights, 'JOINTS_0': joints}}]}]
    doc['animations'] = [dict(name='idle', samplers=[dict(input=times, output=rotations)],
                              channels=[dict(sampler=0, target=dict(node=0, path='rotation'))])]
    doc['buffers'] = [{'byteLength': len(binary)}]
    text = json.dumps(doc).encode()
    text += b' ' * (-len(text) % 4)
    chunks = struct.pack('<II', len(text), 0x4e4f534a) + text + struct.pack('<II', len(binary), 0x004e4942) + binary
    return struct.pack('<4sII', b'glTF', 2, 12 + len(chunks)) + chunks


class DataTests(unittest.TestCase):
    def test_complete_contract_fixture(self):
        self.assertEqual(validate_data(*data_fixture())['required_move_families'], 135)

    def test_roster_duplicate_and_missing_family_rejected(self):
        roster, rules = data_fixture()
        roster['operators'][-1]['id'] = 'chatgpt'
        with self.assertRaisesRegex(ValueError, 'nine'):
            validate_data(roster, rules)
        roster, rules = data_fixture()
        del roster['operators'][0]['moves']['air_h']
        with self.assertRaisesRegex(ValueError, 'fifteen'):
            validate_data(roster, rules)

    def test_rule_drift_and_super_cost_rejected(self):
        roster, rules = data_fixture()
        rules['buffer_frames'] = 7
        with self.assertRaisesRegex(ValueError, 'buffer_frames'):
            validate_data(roster, rules)
        rules['buffer_frames'] = 6
        roster['operators'][0]['moves']['super']['meter_cost'] = 0
        with self.assertRaisesRegex(ValueError, 'super cost'):
            validate_data(roster, rules)

    def test_nan_unknown_mechanic_cancel_and_box_rejected(self):
        mutations = [({'damage': float('nan')}, 'non-finite'), ({'kind': 'fake'}, 'kind'),
                     ({'cancels': [{'to': 'missing', 'from': 1, 'until': 2, 'on': ['hit']}]}, 'cancel'),
                     ({'hitboxes': [{'x': 0, 'y': 0, 'w': 0, 'h': 1, 'from': 0, 'to': 1}]}, 'box')]
        for mutation, message in mutations:
            with self.subTest(message=message):
                roster, rules = data_fixture()
                roster['operators'][0]['moves']['stand_l'].update(mutation)
                with self.assertRaisesRegex(ValueError, message):
                    validate_data(roster, rules)

    def test_missing_dependencies_are_deferred_not_passed(self):
        with tempfile.TemporaryDirectory() as directory:
            result = inspect(directory)
            self.assertEqual(result['status'], 'deferred')
            self.assertEqual(len(result['missing']), 11)
            self.assertFalse(result['failures'])


class BinaryTests(unittest.TestCase):
    def check_glb(self, raw):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'unit.glb'
            path.write_bytes(raw)
            return validate_glb(path, ['idle'])

    def test_actual_weighted_bin_and_numeric_curves(self):
        result = self.check_glb(glb_fixture())
        self.assertEqual(result['weighted_vertices'], 1)
        self.assertEqual(len(result['curve_sha256']['idle']), 64)
        self.assertEqual(result['art_acceptance'], 'unrun')

    def test_binary_nan_and_zero_weight_fail(self):
        for weight in [float('nan'), 0., .5]:
            with self.subTest(weight=weight), self.assertRaises(ValueError):
                self.check_glb(glb_fixture(weight))

    def test_truncated_glb_fails(self):
        with self.assertRaisesRegex(ValueError, 'length'):
            self.check_glb(glb_fixture()[:-1])

    def test_accessor_cannot_read_beyond_view(self):
        doc = {'accessors': [dict(bufferView=0, count=2, componentType=5126, type='VEC4')],
               'bufferViews': [dict(buffer=0, byteLength=16)]}
        with self.assertRaisesRegex(ValueError, 'bounds'):
            accessor(doc, bytes(64), 0)


class EvidenceTests(unittest.TestCase):
    def test_marker_absence_and_substring_refused(self):
        for output in ['', 'prefix OK suffix']:
            result = judge({'status': 'passed'}, output, 'OK', Path('/nonexistent'))
            self.assertEqual(result['failure_reason'], 'missing-exact-success-marker')

    def test_marker_alone_and_placeholder_report_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / 'native.json'
            self.assertEqual(judge({'status': 'passed'}, 'OK\n', 'OK', report)['failure_reason'], 'missing-native-report')
            for data in [{'status': 'passed'}, {'status': 'passed', 'checks': ['unit'], 'unrun': ['critical']}]:
                report.write_text(json.dumps(data))
                self.assertEqual(judge({'status': 'passed'}, 'OK\n', 'OK', report)['failure_reason'], 'incomplete-native-report')

    def test_exit_failure_cannot_be_overridden_by_marker(self):
        result = judge({'status': 'failed', 'failure_reason': 'nonzero-exit'}, 'OK\n', 'OK', Path('/nonexistent'))
        self.assertEqual(result['failure_reason'], 'nonzero-exit')

    def test_real_report_required(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / 'native.json'
            report.write_text(json.dumps({'status': 'passed', 'checks': [{'id': 'measured'}], 'unrun': [], 'failures': []}))
            self.assertEqual(judge({'status': 'passed'}, 'OK\n', 'OK', report)['status'], 'passed')

    def test_dependency_inventory_is_exact(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'present').touch()
            self.assertEqual(dependencies(root, {'requires': ['present', 'absent']}), ['absent'])


class SparseInputTests(unittest.TestCase):
    def test_omission_releases_and_duration_does_not_repeat_edge(self):
        combo = {'setup_inputs': [dict(tick=0, axis_x=-1, axis_y=0, held=0, pressed=0, duration=36)],
                 'inputs': [dict(tick=36, axis_x=-1, axis_y=-1, held=1, pressed=1, duration=2),
                            dict(tick=40, axis_x=1, axis_y=0, held=8, pressed=8)]}
        trace = expand_trace(combo, -1)
        self.assertEqual(len(trace), 41)
        self.assertTrue(all(c['axis_x'] == 1 for c in trace[:36]))
        self.assertEqual(trace[36], dict(axis_x=1, axis_y=-1, held=1, pressed=1))
        self.assertEqual(trace[37], dict(axis_x=1, axis_y=-1, held=1, pressed=0))
        self.assertEqual(trace[38], dict(axis_x=0, axis_y=0, held=0, pressed=0))
        self.assertEqual(trace[40]['axis_x'], -1)

    def test_overlap_and_impossible_edge_refused(self):
        sample = dict(tick=0, axis_x=0, axis_y=0, held=1, pressed=1, duration=2)
        with self.assertRaisesRegex(ValueError, 'overlapping'):
            expand_trace({'inputs': [sample, {**sample, 'tick': 1}]})
        with self.assertRaisesRegex(ValueError, 'masks'):
            expand_trace({'inputs': [{**sample, 'held': 0}]})


if __name__ == '__main__':
    unittest.main()
