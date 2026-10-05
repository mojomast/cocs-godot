"""Synthetic-fixture tests for the Parallax tangent record classifier.

Every category is built from scratch so the classifier is pinned against
hand-computed expectations rather than against the census it is meant to
explain. One fixture reproduces the known sixteen-singular-glyph shape and one
reproduces a mirrored-UV record that is spec-valid but derivative-disagreeing --
the two shapes whose distinction the whole blocker rests on.

No engine, no artifact, no network. GLB bytes are assembled in memory.
"""
import json
import math
import struct
import unittest
import zlib

import classify_records as classify
from classify_records import (SPEC_INVALID, SPEC_VALID_DISAGREEING, UNAFFECTED,
                              FULL_RANK, UV_RANK_FAILURE, ZERO_AREA)

UNIT_Z = (0., 0., 1.)
UNIT_X = (1., 0., 0.)
SQUARE_UV = ((0., 0.), (1., 0.), (0., 1.))
SQUARE_P = ((0., 0., 0.), (1., 0., 0.), (0., 1., 0.))
COLLINEAR_P = ((0., 0., 0.), (1., 0., 0.), (2., 0., 0.))
COLLINEAR_UV = ((0., 0.), (1., 0.), (2., 0.))
# Non-unit but non-parallel N with a nonzero z, so dP/dv stays observable.
NONORTHOGONAL_N = (0.6, 0., 0.8)
SHAPES = {1: 'SCALAR', 2: 'VEC2', 3: 'VEC3', 4: 'VEC4'}


def png_bytes(width, height, pixels):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += pixels[y * width * 4:(y + 1) * width * 4]

    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))

    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(raw)))
            + chunk(b'IEND', b''))


def face(positions, normal, uvs, tangents):
    return [(positions[i], normal, uvs[i], tangents[i]) for i in range(3)]


def agreeing_face(normal=UNIT_Z, tangent=(1., 0., 0., 1.)):
    """Full-rank square UV on a +Z plane: du=+X, dv=+Y, derived sign +1."""
    return face(SQUARE_P, normal, SQUARE_UV, [tangent] * 3)


def mirrored_uv_face(tangent=(1., 0., 0., 1.)):
    """Same frame and geometry, mirrored UV map: derived sign -1, stored +1."""
    return face(SQUARE_P, UNIT_Z, ((0., 0.), (0., 1.), (1., 0.)), [tangent] * 3)


def uv_rank_failure_face():
    """Nonzero area, zero UV Jacobian, and a perfectly valid supplied frame."""
    return face(SQUARE_P, UNIT_Z, ((0., 0.), (1., 0.), (1., 0.)), [(1., 0., 0., 1.)] * 3)


def zero_area_face():
    return face(COLLINEAR_P, UNIT_Z, COLLINEAR_UV, [(1., 0., 0., 1.)] * 3)


def rank_one_glyph_face():
    """The reviewed glyph-side shape: nonzero area, UV Jacobian zero, N parallel T."""
    return face(((0., 0., 0.), (0.05, 0., 0.), (0.05, 0.02, 0.)), (-1., 0., 0.),
                ((0., 0.), (0., 0.), (0.04, 0.02)), [(1., 0., 0., -1.)] * 3)


SURFACE_FACES = [
    agreeing_face(),
    mirrored_uv_face(),
    agreeing_face(NONORTHOGONAL_N),
    uv_rank_failure_face(),
    face(SQUARE_P, UNIT_Z, SQUARE_UV, [(2., 0., 0., 1.)] * 3),
    face(SQUARE_P, UNIT_Z, SQUARE_UV, [(1., 0., 0., 0.5)] * 3),
    face(SQUARE_P, (0., 0., 2.), SQUARE_UV, [(1., 0., 0., 1.)] * 3),
] + [rank_one_glyph_face() for _ in range(16)]
UNTEXTURED_FACES = [agreeing_face(), zero_area_face()]
GLYPH_FIRST_VERTEX = 3 * (len(SURFACE_FACES) - 16)
UNTEXTURED_FIRST_VERTEX = 3 * len(SURFACE_FACES)


