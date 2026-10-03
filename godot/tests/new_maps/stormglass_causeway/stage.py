"""Stormglass grant J: bounded serial stages under a nonwaiting local lock."""
import argparse
import datetime
import fcntl
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/asset-production'))
from run import load_plan, preflight, execute, commands

parser = argparse.ArgumentParser()
parser.add_argument('stage')
parser.add_argument('--granted', action='store_true', required=True)
parser.add_argument('--compact', action='store_true')
args = parser.parse_args()
plan = load_plan()
base = Path('/home/mojo/.tmp-on-disk/cocs-expansion-four-stormglass-evidence-20261002/production-j')
out = base / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')+'-'+args.stage)
out.mkdir(parents=True)
report = preflight(plan)
report['grantOverride'] = 'STORMGLASS-ASSET-PRODUCTION-20261003-J'
(out/'preflight.json').write_text(json.dumps(report,indent=2)+'\n')
assert report['readyForExplicitGrant'], report['missing']
unit = next(u for u in plan['units'] if u['id']=='stormglass-causeway')
if args.stage == 'encode':
    command = {'id':'encode','timeoutSeconds':180,'argv':['ffmpeg','-y','-threads','1','-f','concat','-safe','0','-i',str(base/'wide-cadence.ffconcat'),'-fps_mode','vfr','-c:v','libx264','-threads','1','-preset','fast','-crf','23','-pix_fmt','yuv420p',str(ROOT/'port/expansion-four/stormglass/evidence/production-j/ordinary-input.mp4')]}
elif args.stage in ['representative','inspection']:
    command = {'id':args.stage,'timeoutSeconds':240,'argv':['{godot}','--path','godot','--audio-driver','Dummy','--resolution','1280x800','--script','res://tests/new_maps/stormglass_causeway/inspection.gd','--']+(['--representative'] if args.stage=='representative' else [])}
else:
    command = commands(plan,unit,args.stage)[0]
if args.stage == 'hosted-puma-race':
    command['argv'] = ['node','godot/tests/new_maps/stormglass_causeway/hosted.mjs']
if args.stage in ['representative','inspection','hosted-puma-race']:
    command['argv'] = ['xvfb-run','-a','-s','-screen 0 1280x800x24'] + command['argv']
if args.compact: command['argv'] += ['--compact']
with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as lock:
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    execute(command,plan,out)
(out/'stage.json').write_text(json.dumps({'grant':report['grantOverride'],'stage':args.stage,'accepted':False,'commandCompleted':True})+'\n')
print(out)
