"""AM read-only preservation/checkpoints/release/inventory; never launches native work."""
import importlib.util,json,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];OUT=HERE/'evidence'
STAGE=ROOT/'godot/tests/walker_calibrated_admission/calibrated-admission-am-01'
AL_ROOT=ROOT.parent/'cocs-walker-baseline-characterization-al';AK_ROOT=ROOT.parent/'cocs-walker-parity-admission-ak'
def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
base=load_module('_am_preservation_base',HERE.parent/'walker-baseline-characterization-al/audit_al.py')
loader=load_module('_am_calibrated_loader',HERE.parent/'walker-calibrated-admission/cli.py')
prepare=loader.module('prepare');policy=loader.module('policy');evidence=loader.module('evidence');preserve=loader.module('verify_preservation')
runtime=loader.module('frozen').runtime
load=prepare.load;write=prepare.write;sha=prepare.sha;utc=base.utc
def snapshot():
    r=base.snapshot();r['preservation']=preserve.verify();r['calibratedLineage']=prepare.lineage(AL_ROOT,AK_ROOT)
    for pattern in ['*.uid','*.import']:
        for p in sorted((AL_ROOT/'godot').rglob(pattern)):
            if p.is_file():r['sidecars'][str(p)]={'sha256':sha(p),'bytes':p.stat().st_size}
    receipt=load(HERE.parent/'walker-calibrated-admission/source-receipt.json')
    for n,v in receipt['files'].items():
        if sha(ROOT/n)!=v['sha256'] or (ROOT/n).stat().st_size!=v['bytes']:raise ValueError('calibrated source delivery drift: '+n)
    r['calibratedDeliveryFilesVerified']=len(receipt['files'])
    r['calibratedSeals']={p.name:sha(p) for p in (HERE.parent/'walker-calibrated-admission').glob('*.json')}
    return r
def checkpoint(group):
    config=prepare.validate_stage(STAGE);a=load(OUT/'authorization.json');rpath=STAGE/(group+'-result.json');spath=STAGE/(group+'-supervisor.json')
    for key,name in [('sourceSha256','source.json'),('grantSha256','grant.json')]:
        if sha(STAGE/name)!=a[key]:raise ValueError('source/grant changed')
    if sha(Path(a['engine']))!=a['engineSha256']:raise ValueError('engine drift')
    s=load(spath);r=load(rpath) if rpath.exists() else None
    native_ok=policy.successful(r,group,a['sourceSha256'],a['grantSha256'],a['engineSha256'])
    sup_ok=evidence.supervisor_ok(s,group,a['sourceSha256'],a['grantSha256'],a['engineSha256'],sha(rpath) if r else None)
    deps_hash=sha(STAGE/(group+'-dependencies.json'))
    chain_ok=s.get('dependenciesSha256')==deps_hash and bool(r) and r.get('dependenciesSha256')==deps_hash
    errors=[line for line in (STAGE/(group+'.log')).read_text(errors='replace').splitlines() if any(x in line for x in ['ADMISSION_FAILURE ','SCRIPT ERROR','Parse Error','ERROR:'])]
    if not s.get('owned'):raise ValueError('missing owned identity')
    members=runtime.members(s['owned']['pgid']);lock=base.probe()
    if members:raise ValueError('checkpoint owned group not empty')
    result={'utc':utc(),'group':group,'sourceSha256':a['sourceSha256'],'grantSha256':a['grantSha256'],'engineSha256':a['engineSha256'],'dependenciesSha256':deps_hash,'nativeSha256':sha(rpath) if r else None,'supervisorSha256':sha(spath),'logSha256':sha(STAGE/(group+'.log')),'nativeReceiptPresent':r is not None,'nativeStrictReplay':native_ok,'supervisorStrictReplay':sup_ok,'dependencyChainVerified':chain_ok,'errors':errors,'nativeOutcome':r.get('outcome') if r else None,'nativeReturnCode':s.get('returnCode'),'supervisorFailed':s['failed'],'releasedCleanly':s['releasedCleanly'],'owned':s['owned'],'ownedGroupMembers':members,'lock':lock,'passed':bool(native_ok and sup_ok and chain_ok and not errors),'physicalCallCounts':None,'partialCountersMayBeUnknown':s['partialCountersMayBeUnknown'],'counts':{k:v for k,v in (r or {}).items() if k.endswith('Pairs') or k.endswith('Profiles')},'records':[]}
    for pair in (r or {}).get('records',[]):
        row={'caseIndex':pair['caseIndex'],'spec':pair['spec'],'status':pair['status'],'profiles':[]}
        for p in pair['profiles']:
            frames=p.get('frames',[]);row['profiles'].append({'experimental':p['experimental'],'status':p['status'],'outcome':p.get('outcome'),'settles':len(p.get('settle',[])),'inputResponses':len(frames),'appliedUpCount':p['appliedUpCount'],'verifiedLifts':p['verifiedLifts'],'reached':p['reached'],'stallCount':p['stallCount'],'inclinedWitnesses':p['inclinedWitnesses'],'ordinaryLandingStreak':p['ordinaryLandingStreak'],'lastFrame':frames[-1]['frame'] if frames else None,'lastFault':frames[-1].get('candidateFault') if frames else None})
        result['records'].append(row)
    result['freshPreservation']=preserve.verify();result['explicitExternalLineage']=prepare.lineage(AL_ROOT,AK_ROOT)
    result['ownerInspection']='Strict full native operand replay and supervisor audit/hash replay completed; raw profile/contact review is recorded separately before any next command.'
    return result
