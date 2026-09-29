"""Independent replay of two-plus native seats against passive Room wire evidence."""
import json
import math
import pathlib
import sys

ROLES = ('host','guest','passenger')
PUMA = 'sunscar-0-puma'

def same(left, right):
    if isinstance(left,dict) and isinstance(right,dict):
        return left.keys()==right.keys() and all(same(left[k],right[k]) for k in left)
    if isinstance(left,list) and isinstance(right,list):
        return len(left)==len(right) and all(same(x,y) for x,y in zip(left,right))
    if isinstance(left,(int,float)) and not isinstance(left,bool) and isinstance(right,(int,float)) and not isinstance(right,bool):
        return math.isclose(left,right,rel_tol=1e-12,abs_tol=1e-12)
    return left==right

def records(text, name):
    prefix='CREW_'+name+' '
    return [json.loads(line[len(prefix):]) for line in text.splitlines() if line.startswith(prefix)]

def verify(logs, wire):
    assert set(logs)==set(ROLES), 'exactly three separately launched native logs required'
    assert wire['classification'].startswith('unmodified Room')
    assert wire['cleanup']=={'serverClosed':True,'sockets':0}, 'owned server/socket cleanup failed'
    connected=wire['connections']
    assert len(connected)==3, 'third native passenger required for source seat order'
    assert len({c['peerId'] for c in connected})==len({c['actorId'] for c in connected})==3
    assert [c['actorId'] for c in connected]==[0,1,2], 'native client seating order not source driver/gunner/passenger'
    assert [c['commands'][0]['type'] for c in connected]==['create','join','join']
    assert connected[0]['commands'][1]['type']=='host'
    assert connected[0]['commands'][1]['mode']=='combined-arms' and connected[0]['commands'][1]['botCount']==0
    room=connected[0]['roomId']
    assert room and all(c['roomId']==room for c in connected)
    assert all(c['commands'][0]['roomId']==room for c in connected[1:])
    starts=wire['starts']
    assert len(starts)==3 and {s['connection'] for s in starts}=={1,2,3}
    assert all(s['mapId']=='sunscar-convoy' and s['mode']=='combined-arms' and s['botCount']==0 for s in starts)

    wire_inputs={c['connection']:{} for c in connected}
    for row in wire['inputs']:
        entries=wire_inputs[row['connection']]
        assert row['seq'] not in entries, 'duplicate wire sequence'
        entries[row['seq']]=row['input']
    snapshots={c['connection']:{} for c in connected}
    for row in wire['snapshots']:
        entries=snapshots[row['connection']]
        assert row['seq'] not in entries, 'duplicate authoritative snapshot sequence'
        entries[row['seq']]=row
    counts={}
    for index,role in enumerate(ROLES,1):
        text=logs[role]
        assert 'SCRIPT ERROR' not in text and 'ERROR:' not in text
        assert not records(text,'FAIL'), role+' emitted a native failure'
        boot=records(text,'BOOT')
        complete=records(text,'COMPLETE')
        assert len(boot)==len(complete)==1, role+' did not complete once'
        assert boot[0]['pid']>0 and complete[0]['seconds']<200
        assert complete[0]['actor_id']==index-1 and complete[0]['source_vehicle']==PUMA
        assert complete[0]['mounted_from_spawn'] is True, role+' did not walk from spawn'
        assert complete[0]['seat']=={'host':'driver','guest':'gunner','passenger':'passenger'}[role]
        queues=records(text,'QUEUE')
        assert len(queues)>10 and all(q['result']==0 for q in queues),role+' insufficient queued controls'
        native_inputs={}
        for q in queues:
            seq=q['input_seq']
            assert seq not in native_inputs,role+' duplicate queue sequence'
            native_inputs[seq]=q['packet']
        assert native_inputs.keys()==wire_inputs[index].keys(),role+' native queue != received wire'
        assert all(same(p,wire_inputs[index][seq]) for seq,p in native_inputs.items()),role+' packet changed in transit'
        native=records(text,'SAMPLE')
        correlated=0; mounted=[]
        for item in native:
            source=snapshots[index].get(item['snapshot_seq'])
            if source is None: continue
            assert source['actorId']==item['actor_id'] and source['ack']==item['ack']
            assert same(source['actor'],item['actor']),role+' actor source mismatch'
            vehicle=next((v for v in source['vehicles'] if v['id']==PUMA),None)
            assert vehicle is not None and same(vehicle,item['source_puma'])
            assert item['render_puma'] and math.dist(item['render_puma'],[vehicle[k] for k in ('x','y','z')])<1e-4,role+' source XYZ != native root'
            assert len(item['camera'])==3 and all(math.isfinite(p) for p in item['camera'])
            if item['vehicle']:
                assert same(item['vehicle'],vehicle)
                assert item['actor']['vehicleId']==vehicle['id']
                assert item['actor']['vehicleSeat']=={'host':'driver','guest':'gunner','passenger':'passenger'}[role]
                if role=='host': assert vehicle['driver']==item['actor_id']
                elif role=='guest': assert vehicle['gunner']==item['actor_id']
                else: assert item['actor_id'] in vehicle['passengers']
                assert math.dist(item['camera'],[vehicle[k] for k in ('x','y','z')])<20,role+' camera detached from source vehicle'
                assert item['hands_visible'] is False and item['muzzle_count']==0,role+' mounted infantry hands/muzzle leaked'
                if role!='host' and item['stage'] in ('gunner-fire','passenger-fire','observe'):
                    eye=[item['actor']['x'],item['actor']['y']+item['actor'].get('eyeHeight',1.45),item['actor']['z']]
                    assert math.dist(item['camera'],eye)<3.0,role+' mounted seat camera detached from source actor eye'
                mounted.append(item)
            correlated+=1
        assert correlated>30 and len(mounted)>8,role+' insufficient exact source/native correlations'
        assert max(s['ack'] for s in native)>=min(native_inputs),role+' no ACK of native input'
        neutral=[q for q in queues if q['stage']=='observe' and q['packet']['x']==0 and q['packet']['z']==0 and not q['packet'].get('fire')]
        assert neutral,role+' no neutral release packet'
        counts[role]={'sourceNativeCorrelations':correlated,'mountedSamples':len(mounted),
                      'wireInputs':len(wire_inputs[index]),'completedSeconds':complete[0]['seconds']}
    # Distinct native clients must co-occupy one actual source hull, not merely
    # take turns in separately created local matches.
    shared=0
    for h in snapshots[1].values():
        v=next((v for v in h['vehicles'] if v['id']==PUMA),None)
        if v and v['driver']==0 and v['gunner']==1 and 2 in v['passengers']: shared+=1
    assert shared>8,'no simultaneous source driver/gunner/passenger hull'
    vehicles=[next(v for v in s['vehicles'] if v['id']==PUMA) for s in snapshots[1].values()]
    origin=vehicles[0]
    distance=max(math.hypot(v['x']-origin['x'],v['z']-origin['z']) for v in vehicles)
    assert distance>9,'driver never moved source hull nine metres'
    assert any(q['input'].get('fire') for q in wire['inputs'] if q['connection']==2),'gunner never sent fire'
    assert any(q['input'].get('fire') for q in wire['inputs'] if q['connection']==3),'passenger never sent fire'
    shot_events={e['id']:e for e in wire['events'] if e['type']=='vehicle-shot' and e.get('actor')==1 and e.get('vehicle')==PUMA}
    assert shot_events,'source mounted gunner never produced vehicle-shot'
    assert all(e.get('barrel') in (0,1) and e.get('from') and e.get('to') and e['from']!=e['to'] for e in shot_events.values())
    assert any(e['type']=='shot' and e.get('actor')==2 for e in wire['events']),'source passenger personal shot missing'
    # The physical Space brake is a single held press, not synthetically
    # repeated. Room effective inputs (observed without mutation at step)
    # must contain exactly one accepted jump edge in this non-race mode.
    host_events=records(logs['host'],'INPUT')
    assert sum(e.get('physical_keycode')==32 and e.get('pressed') is True for e in host_events)==1,'held Space was synthesized twice'
    effective=[step.get('inputs',{}).get('0',{}) for step in wire['accepted']]
    assert sum(x.get('jump') is True for x in effective)==1,'Room accepted repeated or absent held-jump edge'
    return {'classification':'three distinct native processes, natural source entry; arranged five-kind oracle separate',
            'native':counts,'sharedCrewSnapshots':shared,'driverDisplacement':distance,
            'gunnerVehicleShots':len(shot_events),'acceptedJumpEdges':1}

if __name__=='__main__':
    root=pathlib.Path(sys.argv[1])
    logs={role:(root/(role+'.log')).read_text() for role in ROLES}
    print(json.dumps(verify(logs,json.loads((root/'wire.json').read_text())),indent=2))
