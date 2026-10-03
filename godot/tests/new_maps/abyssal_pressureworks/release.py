"""Record grant-I owned-group audits only after every bounded stage has exited."""
import datetime
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
STAGES = Path('/home/mojo/.tmp-on-disk/cocs-expansion-three-abyssal-evidence-20261002/production-i')
records = [json.loads(p.read_text()) for p in STAGES.glob('*/*-process.json')]
groups = sorted({r['processGroup'] for r in records})
audits = []
for _ in range(3):
    rows = subprocess.check_output(['ps','-eo','pid=,pgid=,stat=,args='],text=True).splitlines()
    owned = [line.strip() for line in rows if int(line.split(None,3)[1]) in groups]
    audits.append({'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'ownedProcesses':owned})
assert groups and all(not a['ownedProcesses'] for a in audits), audits
report = {'grant':'ABYSSAL-ASSET-PRODUCTION-20261003-I','released':True,'releasedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'ownedGroups':groups,'audits':audits,'allOwnedGroupsEmpty':True,'heavyJobsRemaining':0,'accepted':False,
          'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
          'geometrySha256':hashlib.sha256((ROOT/'godot/multiplayer_worlds/generated/abyssal-pressureworks.json').read_bytes()).hexdigest(),
          'glbSha256':hashlib.sha256((ROOT/'godot/multiplayer_worlds/art/worlds/abyssal-pressureworks.glb').read_bytes()).hexdigest()}
dest = ROOT/'port/expansion-three/abyssal/evidence/production-i/release-i.json'
dest.parent.mkdir(parents=True,exist_ok=True)
assert not dest.exists(),'Immutable release record already exists'
dest.write_text(json.dumps(report,indent=2)+'\n')
(STAGES/'release-i.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
