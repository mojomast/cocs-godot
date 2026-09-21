"""Offline, read-only full-snapshot evidence analyzer. No gameplay execution."""
import argparse
import json
import math
from pathlib import Path


class Invalid(ValueError):
    pass


def require(ok, location, message):
    if not ok:
        raise Invalid(f'{location}: {message}')


def number(v):
    return type(v) in (int, float) and math.isfinite(v)


def integer(v):
    return type(v) is int and v >= 0


def analyze(data):
    result = {'status': 'incomplete', 'classification': 'offline_capture_analysis',
              'transitions': [], 'errors': [], 'notes': [], 'counts': {'snapshots': 0, 'dead_snapshots': 0, 'death_events': 0, 'spawn_events': 0, 'duplicates': 0},
              'camera_reseeding': 'unobserved', 'dead_input_gating': 'unobserved'}
    clients = {}
    segments = []

    def cut(c, reason, loc):
        if c.get('segment'):
            result['notes'].append({'location': loc, 'reason': reason})
        c['segment'] = None

    try:
        require(isinstance(data, dict) and isinstance(data.get('frames'), list), '$', 'expected object with frames array')
        result['input_label'] = data.get('classification', 'unlabeled; provenance requires independent review')
        for i, r in enumerate(data['frames']):
            loc = f'$.frames[{i}]'
            require(isinstance(r, dict), loc, 'expected record object')
            require(integer(r.get('client')), loc, 'client must be a nonnegative connection index')
            require(r.get('direction') in ('server', 'client'), loc, 'unsupported direction; transport records require a documented adapter')
            f = r.get('frame')
            require(isinstance(f, dict) and isinstance(f.get('type'), str), loc, 'expected typed frame object')
            if r['direction'] == 'client':
                continue
            c = clients.setdefault(r['client'], {'peer': None, 'room': None, 'round': None, 'actor': None, 'segment': None, 'seqs': {}, 'seq': -1, 'time': -1, 'events': {}, 'event_id': -1, 'event_time': -1})
            t = f['type']
            if t == 'welcome':
                cut(c, 'welcome connection boundary', loc)
                require(integer(f.get('peerId')) and isinstance(f.get('roomId'), str), loc, 'welcome needs peerId and roomId')
                c.update(peer=f['peerId'], room=f['roomId'], round=None, actor=None, seqs={}, seq=-1, time=-1, events={}, event_id=-1, event_time=-1)
            elif t == 'start':
                cut(c, 'start boundary (never stitch starts)', loc)
                require(integer(f.get('roundRevision')), loc, 'server start requires roundRevision')
                c.update(round=f['roundRevision'], actor=c['actor'] if c.get('mapping_round') == f['roundRevision'] else None, events={}, event_id=-1, event_time=-1, time=-1)
            elif t == 'lobby':
                require(isinstance(f.get('players'), list) and integer(f.get('roundRevision')), loc, 'lobby needs players and roundRevision')
                require(f.get('roomId') == c['room'], loc, 'lobby room differs from welcome')
                if f['roundRevision'] != c['round']:
                    cut(c, 'lobby round boundary; await start', loc)
                    c.update(round=None, actor=None)
                rows = [p for p in f['players'] if isinstance(p, dict) and p.get('peerId') == c['peer']]
                require(len(rows) <= 1, loc, 'duplicate local peer mapping')
                p = rows[0] if rows else {}
                actor = p.get('actorId') if p.get('connected') is True and p.get('spectate') is False else None
                require(actor is None or integer(actor), loc, 'invalid actorId')
                if actor != c['actor']:
                    cut(c, 'actor reassigned/revoked/disconnected', loc)
                c['actor'] = actor
                c['mapping_round'] = f['roundRevision']
            elif t in ('disconnect', 'disconnected', 'close', 'revoked'):
                # Not native protocol types: refuse to guess transport extension semantics.
                raise Invalid(f'{loc}: unsupported connection marker {t}; documented adapter required')
            elif t in ('snapshot-delta', 'snapshot_delta'):
                raise Invalid(f'{loc}: delta snapshots unsupported; provide recorded full snapshots (delta=0)')
            elif t == 'error':
                cut(c, 'native decoder error boundary', loc)
                c.update(round=None, actor=None)
            elif t == 'results':
                cut(c, 'results boundary', loc)
                c['round'] = None
            elif t == 'snapshot':
                seq, s = f.get('seq'), f.get('state')
                require(integer(seq) and isinstance(s, dict), loc, 'snapshot needs integer seq and state')
                if seq in c['seqs']:
                    require(c['seqs'][seq] == f, loc, 'conflicting duplicate snapshot sequence')
                    result['counts']['duplicates'] += 1
                    continue
                require(seq > c['seq'], loc, 'out-of-order snapshot sequence')
                c['seqs'][seq] = f
                c['seq'] = seq
                require(number(s.get('time')) and s['time'] >= c['time'], loc, 'invalid or decreasing simulation time')
                c['time'] = s['time']
                require(type(s.get('over')) is bool and isinstance(s.get('actors'), list), loc, 'state needs over boolean and actors array')
                ids = set()
                for a in s['actors']:
                    require(isinstance(a, dict) and integer(a.get('id')), loc, 'invalid actor object/id')
                    require(a['id'] not in ids, loc, 'duplicate actor ID')
                    ids.add(a['id'])
                    require(number(a.get('health')) and a['health'] >= 0 and number(a.get('dead')) and a['dead'] >= 0, loc, 'health/dead must be finite nonnegative numbers')
                result['counts']['snapshots'] += 1
                if s['over']:
                    cut(c, 'over snapshot', loc)
                    c['round'] = None
                    continue
                if c['round'] is None or c['actor'] is None or c['peer'] is None:
                    continue
                a = next((a for a in s['actors'] if a['id'] == c['actor']), None)
                if a is None:
                    cut(c, 'actor absent: not death evidence', loc)
                    continue
                phase = 'alive' if a['health'] > 0 and a['dead'] == 0 else 'dead' if a['health'] == 0 and a['dead'] > 0 else 'ambiguous'
                if phase == 'ambiguous':
                    cut(c, 'ambiguous health/dead combination', loc)
                    continue
                result['counts']['dead_snapshots'] += phase == 'dead'
                if c['segment'] is None:
                    c['segment'] = {'client': r['client'], 'peer': c['peer'], 'room': c['room'], 'round': c['round'], 'actor': c['actor'], 'samples': [], 'events': []}
                    segments.append(c['segment'])
                c['segment']['samples'].append({'location': loc + '.frame.state', 'seq': seq, 'time': s['time'], 'phase': phase})
            elif t == 'events':
                require(isinstance(f.get('items'), list), loc, 'events needs items array')
                for j, e in enumerate(f['items']):
                    eloc = loc + f'.frame.items[{j}]'
                    require(isinstance(e, dict) and integer(e.get('id')) and number(e.get('time')) and isinstance(e.get('type'), str), eloc, 'event needs id, finite time and type')
                    if e['id'] in c['events']:
                        require(e == c['events'][e['id']], eloc, 'conflicting duplicate event')
                        result['counts']['duplicates'] += 1
                        continue
                    require(e['id'] > c['event_id'] and e['time'] >= c['event_time'], eloc, 'out-of-order event id/time')
                    c['events'][e['id']] = e
                    c.update(event_id=e['id'], event_time=e['time'])
                    if e['type'] in ('death', 'spawn'):
                        require(integer(e.get('actor')), eloc, 'death/spawn needs actor ID')
                        result['counts'][e['type'] + '_events'] += 1
                    if c['segment'] and e.get('actor') == c['actor']:
                        c['segment']['events'].append(dict(e, location=eloc))
        for seg in segments:
            alive = dead = None
            for s in seg['samples']:
                if s['phase'] == 'alive':
                    if alive and dead and alive['time'] < dead['time'] < s['time']:
                        deaths = [e for e in seg['events'] if e['type'] == 'death' and alive['time'] < e['time'] <= dead['time']]
                        spawns = [e for e in seg['events'] if e['type'] == 'spawn' and dead['time'] < e['time'] <= s['time']]
                        result['transitions'].append({k: seg[k] for k in ('client', 'peer', 'room', 'round', 'actor')} | {'level': 'event_corroborated' if deaths and spawns else 'snapshot_observed', 'alive_before': alive, 'dead': dead, 'alive_after': s, 'death_events': [e['location'] for e in deaths], 'spawn_events': [e['location'] for e in spawns]})
                    alive, dead = s, None
                elif alive and dead is None:
                    dead = s
        if result['transitions']:
            result['status'] = 'established'
        else:
            result['notes'].append({'location': '$', 'reason': 'no contiguous same-mapping same-round alive/dead/alive snapshot witness'})
    except Invalid as exc:
        result['status'] = 'invalid'
        result['errors'].append(str(exc))
        result['transitions'] = []
    return result


