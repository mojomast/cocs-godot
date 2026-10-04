"""AL read-only preservation, receipt replay, release audits and inventory. No launch."""
import datetime,fcntl,hashlib,json,shutil,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];OUT=HERE/'evidence'
sys.path.insert(0,str(HERE.parent/'walker-baseline-characterization-run'))
from prepare import load,write,sha,validate_stage
from frozen import runtime
from verify_preservation import verify
from policy import GROUP,successful,MATRIX
STAGE=ROOT/'godot/tests/walker_baseline_characterization/baseline-characterization-al-01'
LOCK=Path('/tmp/opencode/cocs-finish-acceptance.lock')
VIEWER={'pid':2598700,'pgid':2598689,'startTicks':522477875}
def utc():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def probe():
    with LOCK.open('a+') as f:
        fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
        return {'available':True,'measuredUtc':utc()}
def snapshot():
    preservation=verify();viewer=runtime.identity(VIEWER['pid'])
    if viewer!=VIEWER:raise ValueError('viewer identity changed')
    processes=[]
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            row=runtime.identity(int(p.name))
            if row:row['cmdline']=(p/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace');processes.append(row)
        except (FileNotFoundError,ProcessLookupError):pass
    processes.sort(key=lambda r:r['pid'])
    engines=[r for r in processes if any(s in r['cmdline'].split(' ',1)[0].lower() for s in ['godot','blender'])]
    if any(r['pid']!=VIEWER['pid'] for r in engines):raise RuntimeError('unexpected live engine')
    displays=[r for r in processes if r['cmdline'].split(' ',1)[0].rsplit('/',1)[-1] in ['Xorg','Xvfb','Xephyr','Xwayland','weston']]
    if len(displays)!=7:raise ValueError('display census')
    history=load(HERE.parent/'walker-parity-admission/source-provenance.json')
    roots={ROOT,*[Path(r['root']) for r in history['archives'].values()]}
    roots.update(ROOT.parent/n for n in ['cocs-botanical-source-correction','cocs-map-variety-botanical-astra','cocs-walker-parity-admission','cocs-walker-parity-response','cocs-walker-snap-parity','cocs-walker-parity-admission-ah','cocs-walker-parity-admission-ai','cocs-walker-policy-receipt-probe-aj','cocs-walker-parity-admission-ak','cocs-walker-baseline-characterization-design'])
    sidecars={}
    for base in sorted(roots):
        for pattern in ['*.uid','*.import']:
            for p in sorted((base/'godot').rglob(pattern)):
                if p.is_file():sidecars[str(p)]={'sha256':sha(p),'bytes':p.stat().st_size}
    receipts={str(p.relative_to(ROOT)):sha(p) for directory in ['walker-parity-admission','walker-policy-source-diagnosis','walker-policy-receipt-probe','walker-baseline-characterization','walker-baseline-characterization-run'] for p in sorted((HERE.parent/directory).glob('*.json'))}
    delivery=load(HERE.parent/'walker-baseline-characterization-run/source-receipt.json')
    for n,h in delivery['files'].items():
        if sha(ROOT/n)!=h:raise ValueError('approved delivery drift: '+n)
    return {'utc':utc(),'preservation':preservation,'viewer':viewer,'displays':displays,'processes':processes,'sidecars':sidecars,'historicalReceipts':receipts,'approvedDeliveryHashesVerified':len(delivery['files']),'lock':probe(),'disk':{str(p):dict(zip(['total','used','free'],shutil.disk_usage(p))) for p in [ROOT,Path('/tmp/opencode')]}}
def release():
    reports=[load(p) for p in STAGE.glob('*-supervisor.json')]
    if len(reports)!=1 or not reports[0].get('owned'):raise ValueError('sole invocation ownership unavailable')
    owned=[reports[0]['owned']];audits=[]
    for _ in range(3):
        row={'utc':utc(),'measured':True,'groups':[{'owned':o,'members':runtime.members(o['pgid'])} for o in owned]}
        if any(g['members'] for g in row['groups']):raise ValueError('owned group not empty; helper never signals')
        audits.append(row);time.sleep(.2)
    return {'grant':'MOTH-BLENDER-20261004-AL','ownedGroups':owned,'releaseAudits':audits,'lock':probe(),'releasedUtc':utc(),'remainingAuthorization':False,'queuedWork':False,'noFurtherEngineInvocations':True}
def analyze():
    before=load(OUT/'before.json');after=load(OUT/'after.json')
    for key in ['preservation','viewer','displays','historicalReceipts','approvedDeliveryHashesVerified']:
        if before[key]!=after[key]:raise ValueError('preservation difference: '+key)
    for n,r in before['sidecars'].items():
        if after['sidecars'].get(n)!=r:raise ValueError('sidecar drift: '+n)
    validate_stage(STAGE);a=load(OUT/'authorization.json');s=load(STAGE/(GROUP+'-supervisor.json'));path=STAGE/(GROUP+'-result.json');r=load(path) if path.exists() else None
    for key,n in [('sourceSha256','source.json'),('grantSha256','grant.json')]:
        if sha(STAGE/n)!=a[key]:raise ValueError('authorization binding')
    if sha(Path(a['engine']))!=a['engineSha256']:raise ValueError('binary drift')
    text=(STAGE/(GROUP+'.log')).read_text(errors='replace')
    report={'utc':utc(),'invocations':1,'nativeReceiptPresent':r is not None,'nativeStrictPythonReplay':successful(r,a['sourceSha256'],a['grantSha256'],a['engineSha256']),'nativeReturnCode':s.get('returnCode'),'supervisorFailed':s['failed'],'releasedCleanly':s['releasedCleanly'],'partialCountersMayBeUnknown':s['partialCountersMayBeUnknown'],'physicalCallCounts':None,'nativeOutcome':r.get('outcome') if r else None,'nativeFaultCode':r.get('faultCode') if r else None,'nativeSha256':sha(path) if r else None,'supervisorSha256':sha(STAGE/(GROUP+'-supervisor.json')),'logSha256':sha(STAGE/(GROUP+'.log')),'markers':[line for line in text.splitlines() if any(x in line for x in ['ADMISSION_FAILURE ','SCRIPT ERROR:','Parse Error:','ERROR:'])],'records':[],'selectedHeight':None,'candidateAdmission':False,'productionPromotion':False,'nativeRetries':0,'sourceCorrections':0,'candidateMapJourneysRun':0,'productionMotionAccountingOpen':True}
    for i,spec in enumerate(MATRIX):
        p=r['records'][i] if r and len(r.get('records',[]))>i else None
        report['records'].append({'caseIndex':i,'spec':spec,'nativeStatus':p.get('status') if p else None,'outcome':p.get('outcome') if p else None,'settleReturnedRecords':len(p.get('settle',[])) if p else None,'inputReturnedRecords':len(p.get('frames',[])) if p else None,'qualification':'native records' if p else 'no native profile evidence; physical work unknown'})
    report['releasedUtc']=load(OUT/'AL-release.json')['releasedUtc'];write(OUT/'analysis.json',report)
    write(OUT/'preservation.json',{'utc':utc(),**after['preservation'],'viewerUnchanged':True,'sevenDisplaysUnchanged':True,'historicalReceiptsUnchanged':True,'preexistingSidecarsVerified':len(before['sidecars']),'newSidecars':{n:v for n,v in after['sidecars'].items() if n not in before['sidecars']},'approvedDeliveryHashesVerified':15,'noCleanupPerformed':True})
    print(json.dumps(report,indent=2))
def inventory():
    return {'scope':'AL delivery; this inventory self-excluded','files':{str(p.relative_to(ROOT)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(list(HERE.rglob('*'))+list(STAGE.rglob('*'))) if p.is_file() and p.name!='artifact-inventory.json'}}
if __name__=='__main__':
    OUT.mkdir(exist_ok=True);mode=sys.argv[1]
    if mode in ['before','after']:write(OUT/(mode+'.json'),snapshot())
    elif mode=='release':write(OUT/'AL-release.json',release())
    elif mode=='analyze':analyze()
    elif mode=='inventory':write(OUT/'artifact-inventory.json',inventory())
    else:raise SystemExit('before|after|release|analyze|inventory')
