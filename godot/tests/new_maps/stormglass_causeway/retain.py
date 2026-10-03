"""Retain exact grant-J results and timestamp-derived media input; no rendering."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[4]
BASE=Path('/home/mojo/.tmp-on-disk/cocs-expansion-four-stormglass-evidence-20261002/production-j')
DEST=ROOT/'port/expansion-four/stormglass/evidence/production-j'
DEST.mkdir(parents=True,exist_ok=True)
summary={'grant':'STORMGLASS-ASSET-PRODUCTION-20261003-J','accepted':False,'runs':[]}
for path in sorted((BASE/'hosted').glob('*/outcome.json')):
    data=json.loads(path.read_text())
    name=path.parent.name
    out=DEST/'runs'/name
    out.mkdir(parents=True,exist_ok=True)
    for file in path.parent.glob('*.json'): shutil.copy2(file,out/file.name)
    for file in path.parent.glob('*.log'): shutil.copy2(file,out/file.name)
    summary['runs'].append({'id':name,'success':data['success'],'journeyPassed':data['journeyPassed'],'finishTime':data.get('state',{}).get('race',{}).get('standings',[{}])[0].get('finishTime'),'respawn':data['respawn'],'processFailed':data['processFailed']})
for folder in BASE.glob('*'):
    if not folder.is_dir() or folder.name=='hosted': continue
    out=DEST/'stages'/folder.name
    out.mkdir(parents=True,exist_ok=True)
    for file in folder.iterdir():
        if file.suffix in ['.json','.log']: shutil.copy2(file,out/file.name)
for name in ['overview','terminal','freight-bore','quay-chicane','surgeworks','return-gate']:
    source=BASE/'20261003T054216.614385Z-inspection'/(name+'.png')
    shutil.copy2(source,DEST/(name+'.png'))
wide=BASE/'hosted/2026-10-03T06-00-57.076Z-stormglass-causeway-puma-race'
compact=BASE/'hosted/2026-10-03T05-59-03.606Z-stormglass-causeway-puma-race'
for profile,folder in [('wide',wide),('compact',compact)]:
    for label in ['results','restart','frame-000030']:
        shutil.copy2(folder/'frames'/(label+'.png'),DEST/(profile+'-'+label+'.png'))
rows=[json.loads(line.split(' ',1)[1]) for line in (wide/'host.log').read_text().splitlines() if line.startswith('STORMGLASS_NATIVE_CAPTURE ')]
frames=[r for r in rows if r['label'].startswith('frame-')]
elapsed=(frames[-1]['ticksMs']-frames[0]['ticksMs'])/1000
assert elapsed>=20
intervals=[(b['ticksMs']-a['ticksMs'])/1000 for a,b in zip(frames,frames[1:])]
concat=['ffconcat version 1.0']
for i,row in enumerate(frames):
    concat.append("file '%s'"%(wide/'frames'/(row['label']+'.png')))
    if i<len(intervals): concat.append('duration %.6f'%intervals[i])
concat.append("file '%s'"%(wide/'frames'/(frames[-1]['label']+'.png')))
(BASE/'wide-cadence.ffconcat').write_text('\n'.join(concat)+'\n')
camera=lambda r:[float(v) for v in r['camera'].strip('()').split(',')]
dist=lambda a,b:sum((x-y)**2 for x,y in zip(a,b))**.5
summary['clip']={'frames':len(frames),'seconds':elapsed,'sampledFps':(len(frames)-1)/elapsed,'maxGapSeconds':max(intervals),'minGapSeconds':min(intervals),'renderer':frames[0]['renderer'],'viewport':frames[0]['viewport'],'maxCameraSampleStepMetres':max(dist(camera(a),camera(b)) for a,b in zip(frames,frames[1:])),'classification':'actual software-rendered native capture; VFR timestamp encoding; not GPU performance'}
summary['assetHashes']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'tools/godot-multiplayer/new-maps/stormglass-causeway/stormglass-causeway.blend',ROOT/'godot/multiplayer_worlds/art/worlds/stormglass-causeway.glb']}
paths=['game/core.mjs','game/race.mjs','game/vehicles.mjs','port/multiplayer-worlds/derived/core.mjs','port/multiplayer-worlds/wall_candidates.mjs','tools/asset-production/candidate-hosted.mjs','tools/asset-production/candidate-admission.mjs','tools/asset-production/candidate-guidance.mjs','godot/multiplayer_worlds/sports_demo.gd','godot/sports/chase.gd','godot/sports/controls.gd','godot/sports/hud.gd','godot/vehicles/renderer.gd','godot/vehicles/puma.gd','godot/vehicle_assets/attachment.gd','tools/godot-multiplayer/new-maps/stormglass-causeway/architecture.py','tools/godot-multiplayer/new-maps/stormglass-causeway/blender_export.py']
paths += [str(p.relative_to(ROOT)) for p in (ROOT/'godot/vehicle_assets/generated').glob('puma-*.glb')]
paths += [str(p.relative_to(ROOT)) for p in (ROOT/'godot/tests/new_maps/stormglass_causeway').glob('*') if p.suffix in ['.gd','.mjs','.py']]
summary['runtimeAndFixtureHashes']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
receipt=json.loads((BASE/'20261003T054522.251163Z-receipt/resource-receipt.log').read_text())
shutil.copy2(receipt['report'],DEST/'generic-receipt.json')
(DEST/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
(DEST/'capture-timestamps.json').write_text(json.dumps(frames,indent=2)+'\n')
print(json.dumps(summary,indent=2))
