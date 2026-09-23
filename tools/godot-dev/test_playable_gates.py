"""Keep playable-port feature coverage in the canonical verifier, not ad-hoc runs."""
import ast
from pathlib import Path
import unittest


class PlayableGatesTest(unittest.TestCase):
    def test_lattice_evidence_covers_topology(self):
        root = Path(__file__).resolve().parents[2]
        for lane in ("native-lattice-map", "native-lattice-economy", "native-lattice-physical"):
            with self.subTest(lane=lane):
                source = (root / "port" / lane / "run.mjs").read_text()
                inventory = source.split("const sourceFiles = [", 1)[1].split("];", 1)[0]
                self.assertIn("'godot/lattice/topology.gd'", inventory)

    def test_feature_gates_are_registered_once(self):
        tree = ast.parse(Path(__file__).with_name("verify.py").read_text())
        command_list = next(
            node.value for node in tree.body
            if isinstance(node, ast.Assign)
            and any(isinstance(target, ast.Name) and target.id == "commands" for target in node.targets)
        )
        assert isinstance(command_list, ast.List)
        names = []
        commands = {}
        for node in command_list.elts:
            assert isinstance(node, ast.Tuple)
            name, arguments = node.elts
            assert isinstance(name, ast.Constant) and isinstance(arguments, ast.List)
            names.append(name.value)
            commands[name.value] = [item.value for item in arguments.elts if isinstance(item, ast.Constant)]
        self.assertEqual(len(names), len(set(names)), "Gate names must be unique")
        expected = {
            "route-parity": "tools/godot-package/route_parity.test.mjs",
            "blood-live-harness": "port/native-blood-fx/tests/live_budget.test.mjs",
            "main-menu-smoke": "res://ui/main_menu.tscn",
            "main-menu-contracts": "res://tests/main_menu/contracts.gd",
            "playable-gate-registration": "tools/godot-dev/test_playable_gates.py",
            "loadout-unit": "res://tests/loadouts/unit.gd",
            "loadout-source-parity": "res://tests/loadouts/parity.gd",
            "loadout-client": "res://tests/loadouts/client_frames.gd",
            "loadout-setup": "res://tests/loadouts/setup_menu.gd",
            "loadout-lobby": "res://tests/loadouts/lobby_menu.gd",
            "loadout-session": "res://tests/loadouts/session_flow.gd",
            "loadout-loopback": "godot/tests/loadouts/loopback.mjs",
            "loadout-lifecycle": "godot/tests/loadouts/loopback_lifecycle.test.mjs",
            "horde-upgrade-adapter": "port/native-horde/upgrade.test.mjs",
            "horde-upgrade-native": "res://tests/horde/upgrade_selection_test.gd",
            "horde-upgrade-fixture": "godot/tests/horde/upgrade_loopback.mjs",
            "lattice-topology": "res://tests/lattice/topology.gd",
        }
        for name, path in expected.items():
            with self.subTest(gate=name):
                self.assertTrue(name in commands, f"Missing gate: {name}")
                self.assertIn(path, commands[name])
                if path.endswith(".gd"):
                    self.assertIn("--script", commands[name])
                    self.assertLess(names.index("godot-import"), names.index(name))


if __name__ == "__main__":
    unittest.main()
