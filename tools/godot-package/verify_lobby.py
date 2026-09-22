"""Verify the exported popup-free lobby through real product-scene engine events.

The external observer is not part of the production PCK. Uses the reviewed
inline-selector flow; historical OptionButton observers remain in their reports.
This is engine-event acceptance, not OS-input or launcher ownership evidence.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-result', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--targeted', action='store_true', help='Selector/focus checks only; default is full two-client lifecycle')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise RuntimeError('Preserve prior evidence; choose a new output directory')
    build_path = args.build_result.resolve()
    build = json.loads(build_path.read_text())
    package = Path(build['package'])
    manifest = json.loads((package / 'manifest.json').read_text())
    if sha(package / 'manifest.json') != build['manifest_sha256']:
        raise RuntimeError('Manifest integrity mismatch')
    for name in ['godot/ui/lobby_choice.gd', 'godot/ui/lobby_menu.gd', 'godot/net/client.gd', 'godot/world/session.gd']:
        if manifest['inputs'].get(name) != sha(ROOT / name):
            raise RuntimeError('Artifact differs from reviewed integrated runtime: ' + name)
    flow = ROOT / 'port/reports/lobby-popup-free/lobby_live.mjs'
    observer = flow.with_name('lobby_export_observer.gd')
    output.parent.mkdir(parents=True, exist_ok=True)
    command = ['node', str(flow), 'targeted' if args.targeted else 'full', str(build_path), str(output)]
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
    timed_out = False
    try:
        stdout, stderr = process.communicate(timeout=150)
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(process.pid, signal.SIGTERM)
        try:
            stdout, stderr = process.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            stdout, stderr = process.communicate()
    output.mkdir(exist_ok=True)
    (output / 'wrapper.log').write_text(stdout + stderr)
    provenance = {'kind':'exported product scene; external engine-event observer', 'build':build,
                  'flow_sha256':sha(flow), 'observer_sha256':sha(observer), 'wrapper_sha256':sha(Path(__file__)),
                  'wrapper_exit':process.returncode, 'timed_out':timed_out, 'command':command,
                  'source':'unchanged packaged authority', 'limits':'Not OS-input or packaged-launcher automation; no tests added to production PCK.'}
    (output / 'package-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    if timed_out or process.returncode:
        raise RuntimeError('Exported lobby observer failed; see preserved output')
    summary = json.loads((output / 'summary.json').read_text())
    if summary['status'] != 'PASS' or not summary['cleanLogs'] or summary['nativeErrorLines']:
        raise RuntimeError('Exported lobby acceptance failed; see preserved output')
    print('EXPORTED_LOBBY_PASS', output)


if __name__ == '__main__':
    main()
