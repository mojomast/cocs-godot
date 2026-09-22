#!/usr/bin/env python3
"""Owned target-victory/shot-coaching acceptance. No simulation mutation."""
import argparse
import hashlib
import json
import os
import pathlib
import selectors
import shutil
import subprocess
import tempfile
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
BIN = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
DEPS = '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules'
parser = argparse.ArgumentParser()
parser.add_argument('--race', action='store_true')
parser.add_argument('--visual', action='store_true', help='Stationary soccer, no scoring attempt')
parser.add_argument('--attempt', type=int, choices=[1, 2], help='Explicit normal-bot soccer attempt, 175s maximum')
args = parser.parse_args()
assert sum([args.race, args.visual, bool(args.attempt)]) <= 1
OUT = ROOT / 'port/native-sports-victory/evidence' / str(uuid.uuid4())
OUT.mkdir(parents=True)
children = []
report = {'base': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'options':vars(args), 'commands':[], 'cases':[]}
manifest = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
            for folder, suffix in [('game','*.mjs'),('server','*.mjs'),('godot','*.gd'),('port/native-sports-victory','*.py'),('port/native-sports-victory','*.mjs')]
            for p in sorted((ROOT/folder).rglob(suffix))}
for name in ['tools/godot-export/semantic.mjs','godot/project.godot','godot/sports/demo.tscn']:
    manifest[name] = hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
