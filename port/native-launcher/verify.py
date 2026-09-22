"""Exercise the real launcher/scenes with an explicitly bounded headless editor.

The editor wrapper adds only --headless/--quit-after; no gameplay or client code
is replaced. These are startup/ownership checks, not interactive acceptance.
"""
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[2]
os.chdir(root)
out = root / 'port/native-launcher/evidence' / str(time.time_ns())
out.mkdir(parents=True)
real = str(Path(os.environ['GODOT_BIN']).resolve())
cases = [('sports', 'ion-speedway', 'puma-race'),
         ('sports', 'aurora-stadium', 'puma-soccer'),
         ('objectives', 'tidal-citadel', 'ctf'),
         ('objectives', 'sunscar-convoy', 'payload'),
         ('lattice', 'asterion-relay', 'cocs'),
         ('lattice', 'monsoon-foundry', 'cocs-coop')]
results = []
with tempfile.TemporaryDirectory(prefix='native-launcher-', dir='/tmp/opencode') as temporary:
    wrapper = Path(temporary) / 'editor'
    wrapper.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
real=os.environ['LAUNCH_REAL_EDITOR']
args=sys.argv[1:]
if args != ['--version']:
    args=['--headless','--quit-after','180',*args]
    Path(os.environ['LAUNCH_RECORD']).write_text(json.dumps({'pid':os.getpid(),'args':args}))
os.execv(real,[real,*args])
''')
    wrapper.chmod(0o755)
    for experience, map_id, mode in cases:
        record = out / f'{map_id}.json'
        env = dict(os.environ, GODOT_BIN=str(wrapper), LAUNCH_REAL_EDITOR=real,
                   LAUNCH_RECORD=str(record), PORT='0')
        command = ['node', 'tools/godot-dev/launch.mjs', f'--experience={experience}',
                   f'--map={map_id}', f'--mode={mode}']
        child = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, start_new_session=True)
        timed_out = False
        try:
            output, _ = child.communicate(timeout=40)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(child.pid, signal.SIGKILL)
            output, _ = child.communicate()
        (out / f'{map_id}.log').write_text(output)
        editor = json.loads(record.read_text()) if record.exists() else {}
        absent = False
        if editor:
            try:
                os.kill(editor['pid'], 0)
            except ProcessLookupError:
                absent = True
        match = re.search(r'loopback:(\d+)', output)
        closed = False
        if match:
            with socket.socket() as sock:
                sock.settimeout(1)
                closed = sock.connect_ex(('127.0.0.1', int(match[1]))) != 0
        passed = child.returncode == 0 and not timed_out and absent and closed and not any(
            marker in output for marker in ['SCRIPT ERROR', 'ERROR:', 'WARNING: ObjectDB'])
        result = dict(experience=experience, map=map_id, mode=mode, command=command,
                      exit=child.returncode, timeout=timed_out, nativeAbsent=absent,
                      portClosed=closed, passed=passed)
        results.append(result)
        print(map_id, 'PASS' if passed else 'FAIL', flush=True)
        if not passed:
            print(output)
            break
summary = dict(status='PASS' if len(results) == len(cases) and all(r['passed'] for r in results) else 'FAIL',
               revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
               editor=real, scope='bounded headless startup and owned-process cleanup only',
               results=results)
(out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(out)
raise SystemExit(0 if summary['status'] == 'PASS' else 1)
