#!/usr/bin/env python3
"""Owned-lane verifier. Private Xvfb, pinned engine; injected events, not GUI acceptance."""
import json
import os
import select
import sys
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
OUT = Path(__file__).parent / 'evidence'
OUT.mkdir(exist_ok=True)


def run():
    read_fd, write_fd = os.pipe()
    xvfb = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1024x768x24', '-nolisten', 'tcp', '-nolisten', 'unix'], pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.close(write_fd)
    if not select.select([read_fd], [], [], 10)[0]:
        xvfb.terminate()
        xvfb.wait(timeout=10)
        raise RuntimeError('Private Xvfb allocation timed out')
    with os.fdopen(read_fd) as display:
        number = display.readline().strip()
    env = {**os.environ, 'DISPLAY': ':' + number, 'LIBGL_ALWAYS_SOFTWARE': '1'}
    rows = []
    try:
        scripts = sys.argv[1:] or [
            'combat_actions/controls', 'protocol/control_safety', 'protocol/window_focus',
            'protocol/weapon_selection', 'protocol/round_boundaries',
            'protocol/lobby_spectator_session', 'protocol/native_trace',
            'combined_arms/test_controls', 'horde/controls_test', 'combat_actions/live',
        ]
        for script in scripts:
            command = [str(GODOT), '--path', str(ROOT / 'godot'), '--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', f'res://tests/{script}.gd']
            if script == 'protocol/lobby_spectator_session': command += ['--', '--lobby-menu']
            if script == 'horde/controls_test': command += ['--', '--vectors=' + str(ROOT / 'port/reports/horde-input-vectors.json')]
            server = None
            try:
                if script == 'combat_actions/live':
                    server = subprocess.Popen(['node', str(Path(__file__).parent / 'private-server.mjs')], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                    if not select.select([server.stdout], [], [], 15)[0]: raise RuntimeError('Server startup timeout')
                    line = server.stdout.readline().strip()
                    (OUT / 'server.log').write_text(line + '\n')
                    if not line.startswith('COMBAT_ENDPOINT='): raise RuntimeError(line)
                    command += ['--', '--endpoint=' + line.split('=', 1)[1]]
                try:
                    result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=40)
                except subprocess.TimeoutExpired as exc:
                    text = exc.stdout.decode() if isinstance(exc.stdout, bytes) else (exc.stdout or '')
                    result = subprocess.CompletedProcess(command, 124, text + '\nVERIFIER TIMEOUT\n')
            finally:
                if server:
                    server.terminate()
                    server.wait(timeout=10)
            name = script.replace('/', '-')
            (OUT / f'{name}.log').write_text(result.stdout)
            print(script, result.returncode, result.stdout[-800:])
            rows.append({'script': script, 'returncode': result.returncode})
        (OUT / 'checks.json').write_text(json.dumps({'godot': str(GODOT), 'synthetic_events': True, 'gui_acceptance': False, 'checks': rows}, indent=2) + '\n')
        return int(any(row['returncode'] for row in rows))
    finally:
        xvfb.terminate()
        xvfb.wait(timeout=10)


if __name__ == '__main__':
    raise SystemExit(run())
