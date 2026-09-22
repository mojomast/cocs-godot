"""Bounded default-ten-wave exported product startup; not full-round acceptance."""
import ctypes as C
import ctypes.util
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
import urllib.request

from verify import ROOT, require, records, sha


def health_identity(status, port):
    require(status.get('service') == 'cocs-local-horde' and type(status.get('transport')) is int and status['transport'] == 1 and status.get('localOnly') is True and status.get('port') == port, 'Wrong local Horde readiness identity')


def key(x11, window, pressed):
    xtest = C.CDLL(ctypes.util.find_library('Xtst'))
    xtest.XTestFakeKeyEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
    xtest.XTestFakeKeyEvent.restype = C.c_int
    x11.lib.XSetInputFocus(x11.display, window, 2, 0)
    require(xtest.XTestFakeKeyEvent(x11.display, x11.lib.XKeysymToKeycode(x11.display, 0xff09), int(pressed), 0), 'Tab event failed')
    x11.lib.XSync(x11.display, 0)
    x11.check_errors()


def run_cases(package, fresh, unrelated, nodebin, env, output, x11, children):
    observer = fresh / 'horde_observer.gd'
    shutil.copy2(ROOT / 'tools/godot-package/horde_observer.gd', observer)
    helper = fresh / 'horde_authority.mjs'
    shutil.copy2(ROOT / 'tools/godot-package/horde_authority.mjs', helper)
    results = []
    for map_id in ['meridian-exchange', 'verdant-reliquary', 'ember-crucible']:
        for width, height in [(960, 640), (1280, 800)]:
            name = f'horde-product-{map_id}-{width}'
            log = output / (name + '.log')
            authority_log = output / (name + '-authority.log')
            native = authority = None
            port = None
            private = fresh / name
            private.mkdir()
            case_env = dict(env, HORDE_PACKAGE_PNG=str(output / (name + '.png')))
            for key_name in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']:
                case_env[key_name] = str(private / key_name)
                Path(case_env[key_name]).mkdir(mode=0o700)
            deadline = time.monotonic() + 120

            def wait_record(path, prefix, process):
                while time.monotonic() < deadline:
                    found = records(path.read_text(), prefix)
                    if found:
                        return found[0]
                    require(process.poll() is None, f'{name}: process exited before {prefix}; see {path}')
                    time.sleep(0.05)
                raise RuntimeError(f'{name}: bounded 120s deadline at {prefix}')

            try:
                with authority_log.open('w') as stream:
                    authority = subprocess.Popen([nodebin / 'node', helper, package / 'runtime/port/native-horde/authority.mjs'], cwd=unrelated, env=case_env, stdout=stream, stderr=subprocess.STDOUT)
                children.append(authority)
                port = wait_record(authority_log, 'HORDE_VERIFY_READY ', authority)['port']
                with urllib.request.urlopen(f'http://127.0.0.1:{port}/', timeout=5) as response:
                    health = json.load(response)
                health_identity(health, port)
                argv = [str(package / 'cocs.x86_64'), '--main-pack', str(package / 'cocs.pck'), '--script', str(observer), '--resolution', f'{width}x{height}', '--position', '0,0', '--', f'--endpoint=ws://127.0.0.1:{port}', f'--map={map_id}', '--mode=horde']
                with log.open('w') as stream:
                    native = subprocess.Popen(argv, cwd=unrelated, env=case_env, stdout=stream, stderr=subprocess.STDOUT)
                children.append(native)
                proof = wait_record(log, 'HORDE_PRODUCT_READY ', native)
                state = proof['state']
                single = state['singleplayer']
                require(proof['scene'] == 'res://horde/demo.tscn' and proof['map'] == map_id and proof['scoreboard_script'] == 'res://horde/scoreboard.gd', 'Wrong exported composition')
                require(proof['waves'] == single['waveTarget'] == 10 and single['lives'] == 3 and single['wave'] == 1 and single['enemiesAlive'] == 3 and not state['over'], 'Default Horde startup not established')
                require(sum(a.get('isNpc') is True and a['health'] > 0 for a in state['actors']) == 3, 'Live source NPC roster missing')
                event_types = {e['type'] for e in proof['events']}
                require({'spawn', 'horde-wave', 'horde-modifier', 'husk', 'spitter'} <= event_types, 'Source-origin startup events missing')
                require(all('sourceId' in e for e in proof['events']) and [e['id'] for e in proof['events']] == list(range(1, len(proof['events']) + 1)), 'Event cursor sequence missing')
                require(any(e['type'] == 'horde-modifier' and e['sourceId'] == 'swarm' for e in proof['events']), 'String source modifier ID missing')
                require('Tab scores' in proof['help'] and 'Esc release' in proof['help'], 'Product help missing')
                window = x11.window(native.pid)
                require(window, 'Actual exported window missing')
                key(x11, window, True)
                capture = wait_record(log, 'HORDE_PRODUCT_CAPTURE ', native)
                require(capture['size'] == [width, height] and capture['board_visible'], 'Wrong capture dimensions/scoreboard')
                board, strip = capture['board'], capture['horde']
                require(board[1] >= strip[1] + strip[3] and board[1] + board[3] <= height, 'Horde strip/scoreboard overlap or clipping')
                key(x11, window, False)
                wait_record(log, 'HORDE_PRODUCT_RELEASED ', native)
                x11.close_window(window)
                require(native.wait(timeout=12) == 0, 'Exported observer exit failed')
                authority.terminate()
                require(authority.wait(timeout=10) == 0 and 'HORDE_VERIFY_CLOSED' in authority_log.read_text(), 'Horde authority cleanup failed')
                text = log.read_text()
                require('ERROR:' not in text and 'SCRIPT ERROR' not in text, 'Native product error')
                frames = records(text, 'HORDE_PRODUCT_SNAPSHOT ')
                require(len(frames) >= 3 and frames[-1]['state']['time'] > frames[0]['state']['time'], 'Ordinary advancing snapshots missing')
                for process in [native, authority]:
                    require(not Path(f'/proc/{process.pid}').exists(), 'Owned child survived')
                with socket.socket() as connection:
                    require(connection.connect_ex(('127.0.0.1', port)) != 0, 'Horde listener survived')
                result = {'case':name, 'scope':'default-ten-wave startup only; no completion claim', 'argv':argv, 'health':health, 'proof':proof, 'capture':capture, 'snapshot_count':len(frames), 'native_pid':native.pid, 'authority_pid':authority.pid, 'exit':0, 'cleanup':True, 'png_sha256':sha(output / (name + '.png'))}
                results.append(result)
                (output / 'horde-product.json').write_text(json.dumps(results, indent=2) + '\n')
                print(name, 'PASS', flush=True)
            finally:
                for process in [native, authority]:
                    if process and process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()
                shutil.rmtree(private)
    return results
