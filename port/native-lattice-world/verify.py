"""Bounded normal-rate runs; preserve each attempt with private Xvfb lifecycle."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

out = Path('port/native-lattice-world/evidence') / str(time.time_ns())
out.mkdir(parents=True)
binary = os.environ['GODOT_BIN']
cases = [
    ('semantic', ['node', 'tools/godot-export/semantic.mjs']),
    ('import', [binary, '--headless', '--path', 'godot', '--editor', '--import']),
    ('contract', [binary, '--headless', '--path', 'godot', '--script', 'res://tests/lattice/world_contract.gd']),
]
for map_id, mode in [('asterion-relay', 'cocs'), ('monsoon-foundry', 'cocs-coop')]:
    name = f'{map_id}-{mode}'
    cases.append((name, ['xvfb-run', '-a', '-s', '-screen 0 1400x1000x24 -nolisten tcp -nolisten unix',
                        'node', 'port/native-lattice-world/run.mjs', f'--map={map_id}', f'--mode={mode}',
                        '--size=1280x800', f'--output={(out / name).resolve()}']))
results = []
for name, command in cases:
    with tempfile.TemporaryDirectory(prefix='world-check-', dir='/tmp/opencode') as runtime:
        env = dict(os.environ)
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            env[key] = str(Path(runtime) / key)
            Path(env[key]).mkdir()
        try:
            run = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120, env=env)
            text, code = run.stdout, run.returncode
        except subprocess.TimeoutExpired as error:
            text = str(error.stdout) + '\nWRAPPER TIMEOUT'
            code = 124
    (out / f'{name}.log').write_text(text)
    passed = code == 0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text
    results.append(dict(name=name, command=command, exit=code, passed=passed))
    (out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(name, 'PASS' if passed else 'FAIL', str(out), flush=True)
    if not passed:
        print(text[-3000:], flush=True)
        break
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
