#!/usr/bin/env python3
"""Bounded private-X11 heuristic audit helper; ordinary XTest input only.

start is a foreground supervisor (run using the harness background option).
Other invocations operate only on its state file. No simulation mutation.
"""
import argparse
import ctypes as C
import json
import os
from pathlib import Path
import signal
import socket
import struct
import subprocess
import sys
import time
import zlib

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'port/tools/graphical_acceptance'))
from x11 import X11

OUT = Path(__file__).resolve().parent
STATE = OUT / 'active.json'
ROUTES = {
    'combat': [],
    'race': ['--experience=sports', '--map=ion-speedway', '--time-limit=60'],
    'soccer': ['--experience=sports', '--map=aurora-stadium'],
    'payload': ['--experience=objectives', '--map=sunscar-convoy'],
    'board': ['--experience=lattice', '--map=asterion-relay', '--mode=cocs'],
    'world': ['--experience=lattice-world', '--map=monsoon-foundry', '--mode=cocs-coop'],
}

def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')

def driver(display):
    x = X11(display)
    x.x.XMoveResizeWindow.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_int, C.c_uint, C.c_uint]
    x.x.XMoveResizeWindow(x.d, x.sink, 1400, 850, 100, 100)
    x.sync()
    return x

def screenshot(x, window, width, height, path):
    image = x.x.XGetImage(x.d, window, 0, 0, width, height, 0xffffffff, 2)
    if not image:
        raise RuntimeError('XGetImage failed')
    try:
        im = image.contents
        assert (im.bits_per_pixel, im.byte_order) == (32, 0)
        raw = C.string_at(im.data, im.bytes_per_line * im.height)
        rows = []
        for y in range(im.height):
            row = raw[y*im.bytes_per_line:y*im.bytes_per_line+width*4]
            rgb = bytearray(width*3)
            rgb[0::3], rgb[1::3], rgb[2::3] = row[2::4], row[1::4], row[0::4]
            rows.append(b'\0' + rgb)
        def chunk(kind, data):
            return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind+data))
        path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b''))
    finally:
        x.x.XDestroyImage(image)

def start(a):
    directory = OUT / a.flow
    directory.mkdir(exist_ok=True)
    stop = directory / 'stop'
    stop.unlink(missing_ok=True)
    rd, wr = os.pipe()
    xvlog = open(directory / 'xvfb.log', 'w')
    xv = subprocess.Popen(['Xvfb', '-displayfd', str(wr), '-screen', '0', '1600x1000x24', '-nolisten', 'tcp', '-nolisten', 'unix'], pass_fds=(wr,), stdout=xvlog, stderr=xvlog)
    os.close(wr)
    display = ':' + os.read(rd, 64).decode().strip()
    os.close(rd)
    env = dict(os.environ, DISPLAY=display, PORT='0', TMPDIR='/tmp/opencode')
    for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
        env[key] = str(directory / key)
        Path(env[key]).mkdir(exist_ok=True)
    log = open(directory / 'runtime.log', 'w')
    command = ['node', str(Path(a.package) / 'run.mjs'), *ROUTES[a.flow]]
    process = subprocess.Popen(command, env=env, stdout=log, stderr=log)
    x = driver(display)
    state = dict(flow=a.flow, display=display, xvfb_pid=xv.pid, launcher_pid=process.pid, width=a.width, height=a.height, command=command, started=time.time())
    try:
        window = None
        for _ in range(100):
            windows = [(w, n) for w, n in x.windows() if n and 'PRIVATE' not in n]
            if windows:
                window = windows[-1][0]
                break
            if process.poll() is not None:
                raise RuntimeError('Package exited before window')
            time.sleep(.1)
        if window is None:
            raise RuntimeError('No native window')
        x.x.XMoveResizeWindow.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_int, C.c_uint, C.c_uint]
        x.x.XMoveResizeWindow(x.d, window, 0, 0, a.width, a.height)
        x.focus(window)
        state['window'] = window
        state['sink'] = x.sink
        save(STATE, state)
        save(directory / 'session.json', state)
        print(json.dumps(state), flush=True)
        while process.poll() is None and not stop.exists() and time.time() - state['started'] < 240:
            time.sleep(.2)
    finally:
        if process.poll() is None:
            process.send_signal(signal.SIGINT)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        x.close()
        xv.terminate()
        xv.wait(timeout=5)
        log.close()
        xvlog.close()
        text = (directory / 'runtime.log').read_text()
        ready = next((json.loads(line.split(' ', 1)[1]) for line in text.splitlines() if line.startswith('PACKAGE_SERVER_READY ')), {})
        child = next((json.loads(line.split(' ', 1)[1]) for line in text.splitlines() if line.startswith('PACKAGE_NATIVE_STARTED ')), {})
        port = ready.get('port')
        s = socket.socket()
        closed = s.connect_ex(('127.0.0.1', port)) != 0 if port else None
        s.close()
        receipt = dict(launcher_exit=process.returncode, xvfb_exit=xv.returncode, package_stopped='PACKAGE_STOPPED' in text, port=port, port_closed=closed, pids_absent={str(pid): not Path(f'/proc/{pid}').exists() for pid in [process.pid, xv.pid, child.get('pid', 0)]}, ended=time.time())
        save(directory / 'cleanup.json', receipt)
        stop.unlink(missing_ok=True)
        STATE.unlink(missing_ok=True)
        print(json.dumps(receipt), flush=True)

def action(a):
    state = json.loads(STATE.read_text())
    directory = OUT / state['flow']
    if a.action == 'stop':
        (directory / 'stop').touch()
        return
    x = driver(state['display'])
    try:
        x.x.XMoveResizeWindow(x.d, state['sink'], 1400, 850, 100, 100)
        x.sync()
        if a.action == 'shot':
            time.sleep(.3)
            screenshot(x, state['window'], state['width'], state['height'], directory / (a.values[0] + '.png'))
        elif a.action == 'click':
            x.motion(*map(int, a.values)); x.button(True); time.sleep(.08); x.button(False)
        elif a.action == 'key':
            x.key(a.values[0], True); time.sleep(float(a.values[1]) if len(a.values) > 1 else .08); x.key(a.values[0], False)
        elif a.action == 'focus-away':
            x.focus(state['sink'])
            time.sleep(1)
        elif a.action == 'focus-back':
            x.focus(state['window'])
            time.sleep(1)
        elif a.action == 'look':
            x.motion(*map(int, a.values), relative=True)
        with open(directory / 'actions.jsonl', 'a') as f:
            f.write(json.dumps(dict(time=time.time(), action=a.action, values=a.values)) + '\n')
    finally:
        x.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='sub', required=True)
    p = sub.add_parser('start')
    p.add_argument('flow', choices=ROUTES)
    p.add_argument('--package', required=True)
    p.add_argument('--width', type=int, default=960)
    p.add_argument('--height', type=int, default=640)
    p = sub.add_parser('action')
    p.add_argument('action', choices=['shot', 'click', 'key', 'focus-away', 'focus-back', 'look', 'stop'])
    p.add_argument('values', nargs='*')
    a = parser.parse_args()
    start(a) if a.sub == 'start' else action(a)