def synthetic_glb(groups):
    """Build a minimal embedded GLB. `groups` is [(role, textured, faces)].

    Each group becomes its own node, mesh and primitive, and corners are never
    shared, so every face's classification is independent of every other face's.
    """
    blob, views, accessors = bytearray(), [], []
    materials, textures, samplers, images = [], [], [], []
    nodes, meshes, primitives = [], [], []

    def store(data):
        while len(blob) % 4:
            blob.append(0)
        offset = len(blob)
        blob.extend(data)
        views.append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(data)})
        return len(views) - 1

    def floats(values, dimensions, ranged=False):
        packed = b''.join(struct.pack('<' + 'f' * dimensions, *value) for value in values)
        accessor = {'bufferView': store(packed), 'componentType': 5126,
                    'count': len(values), 'type': SHAPES[dimensions]}
        if ranged:
            accessor['min'] = [min(value[k] for value in values) for k in range(dimensions)]
            accessor['max'] = [max(value[k] for value in values) for k in range(dimensions)]
        accessors.append(accessor)
        return len(accessors) - 1

    def indices(values):
        accessors.append({'bufferView': store(b''.join(struct.pack('<I', v) for v in values)),
                          'componentType': 5125, 'count': len(values), 'type': 'SCALAR'})
        return len(accessors) - 1

    samplers.append({'magFilter': 9729, 'minFilter': 9987})
    images.append({'bufferView': store(png_bytes(2, 2, bytes(16))), 'mimeType': 'image/png',
                   'name': 'synthetic-normal'})
    textures.append({'sampler': 0, 'source': 0})
    for group, (role, textured, faces) in enumerate(groups):
        material = {'name': role}
        if textured:
            material['normalTexture'] = {'index': 0, 'scale': 0.5}
        materials.append(material)
        corners = [corner for one in faces for corner in one]
        primitives.append({
            'attributes': {'POSITION': floats([c[0] for c in corners], 3, ranged=True),
                           'NORMAL': floats([c[1] for c in corners], 3),
                           'TEXCOORD_0': floats([c[2] for c in corners], 2),
                           'TANGENT': floats([c[3] for c in corners], 4)},
            'indices': indices(list(range(len(corners)))),
            'material': len(materials) - 1})
        nodes.append({'mesh': group, 'name': 'synthetic.node.%02d' % group})
        meshes.append({'name': 'synthetic.mesh.%02d' % group, 'primitives': [primitives[-1]]})
    doc = {'asset': {'version': '2.0'}, 'scene': 0,
           'scenes': [{'nodes': list(range(len(nodes)))}], 'nodes': nodes, 'meshes': meshes,
           'materials': materials, 'textures': textures, 'samplers': samplers, 'images': images,
           'accessors': accessors, 'bufferViews': views,
           'buffers': [{'byteLength': len(blob)}]}
    header = json.dumps(doc, separators=(',', ':'), allow_nan=False).encode()
    header += b' ' * (-len(header) % 4)
    return (struct.pack('<III', 0x46546c67, 2, 28 + len(header) + len(blob))
            + struct.pack('<I4s', len(header), b'JSON') + header
            + struct.pack('<I4s', len(blob), b'BIN\0') + bytes(blob))


def corners_of(face_corners):
    return [{'P': p, 'N': n, 'UV': uv, 'T': t, 'vertex': i, 'corner': i}
            for i, (p, n, uv, t) in enumerate(face_corners)]


class SpecVerdict(unittest.TestCase):
    def test_spec_invalid_reasons_are_normative_or_frame_degeneracy(self):
        self.assertEqual(classify.spec_verdict(UNIT_Z, (0., 0., 0., 1.)),
                         ('zeroTangent', 'nonUnitTangent', 'degenerateFrame'))
        self.assertEqual(classify.spec_verdict(UNIT_Z, (2., 0., 0., 1.)), ('nonUnitTangent',))
        self.assertEqual(classify.spec_verdict(UNIT_Z, UNIT_X + (0.5,)), ('wNotSign',))
        self.assertEqual(classify.spec_verdict((0., 0., 2.), UNIT_X + (1.,)), ('nonUnitNormal',))
        self.assertEqual(classify.spec_verdict((-1., 0., 0.), (1., 0., 0., -1.)), ('degenerateFrame',))
        self.assertEqual(classify.spec_verdict(UNIT_Z, (math.nan, 0., 0., 1.)), ('nonFiniteRecord',))

    def test_nonorthogonality_is_an_advisory_not_a_spec_failure(self):
        """glTF 2.0 §3.7.2.1 requires unit XYZ and w = ±1. It does not require
        dot(N,T) = 0 per record, and mirroring legitimately opposes a basis."""
        self.assertEqual(classify.spec_verdict(NONORTHOGONAL_N, (1., 0., 0., 1.)), ())
        self.assertEqual(classify.record_advisories(NONORTHOGONAL_N, (1., 0., 0., 1.), True),
                         ('nonorthogonalNT',))
        self.assertEqual(classify.record_advisories(UNIT_Z, (1., 0., 0., 1.), False),
                         ('roleWithoutNormalTexture',))


