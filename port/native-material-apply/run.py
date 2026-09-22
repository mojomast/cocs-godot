#!/usr/bin/env python3
"""Material-apply lane evidence harness.

Stages a private copy of `godot/` (plus this lane's capture script) under a temp
directory, imports it with the pinned Godot 4.5.2, and renders the fixed-camera
evidence at 960x640 and 1280x800 from a private Xvfb + software GL.

The staged copy is deliberate: running captures must not touch the shared
`.godot` import cache, and the same command produces the "before" images from
current sources and the "after" images once the application pass is in.

    python3 port/native-material-apply/run.py --phase before
    python3 port/native-material-apply/run.py --phase after  --maps=prism-foundry
    python3 port/native-material-apply/run.py --phase after  --glow
    python3 port/native-material-apply/run.py --phase after  --gates
"""
import argparse
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PRIMARY = Path('/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port')
GODOT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
SIZES = {'960x640': (960, 640), '1280x800': (1280, 800)}
GATES = [
    'graphics_batch/terrain_contract',
    'graphics_atmosphere/verify',
    'graphics_fx/regression',
    'moth_scenery/verify',
    'moth/validate',
    'shader_lab/validate',
]


def run(command, env, log, marker=None, timeout=900):
    with log.open('w') as stream:
        result = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, text=True, timeout=timeout)
    text = log.read_text()
    if result.returncode:
        raise RuntimeError(f'Exit {result.returncode}: {log}')
    if 'SCRIPT ERROR' in text:
        raise RuntimeError(f'Script error: {log}')
    if marker and marker not in text:
        raise RuntimeError(f'Missing {marker}: {log}')
    print(f'  ok {log.relative_to(log.parents[3]) if len(log.parents) > 3 else log.name}')
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=['before', 'after'], required=True)
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'evidence')
    parser.add_argument('--maps', default='')
    parser.add_argument('--glow', action='store_true', help='render the glow-on A/B set instead of the core set')
    parser.add_argument('--census', action='store_true', help='also write the per-map material/texture census for this phase')
    parser.add_argument('--gates', action='store_true', help='re-run the material-owning gates against the staged project')
    parser.add_argument('--size', choices=sorted(SIZES), default='')
    args = parser.parse_args()
    out = args.output.resolve()
    (out / 'logs').mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='material-apply-', dir='/tmp/opencode') as runtime:
        stage = Path(runtime) / 'godot'
        shutil.copytree(PRIMARY / 'godot', stage, ignore=shutil.ignore_patterns('.godot'))
        (stage / 'tests/material_apply').mkdir(parents=True, exist_ok=True)
        shutil.copy(Path(__file__).parent / 'capture.gd', stage / 'tests/material_apply/capture.gd')
        shutil.copy(Path(__file__).parent / 'census.gd', stage / 'tests/material_apply/census.gd')
        env = dict(os.environ, PORT='0', LIBGL_ALWAYS_SOFTWARE='1',
                   XDG_DATA_HOME=runtime + '/data', XDG_CONFIG_HOME=runtime + '/config',
                   XDG_CACHE_HOME=runtime + '/cache', XDG_RUNTIME_DIR=runtime + '/xdg',
                   LP_NUM_THREADS='8')
        Path(env['XDG_RUNTIME_DIR']).mkdir(mode=0o700)
        base = [GODOT, '--path', str(stage), '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility']
        print(f'[{args.phase}] import staged project')
        run(base + ['--headless', '--editor', '--import', '--quit'], env, out / 'logs' / f'import-{args.phase}.log', timeout=600)
        if args.census:
            run(base + ['--headless', '--script', 'res://tests/material_apply/census.gd', '--',
                       f'--output={out / f"census-{args.phase}.json"}'],
                env, out / 'logs' / f'census-{args.phase}.log', marker='MATERIAL_APPLY_CENSUS')
        read_fd, write_fd = os.pipe()
        with (out / 'logs' / f'xvfb-{args.phase}.log').open('w') as log:
            display = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1280x800x24',
                                        '-nolisten', 'tcp', '-nolisten', 'unix'],
                                       pass_fds=(write_fd,), stdout=log, stderr=log)
            os.close(write_fd)
            try:
                if not select.select([read_fd], [], [], 10)[0]:
                    raise RuntimeError('private Xvfb startup timed out')
                env['DISPLAY'] = ':' + os.read(read_fd, 32).decode().strip()
                sizes = [args.size] if args.size else sorted(SIZES)
                for size in sizes:
                    width, height = SIZES[size]
                    destination = out / size / args.phase
                    destination.mkdir(parents=True, exist_ok=True)
                    extra = ['--maps=' + args.maps] if args.maps else []
                    extra += ['--glow'] if args.glow else []
                    run(base + ['--resolution', f'{width}x{height}', '--script', 'res://tests/material_apply/capture.gd',
                               '--', f'--output={destination}', f'--size={size}', f'--phase={args.phase}'] + extra,
                        env, out / 'logs' / f'capture-{args.phase}-{size}{"-glow" if args.glow else ""}.log',
                        marker='MATERIAL_APPLY_CAPTURE_DONE')
                if args.gates:
                    for gate in GATES:
                        run([GODOT, '--headless', '--path', str(stage), '--script', f'res://tests/{gate}.gd'],
                            env, out / 'logs' / f'gate-{gate.replace("/", "-")}-{args.phase}.log')
            finally:
                display.terminate()
                try:
                    display.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    display.kill()
                    display.wait(timeout=5)
    print(f'[{args.phase}] evidence written to {out}')


if __name__ == '__main__':
    main()
