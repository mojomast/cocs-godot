"""Replay source receipt, ACK, driver relation and XYZ roots independently."""
import json, math, pathlib, sys
def equivalent(a, b):
    if isinstance(a, dict) and isinstance(b, dict): return a.keys()==b.keys() and all(equivalent(a[k],b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list): return len(a)==len(b) and all(equivalent(x,y) for x,y in zip(a,b))
    if isinstance(a, (int,float)) and not isinstance(a,bool) and isinstance(b,(int,float)) and not isinstance(b,bool): return math.isclose(a,b,rel_tol=1e-12,abs_tol=1e-12)
    return a==b
def verify(text, wire):
    def records(prefix): return [json.loads(line[len(prefix):]) for line in text.splitlines() if line.startswith(prefix)]
    samples=records('CA_SAMPLE '); queued=records('CA_QUEUE '); complete=records('CA_COMPLETE ')
    assert complete and complete[-1]['seconds'] < 120, 'missing bounded native completion'
    assert wire['mapId']=='sunscar-convoy' and wire['config']['mode']=='combined-arms' and wire['config']['botCount']==0
    assert wire['starts']==1 and wire['cleanup']=={'serverClosed':True,'sockets':0}
    inputs={i['seq']:i['input'] for i in wire['inputs']}
    assert len(inputs)==len(wire['inputs']), 'duplicate input sequence'
    server={s['seq']:s for s in wire['samples']}
    correlations=0
    for q in queued:
        assert q['result']==0, 'queue failure'
        if q['seq'] in inputs: assert equivalent(inputs[q['seq']],q['packet']), 'queue/receipt mismatch'
    for s in samples:
        if s['seq'] not in server: continue
        src=server[s['seq']]
        assert equivalent(s['actor'],src['actor']), 'recipient actor mismatch'
        assert s['ack']==src['ack'], 'ACK mismatch'
        for v in src['vehicles']:
            assert v['id'] in s['render'], 'missing native vehicle root'
            assert math.dist(s['render'][v['id']],[v[k] for k in ['x','y','z']]) < 0.0001, 'source XYZ/root mismatch'
        if s['vehicle']:
            v=next(v for v in src['vehicles'] if v['id']==s['vehicle']['id'])
            assert equivalent(v,s['vehicle']) and v['driver']==s['actor_id']==src['actor']['id']==0
            assert src['actor']['vehicleId']==v['id'] and src['actor']['vehicleSeat']=='driver'
        correlations+=1
    assert correlations>=20, 'insufficient exact snapshot correlations'
    mounted=[s for s in samples if s['vehicle']]
    assert mounted and all(s['vehicle']['id']=='sunscar-0-puma' for s in mounted)
    origin=mounted[0]['vehicle']
    displacement=max(math.hypot(s['vehicle']['x']-origin['x'],s['vehicle']['z']-origin['z']) for s in mounted)
    assert displacement>=10, 'vehicle did not move 10 metres'
    walk=[s for s in samples if s['stage']=='walk']
    assert len(walk)>2 and math.dist([walk[0]['actor'][k] for k in ['x','z']],[walk[-1]['actor'][k] for k in ['x','z']])>3
    presses=[q for q in queued if q['packet']['interact']]
    assert len(presses)==2, 'interact must be one mount and one exit only'
    for p in presses:
        assert inputs.get(p['seq'],{}).get('interact'), 'no interact receipt'
        assert any(s['ack']>=p['seq'] for s in samples), 'interact never ACKed'
    assert any(s['vehicle'] and s['ack']>=presses[0]['seq'] for s in samples), 'mount ACK without driver application'
    assert any(s['actor'].get('vehicleId') is None and s['ack']>=presses[1]['seq'] for s in samples), 'exit ACK without applied dismount'
    brake=[q for q in queued if q['stage']=='brake' and q['packet']['jump']]
    assert brake, 'missing brake tap'
    assert all(inputs.get(q['seq'],{}).get('jump') for q in brake), 'brake queue without receipt'
    assert any(s['ack']>=brake[-1]['seq'] for s in samples), 'brake request never ACKed'
    speeds=[math.hypot(s['vehicle']['vx'],s['vehicle']['vz']) for s in samples if s['stage']=='brake' and s['vehicle']]
    assert speeds and max(speeds)>5 and min(speeds)<1, 'source vehicle did not slow under brake/reverse commands'
    neutral=0
    for stage in ['released','exit-neutral','final-release']:
        stages=[s for s in samples if s['stage']==stage]
        assert stages, 'missing release stage'
        boundary=stages[0]['seconds']+0.2
        for s in stages:
            if s['seconds']<boundary: continue
            p=inputs.get(s['ack'])
            assert p is not None and p['x']==p['z']==0 and not any(p.get(k) for k in ['fire','jump','sprint','interact']), 'ACKed release not neutral'
            assert not s['engaged']
            neutral+=1
    fresh=[s for s in samples if s['stage']=='infantry-fresh']
    assert fresh and all(not s['vehicle'] for s in fresh)
    moved=math.dist([fresh[0]['actor'][k] for k in ['x','z']],[fresh[-1]['actor'][k] for k in ['x','z']])
    assert moved>=2.5, 'no fresh infantry motion'
    assert neutral>=6
    return {'exactSnapshotCorrelations':correlations,'receivedInputs':len(inputs),'queuedInputs':len(queued),'interactReceipts':len(presses),'maxVehicleDisplacementMetres':displacement,'freshInfantryMetres':moved,'ACKNeutralSamples':neutral,'seconds':complete[-1]['seconds']}
if __name__=='__main__':
    root=pathlib.Path(sys.argv[1]); print(json.dumps(verify((root/'native.log').read_text(),json.loads((root/'wire.json').read_text())),indent=2))
