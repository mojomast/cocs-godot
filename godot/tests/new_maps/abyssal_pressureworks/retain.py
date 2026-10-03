"""Retain exact successful I-run identities, raw logs and native capture cadence."""
import hashlib
import json
from pathlib import Path
import shutil
import statistics

ROOT = Path(__file__).resolve().parents[4]
STAGES = Path('/home/mojo/.tmp-on-disk/cocs-expansion-three-abyssal-evidence-20261002/production-i')
HOSTED = Path('/home/mojo/.tmp-on-disk/cocs-expansion-four-scenery-evidence-20261002/consolidation/hosted')
OUT = ROOT/'port/expansion-three/abyssal/evidence/production-i'
OUT.mkdir(parents=True,exist_ok=True)
def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2)+'\n')
geometry = json.loads((ROOT/'godot/multiplayer_worlds/generated/abyssal-pressureworks.json').read_text())['geometryHash']
art = hashlib.sha256((ROOT/'godot/multiplayer_worlds/art/worlds/abyssal-pressureworks.glb').read_bytes()).hexdigest()
rows = []
for mode in ['deathmatch','teamdeathmatch','ctf','koth','domination','holdout']:
    good = [p for p in sorted(HOSTED.glob('*-abyssal-pressureworks-'+mode)) if (p/'outcome.json').exists() and json.loads((p/'outcome.json').read_text())['success']]
    p = good[-1]
    d = json.loads((p/'outcome.json').read_text())
    assert d['geometryHash']==geometry and d['artSha']==art
    assert d['journeyPassed'] and not d['processFailed'] and d['respawn']=={'dead':True,'alive':True}
    assert all(peer['clean'] and peer['closed'] for peer in d['teardown']['peers'])
    target = OUT/mode
    target.mkdir(exist_ok=True)
    for name in ['outcome.json','trace.json','teardown.json','host.log','guest.log','host-stdout.log','host-stderr.log','guest-stdout.log','guest-stderr.log','wire.json']:
        shutil.copy2(p/name,target/name)
    shutil.copytree(p/'private-authority',target/'private-authority',dirs_exist_ok=True)
    captures = json.loads((p/'frames/abyssal-native-review.json').read_text())['captures']
    sequence = [c for c in captures if c['label'].startswith('frame-')]
    assert len(sequence)>2
    gaps = [(b['ticksMs']-a['ticksMs'])/1000 for a,b in zip(sequence,sequence[1:])]
    row = {'mode':mode,'evidence':str(p),'geometryHash':geometry,'artSha':art,'success':True,
           'reason':d['state']['overReason'],'sourceSeconds':d['state']['time'],'winner':d['state'].get('winner'),'leaders':d['state'].get('leaders'),
           'host':d['state']['actors'][0],'teardown':d['teardown'],'captures':len(captures),'maxClipCounter':max(c['clipCounter'] for c in captures),
           'viewport':captures[-1]['viewport'],'captureCadence':{'samples':len(sequence),'medianSeconds':statistics.median(gaps),'minSeconds':min(gaps),'maxSeconds':max(gaps),'measuredFPS':(len(sequence)-1)/sum(gaps)},
           'captureNote':'Actual PNG capture timestamps during post-respawn ordinary inputs; software-rendered, not a GPU frame-rate claim.'}
    rows.append(row)
    save(target/'capture-review.json',{'captures':captures})
    for label in ['results',sequence[len(sequence)//2]['label']]: shutil.copy2(p/'frames'/(label+'.png'),target/(label+'.png'))
    if mode=='ctf':
        lines = []
        for frame,gap in zip(sequence,gaps): lines += ["file '"+str(p/'frames'/(frame['label']+'.png'))+"'",'duration '+str(gap)]
        lines += ["file '"+str(p/'frames'/(sequence[-1]['label']+'.png'))+"'"]
        (STAGES/'ctf-cadence.ffconcat').write_text('\n'.join(lines)+'\n')
inspection = sorted(p for p in STAGES.glob('*-inspection') if (p/'inspection.json').exists())[-1]
assert json.loads((inspection/'inspection.json').read_text())['geometryHash']==geometry
for p in inspection.glob('*.png'): shutil.copy2(p,OUT/p.name)
shutil.copy2(inspection/'inspection.json',OUT/'inspection.json')
for p in STAGES.glob('*/*-process.json'):
    dest = OUT/'stages'/p.parent.name
    dest.mkdir(parents=True,exist_ok=True)
    shutil.copy2(p,dest/p.name)
    for sibling in p.parent.iterdir():
        if sibling.suffix in ['.log','.json']: shutil.copy2(sibling,dest/sibling.name)
save(OUT/'hosted-summary.json',{'accepted':False,'parentVisualApprovalPending':True,'modes':rows})
print(json.dumps([{'mode':r['mode'],'sourceSeconds':r['sourceSeconds'],'cadence':r['captureCadence'],'maxClipCounter':r['maxClipCounter']} for r in rows],indent=2))
