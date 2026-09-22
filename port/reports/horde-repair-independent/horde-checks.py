"""Independent focused replay. Runtime/source read-only; all logs stay here."""
import gzip
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
GODOT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'

def run(name, command, expected=0, extra=None):
    with tempfile.TemporaryDirectory(prefix='horde-independent-check-', dir='/tmp/opencode') as temp:
        env = dict(os.environ, TMPDIR='/tmp/opencode', GODOT_BIN=GODOT, **(extra or {}))
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']:
            path = Path(temp) / key
            path.mkdir(mode=0o700)
            env[key] = str(path)
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, timeout=120)
        raw = result.stdout + result.stderr
        (OUT / (name + '.log.gz')).write_bytes(gzip.compress(raw, mtime=0))
    report = dict(command=command, envOverrides=extra or {}, exit=result.returncode,
                  expectedExit=expected, temporaryTreeRemoved=not Path(temp).exists())
    (OUT / (name + '.json')).write_text(json.dumps(report, indent=2) + '\n')
    print(name, json.dumps(report), raw.decode(errors='replace')[-1400:], flush=True)
    assert result.returncode == expected, name
    if expected == 0:
        assert not any(x in raw for x in [b'SCRIPT ERROR', b'Parse Error', b'ERROR:', b'ObjectDB instances leaked', b'resources still in use']), name

def native(name, script, args=(), expected=0):
    run(name, [GODOT, '--headless', '--path', 'godot', '--script', script, '--', *args], expected)

if __name__ == '__main__':
    run('semantic', ['node', 'tools/godot-export/semantic.mjs'])
    run('import', [GODOT, '--headless', '--path', 'godot', '--editor', '--import'])
    run('adapter-final', ['node', '--test', 'port/native-horde/test.mjs', 'port/native-horde/input-buffer.test.mjs', 'port/native-horde/repair-regression.test.mjs'])
    run('regression-old', ['node', '--test', 'port/native-horde/repair-regression.test.mjs'], 1, {'HORDE_BASELINE':'59c2b33c3080845eb73f8490b3dc9e355117c000'})
    run('source-ui', ['node', '--test', 'game/singleplayer.test.mjs', 'game/singleplayer-ui.test.mjs'])
    native('horde-model', 'res://tests/horde/test.gd')
    native('control-safety', 'res://tests/protocol/control_safety.gd')
    native('hud-session', 'res://tests/protocol/game_hud_session.gd')
    native('scoreboard', 'res://tests/protocol/scoreboard.gd')
    native('scoreboard-session', 'res://tests/protocol/scoreboard_session.gd')
    vectors = str(OUT / 'input-vectors.json')
    run('input-oracle', ['node', 'port/native-horde/input-oracle.mjs', vectors])
    native('source-input-final', 'res://tests/horde/controls_test.gd', ['--vectors=' + vectors])
    native('layout-final', 'res://tests/horde/layout_test.gd')
    native('layout-old', 'res://tests/horde/layout_test.gd', ['--legacy-layout'], 1)
    native('leak-final', 'res://tests/horde/leak_probe.gd')
    native('leak-old', 'res://tests/horde/leak_probe.gd', ['--replace-script'], 1)
