#!/usr/bin/env python3
"""Read-only artifact/baseline audit. Writes only this lane's provenance.json."""
import hashlib
import json
import platform
import shutil
import subprocess
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
PACKAGE = Path('/tmp/opencode/usability-package-83e4aff')
BASELINE = '83e4aff175eeef47c9ceab5714bad162ce9b32a6'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

manifest = json.loads((PACKAGE / 'manifest.json').read_text())
package_mismatches = {name: sha(PACKAGE / name) for name, expected in manifest['files'].items() if sha(PACKAGE / name) != expected}
inputs_checked, input_mismatches, inputs_missing = [], {}, []
for name, expected in manifest['inputs'].items():
    path = ROOT / name
    if not path.is_file():
        inputs_missing.append(name)
    else:
        inputs_checked.append(name)
        if sha(path) != expected:
            input_mismatches[name] = {'package_input': expected, 'checkout': sha(path)}
flows = {}
for name in ['combat', 'race', 'soccer', 'payload', 'board', 'world']:
    directory = OUT / name
    session = json.loads((directory / 'session.json').read_text())
    cleanup = json.loads((directory / 'cleanup.json').read_text())
    flows[name] = dict(session=session, cleanup=cleanup, duration_seconds=round(cleanup['ended']-session['started'], 2), screenshots={p.name: sha(p) for p in sorted(directory.glob('*.png'))})
result = {
    'baseline': BASELINE, 'checkout_head': git('rev-parse', 'HEAD'),
    'baseline_runtime_trees': {name: git('rev-parse', f'{BASELINE}:{name}') for name in ['godot', 'game', 'server']},
    'package_build_commit': manifest['port_commit'],
    'package_manifest_metadata': {k:v for k,v in manifest.items() if k not in ['files', 'inputs', 'generated_resources', 'server_closure']},
    'package': str(PACKAGE), 'package_manifest_sha256': sha(PACKAGE/'manifest.json'),
    'runtime_hashes': {name: sha(PACKAGE/name) for name in ['cocs.pck', 'cocs.x86_64', 'run.mjs', 'options.mjs']},
    'package_files_checked': len(manifest['files']), 'package_file_mismatches': package_mismatches,
    'build_inputs_checked_against_checkout': len(inputs_checked), 'build_input_mismatches': input_mismatches, 'build_inputs_missing_in_checkout': inputs_missing,
    'changes_since_packaged_revision': git('diff', '--stat', '8a58c97', BASELINE, '--', 'godot', 'game', 'server', 'tools/godot-package', 'tools/godot-dev'),
    'environment': {'uname': platform.uname()._asdict(), 'python': platform.python_version(), 'node': subprocess.check_output(['node', '--version'], text=True).strip(), 'node_path': shutil.which('node'), 'Xvfb_path': shutil.which('Xvfb'), 'display_screen': '1600x1000x24', 'display_flags': ['-nolisten', 'tcp', '-nolisten', 'unix'], 'audio': 'ALSA unavailable; runtime falls back to dummy', 'input': 'ordinary XTest/XSetInputFocus, no state/physics/time mutation', 'x11_helper_sha256': sha(ROOT/'port/tools/graphical_acceptance/x11.py')},
    'flows': flows,
}
(OUT/'provenance.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({'package_mismatches':package_mismatches, 'input_mismatches':input_mismatches, 'inputs_missing':inputs_missing, 'flows':len(flows), 'screenshots':sum(len(f['screenshots']) for f in flows.values()), 'total_graphical_seconds':sum(f['duration_seconds'] for f in flows.values())}, indent=2))
