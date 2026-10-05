"""Pin the post-rebuild contact census for the Vesper stair bevel.

``census_bevel.py`` answers the rebuild's central question -- do the pinned X
contact positions still present a contact normal above the 46 degree
``floor_max_angle`` guard? These tests freeze its answer, including the part that
did **not** improve, so neither can drift silently.

Run from this directory:
    COCS_BOTANICAL_X_FIXTURE_ROOT=<repo> python3 -m unittest test_census_bevel
"""
import json
import unittest

import census_bevel as cb


class Census(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = cb.build_report()

    def test_the_contact_population_is_unchanged(self):
        """The rebuild changes geometry, never which contacts were observed."""
        self.assertEqual(self.report["records"], 368)
        self.assertEqual(self.report["contactEntries"], 356)
        self.assertEqual(self.report["treadAscensionEdgeContacts"], 354)
        self.assertEqual(self.report["nonTreadContacts"], 2)

    def test_the_two_out_of_scope_wall_contacts_persist(self):
        """A stair bevel cannot address these, and must not appear to have."""
        self.assertEqual(
            self.report["nonTreadColliders"], ["central-row-16-45-1602", "central-row-16-45-1603"]
        )
        accepted = self.report["byVariant"]["accepted"]
        self.assertEqual(accepted["nonTreadContacts"], 2)
        for label in ("exploration r.35", "x native r.41", "game envelope r.42"):
            with self.subTest(profile=label):
                self.assertEqual(accepted["profiles"][label]["wall"]["overlapping"], 2)
                self.assertGreater(accepted["profiles"][label]["wall"]["max_angle_deg"], 90.0)

    def test_the_rebuilt_accepted_civic_run_clears_the_guard(self):
        """The 170 accepted-variant civic contacts: none over 46 degrees."""
        accepted = self.report["byVariant"]["accepted"]
        self.assertEqual(accepted["runs"]["civic"], 170)
        self.assertEqual(accepted["runs"]["roof"], 0)
        for label in ("exploration r.35", "x native r.41", "game envelope r.42"):
            with self.subTest(profile=label):
                self.assertEqual(accepted["profiles"][label]["civic"]["overlapping_over_floor_max_angle"], 0)
        # The peak is the apron's own face, not the old 47-51 deg corner.
        peak = accepted["profiles"]["exploration r.35"]["civic"]["max_angle_deg"]
        self.assertLessEqual(peak, 46.0)
        self.assertGreater(peak, 39.0)

    def test_the_candidate_run_clears_the_guard_too(self):
        """Both runs are rebuilt, so the roof's 14 contacts clear as well.

        The 45 degree chamfer could not be rebuilt here: its band is shallower
        than ``terrain.maxSlope``, so the roof steps -- which have nothing
        underneath to fall back on -- lost their support and the candidate source
        gate failed. The support-visible apron restores them.
        """
        candidate = self.report["byVariant"]["candidate"]
        self.assertEqual(candidate["contacts"], 184)
        self.assertEqual(candidate["runs"]["civic"], 170)
        self.assertEqual(candidate["runs"]["roof"], 14)
        for label in ("exploration r.35", "x native r.41", "game envelope r.42"):
            with self.subTest(profile=label):
                self.assertEqual(candidate["profiles"][label]["civic"]["overlapping_over_floor_max_angle"], 0)
                self.assertEqual(candidate["profiles"][label]["roof"]["overlapping_over_floor_max_angle"], 0)

    def test_no_tread_contact_in_either_build_exceeds_the_guard(self):
        """The headline: 354/354 tread contacts under 46 degrees."""
        for variant in ("accepted", "candidate"):
            for label in ("exploration r.35", "x native r.41", "game envelope r.42"):
                with self.subTest(variant=variant, profile=label):
                    row = self.report["byVariant"][variant]["profiles"][label]["tread"]
                    self.assertEqual(row["overlapping_over_floor_max_angle"], 0)
                    self.assertLessEqual(row["max_angle_deg"], 46.0)

    def test_the_census_makes_no_native_claim(self):
        self.assertFalse(self.report["isNativeClaim"])
        self.assertIn("not a new native run", self.report["scope"])

    def test_the_frozen_evidence_is_not_rewritten(self):
        """The native record stays byte-identical; this tool reads it only."""
        self.assertIn("never regenerated", self.report["frozenEvidence"])
        self.assertTrue(cb.FROZEN.is_file())


if __name__ == "__main__":
    unittest.main(verbosity=2)