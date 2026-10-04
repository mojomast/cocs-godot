"""Explicit one-shot compare-only supervisor. Never imports, retries or issues grants."""
import argparse,datetime,fcntl,json,os,signal,subprocess,time
from pathlib import Path
from policy import PHASE,MODE,GROUP,validate
from prepare import ROOT,HERE,load,sha,write,relative,validate_stage,verify_archive
LOCK=Path('/tmp/opencode/cocs-finish-acceptance.lock')
EXTERNAL_SECONDS=180
class Once(argparse.Action):
    def __call__(self,parser,namespace,values,option_string=None):
        if getattr(namespace,self.dest,None) is not None:parser.error('duplicate option: '+option_string)
        setattr(namespace,self.dest,values)
def identity(pid):
    try:
        raw=Path(f'/proc/{pid}/stat').read_text();parts=raw[raw.rfind(')')+2:].split()
        return {'pid':pid,'pgid':int(parts[2]),'startTicks':int(parts[19])}
    except (FileNotFoundError,ProcessLookupError):return None
def members(pgid):
    return [r for p in Path('/proc').iterdir() if p.name.isdigit() for r in [identity(int(p.name))] if r and r['pgid']==pgid]
def parser():
    p=argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    for arg in ['fixture','ae-root','engine','group','mode','grant-id','grant-sha256']:p.add_argument('--'+arg,required=True,action=Once)
    return p
def argv_for(engine,dest,a):
    if a.group!=GROUP or a.mode!=MODE:raise ValueError('compare-only CLI required')
    return [str(engine),'--headless','--single-threaded-scene','--path',str(dest),'--script','res://tests/walker_snap_compare/driver.gd','--',
        '--group='+GROUP,'--mode='+MODE,'--grant-id='+a.grant_id,'--grant-sha256='+a.grant_sha256]
def main(a):
    parent=ROOT/'godot/tests/walker_snap_compare';dest=Path(a.fixture).absolute();engine=Path(a.engine).absolute()
    if dest.parent!=parent or dest.resolve()!=dest or not dest.name.startswith('snap-compare-'):raise ValueError('stage namespace')
    if not Path(a.engine).is_absolute() or engine.resolve()!=engine or not engine.is_file():raise ValueError('explicit nonsymlink binary required')
    config=validate_stage(dest)
    pins=load(HERE/'review-pins.json')
    lineage=verify_archive(a.ae_root,pins['AEManifestPath'],pins['AEManifestSha256'],46)
    if lineage!=config['AEIdentity']:raise ValueError('lineage substitution')
    grant=load(relative(dest,'grant.json'))
    if sha(dest/'grant.json')!=a.grant_sha256:raise ValueError('sealed grant hash mismatch')
    validate(grant,group=a.group,mode=a.mode,grant_id=a.grant_id,source_hash=sha(dest/'source.json'),engine_hash=sha(engine),now=time.time())
    argv=argv_for(engine,dest,a)
    for name in ['comparison-result.json','supervisor-start.json','supervisor.log','supervisor-result.json']:
        if (dest/name).exists():raise FileExistsError('write-once invocation: '+name)
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        validate_stage(dest)
        validate(grant,group=a.group,mode=a.mode,grant_id=a.grant_id,source_hash=sha(dest/'source.json'),engine_hash=sha(engine),now=time.time())
        report={'phase':PHASE,'mode':MODE,'group':GROUP,'argv':argv,'grantSha256':a.grant_sha256,'sourceSha256':sha(dest/'source.json'),
            'engineSha256':sha(engine),'lockAcquiredUnix':time.time(),'timeoutSeconds':EXTERNAL_SECONDS,'autoRetry':False,'queued':False,
            'releaseAudits':[],'processGroupTrace':[],'environment':{'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'},'failed':True}
        owned=None;child=None
        def interrupted(number,frame):raise RuntimeError('supervisor interrupted: '+str(number))
        handlers={number:signal.signal(number,interrupted) for number in [signal.SIGTERM,signal.SIGHUP,signal.SIGINT]}
        try:
            with (dest/'supervisor.log').open('xb') as log:
                child=subprocess.Popen(argv,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,env={**os.environ,'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'})
                owned=identity(child.pid)
                if not owned or owned['pgid']!=child.pid:raise RuntimeError('owned session identity unavailable')
                report['owned']=owned;write(dest/'supervisor-start.json',report)
                deadline=time.monotonic()+EXTERNAL_SECONDS
                while child.poll() is None:
                    report['processGroupTrace'].append({'unix':time.time(),'members':members(owned['pgid'])})
                    text=(dest/'supervisor.log').read_text(errors='replace')
                    if time.monotonic()>=deadline or 'SCRIPT ERROR:' in text or 'Parse Error:' in text:
                        report['stopReason']='external_timeout' if time.monotonic()>=deadline else 'engine_script_error'
                        if identity(child.pid)==owned:os.killpg(child.pid,signal.SIGKILL)
                        break
                    time.sleep(.05)
                report['returnCode']=child.wait(timeout=10)
        except BaseException as error:
            report['supervisorError']=repr(error)
            if child and owned and identity(child.pid)==owned:
                os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=10)
        finally:
            for number in handlers:signal.signal(number,signal.SIG_IGN)
            if owned:
                # A group created by this invocation may outlive its leader.
                # Only that exact new pgid, with no older member, is eligible.
                remaining=members(owned['pgid'])
                leader=identity(owned['pid'])
                if remaining and (leader is None or leader==owned) and all(r['startTicks']>=owned['startTicks'] for r in remaining):
                    os.killpg(owned['pgid'],signal.SIGKILL);report['terminatedOwnedResiduals']=remaining
                for _ in range(3):
                    report['releaseAudits'].append({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'members':members(owned['pgid'])});time.sleep(.2)
            report['releasedCleanly']=bool(owned) and len(report['releaseAudits'])==3 and all(not r['members'] for r in report['releaseAudits'])
            try:
                native=load(dest/'comparison-result.json') if (dest/'comparison-result.json').is_file() else {}
            except (ValueError,OSError) as error:
                native={};report['invalidNativeReceipt']=repr(error)
            report['comparisonCollected']=native.get('comparisonCollected') is True
            report['failed']=not (report.get('returnCode')==0 and not report.get('stopReason') and not report.get('supervisorError') and report['releasedCleanly'] and native.get('failed') is False and native.get('mode')==MODE and native.get('group')==GROUP and native.get('sourceSha256')==report['sourceSha256'] and native.get('grantSha256')==a.grant_sha256 and report['comparisonCollected'])
            report['queryAgreementQualified']=False;report['nativeStepAdmission']=False
            report['lockReleaseUnix']=time.time();write(dest/'supervisor-result.json',report)
            for number,handler in handlers.items():signal.signal(number,handler)
        return 1 if report['failed'] else 0
if __name__=='__main__':raise SystemExit(main(parser().parse_args()))
