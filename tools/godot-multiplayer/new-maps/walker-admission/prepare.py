"""Future explicit write-once synthetic-fixture preparation; no launch/grant creation."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
from phase import PHASE,GROUPS
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
AB_MANIFEST='tools/godot-multiplayer/new-maps/walker-step-ab/evidence/artifact-inventory.json'
AB_ATTEMPT='godot/tests/walker_step_up/walker-step-AB-01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):
    with p.open('x') as f:json.dump(value,f,indent=2);f.write('\n')
def verify_ab(root):
    root=Path(root).resolve(strict=True)
    trusted=subprocess.check_output(['git','show','5fb9ae68:'+AB_MANIFEST],cwd=ROOT)
    assert (root/AB_MANIFEST).read_bytes()==trusted
    manifest=json.loads(trusted);assert len(manifest['files'])==140
    for name,r in manifest['files'].items():
        p=(root/name).resolve(strict=True);assert p.is_relative_to(root)
        assert sha(p)==r['sha256'] and p.stat().st_size==r['bytes'],name
    controls=json.loads((root/AB_ATTEMPT/'controls-result.json').read_text())
    reference=json.loads((root/AB_ATTEMPT/'reference-accepted-civic-r035-result.json').read_text())
    assert not controls['failed'] and controls['passed']==34
    assert reference['failed'] and reference['referenceExpected'] and reference['passed']==reference['failedTrials']==5
    assert controls['sourceSha256']==reference['sourceSha256']
    assert controls['grantReceiptSha256']==reference['grantReceiptSha256']
    assert sha(root/AB_ATTEMPT/'source.json')==controls['sourceSha256']
    return {'producer':'5fb9ae68','manifestSha256':hashlib.sha256(trusted).hexdigest(),'filesVerified':140,
            'controlsSha256':sha(root/AB_ATTEMPT/'controls-result.json'),'referenceSha256':sha(root/AB_ATTEMPT/'reference-accepted-civic-r035-result.json'),
            'sourceSha256':controls['sourceSha256'],'referenceRemainsFailed':True}
def prepare(attempt,ab_root):
    if attempt!='admission-AD-01' and not re.fullmatch(r'admission-[a-z0-9-]{1,40}',attempt):raise ValueError('fresh admission namespace')
    dest=ROOT/'godot/tests/walker_admission'/attempt
    if dest.exists() or dest.resolve()!=dest.absolute():raise ValueError('existing/symlinked destination')
    lineage=verify_ab(ab_root)
    pins=json.loads((HERE.parent/'walker-step-up/post-response-provenance.json').read_text())['original15DependenciesMatchParent']
    for path,h in pins.items():assert sha(ROOT/path)==h,path
    scripts=list((ROOT/'godot/tests/walker_admission').glob('*.gd'))+list((ROOT/'godot/tests/walker_step_up').glob('*.gd'))
    scripts.append(ROOT/'godot/tests/new_maps/botanical_post_x/art_binding.gd')
    res=lambda p:'res://'+str(p.relative_to(ROOT/'godot'))
    files={res(p):sha(p) for p in scripts}
    files.update({res(ROOT/p):h for p,h in pins.items() if p.startswith('godot/')})
    dest.mkdir()
    for name in ['source.json','controls-result.json','reference-accepted-civic-r035-result.json']:
        target=dest/('AB-'+name)
        with target.open('xb') as f:f.write((Path(ab_root)/AB_ATTEMPT/name).read_bytes())
        files[res(target)]=sha(target)
    write(dest/'source.json',{'phase':PHASE,'allowedGroups':GROUPS,'files':files,'productionDependencies':pins,
        'abEvidenceVerified':True,'abLineage':lineage,'grant':None,'queued':False,'autoStart':False,'candidateMapWalksAllowed':False})
    print(dest)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('attempt');p.add_argument('--ab-root',required=True)
    a=p.parse_args();prepare(a.attempt,a.ab_root)
