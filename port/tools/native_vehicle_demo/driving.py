#!/usr/bin/env python3
"""Private copied project, owned Xvfb, normal-rate server; no primary writes."""
import json, math, os, pathlib, selectors, shutil, subprocess, tempfile, time, uuid
ROOT = pathlib.Path(__file__).resolve().parents[3]
BIN = os.environ.get('GODOT_BIN', '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
DEPS = pathlib.Path(os.environ.get('GUEST_NODE_MODULES', '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules'))
OUT = ROOT/'port/native-puma-driving/evidence'/str(uuid.uuid4())
OUT.mkdir(parents=True)
report = {'cases': [], 'evidence': str(OUT), 'classification': 'real normal-rate server; injected native physical key events; focus notifications synthetic'}
children = []
def stop(p):
    if p is None: return
    if p.poll() is None:
        p.terminate()
        try: p.wait(5)
        except subprocess.TimeoutExpired: p.kill(); p.wait(5)
    try: os.kill(p.pid, 0)
    except ProcessLookupError: return
    raise AssertionError(f'owned PID remains: {p.pid}')
def run(args, name, env, timeout=60):
    with (OUT/(name+'.log')).open('w') as log:
        p = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT, env=env)
        children.append(p)
        try: code=p.wait(timeout)
        finally: stop(p)
    text=(OUT/(name+'.log')).read_text()
    assert code==0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text, f'{name} failed; inspect log'
    return text
def endpoint(p):
    sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ)
    try:
        assert sel.select(10), 'server startup timeout'
        line=p.stdout.readline().strip()
        assert line.startswith('ENDPOINT '), line
        return line.split(' ',1)[1]
    finally: sel.close()
from validate_driving import verify
try:
    assert subprocess.check_output([BIN,'--version'],text=True).strip()=='4.5.2.stable.official.6ce3de25a'
    with tempfile.TemporaryDirectory(prefix='puma-driving-') as tmp:
        temp=pathlib.Path(tmp)
        env={**os.environ,'HOME':tmp}
        for key in ['XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME']:
            env[key]=str(temp/key); (temp/key).mkdir()
        for directory in ['godot','game','server']:
            shutil.copytree(ROOT/directory,temp/directory,ignore=shutil.ignore_patterns('.godot','node_modules'))
        (temp/'node_modules').symlink_to(DEPS,target_is_directory=True)
        run(['node',str(ROOT/'tools/godot-export/semantic.mjs'),str(temp/'godot/content/generated')],'export',env)
        run([BIN,'--headless','--path',str(temp/'godot'),'--editor','--import'],'import',env)
        run([BIN,'--headless','--path',str(temp/'godot'),'--script','res://tests/sports/test_controls.gd'],'controls',env)
        run([BIN,'--headless','--path',str(temp/'godot'),'--script','res://tests/vehicles/test_puma.gd'],'vehicles',env)
        readfd,writefd=os.pipe()
        with (OUT/'xvfb.log').open('w') as xlog:
            # Use Linux abstract X sockets; the shared pathname socket directory
            # can be unwritable. Never change permissions on the shared directory.
            xvfb=subprocess.Popen(['Xvfb','-displayfd',str(writefd),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],pass_fds=(writefd,),stdout=xlog,stderr=xlog)
            children.append(xvfb);os.close(writefd)
            sel=selectors.DefaultSelector();sel.register(readfd,selectors.EVENT_READ)
            assert sel.select(10), 'Xvfb startup timeout'
            display=os.read(readfd,100).decode().strip();os.close(readfd);sel.close()
            assert display.isdigit() and xvfb.poll() is None, 'private Xvfb did not provide a live display'
            env['DISPLAY']=':'+display
            for map_id in ['ion-speedway','aurora-stadium']:
                wirepath=OUT/(map_id+'-wire.json')
                with (OUT/(map_id+'-server.log')).open('w') as err:
                    server=subprocess.Popen(['node',str(ROOT/'port/tools/native_vehicle_demo/server.mjs'),tmp,str(wirepath)],stdout=subprocess.PIPE,stderr=err,text=True,env=env)
                    children.append(server)
                    try:
                        url=endpoint(server)
                        text=run([BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x800','--script','res://tests/sports/observe.gd','--','--map='+map_id,'--endpoint='+url,'--sports-capture='+str(OUT/(map_id+'.png'))],map_id,env,60)
                    finally: stop(server)
                report['cases'].append(verify(map_id,text,json.loads(wirepath.read_text())))
            stop(xvfb)
    report['privateTempRemoved']=not temp.exists()
    report['status']='PASS'
except Exception as exc:
    report['status']='FAIL';report['error']=str(exc)
    raise
finally:
    for child in reversed(children): stop(child)
    report['ownedProcessesReaped']=True
    (OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
