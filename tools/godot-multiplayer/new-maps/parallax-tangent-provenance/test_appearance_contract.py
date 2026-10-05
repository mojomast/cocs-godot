"""Tests for the bounded source-only Parallax appearance-preservation contract.

Two layers. The synthetic layer pins the contract's own discipline: an
asymmetric full-rank image where a solitary W flip, a green flip and a wrong
image origin each have to be *rejected*, so a pass is not vacuous. The
real-source layer runs the same comparisons at the actual saltstone face 11823
corners, the five U-reversed corners and every textured role of the committed AC
artifact.

The five U-reversed corners and the singular glyph records are only meaningful
when the pinned GLBs are present; those tests skip loudly rather than invent
bytes. Committed evidence (the Moth pack PNGs) is always checked.
"""
import json
import math
import struct
import unittest
import zlib

import appearance_contract as contract
import classify_records as classify
from appearance_contract import scale


def encode_png(width, height, pixels, methods=None):
    """Encode 8-bit RGBA with a chosen PNG filter per row, to exercise the decoder."""
    rows = bytearray()
    for y in range(height):
        method = 0 if methods is None else methods[y % len(methods)]
        raw = pixels[y * width * 4:(y + 1) * width * 4]
        encoded = bytearray(len(raw))
        prior = pixels[(y - 1) * width * 4:y * width * 4] if y else bytes(len(raw))
        for i in range(len(raw)):
            left = raw[i - 4] if i >= 4 else 0
            up = prior[i]
            upleft = prior[i - 4] if i >= 4 else 0
            if method == 0:
                encoded[i] = raw[i]
            elif method == 1:
                encoded[i] = (raw[i] - left) & 255
            elif method == 2:
                encoded[i] = (raw[i] - up) & 255
            elif method == 3:
                encoded[i] = (raw[i] - ((left + up) // 2)) & 255
            else:
                p, q, r = abs(up - upleft), abs(left - upleft), abs(left + up - 2 * upleft)
                pred = left if (p <= q and p <= r) else (up if q <= r else upleft)
                encoded[i] = (raw[i] - pred) & 255
        rows.append(method)
        rows += encoded

    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))

    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(rows))) + chunk(b'IEND', b''))


class PngDecoder(unittest.TestCase):
    def test_every_filter_round_trips(self):
        pixels = bytearray()
        for y in range(6):
            for x in range(5):
                pixels += bytes(((x * 37 + y * 11) % 256, (y * 53) % 256, (x * 91) % 256, 255))
        for methods in (None, [0], [1], [2], [3], [4], [0, 1, 2, 3, 4]):
            with self.subTest(methods=methods):
                raw = encode_png(5, 6, bytes(pixels), methods)
                self.assertEqual(contract.decode_png(raw), (5, 6, 4, bytes(pixels)))

    def test_rejects_unsupported_png_shapes(self):
        with self.assertRaisesRegex(ValueError, 'Not a PNG'):
            contract.decode_png(b'nope')
        header = struct.pack('>IIBBBBB', 2, 2, 16, 6, 0, 0, 0)
        body = zlib.compress(bytes(2 * (2 * 8 + 1)))
        bad = (b'\x89PNG\r\n\x1a\n' + struct.pack('>I', len(header)) + b'IHDR' + header
               + struct.pack('>I', len(body)) + b'IDAT' + body)
        with self.assertRaisesRegex(ValueError, '8-bit RGB/RGBA'):
            contract.decode_png(bad)

    def test_png_size_reads_ihdr_without_decoding(self):
        raw = encode_png(5, 6, bytes(5 * 6 * 4))
        self.assertEqual(contract.png_size(raw), (5, 6))
        with self.assertRaisesRegex(ValueError, 'Not a PNG'):
            contract.png_size(b'nope')
        with self.assertRaisesRegex(ValueError, '13-byte IHDR'):
            contract.png_size(raw[:8] + struct.pack('>I', 12) + b'IHDR' + bytes(12))


