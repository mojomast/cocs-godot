#!/usr/bin/env python3
"""Independent offline effect audit; queue/receipt/ACK are not interchangeable."""
import gzip
import json
import math
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NAMES = json.loads(subprocess.check_output(['node','--input-type=module','-e',
    "import {WEAPONS} from './game/data.mjs'; console.log(JSON.stringify(WEAPONS.map(w=>w.name)))"],cwd=ROOT,text=True))

def read(path):
    return path.read_text() if path.exists() else gzip.open(str(path)+'.gz','rt').read()

def require(value, message):
    if not value:
        raise RuntimeError(message)

records = []
for directory in sorted((HERE/'evidence').iterdir()):
    summary = json.loads((directory/'summary.json').read_text())
    record = {'id':directory.name,'status':summary['status'],'options':summary['options'],'cases':[]}
    for case in sorted(directory.iterdir()):
        if not case.is_dir() or not any(case.glob('wire.json*')):
            continue
        wire = json.loads(read(case/'wire.json'))
        native = read(case/'native.log')
        def rows(prefix):
            return [json.loads(line[len(prefix):]) for line in native.splitlines() if line.startswith(prefix)]
        queues = [r for r in rows('PORT_NATIVE_TRACE ') if r.get('event') == 'input_queue' and r['queued']]
        captures = rows('ARMS_CAPTURE ')
        snapshots = rows('ARMS_SNAPSHOT ')
        details = {'map':case.name,'starts':wire['starts'],'queued':len(queues),'receipts':len(wire['inputs']),
                   'ACKHighwater':max((s.get('ack') or 0 for s in wire['samples']),default=0),
                   'promotions':[],'captures':captures,'results':wire['results']}
        details['transportByRound'] = [{'round':n,
            'queued':sum(q['round'] == n for q in queues),
            'receipts':sum(r['round'] == n for r in wire['inputs']),
            'ACKHighwater':max((s.get('ack') or 0 for s in wire['samples'] if s['round'] == n),default=0)}
            for n in range(1,wire['starts']+1)]
        require(wire['cleanup'] == {'serverClosed':True,'sockets':0}, 'Server cleanup')
        require(all('weapon' not in r['input'] for r in wire['inputs']), 'Weapon request escaped native lock')
        for config in wire['configs']:
            c = config['config']
            require(config['mapId'] == case.name and c['mode'] == 'armsrace' and c['botCount'] == 2 and c['difficulty'] == 'normal' and c['fragLimit'] == 10, 'Source configuration')
            require(c['timeLimit'] == (180 if summary['options']['attempt'] else 60), 'Ordinary source timer')
        if wire['samples']:
            actor_id = wire['samples'][0]['actor']
            def actor(s):
                return next(a for a in s['state']['actors'] if a['id'] == actor_id)
            require(all(len(s['state']['actors']) == 3 and sum(a['bot'] for a in s['state']['actors']) == 2 for s in wire['samples']), 'Roster changed')
            for event in wire['events']:
                if event['type'] != 'armsrace-promote' or event['actor'] != actor_id:
                    continue
                before = [s for s in wire['samples'] if s['round'] == event['round'] and s['state']['time'] < event['time']][-1]
                after = next(s for s in wire['samples'] if s['round'] == event['round'] and s['state']['time'] >= event['time'])
                deaths = [e for e in wire['events'] if e['round'] == event['round'] and e['type'] == 'death' and e.get('killer') == actor_id and not e.get('self') and e['time'] == event['time']]
                shots = [e for e in wire['events'] if e['round'] == event['round'] and e['type'] == 'shot' and e.get('actor') == actor_id and e['time'] == event['time']]
                a, b = actor(before), actor(after)
                require(deaths and b['frags'] == a['frags']+1 and b['ladder'] > a['ladder'] and b['weapon'] == event['weapon'], 'Source kill/promotion effect')
                display = next(c for c in captures if c['tag'] == 'promotion' and c['display']['seq'] >= after['seq'])
                shown = next(s for s in wire['samples'] if s['seq'] == display['display']['seq'] and s['round'] == event['round'])
                shown_actor = actor(shown)
                require('RUNG %d / 10' % (shown_actor['ladder']+1) in display['display']['current'] and 'PROMOTED' in display['display']['transition'], 'Source rung/display mismatch')
                require(NAMES[shown_actor['weapon']] in display['display']['current'], 'Current weapon label mismatch')
                if shown_actor['ladder'] < 9:
                    require(display['display']['next'] == 'Next: '+NAMES[shown_actor['ladder']+1], 'Next weapon label mismatch')
                require(any(r['input'].get('fire') and r['round'] == event['round'] and r['seq'] <= after['ack'] for r in wire['inputs']), 'No received fire at/below effect ACK highwater')
                native_shown = next(s for s in snapshots if s['seq'] == shown['seq'] and s['round'] == shown['round'])
                require(native_shown['actor']['weapon'] == shown_actor['weapon'], 'Native/source weapon mismatch')
                # Observer snapshot callback precedes the deferred HUD callback.
                # Its actor is current, while its HUD text can be one frame old.
                # ARMS_CAPTURE is awaited post-draw and owns the display claim.
                require(shots and shots[0]['weapon'] == a['weapon'] and shots[0]['hit'] == deaths[0]['actor'], 'Source shot/victim attribution')
                details['promotions'].append({'event':event,'deaths':deaths,'shots':shots,'before':before,'after':after,'snapshotCallback':native_shown,'postDrawDisplay':display})
            if wire['results']:
                require(wire['starts'] == 2 and len(wire['results']) == 1, 'Lifecycle count')
                result = wire['results'][0]['state']
                require(result['over'] and result['overReason'] == 'time' and result['time'] >= 60 and result['winner'] is None, 'Natural timed result')
                reset = next(s for s in wire['samples'] if s['round'] == 2)
                require(all(a['ladder'] == a['weapon'] == a['frags'] == a['deaths'] == 0 for a in reset['state']['actors']), 'Round reset')
                ended = rows('ARMS_ENDED ')[-1]
                require(ended['fresh_moved'] and ended['rounds'] == 2, 'Fresh restart movement')
                details['restartFirstSnapshot'] = reset
                restarted = [s for s in wire['samples'] if s['round'] == 2]
                position = lambda s: [actor(s)[k] for k in ['x','y','z']]
                origin = position(reset)
                held_displacement = max(math.dist(origin,position(s)) for s in restarted if s['state']['time'] < 1)
                fresh_displacement = math.dist(origin,position(restarted[-1]))
                require(held_displacement <= .1 and fresh_displacement > .5, 'Independent restart displacement')
                details['restartDisplacement'] = {'heldFirstSourceSecondMaxMeters':held_displacement,'freshFinalMeters':fresh_displacement,
                    'firstMovingReceipt':next(r for r in wire['inputs'] if r['round'] == 2 and (r['input']['x'] or r['input']['z']))}
        record['cases'].append(details)
    require(summary.get('ownedProcessesReaped') and summary.get('privateTempRemoved'), 'Owned cleanup')
    require(all(c['closed'] for c in summary.get('listenerCleanup',[])), 'Listener survived')
    records.append(record)

combat = [r for r in records if r['options']['attempt'] and any(c['starts'] for c in r['cases'])]
require(len(combat) <= 2, 'Independent combat budget exceeded')
result = {'runs':records,'independentLiveCombatAttempts':len(combat),
          'interpretation':'Source kill/death and actor changes prove effects. Queued records, receipts and ACK highwater are separate; ACK highwater does not prove every intermediate packet was applied.',
          'fullTenRungVictoryAccepted':False}
(HERE/'AUDIT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'runs':len(records),'independentLiveCombatAttempts':len(combat),'status':'PASS'},indent=2))
