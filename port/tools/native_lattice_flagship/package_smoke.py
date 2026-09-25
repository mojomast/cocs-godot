"""Bounded packaged LATTICE route startup on an owned Xvfb display.

Checks packaged launcher/server/native startup and cleanup. This is not a match.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
MARKER = Path('/home/mojo/.tmp-on-disk/cocs-lattice-engine-slot-granted')


def sha(path):
    with open(path, 'rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', required=True, type=Path)
    parser.add_argument('--map', required=True, choices=['asterion-relay', 'monsoon-foundry'])
    parser.add_argument('--mode', required=True, choices=['cocs', 'cocs-coop'])
    args = parser.parse_args()
    if not MARKER.is_file():
        raise SystemExit('Engine slot not granted')
    package = args.package.resolve(strict=True)
    if not (package / 'cocs.pck').is_file() or not (package / 'run.mjs').is_file():
        raise SystemExit('Expected built package')
    attempt = ROOT / 'port/native-lattice/evidence/flagship' / f'package-smoke-{time.time_ns()}'
    attempt.mkdir(parents=True)
    display = None
    launcher = None
    result = {'evidence_class': 'packaged-startup-smoke', 'map': args.map, 'mode': args.mode,
              'package': str(package), 'pack_sha256': sha(package / 'cocs.pck'),
              'launcher_sha256': sha(package / 'run.mjs'), 'attempt': str(attempt)}
    with (attempt / 'xvfb.log').open('w') as xlog, (attempt / 'launcher.log').open('w') as log:
        try:
            # Dedicated high-numbered display; Xvfb's -displayfd scans occupied
            # sockets on this machine and can fail despite a free private slot.
            number = str(1000 + os.getpid() % 20000)
            display = subprocess.Popen(['Xvfb', ':' + number, '-screen', '0', '1280x800x24', '-nolisten', 'tcp'],
                                       stdout=xlog, stderr=xlog, start_new_session=True)
            time.sleep(1)
            if display.poll() is not None:
                raise RuntimeError(f'Owned Xvfb exited: {display.returncode}')
            env = {**os.environ, 'DISPLAY': ':' + number}
            command = ['node', 'run.mjs', '--experience=lattice-world', '--map=' + args.map,
                       '--mode=' + args.mode, '--bots=2', '--time-limit=900', '--native-trace']
            result['command'] = command
            launcher = subprocess.Popen(command, cwd=package, env=env, stdout=log, stderr=subprocess.STDOUT,
                                        start_new_session=True)
            time.sleep(8)
            if launcher.poll() is not None:
                raise RuntimeError(f'Packaged launcher exited early: {launcher.returncode}')
        except Exception as error:
            result['error'] = repr(error)
        finally:
            if launcher is not None and launcher.poll() is None:
                launcher.send_signal(signal.SIGTERM)
                try:
                    result['exit'] = launcher.wait(timeout=12)
                except subprocess.TimeoutExpired:
                    os.killpg(launcher.pid, signal.SIGKILL)
                    result['exit'] = launcher.wait(timeout=5)
                    result['error'] = 'Launcher failed graceful cleanup'
            if display is not None and display.poll() is None:
                display.terminate()
                try:
                    display.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    display.kill()
                    display.wait(timeout=5)
    text = (attempt / 'launcher.log').read_text(errors='replace')
    result['markers'] = {name: text.count(name) for name in ['PACKAGE_SERVER_READY ', 'PACKAGE_NATIVE_STARTED ', 'PACKAGE_STOPPED']}
    result['script_error'] = 'SCRIPT ERROR' in text or 'Parse Error' in text
    result['cleanup'] = {'launcher_exited': launcher is None or launcher.poll() is not None,
                         'display_exited': display is None or display.poll() is not None}
    result['passed'] = not result.get('error') and not result['script_error'] and all(v == 1 for v in result['markers'].values()) and all(result['cleanup'].values())
    (attempt / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f"{attempt}: {'PASS' if result['passed'] else 'FAIL'} packaged startup only")
    if not result['passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
