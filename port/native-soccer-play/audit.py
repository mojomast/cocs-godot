#!/usr/bin/env python3
"""Offline, read-only source/receipt audit. Does not run matches or retry goals."""
import hashlib
import json
import pathlib
import subprocess
import argparse

ROOT = pathlib.Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'port/native-soccer-play/evidence'
BIN = pathlib.Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
WS = pathlib.Path('/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules/ws')
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=pathlib.Path, help='Fresh audit destination; preserves the original delivered audit')
options = parser.parse_args()
destination = options.output if options.output else EVIDENCE / 'audit.json'
if options.output and destination.exists():
    parser.error('Explicit audit destination already exists')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


report = {'classification':'offline source/hash/goal receipt audit; no simulation', 'runs':[], 'files':{}}
attempts = []
for directory in sorted(p for p in EVIDENCE.iterdir() if p.is_dir()):
    summary = json.loads((directory / 'summary.json').read_text())
    if summary['attempt']:
        attempts.append(summary['attempt'])
    assert summary['status'] == 'PASS'
    assert summary['privateTempRemoved'] and summary['ownedProcessesReaped']
    assert sha(directory / 'hashes.json') == summary['hashManifestSHA256']
    manifest = json.loads((directory / 'hashes.json').read_text())
    differences = []
    for path, expected in manifest.items():
        actual = sha(BIN if path == 'pinnedGodot' else ROOT / path)
        if actual != expected:
            differences.append(path)
    # Acceptance drivers evolve between the two planned attempts. Production
    # geometry/source/native gameplay must be identical to the reviewed final code.
    assert not [p for p in differences if p.startswith(('game/', 'server/', 'godot/sports/'))], differences
    goals = []
    timings = []
    for wire_path in sorted(directory.glob('*/wire.json')):
        wire = json.loads(wire_path.read_text())
        assert wire['cleanup'] == {'serverClosed':True, 'sockets':0}
        assert wire['starts'] == 1
        for event in wire['events']:
            if event['type'] != 'soccer-goal':
                continue
            before = [s for s in wire['samples'] if s['time'] < event['time']-0.001][-1]
            after = next(s for s in wire['samples'] if s['time'] >= event['time'])
            role = next((a for a in before['roles'] if a['id'] == event['actorId']), None)
            local = next(a for a in before['roles'] if a['id'] == before['actor'])
            team = str(event['team'])
            assert after['race']['scores'][team] == before['race']['scores'][team]+1
            is_local = event['actorId'] == local['id'] and event['team'] == local['team'] and not local['bot']
            goals.append({'resolution':wire_path.parent.name, 'event':event, 'lastTouchRole':role,
                          'localRole':local, 'localScoringAcceptance':is_local,
                          'ownGoal':role is not None and role['team'] != event['team'],
                          'before':{'seq':before['seq'], 'ack':before['ack'], 'time':before['time'], 'scores':before['race']['scores']},
                          'after':{'seq':after['seq'], 'ack':after['ack'], 'time':after['time'], 'scores':after['race']['scores'], 'ball':after['race']['ball']}})
        samples = wire['samples']
        first, last = samples[0], samples[-1]
        assert last['wallMs'] < 180000, 'bounded owned-server acceptance exceeds three minutes'
        ratio = (last['time']-first['time'])/((last['wallMs']-first['wallMs'])/1000)
        assert 0.8 < ratio < 1.2, ratio
        timings.append({'resolution':wire_path.parent.name, 'lastServerWallMs':last['wallMs'], 'sourceSecondsPerWallSecond':ratio})
    report['runs'].append({'directory':directory.name, 'attempt':summary['attempt'],
                           'hashManifestSHA256':summary['hashManifestSHA256'],
                           'currentToolDifferences':differences, 'productionDifferences':[],
                           'goals':goals, 'timings':timings, 'cleanupVerified':True})
    for path in sorted(directory.rglob('*')):
        if path.is_file():
            report['files'][str(path.relative_to(EVIDENCE))] = {'sha256':sha(path), 'bytes':path.stat().st_size}
assert sorted(attempts) == [1, 2], 'exactly the two planned bounded attempts, no retries'
ws_manifest = ''.join(str(p.relative_to(WS))+' '+sha(p)+'\n' for p in sorted(WS.rglob('*')) if p.is_file())
report['runtime'] = {'godotVersion':subprocess.check_output([str(BIN),'--version'], text=True).strip(), 'godotSHA256':sha(BIN),
                     'nodeVersion':subprocess.check_output(['node','--version'], text=True).strip(), 'nodeSHA256':sha(pathlib.Path('/usr/bin/node')),
                     'wsVersion':json.loads((WS/'package.json').read_text())['version'], 'wsTreeSHA256':hashlib.sha256(ws_manifest.encode()).hexdigest()}
report['status'] = 'PASS'
report['auditorSHA256'] = sha(pathlib.Path(__file__))
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps({'status':report['status'], 'runs':len(report['runs']), 'goals':sum(len(r['goals']) for r in report['runs']),
                  'localGoals':sum(g['localScoringAcceptance'] for r in report['runs'] for g in r['goals']), 'auditSHA256':sha(destination)}, indent=2))
