#!/usr/bin/env python3
"""Run focused headless regressions in a disposable private project copy."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('tests', nargs='*', default=['window_focus','control_safety','session_recovery'])
    args = parser.parse_args()
    for test in args.tests:
        if test not in ['window_focus','control_safety','session_recovery']: parser.error('Unknown focused test')
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    runtime = Path(tempfile.mkdtemp(prefix='graphical-focused-', dir='/tmp/opencode'))
    env = os.environ.copy()
    for key in ['DISPLAY','WAYLAND_DISPLAY','XAUTHORITY','DBUS_SESSION_BUS_ADDRESS']: env.pop(key, None)
    for key in ['HOME','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR','TMPDIR']:
        folder = runtime/key
        folder.mkdir(mode=0o700)
        env[key] = str(folder)
    results = {'headless':True, 'runtime':str(runtime), 'commands':[], 'hashes':{}}
    for file in ['godot/world/session.gd']+[f'godot/tests/protocol/{t}.gd' for t in args.tests]:
        results['hashes'][file] = hashlib.sha256((ROOT/file).read_bytes()).hexdigest()
    def cap(): resource.setrlimit(resource.RLIMIT_FSIZE,(8_000_000,8_000_000))
    def run(name, command):
        with (output/(name+'.log')).open('w') as log:
            process = subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=30,preexec_fn=cap)
        text = (output/(name+'.log')).read_text()
        result = {'name':name, 'command':command, 'exit':process.returncode,
                  'engine_error':'SCRIPT ERROR' in text or '\nERROR:' in text}
        results['commands'].append(result)
        print(name, 'exit='+str(process.returncode), 'engine_error='+str(result['engine_error']))
        return process.returncode == 0 and not result['engine_error']
    passed = False
    try:
        project = runtime/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','generated','probes'))
        if not run('semantic',['node','tools/godot-export/semantic.mjs',str(project/'content/generated')]): return 1
        if not run('import',[args.godot,'--headless','--editor','--path',str(project),'--import']): return 1
        passed = True
        for test in args.tests:
            passed = run(test,[args.godot,'--headless','--path',str(project),'--script',f'res://tests/protocol/{test}.gd']) and passed
    finally:
        shutil.rmtree(runtime)
        results['runtime_removed'] = not runtime.exists()
        results['passed'] = passed
        (output/'result.json').write_text(json.dumps(results,indent=2)+'\n')
    return 0 if passed else 1


if __name__ == '__main__': raise SystemExit(main())
