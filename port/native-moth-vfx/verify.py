#!/usr/bin/env python3
"""Owned private staging only; pinned Godot, isolated XDG and private Xvfb."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
EVIDENCE = ROOT / 'port/native-moth-vfx/evidence'
EVIDENCE.mkdir(exist_ok=True)
subprocess.run(['node', 'port/native-moth-vfx/export-fixtures.mjs'],cwd=ROOT,check=True)
with tempfile.TemporaryDirectory(prefix='moth-vfx-',dir='/tmp/opencode') as temp:
    stage=Path(temp)
    project=stage/'project'
    project.mkdir()
    shutil.copytree(ROOT/'godot/graphics_fx',project/'graphics_fx')
    shutil.copytree(ROOT/'godot/tests/graphics_fx',project/'tests/graphics_fx')
    (project/'project.godot').write_text('''config_version=5
[application]
config/name="Moth VFX fixture"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
environment/defaults/default_clear_color=Color(0.045,0.065,0.09,1)
''')
    env=os.environ.copy()
    for var, name in [('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('XDG_RUNTIME_DIR','runtime'),('HOME','home')]:
        directory=stage/name
        directory.mkdir(mode=0o700)
        env[var]=str(directory)
    env.update(MOTH_VFX_EVIDENCE=str(EVIDENCE),GODOT_SILENCE_ROOT_WARNING='1',LIBGL_ALWAYS_SOFTWARE='1')
    def run(args,log):
        result=subprocess.run([str(GODOT),'--path',str(project),'--audio-driver','Dummy',*args],env=env,capture_output=True,text=True,timeout=90)
        text=result.stdout+result.stderr
        (EVIDENCE/log).write_text(text)
        print(text)
        if result.returncode or 'SCRIPT ERROR' in text or '\nERROR:' in text: raise RuntimeError(log)
    run(['--headless','--script','res://tests/graphics_fx/regression.gd'],'regression.log')
    read_fd,write_fd=os.pipe()
    xvfb_log=(EVIDENCE/'xvfb.log').open('w')
    xvfb=subprocess.Popen(['Xvfb','-displayfd',str(write_fd),'-screen','0','1600x1000x24','-nolisten','tcp','-nolisten','unix'],pass_fds=(write_fd,),stdout=xvfb_log,stderr=subprocess.STDOUT,env=env)
    os.close(write_fd)
    try:
        with os.fdopen(read_fd) as pipe: display=pipe.readline().strip()
        if not display: raise RuntimeError('Private Xvfb failed')
        env['DISPLAY']=':'+display
        for size in ['1280x720','960x540']:
            run(['--rendering-method','gl_compatibility','--resolution',size,'--script','res://tests/graphics_fx/visual.gd'],f'visual-{size}.log')
    finally:
        xvfb.terminate()
        xvfb.wait(timeout=10)
        xvfb_log.close()
print('MOTH_VFX_VERIFY_OK (fixture rendering, not live gameplay)')
