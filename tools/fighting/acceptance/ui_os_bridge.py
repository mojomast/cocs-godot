"""Owned Linux virtual pads and real X11 focus for the granted native UI fixture.

Importing this module creates no devices/windows. Virtual pad removal exercises
Godot's actual OS hotplug path; it is explicitly not physical hardware evidence.
"""
import ctypes
import fcntl
import json
import os
from pathlib import Path
import struct
import subprocess
import threading
import time

UI_SET_EVBIT = 0x40045564
UI_SET_KEYBIT = 0x40045565
UI_SET_ABSBIT = 0x40045567
UI_ABS_SETUP = 0x401c5504
UI_DEV_SETUP = 0x405c5503
UI_DEV_CREATE = 0x5501
UI_DEV_DESTROY = 0x5502
BUTTONS = (304, 305, 307, 308, 310, 311, 314, 315, 316, 317, 318)


def device_setup(name):
    raw = name.encode('ascii')
    if not 0 < len(raw) < 80:
        raise ValueError('bounded ASCII virtual device name required')
    # USB/Xbox 360 axes/buttons, with a unique owned name for menu selection.
    return struct.pack('<HHHH80sI', 3, 0x045e, 0x028e, 0x0114, raw, 0)


def abs_setup(axis, low, high):
    return struct.pack('<H2xiiiiii', axis, 0, low, high, 0, 0, 0)


class VirtualPad:
    def __init__(self, name, device='/dev/uinput'):
        self.name = name
        self.fd = os.open(device, os.O_WRONLY | os.O_NONBLOCK)
        self.created = False
        try:
            for event in (0, 1, 3):
                fcntl.ioctl(self.fd, UI_SET_EVBIT, event)
            for button in BUTTONS:
                fcntl.ioctl(self.fd, UI_SET_KEYBIT, button)
            for axis in (0, 1, 2, 3, 4, 5, 16, 17):
                fcntl.ioctl(self.fd, UI_SET_ABSBIT, axis)
                low, high = (-1, 1) if axis in (16, 17) else (0, 255) if axis in (2, 5) else (-32768, 32767)
                fcntl.ioctl(self.fd, UI_ABS_SETUP, abs_setup(axis, low, high))
            fcntl.ioctl(self.fd, UI_DEV_SETUP, device_setup(name))
            fcntl.ioctl(self.fd, UI_DEV_CREATE)
            self.created = True
        except BaseException:
            self.close()
            raise

    def close(self):
        if self.fd is not None:
            try:
                if self.created:
                    fcntl.ioctl(self.fd, UI_DEV_DESTROY)
            finally:
                os.close(self.fd)
                self.fd = None
                self.created = False


class Focus:
    def __init__(self, display):
        self.x = ctypes.CDLL('libX11.so.6')
        ptr, win = ctypes.c_void_p, ctypes.c_ulong
        signatures = {
            'XOpenDisplay': ([ctypes.c_char_p], ptr), 'XDefaultRootWindow': ([ptr], win),
            'XCreateSimpleWindow': ([ptr, win, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint,
                                     ctypes.c_uint, ctypes.c_ulong, ctypes.c_ulong], win),
            'XMapWindow': ([ptr, win], ctypes.c_int),
            'XSetInputFocus': ([ptr, win, ctypes.c_int, ctypes.c_ulong], ctypes.c_int),
            'XFlush': ([ptr], ctypes.c_int), 'XDestroyWindow': ([ptr, win], ctypes.c_int),
            'XCloseDisplay': ([ptr], ctypes.c_int),
        }
        for name, (args, result) in signatures.items():
            getattr(self.x, name).argtypes = args
            getattr(self.x, name).restype = result
        self.display = self.x.XOpenDisplay(display.encode())
        if not self.display:
            raise RuntimeError('private X11 display unavailable')
        self.window = self.x.XCreateSimpleWindow(self.display, self.x.XDefaultRootWindow(self.display), 0, 0, 32, 32, 0, 0, 0)
        self.x.XMapWindow(self.display, self.window)
        self.x.XFlush(self.display)

    def set(self, pid, away):
        target = self.window
        if not away:
            output = subprocess.check_output(['xdotool', 'search', '--onlyvisible', '--pid', str(pid)], timeout=3, text=True)
            windows = [int(line) for line in output.splitlines() if line.strip().isdigit()]
            if not windows:
                raise RuntimeError('native process has no visible X11 window')
            target = windows[-1]
        self.x.XSetInputFocus(self.display, target, 1, 0)
        self.x.XFlush(self.display)
        return {'pid': pid, 'focused_window': target, 'away': away, 'notification_injected': False}

    def close(self):
        if self.display:
            self.x.XDestroyWindow(self.display, self.window)
            self.x.XCloseDisplay(self.display)
            self.display = None