class Addressing(unittest.TestCase):
    def setUp(self):
        self.image = contract.synthetic_image()

    def test_blender_bottom_up_and_gltf_top_down_pair_at_texel_centers(self):
        """The exporter's v -> 1-v is paired with Blender's bottom-up image
        buffer, so both address the same original PNG row."""
        height, width = self.image[1], self.image[0]
        for row in range(height):
            for column in range(width):
                exported = ((column + 0.5) / width, (row + 0.5) / height)
                entry = contract.addressed_pair(self.image, exported)
                self.assertEqual(entry['gltf']['row'], row)
                self.assertEqual(entry['blender']['row'], row)
                self.assertEqual(entry['gltf']['rgb'], entry['blender']['rgb'])
                self.assertTrue(entry['sameTexel'])
                self.assertFalse(entry['texelBoundaryAligned'])

    def test_export_and_blender_origins_disagree_on_the_wrong_row(self):
        """The negative control the provenance test used: reading the authored UV
        through the wrong origin selects a different texel."""
        height, width = self.image[1], self.image[0]
        for row in range(height):
            exported = (0.5 / width, (row + 0.5) / height)
            authored = contract.authored_uv(exported)
            top_down = contract.texel(self.image, authored[0], authored[1], 'gltfTopDown')
            bottom_up = contract.texel(self.image, authored[0], authored[1], 'blenderBottomUp')
            correct = contract.texel(self.image, exported[0], exported[1], 'gltfTopDown')
            self.assertEqual(top_down[1], height - 1 - bottom_up[1])
            self.assertNotEqual(top_down[2], bottom_up[2])
            # Only the correct origin pairing lands on the authored texel.
            self.assertEqual(bottom_up[2], correct[2])
            self.assertEqual(top_down[2], contract.SYNTHETIC_ROWS[height - 1 - row][0])

    def test_repeat_wrap_matches_the_only_declared_mode(self):
        self.assertAlmostEqual(contract.repeat(0.25), 0.25)
        self.assertAlmostEqual(contract.repeat(35.36811447143555 % 1), 35.36811447143555 % 1)
        self.assertTrue(0. <= contract.repeat(-32.56804275512695) < 1.)
        column, _, rgb = contract.texel(self.image, 0.5 / self.image[0] + 4 * self.image[0], 0.125,
                                    'gltfTopDown')
        self.assertEqual((column, rgb), (0, contract.SYNTHETIC_ROWS[0][0]))

    def test_authored_uv_inverts_the_pinned_exporter_transform(self):
        for v in (0., 0.125, 0.5, 0.875, 1., 33.568, -32.568):
            self.assertAlmostEqual(contract.authored_uv((0.25, v))[1], 1. - v)

    def test_texel_boundary_alignment_is_reported_not_silently_accepted(self):
        entry = contract.addressed_pair(self.image, (0.5 / self.image[0], 0.0))
        self.assertTrue(entry['texelBoundaryAligned'])

    def test_bilinear_repeat_sample_commutes_with_the_v_flip(self):
        """Both pinned samplers declare LINEAR/REPEAT, and under that filter the
        exporter's v flip and Blender's bottom-up buffer select the same 2x2
        neighbourhood with the same weights -- including at texel centres."""
        image = self.image
        probes = [(x / 11., y / 7.) for x in range(11) for y in range(7)]
        probes += [((column + 0.5) / image[0], (row + 0.5) / image[1])
                   for row in range(image[1]) for column in range(image[0])]
        probes += [((k / 64., m / 64.)) for k in range(64) for m in (0, 1, 32, 33, 63)]
        for exported in probes:
            gltf = contract.sample_bilinear(image, exported[0], exported[1], 'gltfTopDown')
            blender = contract.sample_bilinear(image, *contract.authored_uv(exported),
                                               'blenderBottomUp')
            for a, b in zip(gltf, blender):
                self.assertAlmostEqual(a, b, places=9)

    def test_nearest_neighbour_can_only_disagree_by_breaking_a_tie(self):
        """Nearest sampling disagrees exactly where the UV sits on a pixel edge,
        where either answer is a tie-break. That is why the exhaustive sweep uses
        the declared filter and reports the tie set separately."""
        image = self.image
        height = image[1]
        ties = 0
        for column in range(image[0]):
            for edge in range(height + 1):
                exported = ((column + 0.5) / image[0], edge / height)
                gltf = contract.texel_index(image[0], height, exported[0], exported[1], 'gltfTopDown')
                blender = contract.texel_index(image[0], height,
                                              *contract.authored_uv(exported), 'blenderBottomUp')
                ties += gltf != blender
                gltf_b = contract.sample_bilinear(image, exported[0], exported[1], 'gltfTopDown')
                blender_b = contract.sample_bilinear(image, *contract.authored_uv(exported),
                                                     'blenderBottomUp')
                for a, b in zip(gltf_b, blender_b):
                    self.assertAlmostEqual(a, b, places=9)
        self.assertGreater(ties, 0)