manifest['pinnedGodot'] = hashlib.sha256(pathlib.Path(BIN).read_bytes()).hexdigest()
manifest['node'] = hashlib.sha256(pathlib.Path(shutil.which('node')).read_bytes()).hexdigest()
ws = pathlib.Path(DEPS)/'ws'
manifest['wsTree'] = hashlib.sha256(''.join(f'{p.relative_to(ws)} {hashlib.sha256(p.read_bytes()).hexdigest()}\n' for p in sorted(ws.rglob('*')) if p.is_file()).encode()).hexdigest()
(OUT/'hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
report['hashManifestSHA256'] = hashlib.sha256((OUT/'hashes.json').read_bytes()).hexdigest()

def stop(child):
    if child.poll() is None:
        child.terminate()
        try: child.wait(5)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(5)
    try: os.kill(child.pid,0)
    except ProcessLookupError: return
    raise AssertionError('Owned process still exists')

def run(command, path, env, timeout=60):
    report['commands'].append(command)
    with path.open('w') as log:
        child = subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
        children.append(child)
        try: code = child.wait(timeout)
        finally: stop(child)
    text = path.read_text()
    assert code == 0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text, str(path)
    return text

try:
    assert subprocess.check_output([BIN,'--version'],text=True).strip() == '4.5.2.stable.official.6ce3de25a'
    with tempfile.TemporaryDirectory(prefix='sports-victory-',dir='/tmp/opencode') as tmp:
        temp = pathlib.Path(tmp)
        env = {**os.environ,'HOME':tmp,'GODOT_SILENCE_ROOT_WARNING':'1','LIBGL_ALWAYS_SOFTWARE':'1'}
        for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
            env[key] = str(temp/key)
            (temp/key).mkdir()
        for name in ['godot','game','server']:
            shutil.copytree(ROOT/name,temp/name,ignore=shutil.ignore_patterns('.godot','node_modules','__pycache__'))
        (temp/'node_modules').symlink_to(DEPS,target_is_directory=True)
        run(['node',str(ROOT/'tools/godot-export/semantic.mjs'),str(temp/'godot/content/generated')],OUT/'export.log',env)
        generated = {str(p.relative_to(temp/'godot')):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((temp/'godot/content/generated').rglob('*')) if p.is_file()}
        (OUT/'generated-hashes.json').write_text(json.dumps(generated,indent=2)+'\n')
        base = [BIN,'--headless','--path',str(temp/'godot')]
        run(['node',str(ROOT/'port/native-sports-victory/source-config.mjs')],OUT/'source-config.json',env)
        run(base+['--editor','--import'],OUT/'import.log',env)
        for script in ['sports/test_controls','vehicles/test_puma','sports/test_polish','sports/progression_test','sports/soccer_test','sports/practice_test']:
            run(base+['--script','res://tests/'+script+'.gd'],OUT/(script.split('/')[-1]+'.log'),env)
        if args.race or args.visual or args.attempt:
            readfd,writefd = os.pipe()
            with (OUT/'xvfb.log').open('w') as xlog:
                command = ['Xvfb','-displayfd',str(writefd),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix']
                report['commands'].append(command)
                xvfb = subprocess.Popen(command,pass_fds=(writefd,),stdout=xlog,stderr=xlog)
                children.append(xvfb)
                os.close(writefd)
                with selectors.DefaultSelector() as sel:
                    sel.register(readfd,selectors.EVENT_READ)
                    assert sel.select(10),'Xvfb timeout'
                    display = os.read(readfd,100).decode().strip()
                os.close(readfd)
                assert display.isdigit() and xvfb.poll() is None
                env['DISPLAY'] = ':'+display
                for resolution in (['960x640','1280x800'] if not args.attempt else ['1280x800' if args.attempt == 1 else '960x640']):
                    case = OUT/resolution
                    case.mkdir()
                    with (case/'server.log').open('w') as log:
                        command = ['node',str(ROOT/'port/native-sports-victory/server.mjs'),tmp,str(case/'wire.json')]
                        report['commands'].append(command)
                        server = subprocess.Popen(command,stdout=subprocess.PIPE,stderr=log,text=True,env=env)
                        children.append(server)
                        try:
                            with selectors.DefaultSelector() as sel:
                                sel.register(server.stdout,selectors.EVENT_READ)
                                assert sel.select(10),'server timeout'
                                line = server.stdout.readline().strip()
                            assert line.startswith('ENDPOINT ws://127.0.0.1:'),line
                            script = 'practice_race_observe' if args.race else ('practice_soccer_observe' if args.attempt else 'soccer_observe')
                            command = [BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution',resolution,'--script','res://tests/sports/'+script+'.gd','--','--map='+('ion-speedway' if args.race else 'aurora-stadium'),'--endpoint='+line.split(' ',1)[1],'--time-limit=180','--round-target='+('1' if args.race else '15'),'--progression-out='+str(case),'--soccer-attempt='+str(args.attempt or 0)]
                            text = run(command,case/'native.log',env,185)
                        finally: stop(server)
                    wire = json.loads((case/'wire.json').read_text())
                    assert wire['cleanup'] == {'serverClosed':True,'sockets':0}
                    prefix = 'VICTORY_ENDED ' if args.race else 'SOCCER_ENDED '
                    end = json.loads(next(line.split(' ',1)[1] for line in text.splitlines() if line.startswith(prefix)))
                    if args.race:
                        assert wire['starts'] == 2 and len(wire['results']) == 1
                        result = wire['results'][0]
                        assert result['overReason'] == 'race-finish' and result['race']['winnerId'] == result['actor']
                        assert result['race']['laps'] == 1 and result['race']['standings'][0]['completedLaps'] == 1
                        assert set(end['gates']) == set(range(17)) and end['fresh_displacement'] > .5
                        assert len([e for e in wire['events'] if e['type'] == 'race-finish' and e['actor'] == result['actor']]) == 1
                        stages = [json.loads(s.split(' ',1)[1]) for s in text.splitlines() if s.startswith('VICTORY_INPUT_STAGE ')]
                        early = [i for i in wire['inputs'] if i['round'] == 2 and i['seq'] <= stages[1]['seq']]
                        assert len(early)>30 and all(i['input'].get('x',0)==0 and i['input'].get('z',0)==0 for i in early)
                    goals = [e for e in wire['events'] if e['type']=='soccer-goal']
                    proven = []
                    for goal in goals:
                        before = [s for s in wire['samples'] if s['time']<goal['time']-.001]
                        after = [s for s in wire['samples'] if s['time']>=goal['time']]
                        if not before or not after: continue
                        low,high = before[-1],after[0]
                        local = next(a for a in low['roles'] if a['id']==low['actor'])
                        team = str(goal['team'])
                        if goal['actorId']==local['id'] and goal['team']==local['team'] and not local['bot'] and high['race']['scores'][team]==low['race']['scores'][team]+1:
                            proven.append({'event':goal,'before':low,'after':high})
                    if args.attempt: assert bool(proven)==end['local_goal']
                    if proven:
                        captures = [json.loads(line.split(' ',1)[1]) for line in text.splitlines() if line.startswith('PROGRESSION_CAPTURE ')]
                        for proof in proven:
                            team = str(proof['event']['team'])
                            message = ('Red' if team=='0' else 'Blue')+' GOAL · Ball reset to centre'
                            assert any(c['seq']>=proof['after']['seq'] and c['race']['scores'][team]==proof['after']['race']['scores'][team] and message in c['hud'] for c in captures), 'Local goal requires its own visible score/reset capture'
                    if goals: assert 'GOAL · Ball reset to centre' in text and (case/'goal.png').exists()
                    report['cases'].append({'resolution':resolution,'outcome':end,'provenLocalGoals':proven,'sourceGoals':goals,'inputReceipts':len(wire['inputs']),'cleanup':wire['cleanup']})
                stop(xvfb)
    report['privateTempRemoved'] = not temp.exists()
    report['status'] = 'PASS'
except Exception as exc:
    report['status'] = 'FAIL'
    report['error'] = str(exc)
    raise
finally:
    for child in reversed(children): stop(child)
    report['ownedProcessesReaped'] = True
    (OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'evidence':str(OUT),**report},indent=2))
