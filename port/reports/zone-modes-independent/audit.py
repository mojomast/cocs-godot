"""Read-only independent audit. Run from repo root with new evidence directories."""
import gzip
import hashlib
import json
import math
import struct
import subprocess
import sys
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args]).decode().strip()


def audit(path):
    summary = json.loads((path / 'summary.json').read_text())
    archive = json.loads((path / 'archive.json').read_text())
    logs = {}
    for name, expected in archive.items():
        raw = gzip.decompress((path / (name + '.gz')).read_bytes())
        assert len(raw) == expected['bytes'] and sha(raw) == expected['sha256']
        logs[name] = raw.decode()
    for name, expected in summary['runtimeHashes'].items():
        assert sha(Path(name).read_bytes()) == expected, name
    assert summary['exit'] == 0, summary['reason']
    assert all(p['reaped'] and p['absent'] for p in summary['cleanup'])
    assert summary['serverClosed'] and not summary['sockets'] and summary['temporaryTreeRemoved']
    assert not any(s in logs['native.stdout.log'] + logs['native.stderr.log']
                   for s in ['SCRIPT ERROR', 'ERROR:', 'Parse Error', 'leaked'])
    wire = [json.loads(line) for line in logs['wire.jsonl'].splitlines()]
    native = [json.loads(line.removeprefix('ZONE_NATIVE '))
              for line in logs['native.stdout.log'].splitlines() if line.startswith('ZONE_NATIVE ')]
    live = [json.loads(line.removeprefix('ZONE_LIVE_OK '))
            for line in logs['native.stdout.log'].splitlines() if line.startswith('ZONE_LIVE_OK ')]
    assert len(live) == 1 and live[0]['capture'] and live[0]['held_score'] and live[0]['results']
    assert live[0]['rounds'] == 2 and not live[0]['route_error']
    actor_id = native[0]['actor_id']
    starts = [f for f in wire if f['type'] == 'start' and f['recipient'] == 0]
    results = [f for f in wire if f['type'] == 'results' and f['recipient'] == 0]
    assert len(starts) == 2 and len(results) == 1
    cfg = starts[0]['config']
    assert cfg['botCount'] == 0 and cfg['timeLimit'] == 60 and cfg['fragLimit'] == 100
    assert cfg['speed'] == cfg['gravity'] == cfg['damage'] == 1 and not cfg['mutators']
    received = [f['frame'] for f in wire if f['type'] == 'received']
    assert set(f['type'] for f in received) == {'create', 'host', 'start', 'input'}
    hosts = [f for f in received if f['type'] == 'host']
    assert len(hosts) == 1 and hosts[0]['config'] == {'mode': summary['mode'], 'botCount': 0, 'timeLimit': 60}
    frames = [f for f in wire if f['type'] == 'snapshot' and f['recipient'] == 0]
    index = {(f['round'], f['seq']): f for f in frames}
    correlated = 0
    for n in native:
        if n['seq'] < 0 or not n['projection'].get('zones'):
            continue
        f = index[n['round'], n['seq']]
        s = f['state']
        assert n['projection']['time'] == s['time']
        assert n['projection']['scores'] == [s['teamScores']['0'], s['teamScores']['1']]
        assert n['rendered'] == s['objectives']['zones']
        assert n['actor_id'] == actor_id
        correlated += 1
    state = [f['state'] for f in frames if f['round'] == 1]

    def actor(s):
        return next(a for a in s['actors'] if a['id'] == actor_id)

    team = actor(state[0])['team']
    capture = []
    scored = []
    for before, after in zip(state, state[1:]):
        a = actor(after)
        assert after['time'] >= before['time']
        for z in after['objectives']['zones']:
            p = next((p for p in before['objectives']['zones'] if p['id'] == z['id']), None)
            inside = (a['health'] > 0 and math.hypot(a['x']-z['x'], a['z']-z['z']) <= z['radius']
                      and abs(a['y']-z['y']) <= 5)
            if p and p['owner'] is None and z['owner'] == team:
                assert inside and a['scoreStats']['objectiveCaptures'] > actor(before)['scoreStats']['objectiveCaptures']
                capture.append({'time': after['time'], 'zone': z, 'actor': a})
            if after['teamScores'][str(team)] > before['teamScores'][str(team)] and z['owner'] == team and not z['contested'] and inside:
                scored.append({'time': after['time'], 'score': after['teamScores'][str(team)], 'zone': z['id']})
    assert capture and scored, 'actual source capture and living in-zone score growth required'
    end = results[0]['state']
    assert end['over'] and end['winner'] == team and 60 <= end['time'] < 61
    wall_seconds = (results[0]['wall'] - starts[0]['wall']) / 1000
    assert 55 < wall_seconds < 85, wall_seconds
    events = [e for f in wire if f['type'] == 'events' and f['round'] == 1 for e in f['items']]
    captures = [e for e in events if e['type'] == 'zone-capture']
    rotations = [e for e in events if e['type'] == 'hill-rotate']
    assert captures
    if summary['mode'] == 'koth':
        assert rotations
        assert len({z['id'] for s in state for z in s['objectives']['zones']}) > 1
    restarted = next(f['state'] for f in frames if f['round'] == 2)
    assert restarted['time'] < 1 and not restarted['over']
    assert all(score == 0 for score in restarted['teamScores'].values())
    assert actor(restarted)['scoreStats']['objectiveCaptures'] == 0
    dimensions = {}
    for name in ['gameplay.png', 'results.png']:
        raw = (path / name).read_bytes()
        dimensions[name] = list(struct.unpack('>II', raw[16:24]))
        assert dimensions[name] == ([960, 640] if summary['mode'] == 'domination' else [1280, 800])
    return {'evidence': str(path), 'summaryBaseFieldIsStale': summary['base'],
            'archiveAndRuntimeHashesVerified': True, 'dimensions': dimensions,
            'initialActor': actor(state[0]), 'captureTransitions': capture,
            'scoredInsideSamples': len(scored), 'firstScore': scored[0], 'lastScore': scored[-1],
            'captureEvents': captures, 'rotationEvents': rotations,
            'correlatedSnapshots': correlated, 'finalScore': end['teamScores'],
            'sourceTime': end['time'], 'sourceRoundWallSeconds': wall_seconds,
            'winner': end['winner'], 'restartResetVerified': True, 'liveChecks': live[0]['checks'],
            'ackHighwater': max(n['ack'] for n in native), 'ackMeaning': 'receipt only',
            'receivedInputs': sum(f['type'] == 'input' for f in received), 'cleanup': summary['cleanup']}


if __name__ == '__main__':
    report = {'testedHead': '70f4b8f726cf202776b1e7a2fc49e66e5da184ed',
              'integrationBase': git('rev-parse', '8a58c97'),
              'sourceLock': json.loads(Path('port/contracts/source-lock.json').read_text()),
              'runs': [audit(Path(p)) for p in sys.argv[1:]]}
    assert len(report['runs']) == 2
    print(json.dumps(report, indent=2))
