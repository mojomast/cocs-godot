"""Read-only AM raw profile/guard inspection, including incomplete/fault paths."""
import json,math,sys
from audit_am import STAGE,OUT,load,write,sha,utc,evidence,policy
def inspect(group):
    path=STAGE/(group+'-result.json')
    if not path.exists():return {'utc':utc(),'group':group,'nativeReceiptPresent':False,'physicalCallCounts':None,'qualification':'No native result: no per-profile completion or zero-work inference.'}
    r=load(path);summaries=[];pair_deltas=[]
    for pair in r['records']:
        spec=pair['spec'];profiles=pair['profiles']
        if group!=policy.GROUPS[2] and len(profiles)==2:
            aa=profiles[0]['settle']+profiles[0]['frames'];bb=profiles[1]['settle']+profiles[1]['frames']
            if len(aa)==len(bb) and all('after' in x and 'after' in y for x,y in zip(aa,bb)):
                pair_deltas.append({'caseIndex':pair['caseIndex'],'responseRowsPerProfile':len(aa),'maxPositionDifference':max(math.dist(x['after']['transform']['origin'],y['after']['transform']['origin']) for x,y in zip(aa,bb)),'maxVelocityDifference':max(math.dist(x['after']['velocity'],y['after']['velocity']) for x,y in zip(aa,bb)),'allGroundedStatesEqual':all(x['after']['grounded']==y['after']['grounded'] for x,y in zip(aa,bb))})
        for p in profiles:
            rows=p.get('settle',[])+p.get('frames',[]);frames=p.get('frames',[]);last=frames[-1] if frames else rows[-1] if rows else {};after=last.get('after',{});pos=after.get('transform',{}).get('origin')
            summary={'caseIndex':pair['caseIndex'],'spec':spec,'experimental':p['experimental'],'status':p['status'],'outcome':p.get('outcome'),'settleRecords':len(p.get('settle',[])),'inputRecords':len(frames),'lastFrame':last.get('frame'),'end':pos,'reached':p['reached'],'stallCount':p['stallCount'],'inclinedWitnesses':p['inclinedWitnesses'],'ordinaryLandingStreak':p['ordinaryLandingStreak'],'appliedUpCount':p['appliedUpCount'],'verifiedLifts':p['verifiedLifts'],'parameters':p['parameters'],'target':p.get('target'),'candidateFaults':[{'frame':x.get('frame'),'fault':x.get('candidateFault')} for x in rows if x.get('candidateFault')],'terminalProposal':last.get('proposal'),'applications':[],'strictIndividualProfileReplay':evidence.profile(p,spec,group,p['experimental']) if p['status']=='completed' else None}
            if pos and 'yaw' in spec:summary['along']=math.sin(spec['yaw'])*pos[0]+math.cos(spec['yaw'])*pos[2]
            returned=[x for x in rows if x.get('returned') and 'after' in x]
            summary['returnedRows']=len(returned);summary['consecutiveFrames']=all(b['frame']==a['frame']+1 for a,b in zip(returned,returned[1:]));summary['strictlyIncreasingUsec']=all(b['usec']>a['usec'] for a,b in zip(returned,returned[1:]));summary['allClocks60HzUnitScale']=all(x['physicsHz']==60 and x['timeScale']==1 and abs(x['actualDelta']-1/60)<1e-8 for x in returned)
            if not p['experimental']:summary['allBaselineQueriesReadOnly']=all(x['afterQueries']==x['before'] for x in returned)
            else:summary['ordinaryCandidateResponses']=sum(x['lifecycle']['ordinary'] for x in returned);summary['parentCallsRecorded']=sum(x['lifecycle']['parentCalls'] for x in returned)
            if group==policy.GROUPS[0]:
                summary['expectedReasons']=p.get('expectedReasons');summary['observedReason']=last.get('proposal',{}).get('reason');summary['terminalStages']=last.get('proposal',{}).get('stages');summary['ordinaryWholeDelta']=last.get('wholeFrameDelta')
            if group==policy.GROUPS[1]:
                witnessed=[x for x in frames if x['proposal'].get('reason')=='no_continuous_flat_landing' and evidence.inclined_witness(x['proposal'],p['target'])]
                summary['rawWitnessResponses']=len(witnessed);summary['firstWitnessFrame']=witnessed[0]['frame'] if witnessed else None
            if group==policy.GROUPS[2] and not p['experimental']:
                window=frames[-120:];witnesses=[x for x in window if x.get('after') and evidence.baseline_target(x,p['target'])]
                summary['terminalWindowResponses']=len(window);summary['terminalWindowActualTargetWitnesses']=len(witnesses);summary['terminalWindowMaxWholeDistance']=max((math.dist(x['wholeFrameDelta'],[0,0,0]) for x in window if 'wholeFrameDelta' in x),default=None)
                summary['terminalWindowFirstFrame']=window[0]['frame'] if window else None
            for x in returned:
                if not p['experimental'] or not (x.get('appliedUpCount') or x.get('candidateFault')):continue
                plan=x['proposal'];g=plan.get('responseGuard');t=x.get('telemetry',{})
                app={'frame':x['frame'],'applied':x.get('appliedUpCount'),'parentCalls':x['lifecycle']['parentCalls'],'candidateFault':x.get('candidateFault'),'responseGuardPassed':x.get('responseGuardPassed'),'proposalAccepted':plan.get('accepted'),'proposalReason':plan.get('reason'),'landingY':plan.get('landingY'),'originalProof':x['lifecycle'].get('originalProof'),'guard':g,'telemetry':t,'wholeFrameDelta':x['wholeFrameDelta'],'parentPositionDelta':x['after'].get('parentPositionDelta'),'parentRealVelocity':x['after'].get('parentRealVelocity'),'lastMotion':x['after'].get('lastMotion'),'liftLimit':x['lifecycle'].get('liftLimit')}
                if g and 'actualFinal' in g and 'expectedFinal' in g:app['endpointDistance']=math.dist(g['actualFinal'],g['expectedFinal'])
                if x.get('responseGuardPassed'):app['strictGuardOperandsReplay']=evidence.guarded(x,p)
                summary['applications'].append(app)
            if p.get('finalSupport'):
                final=p['finalSupport'];summary['finalSupport']=final
                summary['strictFinalSupportReplay']=bool(final.get('passed') and evidence.footprint(last['after'],spec) and evidence.support(final.get('query'),p['targetRid'],last['after']['transform'],p['parameters'],final['epsilon'],spec['rise'],'fresh-full-tread-support'))
                summary['lastThreeOrdinaryGroundedContinuedInput']=[{'frame':x['frame'],'input':x['input'],'grounded':x['after']['grounded'],'footprintInside':evidence.footprint(x['after'],spec),'ordinary':not p['experimental'] or x['lifecycle']['ordinary'],'position':x['after']['transform']['origin']} for x in frames[-3:]]
            summaries.append(summary)
    return {'utc':utc(),'group':group,'nativeReceiptPresent':True,'nativeSha256':sha(path),'nativeOutcome':r['outcome'],'counts':{k:v for k,v in r.items() if k.endswith('Pairs') or k.endswith('Profiles')},'profiles':summaries,'pairedComparisons':pair_deltas,'settleRecords':sum(x['settleRecords'] for x in summaries),'inputRecords':sum(x['inputRecords'] for x in summaries),'qualification':'Read-only individual operand inspection; no unique engine-internal branch causation or production promotion. Whole-frame and parent-only accounting remain distinct.','physicalCallCounts':None,'candidateMapJourneysRun':0}
if __name__=='__main__':
    group=sys.argv[1];r=inspect(group);write(OUT/(group+'-detail.json'),r)
    print(json.dumps({k:v for k,v in r.items() if k not in ['profiles','pairedComparisons']},indent=2))
