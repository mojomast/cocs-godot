"""Read-only AH post-release analysis. Does not execute Godot or change receipts."""
import math
from audit_ah import ROOT,HERE,OUT,STAGE,load,write,sha,utc,validate_stage,successful,dependencies,GROUPS
def analyze():
    auth=load(OUT/'authorization.json');before=load(OUT/'before.json');after=load(OUT/'after.json');release=load(OUT/'AH-release.json')
    assert before['viewer']==after['viewer'] and before['displays']==after['displays']
    assert before['pins']==after['pins'] and before['archives']==after['archives'] and before['historicalProvenance']==after['historicalProvenance']
    for name,row in before['sidecars'].items():assert after['sidecars'].get(name)==row,name
    config=validate_stage(STAGE)
    assert sha(STAGE/'source.json')==auth['sourceSha256'] and sha(STAGE/'grant.json')==auth['grantSha256']
    assert release['remainingAuthorization'] is False and release['lock']['available']
    assert len(release['releaseAudits'])==3 and all(a['measured'] and all(g['members']==[] for g in a['groups']) for a in release['releaseAudits'])
    nr=load(STAGE/'negative-controls-result.json');ns=load(STAGE/'negative-controls-supervisor.json');ins=load(STAGE/'inclined-landing-rejections-supervisor.json')
    assert successful(nr,GROUPS[0],auth['sourceSha256'],auth['grantSha256'],auth['engineSha256'])
    deps=dependencies(STAGE,GROUPS[1],auth['sourceSha256'],auth['grantSha256'],auth['engineSha256'])
    assert ns['returnCode']==0 and ns['failed'] is False and ins['returnCode']==2 and ins['failed'] is True and ins['releasedCleanly'] is True
    assert not (STAGE/'inclined-landing-rejections-result.json').exists()
    assert not any(STAGE.glob('positive-step-admission*'))
    maximum=0.;settle=inputs=ordinary=0;positive_ordinary=[]
    for row in nr['records']:
        a,b=row['profiles'];aa=a['settle']+a['frames'];bb=b['settle']+b['frames'];assert len(aa)==len(bb)
        for x,y in zip(aa,bb):
            maximum=max(maximum,math.dist(x['after']['transform']['origin'],y['after']['transform']['origin']))
            assert x['after']['velocity']==y['after']['velocity'] and x['after']['grounded']==y['after']['grounded']
        for p in [a,b]:
            settle+=len(p['settle']);inputs+=len(p['frames'])
            assert p['appliedUpCount']==p['verifiedLifts']==0
            for i,x in enumerate(p['settle']+p['frames']):
                assert x['returned'] and x['candidateFault']=='' and x['after']['resetCount']==1
                if i:assert x['frame']==(p['settle']+p['frames'])[i-1]['frame']+1
                if p['experimental']:
                    assert x['lifecycle']['ordinary'] and x['lifecycle']['parentCalls']==1 and x['appliedUpCount']==0
                    ordinary+=1
            if row['spec']['radius']==.42 and p['frames'][-1]['wholeFrameDelta'][1]>0:
                positive_ordinary.append({'fixture':row['spec']['id'],'experimental':p['experimental'],'wholeFrameDelta':p['frames'][-1]['wholeFrameDelta'],'appliedUp':p['appliedUpCount']})
    summary={'utc':utc(),'scope':'AH native synthetic campaign stopped on second invocation failure; no positive admission','sourceSha256':auth['sourceSha256'],'grantSha256':auth['grantSha256'],'engineSha256':auth['engineSha256'],'supervisedInvocations':2,'nativeSourceCorrections':0,'retries':0,'groups':{
        GROUPS[0]:{'plannedPairs':34,'invocations':1,'passed':True,'attemptedPairs':34,'completedPairs':34,'passedPairs':34,'failedPairs':0,'interruptedPairs':0,'unrunPairs':0,'attemptedProfiles':68,'completedProfiles':68,'failedProfiles':0,'interruptedProfiles':0,'unrunProfiles':0,'settlingRecords':settle,'inputRecordsIncludingJumpLaunches':inputs,'candidateOrdinaryResponses':ordinary,'appliedUp':0,'verifiedLifts':0,'maxPairedPositionDifference':maximum},
        GROUPS[1]:{'plannedPairs':4,'plannedProfiles':8,'invocations':1,'passed':False,'returnCode':2,'nativeReceiptPresent':False,'instrumentedCompletedPairs':0,'instrumentedCompletedProfiles':0,'attemptedPairs':None,'failedPairs':None,'interruptedPairs':None,'unrunPairs':None,'attemptedProfiles':None,'failedProfiles':None,'interruptedProfiles':None,'unrunProfiles':None,'physicalCalls':None,'counterQualification':'No native receipt: internal trial/call counters unknown, not zero. All4 pairs and8 profiles unqualified. Group invocation failed; do not invent a failed trial.'},
        GROUPS[2]:{'plannedPairs':4,'plannedProfiles':8,'invocations':0,'attemptedPairs':0,'completedPairs':0,'passedPairs':0,'failedPairs':0,'interruptedPairs':0,'unrunPairs':4,'attemptedProfiles':0,'completedProfiles':0,'failedProfiles':0,'interruptedProfiles':0,'unrunProfiles':8,'passed':False,'status':'unrun_due_to_prior_failure'}},
        'firstFailure':{'group':GROUPS[1],'nativeReturnCode':2,'supervisorExitCode':1,'log':'Official4.5.2 banner only; no script/error lines','nativeResult':None,'qualification':'Consistent with early initialization/admission exit; staged driver has silent quit(2) preflight branches before ready. Exact branch not traced. Host negative strict replay and predecessor dependency validation still pass. No source fix or engine probe performed.'},
        'negativeR042PositiveOrdinaryDisplacements':positive_ordinary,'predecessorReplayAfterFailure':deps,'positiveAdmission':False,'nativeStepAdmission':False,'productionPromotion':False,'candidateMapWalks':0,'parentAccountingLimitationUnchanged':True,'releaseUtc':release['releasedUtc'],'noEngineAfterRelease':True}
    preservation={'utc':utc(),'viewerUnchanged':True,'displaysUnchanged':True,'preexistingSidecarsVerified':len(before['sidecars']),'newSidecars':{k:v for k,v in after['sidecars'].items() if k not in before['sidecars']},'archivesVerified':{k:v['filesVerified'] for k,v in after['archives'].items()},'XUVerified':after['frozen'],'productionDependenciesVerified':len(after['pins']['productionDependencies']),'stageScriptsVerified':len(config['files'])-1,'historicalProvenanceVerified':True,'noCleanupPerformed':True}
    write(OUT/'analysis.json',summary);write(OUT/'preservation.json',preservation)
    print(summary['groups']);print('Preserved sidecars',len(before['sidecars']),'new',len(preservation['newSidecars']))
if __name__=='__main__':analyze()
