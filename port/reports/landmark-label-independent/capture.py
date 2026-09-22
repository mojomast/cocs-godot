"""Controlled offline landmark captures using an owned private display."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(root / 'port/tools/meridian_visual_review'))
from owned_process import private_environment, run_owned

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('variant', choices=['before', 'after', 'after-revised'])
args = parser.parse_args()
destination = Path(__file__).parent / args.variant
destination.mkdir(exist_ok=False)
results = []
with tempfile.TemporaryDirectory(prefix='landmark-label-', dir='/tmp/opencode') as temporary:
    env = private_environment(temporary)
    for size in ['960x640', '1280x800']:
        out = destination / size
        out.mkdir()
        command = ['xvfb-run', '-a', '-s', '-screen 0 1400x1000x24 -nolisten tcp -nolisten unix',
                   os.environ['GODOT_BIN'], '--path', str(root / 'godot'), '--rendering-method',
                   'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', size,
                   '--script', str(Path(__file__).with_suffix('.gd')), '--', f'--label-out={out}']
        result = run_owned(command, env=env, cwd=root, timeout=45)
        (out / 'stdout.log').write_text(result.pop('stdout'))
        (out / 'stderr.log').write_text(result.pop('stderr'))
        results.append(result)
        assert result['returncode'] == 0 and result['cleanup_complete'], result
        assert 'ERROR:' not in (out / 'stderr.log').read_text()
        assert all((out / name).exists() for name in ['near.png', 'far.png'])
        print(args.variant, size, 'PASS')
report = dict(scope='offline authored-label presentation; no gameplay authority',
              styleSHA256=hashlib.sha256((root / 'godot/world/environment_style.gd').read_bytes()).hexdigest(),
              results=results)
(destination / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
