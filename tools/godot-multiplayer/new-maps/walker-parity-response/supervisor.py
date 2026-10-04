"""Single-response supervisor; isolated copy of corrected AF ownership lifecycle."""
import argparse,datetime,fcntl,json,os,signal,subprocess,sys,time
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
def cleanup_error(report,operation,error):
    report.setdefault('cleanupErrors',[]).append({'operation':operation,'error':repr(error)})
def audit_release(owned,report):
    # Signal delivery (including ESRCH) is never evidence of an empty group.
    try:
        if not owned or owned['pid']!=owned['pgid']:raise RuntimeError('owned session identity unavailable')
        remaining=members(owned['pgid'])
        leader=identity(owned['pid'])
        if leader is not None and leader!=owned:raise RuntimeError('leader identity changed; refusing group signal')
        if any(r['startTicks']<owned['startTicks'] for r in remaining):raise RuntimeError('older group member; refusing group signal')
        if remaining:
            try:
                os.killpg(owned['pgid'],signal.SIGKILL)
                report['signalledOwnedResiduals']=remaining
            except ProcessLookupError:
                report['residualGroupDisappearedBeforeSignal']=True
    except Exception as error:
        cleanup_error(report,'residual_cleanup',error)
    for _ in range(3):
        audit={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'members':None,'measured':False}
        try:
            if not owned:raise RuntimeError('cannot audit without owned identity')
            audit['members']=members(owned['pgid']);audit['measured']=True
        except Exception as error:
            audit['error']=repr(error);cleanup_error(report,'release_audit',error)
        report['releaseAudits'].append(audit)
        try:time.sleep(.2)
        except Exception as error:cleanup_error(report,'audit_interval',error)
    report['releasedCleanly']=bool(owned) and not report.get('cleanupErrors') and len(report['releaseAudits'])==3 and all(r['measured'] and r['members']==[] for r in report['releaseAudits'])
def parser():
    p=argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    for arg in ['fixture','af-root','engine','group','mode','grant-id','grant-sha256']:p.add_argument('--'+arg,required=True,action=Once)
    return p
def argv_for(engine,dest,a):
    if a.group!=GROUP or a.mode!=MODE:raise ValueError('single-response CLI required')
    return [str(engine),'--headless','--single-threaded-scene','--path',str(dest),'--script','res://tests/walker_parity_response/driver.gd','--',
        '--group='+GROUP,'--mode='+MODE,'--grant-id='+a.grant_id,'--grant-sha256='+a.grant_sha256]
def successful_response(native,source_hash,grant_hash,engine_hash):
    return (native.get('failed') is False and native.get('phase')==PHASE and native.get('mode')==MODE and native.get('group')==GROUP
        and native.get('sourceSha256')==source_hash and native.get('grantSha256')==grant_hash and native.get('engineSha256')==engine_hash
        and native.get('candidateResponseCollected') is True and native.get('responseGuardPassed') is True
        and all(type(native.get(key)) in (int,float) and native[key]==1 for key in ['candidateAttempts','appliedUpCount','parentResponseCount'])
        and native.get('positiveAdmission') is False and native.get('nativeStepAdmission') is False
        and native.get('outcome')=='single_response_guard_passed_not_positive_admission')
def main(a):
    parent=ROOT/'godot/tests/walker_parity_response';dest=Path(a.fixture).absolute();engine=Path(a.engine).absolute()
    if dest.parent!=parent or dest.resolve()!=dest or not dest.name.startswith('parity-response-'):raise ValueError('stage namespace')
    if not Path(a.engine).is_absolute() or engine.resolve()!=engine or not engine.is_file():raise ValueError('explicit nonsymlink binary required')
    config=validate_stage(dest)
    pins=load(HERE/'review-pins.json')
    lineage=verify_archive(a.af_root,pins['AFManifestPath'],pins['AFManifestSha256'],24)
    if lineage!=config['AFIdentity']:raise ValueError('lineage substitution')
    grant=load(relative(dest,'grant.json'))
    if sha(dest/'grant.json')!=a.grant_sha256:raise ValueError('sealed grant hash mismatch')
    validate(grant,group=a.group,mode=a.mode,grant_id=a.grant_id,source_hash=sha(dest/'source.json'),engine_hash=sha(engine),now=time.time())
    argv=argv_for(engine,dest,a)
    for name in ['response-result.json','supervisor-start.json','supervisor.log','supervisor-result.json']:
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
            try:
                if child and owned and identity(child.pid)==owned:
                    os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=10)
            except Exception as cleanup_exception:
                cleanup_error(report,'exception_cleanup',cleanup_exception)
        finally:
            try:
                for number in handlers:
                    try:signal.signal(number,signal.SIG_IGN)
                    except Exception as error:cleanup_error(report,'ignore_signal',error)
                audit_release(owned,report)
                # A fast exit can precede the polling loop's error scan.
                final_log=(dest/'supervisor.log').read_text(errors='replace')
                if 'SCRIPT ERROR:' in final_log or 'Parse Error:' in final_log:report['stopReason']='engine_script_error'
                try:
                    native=load(dest/'response-result.json') if (dest/'response-result.json').is_file() else {}
                    if not isinstance(native,dict):raise ValueError('native receipt must be an object')
                except (ValueError,OSError) as error:
                    native={};report['invalidNativeReceipt']=repr(error)
                report['candidateResponseCollected']=native.get('candidateResponseCollected') is True
                report['responseGuardPassed']=native.get('responseGuardPassed') is True
                report['nativeOutcome']=native.get('outcome')
                report['failed']=not (report.get('returnCode')==0 and not report.get('stopReason') and not report.get('supervisorError') and report['releasedCleanly'] and successful_response(native,report['sourceSha256'],a.grant_sha256,report['engineSha256']))
            except Exception as error:
                cleanup_error(report,'finalization',error);report['failed']=True;report['releasedCleanly']=False
            finally:
                # Restoration is independent of cleanup and receipt I/O success.
                for number,handler in handlers.items():
                    try:signal.signal(number,handler)
                    except Exception as error:
                        cleanup_error(report,'restore_signal',error);report['failed']=True;report['releasedCleanly']=False
            report['positiveAdmission']=False;report['nativeStepAdmission']=False
            # The surrounding file context releases flock on every exit, including
            # failed receipt writes. This timestamp precedes release, not proof of it.
            report['lockReleasePendingUnix']=time.time()
            try:write(dest/'supervisor-result.json',report)
            except Exception as error:
                cleanup_error(report,'write_result',error);report['failed']=True
                try:sys.stderr.write(json.dumps(report)+'\n')
                except Exception:pass # Best effort only; never convert I/O failure to success.
        return 1 if report['failed'] else 0
if __name__=='__main__':raise SystemExit(main(parser().parse_args()))
