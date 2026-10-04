"""Future write-once source receipt preparation; no grant, engine or queue."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main(attempt,ae_root):
    if not re.fullmatch(r'snap-parity-[a-z0-9-]{1,32}',attempt):raise ValueError('fresh lowercase namespace required')
    dest=ROOT/'godot/tests/walker_snap_parity'/attempt
    if dest.exists() or dest.resolve()!=dest.absolute():raise ValueError('existing/symlinked attempt refused')
    external=Path(ae_root).resolve(strict=True)
    name='tools/godot-multiplayer/new-maps/walker-admission-ae/evidence/artifact-inventory.json'
    trusted=subprocess.check_output(['git','show','c0761dbe:'+name],cwd=ROOT)
    assert (external/name).read_bytes()==trusted
    manifest=json.loads(trusted);assert len(manifest['files'])==46
    for path,r in manifest['files'].items():
        file=(external/path).resolve(strict=True);assert file.is_relative_to(external)
        assert sha(file)==r['sha256'] and file.stat().st_size==r['bytes']
    pins=json.loads((HERE.parent/'walker-step-up/post-response-provenance.json').read_text())['original15DependenciesMatchParent']
    for path,digest in pins.items():assert sha(ROOT/path)==digest,path
    files={}
    for namespace in ['walker_snap_parity','walker_admission','walker_step_up']:
        for path in (ROOT/'godot/tests'/namespace).glob('*.gd'):files['res://'+str(path.relative_to(ROOT/'godot'))]=sha(path)
    binding=ROOT/'godot/tests/new_maps/botanical_post_x/art_binding.gd'
    files['res://'+str(binding.relative_to(ROOT/'godot'))]=sha(binding)
    files.update({'res://'+p[6:]:d for p,d in pins.items() if p.startswith('godot/')})
    dest.mkdir()
    with (dest/'source.json').open('x') as f:json.dump({'phase':'snap-query-parity-only-v1','files':files,'productionDependencies':pins,
        'AEManifestSha256':hashlib.sha256(trusted).hexdigest(),'AEFilesVerified':46,'grant':None,'autoStart':False,'queued':False,
        'scope':'one response on unchanged .35/-45 synthetic step; not positive admission or map traversal'},f,indent=2);f.write('\n')
    print(dest)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('attempt');p.add_argument('--ae-root',required=True)
    a=p.parse_args();main(a.attempt,a.ae_root)
