"""Read-only AD native trace verification; never launches Godot or edits raw evidence."""
import collections,json,math,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-admission'))
from prepare import sha,write
def angle(normal):
    return math.degrees(math.acos(max(-1,min(1,normal[1]/math.sqrt(sum(v*v for v in normal))))))
def normal(triangle):
    a,b,c=triangle;u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
    return [u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
def main():
    p=ROOT/'godot/tests/walker_admission/admission-AD-01'
    source=json.loads((p/'source.json').read_text());grant=json.loads((p/'grant.json').read_text())
    d=json.loads((p/'inclined-landing-rejections-result.json').read_text())
    supervisor=json.loads((p/'inclined-landing-rejections-supervisor.json').read_text())
    assert supervisor['returnCode']==0 and supervisor['releasedCleanly'] and len(supervisor['releaseAudits'])==3
    assert grant['allowedGroups']==['inclined-landing-rejections'] and grant['phase']=='admission-controls-only-v4'
    assert d['grantReceiptSha256']==sha(p/'grant.json') and d['sourceSha256']==sha(p/'source.json')==grant['sourceSha256']
    for name,h in source['files'].items():assert sha(ROOT/'godot'/name[6:])==h,name
    assert not d['failed'] and d['passed']==d['attempted']==4 and d['failedTrials']==d['unrun']==0
    assert d['baselinePassed']==d['candidatePassed']==4 and not d['nativeStepAdmission'] and not d['productionPromotion']
    records=[];frames_total=settle_total=witness_total=0;numeric_contacts=0;max_error=0;reasons=collections.Counter()
    for row in d['records']:
        spec=row['spec'];assert row['passed'] and len(row['profiles'])==2
        assert spec['radius'] in [.35,.42] and abs(abs(spec['yaw'])-math.pi/4)<1e-8
        assert spec['incline']==47 and spec['goal']==1 and spec['start']==-1
        for profile in row['profiles']:
            assert profile['appliedVerifiedLifts']==0 and profile['stallCount']==120 and profile['inclinedPolicyWitnesses']==120
            assert profile['topShapeIndex']==0 and isinstance(profile['topRid'],int) and profile['topRid']>0
            geometry=profile['geometry'];assert len(geometry)==6
            triangle_angles=[angle(normal(geometry[i:i+3])) for i in [0,3]]
            assert all(abs(a-47)<.00001 for a in triangle_angles)
            assert abs(angle(profile['geometryNormal'])-47)<.00001
            params=profile['parameters'];assert params['walk']==6 and params['sprint']==10 and params['gravity']==20 and params['jump']==6.5
            assert abs(params['margin']-.02)<1e-7 and abs(params['floorAngle']-math.radians(46))<1e-7
            assert abs(params['offset']['origin'][1]-.9)<1e-7
            samples=profile['settle']+profile['frames'];frames_total+=len(profile['frames']);settle_total+=len(profile['settle'])
            assert len(profile['settle'])==20 and profile['settle'][-1]['groundedAfter']
            assert all(b['clock']['frame']==a['clock']['frame']+1 for a,b in zip(samples,samples[1:]))
            for sample in samples:
                assert sample['clock']['physics'] and sample['clock']['hz']==60 and sample['clock']['scale']==1
                assert sample['resetCount']==1 and not sample['candidateFault'] and not sample['sprint'] and not sample['jump']
                assert isinstance(sample['bodyRid'],int) and sample['bodyRid']>0 and isinstance(sample['capsuleRid'],int) and sample['capsuleRid']>0
                assert abs(sample['actualShapeData']['radius']-spec['radius'])<1e-7 and abs(sample['actualShapeData']['height']-1.8)<1e-7
                assert not sample['proposal'].get('accepted',False)
                for collision in sample['collisions']:
                    assert isinstance(collision['colliderShapeIndex'],int) and collision['colliderShapeIndex']==0
                    assert collision['shapeObjectDescription']=='CollisionShape3D'
                    assert isinstance(collision['colliderRid'],int) and collision['colliderRid']>0
                    assert 'shape' not in collision
                    numeric_contacts+=1
            witnessed=[]
            for i,sample in enumerate(profile['frames']):
                assert sample['input']==[0,-1]
                plan=sample['proposal'] if profile['experimental'] else sample['baselineObserver']
                assert not plan['accepted'];reasons[plan['reason']]+=1
                if plan['reason']=='no_bounded_riser':continue
                assert plan['reason']=='no_continuous_flat_landing'
                direction=(math.sin(spec['yaw']),0,math.cos(spec['yaw']))
                contacts=[c for s in plan['stages'] if s['name']=='intent' for c in s['contacts'] if c['collider'].endswith('/InclinedLanding')]
                good=[]
                for c in contacts:
                    nx,_,nz=c['normal'];length=math.hypot(nx,nz)
                    if c['colliderShape']==0 and c['localShape']==0 and 0<c['point'][1]<.25 and -(nx*direction[0]+nz*direction[2])/length>=.98:good.append(c)
                assert good
                # Numeric body RID in the actual response must also identify
                # the same target. Query logs supply path/shape, response supplies RID.
                assert any(c['colliderRid']==profile['topRid'] and c['colliderShapeIndex']==0 for c in sample['collisions'])
                witnessed.extend(good);witness_total+=1
            assert len([s for s in profile['frames'] if (s['proposal'] if profile['experimental'] else s['baselineObserver'])['reason']=='no_continuous_flat_landing'])==120
            records.append({'case':spec['id'],'experimental':profile['experimental'],'inputResponses':len(profile['frames']),'settlingResponses':20,
                'surfaceTriangleAnglesDegrees':triangle_angles,'contactNormalAnglesDegrees':[min(angle(c['normal']) for c in witnessed),max(angle(c['normal']) for c in witnessed)],
                'contactYRange':[min(c['point'][1] for c in witnessed),max(c['point'][1] for c in witnessed)],'firstWitness':witnessed[0],
                'targetRid':profile['topRid'],'targetShapeIndex':0,'bodyRid':samples[-1]['bodyRid'],'capsuleRid':samples[-1]['capsuleRid'],
                'finalPosition':samples[-1]['after'],'stalledResponses':120,'policyWitnesses':120})
        a,b=row['profiles'];assert not a['experimental'] and b['experimental']
        for sequence in ['settle','frames']:
            assert len(a[sequence])==len(b[sequence])
            for x,y in zip(a[sequence],b[sequence]):
                for field in ['before','after','velocity','wholeFrameDelta','parentPositionDelta','parentRealVelocity','input']:
                    error=math.dist(x[field],y[field]);max_error=max(max_error,error);assert error==0,(spec['id'],field,error)
                for field in ['groundedBefore','groundedAfter','resetCount','sprint','jump']:assert x[field]==y[field]
    report={'status':'native inclined rejection PASS only; no positive admission','attemptedPairs':4,'passedPairs':4,'completedProfiles':8,'failed':0,'unrunPairs':0,
        'inputResponses':frames_total,'settlingResponses':settle_total,'qualifiedPolicyWitnesses':witness_total,'numericSlideContactsVerified':numeric_contacts,
        'maximumComparedPairError':max_error,'reasons':dict(reasons),'profiles':records,'nativeStepAdmission':False,'positiveStepGroupsRun':0,'candidateMapWalksRun':0,
        'rawResultSha256':sha(p/'inclined-landing-rejections-result.json'),'sourceSha256':d['sourceSha256'],'scope':'flat-landing policy rejection on real 47-degree geometry; down-sweep floor-angle rejection and applied-step postguard not exercised'}
    write(HERE/'evidence/trace-analysis.json',report)
    print('Verified',frames_total,'input +',settle_total,'settles;',witness_total,'exact policy witnesses;',numeric_contacts,'numeric slide contacts; pairs identical on compared fields')
if __name__=='__main__':main()
