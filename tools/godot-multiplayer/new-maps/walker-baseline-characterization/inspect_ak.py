"""Offline frozen-AK comparison. No engine, staging, fixture or runtime edits."""
import csv,hashlib,io,json,math,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
AK=ROOT.parent/'cocs-walker-parity-admission-ak'
STAGE=AK/'godot/tests/walker_parity_admission/parity-admission-ak-01'
MANIFEST='827dd68b00c400b7ec17f9ab0e5a2067929277c3bb22e1681d38a1d5143a5ee1'
NATIVE='76130effe1da05bfc800fa8e14bea5b0382b87b130899a3cc1b52e2dab9bb6d7'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text())
def angle(n):return math.degrees(math.acos(max(-1,min(1,n[1]))))
def verify():
    path=AK/'tools/godot-multiplayer/new-maps/walker-parity-admission-ak/evidence/artifact-inventory.json'
    assert sha(path)==MANIFEST;rows=load(path)['files'];assert len(rows)==51
    for n,r in rows.items():assert sha(AK/n)==r['sha256'] and (AK/n).stat().st_size==r['bytes'],n
    assert sha(STAGE/'positive-step-admission-result.json')==NATIVE
    source=load(STAGE/'source.json')
    for n,h in source['files'].items():
        p=STAGE/n.removeprefix('res://');assert sha(p)==h
        if n.endswith('.gd'):assert p.read_bytes()==(ROOT/'godot'/n.removeprefix('res://')).read_bytes(),n
    return source
def inspect():
    source=verify();r=load(STAGE/'positive-step-admission-result.json');profiles=[];chart=[]
    for case in r['records']:
        spec=case['spec'];yaw=spec['yaw']
        for role,p in enumerate(case['profiles']):
            threshold=math.degrees(p['parameters']['floorAngle']);rows=[];angles=[];faults=[];ups=[]
            sequence=p['settle']+p['frames']
            for i,row in enumerate(sequence):
                assert row['returned'] and row['physicsHz']==60 and row['timeScale']==1 and abs(row['actualDelta']-1/60)<1e-8
                assert row['after']['resetCount']==1 and not row['jump'] and not row['sprint']
                if i:assert row['frame']==sequence[i-1]['frame']+1
                if not role:assert row['afterQueries']==row['before']
                else:
                    assert row['lifecycle']['parentCalls']==1 and row['appliedUpCount'] in [0,1]
                    if row['appliedUpCount']:ups.append(row['frame']);assert row['responseGuardPassed']
                if row['candidateFault']:faults.append(row['candidateFault'])
            for index,row in enumerate(p['frames']):
                assert row['input']==[0.,-1.]
                a=row['after'];pos=a['transform']['origin'];contacts=[c for c in row['slides'] if c['colliderRid']==p['targetRid']]
                actual_angles=[angle(c['normal']) for c in contacts];angles+=actual_angles
                intents=[angle(c['normal']) for stage in row['proposal']['stages'] if stage['name']=='intent' for c in stage['contacts'] if c['collider']==p['target']['path']]
                data={'caseIndex':case['caseIndex'],'role':'candidate' if role else 'baseline','radius':spec['radius'],'yawDegrees':round(math.degrees(yaw)), 'inputIndex':index,'frame':row['frame'],'delta':row['actualDelta'],'along':math.sin(yaw)*pos[0]+math.cos(yaw)*pos[2],'y':pos[1],'dy':row['wholeFrameDelta'][1],'velocity':a['velocity'],'parentDelta':a['parentPositionDelta'],'parentRealVelocity':a['parentRealVelocity'],'lastMotion':a['lastMotion'],'grounded':a['grounded'],'onWall':a['onWall'],'floorNormal':a['floorNormal'],'targetContactAngles':actual_angles,'intentQueryTargetAngles':intents,'targetContactsStrict46Compatible':sum(x<=threshold for x in actual_angles),'targetContactsEngineAngleCompatible':sum(x<=threshold+math.degrees(.01) for x in actual_angles),'proposalAccepted':row['proposal']['accepted'],'proposalReason':row['proposal']['reason'],'applied':row.get('appliedUpCount',0),'ordinary':not role or row['lifecycle']['ordinary']}
                rows.append(data);chart.append(data)
            first=next((x for x in rows if x['targetContactAngles']),None)
            profiles.append({'caseIndex':case['caseIndex'],'role':role,'spec':spec,'parameters':p['parameters'],'inputResponses':len(rows),'settlingResponses':len(p['settle']),'thresholdDegrees':threshold,'engineAngleThresholdDegrees':threshold+math.degrees(.01),'firstTargetSlide':first,'targetSlideAngleMin':min(angles) if angles else None,'targetSlideAngleMax':max(angles) if angles else None,'last':rows[-1],'positiveYFrames':[x['frame'] for x in rows if x['dy']>1e-6],'appliedFrames':ups,'faults':faults,'appliedUpCount':p['appliedUpCount'],'verifiedLifts':p['verifiedLifts'],'stallCount':p['stallCount'],'landingStreak':p['ordinaryLandingStreak'],'reached':p['reached'],'status':p['status'],'tailSevenOrdinaryGrounded':all(x['ordinary'] and x['grounded'] for x in rows[-7:])})
    return {'qualification':'Frozen native arrays; angles/along are offline reconstruction. No engine internal branch trace.','AKManifestSha256':MANIFEST,'nativeSha256':NATIVE,'sourceSha256':sha(STAGE/'source.json'),'sourceFiles':source['files'],'outcome':r['outcome'],'radius042Plus45':'UNRUN; no symmetry inference','profiles':profiles,'heuristic':{'formula':'h_critical = bottom_clearance + radius*(1-cos(theta)); ideal sphere-edge contact, no margin/recovery model','bottomClearance':.0166666638106108,'nominal46':{str(rad):.0166666638106108+rad*(1-math.cos(math.radians(46))) for rad in [.35,.42]},'engine46Plus001Rad':{str(rad):.0166666638106108+rad*(1-math.cos(math.radians(46)+.01)) for rad in [.35,.42]},'proposedHeights':[.15,.18,.20],'strictPlannerRiseUpperBound':.25-.0001}},chart
def chart_csv(rows):
    stream=io.StringIO();writer=csv.DictWriter(stream,fieldnames=list(rows[0]),lineterminator='\n');writer.writeheader()
    for row in rows:writer.writerow({k:json.dumps(v,separators=(',',':')) if isinstance(v,(list,dict)) else v for k,v in row.items()})
    return stream.getvalue()
if __name__=='__main__':
    result,chart=inspect()
    if sys.argv[1:]==['--write']:
        with (HERE/'comparison.json').open('x') as f:json.dump(result,f,indent=2);f.write('\n')
        with (HERE/'frames.csv').open('x') as f:f.write(chart_csv(chart))
    else:print(json.dumps(result,indent=2))
