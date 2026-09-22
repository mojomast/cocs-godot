#!/usr/bin/env python3
"""Normal-rate production session for the source operator presentation lane.

Private authority, private staged project and private Xvfb display. The shipped
combat scene connects over the real transport; the two remote authority bots
walk, fire and reload while the observer records what the client renders.
Round results, the restart boundary and clean unload are part of the run.
"""
import argparse
import json
import os
import select
import shutil
import struct
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path(os.environ.get('GODOT_BIN', ROOT.parent / 'godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'))


def png_size(path):
    with path.open('rb') as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    return list(struct.unpack('>II', header[16:24]))


def stop(process):
    if process is None:
        return None
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    return process.returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    summary = {'passed': False, 'platform': 'Linux X11 llvmpipe', 'normal_rate': True, 'state_injection': False, 'checks': []}
    server = client = display = None
    peers = []
    with tempfile.TemporaryDirectory(prefix='source-operators-live-', dir='/tmp/opencode') as temporary:
        stage = Path(temporary)
        env = {**os.environ, 'HOME': str(stage), 'LIBGL_ALWAYS_SOFTWARE': '1', 'LP_NUM_THREADS': '2', 'SOURCE_OPERATOR_LIVE_OUTPUT': str(output)}
        for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']:
            path = stage / key
            path.mkdir(mode=0o700)
            env[key] = str(path)
        with (output / 'server.log').open('w') as server_log, (output / 'xvfb.log').open('w') as display_log, (output / 'native.log').open('w') as native_log, (output / 'peer-host.log').open('w') as peer_host_log, (output / 'peer-guest.log').open('w') as peer_guest_log:
            try:
                project = stage / 'godot'
                shutil.copytree(ROOT / 'godot', project, ignore=shutil.ignore_patterns('.godot'))
                import_result = subprocess.run([str(GODOT), '--headless', '--path', str(project), '--editor', '--import'], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900)
                (output / 'import.log').write_text(import_result.stdout)
                if import_result.returncode or 'SCRIPT ERROR' in import_result.stdout:
                    raise RuntimeError('Private project import failed')
                ready = stage / 'authority.json'
                server = subprocess.Popen(['node', str(ROOT / 'tools/godot-operators/live-server.mjs'), str(ready)], cwd=ROOT, env=env, stdout=server_log, stderr=subprocess.STDOUT)
                deadline = time.monotonic() + 15
                while not ready.exists():
                    if server.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError('Authority readiness failed')
                    time.sleep(0.05)
                port = json.loads(ready.read_text())['port']
                read_fd, write_fd = os.pipe()
                try:
                    display = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'], env=env, pass_fds=[write_fd], stdout=display_log, stderr=subprocess.STDOUT)
                    os.close(write_fd)
                    if not select.select([read_fd], [], [], 10)[0]:
                        raise RuntimeError('Display readiness failed')
                    env['DISPLAY'] = ':' + os.read(read_fd, 64).decode().strip()
                finally:
                    os.close(read_fd)
                peer_host_ready = stage / 'peer-host.json'
                peer_host = subprocess.Popen(['node', str(ROOT / 'tools/godot-operators/live-peer.mjs'), str(peer_host_ready), f'ws://127.0.0.1:{port}', 'host'], cwd=ROOT, env=env, stdout=peer_host_log, stderr=subprocess.STDOUT)
                peers.append(peer_host)
                deadline = time.monotonic() + 15
                while not peer_host_ready.exists():
                    if peer_host.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError('Host peer readiness failed')
                    time.sleep(0.05)
                peer_guest_ready = stage / 'peer-guest.json'
                peer_guest = subprocess.Popen(['node', str(ROOT / 'tools/godot-operators/live-peer.mjs'), str(peer_guest_ready), f'ws://127.0.0.1:{port}', 'guest'], cwd=ROOT, env=env, stdout=peer_guest_log, stderr=subprocess.STDOUT)
                peers.append(peer_guest)
                deadline = time.monotonic() + 15
                while not peer_guest_ready.exists():
                    if peer_guest.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError('Guest peer readiness failed')
                    time.sleep(0.05)
                room = json.loads(peer_host_ready.read_text())['roomId']
                command = [str(GODOT), '--path', str(project), '--script', str(ROOT / 'tools/godot-operators/live_observe.gd'), '--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', '960x640', '--position', '0,0', '--',
                           f'--endpoint=ws://127.0.0.1:{port}', '--map=meridian-exchange', f'--join-room={room}', '--mute']
                summary['command'] = command
                client = subprocess.Popen(command, cwd=ROOT, env=env, stdout=native_log, stderr=subprocess.STDOUT)
                try:
                    client.wait(timeout=200)
                except subprocess.TimeoutExpired:
                    summary['error'] = 'production client did not finish the lifecycle'
                native_log.flush()
                native = (output / 'native.log').read_text()
                report = json.loads((output / 'report.json').read_text()) if (output / 'report.json').exists() else {}

                def check(name, condition, **details):
                    summary['checks'].append({'name': name, 'passed': bool(condition), **details})
                    return bool(condition)

                session_ok = 'SOURCE_OPERATOR_LIVE_DONE' in native
                clean = client.returncode == 0 and session_ok and 'SCRIPT ERROR' not in native and 'ERROR:' not in native
                check('clean production session and unload', clean, returncode=client.returncode, completion='SOURCE_OPERATOR_LIVE_DONE' in native, script_errors='SCRIPT ERROR' in native, engine_errors='ERROR:' in native)
                remote_ids = report.get('remote_ids', [])
                check('at least two remote authority actors', len(remote_ids) >= 2, remote=remote_ids, actor_count=report.get('actor_count'))
                check('at least two remotes walked', len(report.get('remote_walking', [])) >= 2, walking=report.get('remote_walking'))
                check('at least two remotes fired', len(report.get('remote_firing', [])) >= 2, firing=report.get('remote_firing'), shots=report.get('remote_max_shots'))
                check('at least two remotes reloaded', len(report.get('remote_reloading', [])) >= 2, reloading=report.get('remote_reloading'))
                check('snapshot stream and interpolated remote poses', int(report.get('snapshots', 0)) > 100 and int(report.get('rendered_remote_poses', 0)) > 100, snapshots=report.get('snapshots'), rendered_remote_poses=report.get('rendered_remote_poses'))
                check('presentation renders the source operator visual', report.get('visual_scripts_all_match') is True and report.get('visual_script') == 'res://source_operators/operator_visual.gd', script=report.get('visual_script'))
                check('world weapons mount and hide the built-in pulse', report.get('visual_world_weapons_all_match') is True and report.get('visual_pulse_hidden_all_match') is True and report.get('visual_weapon_matches_all_match') is True, weapons=report.get('remote_weapons'))
                check('post-pose grips track the chassis contacts', float(report.get('grip_excess_max', 1.0)) < 0.0001 and float(report.get('grip_max_error', 1.0)) < 0.05, max_error=report.get('grip_max_error'), reach_clamp=report.get('grip_clamp_max'), clamp_excess=report.get('grip_excess_max'))
                check('round results observed', int(report.get('results', {}).get('count', 0)) >= 1 and report.get('results', {}).get('over') is True, results=report.get('results'))
                check('restart boundary rebuilt the round', int(report.get('restarts', {}).get('count', 0)) >= 1, restarts=report.get('restarts'))
                capture_ok = True
                captures = report.get('captures', [])
                for expected_name, expected_size in [('actors-960x640', [960, 640]), ('actors-1280x800', [1280, 800]), ('restart-1280x800', [1280, 800])]:
                    entry = next((item for item in captures if item.get('name') == expected_name), None)
                    path = output / (expected_name + '.png')
                    size = png_size(path) if path.exists() else None
                    if entry is None or size != expected_size or path.stat().st_size < 10000:
                        capture_ok = False
                    check('capture ' + expected_name, entry is not None and size == expected_size and path.exists() and path.stat().st_size > 10000, size=size)
                check('two viewport resolutions rendered', capture_ok)
                check('observer recorded no transport errors', report.get('errors', []) == [], errors=report.get('errors'))
                summary['report'] = report
                summary['passed'] = all(item['passed'] for item in summary['checks'])
            except Exception as error:
                summary['error'] = str(error)
            finally:
                summary['cleanup'] = {'client': stop(client), 'authority': stop(server), 'display': stop(display), 'peers': [stop(remote) for remote in peers]}
                (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
    if not summary['passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
