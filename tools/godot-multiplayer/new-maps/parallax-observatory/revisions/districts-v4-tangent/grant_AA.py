"""AA isolated nonwaiting lifetime supervisor around reviewed owned-PGID kernel."""
import datetime as dt
import fcntl
import hashlib
import json
import sys
import time
from pathlib import Path
from contract import ROOT, HERE

GRANT = 'MOTH-BLENDER-20261003-AA'
STATE = Path('/tmp/opencode/parallax-tangent-AA')
LOG = HERE / 'native/AA01/attempts'
path = ROOT / 'tools/godot-multiplayer/new-maps/gravemill-foundry/revision5/grant.py'
source = path.read_text()
kernel = {'__file__':str(path), '__name__':'AA_owned_kernel'}
exec(compile(source.replace('MOTH-BLENDER-20261003-S', GRANT),str(path),'exec'),kernel)
kernel.update(ROOT=ROOT, HERE=HERE, STATE=STATE, LOG=LOG)
inventory,now = kernel['inventory'],kernel['now']

def request(command,seconds):
    if not 0 < seconds <= 900: raise ValueError('AA bounded commands only')
    owner = json.loads((STATE/'ready.json').read_text())
    if not any(p['pid']==owner['pid'] and p['startTicks']==owner['startTicks'] for p in inventory()):
        raise RuntimeError('AA lifetime owner is gone; do not start work')
    ident=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%f')
    req=STATE/(ident+'.request.json')
    req.write_text(json.dumps({'id':ident,'command':command,'timeout':seconds})+'\n')
    result=STATE/(ident+'.result.json');deadline=time.monotonic()+seconds+45
    while not result.exists():
        if time.monotonic()>deadline:raise RuntimeError('Inspect AA owned group; no supervisor result')
        time.sleep(.2)
    data=json.loads(result.read_text())
    print(json.dumps({k:v for k,v in data.items() if k!='sourceHashes'},indent=2))
    log=LOG/(ident+'.log')
    if log.exists():print(log.read_text()[-12000:])
    return data['returncode']

if __name__=='__main__':
    action=sys.argv[1]
    if action=='serve':
        if (LOG/'grant-start.json').exists():raise FileExistsError('AA owner already started')
        kernel['serve']()
    elif action=='run':sys.exit(request(sys.argv[3:],int(sys.argv[2])))
    elif action=='release':sys.exit(request(['RELEASE'],30))
    elif action=='verify-release':
        receipt=json.loads((LOG/'release.json').read_text())
        if receipt['grant']!=GRANT or len(receipt['audits'])!=3 or any(x['ownedGroupMembers'] for x in receipt['audits']):raise ValueError('AA release incomplete')
        live=[p for p in inventory() if any(p['pgid']==g['pgid'] and p['startTicks']>=g['startTicks'] for g in receipt['audits'][-1]['groups'])]
        if live or not receipt['noQueuedHeavyWork']:raise ValueError('AA owned work remains')
        with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as f:
            fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB);available=now();fcntl.flock(f,fcntl.LOCK_UN)
        (LOG.parent/'release-receipt.json').write_text(json.dumps({'grant':GRANT,'released':now(),'audits':receipt['audits'],
            'currentOwnedMembers':live,'nonwaitingLockAvailableAt':available,
            'supervisorReceiptSha256':hashlib.sha256((LOG/'release.json').read_bytes()).hexdigest(),'noQueuedHeavyWork':True},indent=2)+'\n')
        print('AA released, three empty audits, lock available',available)
    else:raise ValueError('Unknown AA action')
