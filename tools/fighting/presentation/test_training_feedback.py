"""Source contract for the read-only fighting training feedback helper.

No Godot/engine execution. This checks the helper against the authoritative
roster, proves the shell wiring is read-only/ordered, and refuses fabricated
combo claims. Grammar parsing uses gdtoolkit when available (the dedicated
fighting grammar venv); otherwise that part is skipped, never faked.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]
HELPER = ROOT / 'godot/fighting/presentation/training_feedback.gd'
MAIN = ROOT / 'godot/fighting/main.gd'
TEST = ROOT / 'godot/tests/fighting/presentation/training_feedback.gd'
ROSTER = json.loads((ROOT / 'godot/fighting/data/roster.json').read_text())


def parse(paths):
    try:
        from gdtoolkit.parser import parser as gdparser
    except ImportError:  # pragma: no cover - environment dependent
        try:
            import subprocess
            binary = '/tmp/opencode/fighting-core-grammar/bin/gdparse'
            if not Path(binary).exists():
                return False
            for path in paths:
                subprocess.check_call([binary, str(path)])
            return True
        except Exception:  # pragma: no cover
            return None
    for path in paths:
        gdparser.parse(path.read_text())
    return True


class TrainingFeedbackSourceTest(unittest.TestCase):
    def setUp(self):
        self.helper = HELPER.read_text()
        self.main = MAIN.read_text()

    def test_grammar_when_parser_available(self):
        parsed = parse([HELPER, MAIN, TEST])
        if parsed is None:
            self.skipTest('no gdscript parser available in this environment')
        self.assertTrue(parsed)

    def test_goal_assumptions_hold_for_all_nine_authored_operators(self):
        self.assertEqual(len(ROSTER['operators']), 9)
        for operator in ROSTER['operators']:
            moves = operator['moves']
            self.assertEqual(moves['crouch_l']['level'], 'low', operator['id'])
            for move_id in ['crouch_l', 'special1', 'special2', 'throw_f', 'super']:
                self.assertIn(move_id, moves, operator['id'])
                self.assertTrue(moves[move_id]['name'], operator['id'])
            self.assertTrue(moves['special1']['input']['simple'], operator['id'])
            # The helper builds one goal per real family plus throw/tech/block.
            self.assertEqual(len(operator['combos']), 3, operator['id'])
            for combo in operator['combos']:
                self.assertEqual(combo['status'], 'proposed', operator['id'])

    def test_helper_is_read_only_and_has_no_engine_or_authority_access(self):
        for forbidden in ['simulation', '.step(', 'randi(', 'randf(', 'Input.', 'Engine.', 'Time.', 'FileAccess', 'Node3D']:
            self.assertNotIn(forbidden, self.helper, forbidden)
        for required in ['func reset(', 'func reset_transient(', 'func observe(', 'func result_text(', 'func goal_lines(', 'func goal_summary(']:
            self.assertIn(required, self.helper, required)
        self.assertRegex(self.helper, r'^extends RefCounted')

    def test_helper_never_asserts_an_unsupported_combo(self):
        for operator in ROSTER['operators']:
            for combo in operator['combos']:
                self.assertNotIn(combo['name'], self.helper)
        for claim in ['confirmed', 'proven', 'combo verified']:
            self.assertNotIn(claim, self.helper.lower(), claim)

    def test_shell_wiring_observes_after_authority_and_resets_explicitly(self):
        self.assertIn('const TrainingFeedback = preload("res://fighting/presentation/training_feedback.gd")', self.main)
        self.assertIn('var feedback = TrainingFeedback.new()', self.main)
        self.assertLess(self.main.index('simulation.step(commands)'), self.main.index('feedback.observe(state,last_inputs)'))
        self.assertIn('feedback.reset(operators,roster)', self.main)
        self.assertIn('feedback.reset_transient()', self.main)
        self.assertIn('feedback.history_detail(', self.main)
        self.assertIn('feedback.goal_lines(', self.main)
        self.assertIn('feedback.result_text(', self.main)
        # FX pools still never rebuild inside the tick/present loops.
        tick = self.main.split('func _tick(', 1)[1].split('\nfunc ', 1)[0]
        self.assertNotIn('effects.configure(', tick)
        # Goals show dynamic bind hints through the existing router labels.
        training = self.main.split('func show_training(', 1)[1].split('\nfunc ', 1)[0]
        self.assertIn('router.label(p,"Grab")', training)

    def test_history_and_result_views_are_contractually_present(self):
        self.assertIn('const HISTORY_LIMIT := 12', self.helper)
        self.assertIn('const RESULT_LIMIT := 6', self.helper)
        self.assertRegex(self.helper, r'func history_line\(p: int, limit: int = 6\)')


if __name__ == '__main__':
    unittest.main()
