"""After grant daemon exits: three exact-owned-group empty/lock-free audits."""
import datetime
import fcntl
import json
import os
import time
from grant import HERE,inventory,now,write
release=json.loads((HERE/'evidence/attempts/release.json').read_text())
groups=release['audits'][-1]['groups'];hz=os.sysconf('SC_CLK_TCK')
boot=int(next(line.split()[1] for line in open('/proc/stat') if line.startswith('btime ')))
for g in groups:g['kernelStartUtc']=datetime.datetime.fromtimestamp(boot+g['startTicks']/hz,datetime.timezone.utc).isoformat()
audits=[]
for number in range(1,4):
 rows=inventory();live=[p for p in rows if any(p['pgid']==g['pgid'] and p['startTicks']>=g['startTicks'] for g in groups)]
 with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);free=True;fcntl.flock(lock,fcntl.LOCK_UN)
 assert not live,live
 audits.append({'number':number,'time':now(),'ownedGroupMembers':live,'exclusiveLockAvailable':free})
 time.sleep(.2)
viewers=[p for p in inventory() if p['pid']==2598700]
baseline=json.loads((HERE/'evidence/attempts/grant-start.json').read_text())
old_viewer=next(p for p in baseline['preexistingMatching'] if p['pid']==2598700)
assert len(viewers)==1 and viewers[0]['pgid']==2598689 and viewers[0]['startTicks']==old_viewer['startTicks']
assert not any(p['pid']==baseline['owner']['pid'] and p['startTicks']==baseline['owner']['startTicks'] for p in inventory()),'Grant owner has not exited'
write(HERE/'evidence/release-receipt.json',{'grant':'MOTH-BLENDER-20261003-S','status':'released; no queued heavy work','time':now(),
 'bootEpochSeconds':boot,'kernelClockTicksPerSecond':hz,'ownedGroups':groups,'audits':audits,
 'preexistingViewerUntouched':viewers,'scope':'Exact PGIDs with kernel start-time guards, plus renderer descendant inventories in attempts/capture-group-*.json'})
print('S_RELEASE_VERIFIED',json.dumps({'audits':len(audits),'ownedEmpty':True,'lockFree':True,'preexistingViewer':viewers}))
