"""Post-exit AG trace validation. No native invocation or controller mutation."""
import math,struct,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-parity-response'))
from prepare import load,sha,write
from supervisor import successful_response
def f32(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def vec(v):return [f32(x) for x in v]
def sub(a,b):return [f32(f32(x)-f32(y)) for x,y in zip(a,b)]
def add(a,b):return [f32(f32(x)+f32(y)) for x,y in zip(a,b)]
def length(v):return math.sqrt(sum(x*x for x in v))
def main():
    stage=ROOT/'godot/tests/walker_parity_response/parity-response-ag-01'
    source=load(stage/'source.json');grant=load(stage/'grant.json');native=load(stage/'response-result.json');supervisor=load(stage/'supervisor-result.json')
    for name,h in source['files'].items():assert sha(stage/name[6:])==h,name
    for name,h in {**source['productionDependencies'],**source['hostInputs']}.items():assert sha(ROOT/name)==h,name
    assert len([p for p in source['files'] if p.endswith('.gd')])==13
    for r in [native,supervisor]:
        assert r['sourceSha256']==sha(stage/'source.json')==grant['sourceSha256']
        assert r['grantSha256']==sha(stage/'grant.json') and r['engineSha256']==grant['engineSha256']
        assert r['failed'] is False and r['positiveAdmission'] is False and r['nativeStepAdmission'] is False
    assert successful_response(native,sha(stage/'source.json'),sha(stage/'grant.json'),grant['engineSha256'])
    assert supervisor['returnCode']==0 and supervisor['releasedCleanly']
    assert len(supervisor['releaseAudits'])==3 and all(a['measured'] and a['members']==[] for a in supervisor['releaseAudits'])
    log=(stage/'supervisor.log').read_text();assert 'v4.5.2.stable.official.6ce3de25a' in log and 'ERROR' not in log and len(log.splitlines())==2
    records=native['records'];assert len(records)==28
    for i,r in enumerate(records):
        assert r['tick']==i and r['frame']==i+2 and r['physicsHz']==60 and r['timeScale']==1 and abs(r['actualDelta']-1/60)<1e-15
        assert r['input']==([0.,0.] if i<20 else [0.,-1.]) and not r['sprint'] and not r['jump']
        assert r['beforeOriginalProof']==r['afterOriginalProof']
        assert r['originalProof']['accepted']==(i==27)
        after=r['afterCandidate'] if i==27 else r['afterOrdinaryStep']
        assert after['resetCount']==1
        assert sub(after['transform']['origin'],r['beforeOriginalProof']['transform']['origin'])==vec(r['wholeFrameDelta'])
        if i<27:assert vec(r['wholeFrameDelta'])==vec(after['parentPositionDelta'])
        if i<27:assert records[i+1]['beforeOriginalProof']==after
    event=records[-1];p=event['parityProposal'];t=event['candidateTelemetry'];guard=p['responseGuard'];pair=p['queryParity']
    assert p['accepted'] and event['candidateFault']==''
    assert native['candidateAttempts']==native['appliedUpCount']==native['parentResponseCount']==1
    assert native['candidateResponseCollected'] and native['responseGuardPassed'] and native['candidateMapWalks']==0
    assert t['frame']==pair['frame']==event['frame']==29
    assert t['beforePlanning']==t['afterPlanning']==event['afterOriginalProof']==t['upRequest']['before']
    assert t['upAfter']==t['beforeParent'] and t['afterParent']==t['afterGuard']==event['afterCandidate']
    assert not t['upCollisionReturned'] and not t['upContacts']
    assert t['upRequest']['testOnly'] is False and t['upRequest']['maxCollisions']==32 and t['upRequest']['motion']==p['upMotion']
    assert sub(t['upAfter']['transform']['origin'],t['upRequest']['from']['origin'])==vec(t['actualUpTravel'])
    raised_error=sub(t['upAfter']['transform']['origin'],p['raised']['origin']);assert raised_error==[0.,0.,0.]
    actual=vec(guard['actualFinal']);expected=vec(guard['expectedFinal']);error=sub(actual,expected)
    assert error==[0.,0.,0.] and guard['epsilon']==1e-6 and guard['passed']
    assert guard['reason']=='endpoint_and_pinned_clear_branch_and_live_support_agree'
    assert not guard['observedSlides'] and guard['slideCount']==0 and not event['slides']
    forward_error=sub(guard['lastMotion'],p['horizontalBudget']);assert length(forward_error)<guard['epsilon']
    for key,count,rays in [('short32',32,True),('parentSnap4',4,True),('parentForward6',6,False)]:
        q=pair[key];assert q['maxCollisions']==count and q['recoveryAsCollision'] and q['collideSeparationRay']==rays and q['validResult']
        assert q['bodyRid']==native['bodyRid'] and q['shapeRid']==native['shapeRid'] and q['actualShape']==native['actualShape'] and q['shapeTransform']==native['shapeOffset']
    short=pair['short32'];full=pair['parentSnap4'];forward=pair['parentForward6']
    assert short['from']==full['from'] and forward['from']==p['raised']
    assert forward['motion']==forward['travel'] and not forward['hit'] and not forward['contacts']
    assert pair['cancellationWrapperExecuted'] is False and not native['parentInternalTraceCaptured']
    assert length(full['travel'])>full['margin'] and vec(pair['parentSnapProjectedTravel'])==[0.,f32(full['travel'][1]),0.]
    assert add(full['from']['origin'],pair['parentSnapProjectedTravel'])==actual==vec(p['expectedFinal'])
    short_endpoint=add(short['from']['origin'],short['travel']);assert short_endpoint==vec(p['originalExpectedFinal'])==vec(event['originalProof']['expectedFinal'])
    assert t['finalSupportQueryReached'];support=guard['support'];identities=t['finalSupportIdentities']
    assert support['validResult'] and support['hit'] and len(support['contacts'])==len(identities)==1
    assert support['from']==t['afterParent']['transform'] and support['maxCollisions']==32 and support['recoveryAsCollision'] and support['collideSeparationRay']
    contact=support['contacts'][0];identity=identities[0]
    assert identity['ridResolved'] and identity['colliderRid']==native['targetRid']==p['supportRid']
    assert identity['colliderId']==contact['colliderId'] and identity['colliderShapeIndex']==identity['localShapeIndex']==contact['colliderShape']==contact['localShape']==0
    assert contact['velocity']==[0.,0.,0.] and contact['normal'][1]>=math.cos(native['parameters']['floorMaxAngle'])
    plane_error=abs(f32(contact['point'][1])-f32(p['landingY']));assert plane_error==0.
    whole=vec(event['wholeFrameDelta']);parent=vec(t['afterParent']['parentPositionDelta']);up=vec(t['actualUpTravel'])
    assert sub(whole,parent)==up and whole==vec(t['wholeFrameDelta'])==vec(p['actualWholeFrameDelta'])
    assert t['afterParent']['velocity'][1]==0 and t['afterParent']['parentRealVelocity'][1]==-5.0625
    af=load(ROOT/'godot/tests/walker_snap_compare/snap-compare-af-01/comparison-result.json')['records'][-1]
    assert vec(af['actualBodyGlobalTransform']['origin'])==vec(t['beforePlanning']['transform']['origin'])
    assert actual==add(af['comparison']['parentSnap4']['from']['origin'],af['comparison']['parentSnapProjectedTravel'])
    ae=load(HERE.parent/'walker-snap-parity/AE-witness.json')['response'];assert actual==vec(ae['after'])
    assert short_endpoint==vec(ae['proposal']['expectedFinal']) and not ae['proposal']['responseGuard']['passed']
    before=load(HERE/'evidence/before.json');after=load(HERE/'evidence/after.json')
    assert before['sidecars']==after['sidecars'] and before['viewer']==after['viewer'] and before['displays']==after['displays']
    assert before['archives']==after['archives'] and before['productionDependencies']==after['productionDependencies']
    angle=math.degrees(math.acos(contact['normal'][1]/length(contact['normal'])))
    result={'status':'one completed guarded parity response passed; not positive admission','completedInstrumentedPath':True,'counterInterpretation':'post-return counts valid for this completed error-free path; default zeros on interrupted paths would be unknown',
        'records':28,'settleFrames':20,'inputResponses':8,'ordinaryApproachResponses':27,'ordinaryApproachInputResponses':7,'candidateAttempts':1,'appliedUpCount':1,'candidateParentResponses':1,'firstEligibleFrame':29,'tick':27,
        'candidateResponseCollected':True,'responseGuardPassed':True,'positiveAdmission':False,'nativeStepAdmission':False,'candidateMapWalksRun':0,'allGuardChecksReached':True,'guardChecksNotReached':[],
        'rawTraceSha256':sha(stage/'response-result.json'),'sourceSha256':sha(stage/'source.json'),'grantSha256':sha(stage/'grant.json'),'engineSha256':grant['engineSha256'],
        'epsilon':guard['epsilon'],'actualEndpointFloat32':actual,'parityExpectedEndpointFloat32':expected,'endpointErrorFloat32':error,'endpointErrorLength':length(error),'oldExpectedEndpointFloat32':short_endpoint,
        'actualMinusOldEndpointFloat32':sub(actual,short_endpoint),'actualUpTravelFloat32':up,'actualRaisedMinusModeledRaisedFloat32':raised_error,'parentLastMotionMinusModeledForwardFloat32':forward_error,'forwardErrorLength':length(forward_error),
        'wholeFrameDeltaFloat32':whole,'parentPositionDeltaFloat32':parent,'wholeMinusParentEqualsActualUp':True,'parentRealVelocity':t['afterParent']['parentRealVelocity'],'actualGroundedVelocity':t['afterParent']['velocity'],
        'liveFinalSupportGuardPassed':True,'finalSupportQuery':support,'finalSupportIdentities':identities,'supportNormalAngleDegrees':angle,'supportPlaneError':plane_error,'supportQueryTravelApplied':False,
        'finalSupportQueryDidNotMutateObservedBody':t['afterParent']==t['afterGuard'],'parentSlideCount':0,'parentSlides':[],
        'modeledParentQueries':pair,'actualUpBefore':t['upRequest']['before'],'actualUpAfter':t['upAfter'],
        'internalParentCallsTraced':False,'cancellationWrapperObserved':False,'configuredPhysicsEngineSetting':native['configuredPhysicsEngineSetting'],'backendImplementationVerified':False,
        'fullTreadLandingQualified':False,'productionAccountingLimitationRemains':True,'uniqueAERootCauseProved':False,
        'preservation':{'sidecarsUnchanged':len(before['sidecars']),'sidecarsDeleted':0,'cleanupPerformed':False,'viewer':after['viewer'],'displaysUnchanged':True,'historicalArchivesUnchanged':True,'all15ProductionDependenciesUnchanged':True}}
    write(HERE/'evidence/analysis.json',result)
    print('Validated28 consecutive records, one UP/parent/guard response, zero endpoint error, live support RID/shape/plane and preserved accounting. Support normal degrees:',angle)
if __name__=='__main__':main()
