#!/usr/bin/env python3
"""Private pinned-Godot source-map smoke and matched native scenery captures."""
import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
PRIMARY = Path('/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port')
GODOT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'


def stage_materials(stage, output):
    """Exact PRIVATE baseline adaptations, recorded as an unapplied diff.

    The lead owns real semantic material mapping. This bounded approximation
    puts the inherited triplanar renderer underneath our mounted accents so
    their contrast is reviewed on textured walls as well as source geometry.
    """
    path = stage / 'world/environment_style.gd'
    before = path.read_text()
    after = before.replace('extends RefCounted\n', 'extends RefCounted\nconst MothSurfaces = preload("res://moth/surfaces.gd")\n', 1)
    old = '\t\tvar mat := ShaderMaterial.new()\n\t\tmat.shader = shader\n\t\tmat.set_shader_parameter("tint", color)\n\t\tmat.set_shader_parameter("seams", seams)'
    new = '\t\tvar texture_key := "weathered_concrete-worn"\n\t\tif key in ["equipment", "structure"]: texture_key = "metal"\n\t\telif key in ["rock", "bark"]: texture_key = "rock-moss"\n\t\telif key == "terrain": texture_key = "weathered_concrete"\n\t\tvar mat := MothSurfaces.create_surface(texture_key, color)'
    if after.count(old) != 1:
        raise RuntimeError('Private material patch baseline mismatch')
    after = after.replace(old, new)
    path.write_text(after)
    patch = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='a/godot/world/environment_style.gd', tofile='b/godot/world/environment_style.gd'))
    path = stage / 'world/viewer.gd'
    before = path.read_text()
    old = 'surface.set_color(style.terrain_color(triangle).srgb_to_linear())'
    if before.count(old) != 1:
        raise RuntimeError('Private terrain patch baseline mismatch')
    after = before.replace(old, 'surface.set_color(style.terrain_color(triangle))')
    path.write_text(after)
    patch += ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='a/godot/world/viewer.gd', tofile='b/godot/world/viewer.gd'))
    (output / 'private-staging.patch').write_text(patch)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content', type=Path, default=PRIMARY / 'godot/content/generated')
    parser.add_argument('--checks-only', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    evidence = ROOT / 'port/native-moth-scenery/evidence'
    evidence.mkdir(parents=True, exist_ok=True)
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='run-', dir=evidence))
    output.mkdir(parents=True, exist_ok=True)
    if (output / 'summary.json').exists():
        raise RuntimeError('Refusing to overwrite prior evidence')
    results = []
    metadata = {'baseline': '7bfb473', 'engine': GODOT, 'renderer': 'GL Compatibility / llvmpipe', 'results': results, 'private_adaptations': ['recorded private-staging.patch', 'capture.gd applies inherited Atmosphere + original Library.sky identically to before/after', 'capture.gd calls Scenery.create after ordinary style.decorate', 'clock fixed to 12.0 for both phases']}
    try:
        with tempfile.TemporaryDirectory(prefix='moth-scenery-', dir='/tmp/opencode') as folder:
            private = Path(folder)
            stage = private / 'godot'
            shutil.copytree(ROOT / 'godot', stage, ignore=shutil.ignore_patterns('.godot', 'content'))
            shutil.copytree(args.content, stage / 'content/generated')
            manifest = stage / 'content/generated/manifest.json'
            metadata['content_manifest_sha256'] = hashlib.sha256(manifest.read_bytes()).hexdigest()
            metadata['source_commit'] = json.loads(manifest.read_text())['source_commit']
            env = dict(os.environ, PORT='0', LIBGL_ALWAYS_SOFTWARE='1')
            for key in ['HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']:
                directory = private / key.lower()
                directory.mkdir(mode=0o700)
                env[key] = str(directory)
            env.pop('DISPLAY', None)
            base = [GODOT, '--path', str(stage), '--audio-driver', 'Dummy', '--quit-after', '1800']

            def run(name, command, timeout=240):
                start = time.monotonic()
                with (output / (name + '.log')).open('w') as log:
                    try:
                        process = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
                    except subprocess.TimeoutExpired:
                        results.append({'name': name, 'passed': False, 'timeout': timeout})
                        raise
                text = (output / (name + '.log')).read_text()
                passed = process.returncode == 0 and not any(marker in text for marker in ['SCRIPT ERROR', 'SHADER ERROR', 'ERROR:', 'Leaked instance', 'ObjectDB instances leaked'])
                if name.startswith('verify'): passed = passed and 'MOTH_SCENERY_VERIFY' in text
                if name.startswith('capture'): passed = passed and 'MOTH_SCENERY_GRAPHICAL_SMOKE' in text
                results.append({'name': name, 'returncode': process.returncode, 'passed': passed, 'seconds': round(time.monotonic() - start, 3)})
                print(name, 'PASS' if passed else 'FAIL', flush=True)
                if not passed: raise RuntimeError(text[-16000:])

            run('import', base + ['--headless', '--editor', '--import', '--quit'])
            # Source viewer smoke uses the untouched baseline shared code.
            run('verify-headless', base + ['--headless', '--script', 'res://tests/moth_scenery/verify.gd', '--', str(output / 'geometry.json')])
            if args.checks_only: return
            stage_materials(stage, output)
            read_fd, write_fd = os.pipe()
            with (output / 'xvfb.log').open('w') as log:
                display = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'], pass_fds=(write_fd,), stdout=log, stderr=subprocess.STDOUT, env=env)
            os.close(write_fd)
            try:
                if not select.select([read_fd], [], [], 10)[0]: raise RuntimeError('Private Xvfb timeout')
                number = os.read(read_fd, 32).decode().strip()
                if not number.isdigit(): raise RuntimeError('Invalid Xvfb display')
                env['DISPLAY'] = ':' + number
                for size in ['960x640', '1280x800']:
                    destination = output / size
                    destination.mkdir()
                    run('capture-' + size, base + ['--rendering-method', 'gl_compatibility', '--resolution', size, '--script', 'res://tests/moth_scenery/capture.gd', '--', str(destination)], 300)
                run('verify-graphical', base + ['--rendering-method', 'gl_compatibility', '--script', 'res://tests/moth_scenery/verify.gd', '--', str(output / 'geometry-graphical.json')])
            finally:
                os.close(read_fd)
                display.terminate()
                try: display.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    display.kill()
                    display.wait(timeout=10)
    finally:
        (output / 'summary.json').write_text(json.dumps(metadata, indent=2) + '\n')
        print('Evidence:', output, flush=True)


if __name__ == '__main__':
    main()
