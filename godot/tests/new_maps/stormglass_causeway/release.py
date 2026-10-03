"""Release only grant J's recorded owned process groups; no global process kill."""
import datetime
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[4]
BASE=Path('/home/mojo/.tmp-on-disk/cocs-expansion-four-stormglass-evidence-20261002/production-j')
groups=sorted({json.loads(p.read_text())['processGroup'] for p in BASE.glob('*/*-process.json')})
audits=[]
for _ in range(3):
    lines=subprocess.check_output(['ps','-eo','pid=,pgid=,args='],text=True).splitlines()
    owned=[line.strip() for line in lines if len(line.split(None,2))>=2 and int(line.split(None,2)[1]) in groups]
    audits.append({'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'ownedProcesses':owned})
    assert not owned,owned
report={'grant':'STORMGLASS-ASSET-PRODUCTION-20261003-J','released':True,'releasedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'ownedGroups':groups,'audits':audits,'allOwnedGroupsEmpty':True,'heavyJobsRemaining':0,'accepted':False,'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()}
out=ROOT/'port/expansion-four/stormglass/evidence/production-j/release-j.json'
out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