class StrengthModels(unittest.TestCase):
    """The same scalar reaches the two pinned shader paths differently. Both are
    modelled; neither is asserted to be the accepted appearance."""

    def test_blender_scales_xy_and_mixes_z(self):
        N, T, w = (0., 0., 1.), (1., 0., 0.), 1.
        status, normal, B, channels = contract.world_perturbation(
            N, T, w, 0.4, -0.2, 0.9, 'blenderNormalMapNode', 0.5)
        self.assertEqual(status, 'ok')
        self.assertEqual(channels, (0.2, -0.1, 0.95))
        self.assertEqual(B, (0., 1., 0.))
        self.assertAlmostEqual(normal[0], 0.2 / math.sqrt(0.04 + 0.01 + 0.9025))
        self.assertAlmostEqual(normal[1], -0.1 / math.sqrt(0.04 + 0.01 + 0.9025))

    def test_godot_rebuilds_z_and_mixes_by_depth(self):
        N, T, w = (0., 0., 1.), (1., 0., 0.), 1.
        status, normal, B, channels = contract.world_perturbation(
            N, T, w, 0.4, -0.2, 0.9, 'godotForwardMixDepth', 0.5)
        self.assertEqual(status, 'ok')
        self.assertEqual(B, (0., 1., 0.))
        self.assertAlmostEqual(channels[2], math.sqrt(1. - 0.2))
        mixed = (0.5 * 0.4, 0.5 * -0.2, 0.5 * N[2] + 0.5 * channels[2])
        size = math.sqrt(sum(c * c for c in mixed))
        for got, want in zip(normal, mixed):
            self.assertAlmostEqual(got, want / size)

    def test_models_agree_only_when_the_stored_z_is_consistent_with_xy(self):
        """Godot always rebuilds z from xy and ignores the stored blue; Blender
        keeps it. So the two pinned paths coincide exactly only for a texel whose
        stored z already equals that reconstruction. That divergence is a property
        of the shaders, identical in X, AA and AC, and not a tangent defect."""
        N, T, w = (0., 0., 1.), (1., 0., 0.), 1.
        consistent = math.sqrt(1. - 0.3 ** 2 - 0.4 ** 2)
        first = contract.world_perturbation(N, T, w, 0.3, -0.4, consistent,
                                            'blenderNormalMapNode', 1.)[1]
        second = contract.world_perturbation(N, T, w, 0.3, -0.4, consistent,
                                             'godotForwardMixDepth', 1.)[1]
        self.assertLess(contract.angle_degrees(first, second), 1e-9)
        diverged = contract.world_perturbation(N, T, w, 0.3, -0.4, 0.9,
                                               'blenderNormalMapNode', 1.)[1]
        self.assertGreater(contract.angle_degrees(diverged, second), 0.5)

    def test_degenerate_frame_has_no_world_perturbation(self):
        status, normal, B, channels = contract.world_perturbation(
            (-1., 0., 0.), (1., 0., 0.), -1., 0.4, -0.2, 0.9, 'blenderNormalMapNode', 0.4)
        self.assertEqual(status, 'degenerateFrame')
        self.assertIsNone(normal)
        self.assertIsNone(B)

    def test_unknown_model_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unknown strength model'):
            contract.world_perturbation((0., 0., 1.), (1., 0., 0.), 1., 0., 0., 1., 'x', 1.)


class AsymmetricFullRankFixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.case = contract.asymmetric_full_rank_fixture()

    def test_fixture_is_asymmetric_and_green_straddles_neutral(self):
        rows = contract.SYNTHETIC_ROWS
        self.assertEqual(len({tuple(r) for r in rows}), len(rows))
        self.assertTrue(all(rows[i][j] != rows[k][l]
                            for i in range(len(rows)) for k in range(len(rows))
                            for j in range(3) for l in range(3)
                            if (i, j) != (k, l)))
        greens = [r[1] for row in rows for r in row]
        self.assertTrue(any(g < 128 for g in greens))
        self.assertTrue(any(g > 128 for g in greens))

    def test_authored_and_supplied_sides_agree_everywhere(self):
        summary = self.case['summary']
        self.assertEqual(summary['locations'], 12)
        self.assertEqual(summary['basePreserved'], summary['locations'])
        for sample in self.case['samples']:
            self.assertTrue(sample['baseVerdict']['sameTexel'])
            for model in contract.STRENGTH_MODELS:
                self.assertTrue(sample['baseVerdict'][model], model)
                self.assertLessEqual(sample['base']['models'][model]['worldAngleDegrees'], 1e-9)

    def test_solitary_w_flip_is_rejected_everywhere(self):
        """A W flip reverses the green axis outright even at a reviewed 0.4
        strength, and is visible in the world normal too."""
        for sample in self.case['samples']:
            for model in contract.STRENGTH_MODELS:
                self.assertAlmostEqual(contract.angle_degrees(
                    sample['base']['models'][model]['gltfTopDown']['binormal'],
                    sample['wFlip']['models'][model]['gltfTopDown']['binormal']), 180.)
                self.assertGreater(sample['wFlip']['models'][model]['worldAngleDegrees'], 1.)
                self.assertGreater(sample['wFlip']['models'][model]['maxComponentError'], 1e-4)

    def test_solitary_green_flip_is_rejected_everywhere(self):
        for sample in self.case['samples']:
            for model in contract.STRENGTH_MODELS:
                self.assertAlmostEqual(contract.angle_degrees(
                    scale(sample['base']['models'][model]['gltfTopDown']['binormal'],
                          sample['base']['models'][model]['gltfTopDown']['tangentSpace'][1]),
                    scale(sample['greenFlip']['models'][model]['gltfTopDown']['binormal'],
                          sample['greenFlip']['models'][model]['gltfTopDown']['tangentSpace'][1])), 180.)
                self.assertGreater(sample['greenFlip']['models'][model]['worldAngleDegrees'], 1.)

    def test_wrong_image_origin_is_rejected_everywhere(self):
        self.assertEqual(self.case['summary']['wrongOriginRejected'], self.case['summary']['locations'])
        for sample in self.case['samples']:
            self.assertTrue(contract._sides_disagree(sample['wrongOrigin']))

    def test_two_simultaneous_inversions_cancel_and_that_is_not_a_recommendation(self):
        image = contract.synthetic_image()
        exported = (0.5 / image[0], 0.5 / image[1])
        both = contract.compare_perturbation(image, exported, (0., 0., 1.), (1., 0., 0.), 1., 0.4,
                                            flip_w=True, flip_green=True)
        base = contract.compare_perturbation(image, exported, (0., 0., 1.), (1., 0., 0.), 1., 0.4)
        for model in contract.STRENGTH_MODELS:
            self.assertLessEqual(both['models'][model]['worldAngleDegrees'], 1e-9)
            self.assertLessEqual(base['models'][model]['worldAngleDegrees'], 1e-9)