class FaceVerdict(unittest.TestCase):
    def test_full_rank_uv_rank_failure_and_zero_area_are_distinct(self):
        state, derivative = classify.face_verdict(corners_of(agreeing_face()))
        self.assertEqual(state, FULL_RANK)
        self.assertEqual((derivative['area'], derivative['uvJacobian']), (0.5, 1.))
        state, _ = classify.face_verdict(corners_of(uv_rank_failure_face()))
        self.assertEqual(state, UV_RANK_FAILURE)
        state, _ = classify.face_verdict(corners_of(rank_one_glyph_face()))
        self.assertEqual(state, UV_RANK_FAILURE)
        state, _ = classify.face_verdict(corners_of(zero_area_face()))
        self.assertEqual(state, ZERO_AREA)

    def test_derived_sign_follows_the_exported_uv_basis(self):
        _, derivative = classify.face_verdict(corners_of(agreeing_face()))
        self.assertEqual(derivative['wFromUV'], [1, 1, 1])
        self.assertEqual((derivative['du'], derivative['dv']), ((1., 0., 0.), (0., 1., 0.)))
        _, mirrored = classify.face_verdict(corners_of(mirrored_uv_face()))
        self.assertEqual(mirrored['wFromUV'], [-1, -1, -1])

    def test_corner_disagreements_separate_the_three_raw_metrics(self):
        _, mirrored = classify.face_verdict(corners_of(mirrored_uv_face()))
        corner = corners_of(mirrored_uv_face())[0]
        # Stored w=+1 against a derived -1 is the only disagreement here; the
        # mirrored dP/du and dP/dv are perpendicular to the stored frame, so the
        # other two metrics do not fire and must not be inferred from the first.
        self.assertEqual(classify.corner_disagreements(corner, mirrored, -1), 1)
        self.assertEqual(classify.corner_disagreements(corner, mirrored, 1), 0)
        _, agreeing = classify.face_verdict(corners_of(agreeing_face()))
        flipped = dict(corners_of(agreeing_face())[0])
        flipped['T'] = (1., 0., 0., -1.)
        self.assertEqual(classify.corner_disagreements(flipped, agreeing, 1), 1 | 4)
        backwards = dict(corners_of(agreeing_face())[0])
        backwards['T'] = (-1., 0., 0., 1.)
        self.assertEqual(classify.corner_disagreements(backwards, agreeing, 1), 2 | 4)


