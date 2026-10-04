"""Read-only extraction from the stopped positive invocation; no native calls."""
import math
from audit_ak import STAGE,OUT,load,write,sha,utc
from evidence import profile,guarded,footprint,support
def inspect():
    r=load(STAGE/'positive-step-admission-result.json');summaries=[]
    for case in r['records']:
        spec=case['spec']
        def along(pos):return math.sin(spec['yaw'])*pos[0]+math.cos(spec['yaw'])*pos[2]
        for p in case['profiles']:
            first=p['settle'][0]['before']['transform']['origin'];last=p['frames'][-1];end=last['after']['transform']['origin']
            summary={'caseIndex':case['caseIndex'],'spec':spec,'experimental':p['experimental'],'status':p['status'],'outcome':p.get('outcome'),'settleRecords':len(p['settle']),'inputRecords':len(p['frames']),'lastFrame':last['frame'],'start':first,'end':end,'netTravel':[end[i]-first[i] for i in range(3)],'along':along(end),'goal':spec['goal'],'reached':p['reached'],'stallCount':p['stallCount'],'ordinaryLandingStreak':p['ordinaryLandingStreak'],'appliedUpCount':p['appliedUpCount'],'verifiedLifts':p['verifiedLifts'],'candidateFaults':[x['candidateFault'] for x in p['settle']+p['frames'] if x['candidateFault']],'targetRid':p['targetRid'],'targetShape':p['targetShape'],'applications':[]}
            if p['status']=='completed':assert profile(p,spec,'positive-step-admission',p['experimental']);summary['strictIndividualProfileReplay']=True
            for row in p['settle']+p['frames']:
                assert row['returned'] and row['physicsHz']==60 and row['timeScale']==1 and abs(row['actualDelta']-1/60)<1e-8
                if p['experimental']:
                    assert row['lifecycle']['parentCalls']==1 and row['appliedUpCount'] in [0,1]
                    if row['appliedUpCount']:
                        assert guarded(row,p)
                        g=row['proposal']['responseGuard'];t=row['telemetry']
                        summary['applications'].append({'frame':row['frame'],'responseGuardPassed':row['responseGuardPassed'],'guard':g,'finalSupportQueryReached':t['finalSupportQueryReached'],'supportIdentities':t['finalSupportIdentities'],'actualUpTravel':t['actualUpTravel'],'upRequest':t['upRequest'],'endpointDistance':math.dist(g['actualFinal'],g['expectedFinal']),'wholeFrameDelta':row['wholeFrameDelta'],'parentPositionDelta':row['after']['parentPositionDelta'],'parentRealVelocity':row['after']['parentRealVelocity'],'actualVelocity':row['after']['velocity'],'liftLimit':row['lifecycle']['liftLimit'],'strictGuardOperandsReplay':True})
            if p.get('finalSupport'):
                final=p['finalSupport'];assert final['passed'] and final['footprintInside'] and footprint(last['after'],spec)
                assert support(final['query'],p['targetRid'],last['after']['transform'],p['parameters'],final['epsilon'],.15,'fresh-full-tread-support')
                summary['finalSupport']=final;summary['strictFinalSupportReplay']=True
                summary['lastThreeOrdinaryGroundedContinuedInput']=[{'frame':x['frame'],'input':x['input'],'grounded':x['after']['grounded'],'footprintInside':footprint(x['after'],spec),'ordinary':not p['experimental'] or x['lifecycle']['ordinary'],'position':x['after']['transform']['origin']} for x in p['frames'][-3:]]
            summaries.append(summary)
    failed=summaries[-1]
    assert r['outcome']=='unexpected_baseline_arrival' and failed['caseIndex']==2 and not failed['experimental'] and failed['appliedUpCount']==0 and failed['reached']
    return {'utc':utc(),'nativeSha256':sha(STAGE/'positive-step-admission-result.json'),'outcome':r['outcome'],'profiles':summaries,'firstFailure':{'caseIndex':2,'profileIndex':0,'frame':failed['lastFrame'],'expected':'baseline blocked with120 stalled responses and reachedfalse','actual':'baseline reached goal with fresh exclusive target support, full footprint and zero assist','along':failed['along'],'goal':failed['goal'],'stallCount':failed['stallCount'],'ordinaryLandingStreak':failed['ordinaryLandingStreak'],'driverSourceLine':286,'candidateGuardFailure':False,'candidateApplicationGuard':'not applicable to this baseline profile','freshArrivalSupportReached':True,'freshArrivalSupportPassed':True,'radius042CandidateProfileInvoked':False},'positiveAdmission':False,'candidateRadius035ProfilesIndividuallyPassed':2,'qualification':'Individual completed profile/guard replay only; positive group failed. Whole-frame pre-lift displacement and parent-only motion remain distinct; production accounting open.'}
if __name__=='__main__':
    result=inspect();write(OUT/'positive-detail.json',result)
    for p in result['profiles']:print({k:p[k] for k in ['caseIndex','experimental','status','lastFrame','along','ordinaryLandingStreak','appliedUpCount','verifiedLifts']})
    print(result['firstFailure'])
