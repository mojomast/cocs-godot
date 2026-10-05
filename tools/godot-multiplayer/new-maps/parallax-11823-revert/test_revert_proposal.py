"""Tests for the bounded Parallax face-11823 revert decision package.

Three layers, in increasing dependence on committed state.

*Synthetic.* `proposed_successor_contract.plan` and `validate_rows` are driven
over hand-built BIN blobs and accessor tables, so every containment guard is
exercised without any committed artifact: an unexpected AC record, an
unexpected X record, a vertex that picked up a second incident face, a
corner-0 record that is *not* the reviewed X zero tangent, an over-wide byte
delta, an accessor alias and an image alias each have to be **rejected**, so a
pass means something. The harness-readiness audit is driven against synthetic
harness text, so a `feasible` verdict is unreachable by accident.

*Committed.* The real pinned X / AA / AC bytes produce every number the decision
document states. These tests skip loudly, never fabricate, when a pinned source
is absent.

*Guard.* The emitted revert diff is checked structurally and with `git apply
--check` against a scratch index, so the patch a reviewer is asked to read is a
patch that would actually apply -- while still never being applied to the
worktree.
"""
import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/map_variety'))
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis'))
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/parallax-observatory/revisions/'
                           'districts-v4-tangent'))
sys.path.insert(0, str(HERE))

import contract as aa

import proposed_successor_contract as psc
import revert_proposal as rp


# --------------------------------------------------------------------------
# Synthetic container for the containment guards.
# --------------------------------------------------------------------------

STRIDE = 16
BIN_START = 1024


def rows(**overrides):
    """The three reviewed rows, with any field overridable per corner."""
    base = []
    for corner, vertex in enumerate(psc.VERTICES):
        row = {'corner': corner, 'vertex': vertex,
               'acTangent': (1., 0., 0., -1.),
               'xTangent': tuple(psc.X_BASIS[corner]),
               'normal': (0., 1., 0.),
               'incidentFaces': [11823],
               'binOffset': BIN_START + vertex * STRIDE}
        row.update(overrides.get(corner, {}))
        base.append(row)
    return base


def blob_for(reviewed, filler=0):
    """A BIN blob long enough for every reviewed vertex record."""
    highest = max(row['vertex'] for row in reviewed)
    size = BIN_START + (highest + 1) * STRIDE + 64
    blob = bytearray(bytes([filler]) * size)
    for row in reviewed:
        struct.pack_into('<4f', blob, row['binOffset'], *row['acTangent'])
    return blob


def doc_for(reviewed, decoy_accessors=(), decoy_views=()):
    """An accessor table where the reviewed TANGENT accessor is index 48."""
    accessors = [{'bufferView': i, 'componentType': 5126, 'count': 1, 'type': 'SCALAR'}
                 for i in range(psc.ACCESSOR)]
    accessors.append({'bufferView': psc.ACCESSOR, 'componentType': 5126,
                      'count': max(r['vertex'] for r in reviewed) + 1, 'type': 'VEC4'})
    assert accessors[psc.ACCESSOR]['type'] == 'VEC4'
    accessors.extend(dict(entry) for entry in decoy_accessors)
    views = [{'buffer': 0, 'byteOffset': i * 4, 'byteLength': 4} for i in range(psc.ACCESSOR)]
    views.append({'buffer': 0, 'byteOffset': BIN_START, 'byteLength': 4 * STRIDE * 8})
    views.extend(dict(view) for view in decoy_views)
    return {'accessors': accessors, 'bufferViews': views}


