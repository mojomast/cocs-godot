#!/usr/bin/env python3
"""Isolated native verification. Retains every run's logs/images, including failures."""
import argparse
import json
import os
from pathlib import Path
import select
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=DEFAULT_GODOT)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    evidence = ROOT / 'port/native-moth-graphics/evidence'
    evidence.mkdir(parents=True, exist_ok=True)
    output = args.output or Path(tempfile.mkdtemp(prefix='run-', dir=evidence))
    output.mkdir(parents=True, exist_ok=True)
    if (output / 'summary.json').exists():
        raise RuntimeError('Refusing to overwrite prior verification evidence')
    private = Path(tempfile.mkdtemp(prefix='moth-native-', dir='/tmp/opencode'))
    env = os.environ.copy()
    for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR', 'HOME']:
        folder = private / key.lower()
        folder.mkdir(mode=0o700)
        env[key] = str(folder)
    env.update(PORT='0', LIBGL_ALWAYS_SOFTWARE='1')
    results = []

    def run(name, command):
        process = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        text = process.stdout.decode(errors='replace')
        (output / (name + '.log')).write_text(text)
        passed = process.returncode == 0 and not any(marker in text for marker in ['SCRIPT ERROR:', 'SHADER ERROR:', 'ERROR:'])
        results.append(dict(name=name, returncode=process.returncode, passed=passed))
        print(name, 'PASS' if passed else 'FAIL', flush=True)
        if not passed:
            raise RuntimeError(text[-12000:])

    xvfb = None
    try:
        run('offline-export', ['node', '--test', 'tools/godot-moth/export.test.mjs'])
        run('import', [args.godot, '--headless', '--path', str(ROOT / 'godot'), '--editor', '--import'])
        run('runtime', [args.godot, '--headless', '--path', str(ROOT / 'godot'), '--script', 'res://tests/moth/validate.gd'])
        readfd, writefd = os.pipe()
        with (output / 'xvfb.log').open('wb') as log:
            xvfb = subprocess.Popen(['Xvfb', '-displayfd', str(writefd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'], pass_fds=(writefd,), stdout=log, stderr=subprocess.STDOUT, env=env)
        os.close(writefd)
        if not select.select([readfd], [], [], 10)[0]:
            raise RuntimeError('Private Xvfb display allocation timed out')
        display = os.read(readfd, 32).decode().strip()
        os.close(readfd)
        if not display.isdigit():
            raise RuntimeError('Invalid private display')
        env['DISPLAY'] = ':' + display
        for mode, size in [('materials', '960x640'), ('materials', '1280x800'), ('textures', '1280x800'), ('extras', '1280x800')]:
            name = mode + '-' + size
            run(name, [args.godot, '--path', str(ROOT / 'godot'), '--resolution', size, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--script', 'res://tests/moth/gallery.gd', '--', '--mode=' + mode, '--size=' + size, '--output=' + str(output / (name + '.png'))])
    finally:
        if xvfb is not None:
            xvfb.terminate()
            xvfb.wait(timeout=10)
        (output / 'summary.json').write_text(json.dumps({'results': results, 'renderer': 'Godot 4.5.2 GL Compatibility / software Mesa / private Xvfb', 'private_state': str(private)}, indent=2) + '\n')
        print('Evidence:', output)


if __name__ == '__main__':
    main()
