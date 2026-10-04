"""Write-once minimal source project. No engine/import/grant/queue side effects."""
import argparse,hashlib,json,re
from pathlib import Path
from policy import PHASE,MODE,GROUP
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
PROJECT='''config_version=5
[application]
config/name="Read-only snap query comparison"
[physics]
common/physics_ticks_per_second=60
[threading]
worker_pool/max_threads=1
[rendering]
renderer/rendering_method="gl_compatibility"
'''
def digest(data):return hashlib.sha256(data).hexdigest()
def sha(path):return digest(path.read_bytes())
def load(path):
    def unique(pairs):
        result={}
        for key,value in pairs:
            if key in result:raise ValueError('duplicate JSON key: '+key)
            result[key]=value
        return result
    return json.loads(path.read_text(),object_pairs_hook=unique,parse_constant=lambda value:(_ for _ in ()).throw(ValueError(value)))
def write(path,value):
    with path.open('x') as f:json.dump(value,f,indent=2,allow_nan=False);f.write('\n')
def relative(root,name):
    if not isinstance(name,str) or not name or '\\' in name:raise ValueError('invalid relative path')
    p=Path(name)
    if p.is_absolute() or any(part in ['.','..'] for part in p.parts) or str(p)!=name:raise ValueError('noncanonical relative path')
    path=root/p
    if path.resolve()!=path.absolute():raise ValueError('symlink path refused')
    if not path.is_relative_to(root):raise ValueError('path escape')
    return path
def verify_archive(root,manifest_path,expected_sha,count):
    root=Path(root).absolute()
    if root.resolve()!=root:raise ValueError('symlink archive root')
    manifest=relative(root,manifest_path)
    if sha(manifest)!=expected_sha:raise ValueError('frozen AE manifest mismatch')
    records=load(manifest)['files']
    if len(records)!=count:raise ValueError('frozen inventory count')
    for name,row in records.items():
        path=relative(root,name)
        if sha(path)!=row['sha256'] or path.stat().st_size!=row['bytes']:raise ValueError('frozen AE file mismatch: '+name)
    return {'manifestSha256':expected_sha,'filesVerified':count,'producer':'c0761dbe'}
def build(attempt,ae_root,*,root=ROOT,stage_parent=None,pins=None):
    root=Path(root).absolute();stage_parent=Path(stage_parent or ROOT/'godot/tests/walker_snap_compare').absolute()
    if root.resolve()!=root or stage_parent.resolve()!=stage_parent:raise ValueError('symlink root')
    if not re.fullmatch(r'snap-compare-[a-z0-9]+(?:-[a-z0-9]+)*',attempt) or len(attempt)>64:raise ValueError('lowercase canonical attempt required')
    dest=relative(stage_parent,attempt)
    if dest.exists():raise FileExistsError('write-once stage exists')
    pins=pins if pins is not None else load(HERE/'review-pins.json')
    lineage=verify_archive(ae_root,pins['AEManifestPath'],pins['AEManifestSha256'],46)
    for name,h in pins['hostInputs'].items():
        if sha(relative(root,name))!=h:raise ValueError('reviewed host wiring drift: '+name)
    scripts={}
    for name,h in pins['stageInputs'].items():
        p=relative(root,name)
        if sha(p)!=h:raise ValueError('reviewed source pin drift: '+name)
        if not name.startswith('godot/'):raise ValueError('non-Godot stage input')
        scripts[name[6:]]=p.read_bytes()
    for name,h in pins['productionDependencies'].items():
        if sha(relative(root,name))!=h:raise ValueError('production dependency drift: '+name)
    if pins['projectSha256']!=digest(PROJECT.encode()):raise ValueError('minimal project recipe drift')
    # Verify everything before first write. No fixture output/result/grant is invented.
    dest.mkdir()
    scripts['project.godot']=PROJECT.encode()
    for name,data in scripts.items():
        p=relative(dest,name);p.parent.mkdir(parents=True,exist_ok=True)
        with p.open('xb') as f:f.write(data)
    receipt={'phase':PHASE,'mode':MODE,'allowedGroups':[GROUP],'attempt':attempt,'grant':None,'autoStart':False,'queued':False,
        'AEIdentity':lineage,'files':{'res://'+name:digest(data) for name,data in scripts.items()},
        'productionDependencies':pins['productionDependencies'],'hostInputs':pins['hostInputs'],'reviewPinsSha256':sha(HERE/'review-pins.json'),
        'comparisonOnly':True,'nativeStepAdmission':False,'candidateMapWalksAllowed':False}
    write(dest/'source.json',receipt)
    return dest
def validate_stage(dest,*,root=ROOT,pins=None):
    dest=Path(dest).absolute();root=Path(root).absolute()
    if dest.resolve()!=dest:raise ValueError('symlink stage')
    pins=pins if pins is not None else load(HERE/'review-pins.json')
    config=load(dest/'source.json')
    if config.get('reviewPinsSha256')!=sha(HERE/'review-pins.json') or config.get('hostInputs')!=pins['hostInputs']:raise ValueError('host source receipt substitution')
    for name,h in pins['hostInputs'].items():
        if sha(relative(root,name))!=h:raise ValueError('reviewed host wiring drift: '+name)
    if not re.fullmatch(r'snap-compare-[a-z0-9]+(?:-[a-z0-9]+)*',dest.name) or len(dest.name)>64 or config.get('attempt')!=dest.name:raise ValueError('stage attempt namespace')
    if config.get('phase')!=PHASE or config.get('mode')!=MODE or config.get('allowedGroups')!=[GROUP] or config.get('grant') is not None or config.get('queued') is not False or config.get('autoStart') is not False:raise ValueError('stage policy drift')
    expected={'res://'+name[6:]:h for name,h in pins['stageInputs'].items()}
    expected['res://project.godot']=pins['projectSha256']
    allowed={name[6:] for name in expected}|{'source.json','grant.json'}
    for path in dest.rglob('*'):
        if path.is_symlink() or (path.is_file() and str(path.relative_to(dest)) not in allowed):raise ValueError('unexpected staged file or symlink')
    if config.get('files')!=expected or config.get('productionDependencies')!=pins['productionDependencies']:raise ValueError('stage manifest substitution')
    for name,h in expected.items():
        if sha(relative(dest,name[6:]))!=h:raise ValueError('staged bytes drift: '+name)
    for name,h in pins['productionDependencies'].items():
        if sha(relative(root,name))!=h:raise ValueError('production dependency drift')
    return config
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__,allow_abbrev=False);p.add_argument('attempt');p.add_argument('--ae-root',required=True)
    a=p.parse_args();print(build(a.attempt,a.ae_root))