class SyntheticGuardTests(unittest.TestCase):
    """Every containment guard, driven without any committed artifact."""

    def test_accepted_shape_changes_exactly_three_bytes_inside_the_window(self):
        reviewed = rows()
        blob = blob_for(reviewed)
        out, changed, permitted = psc.plan(blob, None, reviewed, doc_for(reviewed), [])
        self.assertEqual(len(changed), 3)
        self.assertEqual(len(permitted), 48)
        self.assertTrue(changed <= permitted)
        for corner, row in enumerate(reviewed):
            self.assertEqual(struct.unpack_from('<4f', out, row['binOffset']),
                             psc.REVERT_BASIS[corner])
            self.assertEqual(struct.unpack_from('<2f', out, row['binOffset'] + 4),
                             (0., 0.))
        # every other byte untouched
        self.assertEqual(bytes(out[:BIN_START]), bytes(blob[:BIN_START]))
        for vertex in range(0, max(r['vertex'] for r in reviewed) + 1):
            if vertex in psc.VERTICES:
                continue
            offset = BIN_START + vertex * STRIDE
            self.assertEqual(bytes(out[offset:offset + STRIDE]),
                             bytes(blob[offset:offset + STRIDE]))

    def test_only_the_w_byte_of_each_record_moves(self):
        reviewed = rows()
        blob = blob_for(reviewed)
        out, changed, _permitted = psc.plan(blob, None, reviewed, doc_for(reviewed), [])
        for row in reviewed:
            offset = row['binOffset']
            self.assertEqual(bytes(out[offset:offset + 12]), bytes(blob[offset:offset + 12]))
            self.assertEqual(struct.unpack_from('<4f', out, offset)[3], 1.0)
            self.assertEqual(struct.unpack_from('<4f', blob, offset)[3], -1.0)
            self.assertIn(offset + 15, changed)

    def test_validate_rows_accepts_the_reviewed_shape(self):
        psc.validate_rows(rows())

    def test_unexpected_ac_record_is_rejected(self):
        reviewed = rows()
        reviewed[1]['acTangent'] = (1., 0., 0., 1.)
        with self.assertRaises(ValueError):
            psc.validate_rows(reviewed)

    def test_unexpected_x_record_is_rejected(self):
        reviewed = rows()
        reviewed[0]['xTangent'] = (0., 0., 0., -1.)
        with self.assertRaises(ValueError):
            psc.validate_rows(reviewed)

    def test_vertex_with_a_second_incident_face_is_rejected(self):
        reviewed = rows()
        reviewed[1]['incidentFaces'] = [11823, 11824]
        with self.assertRaises(ValueError) as caught:
            psc.validate_rows(reviewed)
        self.assertIn('exclusive', str(caught.exception))

    def test_wrong_corner_or_vertex_set_is_rejected(self):
        reviewed = rows()
        reviewed[2]['vertex'] = 24052
        with self.assertRaises(ValueError):
            psc.validate_rows(reviewed)

    def test_corner_zero_that_is_usable_defeats_the_x_restore_precondition(self):
        """The proposal depends on X having no usable basis at corner 0."""
        reviewed = rows()
        reviewed[0]['xTangent'] = (1., 0., 0., 1.)
        with self.assertRaises(ValueError) as caught:
            psc.validate_rows(reviewed)
        self.assertIn('spec-invalid', str(caught.exception))

    def test_over_wide_byte_delta_is_rejected(self):
        """A blob whose AC records already hold +1 changes nothing and must fail."""
        reviewed = rows()
        for row in reviewed:
            row['acTangent'] = (1., 0., 0., 1.)
        blob = blob_for(reviewed)
        with self.assertRaises(ValueError) as caught:
            psc.plan(blob, None, reviewed, doc_for(reviewed), [])
        self.assertIn('three-byte delta', str(caught.exception))

    def test_accessor_alias_is_rejected(self):
        reviewed = rows()
        blob = blob_for(reviewed)
        target = reviewed[0]['binOffset']
        decoy = {'bufferView': psc.ACCESSOR + 1, 'componentType': 5126, 'count': 1,
                 'type': 'SCALAR'}
        view = {'buffer': 0, 'byteOffset': target + 15, 'byteLength': 4}
        with self.assertRaises(ValueError) as caught:
            psc.plan(blob, None, reviewed, doc_for(reviewed, [decoy], [view]), [])
        self.assertIn('aliases another accessor', str(caught.exception))

    def test_a_nearby_but_disjoint_decoy_accessor_is_accepted(self):
        """The accessor guard must not be a blanket 'anything inside the window'."""
        reviewed = rows()
        blob = blob_for(reviewed)
        last = reviewed[-1]['binOffset']
        decoy = {'bufferView': psc.ACCESSOR + 1, 'componentType': 5126, 'count': 1,
                 'type': 'SCALAR'}
        view = {'buffer': 0, 'byteOffset': last + STRIDE, 'byteLength': 4}
        view = {'buffer': 0, 'byteOffset': last + STRIDE, 'byteLength': 4}
        out, changed, _p = psc.plan(blob, None, reviewed,
                                    doc_for(reviewed, [decoy], [view]), [])
        self.assertEqual(len(changed), 3)
        for start in range(last + STRIDE, last + STRIDE + 4):
            self.assertNotIn(start, changed)
        del out

    def test_image_alias_is_rejected(self):
        reviewed = rows()
        blob = blob_for(reviewed)
        images = [(reviewed[1]['binOffset'] + 15, 1)]
        with self.assertRaises(ValueError) as caught:
            psc.plan(blob, None, reviewed, doc_for(reviewed), images)
        self.assertIn('aliases an embedded image', str(caught.exception))

    def test_image_just_beside_the_window_is_accepted(self):
        reviewed = rows()
        blob = blob_for(reviewed)
        images = [(reviewed[0]['binOffset'] + 16, 8)]  # starts one byte past the window
        blob, changed, _p = psc.plan(blob, None, reviewed, doc_for(reviewed), images)
        self.assertEqual(len(changed), 3)

    def test_wrong_window_size_is_rejected(self):
        reviewed = rows()
        reviewed[1]['binOffset'] = reviewed[0]['binOffset']   # two corners, one record
        blob = blob_for(reviewed)
        with self.assertRaises(ValueError) as caught:
            psc.plan(blob, None, reviewed, doc_for(reviewed), [])
        self.assertIn('48 bytes', str(caught.exception))

    def test_restore_report_declares_scope_and_omissions(self):
        report = psc.restore_report()
        self.assertEqual(report['status'], 'PROPOSAL ONLY, not applied')
        self.assertFalse(report['artifactWritten'])
        self.assertIn('48 BIN positions', report['byteScope'])
        self.assertTrue(any('Blender' in item for item in report['whatARealRevertStillNeeds']))
        self.assertTrue(any('native' in item for item in report['whatARealRevertStillNeeds']))
        self.assertTrue(any('capture' in item for item in report['whatARealRevertStillNeeds']))


