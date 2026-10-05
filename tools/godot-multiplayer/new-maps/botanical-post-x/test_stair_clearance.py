"""Tests for the height-preserving stair collision proposal.

Source-only and deterministic. Covers the three required synthetic fixtures --
plain edge > 46 deg, beveled edge <= 46 deg, height-preserved tread -- plus the
authority/geometry invariants and the nav490 regression.

Run from this directory:  python3 -m unittest test_stair_clearance -v
"""
import json
import math
import re
import unittest

import stair_clearance as sc


class SyntheticStepFixtures(unittest.TestCase):
    """Required fixture matrix over synthetic rises and both capsule radii."""

    RISES = (0.15, 0.18, 2 / 14, 0.20, 0.42)
    PROFILES = (sc.EXPLORATION, sc.GAME_ENVELOPE)

    def test_plain_edge_exceeds_46_degrees_at_every_synthetic_rise(self):
        """A 90 deg ascent corner is a wall: no synthetic rise is climbable."""
        for rise in self.RISES:
            for profile in self.PROFILES:
                with self.subTest(rise=rise, profile=profile["label"]):
                    sweep = sc.sweep_angle(rise, profile["radius"], profile["separation"], 0.0)
                    self.assertIsNotNone(sweep["worst_angle_deg"])
                    self.assertGreater(
                        sweep["worst_angle_deg"],
                        sc.FLOOR_MAX_ANGLE_DEG,
                        f"plain edge for rise {rise} / {profile['label']} should exceed 46 deg",
                    )

    def test_a_042_m_rise_is_out_of_reach_for_a_035_capsule(self):
        """An honest limit of the proposal, stated rather than hidden.

        A 0.42 m rise is larger than either Vesper run (0.15 m, 2/14 m). No bevel
        short of a half-metre fixes it for the 0.35 exploration capsule, which is
        why the recommendation is a per-rise admissibility window.
        """
        self.assertIsNone(sc.minimum_admissible_leg(0.42, sc.EXPLORATION))
        self.assertIsNotNone(sc.minimum_admissible_leg(0.42, sc.GAME_ENVELOPE))
        for rise, _ in ((0.15, None), (2 / 14, None), (0.18, None), (0.20, None)):
            self.assertLess(rise, 0.30, "Vesper-scale rises are within bevel reach")

    def test_beveled_edge_is_at_or_below_46_degrees(self):
        """At each rise's own minimum admissible leg the bevel is within 46 deg.

        A leg tuned for the Vesper 0.15 m rise is not sufficient for a larger
        synthetic rise, so each rise gets its own leg. Rises too large for a
        0.35 m capsule to climb report no admissible leg and are covered by
        ``test_a_042_m_rise_is_out_of_reach_for_a_035_capsule``.
        """
        for rise in self.RISES:
            for profile in self.PROFILES:
                leg = sc.minimum_admissible_leg(rise, profile)
                if leg is None:
                    if profile["label"] == sc.EXPLORATION["label"] and rise >= 0.30:
                        continue  # documented above as out of reach
                    self.fail(f"rise {rise} / {profile['label']} unexpectedly has no admissible leg")
                with self.subTest(rise=rise, profile=profile["label"], leg=leg):
                    sweep = sc.sweep_angle(rise, profile["radius"], profile["separation"], leg)
                    self.assertFalse(sweep["any_over_46"])
                    self.assertLessEqual(sweep["worst_angle_deg"], sc.FLOOR_MAX_ANGLE_DEG)

    def test_height_preserved_tread_keeps_its_exact_plane(self):
        """The beveled top face reuses the authored Y bit-for-bit."""
        treads = sc.civic_treads_from_authority()
        window = sc.admissible_window(treads + sc.roof_steps_from_evidence(), sc.audited_points() + sc.contact_feet())
        for tread in treads:
            with self.subTest(tread=tread.id):
                proposal = sc.bevel_triangles(tread, window["midpoint"])
                self.assertEqual(sc.bits(proposal["top_plane_y"]), sc.bits(tread.y))
                for triangle in proposal["top_triangles"]:
                    for vertex in triangle:
                        self.assertEqual(sc.bits(vertex[1]), sc.bits(tread.y))

    def test_too_small_a_bevel_does_not_reach_the_face(self):
        """Documents why 0.02-0.04 m fails despite being 'industry typical'."""
        for leg in (0.02, 0.03, 0.04):
            with self.subTest(leg=leg):
                sweep = sc.sweep_angle(0.15, sc.EXPLORATION["radius"], 0.0, leg)
                self.assertGreater(sweep["worst_angle_deg"], sc.FLOOR_MAX_ANGLE_DEG)
                # The contact is the bevel's own lower edge, not its face, so the
                # normal is edge-steep and the fix does not actually take.
                self.assertEqual(sweep["worst_feature"], "bevel lower edge")


