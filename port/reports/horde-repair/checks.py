"""Owned logs/XDG; originals never overwritten. Pass commands after -- via JSON."""
import json, os, pathlib, subprocess, sys, tempfile
root=pathlib.Path(__file__).resolve().parents[3]
out=pathlib.Path(__file__).resolve().parent
name=sys.argv[1]
command=json.loads(sys.argv[2])
with tempfile.TemporaryDirectory(prefix='horde-repair-check-',dir='/tmp/opencode') as temp:
 env=dict(os.environ)
 env['TMPDIR']='/tmp/opencode'
 for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']:
  p=pathlib.Path(temp)/key;p.mkdir(mode=0o700);env[key]=str(p)
 result=subprocess.run(command,cwd=root,env=env,capture_output=True,text=True,timeout=120)
 text=result.stdout+result.stderr
 (out/(name+'.log')).write_text(text)
 (out/(name+'.json')).write_text(json.dumps(dict(command=command,exit=result.returncode,temporaryTreeRemoved=True),indent=2))
 print(text[-5000:])
 raise SystemExit(result.returncode or (1 if any(s in text for s in ['SCRIPT ERROR','Parse Error','ERROR:']) else 0))
