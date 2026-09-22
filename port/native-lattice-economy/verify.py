"""Scoped verification. Keep every attempt and run owned private X displays."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import sys

out = Path('port/native-lattice-economy/evidence') / str(time.time_ns())
out.mkdir(parents=True)
binary = os.environ['GODOT_BIN']
group = sys.argv[1] if len(sys.argv) > 1 else 'all'
cases = []
if group in ('all', 'checks'):
    cases += [
        ('semantic', ['node', 'tools/godot-export/semantic.mjs']),
        ('source', ['node', '--test', 'game/cocs-coop-o1c.test.mjs', 'game/cocs-spend-surface.test.mjs', 'server/cocs-net.test.mjs', 'server/cocs-visibility.test.mjs']),
        ('import', [binary, '--headless', '--path', 'godot', '--editor', '--import']),
        *[(name, [binary, '--headless', '--path', 'godot', '--script', f'res://tests/lattice/{name}.gd']) for name in ['adapter', 'ui', 'map_view', 'economy']],
    ]
if group in ('all', 'live'):
    for map_id in ['asterion-relay', 'monsoon-foundry']:
        name = f'economy-{map_id}-960x640'
        cases.append((name, ['xvfb-run', '-a', '-s', '-screen 0 1400x1000x24 -nolisten tcp -nolisten unix',
                            'node', 'port/native-lattice-economy/run.mjs', f'--map={map_id}', '--size=960x640',
                            f'--output={(out / name).resolve()}']))
if group in ('all', 'regression'):
    for lane in ['native-lattice-map', 'native-lattice-physical']:
        for map_id, mode, size in [('asterion-relay', 'cocs', '960x640'), ('monsoon-foundry', 'cocs', '1280x800'), ('asterion-relay', 'cocs-coop', '960x640')]:
            name = f'{lane}-{map_id}-{mode}-{size}'
            cases.append((name, ['xvfb-run', '-a', '-s', '-screen 0 1400x1000x24 -nolisten tcp -nolisten unix',
                                'node', f'port/{lane}/run.mjs', f'--map={map_id}', f'--mode={mode}', f'--size={size}',
                                f'--output={(out / name).resolve()}']))
results = []
for name, command in cases:
    with tempfile.TemporaryDirectory(prefix='economy-check-', dir='/tmp/opencode') as runtime:
        env = dict(os.environ)
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            env[key] = str(Path(runtime) / key)
            Path(env[key]).mkdir()
        try:
            run = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=320, env=env)
            output, code = run.stdout, run.returncode
        except subprocess.TimeoutExpired as exc:
            output = (exc.stdout or b'').decode() if isinstance(exc.stdout, bytes) else (exc.stdout or '')
            output += '\nVERIFIER TIMEOUT\n'
            code = 124
    (out / f'{name}.log').write_text(output)
    passed = code == 0 and 'SCRIPT ERROR' not in output and 'ERROR:' not in output
    results.append(dict(name=name, command=command, exit=code, passed=passed))
    (out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(name, 'PASS' if passed else 'FAIL', str(out), flush=True)
    if not passed:
        print(output[-5000:], flush=True)
        break
raise SystemExit(0 if results and all(result['passed'] for result in results) else 1)
