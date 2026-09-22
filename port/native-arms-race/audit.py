#!/usr/bin/env python3
"""Offline audit of retained evidence. Never launches or changes gameplay."""
import gzip
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def read(path):
    return path.read_text() if path.exists() else gzip.open(str(path)+'.gz','rt').read()

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

records = []
for directory in sorted((ROOT/'evidence').iterdir()):
    if not directory.is_dir() or not (directory/'summary.json').exists():
        continue
    summary = json.loads((directory/'summary.json').read_text())
    record = {'id':directory.name,'status':summary['status'],'options':summary['options'],'error':summary.get('error'),'cases':[]}
    for case in sorted(directory.iterdir()):
        if not case.is_dir() or not ((case/'wire.json').exists() or (case/'wire.json.gz').exists()):
            continue
        wire = json.loads(read(case/'wire.json'))
        native = read(case/'native.log')
        traces = [json.loads(s.split(' ',1)[1]) for s in native.splitlines() if s.startswith('PORT_NATIVE_TRACE ')]
        queued = [t for t in traces if t.get('event')=='input_queue' and t['queued']]
        captures = [json.loads(s.split(' ',1)[1]) for s in native.splitlines() if s.startswith('ARMS_CAPTURE ')]
        ended = [json.loads(s.split(' ',1)[1]) for s in native.splitlines() if s.startswith('ARMS_ENDED ')]
        report = {'map':case.name,'starts':wire['starts'],'queuedRecords':len(queued),'serverReceipts':len(wire['inputs']), 'appliedACKMax':max((s.get('ack',0) or 0 for s in wire['samples']),default=0),'sourceSamples':len(wire['samples']),'captures':captures,'end':ended,'cleanup':wire['cleanup'],'promotions':[]}
        require(wire['cleanup']=={'serverClosed':True,'sockets':0},'Unclean server '+str(case))
        if wire['samples']:
            actor = wire['samples'][0]['actor']
            require(all('weapon' not in i['input'] for i in wire['inputs']), 'Weapon selection escaped lock')
            require(all(len(s['state']['actors'])==3 and sum(a['bot'] for a in s['state']['actors'])==2 for s in wire['samples']), 'Ordinary bot roster changed')
            for event in wire['events']:
                if event['type']!='armsrace-promote' or event['actor']!=actor: continue
                before = [s for s in wire['samples'] if s['round']==event['round'] and s['state']['time']<event['time']]
                after = [s for s in wire['samples'] if s['round']==event['round'] and s['state']['time']>=event['time']]
                require(before and after,'Promotion snapshot bracket missing')
                low, high = before[-1], after[0]
                a = next(a for a in low['state']['actors'] if a['id']==actor)
                b = next(a for a in high['state']['actors'] if a['id']==actor)
                deaths = [e for e in wire['events'] if e['type']=='death' and e.get('killer')==actor and not e.get('self') and e['time']==event['time']]
                require(deaths and b['frags']==a['frags']+1 and b['ladder']>a['ladder'] and b['weapon']==event['weapon'],'Local kill/promotion not proved')
                display = next((c for c in captures if c['tag']=='promotion' and c['display']['seq']>=high['seq']),None)
                require(display and 'PROMOTED' in display['display']['transition'],'Native promotion display missing')
                require(any(i['input'].get('fire') and i['seq']<=high['ack'] for i in wire['inputs'] if i['round']==event['round']), 'No applied fire input')
                report['promotions'].append({'event':event,'death':deaths[0],'before':{'seq':low['seq'],'actor':a},'after':{'seq':high['seq'],'ack':high['ack'],'actor':b},'display':display})
        record['cases'].append(report)
    records.append(record)
result = {'runs':records,'liveCombatRuns':sum(bool(r['options']['attempt']) and any(c['starts'] for c in r['cases']) for r in records),'interpretation':'Queued records, server receipt and applied ACK are separate. Kill/promotion requires source death + snapshot change + native HUD capture. Failed runs retain their original FAIL status.'}
require(result['liveCombatRuns']<=2,'Exceeded two live combat attempts')
(ROOT/'AUDIT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'liveCombatRuns':result['liveCombatRuns'],'runs':len(records),'output':str(ROOT/'AUDIT.json')},indent=2))
