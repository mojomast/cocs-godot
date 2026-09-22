"""Offline audit only: preserve primary evidence, correlate triage, verify cleanup."""
import collections,gzip,hashlib,json,math,pathlib,socket,subprocess
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[2]
PACKAGE=pathlib.Path('/tmp/opencode/lead-native-linux-package/builds/1790054125934591826/cocs-native-linux')
PRIMARY=pathlib.Path('/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/port/reports/linux-lobby-play-independent')
report={'verdict':'HOLD full exported package play: release embedded-popup connection cleanup errors reproduced','checks':[],'runs':{}}
def check(name,value):
    assert value,name
    report['checks'].append(name)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def lines(path): return gzip.decompress(path.read_bytes()).decode().splitlines()
def records(path): return [json.loads(l) for l in lines(path) if l.strip()]
inspection=json.loads((OUT/'lead-failure-inspection.json').read_text())
for name,digest in inspection['files'].items(): check('primary report unchanged '+pathlib.Path(name).name,sha(pathlib.Path(name))==digest)
manifest=json.loads((PACKAGE/'manifest.json').read_text())
check('manifest unchanged',sha(PACKAGE/'manifest.json')=='8f602b1cc48ab07a05378365a5890d96efea6b8b3d90e9d1c8a916ee085f40cc')
for name,digest in manifest['files'].items(): check('package unchanged '+name,sha(PACKAGE/name)==digest)
report['package']={'path':str(PACKAGE),'manifestSha256':sha(PACKAGE/'manifest.json'),'filesVerified':len(manifest['files']),'authorityModules':sum(n.startswith('runtime/') and n.endswith('.mjs') and '/node_modules/' not in n for n in manifest['files']),'releaseSha256':sha(PACKAGE/'cocs.x86_64'),'pckSha256':sha(PACKAGE/'cocs.pck')}
actions_by_run={}
for run in ['targeted','targeted-debug']:
    directory=OUT/run
    summary=json.loads((directory/'summary.json').read_text())
    check(run+' scenario completed',summary['status']=='TARGETED COMPLETE')
    check(run+' bounded',summary['wallMs']<45000)
    check(run+' isolated environment removed',summary['tempRemoved'])
    check(run+' authority closed without clients',summary['serverClosed'] and summary['sockets']==0)
    check(run+' all owned children reaped',all(p['reaped'] and not pathlib.Path('/proc/'+str(p['pid'])).exists() for p in summary['cleanup']))
    with socket.socket() as s:
        s.settimeout(.5)
        check(run+' former owned port closed',s.connect_ex(('127.0.0.1',summary['port']))!=0)
    check(run+' protected port not owned',summary['port']!=4332)
    check(run+' no room/gameplay messages',records(directory/'wire.jsonl.gz')==[])
    for name in ['wire.jsonl','actions.jsonl','witnesses.jsonl']:
        raw=gzip.decompress((directory/(name+'.gz')).read_bytes())
        check(run+' archive '+name,len(raw)==summary[name]['bytes'] and hashlib.sha256(raw).hexdigest()==summary[name]['sha256'])
    witnesses=records(directory/'witnesses.jsonl.gz')
    actions=records(directory/'actions.jsonl.gz');actions_by_run[run]=actions
    errors=[f for f in witnesses if f['kind']=='stderr' and 'ERROR:' in f['text']]
    error_lines=[{'wall':f['receivedWall'],'client':f['client'],'stage':f['stage'],'command':f.get('currentCommand'),'text':l} for f in errors for l in f['text'].splitlines() if 'ERROR:' in l]
    engine=[f for f in witnesses if f['kind']=='engine' and f['client']=='guest']
    hides=[f for f in engine if f['event'].endswith('-popup-hide')]
    check(run+' all popup types covered',{f['event'] for f in hides}=={'role-popup-hide','maps-popup-hide','modes-popup-hide'})
    check(run+' needed policy skipped redundant calls',any(f['event']=='grab-focus-skipped-already-focused' and f['stage']=='needed-focus-map' for f in engine))
    check(run+' Enter and Escape paths exercised',any(f['op']=='key' and f['key']=='Enter' and f['pressed'] for f in actions) and any(f['op']=='key' and f['key']=='Escape' and f['pressed'] for f in actions))
    if run=='targeted':
        check('release reproduces fourteen engine errors',len(error_lines)==14 and not summary['cleanLogs'])
        check('release first error is ordinary Enter selection',error_lines[0]['command']['id']==22 and error_lines[0]['command']['op']=='key' and error_lines[0]['command']['key']=='Enter')
        check('release errors also occur with needed-only focus',any(f['stage']=='needed-focus-map' for f in error_lines))
        check('release errors not emitted on grab-focus commands',all(f['command']['op']!='focus' for f in error_lines))
        check('release leaked connections retained after popup hides',all(len(f['connections']['tree_exited'])>=1 for f in hides))
        check('release never disconnects three popup callbacks',len(hides[-1]['connections']['tree_exited'])==3)
    else:
        check('debug comparison has no engine errors',not error_lines and summary['cleanLogs'])
        check('debug removes popup callbacks after every hide',all(not f['connections']['tree_exited'] for f in hides))
        check('same external observer',summary['observerSha256']==sha(OUT/'export-lobby-observer.gd'))
    report['runs'][run]={'durationMs':summary['wallMs'],'functionalAssertions':len(summary['checks']),'engineErrorCount':len(error_lines),'errorWitnesses':error_lines,'commands':len(actions),'popupHideReceipts':[{'command':f['command'],'event':f['event'],'wall':f['wall'],'retainedTreeExitCallbacks':len(f['connections']['tree_exited'])} for f in hides],'cleanup':summary['cleanup'],'port':summary['port']}
