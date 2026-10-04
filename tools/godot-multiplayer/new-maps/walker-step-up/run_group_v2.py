"""Future explicit single-group supervisor. No waiting, queue, retry or batch loop."""
import argparse,fcntl,hashlib,json,os,re,signal,subprocess,time
from pathlib import Path
from prepare_v2 import ROOT,write,digest
from grant_policy_v3 import validate_phase
LOCK=Path('/tmp/opencode/cocs-finish-acceptance.lock')
def identity(pid):
    try:
        raw=Path(f'/proc/{pid}/stat').read_text();fields=raw[raw.rfind(')')+2:].split()
        return {'pid':pid,'pgid':int(fields[2]),'startTicks':int(fields[19])}
    except (FileNotFoundError,ProcessLookupError):return None
def members(pgid):
    found=[]
    for p in Path('/proc').iterdir():
        if p.name.isdigit():
            row=identity(int(p.name))
            if row and row['pgid']==pgid:found.append(row)
    return found
def main(a):
    dest=Path(a.fixture).resolve(strict=True);engine=Path(a.engine).resolve(strict=True)
    if dest.parent!=ROOT/'godot/tests/walker_step_up' or not re.fullmatch('[a-z0-9-]+',a.group):raise ValueError('namespace')
    grant=dest/'grant.json';g=json.loads(grant.read_text());config=json.loads((dest/'source.json').read_text())
    if digest(grant)!=a.grant_sha256 or g.get('grantId')!=a.grant_id or not g.get('authorized'):raise ValueError('explicit grant receipt required')
    validate_phase(g,a.group,a.continue_after_known_baseline_failure)
    if g.get('expiresUnix',0)<=time.time() or digest(engine)!=g.get('engineSha256'):raise ValueError('grant expired or binary identity mismatch')
    if a.group not in config['groups']:raise ValueError('one known group only')
    if a.continue_after_known_baseline_failure and not g.get('continueAfterKnownBaselineFailure'):raise ValueError('continuation not granted')
    for path,h in config['files'].items():
        if digest(ROOT/'godot'/path.removeprefix('res://'))!=h:raise ValueError(path)
    for path,h in config['productionDependencies'].items():
        if digest(ROOT/path)!=h:raise ValueError(path)
    stem=dest/(a.group+'-supervisor')
    if Path(str(stem)+'.json').exists() or Path(str(stem)+'.log').exists():raise FileExistsError('write-once invocation')
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        argv=[str(engine),'--headless','--path',str(ROOT/'godot'),'--script','res://tests/walker_step_up/driver_v2.gd','--',
              '--fixture=res://tests/walker_step_up/'+dest.name+'/', '--group='+a.group,'--grant-id='+a.grant_id,'--grant-sha256='+a.grant_sha256]
        if a.continue_after_known_baseline_failure:argv.append('--continue-after-known-baseline-failure')
        report={'argv':argv,'grantSha256':digest(grant),'startUnix':time.time(),'timeoutSeconds':180,'autoRetry':False,'queued':False,'releaseAudits':[]}
        with Path(str(stem)+'.log').open('xb') as log:
            process=subprocess.Popen(argv,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            owned=identity(process.pid);report['owned']=owned
            try:report['returnCode']=process.wait(timeout=180)
            except subprocess.TimeoutExpired:
                report['timeout']=True
                if owned and identity(process.pid)==owned:os.killpg(process.pid,signal.SIGKILL)
                report['returnCode']=process.wait(timeout=10)
        # No broad cleanup or inherited-process termination. Lingering descendants
        # leave a failed release receipt for parent intervention, never a success.
        for _ in range(3):
            report['releaseAudits'].append({'unix':time.time(),'members':members(process.pid)})
            time.sleep(.2)
        report['releasedCleanly']=all(not audit['members'] for audit in report['releaseAudits'])
        report['finishUnix']=time.time();write(Path(str(stem)+'.json'),report)
        if not report['releasedCleanly']:raise RuntimeError('owned group not empty; parent intervention required')
        return report['returnCode']
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['fixture','engine','group','grant-id','grant-sha256']:p.add_argument('--'+name,required=True)
    p.add_argument('--continue-after-known-baseline-failure',action='store_true')
    raise SystemExit(main(p.parse_args()))