# A harness with none of the AC01 blockers present, so a `feasible` verdict is
# reachable: three variants, no hash-pinned staged scripts, a re-renderable stage,
# no grant or reopen receipts, no real-UID sidecar check.
FEASIBLE_CAPTURE = 'for variant: String in variants:\n'
FEASIBLE_STAGED = 'read_json(path)\n'
FEASIBLE_STAGE = 'dest.mkdir(parents=True)\n'


class SyntheticHarnessTests(unittest.TestCase):
    """`render_feasibility` must be unable to reach 'feasible' by accident."""

    def test_all_preconditions_satisfied_is_feasible(self):
        result = rp.render_feasibility_from_text(
            FEASIBLE_CAPTURE, FEASIBLE_STAGED, FEASIBLE_STAGE, captures=(),
            import_cache=True, blender='/usr/bin/blender', resolving=['overview'])
        self.assertTrue(result['feasible'], result['unsatisfiedPreconditions'])
        self.assertEqual(result['unsatisfiedPreconditions'], [])
        self.assertEqual(result['verdict'], 'feasible')

    def test_two_variant_harness_is_reported_infeasible(self):
        text = ('for candidate: bool in [false,true]\n'
                'assert(records.size()==(2 if selected!="" else probes.cameras.size()*2))\n')
        result = rp.render_feasibility_from_text(
            text, 'Stale staged bytes\n', 'exist_ok=False\nuse a new attempt\n'
            'require_grant\nreopen-report.json\ncheck_sidecar\n',
            captures=('a.png',), import_cache=True, blender='/usr/bin/blender',
            resolving=['overview'])
        self.assertFalse(result['feasible'])
        self.assertIn('harnessSupportsThreeVariants', result['unsatisfiedPreconditions'])
        self.assertIn('stagedScriptsAreRewritable', result['unsatisfiedPreconditions'])

    def test_unresolvable_face_is_reported_infeasible(self):
        text = FEASIBLE_CAPTURE
        result = rp.render_feasibility_from_text(
            text, FEASIBLE_STAGED, FEASIBLE_STAGE,
            captures=('a.png',), import_cache=True, blender='/usr/bin/blender', resolving=[])
        self.assertFalse(result['feasible'])
        self.assertIn('committedCamerasResolveTheFace', result['unsatisfiedPreconditions'])

    def test_missing_import_cache_and_blender_are_reported_infeasible(self):
        text = FEASIBLE_CAPTURE
        result = rp.render_feasibility_from_text(
            text, FEASIBLE_STAGED, FEASIBLE_STAGE, captures=('a.png',), import_cache=False,
            blender=None, resolving=['overview'])
        self.assertFalse(result['feasible'])
        self.assertIn('projectImportCachePresent', result['unsatisfiedPreconditions'])
        self.assertIn('blenderAvailable', result['unsatisfiedPreconditions'])

    def test_missing_fixture_list_is_populated_when_infeasible(self):
        result = rp.render_feasibility_from_text('for candidate: bool in [false,true]\n',
                                                 '', '', captures=(), import_cache=False,
                                                 blender=None, resolving=[])
        self.assertTrue(result['missingFixture'])
        self.assertTrue(all(isinstance(item, str) for item in result['missingFixture']))


