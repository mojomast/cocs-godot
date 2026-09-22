#!/usr/bin/env python3
"""Private, small Godot project: never imports or writes other agents' assets."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT.parent / 'godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
parser = argparse.ArgumentParser()
parser.add_argument('--render', action='store_true')
args = parser.parse_args()
evidence = ROOT / 'port/native-source-operators/evidence'
evidence.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, OPERATOR_EVIDENCE=str(evidence))
with tempfile.TemporaryDirectory(prefix='source-operators-', dir='/tmp/opencode') as tmp:
    tmp = Path(tmp)
    # ~20MB owned source assets only, no repo copies or shared .godot cache.
    for path in ['source_operators', 'tests/source_operators']:
        shutil.copytree(ROOT / 'godot' / path, tmp / path)
    # Read-only host presentation dependencies for the integration test.
    (tmp / 'world').mkdir()
    for name in ['presentation.gd','remote_motion.gd','local_lifecycle.gd']:
        shutil.copy2(ROOT / 'godot/world' / name, tmp / 'world' / name)
    (tmp / 'project.godot').write_text('''config_version=5
[application]
config/name="Source Operators Proof"
config/features=PackedStringArray("4.5", "GL Compatibility")
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''')
    def run(command, log):
        result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=480)
        (evidence / log).write_text(result.stdout)
        print(result.stdout[-10000:])
        if result.returncode or 'SCRIPT ERROR' in result.stdout or 'ERROR:' in result.stdout:
            raise SystemExit(f'Failed: {log} ({result.returncode})')
    base = [str(GODOT), '--path', str(tmp)]
    run(base + ['--headless', '--editor', '--import'], 'import.log')
    # Prevent Godot generating additional, non-source LODs or lossy compression.
    for file in (tmp / 'source_operators/generated').rglob('*.glb.import'):
        data = file.read_text().replace('meshes/generate_lods=true','meshes/generate_lods=false').replace('meshes/force_disable_compression=false','meshes/force_disable_compression=true')
        file.write_text(data)
        shutil.copy2(file, ROOT / 'godot/source_operators/generated' / file.relative_to(tmp / 'source_operators/generated'))
    run(base + ['--headless', '--editor', '--import'], 'import-authored-lods.log')
    run(base + ['--headless', '--script', 'tests/source_operators/check.gd'], 'check.log')
    run(base + ['--headless', '--script', 'tests/source_operators/weapons.gd'], 'weapons.log')
    run(base + ['--headless', '--script', 'tests/source_operators/grips.gd'], 'grips.log')
    run(base + ['--headless', '--script', 'tests/source_operators/presentation.gd'], 'presentation.log')
    if args.render:
        run(['xvfb-run', '-a'] + base + ['--audio-driver','Dummy','--rendering-method','gl_compatibility','--script','tests/source_operators/render.gd'], 'render.log')
