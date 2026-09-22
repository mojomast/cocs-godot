#!/usr/bin/env python3
"""Exercise only the Puma components in a private disposable Godot project."""
import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
DEFAULT_ENGINE = ROOT.parent / 'godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', str(DEFAULT_ENGINE)))
    parser.add_argument('--capture', type=Path)
    args = parser.parse_args()
    version = subprocess.run([args.godot, '--version'], capture_output=True, text=True, timeout=10, check=True).stdout.strip()
    if version != '4.5.2.stable.official.6ce3de25a':
        raise SystemExit(f'Wrong engine: {version}')
    with tempfile.TemporaryDirectory(prefix='cocs-puma-') as directory:
        base = Path(directory)
        shutil.copytree(ROOT / 'godot/vehicles', base / 'vehicles')
        shutil.copytree(ROOT / 'godot/tests/vehicles', base / 'tests/vehicles')
        (base / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Puma isolated verification"\n[display]\nwindow/size/viewport_width=1100\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = os.environ.copy()
        for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
            env[key] = str(base / key)
            Path(env[key]).mkdir()
        def run(command):
            proc = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
            try:
                stdout, stderr = proc.communicate(timeout=60)
            finally:
                # Only this freshly owned session, including xvfb-run descendants.
                try:
                    os.killpg(proc.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait()
            print(stdout, end='')
            print(stderr, end='')
            if proc.returncode or 'ERROR:' in stderr:
                raise SystemExit(proc.returncode or 1)
        command = [args.godot, '--path', str(base)]
        run(command + ['--headless', '--editor', '--import', '--quit'])
        run(command + ['--headless', '--script', 'res://tests/vehicles/test_puma.gd'])
        if args.capture:
            destination = args.capture.resolve()
            destination.parent.mkdir(parents=True, exist_ok=True)
            run(['xvfb-run', '-a'] + command + ['--audio-driver', 'Dummy', 'res://vehicles/demo.tscn', '--', f'--capture={destination}'])
    print('Private project removed; owned bounded Godot/Xvfb commands returned.')


if __name__ == '__main__':
    main()
