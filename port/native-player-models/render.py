"""Owned private Xvfb capture. No shared display or host credentials inherited."""
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time
from verify import ROOT, OUT, DEFAULT, run

def main():
    evidence=OUT/'evidence'/('render-'+str(time.time_ns()))
    evidence.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix='player-model-render-',dir='/tmp/opencode') as temporary:
        stage=Path(temporary)
        env={'PATH':os.environ['PATH'],'HOME':str(stage),'LANG':'C.UTF-8','LIBGL_ALWAYS_SOFTWARE':'1'}
        for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
            env[key]=str(stage/key); Path(env[key]).mkdir()
        project=stage/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','content','*.uid'))
        read_fd,write_fd=os.pipe()
        with (evidence/'xvfb.log').open('w') as log:
            server=subprocess.Popen(['Xvfb','-displayfd',str(write_fd),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],env=env,pass_fds=[write_fd],stdout=log,stderr=subprocess.STDOUT)
            os.close(write_fd)
            try:
                if not select.select([read_fd],[],[],10)[0]: raise RuntimeError('Xvfb not ready')
                display=os.read(read_fd,64).decode().strip()
                if not display.isdigit(): raise RuntimeError('invalid Xvfb display')
                env['DISPLAY']=':'+display
                text=run([os.environ.get('GODOT_BIN',DEFAULT),'--audio-driver','Dummy','--path',project,'--resolution','1280x800','res://player_models/preview.tscn','--','--output='+str(evidence)],env,evidence/'capture.log',timeout=240)
                if 'PLAYER_MODEL_CAPTURE_OK' not in text: raise RuntimeError('capture completion absent')
            finally:
                os.close(read_fd)
                server.terminate()
                try: server.wait(timeout=5)
                except subprocess.TimeoutExpired: server.kill(); server.wait()
    print('PLAYER_MODEL_RENDER_OK '+str(evidence))
if __name__=='__main__': main()
