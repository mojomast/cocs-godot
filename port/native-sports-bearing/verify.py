#!/usr/bin/env python3
"""Focused synthetic suite. Live evidence is separately captured by run.py."""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BIN = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
OUT = Path(__file__).resolve().parent / 'tests'
SCRIPTS = ['bearing_projection_test', 'soccer_test', 'progression_test', 'practice_test', 'test_polish', 'test_controls']

def main():
    OUT.mkdir(exist_ok=True)
    env = dict(os.environ, TMPDIR='/tmp/opencode', PORT='0')
    for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
        env[key] = '/tmp/opencode/sports-bearing-xdg/' + key
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    results = []
    for script in SCRIPTS:
        command = [BIN, '--headless', '--path', str(ROOT / 'godot'), '--script', 'res://tests/sports/' + script + '.gd']
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=45)
        text = result.stdout + result.stderr
        (OUT / (script + '.log')).write_text(text)
        ok = result.returncode == 0 and 'ERROR:' not in text and 'SCRIPT ERROR' not in text
        results.append(dict(script=script, passed=ok, command=command, exit=result.returncode))
        print(script, 'PASS' if ok else 'FAIL', text.strip())
    (OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    if not all(r['passed'] for r in results): raise SystemExit(1)

if __name__ == '__main__': main()
