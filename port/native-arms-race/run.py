#!/usr/bin/env python3
"""Owned normal-rate source + native evidence; no simulation mutation."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
BIN = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
DEPS = '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules'
parser = argparse.ArgumentParser()
parser.add_argument('--startup', action='store_true', help='Three maps, timer results/restart on Meridian')
parser.add_argument('--attempt', type=int, choices=[1, 2], help='One <=177s Meridian combat attempt')
args = parser.parse_args()
OUT = ROOT / 'port/native-arms-race/evidence' / str(uuid.uuid4())
OUT.mkdir(parents=True)
children = []
report = {'base':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), 'options':vars(args),'commands':[],'cases':[]}

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def stop(child):
    if child.poll() is None:
        child.terminate()
        try: child.wait(8)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(5)
    try: os.kill(child.pid, 0)
    except ProcessLookupError: return
    raise RuntimeError('Owned child not reaped')

def run(command, path, env, timeout=120):
    report['commands'].append(command)
    with path.open('w') as log:
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        children.append(child)
        try: code = child.wait(timeout)
        finally: stop(child)
    text = path.read_text()
    require(code == 0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text, str(path))
    return text

def line_from(child):
    with selectors.DefaultSelector() as sel:
        sel.register(child.stdout, selectors.EVENT_READ)
        require(bool(sel.select(15)), 'Server startup timeout')
    line = child.stdout.readline().strip()
    require(line.startswith('ENDPOINT ws://127.0.0.1:'), line)
    return line.split(' ',1)[1]

try:
    require(not (args.startup and args.attempt), 'Choose one operation')
    hashes = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
              for folder, suffix in [('game','*.mjs'),('server','*.mjs'),('godot','*.gd'),('port/native-arms-race','*.py'),('port/native-arms-race','*.mjs')]
              for p in sorted((ROOT/folder).rglob(suffix))}
    for name in ['godot/project.godot','godot/arms_race/demo.tscn','tools/godot-export/semantic.mjs','port/contracts/map-selection.json']:
        hashes[name] = hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
    hashes['pinnedGodot'] = hashlib.sha256(Path(BIN).read_bytes()).hexdigest()
    hashes['node'] = hashlib.sha256(Path(shutil.which('node')).read_bytes()).hexdigest()
    ws = Path(DEPS)/'ws'
    hashes['wsTree'] = hashlib.sha256(''.join(f'{p.relative_to(ws)} {hashlib.sha256(p.read_bytes()).hexdigest()}\n' for p in sorted(ws.rglob('*')) if p.is_file()).encode()).hexdigest()
    (OUT/'hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
    require(subprocess.check_output([BIN,'--version'],text=True).strip() == '4.5.2.stable.official.6ce3de25a','Wrong Godot')
    with tempfile.TemporaryDirectory(prefix='arms-race-',dir='/tmp/opencode') as tmp:
        temp = Path(tmp)
        env = {**os.environ,'HOME':tmp,'PORT':'0','GODOT_SILENCE_ROOT_WARNING':'1','LIBGL_ALWAYS_SOFTWARE':'1'}
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
        run(base+['--editor','--import'],OUT/'import.log',env)
        run(base+['--script','res://tests/arms_race/fixtures.gd'],OUT/'fixtures.log',env)
        run(['node','--test','game/armsrace.test.mjs','game/outcome.test.mjs'],OUT/'source-tests.log',env)
        if args.startup or args.attempt:
            readfd, writefd = os.pipe()
            with (OUT/'xvfb.log').open('w') as xlog:
                command = ['Xvfb','-displayfd',str(writefd),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix']
                report['commands'].append(command)
                xvfb = subprocess.Popen(command,pass_fds=(writefd,),stdout=xlog,stderr=xlog)
                children.append(xvfb)
                os.close(writefd)
                with selectors.DefaultSelector() as sel:
                    sel.register(readfd,selectors.EVENT_READ)
                    require(bool(sel.select(10)), 'Xvfb timeout')
                    # Xvfb may write the number and newline separately. Closing
                    # after a short os.read breaks its second write (SIGPIPE).
                    with os.fdopen(readfd) as pipe:
                        display = pipe.readline().strip()
                require(display.isdigit() and xvfb.poll() is None, 'Invalid/dead display')
                env['DISPLAY'] = ':'+display
                report['display'] = env['DISPLAY']
                run([BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--quit'],OUT/'display.log',env,20)
                cases = [('meridian-exchange','1280x800',False)] if args.attempt else [('meridian-exchange','960x640',True),('verdant-reliquary','1280x800',False),('ember-crucible','960x640',False)]
                for map_id, resolution, lifecycle in cases:
                    case = OUT/map_id
                    case.mkdir()
                    with (case/'server.log').open('w') as log:
                        command = ['node',str(ROOT/'port/native-arms-race/server.mjs'),tmp,str(case/'wire.json')]
                        report['commands'].append(command)
                        server = subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=log,text=True)
                        children.append(server)
                        try:
                            endpoint = line_from(server)
                            command = [BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution',resolution,'--script','res://tests/arms_race/observe.gd','--','--map='+map_id,'--endpoint='+endpoint,'--round-seconds='+('180' if args.attempt else '60'),'--evidence-out='+str(case),'--native-trace']
                            if args.attempt: command += ['--attempt='+str(args.attempt)]
                            if lifecycle: command += ['--check-lifecycle']
                            text = run(command,case/'native.log',env,180 if args.attempt else 90)
                        finally: stop(server)
                    wire = json.loads((case/'wire.json').read_text())
                    require(wire['cleanup'] == {'serverClosed':True,'sockets':0}, 'Server cleanup')
                    end = json.loads(next(s.split(' ',1)[1] for s in text.splitlines() if s.startswith('ARMS_ENDED ')))
                    require(wire['samples'] and wire['inputs'] and end['ack'] > 10, 'Startup/ACK missing')
                    for config in wire['configs']:
                        c = config['config']
                        require(config['mapId']==map_id and c['mode']=='armsrace' and c['botCount']==2 and c['difficulty']=='normal' and c['fragLimit']==10, 'Wrong source config')
                    require(all('weapon' not in i['input'] for i in wire['inputs']), 'Illegal selection queued')
                    if lifecycle:
                        require(wire['starts']==2 and len(wire['results'])==1 and end['fresh_moved'], 'Round lifecycle not proved')
                        require(wire['results'][0]['state']['overReason']=='time','Expected ordinary timer ending')
                    promotions = [e for e in wire['events'] if e['type']=='armsrace-promote' and e['actor']==wire['samples'][0]['actor']]
                    if args.attempt:
                        require(bool(promotions)==end['promoted'], 'Native/source promotion mismatch')
                        if end['promoted']:
                            require('promotion' in end['captures'] and 'PROMOTED' in end['captures']['promotion']['transition'], 'Displayed promotion missing')
                            require(any(s['state']['actors'][0]['frags']>0 and s['state']['actors'][0]['ladder']>0 for s in wire['samples']), 'Source kill/ladder effect missing')
                    report['cases'].append({'map':map_id,'resolution':resolution,'outcome':end,'localPromotions':promotions,'sourceConfigs':wire['configs'],'inputReceipts':len(wire['inputs']),'maxAppliedACK':max(s.get('ack',0) or 0 for s in wire['samples']),'cleanup':wire['cleanup']})
                    for name in ['wire.json','native.log']:
                        path = case/name
                        with gzip.open(str(path)+'.gz','wb') as out: out.write(path.read_bytes())
                        path.unlink()
                stop(xvfb)
        report['privateTempRemoved'] = True
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
