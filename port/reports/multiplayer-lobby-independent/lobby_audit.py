"""Offline audit of retained receipts. Never upgrades either live helper exit."""
import collections, gzip, hashlib, json, math, pathlib, socket, subprocess
OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[2]
checks = []
def require(name, condition):
    assert condition, name
    checks.append(name)
def archive(path):
    return gzip.decompress(path.read_bytes()).decode()
def records(text, prefix=''):
    return [json.loads(line[len(prefix):]) for line in text.splitlines() if line.startswith(prefix)]
report = {'scope':'Offline retained-receipt audit; live attempts remain PARTIAL/FAIL','cases':{},'checks':checks}
for case in ['meridian-exchange','ember-crucible']:
    directory = OUT/case
    summary = json.loads((directory/'summary.json').read_text())
    for name in ['wire.jsonl','actions.jsonl']:
        raw = gzip.decompress((directory/(name+'.gz')).read_bytes())
        require(case+' '+name+' archive hash',hashlib.sha256(raw).hexdigest()==summary[name]['sha256'] and len(raw)==summary[name]['bytes'])
    require(case+' owned children reaped',all(p['reaped'] and not pathlib.Path('/proc/'+str(p['pid'])).exists() for p in summary['cleanup']))
    require(case+' listener/socket/temp cleanup',summary['serverClosed'] and summary['sockets']==0 and summary['tempRemoved'])
    with socket.socket() as s:
        s.settimeout(.5)
        closed = s.connect_ex(('127.0.0.1',summary['port'])) != 0
    require(case+' loopback port now refuses connection',closed)
    report['cases'][case] = {'liveStatus':summary['status'],'liveError':summary['error'],'wallMs':summary['wallMs'],'portClosed':closed}

directory = OUT/'ember-crucible'
wire = records(archive(directory/'wire.jsonl.gz'))
actions = records(archive(directory/'actions.jsonl.gz'))
received = [f for f in wire if f['type']=='received']
counts = {r:dict(collections.Counter(f['frame']['type'] for f in received if f['recipient']==r)) for r in [0,1,2]}
require('host creates/configures once and starts twice',counts[0].get('create')==1 and counts[0].get('host')==1 and counts[0].get('start')==2)
require('guest first connection only join and explicit leave',counts[1]=={'join':1,'leave':1})
require('guest rejoin emits only join/input',counts[2].get('join')==1 and set(counts[2])=={'join','input'})
config = next(f['frame']['config'] for f in received if f['frame']['type']=='host')
require('ordinary 60s two-bot Rockets request',config['mode']=='rockets' and config['timeLimit']==60 and config['botCount']==2)
starts = [f for f in wire if f['type']=='start']
require('two authoritative starts per connected participant',collections.Counter(f['recipient'] for f in starts)=={0:2,2:2})
for r in [0,2]:
    result = next(f for f in wire if f['type']=='results' and f['recipient']==r)
    start = next(f for f in starts if f['recipient']==r)
    require('natural round time recipient '+str(r),60<=result['state']['time']<61 and 55_000<=result['wall']-start['wall']<=70_000)
report['emberWireCounts']=counts
report['sourceResultTime']=result['state']['time']
report['sourceRoundWallMs']=result['wall']-start['wall']

