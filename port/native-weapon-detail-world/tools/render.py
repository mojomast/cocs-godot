#!/usr/bin/env python3
"""Private rendered review of the exported world weapons.

Stages only `godot/source_operators` and `godot/tests/source_operators` into a
private temporary project, imports it with the pinned Godot binary, and runs
`weapon_detail_render.gd` under a private Xvfb display with a private HOME and
temp, writing captures into the lane's evidence directory.
"""
import argparse
import os
import select
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GODOT = Path(os.environ.get('GODOT_BIN', ROOT.parent / 'godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'))


def stop(process):
    if process is None:
        return None
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    return process.returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'port/native-weapon-detail-world/evidence')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    display = None
    with tempfile.TemporaryDirectory(prefix='world-weapon-detail-', dir='/tmp/opencode') as temporary:
        stage = Path(temporary)
        project = stage / 'godot'
        for path in ['source_operators', 'tests/source_operators']:
            shutil.copytree(ROOT / 'godot' / path, project / path)
        (project / 'project.godot').write_text('''config_version=5
[application]
config/name="World Weapon Detail Review"
config/features=PackedStringArray("4.5", "GL Compatibility")
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''')
        env = {**os.environ, 'HOME': str(stage), 'LIBGL_ALWAYS_SOFTWARE': '1', 'LP_NUM_THREADS': '2', 'OPERATOR_EVIDENCE': str(output)}
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']:
            path = stage / key
            path.mkdir(mode=0o700)
            env[key] = str(path)
        with (output / 'render-import.log').open('w') as import_log, (output / 'render.log').open('w') as render_log, (output / 'xvfb.log').open('w') as display_log:
            imported = subprocess.run([str(GODOT), '--headless', '--path', str(project), '--editor', '--import'], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900)
            import_log.write(imported.stdout)
            if imported.returncode or 'SCRIPT ERROR' in imported.stdout:
                raise SystemExit('Private project import failed; see render-import.log')
            read_fd, write_fd = os.pipe()
            try:
                display = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'], env=env, pass_fds=[write_fd], stdout=display_log, stderr=subprocess.STDOUT)
                os.close(write_fd)
                if not select.select([read_fd], [], [], 10)[0]:
                    raise SystemExit('Display readiness failed')
                env['DISPLAY'] = ':' + os.read(read_fd, 64).decode().strip()
            finally:
                os.close(read_fd)
            render = subprocess.run([str(GODOT), '--path', str(project), '--script', 'res://tests/source_operators/weapon_detail_render.gd',
                                     '--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
                                     '--resolution', '1280x800', '--position', '0,0'], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=1800)
            render_log.write(render.stdout)
            stop(display)
            print(render.stdout[-4000:])
            if render.returncode or 'SCRIPT ERROR' in render.stdout or 'ERROR:' in render.stdout:
                raise SystemExit(f'Render failed ({render.returncode}); see render.log')
    print('captures written to', output)


if __name__ == '__main__':
    main()
