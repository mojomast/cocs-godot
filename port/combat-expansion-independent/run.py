"""Private Compatibility review process; no shared scene/editor or repository copy."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
OUT = ROOT / 'port/combat-expansion-independent/evidence'
OUT.mkdir(parents=True, exist_ok=True)
private = Path(tempfile.mkdtemp(prefix='combat-independent-', dir='/tmp/opencode'))
env = os.environ.copy()
for key in ['HOME', 'TMPDIR', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'XDG_RUNTIME_DIR']:
    folder = private / key
    folder.mkdir(mode=0o700)
    env[key] = str(folder)
for display in range(241, 290):
    with socket.socket() as sock:
        try:
            sock.bind(('127.0.0.1', 6000 + display))
            break
        except OSError:
            continue
env['DISPLAY'] = f'localhost:{display}'
stamp = str(time.time_ns())
with (OUT / f'xvfb-{stamp}.log').open('w') as log:
    xvfb = subprocess.Popen(['Xvfb', f':{display}', '-screen', '0', '1400x900x24', '-nolisten', 'unix', '-listen', 'tcp', '-ac'], stdout=log, stderr=subprocess.STDOUT, env=env)
    try:
        for _ in range(100):
            try:
                with socket.create_connection(('127.0.0.1', 6000 + display), timeout=.1):
                    break
            except OSError:
                time.sleep(.05)
        runs = []
        if '--graphics-only' not in sys.argv:
            runs.append(('source', ['node', 'port/combat-expansion-independent/source-oracle.mjs']))
            runs.append(('delivered-binding-contract', [str(GODOT), '--path', 'godot', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://tests/first_person/binding.gd']))
        for size in ['960x640', '1280x800']:
            target = OUT / size
            target.mkdir(exist_ok=True)
            runs.append((size, [str(GODOT), '--path', 'godot', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://tests/combat_expansion_independent/review.gd', '--', f'--size={size}', f'--output={target}']))
        for label, command in runs:
            result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
            (OUT / f'{label}-{stamp}.log').write_text(result.stdout)
            print(f'{label} exit={result.returncode}\n{result.stdout}', flush=True)
            if result.returncode or any(word in result.stdout for word in ['SCRIPT ERROR', 'Parse Error', 'ERROR:', 'instances leaked', 'resources still in use']):
                raise RuntimeError(f'{label} failed; attempt retained')
    finally:
        xvfb.terminate()
        xvfb.wait(timeout=10)
