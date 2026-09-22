"""Offline release popup-free/UI/authority application audit, never drives play."""
import collections,gzip,hashlib,json,math,pathlib,socket,subprocess
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[2]
BASE='7f703a13c38c57462bd628f5aaf6b6a26004be81'
report={'verdict':'PASS scoped popup-free exported lobby; other menus and final integrated package remain separate','checks':[],'runs':{},'truncatedFinalNativeRecords':[]}
def check(name,value):
    assert value,name
    report['checks'].append(name)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def records(path,prefix=''):
    text=gzip.decompress(path.read_bytes()).decode();lines=text.splitlines();result=[]
    for i,line in enumerate(lines):
        if not line.strip() or not line.startswith(prefix): continue
        try: result.append(json.loads(line[len(prefix):]))
        except json.JSONDecodeError:
            # Owned SIGTERM can interrupt the final stdout write. Preserve and
            # explicitly count it; never treat partial JSON as application proof.
            assert path.name.endswith('.stdout.log.gz') and i==len(lines)-1 and not text.endswith('\n'),(str(path),i)
            report['truncatedFinalNativeRecords'].append({'file':str(path.relative_to(ROOT)),'prefix':prefix,'bytes':len(line.encode()),'sha256':hashlib.sha256(line.encode()).hexdigest()})
    return result
def intersects(a,b): return a[0]<b[0]+b[2] and a[0]+a[2]>b[0] and a[1]<b[1]+b[3] and a[1]+a[3]>b[1]
build=json.loads((OUT/'build-result.json').read_text());package=pathlib.Path(build['package']);manifest=json.loads((package/'manifest.json').read_text())
check('manifest hash',sha(package/'manifest.json')==build['manifest_sha256'])
for name,digest in manifest['files'].items(): check('package bytes '+name,sha(package/name)==digest)
check('no added unmanifested package files',{str(p.relative_to(package)) for p in package.rglob('*') if p.is_file()}==set(manifest['files'])|{'manifest.json'})
for name in ['godot/ui/lobby_choice.gd','godot/ui/lobby_choice.gd.uid','godot/ui/lobby_menu.gd']:
    check('export input equals reviewed runtime '+name,manifest['inputs'][name]==sha(ROOT/name))
report['artifact']={'package':str(package),'manifestSha256':sha(package/'manifest.json'),'pckSha256':sha(package/'cocs.pck'),'binarySha256':sha(package/'cocs.x86_64'),'portCommit':manifest['port_commit'],'archiveSha256':sha(pathlib.Path(build['archive'])),'manifestFiles':len(manifest['files'])}
for prior in ['lobby-export-focus','lobby-spectator','lobby-followup','multiplayer-lobby-independent']:
    entries=subprocess.check_output(['git','ls-tree','-r',BASE,'port/reports/'+prior],cwd=ROOT,text=True)
    for line in entries.splitlines():
        meta,name=line.split('\t')
        actual=subprocess.check_output(['git','hash-object',name],cwd=ROOT,text=True).strip()
        assert actual==meta.split()[2],name
    check('prior report byte-identical '+prior,bool(entries))
