#!/usr/bin/env python3
"""Isolated, bounded real-time native progression checks; ordinary host config."""
import argparse
import hashlib
import json
import os
import pathlib
import selectors
import shutil
import subprocess
import tempfile
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
BIN = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
DEPS = '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules'
parser = argparse.ArgumentParser()
parser.add_argument('--unit-only', action='store_true')
parser.add_argument('--goal-attempt', action='store_true', help='Separate bounded native Aurora goal attempt; does not replace lifecycle matrix')
parser.add_argument('--map', choices=['ion-speedway', 'aurora-stadium'])
parser.add_argument('--resolution', choices=['960x640', '1280x800'])
args = parser.parse_args()
if args.goal_attempt:
    args.map = 'aurora-stadium'
    args.resolution = '1280x800'
OUT = ROOT / 'port/native-sports-progression/evidence' / str(uuid.uuid4())
OUT.mkdir(parents=True)
children = []
report = {'base': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
          'classification': 'real normal-rate owned server; native physical key events only; synthetic unit checks separately labeled',
          'commands': [], 'cases': []}
manifest = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for folder, suffix in [('game', '*.mjs'), ('server', '*.mjs'), ('godot', '*.gd'), ('port/native-sports-progression', '*.py'), ('port/native-sports-progression', '*.mjs')]
            for p in sorted((ROOT / folder).rglob(suffix))}
manifest['pinnedGodot'] = hashlib.sha256(pathlib.Path(BIN).read_bytes()).hexdigest()
for relative in ['tools/godot-export/semantic.mjs', 'godot/project.godot', 'godot/sports/demo.tscn']:
    manifest[relative] = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
(OUT / 'hashes.json').write_text(json.dumps(manifest, indent=2) + '\n')
report['hashManifestSHA256'] = hashlib.sha256((OUT / 'hashes.json').read_bytes()).hexdigest()


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


