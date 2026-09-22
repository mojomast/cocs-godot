"""Provenance and owned listener/process checks; no previous report is rewritten."""
import hashlib
import json
from pathlib import Path
import socket
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BASE = '1a00d90227c9cf7d24a1e132b34f53e8aafcb838'
OLD = '59c2b33c3080845eb73f8490b3dc9e355117c000'
TIP = '50521191ee6922295a50448301e929d945926ef9'
APPLIED = '9c0f5a50c8935eecbf21cf6f0ff0e1ded57f7345'
def git(*args): return subprocess.check_output(['git', *args], cwd=ROOT)
def sha(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(path.read_text())
def closed(port):
    assert port != 4332
    with socket.socket() as s:
        s.settimeout(1)
        assert s.connect_ex(('127.0.0.1', port)) != 0, ('owned listener remains', port)
    return True

originals = {}
for path in git('ls-tree', '-r', '--name-only', OLD, 'port/reports/horde-independent', 'port/native-horde/evidence').decode().splitlines():
    data = (ROOT / path).read_bytes()
    assert data == git('show', f'{OLD}:{path}'), path
    originals[path] = sha(data)
assert len(originals) == 119
prior_repair = {}
for path in git('ls-tree', '-r', '--name-only', APPLIED, 'port/reports/horde-repair').decode().splitlines():
    data = (ROOT / path).read_bytes()
    assert data == git('show', f'{APPLIED}:{path}'), path
    prior_repair[path] = sha(data)
runtime = {}
for path in git('diff', '--name-only', OLD, TIP, '--', 'godot', 'port/native-horde').decode().splitlines():
    data = (ROOT / path).read_bytes()
    assert data == git('show', f'{TIP}:{path}'), path
    runtime[path] = sha(data)
protected = ['game', 'app', 'server', 'godot/world', 'godot/ui', 'godot/net', 'tools', 'port/contracts', 'package.json', 'package-lock.json']
assert not git('diff', BASE, '--', *protected)
assert sha((ROOT / 'game/core.mjs').read_bytes()) == '23d0a86acf720136c62a42547207b1c43f2146002fd26d8ac7d325b2d6312631'
runs = []
opened = {
 'b3e2a06b-5e89-46ab-a078-24cc57c91b60': ['gameplay-results.png', 'gameplay-results-alternate.png', 'gameplay-restart.png'],
 'fe8751ed-4200-4eec-8e91-5252bf598f4b': ['gameplay-final.png', 'gameplay-alternate.png', 'gameplay-death.png'],
 'f1346289-0f65-4210-bad5-1df72d0dc179': ['gameplay-final.png', 'gameplay-alternate.png'],
}
for folder in sorted((OUT / 'evidence').iterdir()):
    launch = read(folder / 'launch.json')
    summary = read(folder / 'summary.json')
    assert launch['base'] == APPLIED
    for path, digest in launch['hashes'].items():
        assert sha((ROOT / path).read_bytes()) == digest, ('launch bytes changed', path)
    for child in summary['cleanup']:
        assert child['absent'] and child['reaped'] and not Path('/proc', str(child['pid'])).exists()
    endpoint = next(arg.split('=', 1)[1] for arg in launch['argv'] if arg.startswith('--endpoint='))
    closed(int(endpoint.rsplit(':', 1)[1]))
    images = []
    for path in sorted(folder.glob('*.png')):
        data = path.read_bytes()
        width, height = struct.unpack('>II', data[16:24])
        assert (width, height) in [(960, 640), (1280, 800)]
        images.append(dict(file=path.name, width=width, height=height, sha256=sha(data), directlyOpened=path.name in opened[folder.name]))
    runs.append(dict(id=folder.name, summary=summary, formerEndpoint=endpoint, portClosed=True, images=images))
for name in ['event-gap.json', 'default-room.json']:
    diagnostic = read(OUT / name)
    port = diagnostic.get('port') or int(diagnostic['endpoint'].rsplit(':', 1)[1])
    assert diagnostic['serverClosed'] and diagnostic['sockets'] == 0
    closed(port)
generated = {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in (ROOT / 'godot/content/generated').rglob('*') if p.is_file()}
report = dict(baseline=BASE, appliedTip=APPLIED, externalRuntimeTip=TIP,
              sourceCommit=read(ROOT / 'port/contracts/source-lock.json')['source_commit'],
              sourceMatchSHA256=sha((ROOT / 'game/core.mjs').read_bytes()),
              originalEvidenceCount=len(originals), originalEvidenceSHA256=originals,
              priorRepairFileCount=len(prior_repair), priorRepairSHA256=prior_repair,
              exactFinalRuntimeHashes=runtime, protectedPathsUnchanged=protected,
              generatedBeforeCleanup=generated, runs=runs,
              nodeVersion=subprocess.check_output(['node', '--version'], text=True).strip(),
              result='HOLD: event-ring cursor still replays source events; Meridian repair validator rejection retained')
(OUT / 'provenance.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(dict(originalFiles=len(originals), priorRepairFiles=len(prior_repair), finalRuntimeFiles=len(runtime),
                     runs=len(runs), generatedResources=len(generated), result=report['result']), indent=2))
