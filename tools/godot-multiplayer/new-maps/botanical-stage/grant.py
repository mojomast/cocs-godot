"""U namespace around SHA-pinned reviewed R5 owned-PGID supervisor.

Import is inert. `serve` is only for the explicitly authorized exclusive U slot.
The R5 algorithm is reused unchanged; only identity/evidence namespaces change.
"""
import datetime as dt
import json
import sys
import time
from pathlib import Path
from config import HERE, ROOT, R5, sha

GRANT='MOTH-BLENDER-20261003-U'
STATE=Path('/tmp/opencode/botanical-astra-U')
LOG=HERE/'evidence/attempts'
path=R5/'grant.py'
if sha(path)!='8d919347092909d266ef1bca504e074a0b786e949dbb677c6f03847d59be916f':
    raise ValueError('Reviewed R5 supervisor source changed')
source=path.read_text().replace('MOTH-BLENDER-20261003-S',GRANT).replace('godot/tests/new_maps/gravemill_foundry/revision5','godot/tests/new_maps/botanical_stage')
kernel={'__file__':str(path),'__name__':'botanical_owned_kernel'}
exec(compile(source,str(path),'exec'),kernel)
kernel.update(HERE=HERE,ROOT=ROOT,STATE=STATE,LOG=LOG)
inventory,now,write=kernel['inventory'],kernel['now'],kernel['write']

def request(command,seconds):
    if not 0<seconds<=1800:raise ValueError('Bounded commands only')
    owner=json.loads((STATE/'ready.json').read_text())
    if not any(p['pid']==owner['pid'] and p['startTicks']==owner['startTicks'] for p in inventory()):raise RuntimeError('U supervisor is not alive')
    ident=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%f')
    write(STATE/(ident+'.request.json'),{'id':ident,'command':command,'timeout':seconds})
    result=STATE/(ident+'.result.json');deadline=time.monotonic()+seconds+40
    while not result.exists():
        if time.monotonic()>deadline:raise RuntimeError('Supervisor result missing; inspect owned group before further work')
        time.sleep(.2)
    data=json.loads(result.read_text())
    print(json.dumps({k:v for k,v in data.items() if k!='sourceHashes'},indent=2))
    log=LOG/(ident+'.log')
    if log.exists():print(log.read_text()[-12000:])
    return data['returncode']

if __name__=='__main__':
    action=sys.argv[1]
    if action=='serve':kernel['serve']()
    elif action=='release':sys.exit(request(['RELEASE'],30))
    elif action=='run':sys.exit(request(sys.argv[3:],int(sys.argv[2])))
    else:raise ValueError('Unknown U supervisor action')
