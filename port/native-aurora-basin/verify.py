#!/usr/bin/env python3
"""Private native runner; no network/shared display, preserves every run's logs."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', choices=['all', 'import', 'validate', 'capture', 'smoke'], default='all')
    parser.add_argument('--views', default='landing,observatory,fracture,vista,overview')
    parser.add_argument('--sizes', default='960x640,1280x800')
    args = parser.parse_args()
    evidence = ROOT / 'port/native-aurora-basin/evidence' / datetime.datetime.now(datetime.timezone.utc).strftime('run-%Y%m%dT%H%M%S%fZ')
    evidence.mkdir(parents=True)
    runtime = Path(tempfile.mkdtemp(prefix='aurora-private-', dir='/tmp/opencode'))
    env = dict(os.environ)
    for key, folder in [('HOME', 'home'), ('XDG_CONFIG_HOME', 'config'), ('XDG_DATA_HOME', 'data'), ('XDG_CACHE_HOME', 'cache'), ('XDG_RUNTIME_DIR', 'runtime')]:
        path = runtime / folder
        path.mkdir(mode=0o700)
        env[key] = str(path)
    env['LIBGL_ALWAYS_SOFTWARE'] = '1'
    env['GODOT_SILENCE_ROOT_WARNING'] = '1'
    env.pop('DISPLAY', None)
    env.pop('WAYLAND_DISPLAY', None)
    base = [str(GODOT), '--path', str(ROOT / 'godot'), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy']
    results = []

    def run(name, command, timeout=180):
        start = time.monotonic()
        with (evidence / (name + '.log')).open('w') as log:
            try:
                process = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout, cwd=ROOT)
                code = process.returncode
            except subprocess.TimeoutExpired:
                code = 124
        content = (evidence / (name + '.log')).read_text()
        errors = [line for line in content.splitlines() if 'SCRIPT ERROR' in line or 'SHADER ERROR' in line or line.startswith('ERROR:')]
        result = dict(name=name, code=code, seconds=round(time.monotonic() - start, 3), errors=errors, command=command)
        results.append(result)
        print(json.dumps(result), flush=True)
        return code == 0 and not errors

    passed = True
    xvfb = None
    display_log = None
    try:
        if args.stage in ('all', 'import'):
            passed = run('import', base + ['--headless', '--editor', '--import', '--quit']) and passed
        if passed and args.stage != 'import':
            script = 'validate.gd' if args.stage == 'validate' else 'capture.gd'
            passed = run('preflight', base + ['--headless', '--check-only', '--script', 'res://tests/aurora_basin/' + script], timeout=15) and passed
        if passed and args.stage in ('all', 'validate'):
            passed = run('collision', base + ['--headless', '--script', 'res://tests/aurora_basin/validate.gd', '--', '--output=' + str(evidence / 'collision.json')]) and passed
        if passed and args.stage in ('all', 'capture', 'smoke'):
            read_fd, write_fd = os.pipe()
            display_log = (evidence / 'xvfb.log').open('w')
            xvfb = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'], pass_fds=(write_fd,), stdout=display_log, stderr=subprocess.STDOUT, env=env)
            os.close(write_fd)
            with os.fdopen(read_fd) as pipe:
                display = pipe.readline().strip()
            if not display:
                raise RuntimeError('Private Xvfb did not return a display')
            env['DISPLAY'] = ':' + display
            if args.stage in ('all', 'smoke'):
                passed = run('smoke', base + ['--resolution', '960x640', 'res://aurora_basin/demo.tscn', '--', '--smoke']) and passed
            if args.stage in ('all', 'capture'):
                for size in args.sizes.split(','):
                    for view in args.views.split(','):
                        name = view + '-' + size
                        passed = run(name, base + ['--resolution', size, '--script', 'res://tests/aurora_basin/capture.gd', '--', '--size=' + size, '--view=' + view, '--output=' + str(evidence / (name + '.png'))], timeout=60) and passed
                        if not passed:
                            break
                    if not passed:
                        break
    except BaseException:
        passed = False
        raise
    finally:
        if xvfb:
            xvfb.terminate()
            try:
                xvfb.wait(timeout=5)
            except subprocess.TimeoutExpired:
                xvfb.kill()
                xvfb.wait()
        if display_log:
            display_log.close()
        summary = dict(passed=passed, stage=args.stage, runtime=str(runtime), godot=str(GODOT), results=results)
        (evidence / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print('AURORA_EVIDENCE', evidence, flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
