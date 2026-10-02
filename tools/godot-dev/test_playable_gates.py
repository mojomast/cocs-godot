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
            "finish-runner-tests": "tools/godot-dev/test_finish_runner.py",
            "finish-gameplay-source": "tools/port/pass-two-gameplay/source.mjs",
            "finish-gameplay-contract": "res://tests/player_gameplay/second_pass_test.gd",
            "finish-world-source": "scripts/world-weather-spatial-oracle.mjs",
            "finish-world-contract": "res://tests/world_weather/spatial.gd",
            "finish-challenge-source": "port/pass-two/modes/challenges.test.mjs",
            "finish-challenge-contract": "res://tests/mode_expansion/challenges_contracts.gd",
            "finish-spectator-source": "tools/experience/spectator-oracle.mjs",
            "finish-spectator-contract": "res://tests/experience/spectator_contract.gd",
            "finish-spectator-camera": "res://tests/experience/competitive_camera.gd",
            "finish-horde-guidance": "res://tests/horde_expansion/guidance_test.gd",
            "finish-audio-source": "tools/godot-audiovisual/expansion/telegraph.test.mjs",
            "finish-audio-contract": "res://tests/audio_expansion/threat_gate.gd",
            "finish-lattice-source": "tools/port/lattice/source-oracle.mjs",
            "finish-lattice-contract": "res://tests/lattice/expansion_feedback_contract.gd",
            "finish-controls-source": "tools/port/input-bindings/source-oracle.mjs",
            "finish-controls-contract": "res://tests/input_bindings/contracts.gd",
            "finish-replay-source": "tools/port/replay/adapter.test.mjs",
            "finish-caption-source": "tools/port/finish/caption-oracle.mjs",
            "finish-caption-integration": "res://tests/finish/caption_integration.gd",
            "finish-home-replays": "res://tests/finish/home_replays.gd",
            "finish-replay-bridge-negative": "res://tests/finish/replay_bridge_negative.gd",
            "finish-replay-bridge-source": "tools/port/finish/replay-bridge-contract.test.mjs",
            "finish-package-closure": "tools/godot-package/finishing_closure.test.mjs",
            "route-parity": "tools/godot-package/route_parity.test.mjs",
            "blood-live-harness": "port/native-blood-fx/tests/live_budget.test.mjs",
            "main-menu-smoke": "res://ui/main_menu.tscn",
            "main-menu-contracts": "res://tests/main_menu/contracts.gd",
            "playable-gate-registration": "tools/godot-dev/test_playable_gates.py",
            "verifier-report-tests": "tools/godot-dev/test_verifier_report.py",
            "native-ci-contracts": "port/native-ci/source-selection.test.mjs",
            "product-shell-supervisor": "tools/godot-package/menu_journey.test.mjs",
            "product-shell-settings": "res://tests/product_shell/settings_contract.gd",
            "product-shell-journey": "tools/godot-dev/product_journey.mjs",
            "product-shell-guest-leave": "tools/godot-dev/guest_leave_journey.mjs",
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
            "lattice-world-commands": "res://tests/lattice/world_commands_contract.gd",
            "lattice-req-generator-tests": "port/tools/native_lattice_req_catalog/export.test.mjs",
            "lattice-req-catalog-check": "port/tools/native_lattice_req_catalog/export.mjs",
            "lattice-req-catalog": "res://tests/lattice/req_catalog_contract.gd",
            "lattice-req-purchase": "res://tests/lattice/req_purchase_contract.gd",
            "lattice-world-tactical": "res://tests/lattice/world_tactical_contract.gd",
            "lattice-flagship-l1": "res://tests/lattice/flagship_l1_contract.gd",
            "lattice-flagship-l2": "res://tests/lattice/flagship_l2_contract.gd",
            "lattice-flagship-l3-roles": "res://tests/lattice/flagship_l3_roles_contract.gd",
            "lattice-flagship-l3-evidence": "res://tests/lattice/flagship_l3_evidence_contract.gd",
            "lattice-flagship-assets": "res://tests/lattice/flagship_asset_contract.gd",
            "lattice-flagship-l3-static": "godot/tests/lattice/flagship_l3_contract.mjs",
            "lattice-flagship-l5-static": "godot/tests/lattice/flagship_l5_contract.mjs",
            "local-render-motion": "res://tests/world_motion/unit.gd",
            "muzzle-sight-geometry": "res://tests/first_person/muzzle_geometry.gd",
            "muzzle-path-geometry": "res://tests/weapon_effects/muzzle_path_geometry.gd",
            "horde-death-wire": "port/native-horde-deaths/wire.test.mjs",
            "horde-death-presentation": "res://tests/horde_deaths/contracts.gd",
            "identity-horde-occlusion": "res://tests/combat_integration/identity_horde_occlusion.gd",
            "combat-remote-muzzle": "res://tests/combat_integration/remote_muzzle.gd",
            "mode-diagnostics": "res://tests/debug/diagnostics.gd",
            "local-24-roster": "port/native-menu-debug-bots/tests/startup.test.mjs",
            "player-flow-journey": "tools/godot-dev/product_journey.mjs",
            "career-player-flow-clarity-journey": "port/native-player-flow/clarity-journey.mjs",
            "objective-zone-variants": "res://tests/zone_modes/variants.gd",
            "objective-assault-state": "res://tests/assault/state_test.gd",
            "objective-scoreboard": "res://tests/objective_scoreboard.gd",
            "vehicle-source-oracle": "port/native-vehicle-expansion/source-oracle.mjs",
            "vehicle-room-edge-oracle": "port/native-vehicle-expansion/room-edge-oracle.mjs",
            "vehicle-fleet-visuals": "res://tests/combined_arms/test_fleet_visuals.gd",
            "vehicle-shared-shot-owner": "res://tests/combined_arms/test_shared_shots.gd",
            "vehicle-three-native-crew": "port/native-vehicle-expansion/run.py",
            "audiovisual-assets": "tools/godot-audiovisual/music_pack.mjs",
            "audiovisual-weather-oracle": "res://tests/audio_new/weather_oracle.gd",
            "audiovisual-lifecycle": "res://tests/audio_new/lifecycle.gd",
            "audiovisual-soak": "res://tests/audio_new/soak.gd",
            "world-weather-source-look": "scripts/world-weather-oracle.mjs",
            "world-weather-native-look": "res://tests/world_weather/unit.gd",
            "world-weather-standalone": "res://tests/world_weather/standalone.gd",
            "world-weather-source-journey": "scripts/world-weather-journey.mjs",
            "world-weather-campaign-journey": "scripts/world-weather-journey.mjs",
            "experience-source-captions": "tools/experience/extract.mjs",
            "experience-native-information": "res://tests/experience/contracts.gd",
            "experience-combined-hud": "res://tests/experience/combined.gd",
            "experience-mode-journey": "tools/experience/native-journey.mjs",
            "experience-campaign-journey": "tools/experience/native-journey.mjs",
            "experience-sports-journey": "tools/experience/native-journey.mjs",
            "experience-combined-arms-journey": "tools/experience/native-journey.mjs",
            "player-gameplay-catalog": "port/next-port/gameplay/catalog.mjs",
            "player-gameplay-source-fixtures": "port/next-port/gameplay/fixtures.mjs",
            "player-gameplay-native": "res://tests/player_gameplay/test.gd",
            "player-gameplay-live-input": "port/next-port/gameplay/live.mjs",
            "competitive-source-modes": "port/next-port/modes/source-parity.test.mjs",
            "competitive-native-contracts": "res://tests/mode_expansion/contracts.gd",
            "competitive-native-arsenal": "port/next-port/modes/native-proof.mjs",
            "competitive-native-juggernaut": "port/next-port/modes/native-proof.mjs",
            "competitive-native-elimination": "port/next-port/modes/native-proof.mjs",
            "competitive-native-vip": "port/next-port/modes/native-proof.mjs",
        }
        for name, path in expected.items():
            with self.subTest(gate=name):
                self.assertTrue(name in commands, f"Missing gate: {name}")
                self.assertIn(path, commands[name])
                if path.endswith(".gd"):
                    self.assertIn("--script", commands[name])
                    self.assertLess(names.index("godot-import"), names.index(name))
        self.assertLess(names.index("lattice-req-generator-tests"), names.index("lattice-req-catalog-check"))
        self.assertLess(names.index("lattice-req-catalog-check"), names.index("semantic-export"))
        self.assertLess(names.index("semantic-export"), names.index("lattice-req-catalog"))
        self.assertIn("--check", commands["lattice-req-catalog-check"])
        focused = (Path(__file__).resolve().parents[2] / "port/tools/native_lattice_flagship/verify.py").read_text()
        for name in ("req_catalog_contract.gd", "req_purchase_contract.gd", "world_tactical_contract.gd",
                     "flagship_asset_contract.gd", "flagship_l1_contract.gd", "flagship_l2_contract.gd",
                     "flagship_l3_roles_contract.gd", "flagship_l3_evidence_contract.gd"):
            with self.subTest(focused=name):
                self.assertIn('"' + name + '"', focused)


if __name__ == "__main__":
    unittest.main()
