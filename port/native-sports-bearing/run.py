#!/usr/bin/env python3
"""Bounded real native scenes, normal source server, external XTest keys only.

Usage: python3 -B port/native-sports-bearing/run.py ion-speedway 960x640
Fresh evidence directory required. No state, camera, AI or timing mutations.
"""
import argparse
import ctypes as C
import json
import os
from pathlib import Path
import selectors
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
BIN = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
DEPS = Path('/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules')
sys.path.insert(0, str(ROOT / 'port/tools/graphical_acceptance'))
from x11 import X11

def stop(process):
    if process.poll() is None:
        process.terminate()
        try: process.wait(timeout=6)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)

def wait_for(fn, seconds=12):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            result = fn()
            if result: return result
        except (FileNotFoundError, json.JSONDecodeError): pass
        time.sleep(.05)
    raise RuntimeError('Timed out waiting for native scene')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('map', choices=['ion-speedway', 'aurora-stadium'])
    parser.add_argument('resolution', choices=['960x640', '1280x800'])
    parser.add_argument('--goal-right', action='store_true', help='Add a short D turn before the A sweep')
    args = parser.parse_args()
    out = Path(__file__).resolve().parent / 'live' / (args.map + '-' + args.resolution + ('-goal' if args.goal_right else ''))
    out.mkdir(parents=True, exist_ok=False)
    children, logs, actions = [], [], []
    x = None
    port = None
    started = time.time()
    def log(name):
        f = (out / name).open('w'); logs.append(f); return f
    def key(name, duration=.08):
        actions.append(dict(elapsed=time.time()-started, key=name, hold_seconds=duration))
        x.key(name, True); time.sleep(duration); x.key(name, False)
    def capture(label):
        (out / 'capture.txt').write_text(label)
        wait_for(lambda: (out / (label + '.json')).exists())
        receipt = json.loads((out / (label + '.json')).read_text())
        print(label, json.dumps({'vehicle':receipt['vehicle'], 'projections':receipt['projections'], 'hud':receipt['hud']}), flush=True)
    try:
        # The source authority resolves its pinned ws dependency through this private link.
        link = ROOT / 'node_modules'
        if not link.exists(): link.symlink_to(DEPS, target_is_directory=True)
        with tempfile.TemporaryDirectory(prefix='bearing-xdg-', dir='/tmp/opencode') as tmp:
            env = dict(os.environ, TMPDIR='/tmp/opencode', PORT='0')
            for k in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
                env[k] = str(Path(tmp) / k); Path(env[k]).mkdir()
            rd, wr = os.pipe()
            xv_cmd = ['Xvfb', '-displayfd', str(wr), '-screen', '0', '1600x1000x24', '-nolisten', 'tcp', '-nolisten', 'unix']
            xv = subprocess.Popen(xv_cmd, pass_fds=(wr,), stdout=log('xvfb.log'), stderr=subprocess.STDOUT)
            children.append(xv); os.close(wr)
            with selectors.DefaultSelector() as selector:
                selector.register(rd, selectors.EVENT_READ)
                if not selector.select(10): raise RuntimeError('Xvfb timeout')
                env['DISPLAY'] = ':' + os.read(rd, 64).decode().strip()
            os.close(rd)
            server_cmd = ['node', str(ROOT / 'port/native-sports-victory/server.mjs'), str(ROOT), str(out / 'wire.json')]
            server = subprocess.Popen(server_cmd, env=env, stdout=subprocess.PIPE, stderr=log('server.log'), text=True)
            children.append(server)
            with selectors.DefaultSelector() as selector:
                selector.register(server.stdout, selectors.EVENT_READ)
                if not selector.select(10): raise RuntimeError('Server timeout')
                endpoint = server.stdout.readline().strip().removeprefix('ENDPOINT ')
            port = int(endpoint.rsplit(':', 1)[1])
            native_cmd = [BIN, '--path', str(ROOT / 'godot'), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', args.resolution, '--script', 'res://tests/sports/bearing_observe.gd', '--', '--map=' + args.map, '--endpoint=' + endpoint, '--bearing-out=' + str(out)]
            native = subprocess.Popen(native_cmd, env=env, stdout=log('native.log'), stderr=subprocess.STDOUT)
            children.append(native)
            x = X11(env['DISPLAY'])
            x.x.XMoveResizeWindow.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_int, C.c_uint, C.c_uint]
            x.x.XMoveResizeWindow(x.d, x.sink, 1400, 850, 100, 100); x.sync()
            window = wait_for(lambda: next((w for w, title in x.windows() if title and 'PRIVATE' not in title), None))
            x.focus(window)
            wait_for(lambda: json.loads((out / 'latest.json').read_text()).get('eligible'))
            time.sleep(.5)
            capture('00-spawn')
            key('Return')
            if args.goal_right:
                key('d', .2)
                time.sleep(.65)
                capture('00b-right')
            for i in range(1, 5):
                key('a', .3)
                time.sleep(.65)  # let the unchanged chase smoothing settle
                capture('%02d-turn' % i)
            key('Escape')
            time.sleep(.5)
            capture('05-released')
            (out / 'session.json').write_text(json.dumps(dict(map=args.map, resolution=args.resolution, started=started, display=env['DISPLAY'], port=port, commands=[xv_cmd, server_cmd, native_cmd], classification='normal-rate source; ordinary external XTest input; passive observer'), indent=2)+'\n')
    finally:
        if x: x.close()
        for process in reversed(children): stop(process)
        for f in logs: f.close()
        (out / 'actions.json').write_text(json.dumps(actions, indent=2)+'\n')
        sock = socket.socket()
        closed = sock.connect_ex(('127.0.0.1', port)) != 0 if port else None
        sock.close()
        receipt = dict(elapsed=time.time()-started, port=port, port_closed=closed, pids_absent={p.pid:not Path('/proc/%d'%p.pid).exists() for p in children}, exits=[p.returncode for p in children])
        (out / 'cleanup.json').write_text(json.dumps(receipt, indent=2)+'\n')
        print('CLEANUP', json.dumps(receipt), flush=True)

if __name__ == '__main__': main()
