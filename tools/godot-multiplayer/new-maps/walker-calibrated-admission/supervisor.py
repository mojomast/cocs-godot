"""Manual one-group supervisor; no grant writer, retry or three-group executor.

Lifecycle adapted from approved AL: bounded outputs, prelaunch consumption,
owned cleanup, post-exit scan, measured release and independent workload failure.
"""
import argparse,fcntl,json,os,signal,subprocess,sys,time
from pathlib import Path
from .frozen import runtime
from .policy import PHASE,MODE,GROUPS,ENGINE,validate,successful
from .evidence import supervisor_ok
from .prepare import ROOT,load,write,sha,relative,validate_stage,lineage,dependencies
LOCK=Path('/tmp/opencode/cocs-finish-acceptance.lock');EXTERNAL_SECONDS=180
RESULT_CAP=64*1024*1024;LOG_CAP=4*1024*1024
def parser():
    p=argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    for name in ['fixture','al-root','ak-root','engine','group','mode','grant-id','grant-sha256']:p.add_argument('--'+name,required=True,action=runtime.Once)
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
def collect(dest,group,argv,report):
    log_path=dest/(group+'.log');result_path=dest/(group+'-result.json');child=owned=None;handlers={};report['partialCountersMayBeUnknown']=True
    def interrupted(number,frame):raise RuntimeError('supervisor interrupted: '+str(number))
    try:
        for number in [signal.SIGTERM,signal.SIGHUP,signal.SIGINT]:handlers[number]=signal.signal(number,interrupted)
        with log_path.open('xb') as log:
            child=subprocess.Popen(argv,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,env={**os.environ,'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'})
            owned=runtime.identity(child.pid)
            if not owned or owned['pid']!=child.pid or owned['pgid']!=child.pid:raise RuntimeError('owned identity unavailable')
            report['owned']=owned;deadline=time.monotonic()+EXTERNAL_SECONDS
            while child.poll() is None:
                report['processGroupTrace'].append({'unix':time.time(),'members':runtime.members(owned['pgid'])})
                reason=log_fault(log_path)
                if result_path.exists() and result_path.stat().st_size>RESULT_CAP:reason='result_cap'
                if time.monotonic()>=deadline:reason='external_timeout'
                if reason:report['stopReason']=reason;kill_owned(child,owned,report);break
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
            valid=successful(native,group,report['sourceSha256'],report['grantSha256'],report['engineSha256']) and native.get('dependenciesSha256')==report['dependenciesSha256']
            report['nativeOutcome']=native.get('outcome');report['nativePolicyValidated']=valid
            report['partialCountersMayBeUnknown']=not valid or bool(report.get('stopReason')) or bool(report.get('supervisorError'))
            report['failed']=not (report.get('returnCode')==0 and valid and report['releasedCleanly'] and not report.get('stopReason') and not report.get('supervisorError') and not report.get('cleanupErrors'))
        except Exception as error:runtime.cleanup_error(report,'finalization',error);report['failed']=True
        finally:
            for number,handler in handlers.items():
                try:signal.signal(number,handler)
                except Exception as error:runtime.cleanup_error(report,'restore_signal',error);report['failed']=True
        report['physicalCallCounts']=None;report['nativeStepAdmission']=False;report['productionPromotion']=False
        report['positiveAdmission']=not report['failed'] and group==GROUPS[2];report['scope']='calibrated-admission';report['lockReleasePendingUnix']=time.time()
        if not report['failed'] and not supervisor_ok(report,group,report['sourceSha256'],report['grantSha256'],report['engineSha256'],report.get('nativeReceiptSha256')):
            report['failed']=True;report['positiveAdmission']=False;report['supervisorError']='inconsistent_success_receipt'
        try:write(dest/(group+'-supervisor.json'),report)
        except Exception as error:
            runtime.cleanup_error(report,'write_result',error);report['failed']=True;report['positiveAdmission']=False
            try:sys.stderr.write(json.dumps(report)+'\n')
            except Exception:pass
    return 1 if report['failed'] else 0
def main(a):
    dest=Path(a.fixture).absolute();engine=Path(a.engine).absolute()
    if dest.parent!=ROOT/'godot/tests/walker_calibrated_admission' or dest.resolve()!=dest:raise ValueError('stage namespace')
    if not Path(a.engine).is_absolute() or engine.resolve()!=engine or not engine.is_file() or sha(engine)!=ENGINE:raise ValueError('pinned absolute nonsymlink Godot binary')
    config=validate_stage(dest)
    if lineage(a.al_root,a.ak_root)!=config['lineage']:raise ValueError('lineage substitution')
    grant_path=relative(dest,'grant.json');g=load(grant_path);source_hash=sha(dest/'source.json')
    def authorize():
        if sha(grant_path)!=a.grant_sha256 or load(grant_path)!=g:raise ValueError('grant changed')
        validate(g,group=a.group,mode=a.mode,grant_id=a.grant_id,source_hash=sha(dest/'source.json'),engine_hash=sha(engine),now=time.time())
        if sha(dest/'source.json')!=source_hash:raise ValueError('source changed')
    authorize()
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);validate_stage(dest);lineage(a.al_root,a.ak_root);authorize()
        group=a.group
        for suffix in ['-result.json','-supervisor.json','-start.json','-dependencies.json','.log']:
            if (dest/(group+suffix)).exists():raise FileExistsError('consumed group invocation')
        deps=dependencies(dest,group,source_hash,a.grant_sha256,ENGINE);write(dest/(group+'-dependencies.json'),deps);dh=sha(dest/(group+'-dependencies.json'))
        argv=[str(engine),'--headless','--single-threaded-scene','--path',str(dest),'--script','res://tests/walker_calibrated_admission/driver.gd','--','--group='+group,'--mode='+MODE,'--grant-id='+a.grant_id,'--grant-sha256='+a.grant_sha256,'--dependencies-sha256='+dh]
        report={'phase':PHASE,'mode':MODE,'group':group,'sourceSha256':source_hash,'grantSha256':a.grant_sha256,'engineSha256':ENGINE,'dependenciesSha256':dh,'argv':argv,'lockAcquiredUnix':time.time(),'timeoutSeconds':EXTERNAL_SECONDS,'autoRetry':False,'queued':False,'releaseAudits':[],'processGroupTrace':[],'failed':True,'releasedCleanly':False,'environment':{'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'}}
        write(dest/(group+'-start.json'),report)
        return collect(dest,group,argv,report)
def cli():return main(parser().parse_args())
