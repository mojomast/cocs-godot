#!/usr/bin/env python3
"""Two <=100s scenarios, fresh baseline + revised scene, ordinary XTest only."""
import argparse
import ctypes as C
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / 'evidence'
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('audit_capture', ROOT / 'port/native-usability-audit/runner.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)

def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')

def observations(directory):
    text = (directory / 'runtime.log').read_text()
    return [json.loads(s[18:]) for s in text.splitlines() if s.startswith('USABILITY_OBSERVE ')]

def run(width, height, baseline):
    scenario = OUT / f'{width}x{height}'
    scenario.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    # Entire scenario includes baseline, revised client and all cleanup.
    signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError('95s scenario bound')))
    signal.alarm(95)
    rd, wr = os.pipe()
    xvlog = open(scenario / 'xvfb.log', 'w')
    command = ['Xvfb','-displayfd',str(wr),'-screen','0','1600x1000x24','-nolisten','tcp','-nolisten','unix']
    xv = subprocess.Popen(command, pass_fds=(wr,), stdout=xvlog, stderr=xvlog)
    os.close(wr)
    display = ':' + os.read(rd, 64).decode().strip()
    os.close(rd)
    x = capture.driver(display)
    actions = []
    map_id, mode = ('asterion-relay','cocs') if width == 960 else ('monsoon-foundry','cocs-coop')
    try:
        for revision, project in [('before',baseline),('after',ROOT / 'godot')]:
            directory = scenario / revision
            directory.mkdir()
            runtime = Path(tempfile.mkdtemp(prefix='usability-xdg-',dir='/tmp/opencode'))
            env = dict(os.environ, DISPLAY=display, PORT='0', TMPDIR='/tmp/opencode')
            for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
                env[key] = str(runtime / key)
                Path(env[key]).mkdir()
            log = open(directory / 'runtime.log', 'w')
            cmd = ['node', str(ROOT / 'port/native-lattice-usability/launch.mjs'),str(project),str(directory),map_id,mode,f'{width}x{height}']
            process = subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=log,stderr=log)
            try:
                window = None
                deadline = time.monotonic() + 18
                while time.monotonic() < deadline:
                    windows = [w for w,n in x.windows() if n and 'PRIVATE' not in n]
                    if windows:
                        window = windows[-1]
                        x.x.XMoveResizeWindow(x.d,window,0,0,width,height)
                        x.focus(window)
                        obs = observations(directory)
                        if obs and obs[-1]['phase'] == 3 and obs[-1]['eligible']:
                            break
                    if process.poll() is not None:
                        raise RuntimeError('Native client exited before readiness')
                    time.sleep(.15)
                else:
                    raise RuntimeError('No fresh eligible native window')

                def note(action):
                    actions.append(dict(revision=revision,action=action,time=time.time(),x11=x.state()))
                    save(scenario / 'actions.json',actions)

                def shot(name):
                    time.sleep(.25)
                    capture.screenshot(x,window,width,height,directory / (name+'.png'))
                    note(name)

                def key(name,seconds=.1):
                    x.key(name,True); time.sleep(seconds); x.key(name,False); time.sleep(.2)

                def click(px=width-60,py=height-70):
                    x.motion(int(px),int(py)); x.button(True); time.sleep(.08); x.button(False); time.sleep(.25)

                def widget(name,first=False):
                    rect = observations(directory)[-1]['controls'][name]
                    click(rect[0]+min(100,rect[2]/2),rect[1]+(12 if first else rect[3]/2))

                shot('01-released')
                click()
                key('w',.6)
                shot('02-engaged')
                if revision == 'before':
                    key('Escape'); shot('03-escape')
                    continue
                # C opens safely even from active movement; ordinary releases.
                x.key('w',True)
                key('c')
                x.key('w',False)
                shot('03-commands')
                widget('nodes',True)
                widget('hold_button')
                time.sleep(.8)
                shot('04-hold-receipt')
                if mode == 'cocs':
                    time.sleep(.5)
                    widget('confirm_spend')
                    widget('spend_button')
                    time.sleep(.8)
                    shot('05-purchase-receipt')
                key('c')
                shot('06-close-released')
                x.key('w',True)
                click()
                shot('07-held-key-click-blocked')
                x.key('w',False)
                time.sleep(.3)
                click()
                shot('08-fresh-click-engaged')
                x.focus(x.sink)
                time.sleep(1)
                shot('09-focus-lost')
                x.focus(window)
                time.sleep(1)
                shot('10-focus-return-released')
                click()
                key('Escape')
                shot('11-escape-released')
                if width == 1280:
                    # Final runtime at 960 too, within the same bounded scenario.
                    width, height = 960, 640
                    x.x.XMoveResizeWindow(x.d,window,0,0,width,height)
                    time.sleep(.5)
                    shot('12-small-released')
                    click()
                    shot('13-small-engaged')
                    key('c')
                    shot('14-small-commands')
                    key('c')
                    shot('15-small-close-released')
                    click()
                    x.focus(x.sink)
                    time.sleep(1)
                    shot('16-small-focus-lost')
                    x.focus(window)
                    time.sleep(1)
                    shot('17-small-focus-return')
            finally:
                for k in ['w','a','s','d','c','Escape']: x.key(k,False)
                x.button(False)
                if process.poll() is None: process.send_signal(signal.SIGINT)
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(); raise
                log.close()
                shutil.rmtree(runtime)
                manifest = json.loads((directory / 'manifest.json').read_text())
                with socket.socket() as s:
                    closed = s.connect_ex(('127.0.0.1',manifest['port'])) != 0
                save(directory / 'cleanup.json',dict(port=manifest['port'],port_closed=closed,launcher_exit=process.returncode,pids_absent={str(pid):not Path(f'/proc/{pid}').exists() for pid in [process.pid,manifest['nativePid']]},xdg_removed=not runtime.exists()))
    finally:
        x.close(); xv.terminate(); xv.wait(timeout=3); xvlog.close()
        signal.alarm(0)
        save(scenario / 'scenario.json',dict(duration_seconds=time.monotonic()-started,xvfb_command=command,display=display,xvfb_pid=xv.pid,xvfb_absent=not Path(f'/proc/{xv.pid}').exists(),map=map_id,mode=mode))
        save(scenario / 'sha256.json',{str(p.relative_to(scenario)):hashlib.sha256(p.read_bytes()).hexdigest() for p in scenario.rglob('*') if p.is_file() and p.name != 'sha256.json'})

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--width',type=int,choices=[960,1280],required=True)
    args = parser.parse_args()
    run(args.width,640 if args.width == 960 else 800,args.baseline)
