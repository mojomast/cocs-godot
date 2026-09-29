"""Run actual port gates; fail on Godot errors even when its exit code is zero."""
import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from gate_runner import run_gate, save_report

root = Path(__file__).resolve().parents[2]
os.chdir(root)
# Fresh CI runners do not pre-create the scratch root used by coverage and
# rendered smoke gates; keep the aggregate self-contained on those machines.
Path('/tmp/opencode').mkdir(parents=True, exist_ok=True)
report_path = Path('port/reports/verification.json')
lock = json.loads(Path('port/contracts/source-lock.json').read_text())
report = {
    'status': 'running', 'gates': [],
    'source_commit': lock['source_commit'],
    'port_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'port_worktree_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
    'source_derivative': {'selection': 'none'},
    'manual_acceptance': [
        {'scope': 'Rendered visual fidelity and actual player input', 'state': 'owner-run / unrun'},
        {'scope': 'Natural full-round and multiplayer source outcomes', 'state': 'owner-run / unrun'},
        {'scope': 'Human playable acceptance', 'state': 'owner-run / unrun'},
    ],
}
save_report(report_path, report)
def fail_preflight(message):
    report.update(status='failed', failure_reason=message)
    save_report(report_path, report)
    raise SystemExit(message)


binary = os.environ.get("GODOT_BIN")
derivative_path = os.environ.get('COCS_SOURCE_DERIVATIVE')
# Career state is durable in the product. Each aggregate uses an isolated
# authority/credential root so scripted matches cannot mutate a real career.
(root / '.port-runtime').mkdir(exist_ok=True)
os.environ['COCS_CAREER_ROOT'] = tempfile.mkdtemp(prefix='verification-career-', dir=root / '.port-runtime')
os.environ['CAREER_EQUIPPED_OUT'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'equipped-journey')
os.environ['CAREER_CLARITY_OUT'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'clarity-journey')
for key, suffix in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
    os.environ.setdefault(key, str(root / ".port-runtime" / suffix))
    Path(os.environ[key]).mkdir(parents=True, exist_ok=True)
