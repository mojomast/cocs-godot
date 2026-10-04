"""AF read-only preservation snapshots and write-once evidence inventory. No launcher."""
import datetime,hashlib,json,os,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-snap-compare'))
from prepare import load,write,verify_archive
from supervisor import identity
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
    historic=load(HERE.parent/'walker-snap-compare/wiring-provenance.json')
    names={'AE':'walker-admission-ae/evidence/artifact-inventory.json','AD':'walker-admission-ad/evidence/artifact-inventory.json','AB':'walker-step-ab/evidence/artifact-inventory.json','Z':'botanical-native-z/evidence/artifact-inventory.json','AA':'parallax-observatory/revisions/districts-v4-tangent/native/AA_MANIFEST.json','AC':'parallax-observatory/revisions/districts-v4-glyph-tangents/native/AC_MANIFEST.json'}
    for label,row in historic['archives'].items():verify_archive(row['root'],'tools/godot-multiplayer/new-maps/'+names[label],row['manifestSha256'],row['filesVerified'])
    os.environ['COCS_BOTANICAL_X_FIXTURE_ROOT']='/home/mojo/.tmp-on-disk/cocs-botanical-source-correction'
    os.environ['COCS_BOTANICAL_U_FIXTURE_ROOT']='/home/mojo/.tmp-on-disk/cocs-map-variety-botanical-astra'
    sys.path.insert(0,str(HERE.parent/'botanical-post-x'));from verify_frozen import verify
    frozen=verify()
    pins=load(HERE.parent/'walker-snap-compare/review-pins.json')
    for name,h in {**pins['productionDependencies'],**pins['stageInputs'],**pins['hostInputs']}.items():
        if sha(ROOT/name)!=h:raise ValueError('pin drift: '+name)
    viewer=identity(2598700)
    if viewer!={'pid':2598700,'pgid':2598689,'startTicks':522477875}:raise ValueError('preserved viewer identity changed')
    processes=[]
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            row=identity(int(p.name))
            if row:row['cmdline']=(p/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace');processes.append(row)
        except (FileNotFoundError,ProcessLookupError,PermissionError):pass
    displays=[r for r in processes if r['cmdline'].split(' ',1)[0].rsplit('/',1)[-1] in ['Xorg','Xvfb','Xephyr','Xwayland','weston']]
    sidecars={}
    for base in [ROOT,Path(historic['archives']['AE']['root'])]:
        for pattern in ['*.uid','*.import']:
            for p in (base/'godot').rglob(pattern):
                if p.is_file():sidecars[str(p)]={'sha256':sha(p),'bytes':p.stat().st_size}
    return {'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'unix':time.time(),'viewer':viewer,'displays':displays,'processes':processes,'sidecars':sidecars,'archives':historic['archives'],'frozen':frozen,'productionDependencies':pins['productionDependencies'],'stageInputs':pins['stageInputs'],'hostInputs':pins['hostInputs']}
def inventory():
    stage=ROOT/'godot/tests/walker_snap_compare/snap-compare-af-01'
    files=list(HERE.rglob('*'))+list(stage.rglob('*'))
    return {'scope':'AF exact file inventory; excludes inventory itself','files':{str(p.relative_to(ROOT)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(files) if p.is_file() and p.name!='artifact-inventory.json'}}
if __name__=='__main__':
    if len(sys.argv)!=2 or sys.argv[1] not in ['before','after','inventory']:raise SystemExit('before|after|inventory')
    mode=sys.argv[1];dest=HERE/'evidence';dest.mkdir(exist_ok=True)
    write(dest/('artifact-inventory.json' if mode=='inventory' else mode+'.json'),inventory() if mode=='inventory' else snapshot())
