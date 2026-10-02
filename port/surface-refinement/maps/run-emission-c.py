"""Five serial native checks explicitly authorized by Parallax grant C extension."""
import argparse
from pathlib import Path
import subprocess

p=argparse.ArgumentParser()
p.add_argument('--slot-granted',action='store_true')
p.add_argument('--out',type=Path,required=True)
a=p.parse_args()
if not a.slot_granted: raise SystemExit('Explicit heavy grant required')
root=Path(__file__).resolve().parents[3]
out=a.out.resolve()
out.mkdir(parents=True,exist_ok=False)
before=out/'gravemill-foundry-before-emission.json'
before.write_bytes(subprocess.check_output(['git','show','bb02e34b:godot/multiplayer_worlds/dressing/profiles/gravemill-foundry.json'],cwd=root))
(out/'LABELS.txt').write_text('flat = source imported materials\nrejected = pre-emission-fix REFINED bb02e34b profile (not old purple profile)\nrefined = 95c86892 source-emission exclusion\n')
godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
cases=[
 ('cooling-lights','refinement','gravemill-foundry','-84,13.65,13.24','-84,14.3,17.64'),
 ('furnace-sight-glass','refinement','gravemill-foundry','80,1.65,-18.8','80,6,-10.3'),
 ('assay-status-lamp','refinement','gravemill-foundry','66,13.65,45.24','66,19,41.24'),
 ('foundry-emission-lifecycle','proof','gravemill-foundry','-84,13.65,13.24','-84,14.3,17.64'),
 ('helix-exclusion-font-regression','proof','helix-conservatory','-46.671552,9.65,1.629806','-50,11,-8')]
for name,script,world,camera,target in cases:
 command=['python3',str(root/'tools/fighting/animation/run_owned.py'),'--log',str(out/(name+'.log')),'--timeout','180','--',
          'xvfb-run','-a',godot,'--rendering-method','gl_compatibility','--single-threaded-scene','--audio-driver','Dummy',
          '--path',str(root/'godot'),'--resolution','1280x800','--script',f'res://tests/map_finish/{script}.gd','--',
          '--map='+world,'--proof-dir='+str(out/name),'--camera='+camera,'--target='+target,'--clock=12']
 if script=='refinement':command.append('--rejected-profile='+str(before))
 subprocess.run(command,cwd=root,check=True)
