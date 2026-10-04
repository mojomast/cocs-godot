"""Manual single-use supervisor; no grant creation, retry, selection or continuation."""
import argparse,fcntl,json,os,signal,subprocess,sys,time
from pathlib import Path
from frozen import runtime
from policy import PHASE,MODE,GROUP,ENGINE,validate,successful
from prepare import ROOT,HERE,load,write,sha,relative,validate_stage,lineage,LINEAGE
LOCK=Path('/tmp/opencode/cocs-finish-acceptance.lock')
EXTERNAL_SECONDS=180;RESULT_CAP=64*1024*1024;LOG_CAP=4*1024*1024
Once=runtime.Once
def parser():
    p=argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    for name in ['fixture','ak-root','engine','group','mode','grant-id','grant-sha256']:p.add_argument('--'+name,required=True,action=Once)
    return p
def log_fault(path):
    if not path.exists():return 'missing_log'
    if path.stat().st_size>LOG_CAP:return 'log_cap'
    text=path.read_text(errors='replace')
    if 'SCRIPT ERROR:' in text or 'Parse Error:' in text:return 'engine_script_error'
    if 'ADMISSION_FAILURE ' in text:return 'admission_failure'
    return None
def kill_owned(child,owned,report):
    if not child or not owned:return
    now=runtime.identity(child.pid)
    if now is not None and now!=owned:raise RuntimeError('PID reuse; refusing signal')
    if now==owned:
        try:os.killpg(owned['pgid'],signal.SIGKILL)
        except ProcessLookupError:report['leaderDisappearedBeforeSignal']=True
def collect(dest,argv,report):
    """Called only inside locked, consumed, revalidated invocation; injected via mocks in tests."""
    log_path=dest/(GROUP+'.log');result_path=dest/(GROUP+'-result.json')
    child=owned=None;handlers={};report['partialCountersMayBeUnknown']=True
    def interrupted(number,frame):raise RuntimeError('supervisor interrupted: '+str(number))
    try:
        for number in [signal.SIGTERM,signal.SIGHUP,signal.SIGINT]:handlers[number]=signal.signal(number,interrupted)
        with log_path.open('xb') as log:
            child=subprocess.Popen(argv,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,env={**os.environ,'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'})
            owned=runtime.identity(child.pid)
            if not owned or owned['pid']!=child.pid or owned['pgid']!=child.pid:raise RuntimeError('owned session identity unavailable')
            report['owned']=owned;deadline=time.monotonic()+EXTERNAL_SECONDS
            while child.poll() is None:
                report['processGroupTrace'].append({'unix':time.time(),'members':runtime.members(owned['pgid'])})
                reason=log_fault(log_path)
                if result_path.exists() and result_path.stat().st_size>RESULT_CAP:reason='result_cap'
                if time.monotonic()>=deadline:reason='external_timeout'
                if reason:
                    report['stopReason']=reason;kill_owned(child,owned,report);break
                time.sleep(.05)
            report['returnCode']=child.wait(timeout=10)
    except BaseException as error:
        report['supervisorError']=repr(error)
        try:
            kill_owned(child,owned,report)
            if child:child.wait(timeout=10)
        except Exception as error:runtime.cleanup_error(report,'exception_cleanup',error)
    finally:
        try:
            for number in handlers:
                try:signal.signal(number,signal.SIG_IGN)
                except Exception as error:runtime.cleanup_error(report,'ignore_signal',error)
            runtime.audit_release(owned,report)
            reason=log_fault(log_path)
            if reason:report['stopReason']=reason
            native={}
            try:
                if result_path.exists():
                    if result_path.is_symlink() or result_path.stat().st_size>RESULT_CAP:raise ValueError('result bounds')
                    native=load(result_path)
                    if not isinstance(native,dict):raise ValueError('native object required')
                    report['nativeReceiptSha256']=sha(result_path)
            except (OSError,ValueError) as error:report['invalidNativeReceipt']=repr(error)
            valid=successful(native,report['sourceSha256'],report['grantSha256'],report['engineSha256']) and native.get('dependenciesSha256')==report['dependenciesSha256']
            report['nativeOutcome']=native.get('outcome');report['nativeCollectionValidated']=valid
            report['partialCountersMayBeUnknown']=not valid or bool(report.get('stopReason')) or bool(report.get('supervisorError'))
            report['failed']=not (report.get('returnCode')==0 and valid and report['releasedCleanly'] and not report.get('stopReason') and not report.get('supervisorError') and not report.get('cleanupErrors'))
        except Exception as error:runtime.cleanup_error(report,'finalization',error);report['failed']=True
        finally:
            for number,handler in handlers.items():
                try:signal.signal(number,handler)
                except Exception as error:runtime.cleanup_error(report,'restore_signal',error);report['failed']=True
        # Clean release is solely the measured group audit, independent of workload success.
        report['completedCharacterization']=not report['failed']
        report['physicalCallCounts']=None;report['candidateAdmission']=False;report['selectedHeight']=None;report['productionPromotion']=False
        report['lockReleasePendingUnix']=time.time()
        try:write(dest/(GROUP+'-supervisor.json'),report)
        except Exception as error:
            runtime.cleanup_error(report,'write_result',error);report['failed']=True;report['completedCharacterization']=False
            try:sys.stderr.write(json.dumps(report)+'\n')
            except Exception:pass
    return 1 if report['failed'] else 0
