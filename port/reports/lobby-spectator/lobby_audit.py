"""Read-only source/native/renderer correlation; preserves both live attempts."""
import collections,gzip,hashlib,json,math,pathlib,socket,subprocess
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[2]
BASE='12e770ddbcc0befb74e95b7154cfc0ab55b6812b'
report={'status':'PASS active spectator; package integration remains lead-owned','checks':[],'cases':{}}
def require(name,condition):
    assert condition,name
    report['checks'].append(name)
def records(value,prefix=''):
    return [json.loads(line[len(prefix):]) for line in value.splitlines() if line.startswith(prefix)]
def text(path): return gzip.decompress(path.read_bytes()).decode()
def intersect(a,b): return a[0]<b[0]+b[2] and a[0]+a[2]>b[0] and a[1]<b[1]+b[3] and a[1]+a[3]>b[1]
previous=subprocess.check_output(['git','ls-tree','-r',BASE,'port/reports/lobby-followup','port/reports/multiplayer-lobby-independent'],cwd=ROOT,text=True)
for line in previous.splitlines():
    metadata,name=line.split('\t')
    digest=subprocess.check_output(['git','hash-object',name],cwd=ROOT,text=True).strip()
    require('prior evidence byte-identical '+name,digest==metadata.split()[2])
for file in ['port/reports/multiplayer-lobby-independent/provenance.json','port/reports/lobby-followup/provenance.json']:
    provenance=json.loads((ROOT/file).read_text())
    for key in ['ownedObservers']:
        for name,digest in provenance.get(key,{}).items():
            require('prior observer byte-identical '+name,hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest)
