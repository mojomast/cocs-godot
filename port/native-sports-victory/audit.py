#!/usr/bin/env python3
"""Offline attribution/config/ACK/artifact audit; never launches a match."""
import argparse
import hashlib
import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = ROOT/'port/native-sports-victory'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=pathlib.Path, default=HERE/'evidence/audit.json')
args = parser.parse_args()
report = {'runs':[], 'scoringAttempts':0, 'localGoals':0, 'botGoals':0, 'localOwnGoals':0}
for summary_path in sorted((HERE/'evidence').glob('*/summary.json')):
    folder = summary_path.parent
    summary = json.loads(summary_path.read_text())
    hashes = json.loads((folder/'hashes.json').read_text())
    changes = [name for name,digest in hashes.items() if (ROOT/name).is_file() and hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest]
    production_changes = [name for name in changes if name.startswith(('game/','server/','godot/sports/'))]
    assert not production_changes, production_changes
    attempt = summary['options']['attempt']
    if attempt: report['scoringAttempts'] += 1
    row = {'id':folder.name,'status':summary['status'],'options':summary['options'],'hashManifestSHA256':summary['hashManifestSHA256'],'productionHashDifferences':production_changes,'historicalToolDifferences':changes,'cases':[]}
    for case in summary['cases']:
        path = folder/case['resolution']
        wire = json.loads((path/'wire.json').read_text())
        assert wire['cleanup']=={'serverClosed':True,'sockets':0}
        text = (path/'native.log').read_text()
        captures = [json.loads(line.split(' ',1)[1]) for line in text.splitlines() if line.startswith('PROGRESSION_CAPTURE ')]
        samples = wire['samples']
        first = next(s for s in samples if s['race']['elapsed']>0)
        last = [s for s in samples if s['round']==1][-1]
        rate = (last['race']['elapsed']-first['race']['elapsed'])/((last['wallMs']-first['wallMs'])/1000)
        assert .8 < rate < 1.2, rate
        c = {'resolution':case['resolution'],'hostRequests':wire['hostRequests'],'acceptedConfigs':wire['configs'],'initialRoles':samples[0]['roles'],'inputArrivals':len(wire['inputs']),'firstRoundFinalACK':last.get('ack'),'lastWallMs':samples[-1]['wallMs'],'sourceSecondsPerWallSecond':rate,'goals':[]}
        for goal in [e for e in wire['events'] if e['type']=='soccer-goal']:
            before = [s for s in samples if s['time']<goal['time']-.001][-1]
            after = next(s for s in samples if s['time']>=goal['time'])
            scorer = next(a for a in before['roles'] if a['id']==goal['actorId'])
            team = str(goal['team'])
            assert after['race']['scores'][team]==before['race']['scores'][team]+1
            local = goal['actorId']==before['actor'] and not scorer['bot']
            own = goal['team']!=scorer['team']
            classification = 'local-own-goal' if local and own else ('local-goal' if local else ('bot-own-goal' if own else 'bot-goal'))
            report['localGoals'] += int(local and not own)
            report['localOwnGoals'] += int(local and own)
            report['botGoals'] += int(not local)
            c['goals'].append({'classification':classification,'event':goal,'scorer':scorer,'before':before,'after':after})
            if local and not own:
                opponent = next(g for g in before['race']['goals'] if g['team']!=scorer['team'])
                assert goal['pos']['x']==opponent['x'] and goal['pos']['z']==opponent['z']
                assert after['race']['ball']['x']==0 and after['race']['ball']['z']==0
                old_count = next(s['goals'] for s in before['race']['standings'] if s['actorId']==scorer['id'])
                new_count = next(s['goals'] for s in after['race']['standings'] if s['actorId']==scorer['id'])
                assert new_count==old_count+1
                notification = ('Red' if scorer['team']==0 else 'Blue')+' GOAL · Ball reset to centre'
                visible = next(v for v in captures if v['seq']>=after['seq'] and v['race']['scores'][team]==after['race']['scores'][team] and notification in v['hud'])
                assert (path/(visible['label']+'.png')).is_file()
                c['goals'][-1]['visibleLocalGoalCapture'] = visible
        if summary['options']['race']:
            result = wire['results'][0]
            assert result['overReason']=='race-finish' and result['race']['winnerId']==result['actor']
            assert result['race']['standings'][0]['finishTime'] is not None
            assert case['outcome']['gates']==list(range(17))+[0]
            stages = [json.loads(line.split(' ',1)[1]) for line in text.splitlines() if line.startswith('VICTORY_INPUT_STAGE ')]
            neutral = [i for i in wire['inputs'] if i['round']==2 and i['seq']<=stages[1]['seq']]
            assert len(neutral)>30 and all(i['input']['x']==0 and i['input']['z']==0 for i in neutral)
            fresh = next(v for v in captures if v['label']=='restart-fresh-driving')
            origin = next(v for v in captures if v['label']=='restart-enter-neutral')
            distance = math.hypot(fresh['vehicle']['x']-origin['vehicle']['x'],fresh['vehicle']['z']-origin['vehicle']['z'])
            assert distance>.5 and fresh['ack']>origin['ack']
            c.update({'result':result,'restartNeutralReceipts':len(neutral),'freshACK':fresh['ack'],'enterOnlyACK':origin['ack'],'freshDisplacementAtCapture':distance})
        if attempt:
            assert case['outcome']['wallBound']<=180 and samples[-1]['wallMs']<=180000
            drivers = [json.loads(line.split(' ',1)[1]) for line in text.splitlines() if line.startswith('SOCCER_DRIVER ')]
            c['lastDriverPlans'] = drivers[-10:]
            assert bool(case['provenLocalGoals'])==case['outcome']['local_goal']
        row['cases'].append(c)
    assert summary['ownedProcessesReaped'] and summary.get('privateTempRemoved')
    row['artifacts'] = {str(p.relative_to(folder)):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(folder.rglob('*')) if p.is_file()}
    report['runs'].append(row)
assert report['scoringAttempts']<=2
report['auditorSHA256'] = hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'runs':len(report['runs']),'attempts':report['scoringAttempts'],'localGoals':report['localGoals'],'botGoals':report['botGoals'],'localOwnGoals':report['localOwnGoals'],'auditSHA256':hashlib.sha256(args.output.read_bytes()).hexdigest()},indent=2))
