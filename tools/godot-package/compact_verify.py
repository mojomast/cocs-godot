"""Focused live compact HUD proof using the unchanged Linux release artifact."""
import argparse
import json
import os
from pathlib import Path
import select
import shutil
import socket
import subprocess
import time

from verify import ROOT, X11, records, require, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package, output = args.package.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    before = {name: sha(package / name) for name in ['cocs.pck', 'cocs.x86_64', 'manifest.json']}
    private = output / 'private'
    private.mkdir()
    nodebin = private / 'bin'
    nodebin.mkdir()
    shutil.copy2(shutil.which('node'), nodebin / 'node')
    env = {key: value for key, value in os.environ.items() if key in ['LANG', 'LC_ALL', 'LD_LIBRARY_PATH']}
    env.update(PATH=str(nodebin), TMPDIR=str(private), LIBGL_ALWAYS_SOFTWARE='1', GODOT_SILENCE_ROOT_WARNING='1')
    for key in ['HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']:
        env[key] = str(private / key)
        Path(env[key]).mkdir(mode=0o700)
    alsa = private / 'alsa-null.conf'
    alsa.write_text('pcm.!default { type null }\n')
    env['ALSA_CONFIG_PATH'] = str(alsa)
    settings = output / 'settings.json'
    settings.write_text(json.dumps({'version': 1, 'settings': {'ui_scale': 150, 'window_mode': 'windowed'}}))
    env['COCS_SETTINGS_PATH'] = str(settings)
    readfd, writefd = os.pipe()
    children, results = [], []
    x11 = None
    with (output / 'xvfb.log').open('w') as stream:
        xvfb = subprocess.Popen(['/usr/bin/Xvfb', '-displayfd', str(writefd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'], pass_fds=(writefd,), stdout=stream, stderr=subprocess.STDOUT, env=env)
    children.append(xvfb)
    os.close(writefd)
    try:
        require(select.select([readfd], [], [], 10)[0], 'Display timeout')
        env['DISPLAY'] = ':' + os.read(readfd, 100).decode().strip()
        x11 = X11(env['DISPLAY'])
        for name, cli in [('assault', ['--experience=assault', '--map=sunscar-convoy']), ('uplink', ['--experience=zones', '--mode=uplink', '--map=meridian-exchange'])]:
            authority_log = output / (name + '-authority.log')
            with authority_log.open('w') as stream:
                authority = subprocess.Popen([nodebin / 'node', ROOT / 'tools/godot-package/compact_authority.mjs', package, *cli], cwd=private, env=env, stdout=stream, stderr=subprocess.STDOUT)
            children.append(authority)
            deadline = time.monotonic() + 120
            while not records(authority_log.read_text(), 'COMPACT_AUTHORITY_READY '):
                require(authority.poll() is None and time.monotonic() < deadline, 'Authority failed')
                time.sleep(.05)
            ready = records(authority_log.read_text(), 'COMPACT_AUTHORITY_READY ')[0]
            plan, port = ready['plan'], ready['port']
            case_env = dict(env, COMPACT_SCENE=plan['scene'], COMPACT_PNG=str(output / (name + '-live.png')))
            argv = [str(package / 'cocs.x86_64'), '--main-pack', str(package / 'cocs.pck'), '--script', str(ROOT / 'tools/godot-package/compact_observer.gd'), '--resolution', '760x520', '--position', '0,0', '--', *plan['userArgs'], f'--endpoint=ws://127.0.0.1:{port}']
            log = output / (name + '.log')
            with log.open('w') as stream:
                native = subprocess.Popen(argv, cwd=private, env=case_env, stdout=stream, stderr=subprocess.STDOUT)
            children.append(native)
            resized = False
            while native.poll() is None and time.monotonic() < deadline:
                window = x11.window(native.pid)
                if window and not resized:
                    x11.resize(window, 760, 520)
                    resized = True
                time.sleep(.05)
            require(native.poll() == 0, f'{name}: native failed; see {log}')
            text = log.read_text()
            require('ERROR:' not in text, f'{name}: native error')
            proof = records(text, 'COMPACT_PRODUCT_CAPTURE ')[0]
            require(proof['phase'] == 3 and proof['received_pose'] and not proof['stale'] and proof['snapshots'] >= 3, 'No live client state')
            require(proof['size'] == [760, 520] and proof['ui_scale'] == 150, 'Wrong compact settings')
            require(proof['map'] == plan['map'] and proof['mode'] == plan['mode'], 'Wrong route')
            for label in proof['hud'].values():
                require(label['visible'] and label['text'] and 'waiting' not in label['text'].lower(), 'Objective HUD not live')
                x, y, w, h = label['rect']
                require(x >= 0 and y >= 0 and x + w <= 760 and y + h <= 520, 'Objective clipped')
            authority.terminate()
            require(authority.wait(timeout=10) == 0 and 'COMPACT_AUTHORITY_CLOSED' in authority_log.read_text(), 'Authority cleanup failed')
            with socket.socket() as connection:
                require(connection.connect_ex(('127.0.0.1', port)) != 0, 'Listener survived')
            results.append({'case': name, 'argv': argv, 'plan': plan, 'proof': proof, 'png_sha256': sha(Path(proof['path'])), 'cleanup': True})
            (output / (name + '-live.json')).write_text(json.dumps(results[-1], indent=2) + '\n')
            print(name, 'LIVE_CAPTURE_PASS (visual review required)', flush=True)
        after = {name: sha(package / name) for name in before}
        require(before == after, 'Package changed')
        (output / 'summary.json').write_text(json.dumps({'live_capture_passed': True, 'visual_acceptance': 'requires image review; bounds alone do not establish legibility or non-overlap', 'package': str(package), 'unchanged_hashes': after, 'cases': results}, indent=2) + '\n')
    finally:
        if x11: x11.close()
        os.close(readfd)
        for process in reversed(children):
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == '__main__':
    main()
