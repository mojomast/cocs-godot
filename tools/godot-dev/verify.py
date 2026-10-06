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
    'port_tree': subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], text=True).strip(),
    'port_diff_sha256': hashlib.sha256(subprocess.check_output(['git', 'diff', 'HEAD', '--binary'])).hexdigest(),
    'port_worktree_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
    'source_derivative': {'selection': 'none'},
    'manual_acceptance': [
        {'scope': 'Rendered visual fidelity and actual player input', 'state': 'owner-run / unrun'},
        {'scope': 'Natural full-round and multiplayer source outcomes', 'state': 'owner-run / unrun'},
        {'scope': 'Human playable acceptance', 'state': 'owner-run / unrun'},
    ],
}
save_report(report_path, report)
candidate_id = f"{report['port_commit']}+tree:{report['port_tree'][:12]}+diff:{report['port_diff_sha256'][:12]}"
def fail_preflight(message):
    report.update(status='failed', failure_reason=message)
    save_report(report_path, report)
    raise SystemExit(message)


binary = os.environ.get("GODOT_BIN")
# Pin the resolved engine for every child process: four gate scripts resolve a
# machine-path fallback when GODOT_BIN is absent from the child environment.
if binary:
    os.environ['GODOT_BIN'] = binary
derivative_path = os.environ.get('COCS_SOURCE_DERIVATIVE')
active_source = False
if not derivative_path:
    descriptor = json.loads(Path('port/contracts/active-source.json').read_text())
    derivative_path = str(root / descriptor['derivative'])
    digest = hashlib.sha256(Path(derivative_path).read_bytes()).hexdigest()
    if digest != descriptor['derivative_sha256']:
        fail_preflight(f"Active source derivative drift: {descriptor['derivative']}")
    active_source = True
# Career state is durable in the product. Each aggregate uses an isolated
# authority/credential root so scripted matches cannot mutate a real career.
(root / '.port-runtime').mkdir(exist_ok=True)
os.environ['COCS_CAREER_ROOT'] = tempfile.mkdtemp(prefix='verification-career-', dir=root / '.port-runtime')
os.environ['CAREER_EQUIPPED_OUT'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'equipped-journey')
os.environ['CAREER_CLARITY_OUT'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'clarity-journey')
os.environ['ACTOR_ANIMATION_POINTS'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'animated-body-points.json')
os.environ['CAMPAIGN_TARGETING_POINTS'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'targeting-body-points.json')
os.environ['EDGE_SOURCE_EVENTS'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'edge-source-events.json')
os.environ['EDGE_MAP_CASES'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'edge-map-cases.json')
os.environ['EDGE_RENDER_OUT'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'edge-render')
os.environ['PLAYER_GAMEPLAY_EVIDENCE'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'player-gameplay')
os.environ['MODE_EVIDENCE'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'competitive-modes')
os.environ['EVIDENCE_DIR'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'finish-source')
os.environ['LATTICE_EVIDENCE'] = str(Path(os.environ['COCS_CAREER_ROOT']) / 'lattice-source')
# Verification-owned loopback authorities must not inherit a user's fixed server
# port. The launchers resolve and pass the actual ephemeral endpoint to Godot.
os.environ['PORT'] = '0'
os.environ.setdefault('COCS_ATTRACT_EVIDENCE', str(Path(os.environ['COCS_CAREER_ROOT']) / 'live-menu'))
for key, suffix in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
    os.environ.setdefault(key, str(root / ".port-runtime" / suffix))
    Path(os.environ[key]).mkdir(parents=True, exist_ok=True)
