"""Run actual port gates; fail on Godot errors even when its exit code is zero."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[2]
os.chdir(root)
binary = os.environ.get("GODOT_BIN")
if not binary:
    raise SystemExit("Set GODOT_BIN to the pinned editor")
lock = json.loads(Path("port/contracts/source-lock.json").read_text())
if subprocess.check_output([binary, "--version"], text=True).strip() != lock["godot_version"]:
    raise SystemExit("Godot version mismatch")
for key, suffix in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
    os.environ.setdefault(key, str(root / ".port-runtime" / suffix))
    Path(os.environ[key]).mkdir(parents=True, exist_ok=True)
commands = [
    ("export-tests", ["node", "--test", "tools/godot-export/semantic.test.mjs"]),
    ("semantic-export", ["node", "tools/godot-export/semantic.mjs"]),
    ("source-tests", ["node", "--test", "game/protocol.test.mjs", "game/arena-movement.test.mjs", "game/map-schema.test.mjs", "game/destination-maps.test.mjs", "game/destination-sports.test.mjs", "game/destination-lattice.test.mjs"]),
    ("godot-import", [binary, "--headless", "--path", "godot", "--editor", "--import"]),
    ("viewer-smoke", [binary, "--headless", "--path", "godot", "--", "--smoke"]),
    ("glb-import", [binary, "--headless", "--path", "godot", "--script", "res://tests/import.gd"]),
    ("packet-replay", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/replay.gd"]),
    ("native-live", ["node", "tools/godot-dev/launch.mjs", "--network-smoke"]),
    ("presentation-replay", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/presentation.gd"]),
    ("native-session", ["node", "tools/godot-dev/launch.mjs", "--session-smoke"]),
    ("remote-motion", [binary, "--headless", "--path", "godot", "--script", "res://tests/protocol/remote_motion.gd"]),
]
results = []
for name, command in commands:
    run = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    Path(f"port/reports/{name}.log").write_text(run.stdout)
    failed = run.returncode != 0 or "SCRIPT ERROR:" in run.stdout or "ERROR:" in run.stdout
    print(f"{name}: {'FAIL' if failed else 'PASS'}")
    results.append({"gate": name, "command": command, "exit_code": run.returncode, "passed": not failed})
    if failed:
        print(run.stdout)
        raise SystemExit(1)
release = subprocess.run(["node", "tools/godot-export/semantic.mjs", "--release"], capture_output=True, text=True)
if release.returncode == 0 or "Release disabled" not in release.stderr:
    raise SystemExit("Release gate failed open")
results.append({"gate": "release-refused", "passed": True})
Path("port/reports/verification.json").write_text(json.dumps({"source_commit": lock["source_commit"], "gates": results}, indent=2) + "\n")
print("All implemented gates passed. Visual fidelity and playable acceptance remain OPEN.")