class DistributionTests(unittest.TestCase):
    def test_distribution_percentiles_are_ordered(self):
        stats = rp.distribution([0.0, 1.0, 2.0, 3.0, 4.0])
        self.assertEqual(stats['samples'], 5)
        self.assertEqual(stats['minDegrees'], 0.0)
        self.assertEqual(stats['maxDegrees'], 4.0)
        self.assertEqual(stats['meanDegrees'], 2.0)
        self.assertLessEqual(stats['p25Degrees'], stats['medianDegrees'])
        self.assertLessEqual(stats['medianDegrees'], stats['p90Degrees'])
        self.assertLessEqual(stats['p90Degrees'], stats['maxDegrees'])
        self.assertEqual(stats['fractionAbove']['5deg'], 0.0)

    def test_distribution_fraction_above_counts_strictly(self):
        stats = rp.distribution([1.0, 5.0, 5.0])
        self.assertEqual(stats['fractionAbove']['1deg'], 2 / 3)
        self.assertEqual(stats['fractionAbove']['5deg'], 0.0)


class PatchGuardTests(unittest.TestCase):
    """The emitted diff must be a diff that would actually apply -- unapplied here."""

    def test_patch_is_a_new_file_diff_for_both_sources(self):
        text, added = rp.revert_diff()
        self.assertIn('diff --git', text)
        self.assertEqual(text.count('new file mode 100644'), 2)
        self.assertIn('--- /dev/null', text)
        self.assertEqual(len(added), 2)
        for (source, target), entry in zip(rp.PROPOSED_SOURCES, added):
            self.assertEqual(entry['addedPath'], '%s/%s' % (rp.PROPOSED_DIR, target))
            self.assertEqual(entry['sha256'], rp.sha((HERE / source).read_bytes()))

    def test_patch_added_content_matches_the_proposal_sources(self):
        text, added = rp.revert_diff()
        for (source, _target), entry in zip(rp.PROPOSED_SOURCES, added):
            body = (HERE / source).read_text()
            for line in body.splitlines():
                self.assertIn('+' + line, text)
            self.assertEqual(entry['lines'], len(body.splitlines()))

    def test_patch_does_not_touch_any_existing_file(self):
        text, _added = rp.revert_diff()
        for line in text.splitlines():
            if line.startswith('--- ') and not line.startswith('--- /dev/null'):
                self.fail('revert patch must only add files, found: ' + line)

    @unittest.skipUnless((ROOT / '.git').exists(), 'needs a git checkout')
    def test_patch_applies_cleanly_to_a_scratch_index_without_touching_the_worktree(self):
        text, _added = rp.revert_diff()
        with tempfile.TemporaryDirectory() as scratch:
            patch = Path(scratch) / 'revert.patch'
            patch.write_text(text)
            result = subprocess.run(
                ['git', 'apply', '--check', '--cached', '-p1', str(patch)],
                cwd=str(ROOT), capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        # the worktree must still carry no districts-v5 directory
        self.assertFalse((ROOT / rp.PROPOSED_DIR).exists())


# --------------------------------------------------------------------------
# Committed-source layer.
# --------------------------------------------------------------------------

def _has_committed_sources():
    return (aa.SOURCE.is_file() and rp.AC_GLB.is_file()
            and (ROOT / 'godot/tests/new_maps/parallax_glyph/AC01/probes.json').is_file())


@unittest.skipUnless(_has_committed_sources(), 'pinned X/AC/probes sources are absent')
class CommittedSourceTests(unittest.TestCase):
    """Every number the decision document states is asserted, not transcribed."""

    @classmethod
    def setUpClass(cls):
        cls.roles, _conventions = rp.ap.material_table()
        cls.arts = rp.artifacts()
        cls.report = rp.run()

    def test_reviewed_corner_set_and_bases(self):
        corners = self.report['corners']
        self.assertEqual([c['corner'] for c in corners], [0, 1, 2])
        self.assertEqual([c['vertex'] for c in corners], [24049, 24050, 24051])
        self.assertEqual([c['incidentFaces'] for c in corners], [[11823], [11823], [11823]])
        self.assertEqual([c['basis']['X'] for c in corners],
                         [[0., 0., 0., 1.], [1., 0., 0., 1.], [1., 0., 0., 1.]])
        self.assertEqual([c['basis']['AA'] for c in corners], [[1., 0., 0., -1.]] * 3)
        self.assertEqual([c['basis']['AC'] for c in corners], [[1., 0., 0., -1.]] * 3)

    def test_corner_zero_x_basis_is_spec_invalid_and_ac_closes_it(self):
        verdicts = self.report['corners'][0]['specVerdict']
        self.assertIn('zeroTangent', verdicts['X'])
        self.assertIn('degenerateFrame', verdicts['X'])
        self.assertEqual(verdicts['AA'], [])
        self.assertEqual(verdicts['AC'], [])

    def test_reviewed_face_geometry_and_normal_settings(self):
        face = self.report['reviewedFace']
        self.assertEqual(face['mesh'], 9)
        self.assertEqual(face['face'], 11823)
        self.assertEqual(face['faceState'], 'fullRank')
        self.assertAlmostEqual(face['area'], 0.09058172586082947, places=15)
        self.assertAlmostEqual(face['uvJacobian'], -0.04529086293041473, places=15)
        self.assertEqual(self.report['normalScale'], 0.4)
        self.assertEqual(self.report['tilesPerMeter'], 0.5)

    def test_the_two_comparable_corners_reverse_green_180(self):
        per_corner = self.report['visualSignificance']['perCorner']
        self.assertEqual([row['corner'] for row in per_corner], [0, 1, 2])
        self.assertFalse(per_corner[0]['models'][rp.ap.STRENGTH_MODELS[0]]['comparable'])
        for row in per_corner[1:]:
            for model in rp.ap.STRENGTH_MODELS:
                block = row['models'][model]
                self.assertTrue(block['comparable'])
                self.assertAlmostEqual(block['greenComponentAngleDegrees'], 180.0, places=9)
                self.assertAlmostEqual(block['binormalAngleDegrees'], 180.0, places=9)

    def test_world_normal_deviation_is_4_90_and_5_59_degrees(self):
        blender, godot = rp.ap.STRENGTH_MODELS
        per_corner = self.report['visualSignificance']['perCorner']
        self.assertAlmostEqual(per_corner[1]['models'][blender]['worldNormalAngleDegrees'],
                               4.8981065021778525, places=9)
        self.assertAlmostEqual(per_corner[1]['models'][godot]['worldNormalAngleDegrees'],
                               4.905837492371824, places=9)
        self.assertAlmostEqual(per_corner[2]['models'][blender]['worldNormalAngleDegrees'],
                               5.5852321375639695, places=9)
        self.assertAlmostEqual(per_corner[2]['models'][godot]['worldNormalAngleDegrees'],
                               5.584712033546011, places=9)

    def test_all_three_corners_address_the_same_texel(self):
        self.assertTrue(all(row['sameTexelAcrossOrigins']
                            for row in self.report['visualSignificance']['perCorner']))
        self.assertTrue(self.report['appearanceSummary']['sameTexelEveryCorner'])

    def test_directional_diffuse_delta_is_measurable(self):
        per_corner = self.report['visualSignificance']['perCorner']
        deltas = [row['models'][rp.ap.STRENGTH_MODELS[1]]['directionalDiffuse']
                  for row in per_corner[1:]]
        for block in deltas:
            self.assertGreater(block['absoluteDelta'], 0.05)
            self.assertGreater(block['relativeDeltaPercent'], 7.0)
            self.assertLess(block['relativeDeltaPercent'], 9.5)

    def test_face_is_a_needle_and_a_negligible_fraction_of_saltstone(self):
        footprint = self.report['visualSignificance']['geometryFootprint']
        self.assertAlmostEqual(footprint['areaSquareMetres'], 0.09058172586082947, places=15)
        self.assertLess(footprint['meanWidthMetres'], 0.005)
        self.assertGreater(footprint['longestEdgeMetres'], 37.0)
        self.assertLess(footprint['fractionOfSaltstone'], 1e-6)
        self.assertLess(footprint['fractionOfScene'], 1e-6)

    def test_deviation_distribution_over_the_face_footprint(self):
        footprint = self.report['visualSignificance']['faceUvFootprint']
        self.assertGreater(footprint['worldNormalAngleByModel']
                           [rp.ap.STRENGTH_MODELS[0]]['maxDegrees'], 15.0)
        self.assertGreater(footprint['worldNormalAngleByModel']
                           [rp.ap.STRENGTH_MODELS[0]]['medianDegrees'], 1.0)
        self.assertGreater(footprint['greenNeutralFraction'], 0.0)

    def test_whole_normal_map_bound_is_larger_than_the_face_bound(self):
        whole = self.report['visualSignificance']['wholeNormalMap']['worldNormalAngleByModel']
        face = self.report['visualSignificance']['faceUvFootprint']['worldNormalAngleByModel']
        for model in rp.ap.STRENGTH_MODELS:
            self.assertGreater(whole[model]['maxDegrees'], face[model]['maxDegrees'])

    def test_no_committed_camera_resolves_the_face(self):
        visibility = self.report['visualSignificance']['cameraVisibility']
        self.assertEqual(len(visibility['cameras']), 12)
        self.assertEqual(visibility['camerasResolvingTheFace'], [])
        self.assertEqual(sorted(visibility['camerasWithFaceFrontFacing']),
                         ['overview', 'wayfinding-2-glyph-close', 'wayfinding-3-glyph-close'])
        widths = [row['sliverWidthPixelsAtCentroid'] for row in visibility['cameras']
                  if 'sliverWidthPixelsAtCentroid' in row]
        self.assertTrue(widths)
        self.assertLess(max(widths), 1.0)

    def test_one_pixel_resolution_needs_a_camera_two_and_a_half_metres_away(self):
        """The most generous committed fov still needs a 2.56 m close-up.

        The needle is ~4.8 mm wide, so at 68 degrees vertical and 720 px the face
        only reaches one pixel at 2.562 m. The closest committed camera is
        `pump-interior` at 8.08 m of depth, which projects it to 0.317 px.
        """
        footprint = self.report['visualSignificance']['geometryFootprint']
        self.assertAlmostEqual(footprint['distanceForOnePixelWidthMetres'],
                               2.5617891521719756, places=9)
        self.assertAlmostEqual(footprint['distanceForTenPixelWidthMetres'],
                               0.25617891521719754, places=9)
        visibility = self.report['visualSignificance']['cameraVisibility']
        depths = [row['depthMetres'] for row in visibility['cameras']
                  if 'depthMetres' in row]
        self.assertGreater(min(depths), footprint['distanceForOnePixelWidthMetres'])

    def test_render_is_reported_infeasible_with_named_blockers(self):
        feasibility = self.report['renderFeasibility']
        self.assertFalse(feasibility['feasible'])
        for name in ('harnessSupportsThreeVariants', 'projectImportCachePresent',
                     'blenderAvailable', 'committedCamerasResolveTheFace'):
            self.assertIn(name, feasibility['unsatisfiedPreconditions'])
        self.assertTrue(feasibility['verdict'].startswith('NOT FEASIBLE'))
        self.assertTrue(feasibility['missingFixture'])

    def test_revert_candidate_measurements(self):
        by_name = {c['candidate']: c for c in self.report['revertCandidates']}
        r1 = by_name['R1_uniform_w_plus1']
        self.assertTrue(r1['admissible'])
        self.assertEqual(r1['bytes']['changedVsAC'], 3)
        self.assertEqual(r1['bytes']['changedVsX'], 66)
        self.assertTrue(r1['bytes']['changedWithinPermittedWindow'])
        self.assertEqual(r1['bytes']['aliasedAccessors'], [])
        self.assertEqual(r1['bytes']['aliasedImages'], [])
        self.assertEqual(r1['container']['geometryReParsed'],
                         {'primitives': 39, 'triangles': 155553})
        self.assertEqual(r1['classification']['categories']['specInvalid'], 0)
        self.assertEqual([row['byteIdenticalToX'] for row in r1['perCorner']],
                         [False, True, True])

        r2 = by_name['R2_mixed_w']
        self.assertTrue(r2['admissible'])
        self.assertEqual(r2['bytes']['changedVsAC'], 2)
        self.assertEqual(r2['bytes']['changedVsX'], 67)

        literal = by_name['LITERAL_X_bytes']
        self.assertFalse(literal['admissible'])
        self.assertIn('spec-invalid', literal['rejection'])
        self.assertEqual(literal['classification']['categories']['specInvalid'], 1)

    def test_revert_moves_the_three_records_back_into_derivative_disagreement(self):
        by_name = {c['candidate']: c for c in self.report['revertCandidates']}
        r1 = by_name['R1_uniform_w_plus1']['classification']['deltaVsAc']
        self.assertEqual(r1['specInvalid'], 0)
        self.assertEqual(r1['wSignDisagrees'], 3)
        self.assertEqual(r1['specValidDerivativeDisagreeing'], 3)

    def test_in_memory_revert_carries_the_same_basis_as_the_r1_candidate(self):
        """Same BIN, different container JSON: the proposal stamps its own revision.

        The candidate is measured with the AC JSON untouched so its hash isolates the
        basis change; the proposed successor additionally writes revision metadata, so
        the two whole-file hashes differ by design while the BIN bytes must be equal.
        """
        r1 = {c['candidate']: c for c in self.report['revertCandidates']}['R1_uniform_w_plus1']
        self.assertTrue(r1['containerJsonLeftAtAc'])
        expected_bin = r1['bytes']['binSha256']
        proof = self.report['proposedRevert']['inMemoryProof']
        del expected_bin
        self.assertNotEqual(self.report['proposedRevert']['inMemorySha256'],
                            r1['bytes']['artifactSha256'])
        self.assertFalse(self.report['proposedRevert']['artifactWritten'])
        self.assertIsNone(proof['artifactSha256'])
        self.assertEqual(proof['visualRevision'], psc.REVERT)
        self.assertEqual(proof['predecessorSha256'], psc.EXPECTED_AC_SHA)

    def test_revert_restores_x_bytes_on_the_two_usable_corners(self):
        proof = self.report['proposedRevert']['inMemoryProof']
        self.assertEqual(proof['changedBINBytes'], 3)
        self.assertEqual(proof['permittedBINBytes'], 48)
        self.assertEqual([r['byteIdenticalToX'] for r in proof['records']], [False, True, True])
        self.assertEqual([r['xUsableBasisExists'] for r in proof['records']],
                         [False, True, True])
        self.assertEqual([r['xSpecVerdict'][:1] for r in proof['records']],
                         [['zeroTangent'], [], []])
        self.assertEqual(sorted(proof['changedBINPositions']),
                         [16458395, 16458411, 16458427])
        self.assertEqual([r['xUsableBasisExists'] for r in proof['records']],
                         [False, True, True])

    def test_report_declares_no_artifact_native_or_promotion_claim(self):
        blob = json.dumps(self.report).lower()
        for phrase in ('artifactwritten', 'applied', 'no native claim'):
            self.assertIn(phrase, blob)
        self.assertFalse(self.report['revertPatch']['applied'])
        self.assertTrue(any('No artifact change' in b for b in self.report['boundaries']))
        self.assertTrue(any('no promotion' in b for b in self.report['boundaries']))

    def test_run_is_deterministic(self):
        again = rp.run()
        self.assertEqual(json.dumps(again, sort_keys=True),
                         json.dumps(self.report, sort_keys=True))

    def test_ac_baseline_still_has_zero_spec_invalid_records(self):
        self.assertEqual(self.report['acBaseline']['categories']['specInvalid'], 0)
        self.assertEqual(self.report['acBaseline']['categories']['specValidDerivativeDisagreeing'],
                         314178)


class MissingSourceTests(unittest.TestCase):
    """A missing or altered pinned source is reported, never fabricated."""

    def test_missing_x_master_is_reported_by_the_pinned_loader(self):
        saved = aa.SOURCE
        try:
            aa.SOURCE = ROOT / 'tools/godot-multiplayer/new-maps/parallax-11823-revert/absent.glb'
            with self.assertRaises(Exception):
                aa.pinned()
        finally:
            aa.SOURCE = saved

    def test_missing_normal_image_is_reported_not_invented(self):
        roles, _conventions = rp.ap.material_table()
        role = dict(roles['saltstone'], _name='saltstone')
        saved = rp.PACK_ROOT if hasattr(rp, 'PACK_ROOT') else None
        del saved
        # An untextured role reports absence rather than fabricating an image.
        untextured = {'saltstone': {'role': 'preserve', 'normalTexture': False,
                                    'normalScale': None, 'tilesPerMeter': 0.5,
                                    'resource': None}}
        image, report = rp.ap.normal_image(dict(untextured['saltstone'],
                                                _name='saltstone'), None)
        self.assertIsNone(image)
        self.assertFalse(report['available'])
        self.assertIn('reason', report)
        del role


if __name__ == '__main__':
    unittest.main()