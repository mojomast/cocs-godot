"""Write source evidence only, with explicit null future artifact identities."""
import hashlib
import json
import subprocess
from pathlib import Path
from source_scene import ROOT,k,load
from asset_author import MAPS,paths
from test_greenhouse import attachments
from archived_fixture import archive_bytes,PROBES
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    # Full-count evidence is an explicit archive operation, unlike portable
    # positive tests. Fail before writing if the archive is absent or changed.
    fixture_bytes=archive_bytes(PROBES)
    records={}
    for ident,revision in MAPS.items():
        out,master=paths(ident);a=load(ident,revision)
        bindings=json.loads((out/'bindings.json').read_text())
        summary=k.scene_summary(a['arena'],set(bindings['materials']))
        records[ident]={'revision':revision,'geometryHash':a['geometryHash'],
            'authoritySha256':sha(out/'authority.json'),'bindingsSha256':sha(out/'bindings.json'),
            'sourceSummary':summary,'expectedMaster':str(master.relative_to(ROOT)),
            'expectedGlb':str((out/(ident+'.glb')).relative_to(ROOT)),
            'masterSha256':None,'glbSha256':None,'status':'source-only; actual successor export and native pending'}
    joints,edges=attachments(load('helix-conservatory','revision-4')['arena'])
    records['helix-conservatory']['sourceAttachments']={'joints':joints,'edges':edges,
        'numericToleranceMetres':1e-8,'futureActualToleranceMetres':.0001,
        'futureRule':'Match named evaluated components to actual GLB triangles, then test their measured complete bearing sections and longitudinal rings'}
    points=json.loads(subprocess.check_output(['node',str(HERE/'route_points.mjs')],cwd=ROOT))
    records['helix-conservatory']['newFrameFiniteCapsuleSamples']=len(points)+len(json.loads(fixture_bytes)['points'])
    records['helix-conservatory']['frozenUProbeSha256']=hashlib.sha256(fixture_bytes).hexdigest()
    records['helix-conservatory']['finiteCapsule']={'radius':.42,'height':1.8,'spacing':.25,
        'scope':'all original route/nav plus frozen U fixture including mode spawns/objectives against every new frame triangle; complete native physics pending'}
    paths_to_hash=list(HERE.glob('*.py'))+list(HERE.glob('*.mjs'))+[
        ROOT/'tools/godot-multiplayer/new-maps/helix-conservatory/recipe-v4.mjs',
        ROOT/'tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v4/recipe-v4.mjs',
        ROOT/'tools/godot-multiplayer/new-maps/vesper-viaduct/revisions/urban-v3/recipe-v3.mjs']+[
        ROOT/'tools/godot-multiplayer/new-maps/map_variety'/n for n in ['kit_expander.py','source_geometry.py','base_craft.py','kit_build.py']]
    result={'baseline':'243223d3','scope':'Source predictions, no acceptance reuse or heavy execution',
        'candidates':records,'dependencies':{str(p.relative_to(ROOT)):sha(p) for p in sorted(paths_to_hash)}}
    (HERE/'source-evidence.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
    for ident,r in records.items():print(ident,r['geometryHash'],'source estimate',r['sourceSummary']['sourceSceneTriangles'])
if __name__=='__main__':main()