class ContactModel(unittest.TestCase):
    def test_unbeveled_band_matches_the_documented_guard_figures(self):
        """Cross-check against the reviewed 47.5-51.3 deg band.

        BLOCKERS_EFFICIENCY_20261005.md and the post-X README report the guard
        observing ~47.5-51.3 deg on stairs. This is an independent analytic
        reproduction, not a native run, so it is checked as a band and not
        claimed as the same measurement.
        """
        angles = [
            sc.sweep_angle(rise, profile["radius"], 0.0, 0.0)["worst_angle_deg"]
            for profile in (sc.EXPLORATION, sc.GAME_ENVELOPE)
            for rise in (0.15, 2 / 14)
        ]
        self.assertTrue(all(a is not None for a in angles))
        self.assertLess(min(angles), 47.5, "at least one profile must exceed the documented band's floor")
        self.assertLess(max(angles), 52.0, "model exceeds the documented band's ceiling")
        for angle in angles:
            with self.subTest(angle=angle):
                self.assertGreater(angle, sc.FLOOR_MAX_ANGLE_DEG)

    def test_contact_normal_is_zero_on_a_flat_tread(self):
        """No bevel, capsule resting squarely on the tread: support is flat."""
        contact = sc.stair_contact(0.15, 0.35, 0.0, 0.0, 0.0)
        self.assertIn(contact.feature, ("lower top plane", "plain corner"))
        self.assertLessEqual(contact.angle_deg, sc.FLOOR_MAX_ANGLE_DEG)

    def test_deeper_penetration_never_reduces_below_the_bevel_face(self):
        """Once the capsule is on the bevel face the normal is the face normal."""
        leg = 0.0434
        angles = []
        for gap in sc.APPROACH_GAPS:
            contact = sc.stair_contact(0.15, 0.35, 0.0, gap, leg)
            if contact.penetration > 1e-12:
                angles.append(contact.angle_deg)
        self.assertTrue(angles)
        self.assertLessEqual(max(angles), sc.FLOOR_MAX_ANGLE_DEG)

    def test_radius_042_envelope_also_fits(self):
        for rise in (0.15, 2 / 14):
            with self.subTest(rise=rise):
                sweep = sc.sweep_angle(rise, 0.42, 0.0, 0.0434)
                self.assertFalse(sweep["any_over_46"])

    def test_cos_margin_is_far_outside_float32_noise(self):
        """The 1 deg guard margin dwarfs the guard's own numeric budget."""
        margin = math.cos(math.radians(45.0)) - sc.COS_FLOOR_MAX_ANGLE
        self.assertGreater(margin, 1e-3)
        self.assertGreater(margin, sc.SAFE_MARGIN / 100.0)