changed=subprocess.check_output(['git','diff',BASE,'--name-only'],cwd=ROOT,text=True).splitlines()
allowed={'godot/net/client.gd','godot/world/session.gd','godot/ui/lobby_menu.gd'}
require('only authorized runtime and new lobby tests/reports changed',all(n in allowed or n.startswith('godot/tests/protocol/lobby_spectator_') or n.startswith('port/reports/lobby-spectator/') for n in changed))
for case in ['active-spectator','active-spectator-layout']:
    directory=OUT/case
    summary=json.loads((directory/'summary.json').read_text())
    require(case+' live execution success',summary['status']=='PASS' and 'error' not in summary)
    require(case+' under 120 seconds',summary['wallMs']<=120000)
    for name in ['wire.jsonl','actions.jsonl']:
        raw=gzip.decompress((directory/(name+'.gz')).read_bytes())
        require(case+' '+name+' archive integrity',len(raw)==summary[name]['bytes'] and hashlib.sha256(raw).hexdigest()==summary[name]['sha256'])
    require(case+' processes reaped',all(c['reaped'] and not pathlib.Path('/proc/'+str(c['pid'])).exists() for c in summary['cleanup']))
    require(case+' authority and private environment closed',summary['serverClosed'] and summary['sockets']==0 and summary['tempRemoved'])
    with socket.socket() as listener:
        listener.settimeout(.5)
        require(case+' former port closed',listener.connect_ex(('127.0.0.1',summary['port']))!=0)
    require(case+' protected port not owned',summary['port']!=4332)
    wire=records(text(directory/'wire.jsonl.gz'))
    received=[f for f in wire if f['type']=='received']
    counts={str(r):dict(collections.Counter(f['frame']['type'] for f in received if f['recipient']==r)) for r in [0,1,2]}
    require(case+' spectator only explicit join and leave',counts['2']=={'join':1,'leave':1})
    require(case+' original guest no host commands',set(counts['1'])=={'join','input','leave'})
    require(case+' host create/config once; start twice',counts['0']['create']==counts['0']['host']==1 and counts['0']['start']==2)
    config=next(f['frame']['config'] for f in received if f['frame']['type']=='host')
    require(case+' normal 60 second two bot settings',config['timeLimit']==60 and config['botCount']==2 and config['mode']=='teamdeathmatch')
    handshake=[f for f in wire if f['recipient']==2 and f['type'] not in ['received','socket-close']]
    require(case+' ordered source handshake',[f['type'] for f in handshake[:5]]==['welcome','lobby','error','start','snapshot'])
    welcome,roster,notice=handshake[:3]
    self_player=next(p for p in roster['players'] if p['peerId']==welcome['peerId'])
    require(case+' validated source identity',welcome['spectate'] is True and welcome['host'] is False and welcome['roomId']==roster['roomId']==summary['room'] and self_player['spectate'] is True and self_player['connected'] is True and self_player['actorId'] is None)
    require(case+' exact notice',notice['message']=='Match in progress — you joined as a spectator.')
    for f in handshake:
        if f['type']=='lobby':
            p=next(p for p in f['players'] if p['peerId']==welcome['peerId'])
            assert p['spectate'] is True and p['actorId'] is None
    require(case+' no promotion across round restart',len([f for f in handshake if f['type']=='welcome'])==1 and {f['revision'] for f in handshake if f['type']=='start'}=={1,2})
    index={(f['peer'],f['revision'],f['seq']):f for f in wire if f['type']=='snapshot'}
    matched={}
    for client in ['host','guest']:
        native=text(directory/(client+'.stdout.log.gz'))
        require(case+' '+client+' no engine errors',not any(s in native+(directory/(client+'.stderr.log')).read_text() for s in ['SCRIPT ERROR','Parse Error','ERROR:']))
        applied=records(native,'SPECTATOR_APPLIED ')
        for a in applied:
            source=index[(a['peer'],a['revision'],a['seq'])]
            actors={x['id']:x for x in source['state']['actors']}
            assert {x['id'] for x in a['actors']}==set(actors),(case,client,'missing visual actor')
            for rendered in a['actors']:
                actor=actors[rendered['id']]
                expected=[actor['x'],actor['y']+.9,actor['z']]
                assert all(abs(x-y)<1e-4 for x,y in zip(rendered['ingested'],expected)),(case,client,a['seq'],'ingest mismatch')
                assert all(math.isfinite(x) for x in rendered['rendered'])
            if a['spectating']:
                assert a['actor']==-1 and a['ack']==0 and a['local_empty'] and source['actor'] is None
        matched[client]=len(applied)
        require(case+' '+client+' source state ingested by visual actors',len(applied)>5)
        if client=='guest':
            spectator=[a for a in applied if a['spectating']]
            samples=[s for s in records(native,'SPECTATOR_SAMPLE ') if s['spectating'] and s['phase'] in [3,4]]
            require(case+' spectator applied both rounds',{s['revision'] for s in spectator}=={1,2})
            require(case+' no phantom actor or control capture',all(s['actor']==-1 and s['ack']==s['input_seq']==0 and not s['pose'] and not s['captured'] and not s['eligible'] for s in samples))
            require(case+' fixed camera',len({tuple(s['camera']) for s in samples})==1)
            require(case+' explicit spectator HUD in every sampled playing frame',all('SPECTAT' in s['title'] and 'Local actor absent' not in s['detail'] and not s['controls_visible'] and s['score']=='SPECTATOR' for s in samples))
            if case=='active-spectator-layout':
                layout=records(native,'SPECTATOR_LAYOUT ')
                require(case+' status text contained in every sampled panel',len(layout)>50 and all(s['contained'] for s in layout))
                require(case+' live and results text checked at both sizes',{(s['phase'],tuple(s['viewport'])) for s in layout if s['phase'] in [3,4]}=={(phase,size) for phase in [3,4] for size in [(960,640),(1280,800)]})
    effects={}
    for name,r,rev in [('original-guest',1,1),('host-round1',0,1),('host-round2',0,2)]:
        inputs=[f for f in received if f['recipient']==r and f['revision']==rev and f['frame']['type']=='input']
        active=[f for f in inputs if f['frame']['input']['fire'] and math.hypot(f['frame']['input']['x'],f['frame']['input']['z'])>.1]
        require(case+' '+name+' held movement/fire receipts',len(active)>5)
        snaps=[f for f in wire if f['recipient']==r and f['revision']==rev and f['type']=='snapshot' and active[0]['wall']-100<=f['wall']<=active[-1]['wall']+200]
        actors=[next(a for a in f['state']['actors'] if a['id']==f['actor']) for f in snaps]
        living=[a for a in actors if a['health']>0 and a['dead']==0]
        distance=max(math.hypot(a['x']-living[0]['x'],a['z']-living[0]['z']) for a in living)
        shots=max(a['shots'] for a in actors)-min(a['shots'] for a in actors)
        require(case+' '+name+' authority applied living movement and shots',distance>.5 and shots>0)
        effect={'livingDisplacementMetres':distance,'shotGrowth':shots,'activeInputReceipts':len(active)}
        if r==0:
            host_actor=snaps[0]['actor']
            seen=[a for a in spectator if a['revision']==rev and active[0]['wall']-100<=index[(a['peer'],a['revision'],a['seq'])]['wall']<=active[-1]['wall']+350]
            rendered=[next(x for x in a['actors'] if x['id']==host_actor) for a in seen]
            visible=[x['rendered'] for x in rendered if x['visible']]
            travel=max(math.dist(p,visible[0]) for p in visible)
            require(case+' '+name+' spectator renders moving host',travel>.5 and seen[-1]['rendered_remote_poses']>seen[0]['rendered_remote_poses'])
            effect['spectatorRenderedDisplacementMetres']=travel
            effect['spectatorNativeApplicationsDuringBurst']=len(seen)
        effects[name]=effect
    for milestone in summary['milestones']:
        s=milestone['sample'];ui=s['ui'];layout=s['layout']
        for button in ['leave_button','restart_button']:
            if not ui[button]['visible']: continue
            for content in ['top','score','status','board']:
                if layout[content]['visible']:
                    require(case+' '+milestone['name']+' '+button+' avoids '+content,not intersect(ui[button]['rect'],layout[content]['rect']))
        if s['phase']==-3:
            require(case+' '+milestone['name']+' clean disconnected state',s['actor']==s['peer']==-1 and not s['room'] and not s['pose'] and not s['captured'] and s['actors']==s['pickups']==s['ack']==s['input_seq']==0)
    results=[f for f in wire if f['recipient'] in [0,2] and f['type']=='results']
    start=next(f for f in wire if f['recipient']==0 and f['type']=='start')
    require(case+' natural results for host and spectator',len(results)==2 and all(60<=f['state']['time']<61 for f in results) and 55000<results[0]['wall']-start['wall']<70000)
    report['cases'][case]={'assessment':'Protocol/lifecycle PASS; screenshot status-text overflow superseded by second run' if case=='active-spectator' else 'PASS including corrected text containment','baseline':summary['baseline'],'wallMs':summary['wallMs'],'port':summary['port'],'room':summary['room'],'wireCounts':counts,'nativeApplicationsMatched':matched,'spectatorApplications':len(spectator),'effects':effects,'sourceResultsTime':results[0]['state']['time'],'sourceRoundWallMs':results[0]['wall']-start['wall'],'cleanup':summary['cleanup']}
report['port4332Observation']=subprocess.check_output(['ss','-ltnp','sport = :4332'],text=True)
require('protected port remains original Node PID','127.0.0.1:4332' in report['port4332Observation'] and 'pid=1094444' in report['port4332Observation'])
report['assertionCount']=len(report['checks'])
report['applicationFramesMatched']=sum(sum(c['nativeApplicationsMatched'].values()) for c in report['cases'].values())
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='checks'},indent=2))
