#!/usr/bin/env python3
"""Real private-X11 production-scene review; XTest OS input, observational GDScript.

Run from any directory: python3 port/native-graphics-independent/review.py
Only owned evidence/runtime directories are written. No external gameplay window,
engine-injected InputEvents, teleport, time scaling, or throughput benchmark.
"""
import ctypes as C
import ctypes.util
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import threading
import time

OWN = Path(__file__).resolve().parent
ROOT = OWN.parents[1]
GODOT = ROOT.parent / 'godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
EVIDENCE = OWN / 'evidence'
RUNTIME = OWN / 'runtime'


class X11:
    def __init__(self, display):
        self.x = C.CDLL(ctypes.util.find_library('X11'))
        self.t = C.CDLL(ctypes.util.find_library('Xtst'))
        signatures = {
            'XOpenDisplay': ([C.c_char_p], C.c_void_p),
            'XDefaultRootWindow': ([C.c_void_p], C.c_ulong),
            'XQueryTree': ([C.c_void_p, C.c_ulong, C.POINTER(C.c_ulong), C.POINTER(C.c_ulong), C.POINTER(C.POINTER(C.c_ulong)), C.POINTER(C.c_uint)], C.c_int),
            'XFetchName': ([C.c_void_p, C.c_ulong, C.POINTER(C.c_char_p)], C.c_int),
            'XFree': ([C.c_void_p], C.c_int),
            'XSetInputFocus': ([C.c_void_p, C.c_ulong, C.c_int, C.c_ulong], C.c_int),
            'XRaiseWindow': ([C.c_void_p, C.c_ulong], C.c_int),
            'XResizeWindow': ([C.c_void_p, C.c_ulong, C.c_uint, C.c_uint], C.c_int),
            'XStringToKeysym': ([C.c_char_p], C.c_ulong),
            'XKeysymToKeycode': ([C.c_void_p, C.c_ulong], C.c_ubyte),
            'XFlush': ([C.c_void_p], C.c_int),
            'XCloseDisplay': ([C.c_void_p], C.c_int),
        }
        for name, (args, result) in signatures.items():
            function = getattr(self.x, name)
            function.argtypes, function.restype = args, result
        for name, args in {
            'XTestFakeKeyEvent': [C.c_void_p, C.c_uint, C.c_int, C.c_ulong],
            'XTestFakeButtonEvent': [C.c_void_p, C.c_uint, C.c_int, C.c_ulong],
            'XTestFakeMotionEvent': [C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_ulong],
            'XTestFakeRelativeMotionEvent': [C.c_void_p, C.c_int, C.c_int, C.c_ulong],
        }.items():
            getattr(self.t, name).argtypes = args
        self.d = self.x.XOpenDisplay(display.encode())
        if not self.d:
            raise RuntimeError('private X11 connection failed')
        self.root = self.x.XDefaultRootWindow(self.d)

    def windows(self):
        root, parent, children, count = C.c_ulong(), C.c_ulong(), C.POINTER(C.c_ulong)(), C.c_uint()
        self.x.XQueryTree(self.d, self.root, C.byref(root), C.byref(parent), C.byref(children), C.byref(count))
        result = []
        for i in range(count.value):
            name = C.c_char_p()
            if self.x.XFetchName(self.d, children[i], C.byref(name)) and name.value:
                result.append((int(children[i]), name.value.decode(errors='replace')))
                self.x.XFree(name)
        if children:
            self.x.XFree(children)
        return result

    def flush(self):
        self.x.XFlush(self.d)

    def focus(self, window):
        self.x.XSetInputFocus(self.d, window, 1, 0)
        self.flush()
        time.sleep(.4)

    def key(self, name, down):
        code = self.x.XKeysymToKeycode(self.d, self.x.XStringToKeysym(name.encode()))
        assert code, name
        self.t.XTestFakeKeyEvent(self.d, code, int(down), 0)
        self.flush()

    def tap(self, name):
        self.key(name, True)
        time.sleep(.12)
        self.key(name, False)
        time.sleep(.35)

    def motion(self, x, y, relative=False):
        if relative:
            self.t.XTestFakeRelativeMotionEvent(self.d, x, y, 0)
        else:
            self.t.XTestFakeMotionEvent(self.d, -1, x, y, 0)
        self.flush()
        time.sleep(.3)

    def button(self, button, down):
        self.t.XTestFakeButtonEvent(self.d, button, int(down), 0)
        self.flush()
        time.sleep(.15)

    def click(self, x=None, y=None, button=1):
        if x is not None:
            self.motion(x, y)
        self.button(button, True)
        self.button(button, False)
        time.sleep(.3)


