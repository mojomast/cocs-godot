#!/usr/bin/env python3
"""Isolated material-language verification. Retains every run's logs and images.

Steps: offline derivation tests, Godot import, the moth/package-adjacent contract
tests kept green by this lane, the material-language contract test, the viewer
smoke, and private-Xvfb captures (sheet at both audited resolutions, single
family close/wide, grazing floors, viewer screenshot).

    python3 tools/godot-moth/verify_material_language.py
    python3 tools/godot-moth/verify_material_language.py --skip-import
"""
import argparse
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
EVIDENCE = ROOT / 'port/native-material-language/evidence'
PRIVATE_ROOT = Path('/tmp/opencode')

# Every step: (name, argv tail, needs display). Fail markers mirror the other
# lanes' runners: a script/shader error or an ERROR: line is a failure.
STEPS = [
    ('parse-check', ['--headless', '--path', 'godot', '--script', 'res://tests/material_language/parse_check.gd'], False),
    ('derived-tests', ['node', '--test', 'tools/godot-moth/derive.test.mjs'], False),
    ('coverage-scan', ['node', 'tools/godot-moth/coverage.mjs', '--json=port/native-material-language/coverage-after.json'], False),
    ('moth-contract', ['--headless', '--path', 'godot', '--script', 'res://tests/moth/validate.gd'], False),
    ('material-language-contract', ['--headless', '--path', 'godot', '--script', 'res://tests/material_language/validate.gd'], False),
    ('shader-lab-contract', ['--headless', '--path', 'godot', '--script', 'res://tests/shader_lab/validate.gd'], False),
    ('moth-scenery-verify', ['--headless', '--path', 'godot', '--script', 'res://tests/moth_scenery/verify.gd'], False),
    ('graphics-fx-regression', ['--headless', '--path', 'godot', '--script', 'res://tests/graphics_fx/regression.gd'], False),
    ('viewer-smoke', ['--headless', '--path', 'godot', 'res://material_language/gallery.tscn', '--', '--smoke'], False),
]

CAPTURES = [
    # 960x640 skips the A/B pass: software rasterisation is the budget here, and
    # 1280x800 renders the same scene with the measured deltas.
    ('sheet-960x640', ['--resolution', '960x640'], ['--mode=sheet', '--size=960x640', '--ab=off']),
    # The A/B measurement lives on the single-viewport family panels: identical
    # materials, one camera, and a fraction of the software-render cost.
    ('sheet-1280x800', ['--resolution', '1280x800'], ['--mode=sheet', '--size=1280x800', '--ab=off']),
    ('distance-1280x800', ['--resolution', '1280x800'], ['--mode=distance', '--size=1280x800']),
    ('family-bioluminescent-membrane-1280x800', ['--resolution', '1280x800'], ['--mode=family', '--family=bioluminescent-membrane', '--size=1280x800']),
    ('family-hazard-industrial-1280x800', ['--resolution', '1280x800'], ['--mode=family', '--family=hazard-industrial', '--size=1280x800']),
    ('family-brushed-alloy-1280x800', ['--resolution', '1280x800'], ['--mode=family', '--family=brushed-alloy', '--size=1280x800']),
    ('family-pearl-ceramic-1280x800', ['--resolution', '1280x800'], ['--mode=family', '--family=pearl-ceramic', '--size=1280x800']),
    ('family-regolith-1280x800', ['--resolution', '1280x800'], ['--mode=family', '--family=regolith', '--size=1280x800']),
]


def private_env(root: Path) -> dict:
    env = os.environ.copy()
    for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR', 'HOME']:
        folder = root / key.lower()
        folder.mkdir(mode=0o700, exist_ok=True)
        env[key] = str(folder)
    env.update(LIBGL_ALWAYS_SOFTWARE='1', PORT='0')
    env.pop('DISPLAY', None)
    return env


