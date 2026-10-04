"""Manual, grant-bound, ONE receipt-only invocation. No retry or campaign launch."""
import argparse,datetime,fcntl,json,os,signal,subprocess,sys,time
from pathlib import Path
import contract as C
import ownership as O
from prepare import load,write,sha,unique,validate_stage,verify_ai
LOCK=Path('/tmp/opencode/cocs-finish-acceptance.lock')
EXTERNAL_SECONDS=180
def parser():
    p=argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    for name in ['fixture','ai-root','engine','group','mode','grant-id','grant-sha256']:p.add_argument('--'+name,required=True,action=O.Once)
    return p
def log_text(path):
    if path.stat().st_size>65536:raise ValueError('log bound')
    return path.read_text(errors='replace')
def log_failure(text):
    if 'SCRIPT ERROR:' in text or 'Parse Error:' in text:return 'engine_script_error'
    if 'ADMISSION_FAILURE ' in text or 'PROBE_FAILURE ' in text:return 'probe_admission_failure'
    return None
def extract(text):
    if log_failure(text):raise ValueError('error marker')
    lines=[line for line in text.splitlines() if line.startswith('PROBE_RESULT ')]
    if len(lines)!=1 or len(lines[0][13:].encode())>8192:raise ValueError('one bounded result required')
    return json.loads(lines[0][13:],object_pairs_hook=unique,parse_constant=lambda _:(_ for _ in ()).throw(ValueError('nonfinite JSON')))
def release_valid(report):
    try:
        if report.get('cleanupErrors') or not report.get('releasedCleanly') or report['owned']['pid']!=report['owned']['pgid']:return False
        previous=report['lockAcquiredUnix']
        if len(report['releaseAudits'])!=3:return False
        for a in report['releaseAudits']:
            instant=datetime.datetime.fromisoformat(a['utc']).timestamp()
            if a['measured'] is not True or a['members']!=[] or a.get('error') or not previous<instant<=report['lockReleasePendingUnix']:return False
            previous=instant
        return True
    except (KeyError,ValueError,TypeError):return False
def main(a):
    dest=Path(a.fixture).absolute();engine=Path(a.engine)
    if not engine.is_absolute() or engine.resolve()!=engine or not engine.is_file():raise ValueError('absolute nonsymlink engine')
    config=validate_stage(dest);verify_ai(a.ai_root)
    source_hash=sha(dest/'source.json');engine_hash=sha(engine);g=load(dest/'grant.json')
    if sha(dest/'grant.json')!=a.grant_sha256:raise ValueError('grant hash')
    C.validate_grant(g,a.group,a.mode,a.grant_id,source_hash,engine_hash,time.time())
    for n in ['probe-start.json','probe.log','probe-result.json','probe-supervisor.json']:
        if (dest/n).exists():raise FileExistsError('write-once invocation')
    report={'phase':C.PHASE,'mode':C.MODE,'group':C.GROUP,'sourceSha256':source_hash,'grantSha256':a.grant_sha256,'engineSha256':engine_hash,'failed':True,'probeCollected':False,'positiveAdmission':False,'nativeStepAdmission':False,'productionPromotion':False,'autoRetry':False,'queued':False,'releaseAudits':[],'processGroupTrace':[],'timeoutSeconds':180,'environment':{'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'}}
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        validate_stage(dest);verify_ai(a.ai_root)
        if sha(dest/'source.json')!=source_hash or sha(dest/'grant.json')!=a.grant_sha256 or sha(engine)!=engine_hash:raise ValueError('binding changed before launch')
        C.validate_grant(load(dest/'grant.json'),a.group,a.mode,a.grant_id,source_hash,engine_hash,time.time())
        report['lockAcquiredUnix']=time.time()
        argv=[str(engine),'--headless','--single-threaded-scene','--path',str(dest),'--script','res://probe/driver.gd','--','--group='+C.GROUP,'--mode='+C.MODE,'--grant-id='+a.grant_id,'--grant-sha256='+a.grant_sha256]
        report['argv']=argv
        # Consumes this stage before launch, even if Popen fails. No retry path.
        write(dest/'probe-start.json',report)
        owned=None;child=None;handlers={}
        def interrupted(number,frame):raise RuntimeError('supervisor interrupted: '+str(number))
        try:
            for number in [signal.SIGTERM,signal.SIGHUP,signal.SIGINT]:handlers[number]=signal.signal(number,interrupted)
            with (dest/'probe.log').open('xb') as log:
                child=subprocess.Popen(argv,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,env={**os.environ,'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'})
                owned=O.identity(child.pid)
                if not owned or owned['pgid']!=child.pid:raise RuntimeError('owned session identity unavailable')
                report['owned']=owned;deadline=time.monotonic()+EXTERNAL_SECONDS
                while child.poll() is None:
                    report['processGroupTrace'].append({'unix':time.time(),'members':O.members(owned['pgid'])})
                    text=log_text(dest/'probe.log')
                    reason=log_failure(text)
                    if time.monotonic()>=deadline or reason:
                        report['stopReason']='external_timeout' if time.monotonic()>=deadline else reason
                        O.stop_owned(owned);break
                    time.sleep(.05)
                report['returnCode']=child.wait(timeout=10)
        except BaseException as error:
            report['supervisorError']=repr(error)
            try:
                if child and owned:O.stop_owned(owned);child.wait(timeout=10)
            except Exception as error:O.cleanup_error(report,'exception_cleanup',error)
        finally:
            native={}
            try:
                for number in handlers:
                    try:signal.signal(number,signal.SIG_IGN)
                    except Exception as error:O.cleanup_error(report,'ignore_signal',error)
                O.audit_release(owned,report)
                text=log_text(dest/'probe.log')
                reason=log_failure(text)
                if reason:report['stopReason']=reason
                try:native=extract(text)
                except (ValueError,TypeError) as error:report['invalidNativeReceipt']=repr(error)
                valid=C.collected(native,source_hash,a.grant_sha256,engine_hash,config['files']['probe/cloned_policy.gd'],config['files']['probe/cloned_evidence.gd'])
                if valid:write(dest/'probe-result.json',native);report['nativeReceiptSha256']=sha(dest/'probe-result.json')
                report['probeCollected']=valid
                report['failed']=not(valid and report.get('returnCode')==0 and not report.get('stopReason') and not report.get('supervisorError') and report.get('releasedCleanly'))
                # Observation, not a required success condition or promotion.
                report['hypothesisConfirmed']=native.get('hypothesisConfirmed') if valid else None
            except Exception as error:O.cleanup_error(report,'finalization',error);report['failed']=True
            finally:
                for number,handler in handlers.items():
                    try:signal.signal(number,handler)
                    except Exception as error:O.cleanup_error(report,'restore_signal',error);report['failed']=True
            report['lockReleasePendingUnix']=time.time()
            if not release_valid(report):report['failed']=True
            try:write(dest/'probe-supervisor.json',report)
            except Exception as error:
                O.cleanup_error(report,'write_result',error);report['failed']=True
                try:sys.stderr.write(json.dumps(report)+'\n')
                except Exception:pass
    return 1 if report['failed'] else 0
if __name__=='__main__':raise SystemExit(main(parser().parse_args()))
