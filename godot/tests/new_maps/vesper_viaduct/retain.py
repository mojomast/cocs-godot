"""Retain actual H evidence and measured capture cadence; no engines or inference."""
import hashlib
import json
from pathlib import Path
import shutil
import statistics

ROOT = Path(__file__).resolve().parents[4]
STAGES = Path('/home/mojo/.tmp-on-disk/cocs-expansion-three-vesper-evidence-20261002/production-h')
HOSTED = Path('/home/mojo/.tmp-on-disk/cocs-expansion-four-scenery-evidence-20261002/consolidation/hosted')
OUT = ROOT/'port/expansion-three/vesper/evidence/production-h'
OUT.mkdir(parents=True,exist_ok=True)
def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2)+'\n')
rows=[]
for mode in ['deathmatch','teamdeathmatch','ctf','domination','koth','uplink']:
    runs=sorted(HOSTED.glob('*-vesper-viaduct-'+mode))
    good=[p for p in runs if (p/'outcome.json').exists() and json.loads((p/'outcome.json').read_text())['success']]
    p=good[-1]
    d=json.loads((p/'outcome.json').read_text())
    assert d['journeyPassed'] and not d['processFailed'] and d['respawn']=={'dead':True,'alive':True}
    assert all(peer['clean'] and peer['closed'] for peer in d['teardown']['peers'])
    target=OUT/mode
    target.mkdir(exist_ok=True)
    for name in ['outcome.json','trace.json','teardown.json']:
        if (p/name).exists(): shutil.copy2(p/name,target/name)
    captures=json.loads((p/'frames/vesper-native-review.json').read_text())['captures']
    sequence=[c for c in captures if c['label'].startswith('frame-')]
    gaps=[(b['ticksMs']-a['ticksMs'])/1000 for a,b in zip(sequence,sequence[1:])]
    score=d['state']['actors'][0]
    row={'mode':mode,'evidence':str(p),'geometryHash':d['geometryHash'],'artSha':d['artSha'],
         'success':d['success'],'reason':d['state']['overReason'],'sourceSeconds':d['state']['time'],
         'winner':d['state'].get('winner'),'leaders':d['state'].get('leaders'),
         'host':{k:score.get(k) for k in ['id','frags','deaths','scoreStats','x','y','z']},
         'teardown':d['teardown'],'captures':len(captures),'maxClipCounter':max(c['clipCounter'] for c in captures),
         'viewport':captures[-1]['viewport'],'captureCadence':{'samples':len(sequence),'medianSeconds':statistics.median(gaps),'minSeconds':min(gaps),'maxSeconds':max(gaps),'measuredFPS':(len(sequence)-1)/sum(gaps)},
         'captureNote':'PNG capture cadence, not GPU frame rate; DM/TDM early capture predates corrected respawn trigger and canvas-scaled clip counter.' if mode in ['deathmatch','teamdeathmatch'] else 'PNG capture cadence, not GPU frame rate; post-source-respawn movement.'}
    rows.append(row)
    save(target/'capture-review.json',{'captures':captures})
    for label in ['results',sequence[len(sequence)//2]['label']]:
        shutil.copy2(p/'frames'/(label+'.png'),target/(label+'.png'))
inspection=sorted(STAGES.glob('*-inspection'))[-1]
for p in inspection.glob('*.png'): shutil.copy2(p,OUT/p.name)
shutil.copy2(inspection/'inspection.json',OUT/'inspection.json')
for p in STAGES.glob('*/*-process.json'):
    dest=OUT/'stages'/p.parent.name
    dest.mkdir(parents=True,exist_ok=True)
    shutil.copy2(p,dest/p.name)
    log=p.with_name(p.name.replace('-process.json','.log'))
    if log.exists(): shutil.copy2(log,dest/log.name)
save(OUT/'hosted-summary.json',{'accepted':False,'parentVisualApprovalPending':True,'modes':rows})
print(json.dumps(rows,indent=2))
