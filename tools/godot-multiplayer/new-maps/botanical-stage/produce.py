"""Explicit serial U jobs. Never acquires a slot or runs at import time."""
import argparse
import shutil
import subprocess
import sys
from config import HERE, ROOT, DEST, MAPS, BLENDER, GODOT, entry, write, sha

def run(seconds,*args):
    subprocess.run([sys.executable,str(HERE/'grant.py'),'run',str(seconds),*map(str,args)],cwd=ROOT,check=True)

def produce(map_id,phase):
    author,_,_,_,_=entry(map_id)
    if phase=='build':
        if author.MASTER.exists() or author.EXPORT.exists():raise ValueError('Archive existing candidate outputs before a new build')
        run(1800,BLENDER,'-b','-t','1','--python-exit-code','1','--python',author.__file__,'--','build')
        run(900,BLENDER,'-b','-t','1','--python-exit-code','1','--python',HERE/'blender_proof.py','--',map_id)
        run(180,sys.executable,'-B',HERE/'prepare_stage.py','--map',map_id)
    elif phase=='native':
        # Import/parser errors are retained; no timeout is silently widened.
        run(900,GODOT,'--headless','--single-threaded-scene','--path','godot','--editor','--import','--quit')
        run(60,sys.executable,'-B',HERE/'pin_import.py',map_id)
        run(900,GODOT,'--headless','--single-threaded-scene','--path','godot','--editor','--import','--quit')
        for script,seconds in [('import',120),('physics',180)]:
            run(seconds,GODOT,'--headless','--path','godot','--script',f'res://tests/new_maps/botanical_stage/{script}.gd','--','--map='+map_id)
    elif phase=='capture':
        run(300,sys.executable,HERE/'owned_capture.py','xvfb-run','-a','-s','-screen 0 1280x720x24',GODOT,
            '--path','godot','--rendering-method','gl_compatibility','--script','res://tests/new_maps/botanical_stage/capture.gd','--','--map='+map_id)
    else:raise ValueError('Unknown production phase')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('map',choices=MAPS)
    parser.add_argument('phase',choices=['build','native','capture'])
    args=parser.parse_args();produce(args.map,args.phase)
