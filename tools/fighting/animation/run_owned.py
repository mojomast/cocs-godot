"""Bounded serial production command with owned process-group teardown/logs."""
import argparse
import datetime
import json
import os
from pathlib import Path
import signal
import subprocess

p=argparse.ArgumentParser()
p.add_argument('--log',type=Path,required=True)
p.add_argument('--timeout',type=int,default=600)
p.add_argument('command',nargs=argparse.REMAINDER)
a=p.parse_args()
command=a.command[1:] if a.command[:1]==['--'] else a.command
a.log.parent.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,LP_NUM_THREADS='1',OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1')
with a.log.open('w') as log:
    proc=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
    timed_out=False
    try:
        code=proc.wait(timeout=a.timeout)
    except subprocess.TimeoutExpired:
        timed_out=True
        code=124
    finally:
        try: os.killpg(proc.pid,signal.SIGTERM)
        except ProcessLookupError: pass
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid,signal.SIGKILL)
            proc.wait()
receipt={'time_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'command':command,'pid':proc.pid,'exit_code':code,'timed_out':timed_out,'log':str(a.log)}
a.log.with_suffix('.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))
print('\n'.join(a.log.read_text(errors='replace').splitlines()[-30:])[-12000:])
raise SystemExit(code)
