#!/usr/bin/env python3
"""Run exact focused commands without overwriting committed delivery logs."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
GODOT = os.environ['GODOT_BIN']
commands = [
    ['node', 'tools/godot-export/semantic.mjs'],
    [GODOT, '--headless', '--path', 'godot', '--editor', '--import'],
    ['node', '--test', 'port/native-horde/test.mjs'],
    ['node', '--test', 'game/singleplayer.test.mjs', 'game/singleplayer-ui.test.mjs'],
    [GODOT, '--headless', '--path', 'godot', '--script', 'res://tests/horde/test.gd'],
    [GODOT, '--headless', '--path', 'godot', '--script', 'res://tests/protocol/control_safety.gd'],
    [GODOT, '--headless', '--path', 'godot', '--script', 'res://tests/protocol/game_hud_session.gd'],
]
results = []
with tempfile.TemporaryDirectory(prefix='horde-independent-checks-', dir='/tmp/opencode') as tmp:
    env = dict(os.environ)
    for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR'):
        path = Path(tmp) / key
        path.mkdir(mode=0o700)
        env[key] = str(path)
    for index, command in enumerate(commands):
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        log = f'check-{index}.log'
        (OUT / log).write_text(output)
        ok = result.returncode == 0 and not any(s in output for s in ('SCRIPT ERROR', 'Parse Error', 'ERROR:'))
        results.append(dict(command=command, exit=result.returncode, ok=ok, log=log))
        print(json.dumps(results[-1]), flush=True)
        if not ok:
            break
(OUT / 'checks.json').write_text(json.dumps(dict(results=results, temporaryTreeRemoved=not Path(tmp).exists()), indent=2))
raise SystemExit(0 if len(results) == len(commands) and all(r['ok'] for r in results) else 1)
