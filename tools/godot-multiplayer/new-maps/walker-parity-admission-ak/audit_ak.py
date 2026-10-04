"""AK read-only preservation/checkpoint/analysis; never launches native work."""
import importlib.util,json,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];OUT=HERE/'evidence'
STAGE=ROOT/'godot/tests/walker_parity_admission/parity-admission-ak-01'
spec=importlib.util.spec_from_file_location('_ak_archive_base',HERE.parent/'walker-parity-admission-ah/audit_ah.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.HERE=HERE;base.ROOT=ROOT;base.OUT=OUT;base.STAGE=STAGE
load=base.load;write=base.write;sha=base.sha;utc=base.utc
def snapshot():
    r=base.snapshot()
    for tag,count,digest,namespace,folder in [('AH',42,'2eb06da778a5e7218451067592f7293180212eaedabada19885460d8c3f6f495','walker-parity-admission-ah','cocs-walker-parity-admission-ah'),('AI',40,'e9f57119b10ac400430573e59253d78e714832743855094013ecba57797abd96','walker-parity-admission-ai','cocs-walker-parity-admission-ai'),('AJ',23,'dc49cc762bb1eab492e480c429c3528d982154943f32332f9e0d35029d5a030f','walker-policy-receipt-probe-aj','cocs-walker-policy-receipt-probe-aj')]:
        root=ROOT.parent/folder;name='tools/godot-multiplayer/new-maps/'+namespace+'/evidence/artifact-inventory.json'
        base.files.verify_archive(root,name,digest,count);r['archives'][tag]={'root':str(root),'manifestSha256':digest,'filesVerified':count}
        for pattern in ['*.uid','*.import']:
            for p in (root/'godot').rglob(pattern):
                if p.is_file():r['sidecars'][str(p)]={'sha256':sha(p),'bytes':p.stat().st_size}
    r['historicalReceipts']={str(p.relative_to(ROOT)):sha(p) for directory in ['walker-parity-admission','walker-policy-source-diagnosis','walker-policy-receipt-probe'] for p in (HERE.parent/directory).glob('*.json')}
    if any(p['pid']!=2598700 for p in r['processes'] if any(n in p['cmdline'].split(' ',1)[0].lower() for n in ['godot','blender'])):raise RuntimeError('unexpected live engine')
    return r
def checkpoint(group):
    r=base.checkpoint(group);text=(STAGE/(group+'.log')).read_text(errors='replace')
    r['admissionFailureLines']=[line for line in text.splitlines() if line.startswith('ADMISSION_FAILURE ')]
    r['inappropriateProbeMarkers']=[line for line in text.splitlines() if 'PROBE_RESULT ' in line or 'PROBE_FAILURE ' in line]
    r['passed']=r['passed'] and not r['admissionFailureLines'] and not r['inappropriateProbeMarkers']
    return r
def release():
    owned=[load(p)['owned'] for p in sorted(STAGE.glob('*-supervisor.json')) if load(p).get('owned')]
    audits=[]
    for _ in range(3):
        row={'utc':utc(),'measured':True,'groups':[{'owned':r,'members':base.runtime.members(r['pgid'])} for r in owned]}
        if any(g['members'] for g in row['groups']):raise RuntimeError('owned group not empty; helper never signals')
        audits.append(row);time.sleep(.2)
    return {'grant':'MOTH-BLENDER-20261004-AK','ownedGroups':owned,'releaseAudits':audits,'lock':base.probe(),'releasedUtc':utc(),'remainingAuthorization':False,'queuedWork':False,'noFurtherEngineInvocations':True}
def analyze():
    before=load(OUT/'before.json');after=load(OUT/'after.json')
    for k in ['viewer','displays','archives','pins','historicalProvenance','historicalReceipts']:assert before[k]==after[k],k
    for n,row in before['sidecars'].items():assert after['sidecars'].get(n)==row,n
    a=load(OUT/'authorization.json');config=base.validate_stage(STAGE)
    for key,n in [('sourceSha256','source.json'),('grantSha256','grant.json')]:assert sha(STAGE/n)==a[key]
    assert sha(Path(a['engine']))==a['engineSha256']
    groups={}
    for group,count in zip(base.GROUPS,base.COUNTS):
        path=STAGE/(group+'-supervisor.json');native=STAGE/(group+'-result.json')
        if not path.exists():groups[group]={'invocations':0,'plannedPairs':count,'unrunPairs':count,'unrunProfiles':count*2};continue
        s=load(path);r=load(native) if native.exists() else None
        groups[group]={'invocations':1,'returnCode':s.get('returnCode'),'failed':s['failed'],'releasedCleanly':s['releasedCleanly'],'nativeReceiptPresent':r is not None,'nativeOutcome':r.get('outcome') if r else None,'instrumentedCounters':{k:v for k,v in r.items() if k.endswith('Pairs') or k.endswith('Profiles')} if r else None,'internalCountersMayBeUnknown':s.get('partialCountersMayBeUnknown',True),'physicalCallCounts':None,'nativeSha256':sha(native) if r else None,'supervisorSha256':sha(path),'logSha256':sha(STAGE/(group+'.log'))}
    write(OUT/'analysis.json',{'utc':utc(),'groups':groups,'qualification':'Native post-return/instrumented counters only. Fatal/interrupted paths may have unknown internal physical calls; missing receipt is not zero work.','sourceSha256':a['sourceSha256'],'grantSha256':a['grantSha256'],'engineSha256':a['engineSha256'],'releasedUtc':load(OUT/'AK-release.json')['releasedUtc'],'nativeRetries':0,'nativeSourceCorrections':0,'candidateMapJourneysRun':0,'productionAccountingOpen':True})
    write(OUT/'preservation.json',{'utc':utc(),'viewerUnchanged':True,'sevenDisplaysUnchanged':len(after['displays'])==7,'archivesVerified':{k:v['filesVerified'] for k,v in after['archives'].items()},'XUVerified':after['frozen'],'preexistingSidecarsVerified':len(before['sidecars']),'newSidecars':{n:v for n,v in after['sidecars'].items() if n not in before['sidecars']},'historicalReceiptsUnchanged':True,'productionDependenciesVerified':15,'stageScriptsVerified':len(config['files'])-1,'noCleanupPerformed':True})
    print(json.dumps(groups,indent=2))
def inventory():
    return {'scope':'AK delivery; inventory self-excluded','files':{str(p.relative_to(ROOT)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(list(HERE.rglob('*'))+list(STAGE.rglob('*'))) if p.is_file() and p.name!='artifact-inventory.json'}}
if __name__=='__main__':
    OUT.mkdir(exist_ok=True);mode=sys.argv[1]
    if mode in ['before','after']:write(OUT/(mode+'.json'),snapshot())
    elif mode=='checkpoint':write(OUT/(sys.argv[2]+'-checkpoint.json'),checkpoint(sys.argv[2]))
    elif mode=='release':write(OUT/'AK-release.json',release())
    elif mode=='analyze':analyze()
    elif mode=='inventory':write(OUT/'artifact-inventory.json',inventory())
    else:raise SystemExit('before|after|checkpoint GROUP|release|analyze|inventory')
