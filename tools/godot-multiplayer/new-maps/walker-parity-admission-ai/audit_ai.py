"""AI preservation/checkpoint/post-exit helpers only. Never launches an engine."""
import datetime,hashlib,importlib.util,json,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];OUT=HERE/'evidence'
STAGE=ROOT/'godot/tests/walker_parity_admission/parity-admission-ai-01'
AH=Path('/home/mojo/.tmp-on-disk/cocs-walker-parity-admission-ah')
AH_MANIFEST='tools/godot-multiplayer/new-maps/walker-parity-admission-ah/evidence/artifact-inventory.json'
AH_SHA='2eb06da778a5e7218451067592f7293180212eaedabada19885460d8c3f6f495'
spec=importlib.util.spec_from_file_location('_ai_readonly_base',HERE.parent/'walker-parity-admission-ah/audit_ah.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
# Reuse read-only functions against AI paths; do not edit or call historical main.
base.HERE=HERE;base.ROOT=ROOT;base.OUT=OUT;base.STAGE=STAGE
load=base.load;write=base.write;sha=base.sha;utc=base.utc
def snapshot():
    result=base.snapshot();base.files.verify_archive(AH,AH_MANIFEST,AH_SHA,42)
    result['archives']['AH']={'root':str(AH),'manifestSha256':AH_SHA,'filesVerified':42}
    for root in [AH,ROOT.parent/'cocs-walker-admission-gate-diagnosis']:
        for pattern in ['*.uid','*.import']:
            for p in (root/'godot').rglob(pattern):
                if p.is_file():result['sidecars'][str(p)]={'sha256':sha(p),'bytes':p.stat().st_size}
    result['currentHistoricalReceipts']={str(p.relative_to(ROOT)):sha(p) for p in list((HERE.parent/'walker-parity-admission').glob('*receipt.json'))+[HERE.parent/'walker-parity-admission/source-provenance.json',HERE.parent/'walker-admission-gate-diagnosis/source-receipt.json']}
    result['reusedHelperSha256']=sha(HERE.parent/'walker-parity-admission-ah/audit_ah.py')
    engines=[p for p in result['processes'] if any(n in p['cmdline'].split(' ',1)[0].lower() for n in ['godot','blender'])]
    if any(p['pid']!=2598700 for p in engines):raise RuntimeError('unexpected engine process during idle snapshot')
    return result
def checkpoint(group):
    r=base.checkpoint(group);text=(STAGE/(group+'.log')).read_text(errors='replace')
    r['admissionFailureLines']=[line for line in text.splitlines() if line.startswith('ADMISSION_FAILURE ')]
    r['admissionDiagnostics']=[json.loads(line[len('ADMISSION_FAILURE '):]) for line in r['admissionFailureLines']]
    if r['admissionFailureLines']:r['passed']=False
    # Positive is never authorized, even if the shared predecessor reader can
    # validate its prerequisites. Remove that derived suggestion from AI output.
    if group=='inclined-landing-rejections':r.pop('nextDependencyReplay',None)
    return r
def release():
    owned=[load(p)['owned'] for p in sorted(STAGE.glob('*-supervisor.json')) if load(p).get('owned')]
    audits=[]
    for _ in range(3):
        row={'utc':utc(),'measured':True,'groups':[{'owned':r,'members':base.runtime.members(r['pgid'])} for r in owned]}
        if any(g['members'] for g in row['groups']):raise RuntimeError('owned group not empty; no signaling by helper')
        audits.append(row);time.sleep(.2)
    return {'grant':'MOTH-BLENDER-20261004-AI','ownedGroups':owned,'releaseAudits':audits,'lock':base.probe(),'releasedUtc':utc(),'remainingAuthorization':False,'queuedWork':False,'noFurtherEngineInvocations':True}
def inventory():
    return {'scope':'AI delivery; self-excludes artifact-inventory.json','files':{str(p.relative_to(ROOT)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(list(HERE.rglob('*'))+list(STAGE.rglob('*'))) if p.is_file() and p.name!='artifact-inventory.json'}}
def analyze():
    before=load(OUT/'before.json');after=load(OUT/'after.json');authorization=load(OUT/'authorization.json');released=load(OUT/'AI-release.json')
    for key in ['viewer','displays','archives','pins','historicalProvenance','currentHistoricalReceipts']:assert before[key]==after[key],key
    for name,row in before['sidecars'].items():assert after['sidecars'].get(name)==row,name
    config=base.validate_stage(STAGE)
    assert sha(STAGE/'source.json')==authorization['sourceSha256'] and sha(STAGE/'grant.json')==authorization['grantSha256']
    assert not any(STAGE.glob('positive-step-admission*'))
    groups={};diagnostics=[]
    for group,n in [('negative-controls',34),('inclined-landing-rejections',4)]:
        native=STAGE/(group+'-result.json');sup=STAGE/(group+'-supervisor.json')
        if not sup.exists():groups[group]={'invocations':0,'plannedPairs':n,'unrunPairs':n,'unrunProfiles':2*n};continue
        s=load(sup);r=load(native) if native.exists() else None
        groups[group]={'invocations':1,'plannedPairs':n,'nativeReturnCode':s.get('returnCode'),'failed':s['failed'],'releasedCleanly':s['releasedCleanly'],'nativeReceiptPresent':r is not None,'instrumentedCompletedPairs':r.get('completedPairs') if r else 0,'instrumentedCompletedProfiles':r.get('completedProfiles') if r else 0,'internalCounters':{k:v for k,v in r.items() if k.endswith('Pairs') or k.endswith('Profiles')} if r else None,'physicalCallCounts':None if r is None else {'appliedUp':sum(p.get('appliedUpCount',0) for row in r['records'] for p in row['profiles'])}}
        if r is None or s.get('partialCountersMayBeUnknown'):
            groups[group]['physicalCallCounts']=None
            groups[group]['qualification']='Internal attempted/completed/failed/interrupted/unrun and physical calls may be unknown on partial/fatal paths. Zero instrumented completion is not internal zero.'
        text=(STAGE/(group+'.log')).read_text(errors='replace')
        diagnostics.extend({'group':group,'verbatim':line,'parsed':json.loads(line[len('ADMISSION_FAILURE '):])} for line in text.splitlines() if line.startswith('ADMISSION_FAILURE '))
    groups['positive-step-admission']={'invocations':0,'plannedPairs':4,'attemptedPairs':0,'completedPairs':0,'passedPairs':0,'failedPairs':0,'interruptedPairs':0,'unrunPairs':4,'attemptedProfiles':0,'completedProfiles':0,'failedProfiles':0,'interruptedProfiles':0,'unrunProfiles':8,'status':'not_authorized'}
    write(OUT/'analysis.json',{'utc':utc(),'scope':'AI bounded two-group native diagnostic campaign','groups':groups,'admissionDiagnostics':diagnostics,'diagnosticQualification':'Code identifies driver gate only, not an internal Policy/Evidence subpredicate. Unknown native counters remain unknown.','sourceSha256':authorization['sourceSha256'],'grantSha256':authorization['grantSha256'],'engineSha256':authorization['engineSha256'],'positiveAdmission':False,'nativeStepAdmission':False,'productionPromotion':False,'candidateMapJourneysRun':0,'productionAccountingStillOpen':True,'releasedUtc':released['releasedUtc'],'nativeRetries':0,'nativeSourceCorrections':0})
    write(OUT/'preservation.json',{'utc':utc(),'viewerUnchanged':True,'displaysUnchanged':True,'preexistingSidecarsVerified':len(before['sidecars']),'newSidecars':{k:v for k,v in after['sidecars'].items() if k not in before['sidecars']},'archivesVerified':{k:v['filesVerified'] for k,v in after['archives'].items()},'XUVerified':after['frozen'],'productionDependenciesVerified':15,'stageScriptsVerified':len(config['files'])-1,'historicalProvenanceVerified':True,'noCleanupPerformed':True})
    print(groups);print(diagnostics)
if __name__=='__main__':
    OUT.mkdir(exist_ok=True);mode=sys.argv[1]
    if mode in ['before','after']:write(OUT/(mode+'.json'),snapshot())
    elif mode=='checkpoint':write(OUT/(sys.argv[2]+'-checkpoint.json'),checkpoint(sys.argv[2]))
    elif mode=='release':write(OUT/'AI-release.json',release())
    elif mode=='inventory':write(OUT/'artifact-inventory.json',inventory())
    elif mode=='analyze':analyze()
    else:raise SystemExit('before|after|checkpoint GROUP|release|inventory|analyze')