commands = [
    ("gate-runner-tests", [sys.executable, "tools/godot-dev/test_gate_runner.py"]),
    ("finish-runner-tests", [sys.executable, "tools/godot-dev/test_finish_runner.py"]),
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
    ("native-arena-authority", ["node", "--test", "--test-concurrency=1", "port/native-arenas/tests/authority.test.mjs", "port/native-arenas/tests/input-events.test.mjs", "port/native-arenas/tests/source-match.test.mjs", "port/native-arenas/tests/schema.test.mjs", "port/native-arenas/tests/nacre-authority.test.mjs"]),
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
    ("cadence-source", ["node", "--test", "game/cadence.test.mjs"]),
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
    ("protocol-decode-once", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/decode_once.gd"]),
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
    # Supplemental cue gate: requires the preceding godot-import and imported
    # godot/first_person/generated/weapon-0.glb, like the other rig fixtures.
    ("first-person-slide", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/slide.gd"]),
    ("weapon-blender-art", [binary, "--headless", "--path", "godot", "--script", "res://tests/first_person/art_override.gd"]),
    ("weapon-blender-source-audit", [sys.executable, "tools/godot-weapons/blender-art/verify.py"]),
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
    ("multiplayer-world-options", ["node", "--test", "tools/godot-package/world_options.test.mjs"]),
    ("multiplayer-expansion-package-contract", ["node", "--test", "tools/godot-package/expansion_verification.test.mjs"]),
    ("multiplayer-world-derivatives", ["node", "port/multiplayer-worlds/generate-derivative.mjs", "--check"]),
    ("multiplayer-world-scenes", ["node", "tools/godot-multiplayer/generate-scenes.mjs", "--check"]),
    ("multiplayer-world-source-routes", ["node", "--test", "--test-concurrency=1", "tools/godot-multiplayer/worlds/recipes.test.mjs", "tools/godot-multiplayer/worlds/vehicle-route.test.mjs"]),
    ("multiplayer-world-mode-matrix", ["node", "port/multiplayer-worlds/mode-matrix.mjs"]),
    ("multiplayer-urban-navigation", ["node", "port/multiplayer-worlds/urban-audit.mjs"]),
    ("multiplayer-world-network", ["node", "port/multiplayer-worlds/two-client.mjs"]),
    ("horde-robot-expansion", ["node", "--test", "--test-concurrency=1", "port/native-horde/robot-roles.test.mjs", "port/native-horde/robot-authority.test.mjs", "port/native-horde/blackwater.test.mjs", "port/native-horde/robot-network-census.test.mjs"]),
    ("campaign-options", ["node", "--test", "tools/godot-package/campaign_options.test.mjs"]),
    ("solo-cheats-authority", ["node", "--test", "--test-concurrency=1", "port/native-debug/solo_cheats.test.mjs", "port/native-debug/solo_horde.test.mjs"]),
    ("campaign-feel-authority", ["node", "--test", "port/singleplayer-feel/feel.test.mjs"]),
    ("campaign-feel-motion", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/feel_motion.gd"]),
    ("campaign-input-flow", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/input_flow.gd"]),
    ("animation-physics", [binary, "--headless", "--path", "godot", "--script", "res://tests/animation/physics.gd"]),
    ("animation-world-physics", [binary, "--headless", "--path", "godot", "--script", "res://tests/animation/world_physics.gd"]),
    ("campaign-targeting-geometry", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/targeting_geometry.gd"]),
    ("campaign-targeting-authority", ["node", "--test", "port/native-campaign/targeting.test.mjs"]),
    ("animation-actors", [binary, "--headless", "--path", "godot", "--script", "res://tests/animation_pass/actors.gd"]),
    ("animation-actor-geometry", [binary, "--headless", "--path", "godot", "--script", "res://tests/animation_pass/geometry.gd"]),
    ("animation-actor-fire", ["node", "--test", "port/animation-pass/actors-fire.test.mjs"]),
    ("edge-structure-bake", ["node", "port/edge-effects/bake-structures.mjs", "--check"]),
    ("edge-source-hits", ["node", "--test", "port/edge-effects/edges.test.mjs"]),
    ("edge-map-fixtures", ["node", "port/edge-effects/measure.mjs"]),
    ("edge-map-geometry", [binary, "--headless", "--path", "godot", "--script", "res://tests/edge_effects/maps.gd"]),
    ("edge-contact-contracts", [binary, "--headless", "--path", "godot", "--script", "res://tests/edge_effects/contracts.gd"]),
    ("edge-weapon-effects", [binary, "--headless", "--path", "godot", "--script", "res://tests/edge_effects/weapons.gd"]),
    ("edge-render-masks", [sys.executable, "tools/godot-dev/xvfb_run.py", binary, "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--script", "res://tests/edge_effects/render.gd"]),
    ("campaign-interludes-authority", ["node", "--test", "port/native-campaign/interludes.test.mjs"]),
    ("campaign-interludes-fixtures", ["node", "tools/godot-campaign/interlude-fixtures.mjs", str(root / ".port-runtime" / "interlude-fixtures.json")]),
    ("campaign-interludes-native", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/interludes.gd", "--", "--fixtures=" + str(root / ".port-runtime" / "interlude-fixtures.json")]),
    ("campaign-interludes-live", ["node", "tools/godot-campaign/interlude-live.mjs", binary]),
    ("campaign-ownership", ["node", "--test", "tools/godot-package/campaign_ownership.test.mjs"]),
    ("campaign-closure", ["node", "--test", "tools/godot-package/campaign_closure.test.mjs"]),
    ("campaign-authority", ["node", "--test", "--test-concurrency=1", "port/native-campaign/core-provenance.test.mjs", "port/native-campaign/navigation-cache.test.mjs", "port/native-campaign/hit-volume.test.mjs", "port/native-campaign/authority.test.mjs", "port/native-campaign/campaign.test.mjs"]),
    ("campaign-world-routes", ["node", "--test", "--test-concurrency=1", "tools/godot-campaign/terrain.test.mjs"]),
    ("campaign-story-authority", ["node", "--test", "--test-concurrency=1", "port/native-campaign/story.test.mjs"]),
    ("campaign-robots", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/robots.gd"]),
    ("campaign-death-presentation", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/death_presentation.gd"]),
    ("campaign-telegraphs", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/telegraphs.gd"]),
    ("campaign-model", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/model.gd"]),
    ("campaign-environment", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/environment.gd"]),
    ("campaign-robot-voices", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/robot_voices.gd"]),
    ("campaign-client", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/client.gd"]),
    ("campaign-session", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/session.gd"]),
    ("campaign-story-presentation", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/story_presentation.gd"]),
    ("campaign-story-gestures", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/story_gestures.gd"]),
    ("campaign-structure-art", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/structure_art.gd"]),
    ("campaign-landmark-art", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/landmark_art.gd"]),
    ("campaign-environment-art", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/environment_art.gd"]),
    ("campaign-smoke-route", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/smoke_route.gd"]),
    ("campaign-compact-ui", ["xvfb-run", "-a", "-s", "-screen 0 1280x800x24", "node", "port/campaign/live-capture.mjs", "--map=crown-array", "--profile=compact", "--output=" + os.environ.get("COCS_CAMPAIGN_CAPTURE_OUT", "/tmp/opencode/campaign-ui-verification")]),
    ("campaign-terrain", [binary, "--headless", "--path", "godot", "--script", "res://tests/campaign/terrain.gd"]),
    ("campaign-rootfall", ["node", "tools/godot-dev/launch.mjs", "--experience=campaign", "--map=rootfall-verge", "--smoke"]),
    ("campaign-siltwake", ["node", "tools/godot-dev/launch.mjs", "--experience=campaign", "--map=siltwake-crossing", "--smoke"]),
    ("campaign-emberline", ["node", "tools/godot-dev/launch.mjs", "--experience=campaign", "--map=emberline-ascent", "--smoke"]),
    ("campaign-crown", ["node", "tools/godot-dev/launch.mjs", "--experience=campaign", "--map=crown-array", "--smoke"]),
    ("main-menu-smoke", [binary, "--headless", "--path", "godot", "res://ui/main_menu.tscn", "--", "--smoke"]),
    ("main-menu-contracts", [binary, "--headless", "--path", "godot", "--script", "res://tests/main_menu/contracts.gd", "--", "--contracts"]),
    ("main-menu-attract-lifetime", [binary, "--headless", "--path", "godot", "--script", "res://tests/main_menu/lifetime.gd"]),
    ("main-menu-live-attract", [sys.executable, "tools/godot-dev/xvfb_run.py", binary, "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--script", "res://tests/main_menu/live_attract.gd"]),
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
    ("melee-feedback", [binary, "--headless", "--audio-driver", "Dummy", "--path", "godot", "--script", "res://tests/protocol/melee_feedback.gd"]),
    ("damage-numbers", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/damage_numbers.gd"]),
    ("local-lifecycle", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/local_lifecycle.gd"]),
    ("pickup-presentation", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/pickups.gd"]),
    ("entity-visuals", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/entity_visuals.gd"]),
    ("operator-geometry", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_models/geometry.gd"]),
    ("world-weapon-import", [binary, "--headless", "--path", "godot", "--script", "res://tests/source_operators/weapons.gd"]),
    ("world-weapon-grips", [binary, "--headless", "--path", "godot", "--script", "res://tests/source_operators/grips.gd"]),
    ("operator-detail-textures", [binary, "--headless", "--path", "godot", "--script", "res://tests/source_operators/textures.gd"]),
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
    ("world-weather-source-look", ["node", "scripts/world-weather-oracle.mjs", "--check"]),
    ("world-weather-native-look", [binary, "--headless", "--path", "godot", "--script", "res://tests/world_weather/unit.gd"]),
    ("world-weather-standalone", [binary, "--headless", "--path", "godot", "--script", "res://tests/world_weather/standalone.gd"]),
    ("world-weather-source-journey", ["node", "scripts/world-weather-journey.mjs", "source", "tidal-citadel", str(Path(os.environ['COCS_CAREER_ROOT']) / 'weather-source')]),
    ("world-weather-campaign-journey", ["node", "scripts/world-weather-journey.mjs", "campaign", "siltwake-crossing", str(Path(os.environ['COCS_CAREER_ROOT']) / 'weather-campaign')]),
    ("experience-source-captions", ["node", "tools/experience/extract.mjs", "--check"]),
    ("experience-native-information", [binary, "--headless", "--path", "godot", "--script", "res://tests/experience/contracts.gd"]),
    ("experience-combined-hud", [binary, "--headless", "--path", "godot", "--script", "res://tests/experience/combined.gd"]),
    ("experience-mode-journey", ["node", "tools/experience/native-journey.mjs", "--mode=vip-escort", "--compact", "--output=" + str(Path(os.environ['COCS_CAREER_ROOT']) / 'experience-mode')]),
    ("experience-campaign-journey", ["node", "tools/experience/native-journey.mjs", "--scenario=campaign", "--compact", "--output=" + str(Path(os.environ['COCS_CAREER_ROOT']) / 'experience-campaign')]),
    ("experience-sports-journey", ["node", "tools/experience/native-journey.mjs", "--scenario=sports", "--compact", "--output=" + str(Path(os.environ['COCS_CAREER_ROOT']) / 'experience-sports')]),
    ("experience-combined-arms-journey", ["node", "tools/experience/native-journey.mjs", "--scenario=combined_arms", "--compact", "--output=" + str(Path(os.environ['COCS_CAREER_ROOT']) / 'experience-combined-arms')]),
    ("player-gameplay-catalog", ["node", "port/next-port/gameplay/catalog.mjs", "--check"]),
    ("player-gameplay-source-fixtures", ["node", "port/next-port/gameplay/fixtures.mjs", "--check"]),
    ("player-gameplay-native", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_gameplay/test.gd"]),
    ("player-gameplay-live-input", ["node", "port/next-port/gameplay/live.mjs"]),
    ("competitive-source-modes", ["node", "--test", "port/next-port/modes/source-parity.test.mjs", "game/extra-modes.test.mjs"]),
    ("competitive-native-contracts", [binary, "--headless", "--path", "godot", "--script", "res://tests/mode_expansion/contracts.gd"]),
    ("competitive-native-arsenal", [sys.executable, "tools/godot-dev/xvfb_run.py", "node", "port/next-port/modes/native-proof.mjs", "--mode=arsenal"]),
    ("competitive-native-juggernaut", [sys.executable, "tools/godot-dev/xvfb_run.py", "node", "port/next-port/modes/native-proof.mjs", "--mode=juggernaut"]),
    ("competitive-native-elimination", [sys.executable, "tools/godot-dev/xvfb_run.py", "node", "port/next-port/modes/native-proof.mjs", "--mode=team-elimination"]),
    ("competitive-native-vip", [sys.executable, "tools/godot-dev/xvfb_run.py", "node", "port/next-port/modes/native-proof.mjs", "--mode=vip-escort"]),
    # Focused representatives only. Full normal-rate/multi-client matrices are
    # opt-in serial jobs in port/finish/matrix.json, with gate-specific deadlines.
    ("finish-gameplay-source", ["node", "tools/port/pass-two-gameplay/source.mjs", "--check"]),
    ("finish-gameplay-contract", [binary, "--headless", "--path", "godot", "--script", "res://tests/player_gameplay/second_pass_test.gd"]),
    ("finish-world-source", ["node", "scripts/world-weather-spatial-oracle.mjs", "--check"]),
    ("finish-world-contract", [sys.executable, "tools/godot-dev/xvfb_run.py", binary, "--audio-driver", "Dummy", "--path", "godot", "--script", "res://tests/world_weather/spatial.gd"]),
    ("finish-challenge-source", ["node", "--test", "port/pass-two/modes/challenges.test.mjs"]),
    ("finish-challenge-contract", [binary, "--headless", "--path", "godot", "--script", "res://tests/mode_expansion/challenges_contracts.gd"]),
    ("finish-spectator-source", ["node", "tools/experience/spectator-oracle.mjs", "--check"]),
    ("finish-spectator-contract", [binary, "--headless", "--path", "godot", "--script", "res://tests/experience/spectator_contract.gd"]),
    ("finish-spectator-camera", [binary, "--headless", "--path", "godot", "--script", "res://tests/experience/competitive_camera.gd"]),
    ("finish-horde-guidance", [binary, "--headless", "--path", "godot", "--script", "res://tests/horde_expansion/guidance_test.gd"]),
    ("finish-audio-source", ["node", "--test", "tools/godot-audiovisual/expansion/telegraph.test.mjs"]),
    ("finish-audio-contract", [binary, "--headless", "--audio-driver", "Dummy", "--path", "godot", "--script", "res://tests/audio_expansion/threat_gate.gd"]),
    ("finish-lattice-source", ["node", "tools/port/lattice/source-oracle.mjs"]),
    ("finish-lattice-contract", [binary, "--headless", "--path", "godot", "--script", "res://tests/lattice/expansion_feedback_contract.gd"]),
    ("finish-controls-source", ["node", "tools/port/input-bindings/source-oracle.mjs"]),
    ("finish-controls-contract", [binary, "--headless", "--path", "godot", "--script", "res://tests/input_bindings/contracts.gd"]),
    ("finish-replay-source", ["node", "--test", "tools/port/replay/adapter.test.mjs"]),
    ("finish-caption-source", ["node", "tools/port/finish/caption-oracle.mjs"]),
    ("finish-caption-integration", [binary, "--headless", "--path", "godot", "--script", "res://tests/finish/caption_integration.gd"]),
    ("finish-home-replays", [binary, "--headless", "--path", "godot", "--script", "res://tests/finish/home_replays.gd"]),
    ("finish-replay-bridge-negative", [binary, "--headless", "--path", "godot", "--script", "res://tests/finish/replay_bridge_negative.gd"]),
    ("finish-replay-bridge-source", ["node", "--test", "tools/port/finish/replay-bridge-contract.test.mjs"]),
    ("finish-package-closure", ["node", "--test", "tools/godot-package/finishing_closure.test.mjs"]),
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
            'selection': 'active' if active_source else 'explicit', 'path': derivative_path,
            'sha256': hashlib.sha256(derivative_bytes).hexdigest(),
            'source_commit': derivative['source_commit'],
            'derivative_commit': derivative['derivative_commit'],
        }
        save_report(report_path, report)
    except (OSError, ValueError, KeyError, TypeError) as error:
        fail_preflight(f'Invalid explicit COCS_SOURCE_DERIVATIVE: {error}')
if not binary:
    fail_preflight('Set GODOT_BIN to the pinned editor')
version, output = run_gate('toolchain-version', [binary, '--version'], 'port/reports/toolchain-version.log', timeout=10, candidate_id=candidate_id)
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
# Shared documented engine noise for the node/scene-tree family (see GATE_STATUS).
# Pre-existing prints from untouched node/transform access outside the scene tree;
# allowed only for gates that also print their success marker and exit 0.
_scene_tree_noise = (
    r'^ERROR: Cannot get path of node as it is not in a scene tree\.$',
    r'^ERROR: Condition "!is_inside_tree\(\)" is true\. Returning: Transform3D\(\)$',
)
gate_options = {
    'campaign-input-flow': {'timeout': 60},
    'campaign-client': {
        'success_marker': 'CAMPAIGN_CLIENT_OK',
        # The negative decode-once cases intentionally feed malformed JSON; the
        # base hook keeps its exact "Malformed JSON envelope" message, and Godot
        # itself logs this single parse error for that documented input.
        'allowed_error_patterns': (r'^ERROR: Parse JSON failed\. Error at line 0: Expected key$',),
    },
    'round-boundaries': {'success_marker': 'PORT_ROUND_BOUNDARIES_OK', 'allowed_error_patterns': _scene_tree_noise},
    'local-lifecycle': {'success_marker': 'PORT_LOCAL_LIFECYCLE_OK', 'allowed_error_patterns': _scene_tree_noise},
    'horde-model': {'success_marker': 'HORDE_TESTS', 'allowed_error_patterns': _scene_tree_noise},
    'horde-death-presentation': {'success_marker': 'HORDE_DEATH_CONTRACTS', 'allowed_error_patterns': _scene_tree_noise},
    'lattice-world': {'success_marker': 'WORLD_CONTRACT', 'allowed_error_patterns': _scene_tree_noise},
    'lattice-world-usability': {'success_marker': 'USABILITY_CONTRACT', 'allowed_error_patterns': _scene_tree_noise},
    'control-safety': {'success_marker': 'PORT_CONTROL_SAFETY_OK', 'allowed_error_patterns': _scene_tree_noise},
    'first-person-slide': {'timeout': 60},
    'campaign-compact-ui': {'timeout': 300},
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
gate_prerequisites = {
    'first-person-slide': ['godot/first_person/generated/weapon-0.glb'],
}
keep_going = os.environ.get('COCS_VERIFY_KEEP_GOING') == '1'
report['keep_going'] = keep_going
failed_gates = []
for name, command in commands:
    report['active_gate'] = name
    save_report(report_path, report)
    missing = [path for path in gate_prerequisites.get(name, []) if not (root / path).is_file()]
    if missing:
        output = 'Missing gate prerequisites: ' + ', '.join(missing) + '\n'
        Path(f'port/reports/{name}.log').write_text(f"# gate {name} candidate {candidate_id}\n" + output)
        result = {'gate': name, 'command': command, 'exit_code': None, 'passed': False,
                  'failure_reason': 'missing-prerequisite', 'duration_seconds': 0}
    else:
        result, output = run_gate(name, command, f'port/reports/{name}.log', candidate_id=candidate_id, **gate_options.get(name, {}))
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
release, output = run_gate('release-refused', ['node', 'tools/godot-export/semantic.mjs', '--release'], 'port/reports/release-refused.log', candidate_id=candidate_id)
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
