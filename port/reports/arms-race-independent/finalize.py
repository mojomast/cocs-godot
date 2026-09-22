#!/usr/bin/env python3
"""Read-only runtime/cleanup verification; write only this report's manifests."""
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

checks = {'base':'54452957353bcaf72fe467739a1ce2dfcd6dc69a',
          'delivery':['52de3b9216ac2837344015cd55e5527cf7b260d7','21fbd93ded3e92228f882b1d582a3c1623943393'],
          'testedHEAD':'e7602fb2bd96f9e73f6c05b1bbb170be35df4dd9','runs':[]}
for summary_path in sorted((HERE/'evidence').glob('*/summary.json')):
    s = json.loads(summary_path.read_text())
    require(not Path(s['privateTemp']).exists(), 'Private temp remains')
    for child in s['processes']:
        try:
            os.kill(child['pid'], 0)
        except ProcessLookupError:
            pass
        else:
            raise RuntimeError('Owned PID remains/reused: '+str(child['pid']))
    for endpoint in s.get('listenerCleanup',[]):
        with socket.socket() as probe:
            probe.settimeout(1)
            require(probe.connect_ex(('127.0.0.1',int(endpoint['endpoint'].rsplit(':',1)[1]))) != 0,'Authority listener remains')
    hashes = json.loads((summary_path.parent/'hashes.json').read_text())
    matched = 0
    for name, value in hashes.items():
        if name.startswith(('game/','server/','godot/')):
            require(sha(ROOT/name) == value, 'Tested runtime changed: '+name)
            matched += 1
    checks['runs'].append({'id':summary_path.parent.name,'status':s['status'],
        'runtimeHashesMatched':matched,'ownedPIDsAbsent':len(s['processes']),
        'listenerCountClosed':len(s.get('listenerCleanup',[])),'privateTempAbsent':True})

protected = ['game','server','port/contracts','godot/arms_race','godot/world','godot/net','godot/ui','tools/godot-dev','tools/godot-package']
require(not subprocess.check_output(['git','diff','e7602fb','--',*protected],cwd=ROOT), 'Protected runtime/source changed')
checks['protectedRuntimeUnchanged'] = True
inherited = ['godot/world/session.gd','godot/net/client.gd','godot/ui/game_hud.gd','godot/ui/scoreboard.gd']
require(not subprocess.check_output(['git','diff','8a58c97','5445295','--',*inherited],cwd=ROOT), 'Inherited baseline unexpectedly changed')
checks['inheritedFilesIdenticalToDeliveryBase'] = inherited
original = subprocess.run(['git','apply','--check','port/native-arms-race/shared-hooks.patch'],cwd=ROOT,capture_output=True,text=True)
checks['originalHooksPatch'] = {'exit':original.returncode,'stderr':original.stderr}
rebased = subprocess.run(['git','apply','--check',str(HERE/'shared-hooks-rebased.patch')],cwd=ROOT,capture_output=True,text=True)
require(rebased.returncode == 0,'Rebased unapplied hooks patch does not fit')
checks['rebasedHooksPatchAppliesButUnapplied'] = True
(HERE/'FINAL-CHECKS.json').write_text(json.dumps(checks,indent=2)+'\n')
manifest = {str(p.relative_to(HERE)):sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name != 'EVIDENCE-SHA256.json' and '__pycache__' not in p.parts}
(HERE/'EVIDENCE-SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(checks,indent=2))