class CommittedSources(unittest.TestCase):
    def test_material_table_matches_the_reviewed_bindings(self):
        roles, conventions = contract.material_table()
        self.assertEqual(len(roles), 14)
        self.assertFalse(roles['sea']['normalTexture'])
        self.assertEqual(roles['sea']['role'], 'preserve')
        self.assertEqual(roles['saltstone']['normalScale'], 0.4)
        self.assertEqual(roles['saltstone']['tilesPerMeter'], 0.5)
        self.assertEqual(roles['saltstone']['resource'], 'salt-limestone')
        self.assertEqual(roles['paving']['normalScale'], 0.45)
        self.assertEqual(roles['paving']['tilesPerMeter'], 0.25)
        self.assertEqual(conventions['salt-limestone'], 'OpenGL +Y; image rows down, UV v up')
        self.assertEqual(sorted(r for r in roles if roles[r]['normalTexture']),
                         ['cistern', 'metal', 'mirror', 'ochre', 'parallax.enamel', 'parallax.etch',
                          'parallax.glazing', 'parallax.instrument-alloy', 'parallax.optics',
                          'parallax.stone', 'parallax.trim', 'paving', 'saltstone'])

    def test_no_runtime_uv_transform_extension_is_present(self):
        """The UV transform is only the exporter's v flip; a texture-transform
        extension would silently invalidate the addressing pair."""
        for raw in (contract.X_GLB, classify.AC_GLB):
            if not raw.is_file():
                continue
            glb = classify.EmbeddedGlb(raw.read_bytes())
            self.assertIsNone(glb.doc.get('extensionsUsed'))
            for material in glb.doc['materials']:
                slot = material.get('normalTexture')
                if slot is not None:
                    self.assertIsNone(slot.get('extensions'))
                    self.assertEqual(slot.get('texCoord', 0), 0)

    def test_missing_pinned_source_is_reported_not_fabricated(self):
        original = classify.AC_GLB
        try:
            classify.AC_GLB = original.with_name('absent.glb')
            found = contract.load_artifacts()
            self.assertFalse(found['AC'])
            self.assertIsNone(found['AC'])
            report = contract.run()
            self.assertIn('blocked', report)
            self.assertFalse(report['inputs']['AC']['available'])
        finally:
            classify.AC_GLB = original

    def test_missing_packed_png_is_reported(self):
        glb = classify.EmbeddedGlb(contract.X_GLB.read_bytes())
        roles, _ = contract.material_table()
        image, report = contract.normal_image(dict(roles['saltstone'], _name='saltstone'), glb)
        self.assertIsNotNone(image)
        self.assertTrue(report['mothSource']['available'])
        self.assertEqual(report['mothSource']['sha256'], report['mothSource']['expectedSha256'])
        self.assertTrue(report['mothSource']['bytesIdenticalToEmbedded'])
        self.assertEqual(report['sha256'],
                         '203df36b390f61ce7e7a7801c1677637da1ce44ddd61ed4246572a7acf9593b6')
        image, report = contract.normal_image(dict(roles['sea'], _name='sea'), glb)
        self.assertIsNone(image)
        self.assertFalse(report['available'])

    def test_decoded_normal_map_green_is_actually_non_neutral(self):
        """Equal-channel counts exclude a channel rewrite but say nothing about a
        basis, so the contract samples the real data instead of asserting it."""
        glb = classify.EmbeddedGlb(contract.X_GLB.read_bytes())
        roles, _ = contract.material_table()
        image, _ = contract.normal_image(dict(roles['saltstone'], _name='saltstone'), glb)
        greens = [image[3][(row * image[0] + column) * image[2] + 1]
                  for row in range(0, image[1], 4) for column in range(0, image[0], 4)]
        self.assertEqual((image[0], image[1]), (512, 512))
        self.assertTrue(any(g < 128 for g in greens))
        self.assertTrue(any(g > 128 for g in greens))


REAL = contract.load_artifacts()