for name,r in [('host',0),('guest',2)]:
    text=archive(directory/(name+'.stdout.log.gz'))
    applied=records(text,'LOBBY_APPLIED ')
    samples=records(text,'LOBBY_SAMPLE ')
    require(name+' no engine runtime errors','SCRIPT ERROR' not in text+(directory/(name+'.stderr.log')).read_text())
    require(name+' explicit lobby waiting before Start',any(s['phase']==(12 if name=='host' else 11) and s['starts']==0 and not s['pose'] and s['actor']==-1 for s in samples))
    require(name+' room/roster matches source',any('Independent Host' in s['roster'] and 'Independent Guest' in s['roster'] and 'ember-crucible / rockets' in s['roster'] for s in samples))
    require(name+' results pointer/control released',any(s['phase']==4 and not s['captured'] and not s['eligible'] for s in samples))
    resumed=[s for s in samples if s['starts']==2]
    require(name+' new round initially uncaptured',resumed and not resumed[0]['captured'])
    snaps=[f for f in wire if f['recipient']==r and f['type']=='snapshot']
    indexed={(f['round'],f['seq']):f for f in snaps}
    matched=0
    for a in applied:
        source=indexed.get((a['round'],a['seq']))
        require(name+' source snapshot exists '+str(a['round'])+'/'+str(a['seq']),source is not None)
        actor=next((x for x in source['state']['actors'] if x['id']==a['actor']),None)
        require(name+' native pose/shot application '+str(a['round'])+'/'+str(a['seq']),actor is not None and all(abs(actor[k]-a['local'][k])<1e-7 for k in ['x','y','z','shots','health']))
        require(name+' camera source x/z '+str(a['round'])+'/'+str(a['seq']),abs(a['camera'][0]-actor['x'])<1e-5 and abs(a['camera'][2]-actor['z'])<1e-5)
        require(name+' recipient ACK '+str(a['round'])+'/'+str(a['seq']),a['ack']==source['acks'].get(str(a['actor']),0))
        matched+=1
    first=[s for s in snaps if s['round']==1]
    inputs=[f for f in received if f['recipient']==r and f['round']==1 and f['frame']['type']=='input']
    live_inputs=[f for f in inputs if f['frame']['input']['fire'] and math.hypot(f['frame']['input']['x'],f['frame']['input']['z'])>.1]
    require(name+' actual movement/fire requests received',len(live_inputs)>5)
    # Restrict application proof to the input burst, before death/respawn can
    # masquerade as movement; ACK high-water alone is never used as gameplay.
    burst=[s for s in first if live_inputs[0]['wall']-100<=s['wall']<=live_inputs[-1]['wall']+200]
    actors=[next(a for a in s['state']['actors'] if a['id']==s['actor']) for s in burst]
    living=[a for a in actors if a['health']>0 and a['dead']==0]
    distance=max(math.hypot(a['x']-living[0]['x'],a['z']-living[0]['z']) for a in living)
    require(name+' living movement during input burst',distance>.5)
    require(name+' shots increase during input burst',max(a['shots'] for a in actors)>min(a['shots'] for a in actors))
    if name=='host':
        require('host fresh capture in restarted round',any(s['captured'] for s in resumed))
        second=[f for f in snaps if f['round']==2]
        require('host restarted shots actually applied',any(a['local'].get('shots',0)>0 for a in applied if a['round']==2))
    else:
        disconnected=[s for s in samples if s['phase']==-3 and s['command']>35]
        require('guest Leave clean before explicit rejoin',any(s['actor']==-1 and not s['pose'] and not s['room'] and s['actors']==0 and s['pickups']==0 for s in disconnected))
        require('guest restart action hidden at results',all(not s['ui']['restart_button']['visible'] for s in samples if s['phase']==4))
    report[name]={'sourceSnapshotsRound1':len(first),'inputsRound1':len(inputs),'movementFireInputsRound1':len(live_inputs),'livingMovementBurstMetres':distance,'shotsRound1':max(a['local'].get('shots',0) for a in applied if a['round']==1),'nativeSourceApplicationsMatched':matched,'maxAckRound1':max(s['acks'].get(str(s['actor']),0) for s in first)}

# Avoid thousands of repetitive assertion strings in the report.
report['checkCount']=len(checks)
report['checks']=[s for s in checks if not any(x in s for x in ['source snapshot exists ','native pose/shot application ','camera source x/z ','recipient ACK '])]
report['status']='PASS for listed retained-receipt assertions; live acceptance remains partial'
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