class AuthorityIntegrity(unittest.TestCase):
    def test_civic_run_matches_recipe_authoring(self):
        treads = sc.civic_treads_from_authority()
        self.assertEqual(len(treads), 80)
        self.assertEqual([t.id for t in treads], [f"civic-stair-{i}" for i in range(80)])
        for index, tread in enumerate(treads):
            self.assertEqual(tread.z0, 25 + index * 0.5)
            self.assertEqual(tread.y, 12 + (index + 1) * 0.15)
            self.assertEqual(tread.rise, 0.15)

    def test_roof_run_matches_recipe_v2_authoring(self):
        steps = sc.roof_steps_from_evidence()
        self.assertEqual(len(steps), 14)
        for index, step in enumerate(steps):
            self.assertAlmostEqual(step.z0, 53 + index * 12 / 14, places=9)
            self.assertAlmostEqual(step.y, 22 + (index + 1) * 2 / 14, places=9)

    def test_roof_run_is_absent_from_the_accepted_runtime_world(self):
        """Stated as a fact of the authority, not assumed by the analysis."""
        arena = json.loads(sc.AUTHORITY.read_text())["arena"]
        ids = {s["id"] for s in arena["terrain"]["surfaces"]}
        self.assertNotIn("roof-ramp-step-0", ids)
        self.assertIn("civic-stair-0", ids)

    def test_all_354_tread_contacts_are_ascent_edge_contacts(self):
        """Every tread contact in the pinned evidence is a leading-edge hit."""
        records = json.loads(sc.CONTACTS.read_text())["records"]
        treads = sc.civic_treads_from_authority() + sc.roof_steps_from_evidence()
        by_id = {t.id: t for t in treads}
        tread_contacts = 0
        for record in records:
            for contact in record["contacts"]:
                if contact["id"] not in by_id:
                    continue
                tread_contacts += 1
                ys = [p[1] for tri in contact["triangles"] for p in tri]
                zs = [p[2] for tri in contact["triangles"] for p in tri]
                self.assertAlmostEqual(min(ys), max(ys), places=9)
                self.assertAlmostEqual(min(zs), by_id[contact["id"]].z0, places=9)
        self.assertEqual(tread_contacts, 354)

    def test_geometry_diff_touches_only_the_beveled_treads(self):
        treads = sc.civic_treads_from_authority() + sc.roof_steps_from_evidence()
        diff = sc.geometry_diff(treads, 0.0434)
        self.assertEqual(len(diff["affected_treads"]), len(treads))
        self.assertEqual(diff["unaffected_treads"], [])
        self.assertTrue(diff["top_planes_bit_identical"])
        self.assertEqual(
            diff["output_face_count"] - diff["input_face_count"],
            2 * len(treads),
            "each beveled tread adds exactly two chamfer triangles",
        )

    def test_bevel_wedges_hit_no_other_collider(self):
        clearance = sc.overhead_clearance(sc.civic_treads_from_authority(), sc.AUTHORITY, 0.0434)
        self.assertEqual(clearance["wedge_clashes"], [])
        self.assertTrue(clearance["subtractive_only"])
        self.assertFalse(clearance["overhead_clearance_affected"])

    def test_bevel_only_lowers_geometry_so_headroom_can_only_grow(self):
        """A pure subtraction cannot reduce clearance above a tread."""
        treads = sc.civic_treads_from_authority()
        for tread in treads:
            proposal = sc.bevel_triangles(tread, 0.0434)
            for triangle in proposal["chamfer_triangles"]:
                for vertex in triangle:
                    self.assertLessEqual(vertex[1], tread.y + 1e-12)


