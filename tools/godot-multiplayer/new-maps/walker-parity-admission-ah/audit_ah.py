"""AH read-only inspection/preservation helpers. No launch, grant creation or retry."""
import datetime,fcntl,hashlib,json,os,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-parity-admission'))
from prepare import files,load,write,validate_stage,dependencies
from policy import GROUPS,COUNTS,successful
from evidence import supervisor_ok
from frozen import runtime
OUT=HERE/'evidence';STAGE=ROOT/'godot/tests/walker_parity_admission/parity-admission-ah-01'
LOCK=Path('/tmp/opencode/cocs-finish-acceptance.lock')
def utc():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def probe():
    with LOCK.open('a+') as f:
        fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
        return {'available':True,'measuredUtc':utc()}
def snapshot():
    history=load(HERE.parent/'walker-parity-admission/source-provenance.json')
    names={'AG':'walker-parity-response-ag/evidence/artifact-inventory.json','AF':'walker-snap-compare-af/evidence/artifact-inventory.json','AE':'walker-admission-ae/evidence/artifact-inventory.json','AD':'walker-admission-ad/evidence/artifact-inventory.json','AB':'walker-step-ab/evidence/artifact-inventory.json','Z':'botanical-native-z/evidence/artifact-inventory.json','AA':'parallax-observatory/revisions/districts-v4-tangent/native/AA_MANIFEST.json','AC':'parallax-observatory/revisions/districts-v4-glyph-tangents/native/AC_MANIFEST.json'}
    for key,row in history['archives'].items():files.verify_archive(row['root'],'tools/godot-multiplayer/new-maps/'+names[key],row['manifestSha256'],row['filesVerified'])
    os.environ['COCS_BOTANICAL_X_FIXTURE_ROOT']='/home/mojo/.tmp-on-disk/cocs-botanical-source-correction'
    os.environ['COCS_BOTANICAL_U_FIXTURE_ROOT']='/home/mojo/.tmp-on-disk/cocs-map-variety-botanical-astra'
    sys.path.insert(0,str(HERE.parent/'botanical-post-x'));from verify_frozen import verify
    frozen=verify();pins=load(HERE.parent/'walker-parity-admission/review-pins.json')
    for name,h in {**pins['productionDependencies'],**pins['stageInputs'],**pins['hostInputs'],**history['historicalProvenanceUnchanged']}.items():
        if sha(ROOT/name)!=h:raise ValueError('pin drift: '+name)
    viewer=runtime.identity(2598700)
    if viewer!={'pid':2598700,'pgid':2598689,'startTicks':522477875}:raise ValueError('viewer identity changed')
    processes=[]
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            row=runtime.identity(int(p.name))
            if row:row['cmdline']=(p/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace');processes.append(row)
        except (FileNotFoundError,ProcessLookupError):pass
    displays=[r for r in processes if r['cmdline'].split(' ',1)[0].rsplit('/',1)[-1] in ['Xorg','Xvfb','Xephyr','Xwayland','weston']]
    roots={ROOT,*[Path(r['root']) for r in history['archives'].values()],Path(os.environ['COCS_BOTANICAL_X_FIXTURE_ROOT']),Path(os.environ['COCS_BOTANICAL_U_FIXTURE_ROOT'])}
    roots.update(ROOT.parent/n for n in ['cocs-walker-parity-admission','cocs-walker-parity-response','cocs-walker-snap-parity'])
    sidecars={}
    for base in roots:
        for pattern in ['*.uid','*.import']:
            for p in (base/'godot').rglob(pattern):
                if p.is_file():sidecars[str(p)]={'sha256':sha(p),'bytes':p.stat().st_size}
    return {'utc':utc(),'viewer':viewer,'displays':displays,'processes':processes,'sidecars':sidecars,'archives':history['archives'],'frozen':frozen,'pins':pins,'historicalProvenance':history['historicalProvenanceUnchanged'],'lock':probe()}
def checkpoint(group):
    config=validate_stage(STAGE);grant=load(STAGE/'grant.json');engine=Path(load(OUT/'authorization.json')['engine'])
    hashes={'sourceSha256':sha(STAGE/'source.json'),'grantSha256':sha(STAGE/'grant.json'),'engineSha256':sha(engine)}
    result=STAGE/(group+'-result.json');sup=STAGE/(group+'-supervisor.json');r=load(result) if result.exists() else {};s=load(sup)
    native_ok=successful(r,group,hashes['sourceSha256'],hashes['grantSha256'],hashes['engineSha256'])
    host_ok=supervisor_ok(s,group,hashes['sourceSha256'],hashes['grantSha256'],hashes['engineSha256'],sha(result) if result.exists() else None)
    log=(STAGE/(group+'.log')).read_text(errors='replace');errors=[line for line in log.splitlines() if any(x in line for x in ['SCRIPT ERROR','Parse Error','ERROR:'])]
    report={'utc':utc(),'group':group,**hashes,'nativeSha256':sha(result) if result.exists() else None,'supervisorSha256':sha(sup),'logSha256':sha(STAGE/(group+'.log')),'nativeStrictReplay':native_ok,'supervisorStrictReplay':host_ok,'logErrors':errors,'banner':log.splitlines()[:3],'passed':native_ok and host_ok and not errors,'records':[],'nativeCounters':{k:v for k,v in r.items() if k.endswith('Pairs') or k.endswith('Profiles')},'notes':'Strict predicate replay only; owner must inspect raw records and save inspection notes before any next invocation.'}
    for row in r.get('records',[]):
        report['records'].append({'caseIndex':row.get('caseIndex'),'spec':row.get('spec'),'status':row.get('status'),'profiles':[{'experimental':p.get('experimental'),'status':p.get('status'),'outcome':p.get('outcome'),'settles':len(p.get('settle',[])),'frames':len(p.get('frames',[])),'applied':p.get('appliedUpCount'),'verified':p.get('verifiedLifts'),'finalReason':p.get('frames',[{}])[-1].get('proposal',{}).get('reason') if p.get('frames') else None} for p in row.get('profiles',[])]})
    if report['passed'] and group!=GROUPS[-1]:report['nextDependencyReplay']=dependencies(STAGE,GROUPS[GROUPS.index(group)+1],**dict(source_hash=hashes['sourceSha256'],grant_hash=hashes['grantSha256'],engine_hash=hashes['engineSha256']))
    return report
def release():
    owned=[load(p)['owned'] for p in sorted(STAGE.glob('*-supervisor.json')) if load(p).get('owned')]
    audits=[]
    for _ in range(3):
        audit={'utc':utc(),'measured':True,'groups':[{'owned':r,'members':runtime.members(r['pgid'])} for r in owned]}
        if any(g['members'] for g in audit['groups']):raise RuntimeError('owned group not empty; no signaling by this helper')
        audits.append(audit);time.sleep(.2)
    return {'grant':'MOTH-BLENDER-20261004-AH','ownedGroups':owned,'releaseAudits':audits,'lock':probe(),'releasedUtc':utc(),'queuedWork':False,'remainingAuthorization':False,'noFurtherEngineInvocations':True}
def inventory():
    return {'scope':'AH delivery; inventory self-excluded','files':{str(p.relative_to(ROOT)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(list(HERE.rglob('*'))+list(STAGE.rglob('*'))) if p.is_file() and p.name!='artifact-inventory.json'}}
if __name__=='__main__':
    OUT.mkdir(exist_ok=True)
    mode=sys.argv[1]
    if mode in ['before','after']:write(OUT/(mode+'.json'),snapshot())
    elif mode=='checkpoint':write(OUT/(sys.argv[2]+'-checkpoint.json'),checkpoint(sys.argv[2]))
    elif mode=='release':write(OUT/'AH-release.json',release())
    elif mode=='inventory':write(OUT/'artifact-inventory.json',inventory())
    else:raise SystemExit('before|after|checkpoint GROUP|release|inventory')