class Bridge:
    """A bounded service thread under the serial finish supervisor, not an agent."""
    def __init__(self, directory, display, token):
        self.directory = Path(directory)
        self.display = display
        self.token = token
        self.stop_event = threading.Event()
        self.thread = None
        self.records = []
        self.failures = []
        self.allowed_pid = None

    def start(self):
        self.thread = threading.Thread(target=self._serve, name='fighting-owned-os-fixture', daemon=True)
        self.thread.start()

    def _serve(self):
        pads, focus, completed = [], None, set()
        try:
            while not self.stop_event.wait(.015):
                for path in sorted(self.directory.glob('request-*.json')):
                    if path.name in completed:
                        continue
                    completed.add(path.name)
                    request = json.loads(path.read_text())
                    result = {'id': request.get('id'), 'ok': False, 'at_monotonic': time.monotonic()}
                    try:
                        pid = request['pid']
                        if type(pid) is not int or pid <= 1:
                            raise ValueError('invalid native PID')
                        # First request binds to the actual Godot process, verified
                        # as a descendant of this supervisor, never another session.
                        import finish_runner
                        if pid not in finish_runner.descendants():
                            raise ValueError('request PID is not owned by this supervisor')
                        if self.allowed_pid is None:
                            self.allowed_pid = pid
                        if pid != self.allowed_pid:
                            raise ValueError('native PID changed')
                        operation = request['operation']
                        if operation in ('focus-game', 'focus-away'):
                            if focus is None:
                                focus = Focus(self.display)
                            result.update(focus.set(pid, operation == 'focus-away'))
                        elif operation == 'pad-create':
                            actor = request['actor']
                            if type(actor) is not int or actor not in (0, 1) or len(pads) != actor:
                                raise ValueError('create owned pads sequentially, binding each actual enumeration')
                            pads.append(VirtualPad(f'COCS-Acceptance-{self.token}-P{actor+1}'))
                            result['name'] = pads[-1].name
                        elif operation == 'pad-disconnect':
                            actor = request['actor']
                            if type(actor) is not int or actor not in (0, 1) or len(pads) != 2:
                                raise ValueError('invalid owned pad index')
                            pads[actor].close()
                            result['disconnected_actor'] = actor
                        elif operation == 'pads-destroy':
                            for pad in pads:
                                pad.close()
                            pads.clear()
                        else:
                            raise ValueError('unknown bounded bridge operation')
                        result['ok'] = True
                    except Exception as error:
                        result['error'] = str(error)
                        self.failures.append(result)
                    self.records.append({'request': request, 'response': result})
                    target = self.directory / f"response-{int(request['id']):04d}.json"
                    temporary = target.with_suffix('.tmp')
                    temporary.write_text(json.dumps(result))
                    temporary.replace(target)
        except Exception as error:
            self.failures.append({'error': str(error)})
        finally:
            for pad in pads:
                pad.close()
            if focus:
                focus.close()

    def close(self):
        self.stop_event.set()
        if self.thread:
            self.thread.join(timeout=5)
            if self.thread.is_alive():
                self.failures.append({'error': 'OS bridge did not terminate'})
        return {'records': self.records, 'failures': self.failures, 'physical_hardware': 'not exercised'}
