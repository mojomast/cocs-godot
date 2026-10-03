"""Exclusive, explicit-grant wrapper; one chapter per bounded invocation."""
import argparse
import fcntl
from pathlib import Path
import os
import signal
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--map', required=True, choices=['rootfall-verge','siltwake-crossing','emberline-ascent','crown-array'])
parser.add_argument('--granted', action='store_true')
parser.add_argument('--compact', action='store_true')
args = parser.parse_args()
if not args.granted: raise SystemExit('Explicit parent scenery grant required')
root = Path(__file__).resolve().parents[3]
with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as lock:
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    cmd = ['node','tools/godot-biomes/expansion/connected-journey.mjs',args.map,'--granted']
    if args.compact: cmd.append('--compact')
    child = subprocess.Popen(cmd,cwd=root,start_new_session=True)
    try:
        raise SystemExit(child.wait(timeout=1200))
    finally:
        if child.poll() is None:
            os.killpg(child.pid,signal.SIGKILL)
            child.wait()
