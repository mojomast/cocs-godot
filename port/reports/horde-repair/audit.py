"""Read-only audit of retained repair runs. Does not launch games or alter evidence."""
import gzip, hashlib, json, pathlib, socket, struct, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = pathlib.Path(__file__).resolve().parent
BASE = '59c2b33c3080845eb73f8490b3dc9e355117c000'
RUNTIME = '50521191ee6922295a50448301e929d945926ef9'
SUPERSEDED = '0401dfb7-3677-4131-b811-47338e6c67ba'
PASS = ['eb983c30-da2c-4e4b-888a-69a055898a45',
        '6447d73c-3e44-4657-ac91-852bf19c03ea',
        'bcf9d964-252f-4780-864e-6774359a6136']
OPENED = {
 SUPERSEDED: ['gameplay-final.png','gameplay-alternate.png'],
 PASS[0]: ['gameplay-results.png','gameplay-results-alternate.png','gameplay-restart.png'],
 PASS[1]: ['gameplay-final.png','gameplay-alternate.png'],
 PASS[2]: ['gameplay-final.png','gameplay-alternate.png'],
}
def sha(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(path.read_text())
def tagged(text, prefix):
 return [json.loads(line[len(prefix):]) for line in text.splitlines() if line.startswith(prefix)]
def git(*args): return subprocess.check_output(['git', *args], cwd=ROOT)

runs=[]
for id in [SUPERSEDED, *PASS]:
 folder=OUT/'evidence'/id
 summary=read(folder/'summary.json'); launch=read(folder/'launch.json')
 wire=[json.loads(line) for line in gzip.decompress((folder/'wire.jsonl.gz').read_bytes()).decode().splitlines()]
 text=gzip.decompress((folder/'native.stdout.log.gz').read_bytes()).decode()
 frames=[r for r in wire if r['direction']=='out']
 snapshots=[r for r in frames if r['frame']['type']=='snapshot']
 traces=tagged(text,'PORT_NATIVE_TRACE ')
 rows=tagged(text,'HORDE_NATIVE ')
 layouts=tagged(text,'HORDE_LAYOUT ')
 assert summary['wallSeconds'] < 180 and summary['attempt'] <= 2
 assert summary['exit']==0 and summary['serverClosed'] and summary['sockets']==0
 assert summary['temporaryTreeRemoved'] and all(p['reaped'] and p['absent'] for p in summary['cleanup'])
 for p in summary['cleanup']:
  assert not pathlib.Path('/proc',str(p['pid'])).exists(), ('owned PID present',p)
 endpoint=next(arg.split('=',1)[1] for arg in launch['argv'] if arg.startswith('--endpoint='))
 port=int(endpoint.rsplit(':',1)[1])
 with socket.socket() as client:
  client.settimeout(1)
  assert client.connect_ex(('127.0.0.1',port)) != 0, ('former listener open',port)
 for path, expected in launch['hashes'].items():
  assert sha(git('show',f"{launch['base']}:{path}"))==expected, ('recorded launch hash mismatch',path)
 images=[]
 for path in sorted(folder.glob('*.png')):
  data=path.read_bytes();width,height=struct.unpack('>II',data[16:24])
  assert (width,height) in [(960,640),(1280,800)]
  images.append(dict(file=path.name,width=width,height=height,sha256=sha(data),directlyOpened=path.name in OPENED[id]))
 detail=dict(id=id,status='SUPERSEDED_VISUAL_FAILURE' if id==SUPERSEDED else 'PASS',
             summary=summary,launchCommit=launch['base'],formerEndpoint=endpoint,portClosed=True,
             validatorSHA256=sha((ROOT/'port/native-horde/validate.mjs').read_bytes()),
             sourceModifierEvents=[e for r in frames if r['frame']['type']=='events' for e in r['frame']['items'] if e['type']=='horde-modifier'],
             images=images,layouts=layouts)
 if id in PASS:
  validation=read(folder/'validation.json'); assert validation['status']=='PASS'
  detail['validation']=validation
 if summary['scenario']=='combat':
  result=next(r['frame']['state'] for r in frames if r['frame']['type']=='results')
  restart=[r for r in snapshots if r['round']==2]
  assert len([r for r in frames if r['frame']['type']=='results'])==1
  assert restart and all(not r['captured'] for r in rows if r['round']==2)
  assert restart[0]['frame']['state']['actors'][0]['shots']==0
  assert restart[0]['frame']['state']['singleplayer']['kills']==0
  assert restart[0]['frame']['state']['time']<=.051
  detail['effects']={k:result['singleplayer'][k] for k in ['kills','score','lives','phase','winner','wave','waveTarget']}
  detail['restart']={'firstSourceTime':restart[0]['frame']['state']['time'], 'shots':0,'kills':0,'released':True}
 if summary['scenario']=='death':
  dead=next(r for r in snapshots if r['frame']['state']['actors'][0]['health']<=0)
  respawn=next(r for r in snapshots if r['observedMs']>dead['observedMs'] and r['frame']['state']['actors'][0]['health']>0)
  crouched=next(r for r in snapshots if r['frame']['state']['actors'][0]['crouching'])
  assert crouched['observedMs']<dead['observedMs']
  after=traces[next(i for i,t in enumerate(traces) if t['event']=='snapshot' and t['dead']>0):]
  recapture=next(i for i,t in enumerate(after) if t['event']=='snapshot' and t['pointer_captured'])
  neutral=[t for t in after[:recapture] if t['event']=='input_queue']
  assert len(neutral)>10
  for t in neutral:
   for key in ['x','z','fire','jump','reload','sprint','crouch','interact','mobility','power','melee','grenade','ads','altFire']:
    assert not t['controls'].get(key), ('leaked held action',key)
  detail['effects']={'livesBefore':3,'livesAfter':dead['frame']['state']['singleplayer']['lives'],
                     'deadSeq':dead['frame']['seq'],'respawnSeq':respawn['frame']['seq'],
                     'sourceCrouchingSeq':crouched['frame']['seq'],'neutralNativeInputs':len(neutral),
                     'recapturedSnapshotSeq':next(r['seq'] for r in rows if r['seq']>=respawn['frame']['seq'] and r['captured']),
                     'recapturedTraceSequence':after[recapture]['sequence'],
                     'deathReset':next(r for r in wire if r['direction']=='control-reset' and r['reason']=='death')}
 runs.append(detail)

# Baseline blobs establish original evidence identity, not just a clean diff.
originals={}
for path in git('ls-tree','-r','--name-only',BASE,'port/reports/horde-independent','port/native-horde/evidence').decode().splitlines():
 data=(ROOT/path).read_bytes(); assert data==git('show',f'{BASE}:{path}'), ('original evidence changed',path)
 originals[path]=sha(data)
protected=['game','app','server','godot/world','godot/ui','godot/net','tools','package.json','package-lock.json','port/contracts']
assert not git('diff',BASE,'--',*protected), 'protected source/shared files changed'
changed=git('diff','--name-only',BASE).decode().splitlines()
assert all(p.startswith(('godot/horde/','godot/tests/horde/','port/native-horde/','port/reports/horde-repair/')) for p in changed)
assert not git('diff','--check')
lock=read(ROOT/'port/contracts/source-lock.json')
report=dict(baseline=BASE,runtimeTip=RUNTIME,sourceCommit=lock['source_commit'],
            sourceMatchSHA256=sha((ROOT/'game/core.mjs').read_bytes()),originalEvidenceCount=len(originals),
            originalEvidenceSHA256=originals,protectedPathsUnchanged=protected,runs=runs,
            result='NARROW_REPAIR_PASS_WITH_RETAINED_SUPERSEDED_ATTEMPT; COMMON/PACKAGE HOLD')
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(status=report['result'],originalFilesVerified=len(originals),runs=[dict(id=r['id'],status=r['status'],seconds=r['summary']['wallSeconds']) for r in runs]),indent=2))
