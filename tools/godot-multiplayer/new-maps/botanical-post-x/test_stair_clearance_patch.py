"""Guard the review-only builder patch against drift from the proven geometry.

The patch is documentation plus diff hunks, so nothing enforces that its
literals still match what ``stair_clearance.py`` computed. These tests pin the
contract: the leg literal, the first civic tread's emitted triangles, and the
patch's own claims about counts and provenance.
"""
import json
import re
import unittest

import stair_clearance as sc


class PatchLiteral(unittest.TestCase):
    def setUp(self):
        self.patch = sc.PATCH.read_text()
        self.leg = sc.build_report()["recommended"]["leg"]

    def test_patch_contains_the_proven_leg_literal(self):
        literals = re.findall(r"STAIR_BEVEL\s*=\s*([0-9.]+);", self.patch)
        self.assertEqual(len(literals), 2, "both recipe hunks must declare STAIR_BEVEL")
        self.assertEqual(literals[0], literals[1], "the two hunks must agree")
        self.assertEqual(float(literals[0]), self.leg)
        self.assertEqual(sc.bits(float(literals[0])), sc.bits(self.leg))

    def test_patch_literal_is_the_window_midpoint(self):
        literal = float(re.search(r"STAIR_BEVEL\s*=\s*([0-9.]+);", self.patch).group(1))
        window = sc.admissible_window(
            sc.civic_treads_from_authority() + sc.roof_steps_from_evidence(),
            sc.audited_points() + sc.contact_feet(),
        )
        self.assertGreater(literal, window["guard_floor"])
        self.assertLess(literal, window["nav_ceiling"])
        self.assertAlmostEqual(literal, window["midpoint"], places=15)

    def test_patch_geometry_example_matches_the_tool(self):
        """The tread-0 numbers quoted in the patch are the tool's real output."""
        tread = sc.civic_treads_from_authority()[0]
        proposal = sc.bevel_triangles(tread, self.leg)
        self.assertEqual(
            proposal["top_triangles"],
            [
                [[30, 12.15, 25.043438367470067], [30, 12.15, 25.5], [34, 12.15, 25.5]],
                [[30, 12.15, 25.043438367470067], [34, 12.15, 25.5], [34, 12.15, 25.043438367470067]],
            ],
        )
        self.assertEqual(
            proposal["chamfer_triangles"],
            [
                [[30, 12.106561632529933, 25], [30, 12.15, 25.043438367470067], [34, 12.15, 25.043438367470067]],
                [[30, 12.106561632529933, 25], [34, 12.15, 25.043438367470067], [34, 12.106561632529933, 25]],
            ],
        )


class PatchClaims(unittest.TestCase):
    def setUp(self):
        self.patch = sc.PATCH.read_text()
        self.report = sc.build_report()

    def test_patch_declares_itself_unapplied(self):
        for phrase in ("NOT APPLIED", "requires a separate reviewed grant"):
            self.assertIn(phrase, self.patch)

    def test_patch_states_the_184_contacts_remain_failed(self):
        self.assertIn("184 static contacts remain failed", self.patch)

    def test_patch_face_delta_claim_matches_the_tool(self):
        diff = self.report["geometryDiff"]
        treads = sc.civic_treads_from_authority() + sc.roof_steps_from_evidence()
        self.assertEqual(len(treads), 94)
        self.assertEqual(diff["output_face_count"] - diff["input_face_count"], 2 * len(treads))
        self.assertIn(f"{diff['input_face_count']} -> {diff['output_face_count']}", self.patch)

    def test_patch_flags_the_roof_run_as_candidate_only(self):
        self.assertIn("candidate-only", self.patch)
        self.assertIn("highest-residual-risk", self.patch)
        self.assertFalse(self.report["stairRuns"]["roof"]["inRuntimeAuthority"])

    def test_patch_keeps_the_descent_face_unbeveled(self):
        self.assertIn("ascent (-Z) face only", self.patch)
        self.assertFalse(self.report["descentEdgeRejected"]["result"]["preserved"])

    def test_patch_lists_the_two_out_of_scope_wall_contacts(self):
        self.assertIn("central-row-16-45", self.patch)
        self.assertEqual(self.report["contactEffect"]["non_tread_contacts"], 2)

    def test_patch_requires_the_native_batch_before_being_considered(self):
        self.assertIn("Run this FIRST", self.patch)
        self.assertIn("controller_journey.gd", sc.PATCH.parent.joinpath("NATIVE_BINDING_FOLLOWUP.md").read_text())