class SyntheticGlbClassification(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = synthetic_glb([('synthetic.surface', True, SURFACE_FACES),
                                 ('synthetic.untextured', False, UNTEXTURED_FACES)])
        cls.result = classify.classify(cls.raw, 'synthetic', include_records=True)
        cls.rows = {}
        for row in cls.result['recordDetails']:
            cls.rows[(row['mesh'], row['vertex'])] = row

    def test_counts_per_category(self):
        categories = self.result['categories']
        self.assertEqual(categories[SPEC_INVALID], 16 * 3 + 3 + 3 + 3)
        self.assertEqual(categories[SPEC_VALID_DISAGREEING], 3)
        self.assertEqual(categories[UNAFFECTED], 9 + 3 + 3)
        self.assertEqual(sum(categories.values()), self.result['records'])

    def test_face_states(self):
        self.assertEqual(self.result['faceStates'],
                         {FULL_RANK: 7, UV_RANK_FAILURE: 17, ZERO_AREA: 1})
        self.assertEqual(sum(self.result['faceStates'].values()), self.result['faces'])
        self.assertEqual(self.result['records'], 3 * self.result['faces'])

    def test_agreeing_record_is_unaffected(self):
        row = self.by_vertex(0, 0, 0)
        self.assertEqual((row['category'], row['reason']), (UNAFFECTED, 'derivativeAgreeing'))
        self.assertEqual(row['spec'], ())

    def test_mirrored_uv_record_is_spec_valid_but_derivative_disagreeing(self):
        """The distinction the blocker turns on: a mirrored UV map produces a
        legitimate opposite-handed basis, so this is not a spec violation."""
        row = self.by_vertex(0, 1, 0)
        self.assertEqual(row['spec'], ())
        self.assertEqual(row['category'], SPEC_VALID_DISAGREEING)
        self.assertEqual(row['reason'], 'derivative:wSignDisagrees')
        self.assertEqual(row['advisories'], ())

    def test_nonorthogonal_record_is_not_spec_invalid(self):
        row = self.by_vertex(0, 2, 0)
        self.assertEqual(row['spec'], ())
        self.assertEqual(row['category'], UNAFFECTED)
        self.assertEqual(row['advisories'], ('nonorthogonalNT',))
        self.assertEqual(classify.record_category((), 0, 0, 0, 1),
                         (UNAFFECTED, 'derivativeAgreeing'))

    def test_uv_rank_failure_and_zero_area_records_are_unaffected_not_invalid(self):
        self.assertEqual(self.by_vertex(0, 3, 0)['reason'], UV_RANK_FAILURE + 'Only')
        self.assertEqual(self.by_vertex(1, 1, 0)['reason'], ZERO_AREA + 'Only')

    def test_sixteen_singular_glyph_shape(self):
        for face_index in range(len(SURFACE_FACES) - 16, len(SURFACE_FACES)):
            for corner_index in range(3):
                row = self.by_vertex(0, face_index, corner_index)
                self.assertEqual(row['spec'], ('degenerateFrame',))
                self.assertEqual(row['category'], SPEC_INVALID)
                self.assertEqual(row['T'][3], -1.0)
                self.assertEqual(list(row['N']), [-1.0, 0.0, 0.0])
                self.assertIn('nonorthogonalNT', row['advisories'])
        self.assertEqual(self.result['faceStates'][UV_RANK_FAILURE], 17)
        self.assertEqual(GLYPH_FIRST_VERTEX, 3 * 7)

    def test_remaining_spec_invalid_records(self):
        for face_index, expected in ((4, ('nonUnitTangent',)), (5, ('wNotSign',)),
                                     (6, ('nonUnitNormal',))):
            for corner_index in range(3):
                row = self.by_vertex(0, face_index, corner_index)
                self.assertEqual(row['spec'], expected)
                self.assertEqual(row['category'], SPEC_INVALID)

    def test_zero_tangent_shape_is_spec_invalid(self):
        glb = synthetic_glb([('synthetic.surface', True, [
            face(SQUARE_P, UNIT_Z, SQUARE_UV, [(0., 0., 0., 1.)] * 3)])])
        result = classify.classify(glb, 'zero')
        self.assertEqual(result['categories'][SPEC_INVALID], 3)
        self.assertEqual(result['categoryReasons'],
                         {'specInvalid|spec:zeroTangent+nonUnitTangent+degenerateFrame': 3})

    def test_untextured_role_is_flagged_not_invalid(self):
        row = self.by_vertex(1, 0, 0)
        self.assertEqual(row['spec'], ())
        self.assertIn('roleWithoutNormalTexture', row['advisories'])
        self.assertFalse(self.result['roles']['synthetic.untextured']['normalTexture'])
        self.assertTrue(self.result['roles']['synthetic.surface']['normalTexture'])

    def test_stricter_reading_adds_only_uv_rank_records(self):
        stricter = self.result['stricterReadingIncludingUVRank']['records']
        self.assertEqual(stricter, self.result['categories'][SPEC_INVALID] + 3)

    def test_reconciliation_with_census_on_the_same_bytes(self):
        """The classifier must reproduce census.py's own inventory, otherwise its
        thresholds have drifted from the census it claims to explain."""
        committed = classify.census_inventory(self.raw)
        reconciled = classify.reconcile_with_census(self.raw, committed, 'synthetic')
        self.assertTrue(reconciled['reproducedCensusInventory'])
        self.assertEqual(committed['faces'], 25)
        self.assertEqual(committed['zeroT'], 0)
        self.assertEqual(committed['nonunitT'], 3)
        self.assertEqual(committed['nonunitN'], 3)
        # census counts per supplied record, so 16 glyph faces contribute 48.
        self.assertEqual(committed['parallelNT'], 48)
        self.assertEqual(committed['nonorthogonalNT'], 48 + 3)
        self.assertEqual(committed['definedUVFaces'], 7)
        self.assertEqual(committed['undefinedUVFaces'], 18)
        # mirrored UV face (w=+1 vs derived -1) plus the w=0.5 face.
        self.assertEqual(committed['UVHandDisagreeCorners'], 6)
        self.assertEqual(committed['storedTangentOpposesDU'], 0)
        self.assertEqual(committed['storedBinormalOpposesDV'], 0)

    def test_drift_is_rejected_rather_than_silently_reclassified(self):
        committed = dict(classify.census_inventory(self.raw))
        committed['parallelNT'] = 99
        with self.assertRaisesRegex(ValueError, 'census drift'):
            classify.reconcile_with_census(self.raw, committed, 'synthetic')

    def test_classification_is_deterministic(self):
        again = classify.classify(self.raw, 'synthetic', include_records=True)
        self.assertEqual(json.dumps(again, sort_keys=True), json.dumps(self.result, sort_keys=True))

    def test_samples_are_bounded_and_present_per_category(self):
        for role, bucket in self.result['roles'].items():
            self.assertTrue(bucket['samples'])
            for category, samples in bucket['samples'].items():
                self.assertTrue(samples)
                self.assertLessEqual(len(samples), classify.SAMPLE_LIMIT)
                for sample in samples:
                    self.assertEqual(sample['role'], role)
                    self.assertEqual(sample['reason'],
                                     self.rows[(sample['mesh'], sample['vertex'])]['reason'])
        self.assertIn('synthetic.surface|disagreeing', self.result['faceSamples'])
        self.assertEqual(self.result['storedTangentOpposesDUCorners'], [])
        self.assertEqual(self.result['storedTangentOpposesDUCornersTruncated'], 0)

    def test_record_diff_reports_exactly_the_changed_records(self):
        glb = classify.EmbeddedGlb(self.raw)
        accessor = glb.doc['meshes'][0]['primitives'][0]['attributes']['TANGENT']
        view = glb.doc['bufferViews'][glb.doc['accessors'][accessor]['bufferView']]
        binary = 28 + struct.unpack_from('<I', self.raw, 12)[0]
        flipped = bytearray(self.raw)
        offset = binary + view['byteOffset'] + 12
        self.assertEqual(struct.unpack_from('<f', flipped, offset)[0], 1.0)
        struct.pack_into('<f', flipped, offset, -1.0)
        diff = classify.tangent_record_diff(self.raw, bytes(flipped))
        self.assertEqual((diff['records'], diff['changedRecords'], diff['unchangedRecords']),
                         (75, 1, 74))
        self.assertEqual(diff['changed'][0]['role'], 'synthetic.surface')
        self.assertTrue(diff['changed'][0]['wChanged'])
        self.assertFalse(diff['changed'][0]['afterNonUnitT'])

    def test_record_diff_rejects_a_changed_record_inventory(self):
        other = synthetic_glb([('synthetic.surface', True, [agreeing_face()])])
        with self.assertRaisesRegex(ValueError, 'inventory changed'):
            classify.tangent_record_diff(self.raw, other)

    def test_scene_part_name_collision_is_rejected(self):
        glb = classify.EmbeddedGlb(self.raw)
        glb.doc['nodes'][1]['name'] = glb.doc['nodes'][0]['name'].replace('.', '_')
        with self.assertRaisesRegex(ValueError, 'collision'):
            classify.scene_parts(glb)

    def by_vertex(self, mesh, face_index, corner_index):
        return self.rows[(mesh, face_index * 3 + corner_index)]


PINNED = {}
try:
    PINNED['X'] = classify.SOURCE.read_bytes()
    PINNED['AA'] = classify.derive_aa_from_x(PINNED['X'])[0]
    PINNED['AC'] = classify.AC_GLB.read_bytes()
except OSError:                                        # pragma: no cover
    PINNED = {}


@unittest.skipUnless(PINNED, 'pinned X/AA/AC GLB bytes are unavailable in this checkout')
class PinnedArtifacts(unittest.TestCase):
    """The three real artifacts, so the counts in
    port/finish/map-variety/PARALLAX_TANGENT_CLASSIFICATION_20261005.md are pinned."""

    @classmethod
    def setUpClass(cls):
        cls.results = {label: classify.classify(raw, label) for label, raw in PINNED.items()}

    def test_spec_invalid_counts_are_seventeen_sixteen_zero(self):
        self.assertEqual(self.results['X']['categories'][SPEC_INVALID], 17)
        self.assertEqual(self.results['AA']['categories'][SPEC_INVALID], 16)
        self.assertEqual(self.results['AC']['categories'][SPEC_INVALID], 0)
        self.assertEqual(self.results['AC']['categories'][SPEC_VALID_DISAGREEING], 314178)
        self.assertEqual(self.results['AC']['categories'][UNAFFECTED], 4887)
        for result in self.results.values():
            self.assertEqual(result['records'], 319065)
            self.assertEqual(result['faces'], 155553)
            self.assertEqual(result['faceStates'],
                             {FULL_RANK: 150686, UV_RANK_FAILURE: 4811, ZERO_AREA: 56})

    def test_raw_metrics_reproduce_the_committed_census(self):
        committed = json.loads(classify.HERE.joinpath('source-census.json').read_text())
        for label in ('X', 'AA'):
            self.assertEqual(
                classify.reconcile_with_census(PINNED[label], committed[label]['uniqueVertexRecords'],
                                              label)['reproducedCensusInventory'], True)
        self.assertEqual(self.results['X']['cornerDisagreements'],
                         {'wSignDisagrees': 452053, 'storedTangentOpposesDU': 5,
                          'storedBinormalOpposesDV': 452050})
        self.assertEqual(self.results['AC']['cornerDisagreements'],
                         {'wSignDisagrees': 452050, 'storedTangentOpposesDU': 5,
                          'storedBinormalOpposesDV': 452048})

    def test_nonorthogonality_is_only_an_advisory(self):
        total = sum(count for key, count in self.results['AC']['advisories'].items()
                    if key.endswith('|nonorthogonalNT'))
        self.assertEqual(total, 4729)
        self.assertEqual(self.results['X']['categories'][SPEC_INVALID], 17)
        self.assertEqual(len(self.results['AC']['storedTangentOpposesDUCorners']), 5)

    def test_record_diffs_match_the_reviewed_bin_boundaries(self):
        pairs = {('X', 'AA'): 3, ('AA', 'AC'): 16, ('X', 'AC'): 19}
        for (before, after), expected in pairs.items():
            diff = classify.tangent_record_diff(PINNED[before], PINNED[after])
            self.assertEqual(diff['changedRecords'], expected, '%s->%s' % (before, after))
            self.assertEqual(diff['unchangedRecords'], diff['records'] - expected)

    def test_named_cases_confirm_the_reviewed_identities(self):
        for label, expected_present, expected_total in (('X', 16, 17), ('AA', 16, 16), ('AC', 0, 0)):
            cases = classify.named_cases(PINNED[label], label)
            found = cases['singularGlyphRecordSet']
            self.assertEqual(found['reviewedGlyphRecordsPresent'], expected_present, label)
            self.assertEqual(found['degenerateFrameRecords'], expected_total, label)
            self.assertEqual(found['otherDegenerateFrameRecords'], ['48:24049'] if label == 'X' else [])
            face = cases['saltstoneFace11823']
            self.assertEqual(face['faceState'], FULL_RANK)
            self.assertEqual(face['uvJacobian'], -0.04529086293041473)
            self.assertEqual([c['vertex'] for c in face['corners']], [24049, 24050, 24051])
            self.assertEqual([list(c['flags']) for c in face['corners']],
                             [['wSignDisagrees'], ['wSignDisagrees', 'storedBinormalOpposesDV'],
                              ['wSignDisagrees', 'storedBinormalOpposesDV']] if label == 'X' else
                             [[], [], []])
            self.assertEqual(len(cases['storedTangentOpposesDU']), 5)

    def test_every_role_is_classified_and_sampled(self):
        roles = self.results['AC']['roles']
        self.assertEqual(len(roles), 14)
        self.assertEqual(sum(bucket['records'] for bucket in roles.values()), 319065)
        self.assertFalse(roles['sea']['normalTexture'])
        self.assertTrue(roles['sea']['advisories'].get('roleWithoutNormalTexture'))
        self.assertEqual(roles['saltstone']['categories'][UNAFFECTED], 3)
        self.assertEqual(roles['ochre']['advisories']['nonorthogonalNT'], 4676)
        self.assertEqual(sum(bucket['categories'][SPEC_VALID_DISAGREEING]
                             for bucket in roles.values()), 314178)


if __name__ == '__main__':
    unittest.main()