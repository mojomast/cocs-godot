#!/usr/bin/env python3
"""Human launcher on explicitly chosen DISPLAY; native commands, no route automation."""
import argparse, os, pathlib, selectors, shutil, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--map',default='sunscar-convoy',choices=['sunscar-convoy'])
p.add_argument('--endpoint',help='Explicit approved server; default is owned ephemeral loopback')
p.add_argument('--seconds',type=int,default=120,choices=range(10,121),metavar='10..120')
a=p.parse_args()
binary=os.environ.get('GODOT_BIN','/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
deps=os.environ.get('GUEST_NODE_MODULES','/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules')
assert subprocess.check_output([binary,'--version'],text=True).strip()=='4.5.2.stable.official.6ce3de25a'
children=[]
def stop(child):
    if child.poll() is None:
        child.terminate()
        try: child.wait(8)
        except subprocess.TimeoutExpired: child.kill(); child.wait(5)
    try: os.kill(child.pid,0)
    except ProcessLookupError: return
    raise RuntimeError('Owned PID not reaped')
with tempfile.TemporaryDirectory(prefix='combined-arms-play-',dir='/tmp/opencode') as tmp:
    t=pathlib.Path(tmp); env={**os.environ}
    for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
        env[key]=str(t/key); (t/key).mkdir()
    try:
        for name in ['godot','game','server']:
            shutil.copytree(ROOT/name,t/name,ignore=shutil.ignore_patterns('.godot','node_modules'))
        (t/'node_modules').symlink_to(deps,target_is_directory=True)
        subprocess.run(['node',str(ROOT/'tools/godot-export/semantic.mjs'),str(t/'godot/content/generated')],env=env,check=True,timeout=90)
        subprocess.run([binary,'--headless','--path',str(t/'godot'),'--editor','--import'],env=env,check=True,timeout=90)
        endpoint=a.endpoint
        if not endpoint:
            server=subprocess.Popen(['node',str(ROOT/'port/native-combined-arms/server.mjs'),tmp,str(t/'discarded-wire.json')],stdout=subprocess.PIPE,text=True,env=env)
            children.append(server)
            with selectors.DefaultSelector() as sel:
                sel.register(server.stdout,selectors.EVENT_READ)
                assert sel.select(10),'server startup timeout'
                line=server.stdout.readline().strip()
                assert line.startswith('ENDPOINT '),line
                endpoint=line.split(' ',1)[1]
        game=subprocess.Popen([binary,'--path',str(t/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','res://combined_arms/demo.tscn','--','--map='+a.map,'--endpoint='+endpoint],env=env)
        children.append(game)
        try:
            code=game.wait(a.seconds)
            if code: raise RuntimeError(f'Native exited {code}')
        except subprocess.TimeoutExpired: print('Bounded human session ended.')
    finally:
        for child in reversed(children): stop(child)