commands = [
    ("gate-runner-tests", [sys.executable, "tools/godot-dev/test_gate_runner.py"]),
    ("playable-gate-registration", [sys.executable, "tools/godot-dev/test_playable_gates.py"]),
    ("verifier-report-tests", [sys.executable, "tools/godot-dev/test_verifier_report.py"]),
    ("ci-artifact-tests", [sys.executable, "tools/godot-dev/test_ci_artifact.py"]),
    ("native-ci-contracts", ["node", "--test", "port/native-ci/workflow.test.mjs", "port/native-ci/source-selection.test.mjs"]),
    ("export-tests", ["node", "--test", "tools/godot-export/semantic.test.mjs"]),
    ("moth-export", ["node", "--test", "tools/godot-moth/export.test.mjs"]),
    ("gltf-sides", ["node", "--test", "tools/godot-export/gltf_side.test.mjs"]),
    ("health-hud-evidence", ["node", "--test", "port/tools/native_health_damage/analyze.test.mjs", "port/tools/native_health_damage/test.mjs"]),
    ("projectile-navigation", ["node", "--test", "port/native-projectile-combat/route.test.mjs"]),
    ("objective-evidence", ["node", "--test", "port/tools/native_objective_demo/test.mjs"]),
    ("objective-progression-evidence", ["node", "--test", "port/native-objective-progression/test.mjs"]),
    ("objective-completion-evidence", ["node", "--test", "port/native-objective-completion/test.mjs"]),
    ("launcher-options", ["node", "--test", "tools/godot-dev/launch_options.test.mjs"]),
    ("package-options", ["node", "--test", "tools/godot-package/options.test.mjs"]),
    ("product-shell-supervisor", ["node", "--test", "tools/godot-package/settings_path.test.mjs", "tools/godot-package/menu_journey.test.mjs", "tools/godot-dev/journey_options.test.mjs"]),
    ("native-graphics-options", ["node", "--test", "tools/godot-package/native_showcase_options.test.mjs", "tools/godot-dev/native_showcase_options.test.mjs"]),
    ("native-graphics-ownership", ["node", "--test", "tools/godot-package/native_showcase_ownership.test.mjs", "tools/godot-dev/native_showcase_ownership.test.mjs"]),
    ("lobby-options", ["node", "--test", "tools/godot-package/lobby_options.test.mjs"]),
    ("lobby-ownership", ["node", "--test", "tools/godot-package/lobby_ownership.test.mjs"]),
    ("horde-closure", ["node", "--test", "tools/godot-package/horde_closure.test.mjs"]),
    ("native-arena-closure", ["node", "--test", "tools/godot-package/native_arena_closure.test.mjs"]),
    ("package-identity-routes", ["node", "--test", "tools/godot-package/native_identity_options.test.mjs"]),
    ("native-arena-authority", ["node", "--test", "port/native-arenas/tests/authority.test.mjs", "port/native-arenas/tests/input-events.test.mjs", "port/native-arenas/tests/source-match.test.mjs", "port/native-arenas/tests/schema.test.mjs"]),
    ("local-24-roster", ["node", "--test", "port/native-menu-debug-bots/tests/startup.test.mjs", "port/native-menu-debug-bots/tests/debug-24.test.mjs"]),
    ("horde-ownership", ["node", "--test", "tools/godot-package/horde_ownership.test.mjs"]),
    ("zone-routing", ["node", "--test", "port/native-zone-modes/route.test.mjs"]),
    ("combined-arms-evidence", [sys.executable, "-B", "-m", "unittest", "discover", "-s", "port/native-combined-arms", "-p", "test_validate.py"]),
    ("lattice-req-generator-tests", ["node", "--test", "port/tools/native_lattice_req_catalog/export.test.mjs"]),
    ("lattice-req-catalog-check", ["node", "port/tools/native_lattice_req_catalog/export.mjs", "--check"]),
    ("semantic-export", ["node", "tools/godot-export/semantic.mjs"]),
    ("source-inventory", ["node", "--test", "tools/godot-export/source-inventory.test.mjs"]),
    ("package-manifest-contracts", ["node", "--test", "tools/godot-package/manifest_validation.test.mjs"]),
    ("career-catalog-check", ["node", "tools/godot-export/career_catalog.mjs", "--check"]),
    ("finish-catalog-check", ["node", "tools/godot-weapons/finishes.mjs", "--check"]),
    ("finish-source-palette", ["node", "--test", "tools/godot-weapons/finishes.test.mjs"]),
    ("career-source-contracts", ["node", "--test", "--test-concurrency=1", "port/native-career/catalog.test.mjs", "port/native-career/wire.test.mjs"]),
    ("career-persistence", ["node", "--test", "tools/godot-package/career_path.test.mjs"]),
    ("career-history-storage", ["node", "--test", "tools/godot-package/history_storage.test.mjs"]),
    ("career-results-source", ["node", "--test", "port/native-career/results-history.test.mjs"]),
    ("career-equipment-source", ["node", "--test", "port/native-career/equip-lifecycle.test.mjs"]),
    ("career-equipped-source", ["node", "--test", "port/native-career/equipped.test.mjs"]),
    ("social-source", ["node", "--test", "port/native-social/social_authority.test.mjs"]),
    ("source-tests", ["node", "--test", "game/protocol.test.mjs", "game/arena-movement.test.mjs", "game/map-schema.test.mjs", "game/destination-maps.test.mjs", "game/destination-sports.test.mjs", "game/destination-lattice.test.mjs"]),
    ("arms-race-source", ["node", "--test", "game/armsrace.test.mjs", "game/outcome.test.mjs", "game/input.test.mjs", "game/movement-input.test.mjs"]),
    ("horde-source", ["node", "--test", "game/singleplayer.test.mjs", "game/singleplayer-ui.test.mjs"]),
    ("cinderwake-source", ["node", "--test", "--test-concurrency=1", "game/horde-stages.test.mjs", "tools/godot-horde-maps/cinderwake.test.mjs", "tools/godot-horde-maps/source-fixture.test.mjs", "port/native-horde/cinderwake.test.mjs", "port/native-identity-horde/validate_cinderwake.test.mjs"]),
    ("horde-upgrade-adapter", ["node", "--test", "port/native-horde/upgrade.test.mjs"]),
    ("horde-adapter", ["node", "--test", "port/native-horde/test.mjs", "port/native-horde/input-buffer.test.mjs", "port/native-horde/repair-regression.test.mjs", "port/native-horde/event-cursor.test.mjs", "port/native-horde/npc-kills.test.mjs", "port/native-horde/melee-hold.test.mjs", "port/native-horde/interpolated.test.mjs"]),
    ("horde-death-wire", ["node", "--test", "port/native-horde-deaths/wire.test.mjs"]),
    ("horde-input-oracle", ["node", "port/native-horde/input-oracle.mjs", str(root / "port/reports/horde-input-vectors.json")]),
    ("godot-import", [binary, "--headless", "--path", "godot", "--editor", "--import"]),
    ("career-projection", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/projection.gd"]),
    ("career-package-catalog", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/package_catalog.gd"]),
    ("career-identity-native", ["node", "--test", "tools/godot-package/career_native.test.mjs"]),
    ("career-equipment-native", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/actions.gd"]),
    ("career-equipped-model", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/newloadout_model.gd"]),
    ("career-equipped-ui", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/newloadout_ui.gd"]),
    ("career-player-flow-clarity-source", ["node", "--test", "port/native-player-flow/clarity-states.test.mjs"]),
    ("career-player-flow-clarity-model", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_flow/clarity_model.gd"]),
    ("career-player-flow-clarity-ui", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_flow/clarity_ui.gd"]),
    ("career-player-flow-clarity-journey", ["node", "port/native-player-flow/clarity-journey.mjs"]),
    ("career-equipped-lobby", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/newloadout_lobby.gd"]),
    ("career-equipped-journey", ["node", "port/native-career/equipped-journey.mjs"]),
    ("career-results-native", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/results.gd"]),
    ("career-history-native", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/history.gd"]),
    ("career-results-history-ui", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/results_history_ui.gd"]),
    ("social-native", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/lobby_social.gd"]),
    ("reconnect-source-native", ["node", "port/native-reconnect/journey.mjs"]),
    ("reconnect-offline-results", ["node", "port/native-reconnect/offline-results.mjs"]),
    ("reconnect-menu", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/reconnect_menu.gd"]),
    ("career-modal", [binary, "--headless", "--path", "godot", "--script", "res://tests/career/modal.gd"]),
    ("cinderwake-native", [binary, "--headless", "--path", "godot", "--script", "res://tests/horde/cinderwake_test.gd"]),
    ("identity-horde-composition", [binary, "--headless", "--path", "godot", "--script", "res://tests/horde/identity_composition_test.gd"]),
    ("loadout-unit", [binary, "--headless", "--path", "godot", "--script", "res://tests/loadouts/unit.gd"]),
    ("loadout-source-parity", [binary, "--headless", "--path", "godot", "--script", "res://tests/loadouts/parity.gd"]),
    ("loadout-client", [binary, "--headless", "--path", "godot", "--script", "res://tests/loadouts/client_frames.gd"]),
    ("loadout-setup", [binary, "--headless", "--path", "godot", "--script", "res://tests/loadouts/setup_menu.gd"]),
    ("loadout-lobby", [binary, "--headless", "--path", "godot", "--script", "res://tests/loadouts/lobby_menu.gd"]),
    ("loadout-session", [binary, "--headless", "--path", "godot", "--script", "res://tests/loadouts/session_flow.gd"]),
    ("loadout-loopback", [sys.executable, "tools/godot-dev/xvfb_run.py", "node", "godot/tests/loadouts/loopback.mjs"]),
    ("loadout-lifecycle", ["node", "--test", "godot/tests/loadouts/loopback_lifecycle.test.mjs"]),
    ("viewer-smoke", [binary, "--headless", "--path", "godot", "--", "--smoke"]),
    ("graphics-terrain", [binary, "--headless", "--path", "godot", "--script", "res://tests/graphics_batch/terrain_contract.gd"]),
    ("moth-resources", [binary, "--headless", "--path", "godot", "--script", "res://tests/moth/validate.gd"]),
    ("graphics-atmosphere", [binary, "--headless", "--path", "godot", "--script", "res://tests/graphics_atmosphere/verify.gd"]),
    ("graphics-fx", [binary, "--headless", "--path", "godot", "--script", "res://tests/graphics_fx/regression.gd"]),
    ("moth-scenery", [binary, "--headless", "--path", "godot", "--script", "res://tests/moth_scenery/verify.gd"]),
    ("shader-lab", [binary, "--headless", "--path", "godot", "--script", "res://tests/shader_lab/validate.gd"]),
    ("particle-lab", [binary, "--headless", "--path", "godot", "--script", "res://tests/particle_lab/verify.gd"]),
    ("showcase-startup", ["node", "tools/godot-dev/launch.mjs", "--experience=showcase", "--smoke"]),
    ("aurora-traversal", [binary, "--headless", "--path", "godot", "--script", "res://tests/aurora_basin/validate.gd", "--", "--output=" + str(root / "port/reports/aurora-traversal.json")]),
    ("cinder-traversal", [binary, "--headless", "--path", "godot", "--script", "res://tests/cinder_array/verify.gd", "--", str(root / "port/reports/cinder-traversal.json")]),
    ("exploration-walker", [binary, "--headless", "--path", "godot", "--script", "res://tests/graphics_batch/walker.gd"]),
    ("first-person-rig", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/lifecycle.gd"]),
    ("first-person-finishes", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/finishes.gd"]),
    ("finish-source-journey", ["node", "tools/godot-weapons/finish-journey.mjs", "--output=" + str(root / ".port-runtime/finish-source-journey.json")]),
    ("finish-native-source-replay", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/finishes_source.gd", "--", "--source-journey=" + str(root / ".port-runtime/finish-source-journey.json")]),
    # Real pointer capture is required by this fixture; the dummy display server
    # ignores MOUSE_MODE_CAPTURED, so the gate runs under a private owned Xvfb.
    ("first-person-binding", [sys.executable, "tools/godot-dev/xvfb_run.py", binary, "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--script", "res://tests/first_person/binding.gd"]),
    ("first-person-ads", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/ads_contract.gd"]),
    ("first-person-recoil", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/recoil.gd"]),
    ("combat-actions", [sys.executable, "tools/godot-dev/xvfb_run.py", binary, "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--script", "res://tests/combat_actions/controls.gd"]),
    ("combat-shields", [binary, "--headless", "--path", "godot", "--script", "res://tests/combat_shields/validate.gd"]),
    ("combat-shield-capacity", [binary, "--headless", "--path", "godot", "--script", "res://tests/combat_shields/capacity.gd"]),
    ("combat-particles", [binary, "--headless", "--path", "godot", "--script", "res://tests/combat_particles/contracts.gd"]),
    ("combat-pickup-assets", [binary, "--headless", "--path", "godot", "--script", "res://tests/combat_pickup_assets/validate.gd"]),
    ("weapon-effects", [binary, "--headless", "--path", "godot", "--script", "res://tests/weapon_effects/lifecycle.gd"]),
    ("weapon-effects-rig", [binary, "--headless", "--path", "godot", "--script", "res://tests/weapon_effects/rig_integration.gd"]),
    ("muzzle-sight-geometry", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/muzzle_geometry.gd"]),
    ("muzzle-path-geometry", [binary, "--headless", "--path", "godot", "--script", "res://tests/weapon_effects/muzzle_path_geometry.gd"]),
    ("projectile-flight", [binary, "--headless", "--path", "godot", "--script", "res://tests/weapon_effects/projectile_flight.gd"]),
    ("alt-fire", [binary, "--headless", "--path", "godot", "--script", "res://tests/weapon_effects/alt_fire.gd"]),
    ("weapon-handling", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/handling.gd"]),
    ("weapon-detail", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/detail.gd"]),
    ("weapon-export", ["node", "tools/godot-weapons/verify.mjs"]),
    ("world-weapon-identity", ["node", "port/native-world-weapon-identity/check.mjs"]),
    # Impact/player-state feedback contracts. The lane's own runner additionally
    # performs rendered captures and is kept as its full evidence harness.
    ("player-fx-direction", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_fx/direction.gd"]),
    ("player-fx-low-health", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_fx/low_health.gd"]),
    ("player-fx-lifecycle", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_fx/lifecycle.gd"]),
    ("player-fx-marks", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_fx/marks.gd"]),
    ("player-fx-impacts", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_fx/impacts.gd"]),
    ("player-fx-overlay", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_fx/overlay.gd"]),
    ("player-fx-integration", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_fx/integration.gd"]),
    ("benchmark-contracts", [binary, "--headless", "--path", "godot", "--script", "res://tests/benchmark/contracts.gd"]),
    ("benchmark-tools", ["node", "--test", "port/native-benchmark/test.mjs"]),
    # This gate proves env-only auto-start and a *complete rendered* sequence on
    # CPU-only CI. GitHub's llvmpipe can exceed 2 s/frame at 1280x800 High and
    # end the authority round before it can deliver a single usable snapshot.
    # Owner-facing 1280x800 Extreme/4-bot hardware measurements stay separate.
    ("benchmark-autostart", ["node", "port/native-benchmark/run_benchmark.mjs", "--gate=all", "--resolution=640x400", "--level=low", "--bots=1", "--out=/tmp/opencode/benchmark-autostart-gate"]),
    ("material-language", [binary, "--headless", "--path", "godot", "--script", "res://tests/material_language/validate.gd"]),
    ("material-derived", ["node", "--test", "tools/godot-moth/derive.test.mjs"]),
    ("identity-zone-route", ["node", "--test", "port/native-identity-zones/tests/route.test.mjs", "port/native-identity-zones/tests/match.test.mjs", "port/native-identity-zones/tests/authority.test.mjs"]),
    ("debug-tools", ["node", "--test", "port/native-debug/debug.test.mjs", "port/native-arenas/tests/debug.test.mjs", "port/native-horde/debug.test.mjs", "port/native-identity-zones/tests/debug.test.mjs"]),
    ("debug-panel", [binary, "--headless", "--path", "godot", "--script", "res://tests/debug/panel.gd", "--", "--debug-panel"]),
    ("mode-diagnostics", [binary, "--headless", "--path", "godot", "--script", "res://tests/debug/diagnostics.gd", "--", "--diagnostics"]),
    ("blood-live-harness", ["node", "--test", "port/native-blood-fx/tests/live_budget.test.mjs"]),
    # Keep the real rendered authority/blood-event check on CPU-only CI without
    # using its 1280x800 five-hit visual-review preset as a frame-rate test.
    ("blood-live-native", ["node", "port/native-blood-fx/live.mjs", "--ci-render-budget"]),
    ("route-parity", ["node", "--test", "tools/godot-package/route_parity.test.mjs"]),
    ("main-menu-smoke", [binary, "--headless", "--path", "godot", "res://ui/main_menu.tscn", "--", "--smoke"]),
    ("main-menu-contracts", [binary, "--headless", "--path", "godot", "--script", "res://tests/main_menu/contracts.gd", "--", "--contracts"]),
    ("product-shell-settings", [binary, "--headless", "--path", "godot", "--script", "res://tests/product_shell/settings_contract.gd"]),
    ("product-shell-journey", [sys.executable, "tools/godot-dev/xvfb_run.py", "node", "tools/godot-dev/product_journey.mjs", "--itinerary=port/native-shell/itineraries/consolidated.json"]),
    ("player-flow-journey", [sys.executable, "tools/godot-dev/xvfb_run.py", "node", "tools/godot-dev/product_journey.mjs", "--player-flow"]),
    ("player-flow-controls", [sys.executable, "tools/godot-dev/xvfb_run.py", binary, "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--script", "res://tests/player_flow/controls.gd"]),
    ("product-shell-guest-leave", [sys.executable, "tools/godot-dev/xvfb_run.py", "node", "tools/godot-dev/guest_leave_journey.mjs"]),
    # coverage.mjs alone always exits 0; the floor wrapper makes a regression fail.
    ("material-coverage-floor", [sys.executable, "tools/godot-dev/coverage_floor.py"]),
    ("release-pipeline-tools", ["node", "--test", "tools/release/options.test.mjs", "tools/release/release.test.mjs"]),
    ("blood-fx-contracts", [binary, "--headless", "--path", "godot", "--script", "res://tests/blood_fx/contracts.gd"]),
    ("blood-fx-surfaces", [binary, "--headless", "--path", "godot", "--script", "res://tests/blood_fx/surfaces.gd"]),
    ("blood-fx-stress", [binary, "--headless", "--path", "godot", "--script", "res://tests/blood_fx/stress.gd"]),
    ("combat-integration-oracle", ["node", "port/native-combat-integration/export-fixtures.mjs"]),
    ("combat-integration", [binary, "--headless", "--path", "godot", "--script", "res://tests/combat_integration/contracts.gd"]),
    ("combat-combined-integration", [binary, "--headless", "--path", "godot", "--script", "res://tests/combat_integration/combined_adapter.gd"]),
    ("combat-remote-muzzle", [binary, "--headless", "--path", "godot", "--script", "res://tests/combat_integration/remote_muzzle.gd"]),
    ("identity-horde-occlusion", [binary, "--headless", "--path", "godot", "--script", "res://tests/combat_integration/identity_horde_occlusion.gd"]),
    ("native-arena-maps", ["node", "--test", "port/native-arenas/tests/actual-maps.mjs"]),
    ("native-arena-session", [binary, "--headless", "--path", "godot", "--script", "res://tests/native_arenas/session/test.gd", "--", "--mute"]),
    ("native-arena-composition", [binary, "--headless", "--path", "godot", "--script", "res://tests/native_arenas/session/geometry_composition.gd", "--", "--endpoint=ws://127.0.0.1:1", "--mute"]),
    # Visual-identity prototypes: source movement/ray parity and map lifecycle only.
    # These maps are not exposed as a playable route yet; passing here is not
    # playable, visual or performance acceptance.
    ("identity-prototype-graybox", ["node", "--test", "port/native-identity-maps/graybox.test.mjs"]),
    ("identity-prototype-oracle", ["node", "port/native-identity-maps/ray-oracle.mjs"]),
    ("identity-prototype-rays", [binary, "--headless", "--path", "godot", "--script", "res://tests/identity_maps/rays.gd"]),
    ("identity-prototype-lifecycle", [binary, "--headless", "--path", "godot", "--script", "res://tests/identity_maps/lifecycle.gd"]),
    ("native-arena-prism", ["node", "tools/godot-dev/launch.mjs", "--experience=native-dm", "--map=prism-foundry", "--smoke"]),
    ("native-arena-aurora", ["node", "tools/godot-dev/launch.mjs", "--experience=native-dm", "--map=aurora-basin", "--smoke"]),
    ("native-arena-cinder", ["node", "tools/godot-dev/launch.mjs", "--experience=native-dm", "--map=cinder-array", "--smoke"]),
    ("glb-import", [binary, "--headless", "--path", "godot", "--script", "res://tests/import.gd"]),
    ("glb-sides", [binary, "--headless", "--path", "godot", "--script", "res://tests/glb_side_import.gd", "--", "--map=meridian-exchange"]),
    ("input-queue", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/input_queue.gd"]),
    ("protocol-envelopes", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/envelopes.gd"]),
    ("packet-replay", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/replay.gd"]),
    ("native-live", ["node", "tools/godot-dev/launch.mjs", "--network-smoke"]),
    ("presentation-replay", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/presentation.gd"]),
    ("round-boundaries", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/round_boundaries.gd"]),
    ("native-lifecycle", ["node", "tools/godot-dev/launch.mjs", "--lifecycle-smoke"]),
    ("combat-feedback", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/combat_feedback.gd"]),
    ("projectiles", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/projectiles.gd"]),
    ("audio-feedback", [binary, "--headless", "--audio-driver", "Dummy", "--path", "godot", "--script", "res://tests/protocol/audio_feedback.gd"]),
    ("local-lifecycle", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/local_lifecycle.gd"]),
    ("pickup-presentation", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/pickups.gd"]),
    ("entity-visuals", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/entity_visuals.gd"]),
    ("operator-geometry", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_models/geometry.gd"]),
    ("world-weapon-import", [binary, "--headless", "--path", "godot", "--script", "res://tests/source_operators/weapons.gd"]),
    ("world-weapon-grips", [binary, "--headless", "--path", "godot", "--script", "res://tests/source_operators/grips.gd"]),
    ("native-trace", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/native_trace.gd"]),
    ("guest-session", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/guest_session.gd"]),
    ("lobby-flow", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/lobby_flow.gd"]),
    ("lobby-spectator-context", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/lobby_spectator_context.gd"]),
    ("match-selection", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/match_selection.gd"]),
    ("scoreboard", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/scoreboard.gd"]),
    ("team-scores", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/team_scores.gd"]),
    ("scoreboard-session", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/scoreboard_session.gd"]),
    ("game-hud", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/game_hud_session.gd"]),
    ("game-hud-setup", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/game_hud_session.gd", "--", "--setup"]),
    ("game-hud-debug", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/game_hud_session.gd", "--", "--debug-hud"]),
    ("puma-presentation", [binary, "--headless", "--path", "godot", "--script", "res://tests/vehicles/test_puma.gd"]),
    ("zone-modes", [binary, "--headless", "--path", "godot", "--script", "res://tests/zone_modes/unit.gd"]),
    ("objective-expansion-routes", ["node", "--test", "tools/godot-package/objective_routes.test.mjs", "tools/godot-package/combined_guest_options.test.mjs", "port/native-assault/static.test.mjs"]),
    ("objective-source-completion", ["node", "--test", "port/native-objective-expansion/source_completion.test.mjs"]),
    ("uplink-live-timeout", ["node", "port/native-objective-expansion/live.mjs", "--mode=uplink", "--map=meridian-exchange"]),
    ("holdout-live-timeout", ["node", "port/native-objective-expansion/live.mjs", "--mode=holdout", "--map=verdant-reliquary"]),
    ("assault-live-timeout", ["node", "port/native-objective-expansion/live.mjs", "--mode=assault", "--map=sunscar-convoy"]),
    ("uplink-controlled-completion", ["node", "port/native-objective-expansion/live.mjs", "--mode=uplink", "--map=ember-crucible", "--controlled-completion"]),
    ("holdout-controlled-completion", ["node", "port/native-objective-expansion/live.mjs", "--mode=holdout", "--map=meridian-exchange", "--controlled-completion"]),
    ("assault-controlled-completion", ["node", "port/native-objective-expansion/live.mjs", "--mode=assault", "--map=tidal-citadel", "--controlled-completion"]),
    ("objective-zone-variants", [binary, "--headless", "--path", "godot", "--script", "res://tests/zone_modes/variants.gd"]),
    ("objective-assault-state", [binary, "--headless", "--path", "godot", "--script", "res://tests/assault/state_test.gd"]),
    ("objective-scoreboard", [binary, "--headless", "--path", "godot", "--script", "res://tests/objective_scoreboard.gd"]),
    ("vehicle-source-oracle", ["node", "port/native-vehicle-expansion/source-oracle.mjs"]),
    ("vehicle-room-edge-oracle", ["node", "port/native-vehicle-expansion/room-edge-oracle.mjs"]),
    ("vehicle-fleet-visuals", [binary, "--headless", "--path", "godot", "--script", "res://tests/combined_arms/test_fleet_visuals.gd"]),
    ("vehicle-shared-shot-owner", [binary, "--headless", "--path", "godot", "--script", "res://tests/combined_arms/test_shared_shots.gd"]),
    ("vehicle-three-native-crew", [sys.executable, "port/native-vehicle-expansion/run.py"]),
    ("audiovisual-assets", ["node", "tools/godot-audiovisual/music_pack.mjs", "--check"]),
    ("weather-source-vectors", ["node", "port/native-audiovisual/weather-oracle.mjs", "--check"]),
    ("audiovisual-event-router", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/event_router.gd"]),
    ("audiovisual-outcome", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/outcome.gd"]),
    ("audiovisual-settings", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/settings.gd"]),
    ("audiovisual-lifecycle", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/lifecycle.gd"]),
    ("audiovisual-weather-ownership", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/weather_ownership.gd"]),
    ("audiovisual-weather-oracle", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/weather_oracle.gd"]),
    ("audiovisual-score-form", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/score_form.gd"]),
    ("audiovisual-soak", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/soak.gd"]),
    ("audiovisual-standalone-lifecycle", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/standalone_lifecycle.gd"]),
    ("audiovisual-independent-event-binding", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/independent_event_binding.gd"]),
    ("audiovisual-horde-recipe-binding", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/horde_recipe_binding.gd"]),
    ("audiovisual-menu-rapid-lifetime", [binary, "--headless", "--path", "godot", "--script", "res://tests/audio_new/menu_rapid_lifetime.gd"]),
    ("combined-arms-controls", [binary, "--headless", "--path", "godot", "--script", "res://tests/combined_arms/test_controls.gd"]),
    ("combined-arms-graphics", [binary, "--headless", "--path", "godot", "--script", "res://tests/combined_arms/graphics.gd"]),
    ("arms-race", [binary, "--headless", "--path", "godot", "--script", "res://tests/arms_race/independent_fixtures.gd"]),
    ("horde-model", [binary, "--headless", "--path", "godot", "--script", "res://tests/horde/test.gd"]),
    ("horde-death-presentation", [binary, "--headless", "--path", "godot", "--script", "res://tests/horde_deaths/contracts.gd"]),
    ("horde-upgrade-native", [binary, "--headless", "--path", "godot", "--script", "res://tests/horde/upgrade_selection_test.gd"]),
    # Actual native input/authority path; offer timing is an explicit test fixture.
    ("horde-upgrade-fixture", [sys.executable, "tools/godot-dev/xvfb_run.py", "node", "godot/tests/horde/upgrade_loopback.mjs"]),
    ("horde-controls", [binary, "--headless", "--path", "godot", "--script", "res://tests/horde/controls_test.gd", "--", "--vectors=" + str(root / "port/reports/horde-input-vectors.json")]),
    ("sports-controls", [binary, "--headless", "--path", "godot", "--script", "res://tests/sports/test_controls.gd"]),
    ("sports-polish", [binary, "--headless", "--path", "godot", "--script", "res://tests/sports/test_polish.gd"]),
    ("sports-progression", [binary, "--headless", "--path", "godot", "--script", "res://tests/sports/progression_test.gd"]),
    ("soccer-guidance", [binary, "--headless", "--path", "godot", "--script", "res://tests/sports/soccer_test.gd"]),
    ("soccer-coaching", [binary, "--headless", "--path", "godot", "--script", "res://tests/sports/practice_test.gd"]),
    ("sports-bearing", [binary, "--headless", "--path", "godot", "--script", "res://tests/sports/bearing_projection_test.gd"]),
    ("lattice-adapter", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/adapter.gd"]),
    ("lattice-ui", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/ui.gd"]),
    ("lattice-map", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/map_view.gd"]),
    ("lattice-topology", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/topology.gd"]),
    ("lattice-economy", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/economy.gd"]),
    ("lattice-world", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/world_contract.gd"]),
    ("lattice-world-commands", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/world_commands_contract.gd"]),
    ("lattice-req-catalog", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/req_catalog_contract.gd"]),
    ("lattice-req-purchase", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/req_purchase_contract.gd"]),
    ("lattice-world-tactical", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/world_tactical_contract.gd"]),
    ("lattice-flagship-l1", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/flagship_l1_contract.gd"]),
    ("lattice-flagship-l2", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/flagship_l2_contract.gd"]),
    ("lattice-flagship-l3-roles", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/flagship_l3_roles_contract.gd"]),
    ("lattice-flagship-l3-evidence", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/flagship_l3_evidence_contract.gd"]),
    ("lattice-flagship-assets", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/flagship_asset_contract.gd"]),
    ("lattice-flagship-l3-static", ["node", "--test", "godot/tests/lattice/flagship_l3_contract.mjs"]),
    ("lattice-flagship-l5-static", ["node", "--test", "godot/tests/lattice/flagship_l5_contract.mjs"]),
    ("lattice-world-usability", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/usability_contract.gd"]),
    ("objective-renderer", [binary, "--headless", "--path", "godot", "--script", "res://tests/objectives/renderer.gd"]),
    ("objective-controls", [binary, "--headless", "--path", "godot", "--script", "res://tests/objectives/controls.gd", "--", "--map=tidal-citadel"]),
    ("objective-progression", [binary, "--headless", "--path", "godot", "--script", "res://tests/objectives/progression_hud.gd", "--", "--map=tidal-citadel"]),
    ("objective-input-timing", [binary, "--headless", "--path", "godot", "--script", "res://tests/objectives/completion_inputs.gd"]),
    ("payload-guidance", [binary, "--headless", "--path", "godot", "--script", "res://tests/objectives/guidance_fixtures.gd"]),
    ("payload-guidance-hud", [binary, "--headless", "--path", "godot", "--script", "res://tests/objectives/guidance_hud.gd", "--", "--map=tidal-citadel"]),
    ("control-safety", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/control_safety.gd"]),
    ("window-focus", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/window_focus.gd"]),
    ("session-recovery", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/session_recovery.gd"]),
    ("stall-controls", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/stall_controls.gd"]),
    ("snapshot-watch", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/snapshot_watch.gd"]),
    ("native-session", ["node", "tools/godot-dev/launch.mjs", "--session-smoke"]),
    ("two-native-clients", ["node", "tools/godot-dev/two-clients.mjs"]),
    ("motion-impairment", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/impairment.gd"]),
    ("remote-motion", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/remote_motion.gd"]),
    ("local-render-motion", [binary, "--headless", "--path", "godot", "--script", "res://tests/world_motion/unit.gd"]),
]
report['planned_gate_names'] = ['toolchain-version', *(name for name, _ in commands), 'release-refused']
report['unrun_gate_names'] = report['planned_gate_names'].copy()
# Other gates are fast/headless contracts. Owner-only checks are listed above,
# never inserted into the executable inventory as implied passes.
report['gate_tiers'] = {
    'rendered/input': ['first-person-binding', 'combat-actions', 'benchmark-autostart',
                        'blood-live-native', 'loadout-loopback', 'horde-upgrade-fixture',
                        'product-shell-journey', 'product-shell-guest-leave', 'career-equipped-journey',
                        'player-flow-journey', 'player-flow-controls', 'career-player-flow-clarity-journey',
                        'vehicle-three-native-crew'],
    'live-source': ['native-live', 'native-lifecycle', 'native-session', 'two-native-clients',
                    'product-shell-journey', 'product-shell-guest-leave', 'career-equipped-journey',
                    'finish-source-journey', 'player-flow-journey', 'career-player-flow-clarity-journey',
                    'uplink-live-timeout', 'holdout-live-timeout', 'assault-live-timeout', 'vehicle-three-native-crew'],
    'controlled-source-placement': ['uplink-controlled-completion', 'holdout-controlled-completion',
                                    'assault-controlled-completion'],
}
report['execution'] = {'planned': len(report['planned_gate_names']), 'executed': 0,
                       'unrun': len(report['unrun_gate_names'])}
save_report(report_path, report)
def record(result):
    report['gates'].append(result)
    report['unrun_gate_names'].remove(result['gate'])
    report['execution']['executed'] = len(report['gates'])
    report['execution']['unrun'] = len(report['unrun_gate_names'])
    save_report(report_path, report)

if derivative_path:
    try:
        derivative_bytes = Path(derivative_path).read_bytes()
        derivative = json.loads(derivative_bytes)
        report['source_derivative'] = {
            'selection': 'explicit', 'path': derivative_path,
            'sha256': hashlib.sha256(derivative_bytes).hexdigest(),
            'source_commit': derivative['source_commit'],
            'derivative_commit': derivative['derivative_commit'],
        }
        save_report(report_path, report)
    except (OSError, ValueError, KeyError, TypeError) as error:
        fail_preflight(f'Invalid explicit COCS_SOURCE_DERIVATIVE: {error}')
if not binary:
    fail_preflight('Set GODOT_BIN to the pinned editor')
version, output = run_gate('toolchain-version', [binary, '--version'], 'port/reports/toolchain-version.log', timeout=10)
if version['passed'] and output.strip() != lock['godot_version']:
    version.update(passed=False, failure_reason='version-mismatch')
record(version)
if not version['passed']:
    fail_preflight('Godot version probe failed or version mismatch')
# Documented engine-teardown noise, permitted only when the gate prints its own
# success marker and exits zero. Godot's GLES3 reports the X11 cursor textures it
# creates for pointer capture as leaked when a display run exits; a bare display
# session and a session without capture produce no such line, so this is engine
# teardown behaviour, not our content. Any other ERROR line still fails the gate.
gate_options = {
    'product-shell-journey': {'timeout': 300},
    'player-flow-journey': {'timeout': 240},
    'career-player-flow-clarity-journey': {'timeout': 240},
    'vehicle-three-native-crew': {'timeout': 360},
    'benchmark-autostart': {'success_marker': 'BENCHMARK_GATE_OK'},
    'combat-actions': {
        'success_marker': 'NATIVE_COMBAT_ACTIONS',
        'allowed_error_patterns': (r'^ERROR: Texture with GL ID of \d+: leaked \d+ bytes\.$',),
    },
}
keep_going = os.environ.get('COCS_VERIFY_KEEP_GOING') == '1'
report['keep_going'] = keep_going
failed_gates = []
for name, command in commands:
    report['active_gate'] = name
    save_report(report_path, report)
    result, output = run_gate(name, command, f'port/reports/{name}.log', **gate_options.get(name, {}))
    record(result)
    if not result['passed']: failed_gates.append(name)
    report['failed_gate_names'] = failed_gates.copy()
    report['status'] = 'failed' if failed_gates else 'running'
    save_report(report_path, report)
    print(f"{name}: {'PASS' if result['passed'] else 'FAIL'}", flush=True)
    if not result['passed']:
        print(output)
        if not keep_going: raise SystemExit(1)
report['active_gate'] = 'release-refused'
save_report(report_path, report)
release, output = run_gate('release-refused', ['node', 'tools/godot-export/semantic.mjs', '--release'], 'port/reports/release-refused.log')
release['passed'] = release['exit_code'] not in (None, 0) and release['failure_reason'] == 'nonzero-exit' and 'Release disabled' in output
release['failure_reason'] = None if release['passed'] else 'release-guard-failure'
record(release)
if not release['passed']: failed_gates.append('release-refused')
report['failed_gate_names'] = failed_gates.copy()
report['status'] = 'failed' if failed_gates else 'passed'
report.pop('active_gate', None)
save_report(report_path, report)
if failed_gates:
    raise SystemExit('Failed gates: ' + ', '.join(failed_gates))
print("All implemented gates passed. Visual fidelity and playable acceptance remain OPEN.")
