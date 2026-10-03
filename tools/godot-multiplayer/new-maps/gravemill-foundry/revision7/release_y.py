"""Y release: empty groups, free lock, unchanged preexisting viewer/displays."""
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'revision5'))
import grant
grant.HERE=HERE
code=(HERE.parent/'revision5/release_verify.py').read_text()
code=code.replace('evidence/attempts/','evidence/Y/attempts/').replace('evidence/release-receipt.json','evidence/Y/release-receipt.json').replace('MOTH-BLENDER-20261003-S','MOTH-BLENDER-20261003-Y').replace('S_RELEASE_VERIFIED','Y_RELEASE_VERIFIED')
exec(compile(code,__file__,'exec'))
baseline=grant.json.loads((HERE/'evidence/Y/attempts/grant-start.json').read_text());preexisting=[]
for old in baseline['preexistingMatching']:
    if 'xvfb' not in old['comm'].lower() and old['pid']!=2598700:continue
    current=[p for p in grant.inventory() if p['pid']==old['pid'] and p['startTicks']==old['startTicks']]
    assert len(current)==1 and current[0]['pgid']==old['pgid'],('Preexisting viewer/display changed',old)
    preexisting.append(current[0])
path=HERE/'evidence/Y/release-receipt.json';receipt=grant.json.loads(path.read_text())
receipt.update(preexistingViewerAndDisplaysUnchanged=preexisting,managerIdentity=baseline['owner'],managerExited=True)
grant.write(path,receipt)
