"""H-grant-only additional Vesper stages using canonical nonwaiting bounded exec."""
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
parser.add_argument('stage', choices=['representative', 'inspection', 'damage-numbers'] + ['hosted-'+mode for mode in ['deathmatch','teamdeathmatch','ctf','domination','koth','uplink']])
parser.add_argument('--granted', action='store_true', required=True)
parser.add_argument('--compact', action='store_true')
args = parser.parse_args()
plan = load_plan()
output = Path('/home/mojo/.tmp-on-disk/cocs-expansion-three-vesper-evidence-20261002/production-h') / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')+'-'+args.stage)
output.mkdir(parents=True)
report = preflight(plan)
(output/'preflight.json').write_text(json.dumps(report,indent=2)+'\n')
assert report['readyForExplicitGrant']
command = {'id':args.stage, 'timeoutSeconds':180, 'argv':['{godot}','--path','godot','--audio-driver','Dummy','--resolution','1280x800','--script','res://tests/new_maps/vesper_viaduct/inspection.gd','--'] + (['--representative'] if args.stage == 'representative' else [])}
if args.stage.startswith('hosted-'):
    unit = next(u for u in plan['units'] if u['id'] == 'vesper-viaduct')
    command = commands(plan,unit,args.stage)[0]
    if args.compact: command['argv'] += ['--compact']
if args.stage == 'damage-numbers':
    command = {'id':'damage-numbers','timeoutSeconds':30,'argv':['{godot}','--headless','--path','godot','--script','res://tests/protocol/damage_numbers.gd']}
# This checkout has no ambient display. The private Xvfb and all engine clients
# belong to execute()'s one bounded process group and are torn down together.
command['argv'] = ['xvfb-run','-a','-s','-screen 0 1280x800x24'] + command['argv']
with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as lock:
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    execute(command,plan,output)
print(output)