class Session:
    def __init__(self, scene, env, x):
        self.scene, self.x = scene, x
        self.out = EVIDENCE / scene
        self.out.mkdir(parents=True, exist_ok=True)
        self.records, self.events, self.checks = [], [], []
        self.env = dict(env, REVIEW_SCENE=scene, REVIEW_OUTPUT=str(self.out))
        self.command = [str(GODOT), '--path', str(ROOT / 'godot'), '--script', str(OWN / 'observer.gd'), '--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', '960x640', '--position', '0,0', '--max-fps', '30']
        self.log = (self.out / 'native.log').open('w')
        self.proc = subprocess.Popen(self.command, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        self.thread = threading.Thread(target=self.reader, daemon=True)
        self.thread.start()
        try:
            self.wait('REVIEW_READY', timeout=90)
        except Exception:
            if self.proc.poll() is None:
                self.proc.terminate()
                self.proc.wait(timeout=10)
            self.thread.join(timeout=5)
            self.log.close()
            raise
        wins = x.windows()
        self.window = next(w for w, title in wins if 'COCS' in title)
        x.focus(self.window)
        time.sleep(2)
        self.event('start', windows=wins, command=self.command)

    def reader(self):
        for line in self.proc.stdout:
            self.log.write(line)
            self.log.flush()
            if line.startswith('REVIEW_'):
                tag, payload = line.split(' ', 1)
                self.records.append((tag, json.loads(payload)))

    def wait(self, tag, start=0, timeout=30):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            for label, payload in self.records[start:]:
                if label == tag:
                    return payload
            if self.proc.poll() is not None:
                raise RuntimeError(f'{self.scene}: process exited {self.proc.returncode}; inspect native.log')
            time.sleep(.05)
        raise TimeoutError(f'{self.scene}: {tag}')

    def event(self, label, **data):
        self.events.append(dict(label=label, wall_monotonic=time.monotonic(), **data))

    def mark(self, label):
        start = len(self.records)
        self.x.tap('F9')
        state = self.wait('REVIEW_MARK', start)
        self.event(label, state=state)
        return state

    def capture(self, label):
        start = len(self.records)
        self.x.tap('F8')
        data = self.wait('REVIEW_CAPTURE', start)
        self.event(label, **data)
        return data

    def check(self, label, value, **details):
        self.checks.append(dict(label=label, passed=bool(value), **details))
        print(self.scene, 'PASS' if value else 'FAIL', label, flush=True)

    def same_window(self, label):
        windows = self.x.windows()
        self.check(label, len(windows) == 1 and windows[0][0] == self.window, windows=windows)

    def resize(self):
        self.x.x.XResizeWindow(self.x.d, self.window, 1280, 800)
        self.x.flush()
        time.sleep(2)
        self.capture('1280x800 production view')

    def teardown(self, reload=False):
        start = len(self.records)
        self.x.tap('F11' if reload else 'F10')
        data = self.wait('REVIEW_TEARDOWN', start)
        self.event('teardown', **data)
        if reload:
            self.wait('REVIEW_READY', start)
            time.sleep(1)
        else:
            self.proc.wait(timeout=20)
            self.thread.join(timeout=5)
            self.log.close()
        return data

    def save(self):
        (self.out / 'actions.json').write_text(json.dumps(dict(scene=self.scene, command=self.command, checks=self.checks, events=self.events), indent=2) + '\n')


def distance(a, b):
    return math.hypot(a['position'][0] - b['position'][0], a['position'][2] - b['position'][2])


def start_lateral(s, key, label):
    start = len(s.records)
    s.x.key(key, True)
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        for tag, state in s.records[start:]:
            if tag == 'REVIEW_SAMPLE' and math.hypot(state['velocity'][0], state['velocity'][2]) > .1:
                s.event(label, state=state, held_key=key)
                return state
        time.sleep(.05)
    raise RuntimeError(label + ': no observed moving frame within six seconds')


def wait_sample(s, start, predicate):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        for tag, state in s.records[start:]:
            if tag == 'REVIEW_SAMPLE' and predicate(state):
                return state
        time.sleep(.05)
    raise RuntimeError('no matching rendered observer sample within eight seconds')


def maps(s):
    x = s.x
    s.capture('960x640 original eye-level spawn')
    x.click()
    before = s.mark('captured start')
    s.check('click captures production controller', before['mouse_mode'] == 2 and before['camera_current'])
    x.key('w', True)
    time.sleep(.65)
    x.key('w', False)
    time.sleep(.3)
    after = s.mark('short normal-rate forward walk')
    s.check('W moves grounded production actor', distance(before, after) > .4, horizontal_distance=distance(before, after))
    x.motion(45, -10, relative=True)
    look = s.mark('real relative mouse look')
    s.check('mouse changes yaw', abs(look['yaw'] - after['yaw']) > .02)
    moving = start_lateral(s, 'd', 'D held before Escape')
    s.check('lateral motion active before Escape', math.hypot(moving['velocity'][0], moving['velocity'][2]) > .1)
    x.tap('Escape')
    stop = s.mark('Escape while D held')
    time.sleep(.5)
    stopped = s.mark('Escape stationary interval')
    s.check('Escape releases and held lateral movement stops', stopped['mouse_mode'] == 0 and distance(stop, stopped) < .03, horizontal_drift=distance(stop, stopped))
    x.key('d', False)
    x.click()
    recapture = s.mark('click recapture')
    s.check('click recaptures', recapture['mouse_mode'] == 2)
    # Reverse along the just-traversed route so a nearby railing cannot make
    # the stop assertion vacuous. Wait for a real physics sample, not an input
    # callback that can precede physics on a slow software-rendered frame.
    moving = start_lateral(s, 'a', 'A held before focus loss')
    s.check('lateral motion active before focus loss', math.hypot(moving['velocity'][0], moving['velocity'][2]) > .1)
    sample_start = len(s.records)
    x.focus(x.root)
    first = wait_sample(s, sample_start, lambda state: not state['focus'])
    second = wait_sample(s, sample_start, lambda state: not state['focus'] and state['frames'] > first['frames'] and state['ticks_ms'] >= first['ticks_ms'] + 750)
    s.event('actual X11 focus loss with A held', first=first, second=second)
    s.check('focus loss releases and stops held lateral motion', not first['focus'] and not second['focus'] and second['mouse_mode'] == 0 and distance(first, second) < .03, horizontal_drift=distance(first, second))
    x.key('a', False)
    x.focus(s.window)
    x.click()
    back = s.mark('focus regain click')
    s.check('focus regain recaptures', back['focus'] and back['mouse_mode'] == 2)
    s.capture('960x640 eye-level after actual short walk')
    s.resize()


def click_button(s, text):
    state = s.mark('locate button ' + text)
    button = next(b for b in state['buttons'] if text in b['text'])
    left, top, width, height = button['rect']
    s.x.click(int(left + width / 2), int(top + height / 2))


def particle(s):
    x = s.x
    s.capture('960x640 default particle UI')
    before = s.mark('initial actual backend statistics')
    click_button(s, '128K')
    up = s.mark('native button count up 128K')
    s.check('128K button changes actual draw and emitter slots', up['statistics']['draw_slots'] == 131072 and up['statistics']['emitter_amount'] == 131072)
    x.tap('minus')
    down = s.mark('keyboard count down')
    s.check('minus reduces actual slots to 32K', down['statistics']['draw_slots'] == 32768)
    x.tap('equal')
    s.check('plus raises actual slots to 128K', s.mark('keyboard count up')['statistics']['draw_slots'] == 131072)
    click_button(s, 'Pause')
    pause = s.mark('UI pause')
    time.sleep(.6)
    paused = s.mark('paused interval')
    s.check('pause freezes simulation clock', paused['paused'] and abs(paused['clock'] - pause['clock']) < .001)
    click_button(s, 'Reset field')
    reset = s.mark('reset while paused')
    s.check('reset rewinds actual field clock', reset['clock'] < .1)
    s.capture('960x640 paused 128K reset')
    x.tap('space')
    s.check('Space resumes simulation', not s.mark('resume')['paused'])
    x.tap('b')
    analytic = s.mark('actual analytic backend')
    s.check('B switches actual draw backend to MultiMesh', analytic['statistics']['instance_count'] == 131072 and analytic['statistics']['visible_instance_count'] == 131072 and 'MultiMesh' in analytic['backend_text'])
    x.tap('b')
    x.tap('f')
    x.motion(480, 300)
    x.button(3, True)
    flight = s.mark('RMB flight capture')
    s.check('RMB captures flight pointer', flight['mouse_mode'] == 2)
    x.tap('Escape')
    escaped = s.mark('Escape while RMB held')
    s.check('Escape releases pointer', escaped['mouse_mode'] == 0)
    x.button(3, False)
    x.tap('f')
    x.tap('minus')
    s.same_window('popup-free same native main window')
    s.resize()
    after = s.mark('main window still processing')
    s.check('main window advances rendered frames after controls/Escape', after['frames'] > before['frames'])


def shader(s):
    x = s.x
    s.capture('960x640 original interference UI')
    initial = s.mark('initial actual shader statistics')
    x.tap('equal')
    up = s.mark('intensity up')
    x.tap('minus')
    down = s.mark('intensity down')
    s.check('plus/minus changes and restores intensity', up['intensity'] > initial['intensity'] and abs(down['intensity'] - initial['intensity']) < .001)
    x.tap('space')
    pause = s.mark('pause')
    time.sleep(.5)
    paused = s.mark('paused interval')
    s.check('pause freezes shader time', paused['paused'] and abs(paused['seconds'] - pause['seconds']) < .001)
    x.tap('2')
    reactor = s.mark('reactor selection')
    s.check('2 selects reactor', reactor['selected'] == 1)
    s.check('960 reactor sidebar stays within viewport', reactor['sidebar_right'] <= reactor['size'][0], sidebar=reactor['sidebar_rect'], window=reactor['size'])
    s.capture('960x640 reactor UI')
    x.tap('3')
    s.check('3 selects phase', s.mark('phase selection')['selected'] == 2)
    s.capture('960x640 phase UI')
    x.tap('bracketright')
    s.check('phase adjustment works', s.mark('phase adjustment')['phase'] > .43)
    x.tap('r')
    reset = s.mark('R reset')
    s.check('R restores controls and resumes', not reset['paused'] and reset['intensity'] == 1 and abs(reset['phase'] - .43) < .001)
    x.motion(400, 300)
    x.button(1, True)
    x.motion(440, 310)
    x.button(1, False)
    drag = s.mark('mouse drag orbit')
    s.check('mouse drag orbits production camera', abs(drag['yaw'] - reset['yaw']) > .02)
    x.tap('Escape')
    after = s.mark('Escape responsiveness')
    s.check('Escape leaves main window responsive and pointer visible', after['mouse_mode'] == 0 and after['frames'] > reset['frames'])
    s.same_window('popup-free same native main window')
    x.tap('r')
    s.resize()
    x.tap('1')
    s.capture('1280x800 interference UI')
    x.tap('2')
    s.capture('1280x800 reactor UI')


def main():
    EVIDENCE.mkdir(exist_ok=True)
    RUNTIME.mkdir(exist_ok=True)
    for path in ['home', 'config', 'cache', 'data', 'run']:
        (RUNTIME / path).mkdir(exist_ok=True, mode=0o700)
    env = dict(os.environ, HOME=str(RUNTIME / 'home'), XDG_CONFIG_HOME=str(RUNTIME / 'config'), XDG_CACHE_HOME=str(RUNTIME / 'cache'), XDG_DATA_HOME=str(RUNTIME / 'data'), XDG_RUNTIME_DIR=str(RUNTIME / 'run'), LIBGL_ALWAYS_SOFTWARE='1', LP_NUM_THREADS='2', GODOT_SILENCE_ROOT_WARNING='1')
    read_fd, write_fd = os.pipe()
    xvfb_log = (EVIDENCE / 'xvfb.log').open('w')
    xvfb_command = ['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1440x1000x24', '-nolisten', 'tcp', '-nolisten', 'unix', '-noreset']
    xvfb = subprocess.Popen(xvfb_command, env=env, pass_fds=(write_fd,), stdout=xvfb_log, stderr=subprocess.STDOUT)
    os.close(write_fd)
    display = ':' + os.read(read_fd, 100).decode().strip()
    os.close(read_fd)
    env['DISPLAY'] = display
    x = X11(display)
    report = dict(xvfb_command=xvfb_command, display=display, input='XTest OS-level synthetic keyboard/mouse delivered to actual Godot X11 production window; no engine input injection', qualification='Linux native X11 / Mesa software llvmpipe / 30 fps cap, not Windows, not headless, not hardware throughput', scenes=[])
    try:
        scenes = sys.argv[1:] or ['showcase', 'aurora_basin', 'cinder_array', 'particle_lab', 'shader_lab']
        if sys.argv[1:] and (EVIDENCE / 'summary.json').exists():
            report['scenes'] = [entry for entry in json.loads((EVIDENCE / 'summary.json').read_text())['scenes'] if entry['scene'] not in scenes]
        for scene in scenes:
            s = None
            try:
                s = Session(scene, env, x)
                if scene in ['showcase', 'aurora_basin', 'cinder_array']:
                    maps(s)
                elif scene == 'particle_lab':
                    particle(s)
                else:
                    shader(s)
                # Three unload checkpoints, two production reloads. Renderer caches
                # may persist; node/orphan/resource deltas must plateau after warmup.
                teardown = []
                for i in range(3):
                    teardown.append(s.teardown(reload=i < 2))
                first, last = teardown[1]['after'], teardown[2]['after']
                s.check('bounded final two unload checkpoints', last['nodes'] <= first['nodes'] and last['orphans'] <= first['orphans'] and last['resources'] <= first['resources'] + 2 and last['objects'] <= first['objects'] + 5, checkpoints=teardown)
                s.check('clean process exit', s.proc.returncode == 0)
                s.save()
                report['scenes'].append(dict(scene=scene, checks=s.checks))
            except Exception as exc:
                report['scenes'].append(dict(scene=scene, error=str(exc)))
                print(scene, 'ERROR', str(exc), flush=True)
                if s:
                    s.save()
                    if s.proc.poll() is None:
                        s.proc.terminate()
                        s.proc.wait(timeout=10)
            (EVIDENCE / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    finally:
        x.x.XCloseDisplay(x.d)
        xvfb.terminate()
        xvfb.wait(timeout=10)
        xvfb_log.close()
    return int(any('error' in entry or any(not check['passed'] for check in entry.get('checks', [])) for entry in report['scenes']))


if __name__ == '__main__':
    sys.exit(main())
