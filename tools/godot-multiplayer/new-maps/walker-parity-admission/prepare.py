"""Future minimal synthetic project. Write-once; no grant, launch or queue."""
import argparse,re
from pathlib import Path
from frozen import files
from policy import PHASE,MODE,GROUPS,COUNTS,successful
from evidence import supervisor_ok
load=files.load;write=files.write;sha=files.sha;digest=files.digest;relative=files.relative
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
PROJECT=files.PROJECT.replace('Single parity response experiment','Synthetic parity admission controls')
def lineage(ag_root,af_root,pins):
    result={}
    for label,root,n in [('AG',ag_root,29),('AF',af_root,24)]:
        files.verify_archive(root,pins[label+'ManifestPath'],pins[label+'ManifestSha256'],n)
        result[label]={'manifestSha256':pins[label+'ManifestSha256'],'filesVerified':n,'producer':pins[label+'Producer']}
    return result
def verify_inputs(root,pins):
    for group in ['stageInputs','hostInputs','productionDependencies']:
        for name,h in pins[group].items():
            if sha(relative(root,name))!=h:raise ValueError('reviewed input drift: '+name)
def build(attempt,ag_root,af_root,*,root=ROOT,stage_parent=None,pins=None):
    root=Path(root).absolute();parent=Path(stage_parent or ROOT/'godot/tests/walker_parity_admission').absolute()
    if root.resolve()!=root or parent.resolve()!=parent or not re.fullmatch(r'parity-admission-[a-z0-9]+(?:-[a-z0-9]+)*',attempt) or len(attempt)>64:raise ValueError('canonical lowercase nonsymlink namespace')
    dest=relative(parent,attempt)
    if dest.exists():raise FileExistsError('write-once attempt')
    pins=pins or load(HERE/'review-pins.json');ancestry=lineage(ag_root,af_root,pins);verify_inputs(root,pins)
    if digest(PROJECT.encode())!=pins['projectSha256']:raise ValueError('project recipe drift')
    data={name[6:]:(root/name).read_bytes() for name in pins['stageInputs']}
    if any(not name.startswith('godot/') for name in pins['stageInputs']):raise ValueError('invalid stage input')
    data['project.godot']=PROJECT.encode();dest.mkdir()
    for name,raw in data.items():
        p=relative(dest,name);p.parent.mkdir(parents=True,exist_ok=True)
        with p.open('xb') as f:f.write(raw)
    write(dest/'source.json',{'phase':PHASE,'mode':MODE,'order':GROUPS,'pairCounts':COUNTS,'attempt':attempt,'lineage':ancestry,'files':{'res://'+n:digest(v) for n,v in data.items()},'hostInputs':pins['hostInputs'],'productionDependencies':pins['productionDependencies'],'reviewPinsSha256':sha(HERE/'review-pins.json'),'grant':None,'autoStart':False,'queueIdentity':None,'queued':False,'nativeStepAdmission':False,'productionPromotion':False})
    return dest
def validate_stage(dest,*,root=ROOT,pins=None):
    dest=Path(dest).absolute();root=Path(root).absolute();pins=pins or load(HERE/'review-pins.json')
    if dest.resolve()!=dest or not re.fullmatch(r'parity-admission-[a-z0-9]+(?:-[a-z0-9]+)*',dest.name) or len(dest.name)>64:raise ValueError('stage namespace')
    c=load(dest/'source.json');verify_inputs(root,pins)
    if c.get('attempt')!=dest.name or c.get('phase')!=PHASE or c.get('mode')!=MODE or c.get('order')!=GROUPS or c.get('pairCounts')!=COUNTS:raise ValueError('source contract')
    if c.get('grant') is not None or c.get('queued') is not False or c.get('autoStart') is not False or c.get('queueIdentity') is not None:raise ValueError('no implicit authority')
    if c.get('reviewPinsSha256')!=sha(HERE/'review-pins.json') or c.get('hostInputs')!=pins['hostInputs'] or c.get('productionDependencies')!=pins['productionDependencies']:raise ValueError('host seal')
    expected={'res://'+n[6:]:v for n,v in pins['stageInputs'].items()};expected['res://project.godot']=pins['projectSha256']
    if c.get('files')!=expected:raise ValueError('stage manifest substitution')
    allowed={n[6:] for n in expected}|{'source.json','grant.json'}|{g+s for g in GROUPS for s in ['-result.json','-supervisor.json','-start.json','-dependencies.json','.log']}
    for p in dest.rglob('*'):
        if p.is_symlink() or (p.is_file() and str(p.relative_to(dest)) not in allowed):raise ValueError('unknown stage file')
    for name,h in expected.items():
        if sha(relative(dest,name[6:]))!=h:raise ValueError('stage bytes drift')
    return c
def dependencies(dest,group,source_hash,grant_hash,engine_hash):
    deps={}
    for prior in GROUPS[:GROUPS.index(group)]:
        result=relative(dest,prior+'-result.json');supervisor=relative(dest,prior+'-supervisor.json')
        r=load(result);s=load(supervisor)
        if not successful(r,prior,source_hash,grant_hash,engine_hash):raise ValueError('incomplete/failed/unbound predecessor')
        if not supervisor_ok(s,prior,source_hash,grant_hash,engine_hash,sha(result)):raise ValueError('inconsistent predecessor supervisor')
        deps[prior]={'resultSha256':sha(result),'supervisorSha256':sha(supervisor)}
    return {'phase':PHASE,'group':group,'sourceSha256':source_hash,'grantSha256':grant_hash,'engineSha256':engine_hash,'predecessors':deps}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__,allow_abbrev=False);p.add_argument('attempt');p.add_argument('--ag-root',required=True);p.add_argument('--af-root',required=True)
    a=p.parse_args();print(build(a.attempt,a.ag_root,a.af_root))
