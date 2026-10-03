"""S grant: nonwaiting lifetime lock, serial bounded process groups, immutable logs."""
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
STATE = Path('/tmp/opencode/foundry-astra-S')
LOG = HERE/'evidence/attempts'
def now(): return dt.datetime.now(dt.timezone.utc).isoformat()
def write(path, data): path.write_text(json.dumps(data, indent=2)+'\n')
def inventory():
    result=[]
    for p in Path('/proc').iterdir():
        if not p.name.isdigit(): continue
        try:
            stat=(p/'stat').read_text(); fields=stat[stat.rfind(')')+2:].split()
            result.append({'pid':int(p.name),'ppid':int(fields[1]),'pgid':int(fields[2]),
                'startTicks':int(fields[19]),'comm':(p/'comm').read_text().strip(),
                'argv':(p/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace')})
        except (FileNotFoundError,ProcessLookupError,PermissionError): pass
    return result
def sidecars():
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (ROOT/'godot').rglob('*') if p.is_file() and '.godot' not in p.parts and p.suffix in ('.import','.uid')}
def serve():
    STATE.mkdir(exist_ok=True); LOG.mkdir(parents=True,exist_ok=True)
    with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        baseline=inventory(); own=next(p for p in baseline if p['pid']==os.getpid())
        write(LOG/'grant-start.json',{'grant':'MOTH-BLENDER-20261003-S','time':now(),'owner':own,
            'preexistingMatching':[p for p in baseline if any(s in p['comm'].lower() for s in ('godot','blender','ffmpeg','xvfb'))],
            'git':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()})
        write(LOG/'sidecars-before.json',sidecars()); write(STATE/'ready.json',own)
        groups=[]; deadline=time.monotonic()+14400
        while time.monotonic()<deadline:
            requests=sorted(STATE.glob('*.request.json'))
            if not requests: time.sleep(.15); continue
            req=requests[0]; job=json.loads(req.read_text()); req.rename(req.with_suffix('.running'))
            if job['command']==['RELEASE']:
                audits=[]
                for _ in range(3):
                    live=[p for p in inventory() if any(p['pgid']==g['pgid'] and p['startTicks']>=g['startTicks'] for g in groups)]
                    audits.append({'time':now(),'ownedGroupMembers':live,'groups':groups.copy()})
                    if live: raise RuntimeError('Owned group remains: '+str(live))
                    time.sleep(.2)
                write(LOG/'sidecars-after.json',sidecars())
                write(LOG/'release.json',{'grant':'MOTH-BLENDER-20261003-S','time':now(),'audits':audits,
                    'noQueuedHeavyWork':not list(STATE.glob('*.request.json')),'ownership':'exact PGID plus kernel start ticks; preexisting excluded'})
                fcntl.flock(lock,fcntl.LOCK_UN)
                write(STATE/(job['id']+'.result.json'),{'returncode':0,'released':now()}); return
            before=now(); stem=LOG/job['id']; env=os.environ.copy()
            env.update({'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1','PYTHONDONTWRITEBYTECODE':'1'})
            # Preserve every attempt, including parser/import failures.
            meta={'command':job['command'],'timeoutSeconds':job['timeout'],'start':before,
                'git':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                'inputDiffSha256':hashlib.sha256(subprocess.check_output(['git','diff','HEAD'],cwd=ROOT)).hexdigest(),
                'sourceHashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                    for base in (HERE,ROOT/'godot/tests/new_maps/gravemill_foundry/revision5')
                    for p in base.rglob('*') if p.is_file() and p.suffix in ('.py','.mjs','.gd','.json') and 'evidence' not in p.parts}}
            with open(str(stem)+'.log','wb') as output:
                proc=subprocess.Popen(job['command'],cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
                identity=next(p for p in inventory() if p['pid']==proc.pid)
                groups.append(identity);meta['owner']=identity;write(Path(str(stem)+'.json'),meta)
                try: code=proc.wait(timeout=job['timeout'])
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid,signal.SIGTERM)
                    try: proc.wait(timeout=10)
                    except subprocess.TimeoutExpired: os.killpg(proc.pid,signal.SIGKILL);proc.wait()
                    code=124
            remaining=[p for p in inventory() if p['pgid']==identity['pgid'] and p['startTicks']>=identity['startTicks']]
            meta.update({'end':now(),'returncode':code,'remainingGroupMembers':remaining})
            write(Path(str(stem)+'.json'),meta);write(STATE/(job['id']+'.result.json'),meta)
            if remaining: raise RuntimeError('Orphaned owned group: '+str(remaining))
        raise RuntimeError('Grant lifetime exceeded')
if __name__=='__main__':
    if sys.argv[1]=='serve':serve()
    else:
        ident=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%f')
        command=sys.argv[3:] if sys.argv[1]=='run' else ['RELEASE']
        timeout=int(sys.argv[2]) if sys.argv[1]=='run' else 30
        if not (STATE/'ready.json').exists():raise RuntimeError('Grant not ready')
        owner=json.loads((STATE/'ready.json').read_text())
        if not any(p['pid']==owner['pid'] and p['startTicks']==owner['startTicks'] for p in inventory()):
            raise RuntimeError('Grant owner has exited; acquire a new authorized grant before submitting work')
        write(STATE/(ident+'.request.json'),{'id':ident,'command':command,'timeout':timeout})
        result=STATE/(ident+'.result.json')
        while not result.exists():time.sleep(.2)
        data=json.loads(result.read_text());print(json.dumps({k:v for k,v in data.items() if k!='sourceHashes'},indent=2))
        log=LOG/(ident+'.log')
        if log.exists():print(log.read_text()[-18000:])
        sys.exit(data['returncode'])