@unittest.skipUnless(REAL['X'] and REAL['AC'], 'pinned X/AC GLB bytes are unavailable')
class RealSourceCases(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.roles, _ = contract.material_table()
        cls.cases = classify.named_cases(REAL['AC'], 'AC')
        cls.glyph_cases = (classify.named_cases(REAL['AA'], 'AA') if REAL['AA'] else cls.cases)

    def test_saltstone_face_11823_addresses_the_same_texel_before_and_after(self):
        case = contract.saltstone_face_11823(REAL['X'], REAL['AA'], REAL['AC'], self.roles)
        self.assertTrue(case['available'])
        self.assertEqual(case['summary']['corners'], 3)
        self.assertTrue(case['summary']['sameTexelEveryCorner'])
        for corner in case['corners']:
            for label in ('X', 'AA', 'AC'):
                self.assertTrue(corner['evaluations'][label]['addressing']['sameTexel'], label)
                self.assertFalse(corner['evaluations'][label]['addressing']['texelBoundaryAligned'])
            self.assertEqual(corner['basis']['AA'], corner['basis']['AC'])
        self.assertEqual([c['basis']['X'] for c in case['corners']],
                         [[0.0, 0.0, 0.0, 1.0], [1.0, 0.0, 0.0, 1.0], [1.0, 0.0, 0.0, 1.0]])
        self.assertEqual([c['basis']['AC'] for c in case['corners']],
                         [[1.0, 0.0, 0.0, -1.0]] * 3)

    def test_saltstone_edit_does_not_preserve_the_x_appearance(self):
        """This is the provenance report's open question, answered. The AA sign
        change reverses the green contribution on the two corners where X had a
        usable basis, and creates one where X had none."""
        case = contract.saltstone_face_11823(REAL['X'], REAL['AA'], REAL['AC'], self.roles)
        self.assertEqual(case['summary']['XvsAAcomparable'], 2)
        self.assertEqual(case['summary']['XvsAAgreenReversed'], 2)
        self.assertEqual(case['summary']['XAAPreserved'], 0)
        self.assertEqual(case['summary']['XACPreserved'], 0)
        self.assertFalse(case['corners'][0]['XvsAA'][contract.STRENGTH_MODELS[0]]['comparable'])
        self.assertEqual(case['corners'][0]['XvsAA'][contract.STRENGTH_MODELS[0]]['status'],
                         'degenerateFrame')
        for corner in case['corners'][1:]:
            for model in contract.STRENGTH_MODELS:
                self.assertAlmostEqual(corner['XvsAA'][model]['binormalAngleDegrees'], 180.)
                self.assertAlmostEqual(corner['XvsAA'][model]['greenComponentAngleDegrees'], 180.)
                self.assertGreater(corner['XvsAA'][model]['worldAngleDegrees'], 1.)

    def test_five_u_reversed_corners_are_present_and_float32_limited(self):
        case = contract.u_reversed_corners(self.cases, REAL['AC'], self.roles)
        self.assertEqual(case['summary']['corners'], 5)
        self.assertEqual(case['summary']['comparable'], 5)
        self.assertEqual(case['summary']['dPduIsCancellationNoise'], 5)
        self.assertLess(case['summary']['minUvUlps'], 1.)
        self.assertGreater(case['summary']['maxDPDUMagnitude'], 1e5)
        self.assertEqual(case['summary']['unconditionalAppearsPreserved'], 0)
        for corner in case['corners']:
            self.assertLess(corner['dotTangentDudu'], 0.)
            self.assertFalse(corner['suppliedBasis']['addressing']['sameTexel'] is False)
            self.assertIsNotNone(corner['derivativeBasis'])

    def test_singular_glyph_records_are_repaired_but_not_appearance_neutral(self):
        case = contract.singular_glyph_records(self.glyph_cases, REAL['AA'], REAL['AC'], self.roles)
        self.assertEqual(case['summary']['records'], 16)
        self.assertEqual(case['summary']['beforeDegenerate'], 16)
        self.assertEqual(case['summary']['afterDegenerate'], 0)
        self.assertEqual(case['summary']['nowSampleable'], 16)
        self.assertEqual(case['summary']['appearanceIdentical'], 0)
        for entry in case['entries']:
            self.assertEqual(entry['before'][:3], [1.0, 0.0, 0.0])
            self.assertAlmostEqual(abs(entry['orthogonalityBefore']), 1.)
            self.assertAlmostEqual(entry['orthogonalityAfter'], 0.)
            self.assertEqual(entry['after'][3], -1.0)

    def test_per_role_sweep_verifies_the_addressing_pair_for_every_textured_role(self):
        case = contract.per_role_sweep(REAL['AC'], self.roles)
        self.assertEqual(case['summary']['roles'], 14)
        self.assertEqual(case['summary']['texturedRoles'], 13)
        self.assertEqual(case['summary']['rolesPassing'], 13)
        self.assertEqual(case['summary']['sameTexel'], case['summary']['locations'])
        self.assertEqual(case['summary']['texelBoundaryAligned'], 0)
        self.assertGreater(case['summary']['locations'], 10000)
        for role, bucket in case['roles'].items():
            self.assertEqual(bucket['normalScale'], self.roles[role]['normalScale'])
            if not bucket['normalTexture']:
                self.assertEqual(bucket['locations'], 0)
            else:
                self.assertTrue(bucket['examples'])
                self.assertTrue(bucket['image']['available'])
                self.assertEqual(bucket['image']['sha256'],
                                 bucket['image']['mothSource']['expectedSha256'])
                self.assertLess(bucket['greenNeutral'], bucket['locations'])

    def test_exhaustive_address_sweep_covers_every_spec_valid_full_rank_corner(self):
        case = contract.exhaustive_address_sweep(REAL['AC'], self.roles)
        summary = case['summary']
        self.assertEqual(summary['roles'], 14)
        self.assertEqual(summary['texturedRoles'], 13)
        self.assertEqual(summary['bilinearMismatches'], 0)
        self.assertEqual(summary['sameBilinearSample'], summary['specValidCornersOnFullRankFaces'])
        self.assertTrue(summary['verdict'])
        self.assertEqual(summary['recordedMismatchExamples'], 0)
        # 452,058 corner occurrences sit on full-rank faces; the 36 that do not are
        # the reviewed zero tangent, whose frame has no sampled perturbation.
        self.assertEqual(summary['specValidCornersOnFullRankFaces'], 452058 - 36)
        self.assertGreater(summary['nearestTieCorners'], 0)
        self.assertLess(summary['nearestTieCorners'], summary['specValidCornersOnFullRankFaces'])
        for role, bucket in case['roles'].items():
            if bucket['normalTexture']:
                self.assertEqual(bucket['image']['width'], 512)
                self.assertEqual(bucket['image']['height'], 512)
                self.assertEqual(bucket['mismatches'], [])
            else:
                self.assertEqual(bucket['corners'], 0)

    def test_basis_preservation_isolates_exactly_the_reviewed_nineteen(self):
        case = contract.basis_preservation(REAL['X'], REAL['AC'])
        self.assertEqual(case['records'], 319065)
        self.assertEqual(case['changedRecords'], 19)
        self.assertEqual(case['unchangedRecords'], 319046)
        self.assertEqual({role: b['changedRecords'] for role, b in case['changedByRole'].items()},
                         {'saltstone': 3, 'ochre': 16})
        # Only the three saltstone corners change handedness; the sixteen glyph
        # records already stored w=-1 and AC replaces the parallel tangent
        # direction instead. So a wholesale W flip is not what happened.
        self.assertEqual(sum(1 for e in case['changed'] if e['wChanged']), 3)
        self.assertEqual(sum(1 for e in case['changed'] if e['beforeNonUnitT']), 1)
        self.assertFalse(any(e['afterNonUnitT'] or e['afterWNotSign'] for e in case['changed']))

    def test_strength_models_disagree_at_reviewed_strengths(self):
        case = contract.strength_model_divergence(self.roles)
        self.assertEqual(case['summary']['roles'], 13)
        self.assertGreater(case['summary']['maxAngleDegrees'], 1.)
        self.assertLess(case['summary']['maxAngleDegrees'], 90.)


@unittest.skipUnless(REAL['X'] and REAL['AC'], 'pinned X/AC GLB bytes are unavailable')
class ContractVerdict(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = contract.run()

    def test_report_declares_its_scope_and_boundaries(self):
        self.assertEqual(self.report['schema'], 'parallax-tangent-appearance-contract/v1')
        self.assertTrue(self.report['boundaries'])
        for boundary in self.report['boundaries']:
            self.assertIsInstance(boundary, str)
        self.assertEqual(self.report['uvTransform']['authoredToExported'], 'v_exported = 1 - v_authored')
        self.assertEqual(self.report['uvTransform']['wrap'], contract.REPEAT)
        self.assertEqual(sorted(self.report['imageOrigins']), ['blenderBottomUp', 'gltfTopDown'])
        for model, citation in self.report['strengthModels'].items():
            self.assertIn(':', citation)
            self.assertTrue(citation.strip())

    def test_report_is_json_serialisable_without_nan(self):
        text = json.dumps(self.report, indent=2, allow_nan=False)
        self.assertGreater(len(text), 10000)
        self.assertNotIn('NaN', text)

    def test_qualification_block_states_both_the_pass_and_the_gap(self):
        qualification = self.report['summary']['qualification']
        self.assertTrue(qualification['addressingPairHoldsExhaustively'])
        self.assertTrue(qualification['negativeControlsRejected'])
        self.assertFalse(qualification['saltstoneEditPreservesXAppearance'])
        self.assertTrue(qualification['saltstoneEditReversesGreen'])
        self.assertFalse(qualification['uReversedDerivativeAgreementProven'])
        self.assertTrue(qualification['glyphSingularFramesRepaired'])

    def test_qualified_by_identity_is_the_headline_number(self):
        qualified = self.report['summary']['qualifiedByIdentity']
        self.assertEqual(qualified['unchangedBasisRecords'], 319046)
        self.assertEqual(qualified['requiresCaseByCaseArgument'], 19)
        self.assertEqual(qualified['specValidCornersWithExhaustiveAddressingProof'], 452022)
        self.assertEqual(qualified['unchangedBasisRecords'] + qualified['requiresCaseByCaseArgument'],
                         self.report['cases']['basisPreservation']['records'])

    def test_boundaries_name_the_unproven_questions(self):
        joined = ' '.join(self.report['boundaries']).lower()
        for phrase in ('analytic', 'nearest-texel', 'authored', 'render', 'smoothing'):
            self.assertIn(phrase, joined)
        self.assertTrue(self.report['cases']['storedTangentOpposesDUCorners']['summary']['interpretation'])


if __name__ == '__main__':
    unittest.main()