def run(command, env, output: Path, name: str, timeout: int = 600):
    # Own process group: a timeout kills the whole Godot tree, never leaving an
    # orphan renderer behind to compete with the next step.
    process = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=timeout, start_new_session=True)
    text = process.stdout.decode(errors='replace')
    (output / f'{name}.log').write_text(text)
    markers = ['SCRIPT ERROR:', 'SHADER ERROR:', 'ERROR:']
    passed = process.returncode == 0 and not any(marker in text for marker in markers)
    print(f'{name} {"PASS" if passed else "FAIL"}', flush=True)
    return passed, text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=DEFAULT_GODOT)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--skip-import', action='store_true')
    args = parser.parse_args()
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    output = args.output or Path(tempfile.mkdtemp(prefix='run-', dir=EVIDENCE))
    output.mkdir(parents=True, exist_ok=True)
    if (output / 'summary.json').exists():
        raise RuntimeError('Refusing to overwrite prior verification evidence')
    private = Path(tempfile.mkdtemp(prefix='material-language-', dir=PRIVATE_ROOT))
    env = private_env(private)
    results = []

    def record(name, passed, detail=''):
        results.append({'name': name, 'passed': passed, 'detail': detail[:4000]})
        if not passed:
            raise RuntimeError(f'{name} failed; see {output / (name + ".log")}')

    def reap() -> None:
        # Any Godot left alive from a timed-out step would fight the next capture.
        for entry in Path('/proc').glob('[0-9]*/cmdline'):
            try:
                command_line = entry.read_bytes().decode(errors='replace')
            except OSError:
                continue
            if 'godot-toolchain' in command_line and 'material_language' in command_line:
                try:
                    os.kill(int(entry.parent.name), signal.SIGKILL)
                except OSError:
                    pass

    try:
        for name, tail, _ in STEPS:
            command = ([args.godot] if tail[0].startswith('--') or tail[0] == args.godot else []) + tail
            if tail[0] == 'node':
                command = tail
            passed, text = run(command, env, output, name)
            record(name, passed, text[-2000:])
        if not args.skip_import:
            passed, text = run([args.godot, '--headless', '--path', str(ROOT / 'godot'), '--editor', '--import'], env, output, 'godot-import', timeout=900)
            record('godot-import', passed, text[-2000:])

        xvfb = None
        read_fd, write_fd = os.pipe()
        with (output / 'xvfb.log').open('wb') as log:
            xvfb = subprocess.Popen(
                ['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1600x1000x24', '-nolisten', 'tcp', '-nolisten', 'unix'],
                pass_fds=(write_fd,), stdout=log, stderr=subprocess.STDOUT, env=env,
            )
        os.close(write_fd)
        if not select.select([read_fd], [], [], 15)[0]:
            raise RuntimeError('Private Xvfb display allocation timed out')
        display = os.read(read_fd, 32).decode().strip()
        os.close(read_fd)
        if not display.isdigit():
            raise RuntimeError(f'Invalid private display: {display!r}')
        env['DISPLAY'] = ':' + display

        for name, resolution, user_args in CAPTURES:
            reap()
            image = output / f'{name}.png'
            command = [args.godot, '--path', str(ROOT / 'godot'), *resolution, '--audio-driver', 'Dummy',
                       '--rendering-method', 'gl_compatibility', '--script', 'res://tests/material_language/gallery_capture.gd',
                       '--', *user_args, f'--output={image}']
            passed, text = run(command, env, output, name)
            record(name, passed and image.exists(), text[-2000:])
        for resolution, name in [('960x640', 'viewer-960x640'), ('1280x800', 'viewer-1280x800')]:
            viewer = output / f'{name}.png'
            passed, text = run([args.godot, '--path', str(ROOT / 'godot'), '--resolution', resolution, '--audio-driver', 'Dummy',
                                '--rendering-method', 'gl_compatibility', 'res://material_language/gallery.tscn', '--',
                                f'--capture={viewer}'], env, output, name)
            record(name, passed and viewer.exists(), text[-2000:])
    finally:
        if xvfb is not None:
            xvfb.terminate()
            xvfb.wait(timeout=10)
        summary = {
            'results': results,
            'renderer': 'Godot 4.5.2 GL Compatibility / software Mesa llvmpipe / private Xvfb 1600x1000',
            'private_state': str(private),
            'images': sorted(path.name for path in output.glob('*.png')),
        }
        (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print('Evidence:', output)
        print('All steps passed' if all(entry['passed'] for entry in results) else 'FAILURES PRESENT')


if __name__ == '__main__':
    main()
