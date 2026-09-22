"""Verify prior evidence/runtime, then clean only this lane's generated objects."""
import hashlib
import json
from pathlib import Path
import shutil
import socket
import struct
import subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BASE='3dbcceb91c2e1542c91e7e2e3fda55ff43a94cb2'
RUNTIME='c64762ad8104c1976ba7d08051a305009eb95782'
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def sha(data):return hashlib.sha256(data).hexdigest()
def read(path):return json.loads(path.read_text())
def closed(endpoint):
    port=int(endpoint.rsplit(':',1)[1]);assert port!=4332
    with socket.socket() as s:
        s.settimeout(1);assert s.connect_ex(('127.0.0.1',port))!=0,endpoint
    return True

prior={}
paths=['port/native-horde/evidence','port/reports/horde-independent','port/reports/horde-repair','port/reports/horde-repair-independent']
for name in git('ls-tree','-r','--name-only',BASE,*paths).decode().splitlines():
    data=(ROOT/name).read_bytes();assert data==git('show',f'{BASE}:{name}'),name
    prior[name]=sha(data)
assert len(prior)==323
protected=['game','app','server','godot','tools','port/contracts','package.json','package-lock.json']
assert not git('diff',BASE,'--',*protected)
runtime={}
allowed={'port/native-horde/'+p for p in ['authority.mjs','validate.mjs','input-buffer.test.mjs','event-cursor.test.mjs','npc-kills.test.mjs']}
changed=set(git('diff','--name-only',BASE,RUNTIME).decode().splitlines());assert changed==allowed
for name in sorted(changed):
    data=(ROOT/name).read_bytes();assert data==git('show',f'{RUNTIME}:{name}'),name
    runtime[name]=sha(data)
source=sha((ROOT/'game/core.mjs').read_bytes())
assert source=='23d0a86acf720136c62a42547207b1c43f2146002fd26d8ac7d325b2d6312631'
diagnostics=[]
for folder in sorted((OUT/'diagnostics').iterdir()):
    summary=read(folder/'summary.json');assert summary['serverClosed'] and summary['sockets']==0
    closed(summary['endpoint']);diagnostics.append(dict(id=folder.name,summary=summary,portClosed=True))
runs=[]
opened={'gameplay-results.png','gameplay-results-alternate.png','gameplay-restart.png','gameplay-alternate.png'}
for folder in sorted((OUT/'evidence').iterdir()):
    launch=read(folder/'launch.json');summary=read(folder/'summary.json')
    assert launch['base']==RUNTIME
    for name,digest in launch['hashes'].items():assert sha((ROOT/name).read_bytes())==digest,name
    assert sha(Path(launch['binary']).read_bytes())==launch['engineSHA256']=='5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae'
    assert summary['exit']==0 and summary['temporaryTreeRemoved'] and summary['serverClosed'] and summary['sockets']==0
    for child in summary['cleanup']:assert child['absent'] and child['reaped'] and not Path('/proc',str(child['pid'])).exists()
    endpoint=next(a.split('=',1)[1] for a in launch['argv'] if a.startswith('--endpoint='));closed(endpoint)
    images=[]
    for p in sorted(folder.glob('*.png')):
        data=p.read_bytes();width,height=struct.unpack('>II',data[16:24]);assert (width,height) in [(960,640),(1280,800)]
        images.append(dict(file=p.name,width=width,height=height,sha256=sha(data),directlyOpened=p.name in opened))
    runs.append(dict(id=folder.name,summary=summary,formerEndpoint=endpoint,portClosed=True,images=images,
                     oracle=read(folder/'source-object-oracle.json'),validation=read(folder/'validation.json')))
generated={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in (ROOT/'godot/content/generated').rglob('*') if p.is_file()}
dependency=ROOT/'node_modules';assert dependency.is_symlink()
target=dependency.resolve();assert str(target)=='/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules'
ws=read(target/'ws/package.json')['version']
removed=[]
for name in ['godot/.godot','godot/content/generated']:
    assert not git('ls-files','--',name)
    path=ROOT/name
    if path.exists():shutil.rmtree(path);removed.append(name)
content=ROOT/'godot/content'
if content.exists() and not list(content.iterdir()):content.rmdir()
for name in git('ls-files','--others','--exclude-standard','godot').decode().splitlines():
    assert name.endswith('.gd.uid'),name
    (ROOT/name).unlink();removed.append(name)
dependency.unlink();removed.append('node_modules (owned symlink only)');assert target.is_dir()
report=dict(baseline=BASE,runtimeCommit=RUNTIME,priorFilesVerified=len(prior),priorFileSHA256=prior,
            protectedPathsUnchanged=protected,sourceMatchSHA256=source,
            sourceCommit=read(ROOT/'port/contracts/source-lock.json')['source_commit'],runtimeHashes=runtime,
            nodeVersion=subprocess.check_output(['node','--version'],text=True).strip(),wsVersion=ws,
            diagnostics=diagnostics,runs=runs,generatedBeforeCleanup=generated,removed=removed,
            primaryDependenciesPresent=True,result='NARROW_REPAIR_PASS; INTEGRATION_HOLD_PENDING_LEAD_REVIEW')
(OUT/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(priorFilesVerified=len(prior),runtimeFiles=len(runtime),diagnostics=len(diagnostics),freshRuns=len(runs),
                     generatedResources=len(generated),removed=removed,result=report['result']),indent=2))
