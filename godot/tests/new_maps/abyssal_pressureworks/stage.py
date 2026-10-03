"""Grant I stages; canonical bounded executor and nonwaiting local lock."""
import argparse
import datetime
import fcntl
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/asset-production'))
from run import load_plan, preflight, execute, commands

parser = argparse.ArgumentParser()
parser.add_argument('stage', choices=['representative', 'inspection', 'collision', 'encode'] + ['hosted-'+m for m in ['deathmatch','teamdeathmatch','ctf','koth','domination','holdout']])
parser.add_argument('--granted', action='store_true', required=True)
parser.add_argument('--compact', action='store_true')
args = parser.parse_args()
plan = load_plan()
out = Path('/home/mojo/.tmp-on-disk/cocs-expansion-three-abyssal-evidence-20261002/production-i') / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')+'-'+args.stage)
out.mkdir(parents=True)
report = preflight(plan)
report['grantOverride'] = 'ABYSSAL-ASSET-PRODUCTION-20261003-I'
report['dynamicNativeInputs'] = {path: hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in [
    'tools/asset-production/candidate-hosted.mjs', 'tools/asset-production/candidate-admission.mjs',
    'tools/asset-production/candidate-guidance.mjs', 'port/multiplayer-worlds/derived/core.mjs',
    'port/multiplayer-worlds/wall_candidates.mjs', 'godot/multiplayer_worlds/demo.gd',
    'godot/multiplayer_worlds/map.gd', 'godot/multiplayer_worlds/abyssal_presentation.gd',
    'godot/tests/new_maps/abyssal_pressureworks/hosted.gd',
    'godot/tests/new_maps/abyssal_pressureworks/inspection.gd',
    'godot/tests/asset_production/hosted.gd', 'godot/tests/asset_production/candidate_catalog.gd']}
(out/'preflight.json').write_text(json.dumps(report,indent=2)+'\n')
assert report['readyForExplicitGrant']
command = {'id':args.stage,'timeoutSeconds':240,'argv':['{godot}','--path','godot','--audio-driver','Dummy','--resolution','1280x800','--script','res://tests/new_maps/abyssal_pressureworks/inspection.gd','--']+(['--representative'] if args.stage=='representative' else [])}
if args.stage == 'collision':
    command = {'id':'collision','timeoutSeconds':180,'argv':['{godot}','--headless','--path','godot','--script','res://tests/new_maps/abyssal_pressureworks/collision.gd']}
elif args.stage.startswith('hosted-'):
    command = commands(plan,next(u for u in plan['units'] if u['id']=='abyssal-pressureworks'),args.stage)[0]
    if args.compact: command['argv'] += ['--compact']
if args.stage == 'encode':
    command = {'id':'encode','timeoutSeconds':180,'argv':['ffmpeg','-y','-threads','1','-f','concat','-safe','0','-i',str(out.parent/'ctf-cadence.ffconcat'),'-fps_mode','vfr','-c:v','libx264','-threads','1','-preset','fast','-crf','23','-pix_fmt','yuv420p',str(ROOT/'port/expansion-three/abyssal/evidence/production-i/ctf/ordinary-input.mp4')]}
if args.stage not in ['collision','encode']: command['argv'] = ['xvfb-run','-a','-s','-screen 0 1280x800x24'] + command['argv']
with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as lock:
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    execute(command,plan,out)
(out/'stage.json').write_text(json.dumps({'grant':'ABYSSAL-ASSET-PRODUCTION-20261003-I','stage':args.stage,'accepted':False,'commandCompleted':True})+'\n')
print(out)
