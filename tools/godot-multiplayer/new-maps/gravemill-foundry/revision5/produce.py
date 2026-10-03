"""Serial S-grant requests; stop at the first failed bounded stage."""
from pathlib import Path
import subprocess
import sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
BLENDER='/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender'
GODOT='/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64'
def run(seconds,*args):subprocess.run([sys.executable,str(HERE/'grant.py'),'run',str(seconds),*map(str,args)],cwd=ROOT,check=True)
if sys.argv[1]=='build':
 run(60,sys.executable,HERE/'archive.py')
 run(60,sys.executable,HERE/'shapes.py')
 run(60,'node',HERE/'build.mjs')
 run(900,BLENDER,'-b','-t','1','--python-exit-code','1','--python',HERE/'author.py')
 run(120,sys.executable,HERE/'verify.py')
 run(120,'node',HERE/'check.mjs')
 run(60,sys.executable,HERE/'prepare_stage.py')
 run(120,BLENDER,'-b','-t','1','--python-exit-code','1','--python',HERE/'reopen.py')
 run(600,GODOT,'--headless','--path','godot','--editor','--import','--quit')
 run(150,GODOT,'--headless','--path','godot','--script','res://tests/new_maps/gravemill_foundry/revision5/physics.gd')
else:raise ValueError('Unknown production phase')
