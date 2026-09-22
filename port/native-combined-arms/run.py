#!/usr/bin/env python3
"""Private display + copied project; normal-rate source server; bounded native acceptance."""
import hashlib, json, os, pathlib, selectors, shutil, subprocess, tempfile, uuid
ROOT = pathlib.Path(__file__).resolve().parents[2]
BIN = os.environ.get('GODOT_BIN', '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
DEPS = os.environ.get('GUEST_NODE_MODULES', '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules')
OUT = ROOT/'port/native-combined-arms/evidence'/str(uuid.uuid4())
OUT.mkdir(parents=True)
children = []
report = {'evidence': str(OUT), 'classification': 'live default-rate server; harness native physical key/mouse events; no human driving claim'}
def stop(p):
    if p.poll() is None:
        p.terminate()
        try: p.wait(8)
        except subprocess.TimeoutExpired: p.kill(); p.wait(5)
    try: os.kill(p.pid, 0)
    except ProcessLookupError: return
    raise AssertionError(f'owned PID remains: {p.pid}')
def run(args, name, env, timeout=90):
    with (OUT/(name+'.log')).open('w') as log:
        child=subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT, env=env)
        children.append(child)
        try: code=child.wait(timeout)
        finally: stop(child)
    text=(OUT/(name+'.log')).read_text()
    assert code == 0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text, name+' failed; inspect retained log'
    return text
def line(stream):
    with selectors.DefaultSelector() as sel:
        sel.register(stream, selectors.EVENT_READ)
        assert sel.select(10), 'startup timeout'
        return stream.readline().strip()
def hashes(root, directories):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for d in directories for p in sorted((root/d).rglob('*')) if p.is_file() and '.godot' not in p.parts}
try:
    assert subprocess.check_output([BIN,'--version'],text=True).strip() == '4.5.2.stable.official.6ce3de25a'
    with tempfile.TemporaryDirectory(prefix='combined-arms-', dir='/tmp/opencode') as tmp:
        temp=pathlib.Path(tmp)
        env={**os.environ,'HOME':tmp}
        for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
            env[key]=str(temp/key); (temp/key).mkdir()
        for d in ['godot','game','server']:
            shutil.copytree(ROOT/d,temp/d,ignore=shutil.ignore_patterns('.godot','node_modules'))
        (temp/'node_modules').symlink_to(DEPS, target_is_directory=True)
        before=hashes(temp,['game','server'])
        assert before == hashes(ROOT,['game','server']), 'copied source mismatch'
        run(['node',str(ROOT/'tools/godot-export/semantic.mjs'),str(temp/'godot/content/generated')], 'export', env)
        manifest={'base':'013ad65','sourceRoot':str(ROOT),'executedSourceRoot':tmp,'sourceHashes':before,'sceneHashes':hashes(temp,['godot/combined_arms','godot/tests/combined_arms','godot/content/generated'])}
        (OUT/'hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
        run([BIN,'--headless','--path',str(temp/'godot'),'--editor','--import'], 'import', env)
        for name in ['combined_arms/demo.gd','tests/combined_arms/observe.gd','tests/combined_arms/gallery.gd']:
            run([BIN,'--headless','--path',str(temp/'godot'),'--check-only','--script','res://'+name], 'parse-'+pathlib.Path(name).stem, env, 15)
        run([BIN,'--headless','--path',str(temp/'godot'),'--script','res://tests/combined_arms/test_controls.gd'], 'controls', env, 15)
        r,w=os.pipe()
        with (OUT/'xvfb.log').open('w') as log:
            xvfb=subprocess.Popen(['Xvfb','-displayfd',str(w),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],pass_fds=(w,),stdout=log,stderr=log)
            children.append(xvfb); os.close(w)
            with os.fdopen(r) as stream: display=line(stream)
            assert display.isdigit() and xvfb.poll() is None
            env['DISPLAY']=':'+display
            run([BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/combined_arms/gallery.gd','--','--evidence='+str(OUT)], 'gallery', env, 30)
            with (OUT/'server.log').open('w') as err:
                server=subprocess.Popen(['node',str(ROOT/'port/native-combined-arms/server.mjs'),tmp,str(OUT/'wire.json')],stdout=subprocess.PIPE,stderr=err,text=True,env=env)
                children.append(server)
                try:
                    endpoint=line(server.stdout)
                    assert endpoint.startswith('ENDPOINT '), endpoint
                    text=run([BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x800','--script','res://tests/combined_arms/observe.gd','--','--map=sunscar-convoy','--endpoint='+endpoint.split(' ',1)[1],'--evidence='+str(OUT)],'native',env,120)
                finally: stop(server)
            stop(xvfb)
        assert before == hashes(temp,['game','server']), 'source changed during execution'
        from validate import verify
        report['acceptance']=verify(text,json.loads((OUT/'wire.json').read_text()))
    report['privateTempRemoved']=not temp.exists()
    report['status']='PASS'
except Exception as exc:
    report['status']='FAIL'; report['error']=str(exc)
    raise
finally:
    for child in reversed(children): stop(child)
    report['ownedProcessesReaped']=True
    (OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