def release():
    owned=[load(p)['owned'] for p in sorted(STAGE.glob('*-supervisor.json')) if load(p).get('owned')]
    if not owned:raise ValueError('no measured ownership')
    audits=[]
    for _ in range(3):
        row={'utc':utc(),'measured':True,'groups':[{'owned':o,'members':runtime.members(o['pgid'])} for o in owned]}
        if any(g['members'] for g in row['groups']):raise ValueError('owned residual; helper never signals')
        audits.append(row);time.sleep(.2)
    return {'grant':'MOTH-BLENDER-20261004-AM','ownedGroups':owned,'releaseAudits':audits,'lock':base.probe(),'releasedUtc':utc(),'remainingAuthorization':False,'queuedWork':False,'noFurtherEngineInvocations':True}
def preservation():
    before=load(OUT/'before.json');after=load(OUT/'after.json')
    for key in ['viewer','displays','preservation','historicalReceipts','calibratedSeals','calibratedLineage','calibratedDeliveryFilesVerified']:
        if before[key]!=after[key]:raise ValueError('preservation difference: '+key)
    for n,v in before['sidecars'].items():
        if after['sidecars'].get(n)!=v:raise ValueError('preexisting sidecar drift: '+n)
    return {'utc':utc(),**after['preservation'],'viewerUnchanged':True,'sevenDisplaysUnchanged':True,'preexistingSidecarsVerified':len(before['sidecars']),'newSidecars':{n:v for n,v in after['sidecars'].items() if n not in before['sidecars']},'originalReceiptsAndCalibratedSourceSealsUnchanged':True,'calibratedDeliveryFilesVerified':22,'explicitALRootVerified':str(AL_ROOT),'explicitAKRootVerified':str(AK_ROOT),'noCleanupPerformed':True}
def inventory():
    return {'scope':'AM delivery; inventory self-excluded','files':{str(p.relative_to(ROOT)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(list(HERE.rglob('*'))+list(STAGE.rglob('*'))) if p.is_file() and p.name!='artifact-inventory.json'}}
if __name__=='__main__':
    OUT.mkdir(exist_ok=True);mode=sys.argv[1]
    if mode in ['before','after']:write(OUT/(mode+'.json'),snapshot())
    elif mode=='checkpoint':write(OUT/(sys.argv[2]+'-checkpoint.json'),checkpoint(sys.argv[2]))
    elif mode=='release':write(OUT/'AM-release.json',release())
    elif mode=='preservation':write(OUT/'preservation.json',preservation())
    elif mode=='inventory':write(OUT/'artifact-inventory.json',inventory())
    else:raise SystemExit('before|after|checkpoint GROUP|release|preservation|inventory')
