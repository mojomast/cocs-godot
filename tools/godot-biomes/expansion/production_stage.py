"""Scenery grant F narrow custom-stage wrapper; shares nonwaiting queue lock."""
import argparse
import datetime
import fcntl
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/asset-production'))
from run import execute, load_plan

parser = argparse.ArgumentParser()
parser.add_argument('--granted', action='store_true')
parser.add_argument('--name', required=True)
parser.add_argument('--timeout', type=int, default=180)
parser.add_argument('command', nargs=argparse.REMAINDER)
args = parser.parse_args()
assert args.granted and 0 < args.timeout <= 1800
command = args.command[1:] if args.command[0] == '--' else args.command
output = ROOT / 'port/expansion-four/scenery/production-f' / datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
output.mkdir(parents=True)
with open('/tmp/opencode/cocs-finish-acceptance.lock', 'a') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    execute({'id': args.name, 'argv': command, 'timeoutSeconds': args.timeout}, load_plan(), output)
print(output)
