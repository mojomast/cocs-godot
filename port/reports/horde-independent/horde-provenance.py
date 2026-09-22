#!/usr/bin/env python3
"""Read-only provenance and post-run endpoint/PID checks; outputs owned report."""
import hashlib
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
source = '51289b79c627a26a381ba556b92bab71f93f3732'
runtime = '809ef2697463f1665f335f8602e71ecdc6d6b55a'
paths = git('ls-tree', '-r', '--name-only', runtime).splitlines()
selected = [p for p in paths if p.startswith(('game/', 'server/', 'godot/horde/', 'godot/world/', 'godot/net/', 'godot/ui/')) and p.endswith(('.mjs', '.gd', '.tscn'))]
selected += [p for p in paths if p.startswith('port/native-horde/') and p.endswith(('.mjs', '.py'))]
selected += ['package.json', 'package-lock.json', 'port/contracts/source-lock.json']
hashes = {p: sha(ROOT / p) for p in sorted(selected)}
checks = []
pngs = {}
for directory in sorted((OUT / 'evidence').iterdir()):
    launch = json.loads((directory / 'launch.json').read_text())
    summary = json.loads((directory / 'summary.json').read_text())
    endpoint = next(s.split('=', 1)[1] for s in launch['argv'] if s.startswith('--endpoint='))
    parsed = urlparse(endpoint)
    with socket.socket() as s:
        s.settimeout(1)
        closed = s.connect_ex((parsed.hostname, parsed.port)) != 0
    pids = []
    for child in summary['cleanup']:
        try:
            os.kill(child['pid'], 0)
            absent = False
        except ProcessLookupError:
            absent = True
        pids.append(dict(pid=child['pid'], absent=absent))
    checks.append(dict(id=directory.name, endpoint=endpoint, portClosed=closed, pids=pids))
    for png in directory.glob('*.png'):
        data = png.read_bytes()
        width, height = struct.unpack('>II', data[16:24])
        pngs[str(png.relative_to(ROOT))] = dict(sha256=sha(png), width=width, height=height)
engine = Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
report = dict(baseline=git('rev-parse', '5445295'), delivery=git('rev-parse', '94690b6'), runtimeCherryPick=runtime,
              lockedSource=source, trees={p:git('rev-parse', f'{runtime}:{p}') for p in ('game','server','godot','port/native-horde')},
              sourceDiffEmpty=not git('diff', source, '--', 'game', 'server', 'assets', 'public', 'package.json', 'package-lock.json'),
              deliveryFilesDiffEmpty=not git('diff', runtime, '--', 'godot/horde', 'godot/tests/horde', 'port/native-horde'),
              engine=str(engine), engineSha256=sha(engine), node=subprocess.check_output(['node','--version'],text=True).strip(),
              ws=json.loads((ROOT/'node_modules/ws/package.json').read_text())['version'], runtimeSHA256=hashes,
              helperSHA256={str(p.relative_to(ROOT)):sha(p) for p in sorted(OUT.glob('horde-*')) if p.is_file()},
              generatedSHA256={str(p.relative_to(ROOT)):sha(p) for p in sorted((ROOT/'godot/content/generated').rglob('*')) if p.is_file()},
              cleanup=checks, pngs=pngs)
(OUT/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
assert report['sourceDiffEmpty'] and report['deliveryFilesDiffEmpty']
assert all(c['portClosed'] and all(p['absent'] for p in c['pids']) for c in checks)
print(json.dumps(dict(sourceUnchanged=True, deliveryUnchanged=True, endpointsClosed=len(checks), pngs=len(pngs), engineSha256=report['engineSha256'])))
