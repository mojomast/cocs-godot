"""Read-only follow-up receipt/application/layout audit; never touches old runs."""
import collections, gzip, hashlib, json, math, pathlib, socket, subprocess
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[2]
report={'status':'PASS scoped UI/lifecycle acceptance; native active spectator rejoin and package OPEN','checks':[],'cases':{}}
def require(name,condition):
    assert condition,name
    report['checks'].append(name)
def text(path): return gzip.decompress(path.read_bytes()).decode()
def records(value,prefix=''): return [json.loads(l[len(prefix):]) for l in value.splitlines() if l.startswith(prefix)]
def intersect(a,b): return a[0]<b[0]+b[2] and a[0]+a[2]>b[0] and a[1]<b[1]+b[3] and a[1]+a[3]>b[1]
previous=json.loads((ROOT/'port/reports/multiplayer-lobby-independent/provenance.json').read_text())
for name,digest in {**previous['inventory'],**previous['ownedObservers']}.items():
    require('preserved previous file '+name,hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest)
for case in ['meridian-tdm','ember-startup']:
    directory=OUT/case
    summary=json.loads((directory/'summary.json').read_text())
    require(case+' live helper success',summary['status'].startswith('PASS') and 'error' not in summary)
    require(case+' bounded runtime',summary['wallMs']<=180000)
    for name in ['wire.jsonl','actions.jsonl']:
        raw=gzip.decompress((directory/(name+'.gz')).read_bytes())
        require(case+' '+name+' archive integrity',len(raw)==summary[name]['bytes'] and hashlib.sha256(raw).hexdigest()==summary[name]['sha256'])
    require(case+' all owned processes reaped',all(c['reaped'] and not pathlib.Path('/proc/'+str(c['pid'])).exists() for c in summary['cleanup']))
    require(case+' server sockets/temp closed',summary['serverClosed'] and summary['sockets']==0 and summary['tempRemoved'])
    with socket.socket() as s:
        s.settimeout(.5)
        require(case+' former loopback listener closed',s.connect_ex(('127.0.0.1',summary['port']))!=0)
    require(case+' did not own protected port',summary['port']!=4332)
    wire=records(text(directory/'wire.jsonl.gz'))
    received=[f for f in wire if f['type']=='received']
    counts={str(r):dict(collections.Counter(f['frame']['type'] for f in received if f['recipient']==r)) for r in sorted({f['recipient'] for f in received})}
    for r,count in counts.items():
        if r!='0': require(case+' guest boundary '+r,set(count)<= {'join','leave','input'} and count['join']==1)
    require(case+' one host create/config',counts['0']['create']==counts['0']['host']==1)
    require(case+' explicit source start count',counts['0']['start']==(2 if case=='meridian-tdm' else 1))
    config=next(f['frame']['config'] for f in received if f['frame']['type']=='host')
    require(case+' ordinary settings',config['mode']==summary['mode'] and config['botCount']==2 and config['timeLimit']==60)
    applied_by_name={}
    for name in ['host','guest']:
        native=text(directory/(name+'.stdout.log.gz'))
        require(case+' '+name+' engine errors absent','SCRIPT ERROR' not in native+(directory/(name+'.stderr.log')).read_text())
        applied=records(native,'LOBBY_APPLIED ')
        applied_by_name[name]=applied
        index={(f['peer'],f['revision'],f['seq']):f for f in wire if f['type']=='snapshot'}
        for a in applied:
            source=index[(a['peer'],a['revision'],a['seq'])]
            actor=next(x for x in source['state']['actors'] if x['id']==a['actor'])
            assert all(abs(actor[k]-a['local'][k])<1e-7 for k in ['x','y','z','health','dead','shots']),(case,name,a['seq'],'state mismatch')
            assert abs(actor['x']-a['camera'][0])<1e-5 and abs(actor['z']-a['camera'][2])<1e-5,(case,name,a['seq'],'camera mismatch')
            assert a['ack']==source['acks'].get(str(a['actor']),0),(case,name,a['seq'],'recipient ACK mismatch')
        require(case+' '+name+' source/native application matches',len(applied)>5)
    for m in summary['milestones']:
        sample=m['sample'];layout=sample['layout'];ui=sample['ui']
        require(case+' '+m['name']+' HUD visibility',layout['hud']['visible']==(sample['phase'] in [3,4,20]))
        for button in ['leave_button','restart_button']:
            if not ui[button]['visible']: continue
            for content in ['top','score','status','board']:
                if layout[content]['visible']: require(case+' '+m['name']+' '+button+' avoids '+content,not intersect(ui[button]['rect'],layout[content]['rect']))
        if ui['restart_button']['visible']: require(case+' '+m['name']+' separate actions',not intersect(ui['leave_button']['rect'],ui['restart_button']['rect']))
        if 'leave' in m['name']:
            require(case+' '+m['name']+' cleaned local state',sample['phase']==-3 and sample['peer']==sample['actor']==-1 and not sample['room'] and not sample['pose'] and not sample['captured'] and sample['actors']==sample['pickups']==sample['ack']==sample['input_seq']==0)
    result={'wallMs':summary['wallMs'],'runtimeAssertions':len(summary['checks']),'port':summary['port'],'wireCounts':counts,'nativeApplications':{name:len(a) for name,a in applied_by_name.items()},'cleanup':summary['cleanup'],'effects':{}}
    if case=='meridian-tdm':
        for name,r,rev in [('host-round1',0,1),('guest-round1',1,1),('guest-restart',3,2)]:
            inputs=[f for f in received if f['recipient']==r and f['revision']==rev and f['frame']['type']=='input']
            active=[f for f in inputs if f['frame']['input']['fire'] and math.hypot(f['frame']['input']['x'],f['frame']['input']['z'])>.1]
            require(name+' movement/fire receipts',len(active)>5)
            snapshots=[f for f in wire if f['recipient']==r and f['revision']==rev and f['type']=='snapshot']
            burst=[f for f in snapshots if active[0]['wall']-100<=f['wall']<=active[-1]['wall']+200]
            actors=[next(a for a in f['state']['actors'] if a['id']==f['actor']) for f in burst]
            living=[a for a in actors if a['health']>0 and a['dead']==0]
            distance=max(math.hypot(a['x']-living[0]['x'],a['z']-living[0]['z']) for a in living)
            shot_growth=max(a['shots'] for a in actors)-min(a['shots'] for a in actors)
            require(name+' living movement applied',distance>.5)
            require(name+' actual shots applied',shot_growth>0)
            result['effects'][name]={'receivedInputs':len(inputs),'activeMovementFireInputs':len(active),'sourceSnapshots':len(snapshots),'livingMovementMetres':distance,'shotGrowthDuringBurst':shot_growth,'maxShotsInConnection':max(next(a for a in f['state']['actors'] if a['id']==f['actor'])['shots'] for f in snapshots),'ackHighwaterReceiptOnly':max(f['acks'].get(str(f['actor']),0) for f in snapshots)}
        results=next(f for f in wire if f['recipient']==0 and f['type']=='results')
        start=next(f for f in wire if f['recipient']==0 and f['type']=='start' and f['revision']==1)
        result['resultsSourceTime']=results['state']['time'];result['roundWallMs']=results['wall']-start['wall']
        require('natural sixty-second results',60<=result['resultsSourceTime']<61 and 55000<=result['roundWallMs']<=70000)
        require('source spectator assignment and notice',any(f['recipient']==2 and f['type']=='welcome' and f['spectate'] for f in wire) and any(f['recipient']==2 and f['type']=='error' and 'spectator' in f['message'] for f in wire))
        require('spectator remained unassigned',all(f.get('actor') is None for f in wire if f['recipient']==2 and f['type']=='snapshot'))
        require('spectator failure emitted no controls',counts['2']=={'join':1,'leave':1})
        require('guest fresh capture after authoritative revision 2',any(m['name']=='16-guest-fresh-recapture-captured' and m['sample']['captured'] and m['sample']['revision']==2 and m['sample']['actor']>=0 for m in summary['milestones']))
        require('live results geometry both sizes',{tuple(m['sample']['viewport']) for m in summary['milestones'] if m['sample']['phase']==4}=={(960,640),(1280,800)})
        result['spectator']='OPEN: source supports assignment; native treats informational error as fatal'
    report['cases'][case]=result
report['port4332Observation']=subprocess.check_output(['ss','-ltnp','sport = :4332'],text=True)
require('protected 4332 service still listening','127.0.0.1:4332' in report['port4332Observation'] and 'pid=1094444' in report['port4332Observation'])
report['assertionCount']=len(report['checks'])
report['applicationFramesMatched']=sum(sum(c['nativeApplications'].values()) for c in report['cases'].values())
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='checks'},indent=2))
