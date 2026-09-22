"""Owned repeatable acceptance; every attempt is retained, including failures."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

out = Path('port/native-lattice-world-commands/evidence') / str(time.time_ns())
out.mkdir(parents=True)
binary = os.environ['GODOT_BIN']
cases = [
    ('semantic', ['node', 'tools/godot-export/semantic.mjs']),
    ('import', [binary, '--headless', '--path', 'godot', '--editor', '--import']),
    ('world-contract', [binary, '--headless', '--path', 'godot', '--script', 'res://tests/lattice/world_contract.gd']),
    ('commands-contract', [binary, '--headless', '--path', 'godot', '--script', 'res://tests/lattice/world_commands_contract.gd']),
]
for name, script, map_id, mode, size in [
    ('commands-small', 'native-lattice-world-commands', 'asterion-relay', 'cocs', '960x640'),
    ('commands-large', 'native-lattice-world-commands', 'monsoon-foundry', 'cocs-coop', '1280x800'),
    ('world-asterion', 'native-lattice-world', 'asterion-relay', 'cocs', '1280x800'),
    ('world-monsoon', 'native-lattice-world', 'monsoon-foundry', 'cocs-coop', '1280x800'),
]:
    cases.append((name, ['xvfb-run', '-a', '-s', '-screen 0 1400x1000x24 -nolisten tcp -nolisten unix',
                        'node', f'port/{script}/run.mjs', f'--map={map_id}', f'--mode={mode}',
                        f'--size={size}', f'--output={(out / name).resolve()}']))
results = []
for name, command in cases:
    with tempfile.TemporaryDirectory(prefix='world-commands-check-', dir='/tmp/opencode') as runtime:
        env = dict(os.environ, TMPDIR='/tmp/opencode')
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            env[key] = str(Path(runtime) / key)
            Path(env[key]).mkdir()
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, env=env, start_new_session=True)
        try:
            text, _ = process.communicate(timeout=120)
            code = process.returncode
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                text, _ = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                text, _ = process.communicate()
            text += '\nWRAPPER TIMEOUT\n'
            code = 124
    (out / f'{name}.log').write_text(text)
    passed = code == 0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text
    cleanup_path = out / name / 'cleanup.json'
    if name.startswith('commands-') and name != 'commands-contract' or name in ['world-asterion', 'world-monsoon']:
        cleanup = json.loads(cleanup_path.read_text()) if cleanup_path.exists() else {}
        passed = passed and all(cleanup.get(key) is True for key in ['httpClosed', 'nativeExited', 'runtimeRemoved'])
    results.append(dict(name=name, command=command, exit=code, passed=passed))
    (out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(name, 'PASS' if passed else 'FAIL', str(out), flush=True)
    if not passed:
        print(text[-4000:], flush=True)
        break
raise SystemExit(0 if len(results) == len(cases) and all(r['passed'] for r in results) else 1)
