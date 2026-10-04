"""Isolated AG ownership primitives; no launch, kill-by-name or cleanup scans."""
import argparse,datetime,os,signal,time
from pathlib import Path
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
def cleanup_error(report,operation,error):report.setdefault('cleanupErrors',[]).append({'operation':operation,'error':repr(error)})
def stop_owned(owned):
    if owned and identity(owned['pid'])==owned:
        try:os.killpg(owned['pgid'],signal.SIGKILL)
        except ProcessLookupError:pass # Still requires independent measured audits.
def audit_release(owned,report):
    try:
        if not owned or owned['pid']!=owned['pgid']:raise RuntimeError('owned session identity unavailable')
        remaining=members(owned['pgid']);leader=identity(owned['pid'])
        if leader is not None and leader!=owned:raise RuntimeError('leader identity changed; refusing signal')
        if any(r['startTicks']<owned['startTicks'] for r in remaining):raise RuntimeError('older member; refusing signal')
        if remaining:
            try:os.killpg(owned['pgid'],signal.SIGKILL);report['signalledOwnedResiduals']=remaining
            except ProcessLookupError:report['residualGroupDisappearedBeforeSignal']=True
    except Exception as error:cleanup_error(report,'residual_cleanup',error)
    for _ in range(3):
        audit={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'members':None,'measured':False}
        try:
            if not owned:raise RuntimeError('no owned identity')
            audit['members']=members(owned['pgid']);audit['measured']=True
        except Exception as error:audit['error']=repr(error);cleanup_error(report,'release_audit',error)
        report['releaseAudits'].append(audit)
        try:time.sleep(.2)
        except Exception as error:cleanup_error(report,'audit_interval',error)
    report['releasedCleanly']=bool(owned) and not report.get('cleanupErrors') and len(report['releaseAudits'])==3 and all(a['measured'] and a['members']==[] for a in report['releaseAudits'])
