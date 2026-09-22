#!/usr/bin/env python3
"""Owned independent capture, maximum 180 seconds including preflight/cleanup."""
import hashlib
import json
import os
import pathlib
import selectors
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import uuid

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BIN = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
DEPS = '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules'
OUT = HERE / 'evidence' / str(uuid.uuid4())
OUT.mkdir(parents=True)
started = time.monotonic()
children = []
temp = None
endpoint = None
report = {'status':'FAIL', 'evidence':str(OUT), 'commands':[], 'base':'83e4aff',
          'deliveries':['1126a08','613dc92'], 'purpose':'Independent same-route receipt/application and 960x640/1280x800 review',
          'classification':'Harness-injected native physical key/mouse events; no human driving claim'}

def expired(_signum, _frame):
    raise TimeoutError('180 second independent run deadline')

def stop(p):
    if p.poll() is None:
        p.terminate()
        try: p.wait(5)
        except subprocess.TimeoutExpired: p.kill(); p.wait(3)
    try: os.kill(p.pid, 0)
    except ProcessLookupError: return
    raise AssertionError(f'owned PID remains: {p.pid}')

def spawn(args, **kwargs):
    report['commands'].append(args)
    p = subprocess.Popen(args, **kwargs)
    children.append(p)
    return p

def run(args, name, env, timeout=45):
    with (OUT/(name+'.log')).open('w') as log:
        p = spawn(args, stdout=log, stderr=subprocess.STDOUT, env=env)
        try: code = p.wait(timeout)
        finally: stop(p)
    text = (OUT/(name+'.log')).read_text()
    assert code == 0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text, name+' failed; retained log'
    return text

def line(stream):
    with selectors.DefaultSelector() as sel:
        sel.register(stream, selectors.EVENT_READ)
        assert sel.select(10), 'startup timeout'
        return stream.readline().strip()

def hashes(root, directories):
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()
            for d in directories for p in sorted((root/d).rglob('*'))
            if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts}

signal.signal(signal.SIGALRM, expired)
signal.alarm(165)  # Leaves cleanup inside the overall 180-second budget.
try:
    assert subprocess.check_output([BIN,'--version'],text=True).strip() == '4.5.2.stable.official.6ce3de25a'
    temp = pathlib.Path(tempfile.mkdtemp(prefix='ca-independent-',dir='/tmp/opencode'))
    report['temporaryRuntime'] = str(temp)
    env = {**os.environ,'HOME':str(temp),'PYTHONDONTWRITEBYTECODE':'1'}
    for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']:
        env[key]=str(temp/key); (temp/key).mkdir(mode=0o700)
    for d in ['godot','game','server']:
        shutil.copytree(ROOT/d,temp/d,ignore=shutil.ignore_patterns('.godot','node_modules'))
    (temp/'node_modules').symlink_to(DEPS,target_is_directory=True)
    before=hashes(ROOT,['game','server','godot'])
    assert before == hashes(temp,['game','server','godot'])
    # Add only the independent test entrypoint; delivered scripts remain identical.
    shutil.copyfile(HERE/'observe.gd',temp/'godot/tests/combined_arms/independent_observe.gd')
    run(['node',str(ROOT/'tools/godot-export/semantic.mjs'),str(temp/'godot/content/generated')],'export',env)
    manifest={'base':'83e4aff','deliveries':['1126a08','613dc92'],'sourceRoot':str(ROOT),
              'executedSourceRoot':str(temp),'godotBinary':BIN,
              'godotBinarySha256':hashlib.sha256(pathlib.Path(BIN).read_bytes()).hexdigest(),
              'checkoutHashes':before,'executingHashes':hashes(temp,['game','server','godot']),
              'reviewHarnessHashes':hashes(HERE,['.'])}
    # Avoid self-containing evidence paths in harness provenance.
    manifest['reviewHarnessHashes']={k:v for k,v in manifest['reviewHarnessHashes'].items() if not k.startswith('evidence/')}
    (OUT/'hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
    run([BIN,'--headless','--path',str(temp/'godot'),'--editor','--import'],'import',env)
    run([BIN,'--headless','--path',str(temp/'godot'),'--check-only','--script','res://tests/combined_arms/independent_observe.gd'],'parse-observer',env,15)
    controls=run([BIN,'--headless','--path',str(temp/'godot'),'--script','res://tests/combined_arms/test_controls.gd'],'controls',env,15)
    assert 'COMBINED_SYNTHETIC_CHECKS 43' in controls
    r,w=os.pipe()
    with (OUT/'xvfb.log').open('w') as log:
        xvfb=spawn(['Xvfb','-displayfd',str(w),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],pass_fds=(w,),stdout=log,stderr=log,env=env)
        os.close(w)
        with os.fdopen(r) as stream: display=line(stream)
        assert display.isdigit() and xvfb.poll() is None
        env['DISPLAY']=':'+display
        report['display']=env['DISPLAY']
        run([BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/combined_arms/gallery.gd','--','--evidence='+str(OUT)],'gallery',env,25)
        with (OUT/'server.log').open('w') as err:
            server=spawn(['node',str(HERE/'server.mjs'),str(temp),str(OUT/'wire.json')],stdout=subprocess.PIPE,stderr=err,text=True,env=env)
            try:
                banner=line(server.stdout)
                assert banner.startswith('ENDPOINT ws://127.0.0.1:'), banner
                endpoint=banner.split(' ',1)[1]
                report['endpoint']=endpoint
                text=run([BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x800','--script','res://tests/combined_arms/independent_observe.gd','--','--map=sunscar-convoy','--endpoint='+endpoint,'--evidence='+str(OUT)],'native',env,118)
            finally: stop(server)
        stop(xvfb)
    after=hashes(temp,['game','server','godot'])
    assert all(after[k]==v for k,v in before.items()), 'delivered runtime/source changed'
    assert before == hashes(ROOT,['game','server','godot']), 'checkout runtime/source changed'
    report['unchangedRuntimeAndSource']=True
    sys.path.insert(0,str(ROOT/'port/native-combined-arms'))
    from validate import verify
    report['acceptance']=verify(text,json.loads((OUT/'wire.json').read_text()))
    run([sys.executable,'-B','-m','unittest','discover','-s',str(ROOT/'port/native-combined-arms'),'-p','test_validate.py','-v'],'replay-tests',{**env,'COMBINED_EVIDENCE':str(OUT)},15)
    report['status']='PASS'
except Exception as exc:
    report['error']=str(exc)
    raise
finally:
    signal.alarm(0)
    for child in reversed(children): stop(child)
    report['ownedProcesses']=[{'pid':p.pid,'returncode':p.returncode} for p in children]
    report['ownedProcessesReaped']=True
    if endpoint:
        with socket.socket() as probe:
            probe.settimeout(1)
            report['authorityPortClosed']=probe.connect_ex(('127.0.0.1',int(endpoint.rsplit(':',1)[1]))) != 0
    if temp: shutil.rmtree(temp)
    report['privateTempRemoved']=temp is None or not temp.exists()
    report['totalWallSeconds']=time.monotonic()-started
    (OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
