"""Manual one-group invocation; no grant creation, queue, retries or continuation."""
import argparse,fcntl,json,os,signal,subprocess,sys,time
from pathlib import Path
from frozen import runtime
from policy import PHASE,MODE,GROUPS,validate,successful
from prepare import ROOT,HERE,load,write,sha,relative,validate_stage,lineage,dependencies
from evidence import supervisor_ok
LOCK=Path('/tmp/opencode/cocs-finish-acceptance.lock');EXTERNAL_SECONDS=180
Once=runtime.Once
def parser():
    p=argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    for name in ['fixture','ag-root','af-root','engine','group','mode','grant-id','grant-sha256']:p.add_argument('--'+name,required=True,action=Once)
    return p
def main(a):
    dest=Path(a.fixture).absolute();engine=Path(a.engine).absolute()
    if dest.parent!=ROOT/'godot/tests/walker_parity_admission' or dest.resolve()!=dest:raise ValueError('stage namespace')
    if not Path(a.engine).is_absolute() or engine.resolve()!=engine or not engine.is_file():raise ValueError('explicit nonsymlink binary required')
    config=validate_stage(dest);pins=load(HERE/'review-pins.json')
    if lineage(a.ag_root,a.af_root,pins)!=config['lineage']:raise ValueError('lineage substitution')
    g=load(relative(dest,'grant.json'));source_hash=sha(dest/'source.json');engine_hash=sha(engine)
    if sha(dest/'grant.json')!=a.grant_sha256:raise ValueError('sealed grant hash')
    validate(g,group=a.group,mode=a.mode,grant_id=a.grant_id,source_hash=source_hash,engine_hash=engine_hash,now=time.time())
    def path(suffix):return dest/(a.group+suffix)
    for suffix in ['-result.json','-supervisor.json','-start.json','-dependencies.json','.log']:
        if path(suffix).exists():raise FileExistsError('write-once invocation')
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        validate_stage(dest)
        validate(g,group=a.group,mode=a.mode,grant_id=a.grant_id,source_hash=sha(dest/'source.json'),engine_hash=sha(engine),now=time.time())
        deps=dependencies(dest,a.group,source_hash,a.grant_sha256,engine_hash);write(path('-dependencies.json'),deps)
        deps_hash=sha(path('-dependencies.json'))
        argv=[str(engine),'--headless','--single-threaded-scene','--path',str(dest),'--script','res://tests/walker_parity_admission/driver.gd','--','--group='+a.group,'--mode='+MODE,'--grant-id='+a.grant_id,'--grant-sha256='+a.grant_sha256,'--dependencies-sha256='+deps_hash]
        report={'phase':PHASE,'mode':MODE,'group':a.group,'sourceSha256':source_hash,'grantSha256':a.grant_sha256,'engineSha256':engine_hash,'dependenciesSha256':deps_hash,'argv':argv,'lockAcquiredUnix':time.time(),'timeoutSeconds':180,'autoRetry':False,'queued':False,'releaseAudits':[],'processGroupTrace':[],'failed':True,'environment':{'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'}}
        owned=None;child=None
        def interrupted(number,frame):raise RuntimeError('supervisor interrupted: '+str(number))
        handlers={number:signal.signal(number,interrupted) for number in [signal.SIGTERM,signal.SIGHUP,signal.SIGINT]}
        try:
            with path('.log').open('xb') as log:
                child=subprocess.Popen(argv,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,env={**os.environ,'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'})
                owned=runtime.identity(child.pid)
                if not owned or owned['pgid']!=child.pid:raise RuntimeError('owned session identity unavailable')
                report['owned']=owned;write(path('-start.json'),report);deadline=time.monotonic()+EXTERNAL_SECONDS
                while child.poll() is None:
                    report['processGroupTrace'].append({'unix':time.time(),'members':runtime.members(owned['pgid'])})
                    text=path('.log').read_text(errors='replace')
                    if time.monotonic()>=deadline or 'SCRIPT ERROR:' in text or 'Parse Error:' in text:
                        report['stopReason']='external_timeout' if time.monotonic()>=deadline else 'engine_script_error'
                        if runtime.identity(child.pid)==owned:os.killpg(child.pid,signal.SIGKILL)
                        break
                    time.sleep(.05)
                report['returnCode']=child.wait(timeout=10)
        except BaseException as error:
            report['supervisorError']=repr(error)
            try:
                if child and owned and runtime.identity(child.pid)==owned:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=10)
            except Exception as cleanup_exception:runtime.cleanup_error(report,'exception_cleanup',cleanup_exception)
        finally:
            try:
                for number in handlers:
                    try:signal.signal(number,signal.SIG_IGN)
                    except Exception as error:runtime.cleanup_error(report,'ignore_signal',error)
                runtime.audit_release(owned,report)
                text=path('.log').read_text(errors='replace')
                if 'SCRIPT ERROR:' in text or 'Parse Error:' in text:report['stopReason']='engine_script_error'
                try:
                    native=load(path('-result.json')) if path('-result.json').is_file() else {}
                    if not isinstance(native,dict):raise ValueError('native receipt must be object')
                except (ValueError,OSError) as error:native={};report['invalidNativeReceipt']=repr(error)
                report['nativeReceiptSha256']=sha(path('-result.json')) if path('-result.json').is_file() else None
                report['partialCountersMayBeUnknown']=not native or bool(report.get('stopReason')) or bool(report.get('supervisorError'))
                report['nativeOutcome']=native.get('outcome')
                report['failed']=not (report.get('returnCode')==0 and not report.get('stopReason') and not report.get('supervisorError') and report['releasedCleanly'] and successful(native,a.group,source_hash,a.grant_sha256,engine_hash) and native.get('dependenciesSha256')==deps_hash)
                report['positiveAdmission']=not report['failed'] and a.group==GROUPS[2]
            except Exception as error:runtime.cleanup_error(report,'finalization',error);report['failed']=True;report['releasedCleanly']=False
            finally:
                for number,handler in handlers.items():
                    try:signal.signal(number,handler)
                    except Exception as error:runtime.cleanup_error(report,'restore_signal',error);report['failed']=True;report['releasedCleanly']=False
            if report['failed']:report['positiveAdmission']=False
            report['nativeStepAdmission']=False;report['productionPromotion']=False;report['scope']='synthetic-admission';report['lockReleasePendingUnix']=time.time()
            if not report['failed'] and not supervisor_ok(report,a.group,source_hash,a.grant_sha256,engine_hash,report['nativeReceiptSha256']):
                report['failed']=True;report['positiveAdmission']=False;report['supervisorError']='inconsistent_success_receipt'
            try:write(path('-supervisor.json'),report)
            except Exception as error:
                runtime.cleanup_error(report,'write_result',error);report['failed']=True;report['positiveAdmission']=False
                try:sys.stderr.write(json.dumps(report)+'\n')
                except Exception:pass
        return 1 if report['failed'] else 0
if __name__=='__main__':raise SystemExit(main(parser().parse_args()))
