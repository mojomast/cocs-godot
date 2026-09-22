#!/usr/bin/env python3
"""Isolated Godot 4.5.2 verification and matched-camera GL captures; no services."""
import argparse
import hashlib
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


def run(command, env, log, timeout=180):
    with log.open('w') as stream:
        result = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, text=True, timeout=timeout)
    text = log.read_text()
    print(f'Godot import complete: {log}' if log.name == 'import.log' and result.returncode == 0 else text, end='\n', flush=True)
    if result.returncode or 'SCRIPT ERROR' in text or 'ERROR:' in text:
        raise RuntimeError(f'Failed: {log}')
    if log.name.startswith('verify') and 'ATMOSPHERE_VERIFY' not in text:
        raise RuntimeError(f'Missing verification completion: {log}')
    if log.name == 'capture.log' and 'ATMOSPHERE_GRAPHICAL_SMOKE' not in text:
        raise RuntimeError(f'Missing capture completion: {log}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'evidence')
    parser.add_argument('--content', type=Path, default=PRIMARY / 'godot/content/generated')
    parser.add_argument('--checks-only', action='store_true')
    parser.add_argument('--terrain-color-probe', action='store_true', help='Private Ember-only diagnostic: omit baseline CPU sRGB-to-linear vertex conversion')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='atmosphere-stage-', dir='/tmp/opencode') as runtime:
        stage = Path(runtime) / 'godot'
        shutil.copytree(ROOT / 'godot', stage, ignore=shutil.ignore_patterns('.godot', 'content'))
        shutil.copytree(args.content, stage / 'content/generated')
        if args.terrain_color_probe:
            viewer = stage / 'world/viewer.gd'
            source = viewer.read_text()
            old = 'surface.set_color(style.terrain_color(triangle).srgb_to_linear())'
            new = 'surface.set_color(style.terrain_color(triangle))'
            if source.count(old) != 1:
                raise RuntimeError('Terrain diagnostic baseline changed')
            viewer.write_text(source.replace(old, new))
            (out / 'private-staging-change.txt').write_text(f'PRIVATE DIAGNOSTIC ONLY, not applied to shared code\n- {old}\n+ {new}\n')
        # Bounded read-only source copies, private to this staging project. The
        # production controller receives textures from the external asset lane.
        fixtures = stage / 'tests/graphics_atmosphere/fixtures'
        fixtures.mkdir(parents=True, exist_ok=True)
        provenance = []
        for name in ['nebula', 'ashen', 'frost', 'void', 'ember']:
            source = ROOT / 'assets/moth/sources' / ('nebula.png' if name == 'nebula' else f'sky-{name}.png')
            data = source.read_bytes()
            if len(data) > 4 * 1024 * 1024:
                raise RuntimeError('Unexpected source sky size')
            (fixtures / f'{name}.png').write_bytes(data)
            provenance.append({'name': name, 'source': str(source.relative_to(ROOT)), 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
        (out / 'sky-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        env = dict(os.environ, PORT='0', LIBGL_ALWAYS_SOFTWARE='1', XDG_DATA_HOME=runtime + '/data', XDG_CONFIG_HOME=runtime + '/config', XDG_CACHE_HOME=runtime + '/cache', XDG_RUNTIME_DIR=runtime + '/xdg')
        Path(env['XDG_RUNTIME_DIR']).mkdir(mode=0o700)
        base = [GODOT, '--path', str(stage), '--audio-driver', 'Dummy', '--quit-after', '1200']
        run(base + ['--headless', '--editor', '--import', '--quit'], env, out / 'import.log')
        run(base + ['--headless', '--script', 'res://tests/graphics_atmosphere/verify.gd'], env, out / 'verify.log')
        if args.checks_only:
            return
        read_fd, write_fd = os.pipe()
        with (out / 'xvfb.log').open('w') as log:
            display = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'], pass_fds=(write_fd,), stdout=log, stderr=log)
            os.close(write_fd)
            try:
                if not select.select([read_fd], [], [], 10)[0]:
                    raise RuntimeError('Private Xvfb startup timed out')
                number = os.read(read_fd, 32).decode().strip()
                if not number.isdigit():
                    raise RuntimeError('Private Xvfb did not supply display')
                env['DISPLAY'] = ':' + number
                sizes = [(1280, 800)] if args.terrain_color_probe else [(960, 640), (1280, 800)]
                phases = ['after'] if args.terrain_color_probe else ['before', 'after']
                for width, height in sizes:
                    for phase in phases:
                        destination = out / f'{width}x{height}' / phase
                        destination.mkdir(parents=True, exist_ok=True)
                        extra = ['ember-crucible'] if args.terrain_color_probe else []
                        run(base + ['--rendering-method', 'gl_compatibility', '--resolution', f'{width}x{height}', '--script', 'res://tests/graphics_atmosphere/capture.gd', '--', str(destination), phase] + extra, env, destination / 'capture.log')
                run(base + ['--rendering-method', 'gl_compatibility', '--script', 'res://tests/graphics_atmosphere/verify.gd'], env, out / 'verify-graphical.log')
            finally:
                os.close(read_fd)
                display.terminate()
                try:
                    display.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    display.kill()
                    display.wait(timeout=5)


if __name__ == '__main__':
    main()
