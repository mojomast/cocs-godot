"""Exercise the actual exported session with an external engine-event observer.

The production PCK remains untouched and contains no tests. Uses the reviewed
two-client flow, changing only artifact paths and evidence destination. These are
engine events, not OS input; package launcher ownership is verified separately.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-result', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--startup', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise RuntimeError('Preserve prior evidence; choose a new output directory')
    build = json.loads(args.build_result.read_text())
    package = Path(build['package'])
    manifest = json.loads((package / 'manifest.json').read_text())
    if sha(package / 'manifest.json') != build['manifest_sha256']:
        raise RuntimeError('Manifest integrity mismatch')
    for name, digest in manifest['files'].items():
        if sha(package / name) != digest:
            raise RuntimeError('Package byte mismatch: ' + name)
    flow = ROOT / 'port/reports/lobby-followup/lobby_live.mjs'
    observer = ROOT / 'godot/tests/protocol/lobby_followup_observer.gd'
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='exported-lobby-observer-', dir='/tmp/opencode') as temporary:
        temp = Path(temporary)
        shutil.copy2(observer, temp / 'observer.gd')
        text = flow.read_text()
        def replace(old, new):
            nonlocal text
            if text.count(old) != 1:
                raise RuntimeError('Reviewed flow changed: ' + old)
            text = text.replace(old, new)
        replace("'../../../server/game-server.mjs'", json.dumps((package / 'runtime/server/game-server.mjs').as_uri()))
        replace("'../../../tools/godot-export/semantic.mjs'", json.dumps((ROOT / 'tools/godot-export/semantic.mjs').as_uri()))
        replace("'../../tools/native_trace_correlation/guest_helpers.mjs'", json.dumps((ROOT / 'port/tools/native_trace_correlation/guest_helpers.mjs').as_uri()))
        replace("const binary='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';", 'const binary=' + json.dumps(str(package / 'cocs.x86_64')) + ';')
        replace("const out=resolve('port/reports/lobby-followup',startup?'ember-startup':'meridian-tdm');", 'const out=' + json.dumps(str(output)) + ';')
        replace("['--path','godot','--audio-driver'", "['--main-pack'," + json.dumps(str(package / 'cocs.pck')) + ",'--audio-driver'")
        replace("'res://tests/protocol/lobby_followup_observer.gd'", json.dumps(str(temp / 'observer.gd')))
        (temp / 'flow.mjs').write_text(text)
        process = subprocess.Popen(['node', str(temp / 'flow.mjs'), *(['--ember-startup'] if args.startup else [])], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        try:
            stdout, stderr = process.communicate(timeout=205)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                stdout, stderr = process.communicate(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                stdout, stderr = process.communicate()
            output.mkdir(exist_ok=True)
            (output / 'wrapper-timeout.log').write_text(stdout + stderr)
            raise RuntimeError('Exported observer timed out; owned process group terminated')
        output.mkdir(exist_ok=True)
        (output / 'wrapper.log').write_text(stdout + stderr)
        (output / 'external-observer.gd.txt').write_text(observer.read_text())
        summary = json.loads((output / 'summary.json').read_text())
        for name, digest in manifest['files'].items():
            if sha(package / name) != digest:
                raise RuntimeError('Play changed packaged file: ' + name)
        provenance = {'kind':'exported product scene; external engine-event observer', 'build':build,
                      'flow_sha256':sha(flow), 'observer_sha256':sha(observer),
                      'adapted_flow_sha256':sha(temp / 'flow.mjs'), 'wrapper_exit':process.returncode,
                      'source':'unchanged packaged authority', 'package_bytes_unchanged':True,
                      'command':['node', str(temp / 'flow.mjs'), *(['--ember-startup'] if args.startup else [])],
                      'limits':'Not an OS-input or packaged-launcher UI automation run; no test code added to production PCK.'}
        (output / 'package-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        (output / 'adapted-flow.mjs.txt').write_text(text)
        if process.returncode or not summary['status'].startswith('PASS'):
            raise RuntimeError('Exported lobby acceptance failed; see preserved output')
    print('EXPORTED_LOBBY_PASS', output)


if __name__ == '__main__':
    main()
