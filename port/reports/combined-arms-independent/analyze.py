#!/usr/bin/env python3
"""Strict offline audit of the independent wire/native pair; no live changes."""
import copy
import hashlib
import json
import math
import pathlib
import struct
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT/'port/native-combined-arms'))
from validate import equivalent, verify

evidence = pathlib.Path(sys.argv[1])
text = (evidence/'native.log').read_text()
wire = json.loads((evidence/'wire.json').read_text())
records = lambda prefix: [json.loads(line[len(prefix):]) for line in text.splitlines() if line.startswith(prefix)]
samples = records('CA_SAMPLE ')
queues = records('CA_QUEUE ')
identities = records('INDEPENDENT_IDENTITY ')
events = records('CA_EVENT ')
stages = records('CA_STAGE ')
server = {s['seq']:s for s in wire['samples']}
inputs = {i['seq']:i for i in wire['inputs']}
native = {s['seq']:s for s in samples}
assert len(server) == len(wire['samples'])
assert len(native) == len(samples) == len(identities)
assert list(server) == sorted(server) and list(native) == sorted(native)
assert list(inputs) == sorted(inputs)
assert len(queues) == len({q['seq'] for q in queues})
assert set(inputs) == {q['seq'] for q in queues}, 'queued/received sequence sets differ'
assert all(equivalent(q['packet'], inputs[q['seq']]['input']) for q in queues)
assert wire['connections'] == wire['starts'] == 1
identity = identities[0]
assert identity['actor'] == 0 and identity['roundRevision'] == 1
context = {k:identity[k] for k in ['room','peer','roundRevision']}
for item in wire['inputs'] + wire['samples']:
    assert all(item[k] == v for k,v in context.items())
    assert item['actorId'] == identity['actor'] and item['connection'] == 1
for item in identities:
    assert all(item[k] == v for k,v in context.items())
    assert item['actor'] == identity['actor'] and item['seq'] in server
for s in samples:
    src = server[s['seq']]
    assert src['actorCount'] == 1
    assert src['ack'] == s['ack'] and equivalent(src['actor'],s['actor'])
    assert len(src['vehicles']) == len(s['render']) == 10
    for v in src['vehicles']:
        assert math.dist(s['render'][v['id']], [v[k] for k in ['x','y','z']]) < 0.0001
    if s['vehicle']:
        v = next(v for v in src['vehicles'] if v['id'] == s['vehicle']['id'])
        assert equivalent(s['vehicle'],v)
        assert s['actor']['vehicleId'] == v['id'] == 'sunscar-0-puma'
        assert s['actor']['vehicleSeat'] == 'driver' and v['driver'] == identity['actor']

position = lambda a: {k:a[k] for k in ['x','y','z']}
vehicle = lambda s: next(v for v in s['vehicles'] if v['id'] == 'sunscar-0-puma')
speed = lambda v: math.hypot(v['vx'],v['vz'])
neutral = lambda p: p['x'] == p['z'] == 0 and not any(p.get(k) for k in ['fire','jump','sprint','interact','reload','crouch','power'])
report = {'status':'PASS', 'deliveredReplay':verify(text,wire), 'recipient':context,
          'actor':identity['actor'],'connections':wire['connections'],
          'allQueuedPacketsReceivedExactly':len(queues), 'allNativeSamplesCorrelated':len(samples),
          'sourceSamples':len(server), 'rootComparisons':len(samples)*10}
report['stages'] = []
for stage in dict.fromkeys(s['stage'] for s in samples):
    subset = [s for s in samples if s['stage'] == stage]
    row = {'stage':stage,'first':{},'last':{}}
    for label,s in [('first',subset[0]),('last',subset[-1])]:
        row[label] = {'snapshotSeq':s['seq'],'ack':s['ack'],'actorXYZ':position(s['actor']),
                      'vehicleXYZ':position(s['vehicle']) if s['vehicle'] else None,
                      'speed':speed(s['vehicle']) if s['vehicle'] else None,'engaged':s['engaged']}
    report['stages'].append(row)

presses = [q for q in queues if q['packet']['interact']]
assert len(presses) == 2
report['interactions'] = []
for index,request in enumerate(presses):
    seq = request['seq']
    before = [s for s in wire['samples'] if s['ack'] < seq][-1]
    acked = next(s for s in wire['samples'] if s['ack'] >= seq)
    if index == 0:
        assert before['actor']['vehicleId'] is None and vehicle(before)['driver'] is None
        assert acked['actor']['vehicleId'] == 'sunscar-0-puma' and vehicle(acked)['driver'] == 0
    else:
        assert before['actor']['vehicleId'] == 'sunscar-0-puma' and vehicle(before)['driver'] == 0
        assert acked['actor']['vehicleId'] is None and acked['actor']['vehicleSeat'] is None
        assert vehicle(acked)['driver'] is None
    first_native = next(s for s in samples if s['ack'] >= seq)
    assert not first_native['engaged'], 'seat change did not release controls'
    report['interactions'].append({'action':['mount','exit'][index], 'queuedSeq':seq,
        'received':inputs[seq], 'lastPreACKSnapshot':before['seq'], 'firstACKSnapshot':acked['seq'],
        'firstACK':acked['ack'],'beforeActorXYZ':position(before['actor']),
        'afterActorXYZ':position(acked['actor']),'afterVehicleXYZ':position(vehicle(acked)),
        'afterVehicleDriver':vehicle(acked)['driver'],'nativeBoundaryReleased':True})
