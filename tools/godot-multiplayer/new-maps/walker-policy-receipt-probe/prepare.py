"""Explicit future preparation only. No grant creation or launch. Tests use memory."""
import argparse,hashlib,json,re
from pathlib import Path
import contract as C
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
PARENT=ROOT/'godot/tests/walker_policy_receipt_probe'
OLD='tests/walker_parity_admission/'
NEEDLE=b'not up in [0,1]';REPLACEMENT=b'(up != 0 and up != 1)'
PROJECT=b'config_version=5\n[application]\nconfig/name="Frozen receipt numeric probe"\n[threading]\nworker_pool/max_threads=1\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
def sha_bytes(b):return hashlib.sha256(b).hexdigest()
def sha(p):return sha_bytes(p.read_bytes())
def load(p):return json.loads(p.read_text(),object_pairs_hook=unique)
def unique(items):
    d={}
    for k,v in items:
        if k in d:raise ValueError('duplicate JSON key')
        d[k]=v
    return d
def write(p,value):
    with p.open('x') as f:json.dump(value,f,indent=2,allow_nan=False);f.write('\n')
def clone(evidence,policy):
    if sha_bytes(evidence)!=C.EVIDENCE or sha_bytes(policy)!=C.POLICY:raise ValueError('original source pins')
    if evidence.count(NEEDLE)!=1:raise ValueError('unique clause required')
    old=b'preload("evidence.gd")';new=b'preload("cloned_evidence.gd")'
    if policy.count(old)!=1:raise ValueError('unique import required')
    return evidence.replace(NEEDLE,REPLACEMENT),policy.replace(old,new)
def sources():
    original=ROOT/'godot/tests/walker_parity_admission'
    e=(original/'evidence.gd').read_bytes();p=(original/'policy.gd').read_bytes();ce,cp=clone(e,p)
    diagnostic=(HERE.parent/'walker-policy-source-diagnosis/diagnostic.gd').read_bytes()
    if sha_bytes(diagnostic)!=C.DIAGNOSTIC:raise ValueError('diagnostic pin')
    return {OLD+'evidence.gd':e,OLD+'policy.gd':p,'probe/cloned_evidence.gd':ce,'probe/cloned_policy.gd':cp,'probe/diagnostic.gd':diagnostic,'probe/driver.gd':(HERE/'driver.gd').read_bytes(),'project.godot':PROJECT}
def verify_ai(root):
    root=Path(root)
    if not root.is_absolute() or root.resolve()!=root:raise ValueError('explicit nonsymlink AI root')
    manifest=root/'tools/godot-multiplayer/new-maps/walker-parity-admission-ai/evidence/artifact-inventory.json'
    if sha(manifest)!=C.AI_MANIFEST:raise ValueError('AI manifest pin')
    rows=load(manifest)['files']
    if len(rows)!=40:raise ValueError('AI40')
    for name,row in rows.items():
        p=root/name
        if p.resolve()!=p or not p.is_relative_to(root) or '..' in Path(name).parts or sha(p)!=row['sha256'] or p.stat().st_size!=row['bytes']:raise ValueError('AI archive mismatch')
    stage=root/'godot/tests/walker_parity_admission/parity-admission-ai-01'
    for name,h in [('negative-controls-result.json',C.RECEIPT),('source.json',C.AI_SOURCE),('grant.json',C.AI_GRANT),('tests/walker_parity_admission/policy.gd',C.POLICY),('tests/walker_parity_admission/evidence.gd',C.EVIDENCE)]:
        if sha(stage/name)!=h:raise ValueError('AI binding')
    return stage/'negative-controls-result.json'
def verify_host():
    pins=load(HERE/'review-pins.json')
    for name,h in pins['hostFiles'].items():
        if sha(ROOT/name)!=h:raise ValueError('host source pin')
    reviewed=load(HERE.parent/'walker-parity-admission/review-pins.json')
    for group in ['stageInputs','hostInputs','productionDependencies']:
        for name,h in reviewed[group].items():
            if sha(ROOT/name)!=h:raise ValueError('reviewed source dependency')
def build(name,ai_root):
    verify_host();receipt=verify_ai(ai_root);content=sources()
    if not re.fullmatch('policy-receipt-probe-[a-z0-9]+(?:-[a-z0-9]+)*',name):raise ValueError('lowercase probe namespace')
    dest=PARENT/name
    if dest.resolve()!=dest:raise ValueError('nonsymlink stage')
    dest.mkdir(parents=True,exist_ok=False)
    for n,b in content.items():
        p=dest/n;p.parent.mkdir(parents=True,exist_ok=True)
        with p.open('xb') as f:f.write(b)
    # Only one data copy, fixed filename, never treated as a predecessor result.
    with (dest/'frozen-negative.json').open('xb') as f:f.write(receipt.read_bytes())
    write(dest/'source.json',{'phase':C.PHASE,'mode':C.MODE,'group':C.GROUP,'namespace':name,'files':{n:sha_bytes(b) for n,b in content.items()},'receiptSha256':C.RECEIPT,'AIManifestSha256':C.AI_MANIFEST,'hostPinsSha256':sha(HERE/'review-pins.json')})
    validate_stage(dest);return dest
def validate_stage(dest):
    verify_host();dest=Path(dest)
    if dest.parent!=PARENT or dest.resolve()!=dest or not re.fullmatch('policy-receipt-probe-[a-z0-9]+(?:-[a-z0-9]+)*',dest.name):raise ValueError('stage namespace')
    c=load(dest/'source.json');expected={n:sha_bytes(b) for n,b in sources().items()}
    if c!={'phase':C.PHASE,'mode':C.MODE,'group':C.GROUP,'namespace':dest.name,'files':expected,'receiptSha256':C.RECEIPT,'AIManifestSha256':C.AI_MANIFEST,'hostPinsSha256':sha(HERE/'review-pins.json')}:raise ValueError('source seal')
    for n,h in {**expected,'frozen-negative.json':C.RECEIPT}.items():
        p=dest/n
        if p.resolve()!=p or sha(p)!=h:raise ValueError('staged byte mismatch')
    allowed=set(expected)|{'source.json','frozen-negative.json','grant.json','probe-start.json','probe-result.json','probe-supervisor.json','probe.log'}
    for p in dest.rglob('*'):
        if p.is_symlink() or p.is_file() and str(p.relative_to(dest)) not in allowed:raise ValueError('unexpected stage content')
    return c
if __name__=='__main__':
    p=argparse.ArgumentParser(allow_abbrev=False);p.add_argument('name');p.add_argument('--ai-root',required=True);a=p.parse_args();print(build(a.name,a.ai_root))
