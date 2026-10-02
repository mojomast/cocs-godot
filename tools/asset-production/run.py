"""Source-only preflight by default; explicit one-unit/one-stage serial production.

No bpy/Godot import, version subprocess, rendering or cache copying in preflight.
"""
import argparse
import ast
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / 'port/finish/ASSET_PRODUCTION.json'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_plan():
    plan = json.loads(PLAN.read_text())
    assert plan['version'] == 1
    ids = [u['id'] for u in plan['units']]
    assert len(ids) == len(set(ids))
    for unit in plan['units']:
        for command in unit['commands']:
            assert 0 < command['timeoutSeconds'] <= 1800
            assert isinstance(command['argv'], list)
        assert unit.get('acceptedModes', []) == []
    return plan


def preflight(plan):
    report = {'kind':'source-only-preflight', 'heavyExecuted':False, 'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'tools':{}, 'units':[], 'moth':{}, 'missing':[], 'syntax':[], 'dependencies':{}}
    for name, binary in plan['tools'].items():
        path = Path(binary)
        report['tools'][name] = {'path':binary,'exists':path.is_file(),'executable':os.access(path,os.X_OK),'bytes':path.stat().st_size if path.is_file() else None,'versionExecuted':False}
        if not os.access(path,os.X_OK): report['missing'].append(binary)
    report['tools']['ffmpeg'] = {'path':shutil.which('ffmpeg'),'purpose':'later cadence-aware encoding; not invoked'}
    report['freeGiB'] = shutil.disk_usage(ROOT).free / 2**30
    report['diskReady'] = report['freeGiB'] >= plan['minimumFreeGiB']
    report['coreSha256'] = sha(ROOT/'game/core.mjs')
    assert report['coreSha256'] == plan['sourcePinSha256']
    diff = subprocess.check_output(['git','diff',plan['canonicalBase'],'--','game/','port/contracts/source-lock.json'],cwd=ROOT,text=True)
    assert not diff, 'Frozen authority/source pin differs from canonical base'
    report['frozenDiffEmpty'] = True
    from material_contract import contract
    materials = contract()
    report['materialContract'] = materials
    for relative, digest in {**materials['resources'], **materials['master']}.items():
        path = ROOT/relative
        report['moth'][relative] = {'sha256':digest,'bytes':path.stat().st_size}
    pending = {plan['common']['finishScript'], 'tools/asset-production/reopen.py', 'tools/asset-production/run.py', 'tools/asset-production/material_contract.py', 'tools/asset-production/receipt.mjs'}
    for unit in plan['units']:
        if unit.get('external'):
            report['units'].append({'id':unit['id'],'status':'parent/original-worktree-owned; no external polling'})
            continue
        pending.update(unit['recipePaths'])
        for command in unit['commands']:
            pending.update(a.removeprefix('res://') if not a.startswith('res://') else 'godot/'+a[6:] for a in command['argv'] if a.endswith(('.py','.mjs','.gd')))
        masters = sorted(ROOT.glob(unit['masters']['glob']))
        exports = sorted(ROOT.glob(unit['exports']['glob']))
        report['units'].append({'id':unit['id'],'mastersPresent':len(masters),'mastersExpected':unit['masters']['count'],
                               'exportsPresent':len(exports),'exportsExpected':unit['exports']['count'],
                               'resourceHashes':{str(p.relative_to(ROOT)):sha(p) for p in exports},
                               'configuredTriangleCap':unit['configuredTriangleCap'],'measuredTriangles':None,
                               'nextAssets':unit['nextAssets'],'nextCapture':unit['nextCapture']})
    # Follow only literal local JS/GDScript code dependencies, not cache trees.
    seen = set()
    while pending:
        relative = pending.pop()
        path = ROOT/relative
        if relative in seen: continue
        seen.add(relative)
        if not path.is_file(): report['missing'].append(relative); continue
        report['dependencies'][relative] = sha(path)
        if path.suffix == '.py':
            ast.parse(path.read_text(), filename=relative)
            report['syntax'].append(relative)
        if path.suffix in ('.mjs','.gd'):
            text = path.read_text()
            if path.suffix == '.mjs':
                for spec in re.findall(r'(?:from\s*|import\s*)[\'\"](\.[^\'\"]+)[\'\"]', text):
                    dep = (path.parent/spec).resolve()
                    if dep.is_relative_to(ROOT): pending.add(str(dep.relative_to(ROOT)))
            else:
                for dep in re.findall(r'(?:preload|load)\("res://([^\"]+)"\)', text):
                    if '{' not in dep and '%' not in dep: pending.add('godot/'+dep)
    # Resolve ws without opening a server or invoking an engine.
    ws = subprocess.run(['node','--input-type=module','-e',"console.log(import.meta.resolve('ws'))"],cwd=ROOT,capture_output=True,text=True)
    report['nodeWs'] = {'ok':ws.returncode==0,'resolved':ws.stdout.strip(),'error':ws.stderr.strip()}
    if ws.returncode: report['missing'].append('node package ws')
    report['readyForExplicitGrant'] = not report['missing'] and report['diskReady']
    return report


def commands(plan, unit, stage):
    if stage == 'import': return [dict(plan['common']['import'], id='import')]
    if stage == 'reopen': return [{'id':'independent-reopen','argv':['{blender}','-b','-t','1','--python','tools/asset-production/reopen.py','--','--unit='+unit['id']], 'timeoutSeconds':600}]
    if stage == 'receipt': return [{'id':'resource-receipt','argv':['node','tools/asset-production/receipt.mjs',unit['id']], 'timeoutSeconds':60}]
    selected = [c for c in unit['commands'] if c['id'] == stage]
    if not selected: raise ValueError('No such prepared stage: '+unit['id']+'/'+stage)
    return selected


def execute(command, plan, output):
    argv = [a.replace('{root}',str(ROOT)).replace('{blender}',plan['tools']['blender']).replace('{godot}',plan['tools']['godot']) for a in command['argv']]
    if argv[0] == plan['tools']['blender'] and '--python-exit-code' not in argv:
        argv[1:1] = ['--python-exit-code','1']
    log = output/(command['id']+'.log')
    with log.open('w') as stream:
        proc = subprocess.Popen(argv,cwd=ROOT,env={**os.environ,**plan['common']['environment']},stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
        try:
            code = proc.wait(timeout=command['timeoutSeconds'])
        except BaseException:
            os.killpg(proc.pid,signal.SIGKILL)
            proc.wait()
            raise
    if code: raise RuntimeError(f'{command["id"]} failed ({code}); preserve {log}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--unit')
    parser.add_argument('--stage',default='preflight')
    parser.add_argument('--granted',action='store_true')
    parser.add_argument('--compact',action='store_true',help='760x520 UI150 hosted profile')
    args = parser.parse_args()
    plan = load_plan()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    output = Path(plan['evidenceRoot'])/stamp
    output.mkdir(parents=True)
    report = preflight(plan)
    (output/'preflight.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'report':str(output/'preflight.json'),'ready':report['readyForExplicitGrant'],'missing':report['missing'],'freeGiB':report['freeGiB']}))
    if args.stage == 'preflight': return 0 if report['readyForExplicitGrant'] else 1
    if not args.granted: raise ValueError('Explicit parent slot grant and --granted required')
    if not report['readyForExplicitGrant']: raise ValueError('Preflight failed')
    unit = next(u for u in plan['units'] if u['id']==args.unit)
    if unit.get('external'): raise ValueError('Parent-owned external unit; do not run here')
    # Same advisory lock as FINISHCOMBINED-A. Never wait/poll another owner.
    with open('/tmp/opencode/cocs-finish-acceptance.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        for command in commands(plan,unit,args.stage):
            if args.compact:
                if not args.stage.startswith('hosted-'): raise ValueError('--compact requires hosted stage')
                command = {**command, 'argv': command['argv'] + ['--compact']}
            execute(command,plan,output)
    (output/'stage.json').write_text(json.dumps({'unit':unit['id'],'stage':args.stage,'commandCompleted':True,'productionAccepted':False},indent=2)+'\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
