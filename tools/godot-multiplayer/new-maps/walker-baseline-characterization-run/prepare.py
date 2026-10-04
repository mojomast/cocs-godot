"""Future explicit write-once preparation. No grant creator, launch or queue."""
import argparse,re
from pathlib import Path
from frozen import files
from policy import PHASE,MODE,GROUP,MATRIX,AK,AK_RESULT
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
load=files.load;write=files.write;sha=files.sha;digest=files.digest;relative=files.relative
PROJECT=files.PROJECT.replace('Single parity response experiment','Baseline characterization v1')
AK_MANIFEST='tools/godot-multiplayer/new-maps/walker-parity-admission-ak/evidence/artifact-inventory.json'
AK_RECEIPT='godot/tests/walker_parity_admission/parity-admission-ak-01/positive-step-admission-result.json'
LINEAGE={'AKManifestSha256':AK,'AKPositiveSha256':AK_RESULT,'role':'failed-positive-lineage-not-admission'}
OUTPUTS={'grant.json','radius-rise-result.json','radius-rise-supervisor.json','radius-rise-start.json','radius-rise-dependencies.json','radius-rise.log'}
def lineage(ak_root):
    files.verify_archive(ak_root,AK_MANIFEST,AK,51)
    if sha(relative(Path(ak_root).absolute(),AK_RECEIPT))!=AK_RESULT:raise ValueError('AK receipt lineage')
    return LINEAGE.copy()
def verify_inputs(root,pins):
    for group in ['stageInputs','hostInputs','productionDependencies','approvedDesign']:
        for n,h in pins[group].items():
            if sha(relative(root,n))!=h:raise ValueError('source pin drift: '+n)
    if pins['projectSha256']!=digest(PROJECT.encode()):raise ValueError('project recipe')
def namespace(dest):
    if dest.resolve()!=dest or not re.fullmatch(r'baseline-characterization-[a-z0-9]+(?:-[a-z0-9]+)*',dest.name) or len(dest.name)>64:raise ValueError('canonical namespace')
def source(attempt,pins):
    return {'phase':PHASE,'mode':MODE,'group':GROUP,'matrix':MATRIX,'attempt':attempt,'files':{'res://'+n[6:]:h for n,h in pins['stageInputs'].items()}|{'res://project.godot':pins['projectSha256']},'lineage':LINEAGE,'hostInputs':pins['hostInputs'],'productionDependencies':pins['productionDependencies'],'approvedDesign':pins['approvedDesign'],'reviewPinsSha256':sha(HERE/'review-pins.json'),'grant':None,'autoStart':False,'queued':False,'queueIdentity':None,'candidateAdmission':False}
def build(attempt,ak_root,*,root=ROOT,stage_parent=None):
    root=Path(root).absolute();parent=Path(stage_parent or root/'godot/tests/walker_baseline_characterization').absolute();dest=relative(parent,attempt);namespace(dest)
    if dest.exists():raise FileExistsError('write-once stage')
    pins=load(HERE/'review-pins.json');verify_inputs(root,pins);lineage(ak_root)
    data={n[6:]:(root/n).read_bytes() for n in pins['stageInputs']};data['project.godot']=PROJECT.encode()
    config=source(attempt,pins);dest.mkdir()
    for name,raw in data.items():
        p=relative(dest,name);p.parent.mkdir(parents=True,exist_ok=True)
        with p.open('xb') as f:f.write(raw)
    write(dest/'source.json',config);return dest
def validate_stage(dest,*,root=ROOT):
    dest=Path(dest).absolute();namespace(dest);pins=load(HERE/'review-pins.json');verify_inputs(Path(root),pins)
    c=load(dest/'source.json')
    if c!=source(dest.name,pins):raise ValueError('exact source seal')
    if any(c[k] is not False for k in ['autoStart','queued','candidateAdmission']):raise ValueError('typed source flags')
    allowed={n[6:] for n in c['files']}|OUTPUTS|{'source.json'}
    for p in dest.rglob('*'):
        if p.is_symlink() or (p.is_file() and str(p.relative_to(dest)) not in allowed):raise ValueError('unexpected stage file')
    for n,h in c['files'].items():
        if sha(relative(dest,n[6:]))!=h:raise ValueError('staged hash')
    return c
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__,allow_abbrev=False);parser.add_argument('attempt');parser.add_argument('--ak-root',required=True)
    a=parser.parse_args();print(build(a.attempt,a.ak_root))
