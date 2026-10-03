"""Post-supervisor U release receipt and owned-only sidecar cleanup."""
import argparse
import fcntl
import subprocess
from config import HERE, ROOT, DEST, read, write, sha
from grant import inventory,now,LOG,GRANT

def cleanup():
    before=read(LOG/'sidecars-before.json')
    tracked=set(subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines())
    removed=[];changed=[]
    for path in (ROOT/'godot').rglob('*'):
        if not path.is_file() or '.godot' in path.parts or path.suffix not in ('.uid','.import'):continue
        key=str(path.relative_to(ROOT))
        if key in before:
            if sha(path)!=before[key]:changed.append(key)
            continue
        if key in tracked or path.is_relative_to(DEST):continue
        removed.append({'path':key,'sha256':sha(path)})
        path.unlink()
    write(LOG/'sidecar-cleanup.json',{'time':now(),'removed':removed,'preexistingChangedUntouched':changed})

def verify():
    report=read(LOG/'release.json')
    if report['grant']!=GRANT or len(report['audits'])!=3 or any(a['ownedGroupMembers'] for a in report['audits']):raise ValueError('Incomplete supervisor release')
    groups=report['audits'][-1]['groups']
    live=[p for p in inventory() if any(p['pgid']==g['pgid'] and p['startTicks']>=g['startTicks'] for g in groups)]
    if live:raise ValueError('Owned heavy process remains')
    with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        available=now()
        fcntl.flock(lock,fcntl.LOCK_UN)
    result={'grant':GRANT,'released':now(),'supervisorReleaseSha256':sha(LOG/'release.json'),
            'ownedGroups':groups,'threeEmptyAudits':report['audits'],'currentOwnedMembers':live,
            'nonwaitingLockAvailableAt':available,'preexistingProcesses':'untouched',
            'noQueuedHeavyWork':report['noQueuedHeavyWork']}
    write(HERE/'evidence/release-receipt.json',result)
    print('U released; owned groups empty; shared lock available at',available)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--cleanup-sidecars',action='store_true');args=parser.parse_args()
    if args.cleanup_sidecars:cleanup()
    else:verify()
