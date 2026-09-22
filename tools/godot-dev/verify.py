"""Run actual port gates; fail on Godot errors even when its exit code is zero."""
import json
import os
from pathlib import Path
import subprocess
import sys
from gate_runner import run_gate, save_report

root = Path(__file__).resolve().parents[2]
os.chdir(root)
report_path = Path('port/reports/verification.json')
report = {'status': 'running', 'gates': []}
save_report(report_path, report)
def fail_preflight(message):
    report.update(status='failed', failure_reason=message)
    save_report(report_path, report)
    raise SystemExit(message)


binary = os.environ.get("GODOT_BIN")
if not binary:
    fail_preflight("Set GODOT_BIN to the pinned editor")
lock = json.loads(Path("port/contracts/source-lock.json").read_text())
version, output = run_gate('toolchain-version', [binary, '--version'], 'port/reports/toolchain-version.log', timeout=10)
report['gates'].append(version)
if not version['passed']:
    fail_preflight('Godot version probe failed')
if output.strip() != lock["godot_version"]:
    version.update(passed=False, failure_reason='version-mismatch')
    fail_preflight("Godot version mismatch")
for key, suffix in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
    os.environ.setdefault(key, str(root / ".port-runtime" / suffix))
    Path(os.environ[key]).mkdir(parents=True, exist_ok=True)
commands = [
    ("gate-runner-tests", [sys.executable, "tools/godot-dev/test_gate_runner.py"]),
    ("export-tests", ["node", "--test", "tools/godot-export/semantic.test.mjs"]),
    ("semantic-export", ["node", "tools/godot-export/semantic.mjs"]),
    ("source-tests", ["node", "--test", "game/protocol.test.mjs", "game/arena-movement.test.mjs", "game/map-schema.test.mjs", "game/destination-maps.test.mjs", "game/destination-sports.test.mjs", "game/destination-lattice.test.mjs"]),
    ("godot-import", [binary, "--headless", "--path", "godot", "--editor", "--import"]),
    ("viewer-smoke", [binary, "--headless", "--path", "godot", "--", "--smoke"]),
    ("glb-import", [binary, "--headless", "--path", "godot", "--script", "res://tests/import.gd"]),
    ("input-queue", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/input_queue.gd"]),
    ("protocol-envelopes", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/envelopes.gd"]),
    ("packet-replay", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/replay.gd"]),
    ("native-live", ["node", "tools/godot-dev/launch.mjs", "--network-smoke"]),
    ("presentation-replay", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/presentation.gd"]),
    ("round-boundaries", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/round_boundaries.gd"]),
    ("native-lifecycle", ["node", "tools/godot-dev/launch.mjs", "--lifecycle-smoke"]),
    ("combat-feedback", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/combat_feedback.gd"]),
    ("audio-feedback", [binary, "--headless", "--audio-driver", "Dummy", "--path", "godot", "--script", "res://tests/protocol/audio_feedback.gd"]),
    ("local-lifecycle", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/local_lifecycle.gd"]),
    ("pickup-presentation", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/pickups.gd"]),
    ("native-trace", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/native_trace.gd"]),
    ("guest-session", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/guest_session.gd"]),
    ("match-selection", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/match_selection.gd"]),
    ("scoreboard", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/scoreboard.gd"]),
    ("scoreboard-session", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/scoreboard_session.gd"]),
    ("control-safety", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/control_safety.gd"]),
    ("window-focus", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/window_focus.gd"]),
    ("session-recovery", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/session_recovery.gd"]),
    ("stall-controls", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/stall_controls.gd"]),
    ("snapshot-watch", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/snapshot_watch.gd"]),
    ("native-session", ["node", "tools/godot-dev/launch.mjs", "--session-smoke"]),
    ("two-native-clients", ["node", "tools/godot-dev/two-clients.mjs"]),
    ("motion-impairment", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/impairment.gd"]),
    ("remote-motion", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/remote_motion.gd"]),
]
report['source_commit'] = lock['source_commit']
results = report['gates']
for name, command in commands:
    report['active_gate'] = name
    save_report(report_path, report)
    result, output = run_gate(name, command, f'port/reports/{name}.log')
    results.append(result)
    report['status'] = 'running' if result['passed'] else 'failed'
    save_report(report_path, report)
    print(f"{name}: {'PASS' if result['passed'] else 'FAIL'}", flush=True)
    if not result['passed']:
        print(output)
        raise SystemExit(1)
report['active_gate'] = 'release-refused'
save_report(report_path, report)
release, output = run_gate('release-refused', ['node', 'tools/godot-export/semantic.mjs', '--release'], 'port/reports/release-refused.log')
release['passed'] = release['exit_code'] not in (None, 0) and release['failure_reason'] == 'nonzero-exit' and 'Release disabled' in output
release['failure_reason'] = None if release['passed'] else 'release-guard-failure'
results.append(release)
report['status'] = 'passed' if release['passed'] else 'failed'
report.pop('active_gate', None)
save_report(report_path, report)
if not release['passed']:
    raise SystemExit('Release gate failed open')
print("All implemented gates passed. Visual fidelity and playable acceptance remain OPEN.")