def load(path):
    try:
        def pairs(items):
            d = {}
            for k, v in items:
                if k in d:
                    raise ValueError(f'duplicate JSON key: {k}')
                d[k] = v
            return d
        data = json.loads(Path(path).read_text(encoding='utf-8'), object_pairs_hook=pairs,
                          parse_constant=lambda s: (_ for _ in ()).throw(ValueError(f'nonfinite JSON: {s}')))
        return analyze(data)
    except (OSError, ValueError, RecursionError) as exc:
        return {'status': 'invalid', 'errors': [str(exc)], 'transitions': [], 'camera_reseeding': 'unobserved', 'dead_input_gating': 'unobserved'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', help='explicit read-only JSON capture path')
    parser.add_argument('--json', action='store_true', help='deterministic JSON instead of human summary')
    args = parser.parse_args()
    r = load(args.capture)
    if args.json:
        print(json.dumps(r, sort_keys=True, indent=2, allow_nan=False))
    else:
        print(f"{r['status'].upper()}: {len(r['transitions'])} same-actor same-round snapshot transitions")
        for t in r['transitions']:
            print(f"client={t['client']} actor={t['actor']} round={t['round']} {t['level']}: " + ' -> '.join(t[k]['location'] for k in ('alive_before', 'dead', 'alive_after')))
        for error in r['errors']:
            print(error)
        print('Camera reseeding: unobserved; dead-input gating: unobserved. Offline evidence only.')
    return {'established': 0, 'incomplete': 1, 'invalid': 2}[r['status']]


if __name__ == '__main__':
    raise SystemExit(main())