assert [e['event']['type'] for e in wire['events']] == ['vehicle-enter','vehicle-exit']
report['sourceVehicleEvents'] = wire['events']

brake = [q for q in queues if q['packet']['jump']]
assert brake and all(q['stage'] == 'brake' for q in brake)
jump_edges = sum(i['input']['jump'] and (n == 0 or not wire['inputs'][n-1]['input']['jump']) for n,i in enumerate(wire['inputs']))
assert jump_edges == 1
release = next(q for q in queues if q['seq'] > brake[-1]['seq'] and not q['packet']['jump'])
assert any(s['ack'] >= release['seq'] for s in samples)
brake_samples = [s for s in samples if s['stage']=='brake']
report['brake'] = {'jumpTrueSequences':[q['seq'] for q in brake],
    'sourceRoomJumpRisingEdges':jump_edges,'firstFalseReleaseSeq':release['seq'],
    'firstReleaseACKSnapshot':next(s['seq'] for s in samples if s['ack']>=release['seq']),
    'firstSpeed':speed(brake_samples[0]['vehicle']),'lastSpeed':speed(brake_samples[-1]['vehicle']),
    'qualification':'Space rising-edge brake TAP with S deceleration; not isolated brake physics'}
report['neutralBoundaries'] = {}
for stage in ['released','exit-neutral','final-release']:
    subset = [s for s in samples if s['stage']==stage]
    settled = [s for s in subset if s['seconds'] >= subset[0]['seconds']+0.2]
    assert settled and all(not s['engaged'] and neutral(inputs[s['ack']]['input']) for s in settled)
    report['neutralBoundaries'][stage] = {'ACKNeutralSamples':len(settled),
        'actorXZDisplacement':math.dist([subset[0]['actor'][k] for k in ['x','z']], [subset[-1]['actor'][k] for k in ['x','z']])}

# Verify ordinary key chronology: exit -> W without Enter remains released;
# then W-up, fresh Enter down/up, fresh W down -> authoritative infantry movement.
stage_time = {s['stage']:s['seconds'] for s in stages}
key_events = lambda start,end: [e for e in events if start <= e['seconds'] < end]
mounted_events = key_events(stage_time['mounted'],stage_time['drive'])
assert any(e['key']==4194309 and e['pressed'] for e in mounted_events)
assert any(e['key']==4194309 and not e['pressed'] for e in mounted_events)
mounted_packets = [q for q in queues if q['stage']=='mounted']
assert mounted_packets and all(neutral(q['packet']) for q in mounted_packets)
report['mountFreshEnter'] = {'keyEvents':mounted_events,
    'neutralQueuedPacketsBeforeFreshDriveW':len(mounted_packets)}
held_only = key_events(stage_time['exit-neutral'],stage_time['infantry-fresh'])
assert any(e['key']==87 and e['pressed'] for e in held_only)
assert not any(e['key']==4194309 and e['pressed'] for e in held_only)
fresh = key_events(stage_time['infantry-fresh'],stage_time['final-release'])
enter_down = next(i for i,e in enumerate(fresh) if e['key']==4194309 and e['pressed'])
enter_up = next(i for i,e in enumerate(fresh) if e['key']==4194309 and not e['pressed'])
walk_down = next(i for i,e in enumerate(fresh) if e['key']==87 and e['pressed'])
assert enter_down < enter_up < walk_down
assert report['neutralBoundaries']['exit-neutral']['actorXZDisplacement'] == 0
report['freshInfantryKeyEvents'] = fresh

# Reproduce one concrete delivered-validator weakness on an in-memory copy only.
removed = next(q for q in queues if q['stage']=='drive' and q['packet']['x'] != 0)
mutant = copy.deepcopy(wire)
mutant['inputs'] = [i for i in mutant['inputs'] if i['seq'] != removed['seq']]
verify(text,mutant)
report['unappliedFinding'] = {'file':'port/native-combined-arms/validate.py:18-20',
    'description':'Delivered verifier accepts removal of a driving packet receipt',
    'removedInputSeq':removed['seq'],'mutatedCopyOnly':True,'deliveredVerifierIncorrectlyAccepted':True,
    'strictIndependentCheckRejects':set(i['seq'] for i in mutant['inputs']) != {q['seq'] for q in queues}}
report['pngs'] = {}
for p in sorted(evidence.glob('*.png')):
    data=p.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    report['pngs'][p.name] = {'dimensions':list(struct.unpack('>II',data[16:24])),
        'sha256':hashlib.sha256(data).hexdigest()}
assert report['pngs']['mounted-960.png']['dimensions'] == [960,640]
assert report['pngs']['released-1280.png']['dimensions'] == [1280,800]
(evidence/'independent-analysis.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
