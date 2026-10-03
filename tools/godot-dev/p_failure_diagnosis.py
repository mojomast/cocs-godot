"""Read-only diagnosis of completed P attempts. Never launch or mutate a runtime."""
import argparse
import hashlib
import json
from pathlib import Path


def applied_match(rows, received):
    """Sequence numbers restart; only the same round AND input epoch can apply."""
    return [r for r in rows if r.get('kind') == 'applied'
            and (r.get('round'), r.get('inputEpoch'), r.get('inputSeq')) ==
            (received.get('round'), received.get('inputEpoch'), received.get('seq'))]


def campaign(rows):
    received = [r for r in rows if r.get('kind') == 'received' and r.get('round') == 1]
    movement = []
    for i, row in enumerate(received):
        if row.get('controls', {}).get('x') or row.get('controls', {}).get('z'):
            movement.append({'received': row, 'applied': applied_match(rows, row),
                'gap_ms': row['observedMs'] - received[i - 1]['observedMs'] if i else None,
                'next_received': received[i + 1] if i + 1 < len(received) else None})
    return movement


def completed_failure(report, job):
    attempt = report['attempts'][job][-1]
    if attempt['status'] != 'failed':
        raise ValueError('Only retained completed failures: ' + job)
    return Path(attempt['scope'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    evidence = {}

    def read(path):
        raw = path.read_bytes()
        evidence[str(path)] = hashlib.sha256(raw).hexdigest()
        return json.loads(raw)

    jobs = {}
    path = completed_failure(report, 'gameplay-seven-native') / 'artifacts'
    results = read(path / 'results.json')
    jobs['gameplay-seven-native'] = {'operators': results, 'failed_details': {}}
    for row in results:
        if row['passed']: continue
        native = read(path / (row['operator'] + '-native.json'))
        jobs['gameplay-seven-native']['failed_details'][row['operator']] = {
            'events': [e for e in native['events'] if e['type'] in ['move-start', 'move-end', 'move-blocked', 'power']],
            'height_range': [min(p['y'] for p in native['poses']), max(p['y'] for p in native['poses'])]}
        wire = read(path / (row['operator'] + '-wire.json'))
        snapshots = read(path / (row['operator'] + '-snapshots.json'))
        edges, last = [], None
        for packet in wire:
            jumping = packet['input'].get('jump')
            if jumping == last: continue
            last = jumping
            ack = next((s for s in snapshots if s.get('acks', {}).get('0', -1) >= packet['seq']), None)
            edges.append({'seq': packet['seq'], 'jump': jumping,
                'first_ack_source_time': ack['state'].get('time') if ack else None})
        jobs['gameplay-seven-native']['failed_details'][row['operator']]['jump_edges'] = edges
    path = completed_failure(report, 'world-connected-campaign') / 'artifacts/campaign-input-diagnostic.json'
    diagnostic = read(path)
    assert diagnostic['complete'] and diagnostic['dropped'] == 0
    jobs['world-connected-campaign'] = {'round1_movement': campaign(diagnostic['rows'])}
    for family in ['mode', 'world', 'sports', 'combined']:
        for size in ['wide', 'compact']:
            job = f'spectator-{family}-{size}'
            path = completed_failure(report, job)
            reports = read(next((path / 'artifacts').glob('*/native-reports.json')))
            logs = {}
            for log in (path / 'artifacts').rglob('native.log'):
                raw = log.read_bytes()
                evidence[str(log)] = hashlib.sha256(raw).hexdigest()
                logs[log.parent.name] = [s for s in raw.decode(errors='replace').splitlines() if 'FAIL' in s or 'ERROR' in s]
            jobs[job] = {'failures': logs, 'observations': [{
                'name': r['name'], 'action': r.get('action'), 'ok': r['ok'],
                **{k: r.get('observation', {}).get(k) for k in ['target', 'targets', 'pointer', 'ready', 'phase', 'viewport']}}
                for r in reports]}
    path = completed_failure(report, 'horde-rendered-wide')
    result = read(next((path / 'artifacts').glob('native-chain-*/result.json')))
    jobs['horde-rendered-wide'] = {key: result.get(key) for key in
        ['passed', 'normalClock', 'debug', 'maxInputGapMs', 'maxAck', 'upgrades', 'native', 'errors', 'resets', 'videoCadence']}
    args.output.write_text(json.dumps({'schema': 1, 'candidate': report['port_commit'],
        'input_identity': report['input_identity'], 'report': str(args.report),
        'classification': 'read-only completed failure diagnosis, not native acceptance',
        'jobs': jobs, 'artifact_sha256': evidence}, indent=2) + '\n')


if __name__ == '__main__': main()
