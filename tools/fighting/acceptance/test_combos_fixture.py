"""Source-only checks for the journeys combos fixture migration.

These never load Godot. They inspect the actual acceptance GDScript and reject a
regression to the obsolete top-level saved.fighters mutation, while proving the
scanner itself detects that pattern.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ACCEPTANCE = ROOT / 'godot' / 'tests' / 'fighting' / 'acceptance'
JOURNEYS = ACCEPTANCE / 'journeys.gd'

# The old fixture mutated fighter fields through a top-level array that the
# checksummed save_state envelope (state.fighters) does not expose.
INVALID_ENVELOPE = re.compile(r'\b(?:fixture|saved)\s*\.\s*(?:has\(\s*["\']fighters["\']\s*\)|fighters\s*\[)')


def invalid_envelope_mutation(text):
    return bool(INVALID_ENVELOPE.search(text))


def combos_source():
    source = JOURNEYS.read_text()
    body = source[source.index('func combos() -> void:'):]
    end = body.find('\nfunc ', 1)
    return body if end < 0 else body[:end]


def placement_guard_present(text):
    normalized = re.sub(r'\s+', ' ', text)
    return bool(re.search(r'training_place\(\{"fighters": placements\}\) '
                          r'if not expect\(sim\.last_error\.is_empty\(\)', normalized))


class CombosFixtureTests(unittest.TestCase):
    def test_combos_uses_public_training_placement(self):
        body = combos_source()
        self.assertIn('sim.training_place({"fighters": placements})', body)
        self.assertIn('if not expect(sim.last_error.is_empty()', body)
        self.assertIn('fresh([operator.id, operator.id], 23017, true)', body)
        for field in ('"x"', '"y"', '"meter"'):
            self.assertIn(field, body)
        # The obsolete envelope mutation and its load_state path are gone.
        self.assertNotIn('fixture.has("fighters")', body)
        self.assertNotIn('fixture.fighters[', body)
        self.assertNotIn('sim.load_state(fixture)', body)

    def test_corner_uses_the_reachable_wall_clamp(self):
        body = combos_source()
        self.assertIn('int(rules.stage_half_width) - 350', body)
        self.assertNotIn('int(rules.stage_half_width) - 330', body)

    def test_no_analogous_invalid_envelope_mutation(self):
        offenders = [str(path.relative_to(ROOT)) for path in sorted(ACCEPTANCE.rglob('*.gd'))
                     if invalid_envelope_mutation(path.read_text())]
        self.assertEqual(offenders, [])

    def test_scanner_flags_synthetic_regressions(self):
        self.assertTrue(invalid_envelope_mutation('if not fixture.has("fighters"):\n'))
        self.assertTrue(invalid_envelope_mutation('fixture.fighters[victim].x = victim_x\n'))
        self.assertTrue(invalid_envelope_mutation("saved.fighters[0].y = 1\n"))
        self.assertFalse(invalid_envelope_mutation('var state: Dictionary = sim.snapshot()\n'))
        self.assertFalse(invalid_envelope_mutation('f.x = clampi(int(f.x), -7650, 7650)\n'))

    def test_placement_guard_detects_missing_last_error_check(self):
        guarded = 'sim.training_place({"fighters": placements})\nif not expect(sim.last_error.is_empty(), "accepted"):\n'
        unguarded = 'sim.training_place({"fighters": placements})\n'
        self.assertTrue(placement_guard_present(guarded))
        self.assertFalse(placement_guard_present(unguarded))
        self.assertTrue(placement_guard_present(combos_source()))


if __name__ == '__main__':
    unittest.main()