class AppliedApron(unittest.TestCase):
    """The support-visible apron is present in the built world, exactly as analysed.

    These are the load-bearing checks for the 2026-10-05 support-visible redesign:
    the analysis proves a *design*, and these prove the built authority carries
    that geometry, that the tread tops are still the authored ones, and that the
    face is inside the map's support-query slope budget.
    """

    def setUp(self):
        self.report = sc.build_report()
        self.applied = self.report["appliedTreatment"]
        self.treads = sc.civic_treads_from_authority()
        arena = json.loads(sc.AUTHORITY.read_text())["arena"]
        self.arena = arena
        self.surfaces = {s["id"]: s for s in arena["terrain"]["surfaces"]}

    def test_all_eighty_civic_treads_carry_a_walkable_apron(self):
        self.assertEqual(len(self.treads), 80)
        for tread in self.treads:
            with self.subTest(tread=tread.id):
                apron = self.surfaces[f"{tread.id}-apron"]
                self.assertTrue(apron["walkable"], "a non-walkable apron is not floor")
                self.assertEqual(apron["material"], "sandstone")
                self.assertEqual(apron["triangles"], [[0, 1, 2], [0, 2, 3]])
                self.assertGreater(tread.apron_run, 0.0)
                self.assertGreater(tread.apron_slope, 0.0)

    def test_the_apron_face_is_inside_the_support_query_slope_budget(self):
        """The whole point: a 45 deg face is invisible here, 40.03 deg is not."""
        self.assertTrue(self.applied["supportVisible"])
        angle = self.applied["apronFaceAngleDeg"]
        self.assertLessEqual(angle, sc.TERRAIN_MAX_SLOPE_DEG)
        self.assertGreaterEqual(angle, 39.0, "no point being shallower than the budget allows")
        # And the 45 deg chamfer that preceded it really is inadmissible.
        self.assertTrue(
            math.cos(math.radians(45.0)) < sc.COS_TERRAIN_MAX_SLOPE - sc.SUPPORT_EPSILON,
            "the chamfer this replaced was inside the budget; the redesign is moot",
        )

    def test_the_apron_clears_the_controller_guard_with_margin(self):
        self.assertLessEqual(self.applied["contactNormalDeg"], sc.FLOOR_MAX_ANGLE_DEG)
        self.assertGreater(self.applied["guardMarginDeg"], 1.0)
        self.assertTrue(self.applied["capsuleRestsOnFace"])
        self.assertTrue(self.applied["runWithinGoing"])

    def test_the_apron_meets_both_authored_planes_exactly(self):
        """Continuous profile: the base sits on the lower tread, the apex on this one."""
        for tread in self.treads:
            with self.subTest(tread=tread.id):
                self.assertEqual(sc.bits(tread.apron_y(tread.z0)), sc.bits(tread.y))
                self.assertEqual(sc.bits(tread.apron_y(tread.apron_start_z)), sc.bits(tread.y - tread.rise))
                self.assertIsNone(tread.apron_y(tread.z0 + 1e-6), "apron must not spill onto the tread")
                self.assertIsNone(tread.apron_y(tread.apron_start_z - 1e-6))

    def test_the_tread_tops_are_still_exactly_the_authored_geometry(self):
        """The whole safety argument: an additive apron cannot shorten a tread."""
        for tread in self.treads:
            with self.subTest(tread=tread.id):
                self.assertEqual(tread.z0, 25 + int(tread.id.split("-")[-1]) * 0.5)
                self.assertEqual(tread.y, 12 + (int(tread.id.split("-")[-1]) + 1) * 0.15)
                top = self.surfaces[tread.id]
                self.assertTrue(top["walkable"])
                zs = [v[2] for face in top["triangles"] for v in (top["vertices"][i] for i in face)]
                self.assertEqual(min(zs), tread.z0)
                self.assertEqual(max(zs), tread.z1)

    def test_the_apron_adds_exactly_two_faces_per_tread_and_changes_nothing_else(self):
        surfaces = self.arena["terrain"]["surfaces"]
        tops = [s for s in surfaces if re.fullmatch(r"civic-stair-\d+", s["id"])]
        aprons = [s for s in surfaces if re.fullmatch(r"civic-stair-\d+-apron", s["id"])]
        self.assertEqual(len(tops), 80)
        self.assertEqual(len(aprons), 80)
        self.assertTrue(all(len(s["triangles"]) == 2 for s in tops))
        self.assertTrue(all(len(s["triangles"]) == 2 for s in aprons))
        self.assertEqual(sum(len(s["triangles"]) for s in aprons), 2 * 80)

    def test_no_audited_point_loses_support_and_nav490_is_quantified(self):
        column = self.applied["columnAudit"]
        self.assertEqual(column["audited"], 765)
        self.assertEqual(column["losses"], 0)
        self.assertEqual(column["maxLoss"], 0.0)
        self.assertEqual(self.applied["heightPreservation"]["genuine_support_losses"], 0)
        self.assertTrue(self.applied["heightPreservation"]["capsule_preserved"])
        # nav490 is a documented pin: it is not silently preserved, it is reported.
        nav = self.applied["nav490"]
        self.assertEqual(sc.bits(nav["authored_support_y"]), sc.bits(13.8))
        self.assertTrue(sc._within_ulps(nav["resolved_support_y"], 13.873636363636364, 64, 65.0))
        self.assertFalse(nav["nav490_bit_identical"])
        self.assertGreater(nav["resolved_delta_from_13_8"], 0.0)

    def test_the_applied_leg_is_the_proven_minimum_nav490_cost(self):
        """No admissible face can do better than +73.4 mm at nav490.

        Any support-visible face covering the civic rise needs a run of
        ``rise/tan(theta)``, and nav490 sits 0.090909 m before the riser at
        z=31.0, so its height becomes ``13.8 + 0.15 - 0.090909*tan(theta)``.
        The largest admissible ``tan(theta)`` is ``tan(terrain.maxSlope)``, which
        minimises the raise. Verified here at the true optimum and at the shipped
        slope, which is 0.2 mm worse.
        """
        gap = 31.0 - 30.90909090909091
        best = 13.8 + 0.15 - gap * math.tan(sc.TERRAIN_MAX_SLOPE_RAD)
        shipped = 13.8 + 0.15 - gap * sc.APRON_SLOPE
        self.assertGreaterEqual(best, 13.8)
        self.assertLessEqual(shipped, best + 1e-3)
        self.assertGreater(shipped, best)
        self.assertLess(shipped - 13.8, 0.075)

    def test_the_design_space_is_empty_for_the_hypothetical_and_that_is_why(self):
        """A subtractive or shallower-than-visible treatment cannot work at all."""
        space = self.applied["designSpace"]
        self.assertFalse(space["nonEmpty"])
        civic = space["budgets"]["civic"]
        self.assertGreater(civic["minFaceAngleForFullRiseDeg"], sc.FLOOR_MAX_ANGLE_DEG)
        self.assertLess(civic["maxRiseWithinBudget"], civic["rise"])


