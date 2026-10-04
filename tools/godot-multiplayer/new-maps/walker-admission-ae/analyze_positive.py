"""Read-only AE failure diagnosis; no retry, solver query or tolerance changes."""
import json,math,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-admission'))
from prepare import sha,write
def main():
    p=ROOT/'godot/tests/walker_admission/admission-ae-01'
    d=json.loads((p/'positive-step-admission-result.json').read_text())
    supervisor=json.loads((p/'positive-step-admission-supervisor.json').read_text())
    checkpoint=json.loads((HERE/'evidence/inclined-checkpoint.json').read_text())
    assert supervisor['returnCode']==1 and supervisor['releasedCleanly']
    assert d['failed'] and d['failedTrials']==d['attempted']==1 and d['passed']==0 and d['unrun']==3
    assert d['baselinePassed']==1 and d['candidatePassed']==0 and not d['nativeStepAdmission']
    assert d['sourceSha256']==checkpoint['sourceSha256']==sha(p/'source.json')
    assert d['grantReceiptSha256']==checkpoint['grantSha256']==sha(p/'grant.json')
    row=d['records'][0];assert row['spec']['id']=='0.35:-45.0' and not row['passed']
    baseline,candidate=row['profiles'];assert not baseline['experimental'] and candidate['experimental']
    assert len(baseline['frames'])==127 and baseline['stallCount']==120 and not baseline['reached']
    assert len(candidate['frames'])==8 and candidate['appliedVerifiedLifts']==0 and not candidate['reached']
    contacts=0
    for profile in [baseline,candidate]:
        samples=profile['settle']+profile['frames']
        assert len(profile['settle'])==20 and profile['settle'][-1]['groundedAfter']
        assert all(b['clock']['frame']==a['clock']['frame']+1 for a,b in zip(samples,samples[1:]))
        for sample in samples:
            assert sample['clock']['physics'] and sample['clock']['hz']==60 and sample['clock']['scale']==1
            assert sample['resetCount']==1 and not sample['sprint'] and not sample['jump']
            assert abs(sample['actualShapeData']['radius']-.35)<1e-7 and abs(sample['actualShapeData']['height']-1.8)<1e-7
            assert isinstance(sample['bodyRid'],int) and isinstance(sample['capsuleRid'],int)
            for contact in sample['collisions']:
                assert isinstance(contact['colliderShapeIndex'],int) and contact['shapeObjectDescription']=='CollisionShape3D';contacts+=1
    final=candidate['frames'][-1];plan=final['proposal'];guard=plan['responseGuard']
    assert plan['accepted'] and final['candidateFault']==guard['reason']=='endpoint_differs_from_proof'
    assert guard['epsilon']==1e-6 and guard['slideCount']==0 and not guard['observedSlides'] and not guard['passed']
    assert not any(s['candidateFault'] for s in baseline['settle']+baseline['frames']+candidate['settle']+candidate['frames'][:-1])
    assert sum(s['proposal'].get('accepted',False) for s in candidate['frames'])==1
    delta=[a-b for a,b in zip(guard['actualFinal'],guard['expectedFinal'])]
    assert delta[0]==delta[2]==0 and abs(delta[1])>guard['epsilon']
    stages={s['name']:s for s in plan['stages']}
    assert not stages['up']['hit'] and not stages['forward']['hit'] and stages['down']['hit']
    assert plan['supportRid']==candidate['topRid'] and plan['supportShape']==0
    assert stages['down']['contacts'] and all(c['collider'].endswith('/PositiveTread') and c['colliderShape']==c['localShape']==0 for c in stages['down']['contacts'])
    assert 'support' not in guard # guard returned BEFORE fresh final-capsule identity check
    raised=plan['raised']['origin'];before=final['before'];actual=final['after']
    report={'status':'FAILED positive admission; first pair stopped, no retry',
        'counts':{'plannedPairs':4,'attemptedPairs':1,'passedPairs':0,'failedPairs':1,'unrunPairs':3,'plannedProfiles':8,
          'attemptedProfiles':2,'baselineCompletedBlocked':1,'candidateFailedMidProfile':1,'unrunProfiles':6,
          'inputResponses':135,'settlingResponses':40,'acceptedProposals':1,'upSweepsApplied':1,'fullyGuardVerifiedLifts':0},
        'case':row['spec'],'nativeFailureFrame':final['clock']['frame'],'candidateInputOrdinal':8,
        'expectedFinal':guard['expectedFinal'],'actualFinal':guard['actualFinal'],'actualMinusExpected':delta,
        'endpointDistance':math.dist(guard['actualFinal'],guard['expectedFinal']),'epsilon':guard['epsilon'],
        'errorBudgetRatio':abs(delta[1])/guard['epsilon'],'parentSlideCount':guard['slideCount'],
        'plannedHorizontalVector':plan['horizontalBudget'],'actualParentLastMotion':guard['lastMotion'],
        'appliedUpTravel':[a-b for a,b in zip(raised,before)],'plannedDownMotion':stages['down']['motion'],
        'plannedDownTravel':stages['down']['travel'],'plannedDownSafeFraction':stages['down']['safeFraction'],
        'observedParentDownTravelY':actual[1]-raised[1],'existingParentSnapLength':candidate['parameters']['snap'],
        'plannedSupportRid':plan['supportRid'],'plannedSupportShape':plan['supportShape'],
        'plannedDownContactNormal':stages['down']['contacts'][0]['normal'],'actualFinalCapsuleSupportVerified':False,
        'finalSupportCaveat':'endpoint guard returned before live final capsule-support query. Ordinary centre ray hits AdmissionBaseFloor; it does not identify finite-capsule floor support.',
        'wholeFrameDelta':final['wholeFrameDelta'],'parentPositionDelta':final['parentPositionDelta'],
        'parentRealVelocity':final['parentRealVelocity'],'actualVelocity':final['velocity'],'groundedAfter':final['groundedAfter'],
        'numericSlideContactsVerified':contacts,'sourceDifferenceRelevantToDiagnosis':{
          'plannerDownLength':abs(stages['down']['motion'][1]),'plannerMaxCollisions':stages['down']['maxCollisions'],
          'parentSnapLength':candidate['parameters']['snap'],'parentMaxCollisionsFromPinnedSource':4,
          'qualification':'Different downward query lengths/contact budgets are confirmed source facts; their exact contribution to backend rounding/contact search is not isolated by this run.'},
        'nativeStepAdmission':False,'productionPromotion':False,'candidateMapWalksRun':0,
        'resultSha256':sha(p/'positive-step-admission-result.json'),'sourceSha256':d['sourceSha256'],'grantSha256':d['grantReceiptSha256']}
    write(HERE/'evidence/positive-analysis.json',report)
    print('Confirmed endpoint failure:',delta,'epsilon',guard['epsilon'],'ratio',report['errorBudgetRatio'],'one applied up sweep, zero fully verified lifts; three pairs unrun')
if __name__=='__main__':main()
