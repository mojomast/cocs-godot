"""Bounded private-display runs; preserve every attempt under a new directory."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

out = Path('port/native-lattice-physical/evidence') / str(time.time_ns())
out.mkdir(parents=True)
binary = os.environ['GODOT_BIN']
cases = [
    ('semantic', ['node', 'tools/godot-export/semantic.mjs']),
    ('import', [binary, '--headless', '--path', 'godot', '--editor', '--import']),
    *[(name, [binary, '--headless', '--path', 'godot', '--script', f'res://tests/lattice/{name}.gd']) for name in ['adapter', 'ui']],
]
for map_id, mode, size in [('asterion-relay', 'cocs', '960x640'), ('monsoon-foundry', 'cocs', '1280x800'), ('asterion-relay', 'cocs-coop', '960x640')]:
    name = f'{map_id}-{mode}-{size}'
    cases.append((name, ['xvfb-run', '-a', '-s', '-screen 0 1400x1000x24 -nolisten tcp -nolisten unix',
                        'node', 'port/native-lattice-physical/run.mjs', f'--map={map_id}', f'--mode={mode}',
                        f'--size={size}', f'--output={(out / name).resolve()}']))
results = []
for name, command in cases:
    with tempfile.TemporaryDirectory(prefix='physical-check-', dir='/tmp/opencode') as runtime:
        env = dict(os.environ)
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            env[key] = str(Path(runtime) / key)
            Path(env[key]).mkdir()
        run = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120, env=env)
    (out / f'{name}.log').write_text(run.stdout)
    passed = run.returncode == 0 and 'SCRIPT ERROR' not in run.stdout and 'ERROR:' not in run.stdout
    results.append(dict(name=name, command=command, exit=run.returncode, passed=passed))
    (out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(name, 'PASS' if passed else 'FAIL', str(out), flush=True)
    if not passed:
        print(run.stdout[-5000:], flush=True)
        break
raise SystemExit(0 if all(result['passed'] for result in results) else 1)
