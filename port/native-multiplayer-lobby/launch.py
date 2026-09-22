"""Launch the opt-in lobby against an explicit existing authority; owns no server."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--endpoint', required=True, help='ws:// or wss:// authority address')
parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
parser.add_argument('--headless', action='store_true', help='Startup probe only, not playable acceptance')
parser.add_argument('--quit-after', type=int, default=0, help='Optional bounded startup probe frames')
args = parser.parse_args()
if not args.endpoint.startswith(('ws://','wss://')) or '@' in args.endpoint:
    parser.error('Use an explicit WebSocket endpoint without embedded credentials')
command=[args.godot,'--path',str(ROOT/'godot')]
if args.headless: command += ['--headless']
if args.quit_after: command += ['--quit-after',str(args.quit_after)]
command += ['res://world/session.tscn','--','--lobby-menu','--endpoint='+args.endpoint]
raise SystemExit(subprocess.call(command))
