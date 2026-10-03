"""After W daemon exit, verify owned groups empty and preexisting viewers intact."""
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'revision5'))
import grant
grant.HERE=HERE
code=(HERE.parent/'revision5/release_verify.py').read_text()
code=code.replace('evidence/attempts/','evidence/W/attempts/').replace('evidence/release-receipt.json','evidence/W/release-receipt.json').replace('MOTH-BLENDER-20261003-S','MOTH-BLENDER-20261003-W').replace('S_RELEASE_VERIFIED','W_RELEASE_VERIFIED')
exec(compile(code,__file__,'exec'))
baseline=grant.json.loads((HERE/'evidence/W/attempts/grant-start.json').read_text())
preexisting=[]
for old in baseline['preexistingMatching']:
    if 'xvfb' not in old['comm'].lower() and old['pid']!=2598700:continue
    current=[p for p in grant.inventory() if p['pid']==old['pid'] and p['startTicks']==old['startTicks']]
    assert len(current)==1 and current[0]['pgid']==old['pgid'],('Preexisting viewer/display changed',old)
    preexisting.append(current[0])
path=HERE/'evidence/W/release-receipt.json';receipt=grant.json.loads(path.read_text())
receipt['preexistingViewerAndDisplaysUnchanged']=preexisting
receipt['managerIdentity']=baseline['owner'];receipt['managerExited']=True
grant.write(path,receipt)
