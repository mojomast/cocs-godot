"""Normal-rate live candidate observer with private server/display/project."""
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time
import urllib.request
from verify import ROOT, OUT, DEFAULT, run

PRIMARY=Path('/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port')

def reap(process):
    if process is None: return
    process.terminate()
    try: process.wait(timeout=8)
    except subprocess.TimeoutExpired: process.kill(); process.wait()

def main():
    evidence=OUT/'evidence'/('live-'+str(time.time_ns())); evidence.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix='player-model-live-',dir='/tmp/opencode') as temporary:
        stage=Path(temporary)
        env={'PATH':os.environ['PATH'],'HOME':str(stage),'LANG':'C.UTF-8','LIBGL_ALWAYS_SOFTWARE':'1'}
        for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
            env[key]=str(stage/key); Path(env[key]).mkdir()
        project=stage/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','content','*.uid'))
        p=project/'world/presentation.gd'; p.write_text(p.read_text().replace('res://world/actor_visual.gd','res://player_models/candidate.gd'))
        run(['node',ROOT/'tools/godot-export/semantic.mjs',project/'content/generated'],env,evidence/'semantic.log')
        binary=os.environ.get('GODOT_BIN',DEFAULT)
        run([binary,'--headless','--path',project,'--editor','--import'],env,evidence/'import.log')
        for directory in ['server','game']:
            shutil.copytree(ROOT/directory,stage/directory)
        shutil.copy2(ROOT/'package.json',stage/'package.json')
        (stage/'node_modules').symlink_to(PRIMARY/'node_modules',target_is_directory=True)
        runner=stage/'port/native-player-models/server.mjs'; runner.parent.mkdir(parents=True)
        shutil.copy2(OUT/'server.mjs',runner)
        server=None; xvfb=None; read_fd=None
        with (evidence/'server.log').open('w') as server_log,(evidence/'xvfb.log').open('w') as display_log:
            try:
                ready=stage/'server-ready.json'
                server=subprocess.Popen(['node',str(runner),str(ready)],cwd=stage,env=env,stdout=server_log,stderr=subprocess.STDOUT)
                deadline=time.monotonic()+10
                while not ready.exists():
                    if server.poll() is not None or time.monotonic()>deadline: raise RuntimeError('owned authority failed readiness; see server.log')
                    time.sleep(.05)
                port=json.loads(ready.read_text())['port']
                with urllib.request.urlopen(f'http://127.0.0.1:{port}',timeout=5) as response:
                    if response.status!=200: raise RuntimeError('health failed')
                read_fd,write_fd=os.pipe()
                xvfb=subprocess.Popen(['Xvfb','-displayfd',str(write_fd),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],env=env,pass_fds=[write_fd],stdout=display_log,stderr=subprocess.STDOUT)
                os.close(write_fd)
                if not select.select([read_fd],[],[],10)[0]: raise RuntimeError('Xvfb readiness failed')
                env['DISPLAY']=':'+os.read(read_fd,64).decode().strip()
                text=run([binary,'--audio-driver','Dummy','--path',project,'--resolution','1280x800','--script','res://tests/player_models/live.gd','--',f'--endpoint=ws://127.0.0.1:{port}','--map=meridian-exchange','--mode=teamdeathmatch','--mute','--output='+str(evidence)],env,evidence/'live.log',timeout=100)
                if 'PLAYER_MODEL_LIVE_RESULT' not in text: raise RuntimeError('missing live completion')
            finally:
                reap(server); reap(xvfb)
                if read_fd is not None: os.close(read_fd)
                (evidence/'cleanup.json').write_text(json.dumps({'authority_exit':None if server is None else server.returncode,'xvfb_exit':None if xvfb is None else xvfb.returncode}))
    print('PLAYER_MODEL_LIVE_OK '+str(evidence))
if __name__=='__main__': main()