changed=subprocess.check_output(['git','diff',BASE,'--name-only'],cwd=ROOT,text=True).splitlines()
allowed={'godot/ui/lobby_choice.gd','godot/ui/lobby_choice.gd.uid','godot/ui/lobby_menu.gd','godot/tests/protocol/lobby_popup_free.gd'}
check('authorized change scope only',all(n in allowed or n.startswith('port/reports/lobby-popup-free/') for n in changed))
for case in ['targeted','full-flow']:
    directory=OUT/case;summary=json.loads((directory/'summary.json').read_text())
    check(case+' clean PASS',summary['status']=='PASS' and summary['cleanLogs'] and not summary['nativeErrorLines'])
    check(case+' bounded duration',summary['wallMs']<120000)
    check(case+' same release artifact',summary['pckSha256']==report['artifact']['pckSha256'] and summary['binarySha256']==report['artifact']['binarySha256'])
    for name in ['wire.jsonl','actions.jsonl','witnesses.jsonl']:
        raw=gzip.decompress((directory/(name+'.gz')).read_bytes())
        check(case+' archive '+name,len(raw)==summary[name]['bytes'] and hashlib.sha256(raw).hexdigest()==summary[name]['sha256'])
    check(case+' children reaped',all(c['reaped'] and not pathlib.Path('/proc/'+str(c['pid'])).exists() for c in summary['cleanup']))
    check(case+' sockets/temp removed',summary['serverClosed'] and summary['sockets']==0 and summary['tempRemoved'])
    with socket.socket() as s:
        s.settimeout(.5);check(case+' owned port closed',s.connect_ex(('127.0.0.1',summary['port']))!=0)
    check(case+' not protected listener',summary['port']!=4332)
    actions=records(directory/'actions.jsonl.gz')
    clicks=[a for a in actions if a.get('op')=='mouse' and a.get('pressed') and 'target' in a]
    for a in clicks:
        x,y,w,h=a['rect'];vw,vh=a['viewport']
        assert 0<=x<=a['x']<=x+w<=vw and 0<=y<=a['y']<=y+h<=vh,(case,a)
    check(case+' all widget clicks inside recorded viewport/target',len(clicks)>10)
    samples={};applications={}
    for client in ['host','guest']:
        samples[client]=records(directory/(client+'.stdout.log.gz'),'LOBBY_SAMPLE ')
        check(case+' '+client+' popup-free every sampled frame',all(s['lobby_popup_count']==0 for s in samples[client]))
        check(case+' '+client+' stable parent connections',len({(s['tree_exit_callbacks'],s['focus_callbacks']) for s in samples[client]})==1)
        text=gzip.decompress((directory/(client+'.stdout.log.gz')).read_bytes()).decode()+(directory/(client+'.stderr.log')).read_text()
        check(case+' '+client+' raw logs free of engine errors',all(s not in text for s in ['SCRIPT ERROR','Parse Error','ERROR:']))
        if case=='full-flow': applications[client]=records(directory/(client+'.stdout.log.gz'),'LOBBY_APPLIED ')
    for milestone in summary['milestones']:
        s=milestone['sample'];layout=s['layout'];ui=s['ui']
        for button in ['leave_button','restart_button']:
            if not ui[button]['visible']: continue
            for content in ['top','score','status','board']:
                if layout[content]['visible']: assert not intersects(ui[button]['rect'],layout[content]['rect']),(case,milestone['name'],button,content)
    check(case+' captured gameplay controls avoid HUD/scoreboard',True)
    result={'wallMs':summary['wallMs'],'assertions':len(summary['checks']),'clicksWithGeometry':len(clicks),'port':summary['port'],'cleanup':summary['cleanup']}
    wire=records(directory/'wire.jsonl.gz')
    if case=='targeted':
        check('targeted no room or simulation messages',wire==[])
        for size in [(960,640),(1280,800)]:
            check('actual row focus captured '+str(size),any(tuple(m['sample']['viewport'])==size and m['sample']['ui']['role']['focused'] for m in summary['milestones']))
    else:
        received=[f for f in wire if f['type']=='received']
        counts={str(r):dict(collections.Counter(f['frame']['type'] for f in received if f['recipient']==r)) for r in [0,1,2,3]}
        check('spectator connection only joins and leaves',counts['2']=={'join':1,'leave':1})
        check('fresh guest distinct explicit connection',counts['3']['join']==1 and counts['3']['input']>0)
        check('host alone configures and starts',counts['0']['create']==counts['0']['host']==1 and counts['0']['start']==2 and all(set(counts[str(r)])<={'join','input','leave'} for r in [1,2,3]))
        config=next(f['frame']['config'] for f in received if f['frame']['type']=='host')
        check('ordinary mode/time/bot configuration',config['timeLimit']==60 and config['botCount']==2 and config['mode']==summary['mode']=='teamdeathmatch')
        index={(f['peer'],f['revision'],f['seq']):f for f in wire if f['type']=='snapshot'}
        for client,frames in applications.items():
            for a in frames:
                source=index[(a['peer'],a['revision'],a['seq'])];actors={x['id']:x for x in source['state']['actors']}
                for visual in a['visuals']:
                    actor=actors[visual['id']];expected=[actor['x'],actor['y']+.9,actor['z']]
                    assert all(abs(x-y)<1e-4 for x,y in zip(expected,visual['ingested']))
                if a['spectating']:
                    assert a['actor']==-1 and a['local']=={} and a['ack']==0 and source['actor'] is None
                else:
                    actor=actors[a['actor']]
                    assert all(abs(actor[k]-a['local'][k])<1e-7 for k in ['x','y','z','health','dead','shots'])
            check(client+' source/native visual application matches',len(frames)>5)
        spec=[a for a in applications['guest'] if a['spectating']]
        check('spectator actually applies ongoing snapshots',len(spec)>20)
        check('spectator stays actorless and uncaptured',all(s['actor']==-1 and not s['pose'] and not s['captured'] and not s['eligible'] and s['input_seq']==0 for s in samples['guest'] if s['spectating']))
        check('spectator sees natural results',any(m['sample']['spectating'] and m['sample']['phase']==4 for m in summary['milestones']))
        results=next(f for f in wire if f['recipient']==0 and f['type']=='results');start=next(f for f in wire if f['recipient']==0 and f['type']=='start')
        check('natural source 60s results',60<=results['state']['time']<61 and 55000<=results['wall']-start['wall']<=70000)
        effects={}
        for stage,r,rev in [('07-host-play',0,1),('08-guest-play',1,1),('11a-host-for-spectator',0,1),('16-guest-fresh-recapture',3,2)]:
            burst=[a for a in actions if a['stage']==stage and a['op']=='key' and a['key']=='W']
            first,last=burst[0]['wall'],burst[-1]['wall']
            snaps=[f for f in wire if f['recipient']==r and f['revision']==rev and f['type']=='snapshot' and first-100<=f['wall']<=last+200]
            actors=[next(a for a in f['state']['actors'] if a['id']==f['actor']) for f in snaps]
            origin=None;distance=0.0
            for a in actors:
                if a['health']<=0 or a['dead']>0: origin=None;continue
                if origin is None: origin=a
                distance=max(distance,math.hypot(a['x']-origin['x'],a['z']-origin['z']))
            shots=max(a['shots'] for a in actors)-min(a['shots'] for a in actors)
            check(stage+' source applies living movement and fire',distance>.5 and shots>0)
            effects[stage]={'livingDisplacementMetres':distance,'shotGrowth':shots}
            if stage=='11a-host-for-spectator':
                seen=[a for a in spec if first-100<=index[(a['peer'],a['revision'],a['seq'])]['wall']<=last+350]
                visible=[v['rendered'] for a in seen for v in a['visuals'] if v['id']==snaps[0]['actor'] and v['visible']]
                travel=max(math.dist(p,visible[0]) for p in visible)
                check('spectator renderer shows moving host',travel>.5)
                effects[stage]['spectatorRenderedDisplacementMetres']=travel
        result.update(wireCounts=counts,nativeApplications={n:len(a) for n,a in applications.items()},spectatorApplications=len(spec),effects=effects,sourceResultsTime=results['state']['time'],sourceRoundWallMs=results['wall']-start['wall'])
    report['runs'][case]=result
report['protectedPort']=subprocess.check_output(['ss','-ltnp','sport = :4332'],text=True)
check('protected service remains original PID','127.0.0.1:4332' in report['protectedPort'] and 'pid=1094444' in report['protectedPort'])
report['assertionCount']=len(report['checks'])
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='checks'},indent=2))
