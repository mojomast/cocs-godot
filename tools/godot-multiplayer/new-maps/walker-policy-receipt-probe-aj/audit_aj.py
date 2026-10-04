"""Read-only preservation/post-exit analysis. Never launches or stages an engine."""
import importlib.util,json,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];OUT=HERE/'evidence'
STAGE=ROOT/'godot/tests/walker_policy_receipt_probe/policy-receipt-probe-aj-01'
spec=importlib.util.spec_from_file_location('_aj_archive_base',HERE.parent/'walker-parity-admission-ah/audit_ah.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.HERE=HERE;base.ROOT=ROOT
load=base.load;write=base.write;sha=base.sha;utc=base.utc
def snapshot():
    r=base.snapshot()
    for tag,count,digest in [('AI',40,'e9f57119b10ac400430573e59253d78e714832743855094013ecba57797abd96'),('AH',42,'2eb06da778a5e7218451067592f7293180212eaedabada19885460d8c3f6f495')]:
        root=ROOT.parent/('cocs-walker-parity-admission-'+tag.lower());name='tools/godot-multiplayer/new-maps/walker-parity-admission-'+tag.lower()+'/evidence/artifact-inventory.json'
        base.files.verify_archive(root,name,digest,count)
        r['archives'][tag]={'root':str(root),'manifestSha256':digest,'filesVerified':count}
    for root in [ROOT.parent/n for n in ['cocs-walker-parity-admission-ai','cocs-walker-parity-admission-ah','cocs-walker-policy-source-diagnosis','cocs-walker-policy-receipt-probe']]:
        for pattern in ['*.uid','*.import']:
            for p in (root/'godot').rglob(pattern):
                if p.is_file():r['sidecars'][str(p)]={'sha256':sha(p),'bytes':p.stat().st_size}
    r['historicalReceipts']={str(p.relative_to(ROOT)):sha(p) for directory in ['walker-parity-admission','walker-policy-source-diagnosis','walker-policy-receipt-probe'] for p in (HERE.parent/directory).glob('*.json')}
    r['reviewedProbeFiles']={str(p.relative_to(ROOT)):sha(p) for p in (HERE.parent/'walker-policy-receipt-probe').glob('*') if p.is_file()}
    if any(p['pid']!=2598700 for p in r['processes'] if any(n in p['cmdline'].split(' ',1)[0].lower() for n in ['godot','blender'])):raise RuntimeError('unexpected live engine')
    return r
def release():
    s=load(STAGE/'probe-supervisor.json');owned=s.get('owned')
    if not owned:raise RuntimeError('no recorded owned identity; manual investigation required')
    audits=[]
    for _ in range(3):
        members=base.runtime.members(owned['pgid'])
        audits.append({'utc':utc(),'measured':True,'owned':owned,'members':members})
        if members:raise RuntimeError('owned group nonempty; helper never signals')
        time.sleep(.2)
    return {'grant':'MOTH-BLENDER-20261004-AJ','ownedGroups':[owned],'releaseAudits':audits,'lock':base.probe(),'releasedUtc':utc(),'remainingAuthorization':False,'queuedWork':False,'noFurtherEngineInvocations':True}
def analyze():
    before=load(OUT/'before.json');after=load(OUT/'after.json')
    for k in ['viewer','displays','archives','pins','historicalProvenance','historicalReceipts','reviewedProbeFiles']:assert before[k]==after[k],k
    for n,row in before['sidecars'].items():assert after['sidecars'].get(n)==row,n
    a=load(OUT/'authorization.json');config=load(STAGE/'source.json');s=load(STAGE/'probe-supervisor.json')
    for n,h in config['files'].items():assert sha(STAGE/n)==h,n
    for key,n in [('sourceSha256','source.json'),('grantSha256','grant.json')]:assert sha(STAGE/n)==a[key]==s[key]
    assert sha(Path(a['engine']))==s['engineSha256']==a['engineSha256']
    text=(STAGE/'probe.log').read_text(errors='replace');lines=[line for line in text.splitlines() if line.startswith('PROBE_RESULT ')]
    native=load(STAGE/'probe-result.json') if (STAGE/'probe-result.json').exists() else None
    valid=False
    if native is not None:
        sys.path.insert(0,str(HERE.parent/'walker-policy-receipt-probe'));import contract as C
        valid=C.collected(native,a['sourceSha256'],a['grantSha256'],a['engineSha256'],config['files']['probe/cloned_policy.gd'],config['files']['probe/cloned_evidence.gd'])
        assert len(lines)==1 and json.loads(lines[0][13:])==native and valid
    write(OUT/'analysis.json',{'utc':utc(),'phase':'policy-receipt-probe-v1','invocations':1,'supervisorFailed':s['failed'],'nativeReturnCode':s.get('returnCode'),'nativeReceiptPresent':native is not None,'hostCollectionReplay':valid,'observations':native,'rawResultLines':lines,'logErrors':[line for line in text.splitlines() if any(x in line for x in ['SCRIPT ERROR','Parse Error','PROBE_FAILURE','ADMISSION_FAILURE'])],'qualification':'Receipt-only native observations. Helper locates independent invariant, not first executed rejection. Original AI/AH failed results and unknown counters unchanged. No pre/post serialization immutability measurement claimed.','releasedUtc':load(OUT/'AJ-release.json')['releasedUtc'],'positivePairsUnrun':4,'positiveProfilesUnrun':8,'candidateMapJourneysUnrun':60,'productionAccountingOpen':True,'noRetry':True,'noSourceCorrection':True})
    write(OUT/'preservation.json',{'utc':utc(),'viewerUnchanged':True,'sevenDisplaysUnchanged':len(after['displays'])==7,'archivesVerified':{k:v['filesVerified'] for k,v in after['archives'].items()},'XUVerified':after['frozen'],'preexistingSidecarsVerified':len(before['sidecars']),'newSidecars':{n:v for n,v in after['sidecars'].items() if n not in before['sidecars']},'historicalReceiptsAndReviewedProbeUnchanged':True,'productionDependenciesVerified':15,'stageScriptsVerified':sum(n.endswith('.gd') for n in config['files']),'noCleanupPerformed':True})
    print(json.dumps({'supervisorFailed':s['failed'],'nativeReturnCode':s.get('returnCode'),'native':native},indent=2))
def inventory():
    return {'scope':'AJ delivery, inventory self-excluded','files':{str(p.relative_to(ROOT)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(list(HERE.rglob('*'))+list(STAGE.rglob('*'))) if p.is_file() and p.name!='artifact-inventory.json'}}
if __name__=='__main__':
    OUT.mkdir(exist_ok=True);mode=sys.argv[1]
    if mode in ['before','after']:write(OUT/(mode+'.json'),snapshot())
    elif mode=='release':write(OUT/'AJ-release.json',release())
    elif mode=='analyze':analyze()
    elif mode=='inventory':write(OUT/'artifact-inventory.json',inventory())
    else:raise SystemExit('before|after|release|analyze|inventory')