class ProposalDocument(unittest.TestCase):
    def setUp(self):
        self.doc = (sc.ROOT / "port/finish/map-variety/VESPER_STAIR_COLLISION_PROPOSAL_20261005.md").read_text()
        self.report = sc.build_report()

    def test_proposal_states_it_is_a_proposal_only(self):
        self.assertIn("**Status: proposal only.**", self.doc)
        self.assertIn("**no native claim**", self.doc)

    def test_proposal_states_the_184_remain_failed(self):
        self.assertIn("184 static contacts remain failed", self.doc)

    def test_proposal_reports_the_real_angles_and_leg(self):
        rec = self.report["recommended"]
        self.assertIn("0.043438", self.doc)
        self.assertIn("**51.34°**", self.doc)
        self.assertIn("**47.27°**", self.doc)
        self.assertIn("45.0°", self.doc)
        self.assertAlmostEqual(rec["leg"], 0.043438367470067386)

    def test_proposal_reports_the_flagged_seam_case(self):
        self.assertIn("navNode[493]", self.doc)
        self.assertIn("17.4 → 17.25", self.doc)
        self.assertEqual(len(self.report["heightPreservation"]["seamAmbiguityOnly"]), 1)

    def test_proposal_reports_nav490_and_both_ramp_failures(self):
        self.assertIn("13.8, bit-identical", self.doc)
        self.assertIn("13.772727272727272", self.doc)
        self.assertIn("+0.100568 m", self.doc)

    def test_proposal_reports_audited_counts(self):
        self.assertIn("**765 points**", self.doc)
        self.assertEqual(self.report["heightPreservation"]["auditedPoints"], 765)

    def test_proposal_lists_the_rebuild_and_verification_steps(self):
        for step in ("**Rebuild**", "static contact census", "60-journey batch"):
            self.assertIn(step, self.doc)

    def test_proposal_documents_the_risks(self):
        for risk in ("Overhead collision", "Roof run", "Route resampling"):
            self.assertIn(risk, self.doc)

    def test_proposal_points_at_the_review_only_patch(self):
        self.assertIn("vesper-stair-bevel-20261005.patch", self.doc)

    def test_proposal_does_not_claim_the_guard_fully_passes(self):
        self.assertIn("remain\nunproven", self.doc)

    def test_proposal_reproduction_block_matches_reported_numbers(self):
        self.assertIn("admissible leg window: [0.041422, 0.045455] m", self.doc)
        window = self.report["admissibleWindow"]
        self.assertAlmostEqual(window["lower"], 0.041422, places=6)
        self.assertAlmostEqual(window["upper"], 0.045455, places=6)


class EvidenceArtifact(unittest.TestCase):
    def setUp(self):
        if not sc.EVIDENCE.exists():
            self.skipTest("stair-clearance-evidence.json not generated yet; run stair_clearance.py")
        self.evidence = json.loads(sc.EVIDENCE.read_text())

    def test_artifact_matches_a_freshly_built_report(self):
        self.assertEqual(json.dumps(self.evidence, sort_keys=True), json.dumps(sc.build_report(), sort_keys=True))

    def test_artifact_makes_no_native_claim(self):
        self.assertIn("source-only", self.evidence["scope"])
        self.assertFalse(self.evidence["documentedGuardBand"]["isNativeClaim"])
        self.assertEqual(
            self.evidence["documentedGuardBand"]["documentedProvenance"],
            "native guard observation, not reproduced here",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)