normalize=lambda rows:[{k:v for k,v in row.items() if k!='wall'} for row in rows]
check('identical action sequences across release and debug',normalize(actions_by_run['targeted'])==normalize(actions_by_run['targeted-debug']))
# Archived lead gameplay: audit the saved source/native records, do not rerun.
wire=records(PRIMARY/'wire.jsonl.gz')
received=[f for f in wire if f['type']=='received']
counts={str(r):dict(collections.Counter(f['frame']['type'] for f in received if f['recipient']==r)) for r in [0,1,2,3]}
check('archived lead spectator only joins/leaves',counts['2']=={'join':1,'leave':1})
check('archived lead fresh guest is another connection',counts['3']['join']==1 and counts['3']['input']>0)
index={(f['peer'],f['revision'],f['seq']):f for f in wire if f['type']=='snapshot'}
matched={}
for name in ['host','guest']:
    applied=[json.loads(l[len('LOBBY_APPLIED '):]) for l in lines(PRIMARY/(name+'.stdout.log.gz')) if l.startswith('LOBBY_APPLIED ')]
    for a in applied:
        source=index[(a['peer'],a['revision'],a['seq'])]
        if a['actor']<0:
            assert a['local']=={} and a['ack']==0 and source['actor'] is None
        else:
            actor=next(x for x in source['state']['actors'] if x['id']==a['actor'])
            assert all(abs(actor[k]-a['local'][k])<1e-7 for k in ['x','y','z','health','dead','shots'])
    check('archived '+name+' native/source correlation',len(applied)>5)
    matched[name]=len(applied)
effects={}
for name,r,rev in [('host-round1',0,1),('guest-round1',1,1),('fresh-guest-round2',3,2)]:
    active=[f for f in received if f['recipient']==r and f['revision']==rev and f['frame']['type']=='input' and f['frame']['input']['fire'] and math.hypot(f['frame']['input']['x'],f['frame']['input']['z'])>.1]
    snapshots=[f for f in wire if f['recipient']==r and f['revision']==rev and f['type']=='snapshot' and active[0]['wall']-100<=f['wall']<=active[-1]['wall']+200]
    actors=[next(a for a in f['state']['actors'] if a['id']==f['actor']) for f in snapshots]
    living=[a for a in actors if a['health']>0 and a['dead']==0]
    distance=max(math.hypot(a['x']-living[0]['x'],a['z']-living[0]['z']) for a in living)
    shots=max(a['shots'] for a in actors)-min(a['shots'] for a in actors)
    check('archived '+name+' source applied movement/fire',distance>.5 and shots>0)
    effects[name]={'livingDisplacementMetres':distance,'shotGrowth':shots}
lead_summary=json.loads((PRIMARY/'summary.json').read_text())
check('archived full flow remains failed clean-log acceptance',lead_summary['status']=='PARTIAL/FAIL' and 'no native script errors' in lead_summary['error'])
report['archivedLeadFlow']={'notFreshExecution':True,'wallMs':lead_summary['wallMs'],'milestones':len(lead_summary['milestones']),'wireCounts':counts,'nativeApplicationsMatched':matched,'effects':effects,'verdict':lead_summary['status'],'truncatedFinalGuestSampleLines':len(inspection['guest']['truncatedSampleLines'])}
report['protectedPort']=subprocess.check_output(['ss','-ltnp','sport = :4332'],text=True)
check('protected service still original Node PID','127.0.0.1:4332' in report['protectedPort'] and 'pid=1094444' in report['protectedPort'])
check('tracked runtime/shared files untouched',subprocess.check_output(['git','diff','e9ed72f','--name-only','--','godot','tools','server','game'],cwd=ROOT,text=True).strip()=='')
report['assertionCount']=len(report['checks'])
(OUT/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'verdict':report['verdict'],'assertions':report['assertionCount'],'runs':{n:{k:v for k,v in r.items() if k not in ['errorWitnesses','popupHideReceipts']} for n,r in report['runs'].items()},'archivedLeadFlow':report['archivedLeadFlow']},indent=2))
