#!/usr/bin/env python3
"""Focused private graphical polish checks. No source/server/timing modifications."""
import json
import os
import pathlib
import selectors
import shutil
import subprocess
import tempfile
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[3]
BIN = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
DEPS = '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules'
OUT = ROOT / 'port/native-sports-polish/evidence' / str(uuid.uuid4())
OUT.mkdir(parents=True)
children = []
report = {'classification': 'focused real normal-rate demo; native key events only; synthetic unit checks separately labeled', 'cases': []}


def stop(child):
    if child.poll() is None:
        child.terminate()
        try:
            child.wait(5)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(5)
    try:
        os.kill(child.pid, 0)
    except ProcessLookupError:
        return
    raise AssertionError('Owned process still exists')


def run(args, path, env, timeout=60):
    with path.open('w') as log:
        child = subprocess.Popen(args, env=env, stdout=log, stderr=subprocess.STDOUT)
        children.append(child)
        try:
            code = child.wait(timeout)
        finally:
            stop(child)
    text = path.read_text()
    assert code == 0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text, str(path)
    return text


try:
    assert subprocess.check_output([BIN, '--version'], text=True).strip() == '4.5.2.stable.official.6ce3de25a'
    with tempfile.TemporaryDirectory(prefix='sports-polish-', dir='/tmp/opencode') as tmp:
        temp = pathlib.Path(tmp)
        env = {**os.environ, 'HOME': tmp}
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            env[key] = str(temp / key)
            (temp / key).mkdir()
        for name in ['godot', 'game', 'server']:
            shutil.copytree(ROOT / name, temp / name, ignore=shutil.ignore_patterns('.godot', 'node_modules', '__pycache__'))
        (temp / 'node_modules').symlink_to(DEPS, target_is_directory=True)
        run(['node', str(ROOT / 'tools/godot-export/semantic.mjs'), str(temp / 'godot/content/generated')], OUT / 'export.log', env)
        base = [BIN, '--headless', '--path', str(temp / 'godot')]
        run(base + ['--editor', '--import'], OUT / 'import.log', env)
        for script in ['sports/test_controls', 'vehicles/test_puma', 'sports/test_polish']:
            run(base + ['--script', 'res://tests/' + script + '.gd'], OUT / (script.split('/')[-1] + '.log'), env)
        readfd, writefd = os.pipe()
        with (OUT / 'xvfb.log').open('w') as xlog:
            xvfb = subprocess.Popen(['Xvfb', '-displayfd', str(writefd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'], pass_fds=(writefd,), stdout=xlog, stderr=xlog)
            children.append(xvfb)
            os.close(writefd)
            with selectors.DefaultSelector() as sel:
                sel.register(readfd, selectors.EVENT_READ)
                assert sel.select(10), 'Xvfb startup timeout'
                display = os.read(readfd, 100).decode().strip()
            os.close(readfd)
            assert display.isdigit() and xvfb.poll() is None, 'Invalid Xvfb display'
            env['DISPLAY'] = ':' + display
            for map_id in ['ion-speedway', 'aurora-stadium']:
                for resolution in ['960x640', '1280x800']:
                    case = OUT / (map_id + '-' + resolution)
                    case.mkdir()
                    with (case / 'server.log').open('w') as log:
                        server = subprocess.Popen(['node', str(ROOT / 'port/tools/native_vehicle_demo/server.mjs'), tmp, str(case / 'wire.json')], stdout=subprocess.PIPE, stderr=log, text=True, env=env)
                        children.append(server)
                        try:
                            with selectors.DefaultSelector() as sel:
                                sel.register(server.stdout, selectors.EVENT_READ)
                                assert sel.select(10), 'server startup timeout'
                                line = server.stdout.readline().strip()
                            assert line.startswith('ENDPOINT ws://127.0.0.1:'), line
                            endpoint = line.split(' ', 1)[1]
                            text = run([BIN, '--path', str(temp / 'godot'), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', resolution, '--script', 'res://tests/sports/observe_polish.gd', '--', '--map=' + map_id, '--endpoint=' + endpoint, '--polish-out=' + str(case)], case / 'native.log', env, 35)
                        finally:
                            stop(server)
                    assert 'POLISH_LIVE_ENDED ' in text
                    wire = json.loads((case / 'wire.json').read_text())
                    assert wire['cleanup'] == {'serverClosed': True, 'sockets': 0}
                    captures = [json.loads(line.split(' ', 1)[1]) for line in text.splitlines() if line.startswith('POLISH_LIVE_CAPTURE ')]
                    assert {'countdown', 'driving', 'released', 'near-wall'} <= {c['label'] for c in captures}
                    report['cases'].append({'map': map_id, 'resolution': resolution, 'captures': [c['label'] for c in captures], 'receivedInputs': len(wire['inputs']), 'maxCameraCandidates': max(c['candidates'] for c in captures), 'cleanup': wire['cleanup']})
            assert any('near-wall' in case['captures'] for case in report['cases']), 'No actual obstructed camera capture'
            stop(xvfb)
    report['privateTempRemoved'] = not temp.exists()
    report['status'] = 'PASS'
except Exception as exc:
    report['status'] = 'FAIL'
    report['error'] = str(exc)
    raise
finally:
    for child in reversed(children):
        stop(child)
    report['ownedProcessesReaped'] = True
    (OUT / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'evidence': str(OUT), **report}, indent=2))