def main(a):
    dest=Path(a.fixture).absolute();engine=Path(a.engine).absolute()
    if dest.parent!=ROOT/'godot/tests/walker_baseline_characterization' or dest.resolve()!=dest:raise ValueError('stage namespace')
    if not Path(a.engine).is_absolute() or engine.resolve()!=engine or not engine.is_file() or sha(engine)!=ENGINE:raise ValueError('pinned absolute nonsymlink Godot 4.5.2 binary')
    config=validate_stage(dest)
    if lineage(a.ak_root)!=config['lineage']:raise ValueError('lineage substitution')
    grant_path=relative(dest,'grant.json');g=load(grant_path);source_hash=sha(dest/'source.json')
    if sha(grant_path)!=a.grant_sha256:raise ValueError('grant hash')
    def authorize():
        if sha(grant_path)!=a.grant_sha256 or load(grant_path)!=g:raise ValueError('grant changed')
        validate(g,group=a.group,mode=a.mode,grant_id=a.grant_id,source_hash=sha(dest/'source.json'),engine_hash=sha(engine),now=time.time())
        if sha(dest/'source.json')!=source_hash:raise ValueError('source changed')
    authorize()
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        validate_stage(dest);lineage(a.ak_root);authorize()
        for suffix in ['-result.json','-supervisor.json','-start.json','-dependencies.json','.log']:
            if (dest/(GROUP+suffix)).exists():raise FileExistsError('consumed invocation')
        deps={'phase':PHASE,'group':GROUP,'sourceSha256':source_hash,'grantSha256':a.grant_sha256,'engineSha256':ENGINE,'lineage':LINEAGE,'predecessors':{}}
        write(dest/(GROUP+'-dependencies.json'),deps);dh=sha(dest/(GROUP+'-dependencies.json'))
        argv=[str(engine),'--headless','--single-threaded-scene','--path',str(dest),'--script','res://tests/walker_baseline_characterization/driver.gd','--','--group='+GROUP,'--mode='+MODE,'--grant-id='+a.grant_id,'--grant-sha256='+a.grant_sha256,'--dependencies-sha256='+dh]
        report={'phase':PHASE,'mode':MODE,'group':GROUP,'sourceSha256':source_hash,'grantSha256':a.grant_sha256,'engineSha256':ENGINE,'dependenciesSha256':dh,'argv':argv,'lockAcquiredUnix':time.time(),'timeoutSeconds':EXTERNAL_SECONDS,'autoRetry':False,'queued':False,'releaseAudits':[],'processGroupTrace':[],'failed':True,'releasedCleanly':False,'completedCharacterization':False,'environment':{'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'}}
        # Consume before Popen, including launch failure. No retry can reuse this stage.
        write(dest/(GROUP+'-start.json'),report)
        return collect(dest,argv,report)
if __name__=='__main__':raise SystemExit(main(parser().parse_args()))