class SupportQueryRules(unittest.TestCase):
    """The rules this redesign exists to satisfy, read from source and pinned."""

    def test_the_rules_are_documented_with_their_source_lines(self):
        rules = sc.support_query_rules()
        self.assertIn("game/terrain.mjs:92-107 terrainSupportAt", rules["sources"])
        self.assertEqual(rules["predicates"]["P5_slopeBudget"].count("cos(terrain.maxSlope)"), 1)
        self.assertIsNone(rules["fallback"])
        self.assertIsNone(rules["searchRadius"])

    def test_the_authored_slope_budget_is_the_one_that_binds(self):
        arena = json.loads(sc.AUTHORITY.read_text())["arena"]
        self.assertEqual(arena["terrain"]["maxSlope"], sc.TERRAIN_MAX_SLOPE_RAD)

    def test_the_gradient_bound_is_tan_max_slope(self):
        self.assertAlmostEqual(sc.max_admissible_gradient(), math.tan(0.7), places=15)
        self.assertLess(sc.max_admissible_gradient(), math.tan(math.radians(sc.FLOOR_MAX_ANGLE_DEG)))


class HeightPreservation(unittest.TestCase):
    def setUp(self):
        self.treads = sc.civic_treads_from_authority() + sc.roof_steps_from_evidence()
        self.points = sc.audited_points() + sc.contact_feet()
        self.window = sc.admissible_window(self.treads, self.points)
        self.leg = self.window["midpoint"]

    def test_admissible_window_is_bounded_on_both_sides(self):
        self.assertTrue(self.window["exists"])
        self.assertLess(self.window["guard_floor"], self.window["upper"])
        self.assertTrue(self.window["within_guard"])
        self.assertTrue(self.window["preserves"])

    def test_no_audited_point_genuinely_loses_support(self):
        result = sc.height_preservation(self.treads, self.points, self.leg)
        self.assertEqual(result["genuine_support_changes"], [])
        self.assertTrue(result["preserved"])
        self.assertGreater(result["resolved"], 100)

    def test_every_affected_point_stays_capsule_supported(self):
        result = sc.height_preservation(self.treads, self.points, self.leg)
        for change in result["support_changed"]:
            with self.subTest(point=change["point"]):
                self.assertTrue(change["capsule_preserved"])

    def test_only_seam_ambiguity_remains_and_is_reported(self):
        """navNode[493] sits exactly on the z=42.5 seam: pre-existing ambiguity."""
        result = sc.height_preservation(self.treads, self.points, self.leg)
        self.assertEqual(len(result["seam_ambiguity_only"]), 1)
        seam = result["seam_ambiguity_only"][0]
        self.assertEqual(seam["point"], "navNode[493]")
        self.assertEqual(seam["z"], 42.5)
        self.assertEqual(seam["before"], 17.4)
        self.assertEqual(seam["after"], 17.25)
        self.assertEqual(seam["capsule_before"], seam["capsule_after"])

    def test_a_leg_beyond_the_window_does_lose_support(self):
        """Proves the ceiling is a real constraint, not slack in the audit."""
        result = sc.height_preservation(self.treads, self.points, self.window["upper"] + 0.02)
        self.assertFalse(result["preserved"])
        self.assertTrue(result["genuine_support_changes"])

    def test_beveling_the_descent_face_is_not_height_preserving(self):
        """Documents why the recommendation is the ascent face only."""
        result = sc.height_preservation(self.treads, self.points, self.leg, edge="both")
        self.assertFalse(result["preserved"])


