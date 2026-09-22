"""Validation of compact genuine driving observations (never generates evidence)."""
import json
import math

def verify(map_id, text, wire):
    samples=[json.loads(l.split(' ',1)[1]) for l in text.splitlines() if l.startswith('SPORT_SAMPLE ')]
    assert len(samples)>20 and wire['starts']==1
    assert {'countdown' if map_id=='ion-speedway' else 'kickoff', 'racing' if map_id=='ion-speedway' else 'playing'} <= {s['phase'] for s in samples}
    initial=samples[0]['v']
    distance=max(math.hypot(s['v']['x']-initial['x'],s['v']['z']-initial['z']) for s in samples)
    turning=max(abs(math.atan2(math.sin(s['v']['yaw']-initial['yaw']),math.cos(s['v']['yaw']-initial['yaw']))) for s in samples)
    assert distance>1 and turning>0.05, (distance,turning)
    assert all(max(abs(s['render'][i]-s['v'][k]) for i,k in enumerate(['x','y','z']))<0.0001 for s in samples)
    assert all(not s['engaged'] for s in samples if s['stage'] in [4,6,7,10])
    assert all(s['engaged'] for s in samples if s['stage'] in [0,1,5,8])
    received={s['seq']:s for s in wire['samples']}
    correlated=[s for s in samples if s['seq'] in received]
    assert len(correlated)>=5
    for s in correlated:
        other=received[s['seq']]
        assert s['actor']==other['actor'] and s['v']['id']==other['vehicle']['id']
        for key in ['x','y','z','yaw','vx','vz','driver','health']:
            assert s['v'][key]==other['vehicle'][key], (key,s['seq'])
    inputs=wire['inputs']; byseq={i['seq']:i['input'] for i in inputs}
    assert len(byseq)==len(inputs) and list(byseq)==sorted(byseq)
    assert any(i['input'].get('jump') for i in inputs)
    assert any(i['input'].get('sprint') for i in inputs)
    assert any(i['input'].get('interact') for i in inputs)
    assert any((-i['input']['x']*math.sin(i['input']['yaw'])-i['input']['z']*math.cos(i['input']['yaw']))<-.9 for i in inputs)
    reverse=[s['v']['vx']*math.sin(s['v']['yaw'])+s['v']['vz']*math.cos(s['v']['yaw']) for s in samples if s['stage']==3]
    assert min(reverse)<-1
    neutral_checks=0
    for index,s in enumerate(samples):
        if s['stage'] in [4,6,7,10] and s['ack'] in byseq:
            # Exclude first sample of each stage: packets can be in flight.
            if index==0 or samples[index-1]['stage']!=s['stage']: continue
            p=byseq[s['ack']]
            assert abs(p['x'])<1e-6 and abs(p['z'])<1e-6 and not p['jump'] and not p['sprint']
            neutral_checks+=1
    assert neutral_checks>8
    if map_id=='aurora-stadium': assert all(s['ball'] is not None for s in samples)
    reset=False
    if map_id=='ion-speedway':
        before=[s for s in samples if s['stage']==8][-1]['v']
        after=[s for s in samples if s['stage']==9][0]['v']
        reset=math.hypot(after['x']-before['x'],after['z']-before['z'])>2
        assert reset, 'expected source race reset displacement'
    assert wire['cleanup']=={'serverClosed':True,'sockets':0}
    return {'map':map_id,'status':'PASS','snapshots':len(samples),'serverSnapshotCorrelations':len(correlated),'inputReceipts':len(inputs),'ackHighWater':max(s['ack'] for s in samples),'maxDisplacement':distance,'maxHeadingChange':turning,'renderMatches':True,'neutralAckSamples':neutral_checks,'minimumReverseSpeed':min(reverse),'raceResetObserved':reset,'nativeCompletionProven':False}

if __name__=='__main__':
    import pathlib,sys
    p=pathlib.Path(sys.argv[1])
    results=[verify(m,(p/(m+'.log')).read_text(),json.loads((p/(m+'-wire.json')).read_text())) for m in ['ion-speedway','aurora-stadium']]
    print(json.dumps(results,indent=2))
