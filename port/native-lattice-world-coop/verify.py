"""Repeatable owned checks/live cases. No automatic retries; retain every failure."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('mode', choices=['checks', 'live'])
parser.add_argument('--map', choices=['asterion-relay', 'monsoon-foundry'])
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
os.chdir(root)
binary = os.environ.get('GODOT_BIN', '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
out = Path('port/native-lattice-world-coop/evidence') / str(time.time_ns())
out.mkdir(parents=True)
if args.mode == 'checks':
    cases = [
        ('semantic', ['node', 'tools/godot-export/semantic.mjs'], 120),
        ('import', [binary, '--headless', '--path', 'godot', '--editor', '--import'], 120),
        ('observer-parse', [binary, '--headless', '--path', 'godot', '--check-only', '--script', 'res://tests/lattice/world_coop_live.gd'], 30),
        ('separate-lease-fixture', [binary, '--headless', '--path', 'godot', '--script', 'res://tests/lattice/world_commands_contract.gd'], 30),
    ]
else:
    cases = []
    for map_id, size in [('asterion-relay', '960x640'), ('monsoon-foundry', '1280x800')]:
        if args.map and args.map != map_id:
            continue
        cases.append((map_id, ['node', 'port/native-lattice-world-coop/run.mjs', f'--map={map_id}',
                               f'--size={size}', f'--output={(out / map_id).resolve()}'], 210))

results = []
for name, command, timeout in cases:
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix='world-coop-check-', dir='/tmp/opencode') as runtime:
        env = dict(os.environ, GODOT_BIN=binary, TMPDIR='/tmp/opencode')
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            env[key] = str(Path(runtime) / key)
            Path(env[key]).mkdir()
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, env=env, start_new_session=True)
        try:
            text, _ = process.communicate(timeout=timeout)
            code = process.returncode
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                text, _ = process.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                text, _ = process.communicate()
            text += '\nWRAPPER TIMEOUT\n'
            code = 124
    (out / f'{name}.log').write_text(text)
    passed = code == 0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text
    cleanup = {}
    if args.mode == 'live':
        path = out / name / 'cleanup.json'
        cleanup = json.loads(path.read_text()) if path.exists() else {}
        passed = passed and all(cleanup.get(key) is True for key in ['httpClosed', 'nativeExited', 'xvfbExited', 'runtimeRemoved'])
        manifest_path = out / name / 'manifest.json'
        manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
        pids = [manifest.get('nativePid'), manifest.get('serverPid'), manifest.get('xvfb', {}).get('pid')]
        dead = bool(all(pids)) and all(not Path(f'/proc/{pid}').exists() for pid in pids)
        cleanup['recordedPidsGone'] = dead
        (out / name / 'process-cleanup.json').write_text(json.dumps(cleanup, indent=2) + '\n')
        passed = passed and dead
    results.append(dict(name=name, command=command, timeoutSeconds=timeout, elapsedSeconds=time.monotonic()-started,
                        exit=code, passed=passed, cleanup=cleanup))
    (out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(name, 'PASS' if passed else 'FAIL', str(out), flush=True)
    if not passed:
        print(text[-5000:], flush=True)
        if args.mode == 'checks':
            break
raise SystemExit(0 if len(results) == len(cases) and all(r['passed'] for r in results) else 1)
