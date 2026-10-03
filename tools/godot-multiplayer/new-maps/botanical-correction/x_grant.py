"""Explicit X namespace around the SHA-pinned reviewed R5 supervisor. Import is inert."""
import datetime as dt
import fcntl
import json
import sys
import time
from pathlib import Path
from stage_config import ROOT,HERE,sha,read,write
GRANT='MOTH-BLENDER-20261003-X'
STATE=Path('/tmp/opencode/botanical-astra-X')
LOG=HERE/'x-evidence/attempts'
path=ROOT/'tools/godot-multiplayer/new-maps/gravemill-foundry/revision5/grant.py'
if sha(path)!='8d919347092909d266ef1bca504e074a0b786e949dbb677c6f03847d59be916f':raise ValueError('Reviewed supervisor drift')
source=path.read_text().replace('MOTH-BLENDER-20261003-S',GRANT).replace('godot/tests/new_maps/gravemill_foundry/revision5','godot/tests/new_maps/botanical_correction')
kernel={'__file__':str(path),'__name__':'successor_X_owned_kernel'}
exec(compile(source,str(path),'exec'),kernel)
kernel.update(HERE=HERE,ROOT=ROOT,STATE=STATE,LOG=LOG)
inventory,now=kernel['inventory'],kernel['now']

def request(command,seconds):
    if not 0<seconds<=1800:raise ValueError('Bounded commands only')
    owner=read(STATE/'ready.json')
    if not any(p['pid']==owner['pid'] and p['startTicks']==owner['startTicks'] for p in inventory()):raise RuntimeError('X supervisor is not alive')
    ident=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%f')
    write(STATE/(ident+'.request.json'),{'id':ident,'command':command,'timeout':seconds})
    result=STATE/(ident+'.result.json');deadline=time.monotonic()+seconds+40
    while not result.exists():
        if time.monotonic()>deadline:raise RuntimeError('Inspect owned group; no supervisor result')
        time.sleep(.2)
    data=read(result)
    print(json.dumps({k:v for k,v in data.items() if k!='sourceHashes'},indent=2))
    log=LOG/(ident+'.log')
    if log.exists():print(log.read_text()[-10000:])
    return data['returncode']

def verify_release():
    r=read(LOG/'release.json')
    if r['grant']!=GRANT or len(r['audits'])!=3 or any(a['ownedGroupMembers'] for a in r['audits']):raise ValueError('Incomplete release')
    groups=r['audits'][-1]['groups']
    live=[p for p in inventory() if any(p['pgid']==g['pgid'] and p['startTicks']>=g['startTicks'] for g in groups)]
    if live or not r['noQueuedHeavyWork']:raise ValueError('X work remains')
    with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as f:
        fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB);available=now();fcntl.flock(f,fcntl.LOCK_UN)
    write(HERE/'x-evidence/release-receipt.json',{'grant':GRANT,'released':now(),'audits':r['audits'],
        'currentOwnedMembers':live,'nonwaitingLockAvailableAt':available,'supervisorReceiptSha256':sha(LOG/'release.json'),'noQueuedHeavyWork':True})
    print('X released; owned groups empty; shared lock available',available)

if __name__=='__main__':
    action=sys.argv[1]
    if action=='serve':
        if (LOG/'grant-start.json').exists():raise FileExistsError('X grant already started; do not overwrite receipts')
        kernel['serve']()
    elif action=='run':sys.exit(request(sys.argv[3:],int(sys.argv[2])))
    elif action=='release':sys.exit(request(['RELEASE'],30))
    elif action=='verify-release':verify_release()
    else:raise ValueError('Unknown action')
