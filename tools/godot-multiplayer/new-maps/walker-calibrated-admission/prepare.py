"""Explicit future write-once stage. No grant writer, execution or group loop."""
import argparse,re
from pathlib import Path
from .frozen import files
from .policy import PHASE,MODE,GROUPS,COUNTS,successful
from .evidence import canonical,supervisor_ok
from .derive_sources import lineage as lineage_identity
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
load=files.load;write=files.write;sha=files.sha;digest=files.digest;relative=files.relative
PROJECT=files.PROJECT.replace('Single parity response experiment','Calibrated parity admission v1')
ARCHIVES={
 'AL':('tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/evidence/artifact-inventory.json','bef580de4e1605446425927bf9ee3f07dfb61992bfd6bb50af48369db7f738b5',33),
 'AK':('tools/godot-multiplayer/new-maps/walker-parity-admission-ak/evidence/artifact-inventory.json','827dd68b00c400b7ec17f9ab0e5a2067929277c3bb22e1681d38a1d5143a5ee1',51)}
def lineage(al_root,ak_root):
    for tag,root in [('AL',al_root),('AK',ak_root)]:files.verify_archive(root,*ARCHIVES[tag])
    return lineage_identity()
def verify_inputs(root,pins):
    for group in ['stageInputs','hostInputs','productionDependencies','preservedInputs']:
        for n,h in pins[group].items():
            if sha(relative(root,n))!=h:raise ValueError('reviewed input drift: '+n)
    if pins['projectSha256']!=digest(PROJECT.encode()):raise ValueError('project recipe')
def namespace(dest):
    if dest.resolve()!=dest or not re.fullmatch(r'calibrated-admission-[a-z0-9]+(?:-[a-z0-9]+)*',dest.name) or len(dest.name)>64:raise ValueError('canonical calibrated namespace')
def source(attempt,pins):
    return {'phase':PHASE,'mode':MODE,'order':GROUPS,'pairCounts':COUNTS,'positiveCases':canonical(GROUPS[2]),'attempt':attempt,'lineage':lineage_identity(),'files':{'res://'+n[6:]:h for n,h in pins['stageInputs'].items()}|{'res://project.godot':pins['projectSha256']},'hostInputs':pins['hostInputs'],'productionDependencies':pins['productionDependencies'],'preservedInputs':pins['preservedInputs'],'reviewPinsSha256':sha(HERE/'review-pins.json'),'grant':None,'autoStart':False,'queueIdentity':None,'queued':False,'nativeStepAdmission':False,'productionPromotion':False}
def build(attempt,al_root,ak_root,*,root=ROOT,stage_parent=None):
    root=Path(root).absolute();parent=Path(stage_parent or root/'godot/tests/walker_calibrated_admission').absolute();dest=relative(parent,attempt);namespace(dest)
    if dest.exists():raise FileExistsError('write-once attempt')
    pins=load(HERE/'review-pins.json');verify_inputs(root,pins);lineage(al_root,ak_root)
    data={n[6:]:(root/n).read_bytes() for n in pins['stageInputs']};data['project.godot']=PROJECT.encode();config=source(attempt,pins)
    dest.mkdir()
    for n,raw in data.items():
        p=relative(dest,n);p.parent.mkdir(parents=True,exist_ok=True)
        with p.open('xb') as f:f.write(raw)
    write(dest/'source.json',config);return dest
def validate_stage(dest,*,root=ROOT):
    dest=Path(dest).absolute();namespace(dest);pins=load(HERE/'review-pins.json');verify_inputs(Path(root),pins);c=load(dest/'source.json')
    if c!=source(dest.name,pins) or any(c[k] is not False for k in ['autoStart','queued','nativeStepAdmission','productionPromotion']):raise ValueError('exact source contract')
    allowed={n[6:] for n in c['files']}|{'source.json','grant.json'}|{g+s for g in GROUPS for s in ['-result.json','-supervisor.json','-start.json','-dependencies.json','.log']}
    for p in dest.rglob('*'):
        if p.is_symlink() or (p.is_file() and str(p.relative_to(dest)) not in allowed):raise ValueError('unexpected stage file')
    for n,h in c['files'].items():
        if sha(relative(dest,n[6:]))!=h:raise ValueError('staged hash drift')
    return c
def dependencies(dest,group,source_hash,grant_hash,engine_hash):
    if group not in GROUPS:raise ValueError('unknown group')
    deps={}
    for prior in GROUPS[:GROUPS.index(group)]:
        result=relative(dest,prior+'-result.json');supervisor=relative(dest,prior+'-supervisor.json')
        r=load(result);s=load(supervisor)
        if not successful(r,prior,source_hash,grant_hash,engine_hash):raise ValueError('fresh complete calibrated predecessor required')
        if not supervisor_ok(s,prior,source_hash,grant_hash,engine_hash,sha(result)):raise ValueError('predecessor release/error/hash binding')
        text=relative(dest,prior+'.log').read_text(errors='replace')
        if any(marker in text for marker in ['SCRIPT ERROR:','Parse Error:','ADMISSION_FAILURE ']):raise ValueError('predecessor raw log error')
        deps[prior]={'resultSha256':sha(result),'supervisorSha256':sha(supervisor)}
    return {'phase':PHASE,'group':group,'sourceSha256':source_hash,'grantSha256':grant_hash,'engineSha256':engine_hash,'predecessors':deps}
def cli():
    parser=argparse.ArgumentParser(description=__doc__,allow_abbrev=False);parser.add_argument('attempt');parser.add_argument('--al-root',required=True);parser.add_argument('--ak-root',required=True)
    a=parser.parse_args();print(build(a.attempt,a.al_root,a.ak_root));return 0