class Nav490Regression(unittest.TestCase):
    def setUp(self):
        self.nav = sc.nav490_regression(sc.civic_treads_from_authority())

    def test_bevel_keeps_nav490_at_exactly_13_8(self):
        self.assertEqual(self.nav["bevel_support_y"], 13.8)
        self.assertEqual(sc.bits(self.nav["bevel_support_y"]), sc.bits(13.8))
        self.assertTrue(self.nav["bevel_preserves_fixed_y"])

    def test_naive_ramp_reproduces_the_documented_regression(self):
        self.assertTrue(self.nav["naive_ramp_matches_readme"])
        self.assertAlmostEqual(self.nav["naive_ramp_support_y"], 13.772727272727272, places=12)
        self.assertAlmostEqual(self.nav["naive_ramp_delta"], -0.027272727272728, places=12)

    def test_tread_faithful_ramp_also_breaks_nav490(self):
        """A 'better' ramp is still a height change: the treads are the contract."""
        self.assertNotAlmostEqual(self.nav["tread_faithful_ramp_support_y"], 13.8, places=6)
        self.assertGreater(abs(self.nav["tread_faithful_ramp_delta"]), 0.05)

    def test_nav490_stands_on_civic_stair_11_not_12(self):
        self.assertEqual(self.nav["supporting_tread"], "civic-stair-11")

    def test_nav490_foot_is_clear_of_the_beveled_band(self):
        self.assertGreater(self.nav["foot_clearance_to_bevel_m"], 0.045)


class Report(unittest.TestCase):
    def setUp(self):
        self.report = sc.build_report()

    def test_report_is_deterministic(self):
        again = sc.build_report()
        self.assertEqual(json.dumps(self.report, sort_keys=True), json.dumps(again, sort_keys=True))

    def test_recommendation_is_admissible_and_mid_window(self):
        rec = self.report["recommended"]
        self.assertEqual(rec["leg"], self.report["admissibleWindow"]["midpoint"])
        self.assertLessEqual(rec["margin_to_floor_max_angle_deg"], 1.0)
        self.assertGreater(rec["margin_to_floor_max_angle_deg"], 0.0)

    def test_scope_makes_no_native_or_runtime_claim(self):
        scope = self.report["scope"]
        self.assertIn("source-only", scope)
        self.assertIn("no engine run", scope)

    def test_contact_effect_matches_the_pinned_record_count(self):
        effect = self.report["contactEffect"]
        self.assertEqual(effect["records"], 368)
        self.assertEqual(effect["contact_entries"], 356)
        self.assertEqual(effect["tread_ascent_edge_contacts"], 354)
        self.assertEqual(effect["non_tread_contacts"], 2)

    def test_non_tread_contacts_are_roof_terrace_walls_not_stairs(self):
        """The 2 remaining contacts are a wall pair on the roof terrace deck."""
        examples = self.report["contactEffect"]["non_tread_examples"]
        self.assertEqual(len(examples), 2)
        for example in examples:
            self.assertIn("central-row-16-45", example)

    def test_synthetic_fixture_matrix_reports_the_three_required_cases(self):
        fixtures = self.report["syntheticFixtures"]["required"]
        self.assertEqual(
            fixtures,
            ["plain edge > 46 deg", "beveled edge <= 46 deg", "height-preserved tread"],
        )
        rows = self.report["syntheticFixtures"]["fixtures"]
        self.assertTrue(rows)
        for row in rows:
            with self.subTest(rise=row["rise"], profile=row["profile"]):
                # The matrix must be internally consistent: a row is over 46 deg
                # unbeveled iff the report says so, and its own minimum leg
                # must be admissible whenever one exists.
                leg = row["minimum_admissible_leg"]
                self.assertEqual(
                    row["plain_over_46"],
                    sc.sweep_angle(row["rise"], row["radius"], row["separation"], 0.0)["any_over_46"],
                )
                if leg is None:
                    self.assertIsNone(row["at_minimum_leg_ok"])
                    continue
                self.assertTrue(row["at_minimum_leg_ok"])
                sweep = sc.sweep_angle(row["rise"], row["radius"], row["separation"], leg)
                self.assertFalse(sweep["any_over_46"])
                self.assertLessEqual(sweep["worst_angle_deg"], sc.FLOOR_MAX_ANGLE_DEG)

    def test_required_plain_over_46_case_holds_for_the_resting_profiles(self):
        """The required 'plain edge > 46 deg' fixture, stated directly."""
        for rise in (0.15, 0.18, 2 / 14, 0.20):
            for profile in (sc.EXPLORATION, sc.GAME_ENVELOPE):
                with self.subTest(rise=rise, profile=profile["label"]):
                    self.assertGreater(
                        sc.sweep_angle(rise, profile["radius"], profile["separation"], 0.0)["worst_angle_deg"],
                        sc.FLOOR_MAX_ANGLE_DEG,
                    )

    def test_evidence_file_is_not_written_by_the_test(self):
        """build_report is pure; only main() writes."""
        self.assertTrue(sc.EVIDENCE.name.endswith(".json"))
        self.assertEqual(sc.EVIDENCE.parent, sc.HERE)


if __name__ == "__main__":
    unittest.main(verbosity=2)