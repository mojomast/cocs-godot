"""Future manual ONE admission group. No imports, queue, retry or grant issuance."""
import argparse,fcntl,json,os,signal,subprocess,time
from pathlib import Path
from prepare import ROOT,sha,write,verify_ab
from phase import validate
LOCK=Path('/tmp/opencode/cocs-finish-acceptance.lock')
def identity(pid):
    try:
        raw=Path(f'/proc/{pid}/stat').read_text();f=raw[raw.rfind(')')+2:].split()
        return {'pid':pid,'pgid':int(f[2]),'startTicks':int(f[19])}
    except (FileNotFoundError,ProcessLookupError):return None
def members(pgid):
    return [r for p in Path('/proc').iterdir() if p.name.isdigit() for r in [identity(int(p.name))] if r and r['pgid']==pgid]
def main(a):
    dest=Path(a.fixture).resolve(strict=True);engine=Path(a.engine).resolve(strict=True)
    if dest.parent!=ROOT/'godot/tests/walker_admission':raise ValueError('namespace')
    grant=json.loads((dest/'grant.json').read_text());config=json.loads((dest/'source.json').read_text())
    validate(grant,a.group)
    if grant.get('sourceSha256')!=sha(dest/'source.json'):raise ValueError('grant must bind exact prepared source receipt')
    if sha(dest/'grant.json')!=a.grant_sha256 or grant.get('grantId')!=a.grant_id or not grant.get('authorized') or grant.get('expiresUnix',0)<=time.time() or sha(engine)!=grant.get('engineSha256'):raise ValueError('explicit valid grant/binary required')
    if verify_ab(a.ab_root)!=config['abLineage']:raise ValueError('AB lineage drift')
    for name,h in config['files'].items():
        if sha(ROOT/'godot'/name.removeprefix('res://'))!=h:raise ValueError(name)
    for name,h in config['productionDependencies'].items():
        if sha(ROOT/name)!=h:raise ValueError(name)
    stem=dest/(a.group+'-supervisor')
    if Path(str(stem)+'.log').exists() or Path(str(stem)+'.json').exists():raise FileExistsError('write-once group')
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        argv=[str(engine),'--headless','--path',str(ROOT/'godot'),'--script','res://tests/walker_admission/driver_v4.gd','--',
              '--fixture=res://tests/walker_admission/'+dest.name+'/', '--group='+a.group,'--grant-id='+a.grant_id,'--grant-sha256='+a.grant_sha256]
        report={'argv':argv,'grantSha256':sha(dest/'grant.json'),'startUnix':time.time(),'timeoutSeconds':180,'releaseAudits':[],'autoRetry':False}
        with Path(str(stem)+'.log').open('xb') as log:
            child=subprocess.Popen(argv,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,env={**os.environ,'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'})
            owned=identity(child.pid);report['owned']=owned
            try:report['returnCode']=child.wait(timeout=180)
            except subprocess.TimeoutExpired:
                report['timeout']=True
                if owned and identity(child.pid)==owned:os.killpg(child.pid,signal.SIGKILL)
                report['returnCode']=child.wait(timeout=10)
        for _ in range(3):
            report['releaseAudits'].append({'unix':time.time(),'members':members(child.pid)});time.sleep(.2)
        report['releasedCleanly']=all(not r['members'] for r in report['releaseAudits'])
        report['finishUnix']=time.time();write(Path(str(stem)+'.json'),report)
        if not report['releasedCleanly']:raise RuntimeError('owned group not empty; parent intervention required')
        return report['returnCode']
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for arg in ['fixture','engine','group','grant-id','grant-sha256','ab-root']:p.add_argument('--'+arg,required=True)
    raise SystemExit(main(p.parse_args()))
