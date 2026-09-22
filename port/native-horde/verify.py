#!/usr/bin/env python3
"""Focused Horde checks; explicitly not the aggregate/release verifier."""
import os
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT_BIN')
if not GODOT:
    raise SystemExit('Set pinned GODOT_BIN')
commands = [
    ['node', '--test', 'port/native-horde/test.mjs'],
    ['node', '--test', 'game/singleplayer.test.mjs', 'game/singleplayer-ui.test.mjs'],
    [GODOT, '--headless', '--path', 'godot', '--script', 'res://tests/horde/test.gd'],
    [GODOT, '--headless', '--path', 'godot', '--script', 'res://tests/protocol/control_safety.gd'],
    [GODOT, '--headless', '--path', 'godot', '--script', 'res://tests/protocol/game_hud_session.gd'],
]
with tempfile.TemporaryDirectory(prefix='horde-check-') as temporary:
    env = dict(os.environ)
    for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
        path = pathlib.Path(temporary) / key
        path.mkdir()
        env[key] = str(path)
    for index, command in enumerate(commands):
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        (ROOT / f'port/native-horde/check-{index}.log').write_text(output)
        print(output)
        if result.returncode or any(marker in output for marker in ('SCRIPT ERROR', 'Parse Error', 'ERROR:')):
            raise SystemExit(result.returncode or 1)
print('HORDE_VERIFY_OK commands=5')