def run(command, path, env, timeout=60):
    report['commands'].append(command)
    with path.open('w') as log:
        child = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
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
    with tempfile.TemporaryDirectory(prefix='sports-progression-', dir='/tmp/opencode') as tmp:
        temp = pathlib.Path(tmp)
        env = {**os.environ, 'HOME': tmp, 'GODOT_SILENCE_ROOT_WARNING': '1'}
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            env[key] = str(temp / key)
            (temp / key).mkdir()
        for name in ['godot', 'game', 'server']:
            shutil.copytree(ROOT / name, temp / name, ignore=shutil.ignore_patterns('.godot', 'node_modules', '__pycache__'))
        (temp / 'node_modules').symlink_to(DEPS, target_is_directory=True)
        run(['node', str(ROOT / 'tools/godot-export/semantic.mjs'), str(temp / 'godot/content/generated')], OUT / 'export.log', env)
        generated = {str(p.relative_to(temp / 'godot')): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in sorted((temp / 'godot/content/generated').rglob('*')) if p.is_file()}
        (OUT / 'generated-hashes.json').write_text(json.dumps(generated, indent=2) + '\n')
        base = [BIN, '--headless', '--path', str(temp / 'godot')]
        run(base + ['--editor', '--import'], OUT / 'import.log', env)
        for script in ['sports/test_controls', 'vehicles/test_puma', 'sports/test_polish', 'sports/progression_test']:
            run(base + ['--script', 'res://tests/' + script + '.gd'], OUT / (script.split('/')[-1] + '.log'), env)
        if not args.unit_only:
            readfd, writefd = os.pipe()
            with (OUT / 'xvfb.log').open('w') as xlog:
                command = ['Xvfb', '-displayfd', str(writefd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix']
                report['commands'].append(command)
                xvfb = subprocess.Popen(command, pass_fds=(writefd,), stdout=xlog, stderr=xlog)
                children.append(xvfb)
                os.close(writefd)
                with selectors.DefaultSelector() as sel:
                    sel.register(readfd, selectors.EVENT_READ)
                    assert sel.select(10), 'Xvfb startup timeout'
                    display = os.read(readfd, 100).decode().strip()
                os.close(readfd)
                assert display.isdigit() and xvfb.poll() is None, 'Invalid Xvfb display'
                env['DISPLAY'] = ':' + display
                for map_id in ([args.map] if args.map else ['ion-speedway', 'aurora-stadium']):
                    for resolution in ([args.resolution] if args.resolution else ['960x640', '1280x800']):
                        case = OUT / (map_id + '-' + resolution)
                        case.mkdir()
                        limit = 180 if args.goal_attempt else (90 if map_id == 'ion-speedway' else 60)
                        with (case / 'server.log').open('w') as log:
                            command = ['node', str(ROOT / 'port/native-sports-progression/server.mjs'), tmp, str(case / 'wire.json')]
                            report['commands'].append(command)
                            server = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=log, text=True, env=env)
                            children.append(server)
                            try:
                                with selectors.DefaultSelector() as sel:
                                    sel.register(server.stdout, selectors.EVENT_READ)
                                    assert sel.select(10), 'server startup timeout'
                                    line = server.stdout.readline().strip()
                                assert line.startswith('ENDPOINT ws://127.0.0.1:'), line
                                endpoint = line.split(' ', 1)[1]
                                script = 'progression_goal_observe' if args.goal_attempt else 'progression_observe'
                                text = run([BIN, '--path', str(temp / 'godot'), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', resolution, '--script', 'res://tests/sports/' + script + '.gd', '--', '--map=' + map_id, '--endpoint=' + endpoint, '--time-limit=' + str(limit), '--round-target=10' if map_id == 'ion-speedway' else '--round-target=15', '--progression-out=' + str(case)], case / 'native.log', env, 220)
                            finally:
                                stop(server)
                        wire = json.loads((case / 'wire.json').read_text())
                        assert wire['cleanup'] == {'serverClosed': True, 'sockets': 0}
                        if args.goal_attempt:
                            end = json.loads(next(line.split(' ', 1)[1] for line in text.splitlines() if line.startswith('PROGRESSION_GOAL_ATTEMPT_ENDED ')))
                            source_goals = [e for e in wire['events'] if e['type'] == 'soccer-goal']
                            assert len(source_goals) == len(end['goals'])
                            report['cases'].append({'map':map_id, 'resolution':resolution, 'classification':'bounded goal attempt, not lifecycle acceptance', 'outcome':end, 'sourceGoals':source_goals, 'cleanup':wire['cleanup']})
                            continue
                        assert 'PROGRESSION_ENDED ' in text
                        assert wire['starts'] == 2 and wire['results'][0]['overReason'] == 'time'
                        assert abs(wire['results'][0]['race']['elapsed'] - limit) < 0.01
                        receipts = [json.loads(line.split(' ', 1)[1]) for line in text.splitlines() if line.startswith('PROGRESSION_CAPTURE ')]
                        captures = {c['label']: c for c in receipts}
                        assert {'countdown', 'driving', 'results', 'restart-countdown', 'restart-held-blocked', 'restart-enter-neutral', 'restart-fresh-driving'} <= captures.keys()
                        if map_id == 'ion-speedway':
                            assert 'checkpoint' in captures, 'no real checkpoint progression'
                        # ACK/appliedSeq is protocol evidence; state verifies gameplay effect.
                        first = captures['restart-countdown']['vehicle']
                        for label in ['restart-held-blocked', 'restart-enter-neutral']:
                            v = captures[label]['vehicle']
                            assert ((v['x']-first['x'])**2+(v['z']-first['z'])**2)**0.5 < 0.15
                            assert captures[label]['ack'] > 0
                            assert not captures[label]['keys'], 'neutral capture must precede fresh movement'
                        assert not captures['restart-held-blocked']['engaged']
                        assert captures['restart-enter-neutral']['engaged']
                        stages = [json.loads(line.split(' ', 1)[1]) for line in text.splitlines() if line.startswith('PROGRESSION_INPUT_STAGE ')]
                        fresh = next(s for s in stages if s['stage'] == 'fresh-movement')
                        neutral = lambda i: abs(i.get('x', 0)) < 1e-6 and abs(i.get('z', 0)) < 1e-6 and not any(i.get(k, False) for k in ['fire', 'power', 'jump', 'sprint', 'interact'])
                        before_fresh = [p for p in wire['inputs'] if p['round'] == 2 and p['seq'] <= fresh['input_seq']]
                        assert before_fresh and all(neutral(p['input']) for p in before_fresh)
                        assert any(not neutral(p['input']) for p in wire['inputs'] if p['round'] == 2 and p['seq'] > fresh['input_seq'])
                        after_results = [p for p in wire['inputs'] if p['round'] == 1 and p['wallMs'] >= wire['results'][0]['wallMs']]
                        assert after_results and all(neutral(p['input']) for p in after_results)
                        source_samples = [s for s in wire['samples'] if s['round'] == 1 and s['race']['elapsed'] > 0]
                        low, high = source_samples[0], source_samples[-1]
                        clock_ratio = (high['race']['elapsed']-low['race']['elapsed']) / ((high['wallMs']-low['wallMs'])/1000)
                        end = json.loads(next(line.split(' ', 1)[1] for line in text.splitlines() if line.startswith('PROGRESSION_ENDED ')))
                        if end['goals']:
                            assert 'goal' in captures and 'GOAL · Ball reset to centre' in captures['goal']['hud']
                        report['cases'].append({'map': map_id, 'resolution': resolution, 'timeLimit': limit, 'captures': list(captures), 'receivedInputs': len(wire['inputs']), 'neutralBeforeFresh': len(before_fresh), 'neutralAfterResults': len(after_results), 'sourceElapsedPerWallSecond': clock_ratio, 'maxLaps': end['max_laps'], 'goals': end['goals'], 'cleanup': wire['cleanup']})
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
