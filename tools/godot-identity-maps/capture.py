#!/usr/bin/env python3
"""Bounded graphical capture runner. Does not touch shared displays/services."""
import argparse
import json
import os
from pathlib import Path
import signal
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT_BIN', '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
p = argparse.ArgumentParser()
p.add_argument('--sizes', default='960x640,1920x1080')
p.add_argument('--graybox', action='store_true')
p.add_argument('--glow', action='store_true')
a = p.parse_args()
base = ROOT / 'port/native-identity-maps/evidence' / f'render-{time.time_ns()}'
base.mkdir(parents=True)
results = []
for size in a.sizes.split(','):
    width, height = map(int, size.split('x'))
    target = base / size
    cmd = ['xvfb-run', '-a', '-s', f'-screen 0 {width}x{height}x24 -nolisten tcp', GODOT, '--path', str(ROOT/'godot'), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://tests/identity_maps/capture.gd', '--', f'--output={target}', f'--size={size}']
    if a.graybox:
        cmd.append('--graybox')
    if a.glow:
        cmd.append('--glow')
    with (base / f'{size}.log').open('w') as log:
        proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = proc.wait(timeout=180)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
            code = 124
    text = (base / f'{size}.log').read_text()
    images = list(target.glob('*.png'))
    png_sizes = {q.name: struct.unpack('>II', q.read_bytes()[16:24]) for q in images}
    dimensions_ok = len(images) == 15 and all(s == (width, height) for s in png_sizes.values())
    passed = code == 0 and 'SCRIPT ERROR' not in text and (target/'report.json').is_file() and dimensions_ok
    results.append({'size': size, 'code': code, 'passed': passed, 'png_sizes': png_sizes, 'command': cmd})
    print(json.dumps({'directory': str(target), 'code': code, 'passed': passed}), flush=True)
(base/'runner.json').write_text(json.dumps(results, indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
