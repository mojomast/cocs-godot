#!/usr/bin/env python3
"""Private source copy; no changes to lead-owned composition or game modules."""
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
GODOT='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
WS=Path('/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules/ws')
OUT=ROOT/'port/native-moth-vfx/evidence'
with tempfile.TemporaryDirectory(prefix='moth-live-',dir='/tmp/opencode') as temp:
    stage=Path(temp)
    for directory in ['godot','game','port/native-horde']:
        shutil.copytree(ROOT/directory,stage/directory,ignore=shutil.ignore_patterns('.godot'))
    (stage/'port/native-moth-vfx').mkdir()
    shutil.copy2(ROOT/'port/native-moth-vfx/live-authority.mjs',stage/'port/native-moth-vfx/live-authority.mjs')
    shutil.copytree(WS,stage/'node_modules/ws')
    subprocess.run(['node',str(ROOT/'tools/godot-export/semantic.mjs'),str(stage/'godot/content/generated')],cwd=ROOT,check=True)
    env=os.environ.copy()
    for variable in ['HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_DATA_HOME','XDG_RUNTIME_DIR']:
        directory=stage/variable
        directory.mkdir(mode=0o700)
        env[variable]=str(directory)
    env.update(MOTH_VFX_EVIDENCE=str(OUT),LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    def godot(args,name,timeout=90):
        result=subprocess.run([GODOT,'--path',str(stage/'godot'),'--audio-driver','Dummy',*args],env=env,capture_output=True,text=True,timeout=timeout)
        text=result.stdout+result.stderr
        (OUT/name).write_text(text)
        print(text[-3500:])
        if result.returncode or 'SCRIPT ERROR' in text or '\nERROR:' in text: raise RuntimeError(name)
    godot(['--headless','--editor','--import'],'live-import.log')
    r,w=os.pipe()
    with (OUT/'live-xvfb.log').open('w') as display_log:
        xvfb=subprocess.Popen(['Xvfb','-displayfd',str(w),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],pass_fds=(w,),stdout=display_log,stderr=subprocess.STDOUT,env=env)
        os.close(w)
        authority=None
        try:
            with os.fdopen(r) as pipe: display=pipe.readline().strip()
            env['DISPLAY']=':'+display
            authority=subprocess.Popen(['node','port/native-moth-vfx/live-authority.mjs'],cwd=stage,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            ready=authority.stdout.readline().strip()
            assert ready.startswith('MOTH_AUTHORITY_READY '),ready
            port=ready.split()[-1]
            godot(['--max-fps','60','--script','res://tests/graphics_fx/live.gd','--',f'--endpoint=ws://127.0.0.1:{port}','--map=meridian-exchange','--mute'],'live-native.log')
        finally:
            if authority:
                authority.terminate()
                stdout,stderr=authority.communicate(timeout=15)
                (OUT/'live-authority.log').write_text(stdout+stderr)
            xvfb.terminate()
            xvfb.wait(timeout=10)
client=json.loads((OUT/'live-client.json').read_text())
authority=json.loads((OUT/'live-authority.json').read_text())
assert client['ok'] and authority['closed']
source={event['id']:event for event in authority['events']}
def equivalent(a,b):
    # Godot's JSON text formatter rounds doubles; event IDs remain exact.
    if isinstance(a,dict): return isinstance(b,dict) and a.keys()==b.keys() and all(equivalent(a[k],b[k]) for k in a)
    if isinstance(a,list): return isinstance(b,list) and len(a)==len(b) and all(equivalent(x,y) for x,y in zip(a,b))
    if isinstance(a,(int,float)) and not isinstance(a,bool): return isinstance(b,(int,float)) and not isinstance(b,bool) and math.isclose(a,b,rel_tol=1e-12,abs_tol=1e-12)
    return a==b
for row in client['events']:
    assert row['id']==source[row['id']]['id']
    assert equivalent(row['event'],source[row['id']])
    if row['type']=='explosion':
        p=row['event']['pos']
        assert all(abs(a-b)<0.0001 for a,b in zip(row['positions'][0],[p['x'],p['y'],p['z']]))
assert authority['lastTime']-authority['firstTime'] <= client['wall_ms']/1000 + 2
summary={'status':'PASS','normal_rate':True,'state_injection':False,'correlated_events':len(client['events']),
         'spawned':client['spawned'],'snapshots':client['snapshots'],'steps':authority['steps'],
         'source_seconds':authority['lastTime']-authority['firstTime'],'play_wall_seconds':client['wall_ms']/1000,
         'authority_closed':authority['closed'],'private_staging_removed':True}
(OUT/'live-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary))
