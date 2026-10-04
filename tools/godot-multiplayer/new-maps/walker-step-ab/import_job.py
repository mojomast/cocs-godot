"""AB explicit bounded import only; per-job nonwaiting lock, no queued work."""
import sys,os,json,time,fcntl,subprocess,signal
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-step-up'))
from run_group_v2 import identity,members,LOCK
from prepare_v2 import digest,write
ENGINE=Path('/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64')
def main(label):
    if label not in ['import-01','import-02']:raise ValueError('authorized bounded imports only')
    evidence=HERE/'evidence';evidence.mkdir(exist_ok=True)
    report={'grant':'MOTH-BLENDER-20261004-AB','job':label,'timeoutSeconds':900,'engineSha256':digest(ENGINE),'startUnix':time.time(),'releaseAudits':[]}
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        report['lockAcquiredUnix']=time.time()
        argv=[str(ENGINE),'--headless','--path',str(ROOT/'godot'),'--editor','--import']
        report['argv']=argv
        with (evidence/(label+'.log')).open('xb') as log:
            process=subprocess.Popen(argv,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,env={**os.environ,'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'})
            owned=identity(process.pid);report['owned']=owned
            write(evidence/(label+'-started.json'),report)
            try:report['returnCode']=process.wait(timeout=900)
            except subprocess.TimeoutExpired:
                report['timeout']=True
                if identity(process.pid)==owned:os.killpg(process.pid,signal.SIGKILL)
                report['returnCode']=process.wait(timeout=10)
        for _ in range(3):
            report['releaseAudits'].append({'unix':time.time(),'members':members(process.pid)})
            time.sleep(.2)
        report['releasedCleanly']=all(not row['members'] for row in report['releaseAudits'])
        report['lockReleaseUnix']=time.time();write(evidence/(label+'-finished.json'),report)
        if not report['releasedCleanly']:raise RuntimeError('owned group not empty')
    return report['returnCode']
if __name__=='__main__':raise SystemExit(main(sys.argv[1]))
