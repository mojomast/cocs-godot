"""Run bounded attempts; preserve output and check engine errors, not just exit code."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

out = Path('port/native-lattice/evidence') / str(time.time_ns())
out.mkdir(parents=True)
binary = os.environ['GODOT_BIN']
cases = [(name, [binary, '--headless', '--path', 'godot', '--script', f'res://tests/lattice/{name}.gd']) for name in ['adapter', 'ui']]
if '--source' in sys.argv:
    cases += [('semantic', ['node', 'tools/godot-export/semantic.mjs']),
              ('import', [binary, '--headless', '--path', 'godot', '--editor', '--import']),
              ('source-tests', ['node', '--test', 'game/cocs-wire.test.mjs', 'game/cocs-spend-surface.test.mjs', 'game/destination-lattice.test.mjs', 'server/cocs-net.test.mjs'])]
if '--live' in sys.argv:
    for map_id in ['asterion-relay', 'monsoon-foundry']:
        for mode in ['cocs', 'cocs-coop']:
            cases.append((map_id + '-' + mode, ['node', 'port/tools/native_lattice_demo/run.mjs', '--headless', '--smoke', '--map=' + map_id, '--mode=' + mode]))
if '--graphical' in sys.argv:
    for map_id, size in [('asterion-relay', '960x640'), ('monsoon-foundry', '1280x800')]:
        screenshot = (out / (map_id + '.png')).resolve()
        cases.append((map_id + '-graphical', ['xvfb-run', '-a', '-s', '-screen 0 1400x1000x24 -nolisten tcp', 'node', 'port/tools/native_lattice_demo/run.mjs', '--smoke', '--map=' + map_id, '--size=' + size, '--capture=' + str(screenshot)]))
results = []
for name, command in cases:
    started = time.monotonic()
    import tempfile
    with tempfile.TemporaryDirectory(prefix='lattice-check-') as runtime:
        env = dict(os.environ)
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            env[key] = str(Path(runtime) / key)
            Path(env[key]).mkdir()
        run = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=130, env=env)
    (out / (name + '.log')).write_text(run.stdout)
    passed = run.returncode == 0 and 'SCRIPT ERROR' not in run.stdout and 'ERROR:' not in run.stdout
    results.append(dict(name=name, command=command, exit=run.returncode, passed=passed, seconds=time.monotonic()-started))
    print(name, 'PASS' if passed else 'FAIL', 'log:', out / (name + '.log'), flush=True)
    if not passed:
        print(run.stdout[-5000:], flush=True)
(out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
sys.exit(0 if all(r['passed'] for r in results) else 1)
