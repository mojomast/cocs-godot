"""Read-only AF trace validation and float32 reconstruction; never runs an engine."""
import hashlib,json,math,struct,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-snap-compare'))
from prepare import load,sha,write
def f32(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def vector(v):return [f32(x) for x in v]
def add(a,b):return [f32(f32(x)+f32(y)) for x,y in zip(a,b)]
def subtract(a,b):return [f32(f32(x)-f32(y)) for x,y in zip(a,b)]
def main():
    stage=ROOT/'godot/tests/walker_snap_compare/snap-compare-af-01'
    source=load(stage/'source.json');grant=load(stage/'grant.json');receipt=load(stage/'comparison-result.json');supervisor=load(stage/'supervisor-result.json')
    for path,h in source['files'].items():assert sha(stage/path[6:])==h,path
    for path,h in source['hostInputs'].items():assert sha(ROOT/path)==h,path
    for path,h in source['productionDependencies'].items():assert sha(ROOT/path)==h,path
    for r in [receipt,supervisor]:
        assert r['sourceSha256']==sha(stage/'source.json')==grant['sourceSha256']
        assert r['grantSha256']==sha(stage/'grant.json')
        assert r['engineSha256']==grant['engineSha256']
        assert r['failed'] is False and r['comparisonCollected'] is True
        assert r['mode']=='compare-only' and r['group']=='query-compare'
        assert r['nativeStepAdmission'] is False and r['queryAgreementQualified'] is False
    assert supervisor['returnCode']==0 and supervisor['releasedCleanly']
    assert len(supervisor['releaseAudits'])==3 and all(a['measured'] and a['members']==[] for a in supervisor['releaseAudits'])
    assert receipt['controller']=='res://exploration/walker.gd' and receipt['controllerSha256']==source['files'][receipt['controller']]
    assert receipt['engine']['major']==4 and receipt['engine']['minor']==5 and receipt['engine']['patch']==2
    records=receipt['records'];assert len(records)==28
    for index,r in enumerate(records):
        assert r['tick']==index and r['physicsHz']==60 and r['timeScale']==1
        assert abs(r['actualDelta']-1/60)<1e-15
        assert r['input']==([0.,0.] if index<20 else [0.,-1.]) and r['jump'] is False and r['sprint'] is False
        assert r['beforeQueries']==r['afterQueries']
        assert r['actualBodyGlobalTransform']==r['beforeQueries']['bodyTransform']
        assert r['afterOrdinaryStep']['resetCount']==1
        before=r['beforeQueries']['bodyTransform']['origin'];after=r['afterOrdinaryStep']['bodyTransform']['origin']
        assert subtract(after,before)==vector(r['wholeFrameDelta'])
        assert vector(r['wholeFrameDelta'])==vector(r['afterOrdinaryStep']['positionDelta'])
        if index:
            assert r['frame']==records[index-1]['frame']+1
            assert r['beforeQueries']==records[index-1]['afterOrdinaryStep']
    assert [r['tick'] for r in records if r['proofEligible']]==[27]
    event=records[-1];proof=event['readOnlyOriginalProof'];pair=event['comparison']
    short=pair['short32'];full=pair['parentSnap4'];forward=pair['parentForward6']
    assert pair['frame']==event['frame']==29 and pair['bodyUnchanged']
    assert short['from']==full['from'] and forward['from']==proof['raised']
    assert vector(short['from']['origin'])==add(forward['from']['origin'],forward['travel'])
    assert event['queries']=={'oldShort32':short,'modeledParentSnap4':full,'modeledParentForward6':forward}
    assert forward['motion']==forward['travel']==proof['horizontalBudget'] and not forward['hit'] and not forward['contacts']
    for q,count,rays in [(short,32,True),(full,4,True),(forward,6,False)]:
        assert q['bodyRid']==event['bodyRid'] and q['shapeRid']==event['shapeRid']
        assert q['shapeTransform']==event['shapeOffset'] and q['actualShape']==event['actualShape']
        assert q['maxCollisions']==count and q['collideSeparationRay']==rays and q['recoveryAsCollision'] is True
        assert q['margin']==short['margin'] and q['validResult'] is True
        assert q['bodyExceptions']==q['excludeBodies']==q['excludeObjects']==[]
        assert q['collisionMask']==event['collisionMask']==1
    for q in [short,full]:
        assert len(q['contacts'])==1 and q['hit']
        c=q['contacts'][0]
        assert c['colliderRid']==receipt['targetRid']==proof['supportRid'] and c['colliderShape']==c['localShape']==0
        assert c['velocity']==[0.,0.,0.] and c['normal'][1]>math.cos(math.radians(46))
    projected=vector(pair['parentSnapProjectedTravel'])
    assert math.sqrt(sum(x*x for x in full['travel']))>full['margin']
    assert projected==[0.,f32(full['travel'][1]),0.]
    short_endpoint=add(short['from']['origin'],short['travel']);modeled_endpoint=add(full['from']['origin'],projected)
    assert short_endpoint==vector(proof['expectedFinal'])
    delta=subtract(full['travel'],short['travel']);assert delta==vector(event['rawTravelDeltaFullMinusShort'])
    witness=load(HERE.parent/'walker-snap-parity/AE-witness.json')
    assert sha(Path(witness['sourcePath']))==witness['sourceSha256']
    ae=witness['response'];assert short_endpoint==vector(ae['proposal']['expectedFinal'])
    assert modeled_endpoint==vector(ae['after'])
    assert vector(event['beforeQueries']['bodyTransform']['origin'])==vector(ae['before'])
    assert event['wholeFrameDelta']==event['afterOrdinaryStep']['positionDelta']==event['afterOrdinaryStep']['realVelocity']==[0.,0.,0.]
    before=load(HERE/'evidence/before.json');after=load(HERE/'evidence/after.json')
    assert before['sidecars']==after['sidecars'] and before['viewer']==after['viewer'] and before['displays']==after['displays']
    assert before['archives']==after['archives'] and before['productionDependencies']==after['productionDependencies']
    def query_summary(q):
        return {'motion':q['motion'],'maxCollisions':q['maxCollisions'],'travel':q['travel'],'safeFraction':q['safeFraction'],'unsafeFraction':q['unsafeFraction'],'contactCount':len(q['contacts']),
            'normalDegreesFromUp':[math.degrees(math.acos(c['normal'][1]/math.sqrt(sum(x*x for x in c['normal'])))) for c in q['contacts']]}
    analysis={'status':'stage0 comparison collection success; no assisted response executed','records':len(records),'settleFrames':20,'inputResponses':8,'firstFrame':records[0]['frame'],'lastFrame':event['frame'],'eligibleEvents':1,
        'queryBodyStateUnchangedAllRecords':True,'consecutiveClock60HzTimeScale1':True,'baselineWholeFrameEqualsParentDeltaAllRecords':True,
        'sourceSha256':sha(stage/'source.json'),'grantSha256':sha(stage/'grant.json'),'engineSha256':grant['engineSha256'],'rawTraceSha256':sha(stage/'comparison-result.json'),
        'actualBodyBeforeQueries':event['actualBodyGlobalTransform'],'hypotheticalRaised':forward['from'],'hypotheticalEdge':short['from'],
        'short32':query_summary(short),'modeledParentSnap4':query_summary(full),'modeledParentForward6':query_summary(forward),
        'rawTravelDeltaFullMinusShortFloat32':delta,'rawTravelDeltaMicrometers':delta[1]*1e6,
        'shortExpectedEndpointFloat32':short_endpoint,'modeledProjectedFull4EndpointFloat32':modeled_endpoint,
        'historicalAEActualEndpointFloat32':vector(ae['after']),'modeledEndpointMatchesHistoricalAEAtFloat32':True,
        'actualOrdinaryBaselineEndpoint':event['afterOrdinaryStep']['bodyTransform']['origin'],'actualOrdinaryBaselineDelta':event['wholeFrameDelta'],
        'actualOrdinaryBaselineAccounting':event['afterOrdinaryStep'],'liveBodyRid':event['bodyRid'],'liveShapeRid':event['shapeRid'],'targetRid':receipt['targetRid'],'targetShape':receipt['targetShapeIndex'],
        'configuredPhysicsEngineSetting':receipt['configuredPhysicsEngineSetting'],'backendImplementationVerified':False,'internalParentTraceCaptured':False,
        'assistedUpApplications':0,'actualUpliftSupportQualified':False,'queryAgreementQualified':False,'nativeStepAdmission':False,'candidateMapWalksRun':0,
        'preservation':{'sidecarsUnchanged':len(before['sidecars']),'sidecarsDeleted':0,'cleanupPerformed':False,'viewer':after['viewer'],'displaysUnchanged':True,'historicalArchivesUnchanged':True,'all15DependenciesUnchanged':True},
        'limitation':'Matching modeled full4 endpoint to historical AE at float32 is evidence consistent with request-policy mismatch; simultaneous length/contact-limit changes do not isolate a unique cause, and baseline AF is not an actual lifted parent response.'}
    write(HERE/'evidence/analysis.json',analysis)
    print(json.dumps({k:analysis[k] for k in ['records','settleFrames','inputResponses','rawTravelDeltaMicrometers','shortExpectedEndpointFloat32','modeledProjectedFull4EndpointFloat32','actualOrdinaryBaselineEndpoint']},indent=2))
if __name__=='__main__':main()
