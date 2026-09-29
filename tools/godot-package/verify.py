"""Extract a private artifact into an unrelated directory and exercise real exports."""
import argparse
import ctypes as C
import ctypes.util
import hashlib
import json
import os
from pathlib import Path
import select
import shutil
import signal
import socket
import subprocess
import tarfile
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[2]


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def records(text, prefix):
    # A live file may end halfway through a JSON write; only complete lines count.
    return [json.loads(line[len(prefix):]) for line in text.splitlines(keepends=True) if line.startswith(prefix) and line.endswith('\n')]


VALIDATOR = ROOT / 'tools/godot-package/manifest_validation.mjs'


def validate_artifact(package, repo, output, label):
    """Run the one shared artifact validator; never forward an ambient derivative.

    `COCS_SOURCE_DERIVATIVE` is stripped so source identity can only come from the
    package manifest plus the git objects at the commits it records.
    """
    node = shutil.which('node') or 'node'
    env = {key: value for key, value in os.environ.items() if key != 'COCS_SOURCE_DERIVATIVE'}
    result = subprocess.run([node, str(VALIDATOR), '--package', str(package), '--repo', str(repo), '--json'],
                            cwd=ROOT, env=env, capture_output=True, text=True, timeout=300)
    (output / (label + '.json')).write_text(result.stdout + (result.stderr or ''))
    require(result.returncode == 0, f'Artifact validation failed: {result.stdout.strip() or result.stderr.strip()}')
    return json.loads(result.stdout)


class X11:
    """Only the verifier uses Xlib; the artifact has no automation dependency."""
    def __init__(self, display):
        self.lib = C.CDLL(ctypes.util.find_library('X11'))
        # Helper windows can disappear after XQueryTree and before property reads.
        # Xlib's default handler exits the process, bypassing owned cleanup. Keep
        # that expected discovery race nonfatal and surface other errors in Python.
        class ErrorEvent(C.Structure):
            _fields_ = [('type', C.c_int), ('display', C.c_void_p), ('resourceid', C.c_ulong), ('serial', C.c_ulong), ('error_code', C.c_ubyte), ('request_code', C.c_ubyte), ('minor_code', C.c_ubyte)]
        self.errors = []
        self.discovering = False
        def error_handler(_display, event):
            e = event.contents
            if not (self.discovering and e.error_code == 3 and e.request_code in [14, 15, 20]):
                self.errors.append((e.error_code, e.request_code, e.resourceid))
            return 0
        self.error_handler = C.CFUNCTYPE(C.c_int, C.c_void_p, C.POINTER(ErrorEvent))(error_handler)
        self.lib.XSetErrorHandler.argtypes = [C.c_void_p]
        self.lib.XSetErrorHandler.restype = C.c_void_p
        bindings = {
            'XOpenDisplay': (C.c_void_p, [C.c_char_p]),
            'XDefaultRootWindow': (C.c_ulong, [C.c_void_p]),
            'XQueryTree': (C.c_int, [C.c_void_p, C.c_ulong, C.POINTER(C.c_ulong), C.POINTER(C.c_ulong), C.POINTER(C.POINTER(C.c_ulong)), C.POINTER(C.c_uint)]),
            'XInternAtom': (C.c_ulong, [C.c_void_p, C.c_char_p, C.c_int]),
            'XFetchName': (C.c_int, [C.c_void_p, C.c_ulong, C.POINTER(C.c_char_p)]),
            'XGetGeometry': (C.c_int, [C.c_void_p, C.c_ulong, C.POINTER(C.c_ulong), C.POINTER(C.c_int), C.POINTER(C.c_int), C.POINTER(C.c_uint), C.POINTER(C.c_uint), C.POINTER(C.c_uint), C.POINTER(C.c_uint)]),
            'XGetWindowProperty': (C.c_int, [C.c_void_p, C.c_ulong, C.c_ulong, C.c_long, C.c_long, C.c_int, C.c_ulong, C.POINTER(C.c_ulong), C.POINTER(C.c_int), C.POINTER(C.c_ulong), C.POINTER(C.c_ulong), C.POINTER(C.c_void_p)]),
            'XFree': (C.c_int, [C.c_void_p]),
            'XSendEvent': (C.c_int, [C.c_void_p, C.c_ulong, C.c_int, C.c_long, C.c_void_p]),
            'XFlush': (C.c_int, [C.c_void_p]),
            'XCloseDisplay': (C.c_int, [C.c_void_p]),
            'XSetInputFocus': (C.c_int, [C.c_void_p, C.c_ulong, C.c_int, C.c_ulong]),
            'XMoveResizeWindow': (C.c_int, [C.c_void_p, C.c_ulong, C.c_int, C.c_int, C.c_uint, C.c_uint]),
            'XKeysymToKeycode': (C.c_ubyte, [C.c_void_p, C.c_ulong]),
            'XSync': (C.c_int, [C.c_void_p, C.c_int]),
        }
        for name, (result, args) in bindings.items():
            function = getattr(self.lib, name)
            function.restype, function.argtypes = result, args
        self.display = self.lib.XOpenDisplay(display.encode())
        require(self.display, 'Cannot open private Xvfb display')
        self.previous_error_handler = self.lib.XSetErrorHandler(C.cast(self.error_handler, C.c_void_p))
        self.root = self.lib.XDefaultRootWindow(self.display)
        # No WM runs on this private display. Godot queries WM_DELETE_WINDOW
        # with only_if_exists=true during initialization, so register the normal
        # WM protocol atoms before launching it, as a window manager would.
        self.atom('WM_PROTOCOLS')
        self.atom('WM_DELETE_WINDOW')

    def atom(self, name):
        return self.lib.XInternAtom(self.display, name.encode(), 0)

    def windows(self, parent=None):
        root, ancestor, count = C.c_ulong(), C.c_ulong(), C.c_uint()
        children = C.POINTER(C.c_ulong)()
        self.lib.XQueryTree(self.display, self.root if parent is None else parent, C.byref(root), C.byref(ancestor), C.byref(children), C.byref(count))
        values = [children[i] for i in range(count.value)]
        if children:
            self.lib.XFree(children)
        for value in values:
            yield value
            yield from self.windows(value)

    def pid(self, window):
        kind, size, count, rest, value = C.c_ulong(), C.c_int(), C.c_ulong(), C.c_ulong(), C.c_void_p()
        self.lib.XGetWindowProperty(self.display, window, self.atom('_NET_WM_PID'), 0, 1, 0, 0, C.byref(kind), C.byref(size), C.byref(count), C.byref(rest), C.byref(value))
        result = C.cast(value, C.POINTER(C.c_ulong))[0] if value and count.value and size.value == 32 else None
        if value:
            self.lib.XFree(value)
        return result

    def check_errors(self):
        require(not self.errors, f'Unexpected X11 error(s): {self.errors}')

    def window(self, pid):
        self.discovering = True
        try:
            window = self.find_window(pid)
            self.lib.XSync(self.display, 0)
        finally:
            self.discovering = False
        self.check_errors()
        return window

    def find_window(self, pid):
        for window in self.windows():
            name = C.c_char_p()
            self.lib.XFetchName(self.display, window, C.byref(name))
            title = name.value.decode(errors='replace') if name.value else ''
            if name:
                self.lib.XFree(name)
            # Godot also has hidden helper windows carrying the same PID.
            if self.pid(window) == pid and title.startswith('COCS'):
                root, x, y, width, height, border, depth = C.c_ulong(), C.c_int(), C.c_int(), C.c_uint(), C.c_uint(), C.c_uint(), C.c_uint()
                self.lib.XGetGeometry(self.display, window, C.byref(root), C.byref(x), C.byref(y), C.byref(width), C.byref(height), C.byref(border), C.byref(depth))
                if width.value >= 640 and height.value >= 400:
                    return window
        return None

    def close_window(self, window):
        class ClientMessage(C.Structure):
            _fields_ = [('type', C.c_int), ('serial', C.c_ulong), ('send_event', C.c_int), ('display', C.c_void_p), ('window', C.c_ulong), ('message_type', C.c_ulong), ('format', C.c_int), ('data', C.c_long * 5)]
        event = ClientMessage(type=33, send_event=1, display=self.display, window=window, message_type=self.atom('WM_PROTOCOLS'), format=32)
        event.data[0] = self.atom('WM_DELETE_WINDOW')
        # XEvent is a 24-long union; do not let XSendEvent read a short struct.
        buffer = C.create_string_buffer(C.sizeof(C.c_long) * 24)
        C.memmove(buffer, C.byref(event), C.sizeof(event))
        require(self.lib.XSendEvent(self.display, window, 0, 0, buffer), 'WM_DELETE_WINDOW failed')
        self.lib.XFlush(self.display)
        self.lib.XSync(self.display, 0)
        self.check_errors()

    def resize(self, window, width, height):
        self.lib.XMoveResizeWindow(self.display, window, 0, 0, width, height)
        self.lib.XSync(self.display, 0)
        self.check_errors()
        root, x, y, w, h, border, depth = C.c_ulong(), C.c_int(), C.c_int(), C.c_uint(), C.c_uint(), C.c_uint(), C.c_uint()
        require(self.lib.XGetGeometry(self.display, window, C.byref(root), C.byref(x), C.byref(y), C.byref(w), C.byref(h), C.byref(border), C.byref(depth)), 'Window geometry unavailable')
        require((w.value, h.value) == (width, height), 'Compact window resize failed')

    def close(self):
        self.lib.XCloseDisplay(self.display)
        self.lib.XSetErrorHandler(self.previous_error_handler)

    def tap_key(self, window, keysym):
        # Optional exported-UI probe only; no test code enters the production PCK.
        library = ctypes.util.find_library('Xtst')
        require(library, 'Optional command-panel capture requires libXtst')
        xtest = C.CDLL(library)
        xtest.XTestFakeKeyEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
        xtest.XTestFakeKeyEvent.restype = C.c_int
        code = self.lib.XKeysymToKeycode(self.display, keysym)
        require(code != 0, 'No keycode for the requested keysym')
        self.lib.XSetInputFocus(self.display, window, 2, 0)
        require(xtest.XTestFakeKeyEvent(self.display, code, 1, 0), 'Key press dispatch failed')
        require(xtest.XTestFakeKeyEvent(self.display, code, 0, 0), 'Key release dispatch failed')
        self.lib.XSync(self.display, 0)
        self.check_errors()

    def click(self, window, x, y):
        xtest = C.CDLL(ctypes.util.find_library('Xtst'))
        xtest.XTestFakeMotionEvent.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_ulong]
        xtest.XTestFakeButtonEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
        self.lib.XSetInputFocus(self.display, window, 2, 0)
        require(xtest.XTestFakeMotionEvent(self.display, -1, x, y, 0), 'Pointer motion failed')
        require(xtest.XTestFakeButtonEvent(self.display, 1, 1, 0), 'Pointer press failed')
        require(xtest.XTestFakeButtonEvent(self.display, 1, 0, 0), 'Pointer release failed')
        self.lib.XSync(self.display, 0)
        self.check_errors()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-result', type=Path, help='archive build-result.json; required for the play verification run')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--package', type=Path, help='already-extracted Linux/Windows package directory: validate structure/identity only, no engine execution')
    parser.add_argument('--repo', type=Path, help='checkout whose source lock and commits anchor identity (defaults to this repository)')
    parser.add_argument('--world-commands-capture', action='store_true', help='Send X11 C to the exported world and save a panel image for direct review')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    repo = (args.repo or ROOT).resolve()
    if args.package is not None:
        # Static structure/source-identity validation that also covers the Windows
        # layout without running the engine. Actual Windows execution stays
        # owner-run; see port/native-shell/package_verification.md.
        validate_artifact(args.package.resolve(), repo, output, 'manifest-validation')
        print('PACKAGE_ARTIFACT_OK', output, flush=True)
        return
    require(args.build_result is not None, '--build-result is required unless --package is given')
    build = json.loads(args.build_result.read_text())
    archive = Path(build['archive'])
    require(sha(archive) == build['archive_sha256'], 'Archive SHA mismatch')
    # Keep the full extracted artifact on the caller's owned evidence volume.
    # A disk-backed --output avoids consuming tmpfs with the consolidated PCK.
    fresh = Path(tempfile.mkdtemp(prefix='cocs-package-play-', dir=output))
    unrelated = fresh / 'unrelated-working-directory'
    unrelated.mkdir()
    nodebin = fresh / 'bin'
    nodebin.mkdir()
    shutil.copy2(shutil.which('node'), nodebin / 'node')
    env = {key:value for key, value in os.environ.items() if key in ['LANG','LC_ALL','LD_LIBRARY_PATH']}
    env.update(PATH=str(nodebin), HOME=str(fresh / 'home'), TMPDIR=str(fresh), GODOT_SILENCE_ROOT_WARNING='1', LIBGL_ALWAYS_SOFTWARE='1')
    for key in ['HOME','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']:
        env.setdefault(key, str(fresh / key))
        Path(env[key]).mkdir(mode=0o700, exist_ok=True)
    # Private null ALSA sink on a machine without an audio device. No shared Pulse
    # service or audio assets are touched; production still uses normal drivers.
    alsa = fresh / 'alsa-null.conf'
    alsa.write_text('pcm.!default { type null }\n')
    env['ALSA_CONFIG_PATH'] = str(alsa)
    with tarfile.open(archive) as compressed:
        for member in compressed.getmembers():
            require(not member.issym() and not member.islnk() and not member.name.startswith('/') and '..' not in Path(member.name).parts, 'Unsafe archive member')
        compressed.extractall(fresh, filter='data')
    package = fresh / 'cocs-native-linux'
    require(not list(package.rglob('.git')), 'Git metadata shipped')
    require(not any(p.is_symlink() for p in package.rglob('*')), 'Symlink shipped')
    require(sha(package / 'manifest.json') == build['manifest_sha256'], 'Manifest SHA mismatch')
    manifest = json.loads((package / 'manifest.json').read_text())
    require(manifest.get('target') == 'linux', f"Unexpected package target: {manifest.get('target')}")
    # One shared validator owns the exact byte inventory, the dynamic runtime
    # closure and the manifest-anchored source identity. It replaces the older
    # hardcoded Horde-adapter allowlist; the closure itself decides what ships.
    validate_artifact(package, ROOT.resolve(), output, 'manifest-validation')
    for name in ['godot','godot4','git','npm']:
        require(shutil.which(name, path=env['PATH']) is None, f'Developer tool on play PATH: {name}')
    # No original checkout paths in any packaged file, including binary/PCK.
    for path in package.rglob('*'):
        if path.is_file():
            content = path.read_bytes()
            require(str(ROOT).encode() not in content and b'/home/mojo/.hermes-instances/fresh/workspace/' not in content, f'Original repository path embedded: {path.name}')
    inspect = fresh / 'package_inspect.gd'
    shutil.copy2(ROOT / 'godot/tests/package_inspect.gd', inspect)
    probe = subprocess.run([package / 'cocs.x86_64', '--headless', '--main-pack', package / 'cocs.pck', '--script', inspect], cwd=unrelated, env=env, capture_output=True, text=True, timeout=30)
    (output / 'release-inspect.log').write_text(probe.stdout + probe.stderr)
    require(probe.returncode == 0 and 'PACKAGE_INSPECT_OK ' in probe.stdout and 'ERROR:' not in probe.stdout + probe.stderr, 'Release resource/feature probe failed')
    readfd, writefd = os.pipe()
    xvfb_log = (output / 'xvfb.log').open('w')
    # Keep local shared-memory transfer available for ffmpeg's X11 grabber.
    # Linux's abstract listener avoids the root-owned filesystem socket path.
    xvfb = subprocess.Popen(['/usr/bin/Xvfb', '-displayfd', str(writefd), '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'], pass_fds=(writefd,), stdout=xvfb_log, stderr=subprocess.STDOUT, env=env)
    os.close(writefd)
    x11 = None
    children = []
    results = []
    try:
        require(select.select([readfd], [], [], 10)[0], 'Xvfb display allocation timed out')
        display = os.read(readfd, 100).decode().strip()
        require(display.isdecimal(), 'Bad private display number')
        env['DISPLAY'] = ':' + display
        x11 = X11(env['DISPLAY'])

        def launch(name, cli, action='window', active=True, trace=True, external=None, expect_map=None, compact=False, start_click=None, connect_click=None):
            log = output / (name + '.log')
            case_env = dict(env)
            if compact:
                settings = output / (name + '-settings.json')
                settings.write_text(json.dumps({'version': 1, 'settings': {'ui_scale': 150, 'window_mode': 'windowed'}}))
                case_env['COCS_SETTINGS_PATH'] = str(settings)
            with log.open('w') as stream:
                process = subprocess.Popen([nodebin / 'node', package / 'run.mjs', *cli], cwd=unrelated, env=case_env, stdout=stream, stderr=subprocess.STDOUT)
            children.append(process)
            deadline = time.monotonic() + 35
            earliest_setup = time.monotonic() + 8
            ready, native, frames, health = None, None, [], None
            start_clicked = False
            connect_clicked = False
            while time.monotonic() < deadline:
                text = log.read_text()
                ready_records = records(text, 'PACKAGE_SERVER_READY ')
                native_records = records(text, 'PACKAGE_NATIVE_STARTED ')
                if external:
                    require(not ready_records, f'{name}: external route created an authority')
                ready = external or (ready_records[0] if ready_records else None)
                native = native_records[0] if native_records else None
                frames = records(text, 'PORT_NATIVE_TRACE ')
                if ready and native and native.get('pid') and x11.window(native['pid']):
                    if connect_click and not connect_clicked and time.monotonic() >= earliest_setup - 4:
                        x11.click(x11.window(native['pid']), *connect_click)
                        connect_clicked = True
                    if start_click and not start_clicked and time.monotonic() >= earliest_setup:
                        # LATTICE intentionally waits for the host's explicit
                        # Start. Use the visible 1280x800 button coordinates;
                        # source snapshots/traces below prove the request worked.
                        x11.click(x11.window(native['pid']), *start_click)
                        start_clicked = True
                    if ((not active or (ready.get('experience') == 'horde' and not trace)) and time.monotonic() >= earliest_setup) or (active and trace and any(f['event'] == 'round_start' for f in frames) and sum(f['event'] == 'snapshot' and f.get('pose_present') and f.get('phase') == 3 for f in frames) >= 3):
                        break
                    if active and (not trace or action == 'window') and time.monotonic() >= earliest_setup:
                        with urllib.request.urlopen(f"http://127.0.0.1:{ready['port']}/", timeout=5) as response:
                            observed = json.load(response)
                        if observed.get('players') == 1 and observed.get('snapshot', {}).get('fullFrames', 0) >= 3:
                            # Release traces may remain in stdout's buffer until
                            # normal close. Require their exact content below.
                            break
                require(process.poll() is None, f'{name}: launcher exited early; see {log}')
                time.sleep(0.05)
            else:
                raise RuntimeError(f'{name}: actual started/snapshot/window evidence timed out; see {log}')
            native_pid = native['pid']
            with urllib.request.urlopen(f"http://127.0.0.1:{ready['port']}/", timeout=5) as response:
                health = json.load(response)
            require(health['port'] == ready['port'], 'Dynamic owned health port mismatch')
            if ready.get('experience') == 'horde':
                from horde_verify import health_identity
                health_identity(health, ready['port'])
            elif active:
                require(health['players'] == 1 and health['rooms'] == ready['health']['rooms'] + 1 and health['snapshot']['fullFrames'] > 0, f'{name}: real authority did not publish snapshots')
            else:
                require(health['players'] == 0 and health['rooms'] == ready['health']['rooms'] and health['snapshot']['fullFrames'] == 0, 'Native setup should wait for user Start')
            # The launcher's own readiness record names the source map it selected;
            # for the identity routes that is the only client-side evidence without
            # inventing a readiness probe.
            if expect_map is not None:
                require(ready.get('map') == expect_map, f'{name}: launcher reported map {ready.get("map")}, expected {expect_map}')
            if compact:
                x11.resize(x11.window(native_pid), 760, 520)
                # Allow the exported Control tree to reflow before readback.
                # PNG inspection, not the delay, establishes content visibility.
                time.sleep(0.5)
            if action == 'window':
                shot = subprocess.run(['/usr/bin/ffmpeg', '-loglevel', 'error', '-f', 'x11grab', '-video_size', '760x520' if compact else '1280x800', '-i', env['DISPLAY'], '-frames:v', '1', '-threads', '1', '-update', '1', str(output / (name + '.png'))], cwd=unrelated, env=env, capture_output=True, timeout=20)
                require(shot.returncode == 0, f'Screenshot failed: {shot.stderr.decode()}')
            if name == 'lattice-world' and args.world_commands_capture:
                x11.tap_key(x11.window(native_pid), ord('c'))
                # Image inspection, not this delay, determines panel visibility.
                time.sleep(0.5)
                shot = subprocess.run(['/usr/bin/ffmpeg', '-loglevel', 'error', '-f', 'x11grab', '-video_size', '1280x800', '-i', env['DISPLAY'], '-frames:v', '1', '-threads', '1', '-update', '1', str(output / 'lattice-world-commands.png')], cwd=unrelated, env=env, capture_output=True, timeout=20)
                require(shot.returncode == 0, f'Command screenshot failed: {shot.stderr.decode()}')
            if action == 'window':
                x11.close_window(x11.window(native_pid))
                expected = 0
            elif action == 'interrupt':
                process.send_signal(signal.SIGINT)
                expected = 130
            else:
                os.kill(native_pid, signal.SIGKILL)
                expected = 1
            try:
                code = process.wait(timeout=12)
            except subprocess.TimeoutExpired:
                raise RuntimeError(f'{name}: close timed out; native_alive={Path(f"/proc/{native_pid}").exists()}; log={log.read_text()[-2000:]}')
            text = log.read_text()
            require(code == expected and 'PACKAGE_STOPPED' in text, f'{name}: cleanup/exit mismatch {code}; see {log}')
            if active and trace and action == 'window':
                frames = records(text, 'PORT_NATIVE_TRACE ')
                require(any(f['event'] == 'round_start' for f in frames)
                        and sum(f['event'] == 'snapshot' and f.get('pose_present') and f.get('phase') == 3 for f in frames) >= 3,
                        f'{name}: exported round/actor trace missing after normal close')
            require(not Path(f'/proc/{native_pid}').exists(), f'{name}: native process survived')
            with socket.socket() as connection:
                connected = connection.connect_ex(('127.0.0.1', ready['port'])) == 0
                require(connected == bool(external), f'{name}: authority ownership violated')
            if external:
                with urllib.request.urlopen(f"http://127.0.0.1:{ready['port']}/", timeout=5) as response:
                    require(json.load(response)['service'] == 'token-arena-game-server', 'External authority stopped responding')
            require('SCRIPT ERROR' not in text and 'ERROR:' not in text, f'{name}: Godot error in native log')
            result = {'case':name, 'exit':code, 'scene':native['scene'], 'host':ready['host'], 'dynamic_port':ready['port'], 'reported_map':ready.get('map'), 'health':health, 'readiness':'local-horde-health-and-window; separate horde-product.json proves snapshots/wave' if ready.get('experience') == 'horde' else ('setup-window' if not active else ('native-trace' if trace else 'authority-traffic-and-window; inspect PNG separately')), 'round_start_seen':any(f['event'] == 'round_start' for f in frames), 'pose_snapshots_seen':sum(f['event'] == 'snapshot' and f.get('pose_present') for f in frames), 'native_pid':native_pid, 'native_closed':True, 'authority_owned_by_launcher':not bool(external), 'server_closed':not bool(external), 'external_authority_preserved':bool(external), 'action':action}
            results.append(result)
            if start_click: result.update(start_click=list(start_click), start_clicked=start_clicked)
            if connect_click: result.update(connect_click=list(connect_click), connect_clicked=connect_clicked)
            if compact: result.update(window=[760, 520], settings_ui_scale=150)
            (output / 'cases.json').write_text(json.dumps(results, indent=2) + '\n')
            print(name, 'PASS', flush=True)

        # Default boot is the shared Home supervisor, which intentionally owns
        # no source server until a route is selected. Observe the actual exported
        # menu child rather than applying the old combat-setup readiness rule.
        home_log = output / 'home.log'
        with home_log.open('w') as stream:
            home = subprocess.Popen([nodebin / 'node', package / 'run.mjs'], cwd=unrelated,
                                    env=env, stdout=stream, stderr=subprocess.STDOUT)
        children.append(home)
        deadline = time.monotonic() + 35
        home_pid, home_window = None, None
        while time.monotonic() < deadline:
            text = home_log.read_text()
            require('PACKAGE_SERVER_READY ' not in text, 'Home created an authority before route selection')
            require(home.poll() is None, 'Home supervisor exited before displaying its menu')
            # Release Godot buffers its small stdout writes until exit. Waiting
            # for MENU_READY here deadlocks an otherwise visible working Home.
            # Observe the actual owned window now, then require its flushed
            # readiness marker after the normal WM_DELETE shutdown below.
            child_list = Path(f'/proc/{home.pid}/task/{home.pid}/children')
            for child_pid in child_list.read_text().split() if child_list.exists() else []:
                window = x11.window(int(child_pid))
                if window:
                    home_pid, home_window = int(child_pid), window
                    break
            if home_window: break
            time.sleep(0.05)
        require(home_window is not None, 'Exported Home window/readiness timed out')
        time.sleep(2)
        shot = subprocess.run(['/usr/bin/ffmpeg', '-loglevel', 'error', '-f', 'x11grab',
                               '-video_size', '1280x800', '-i', env['DISPLAY'], '-frames:v', '1',
                               '-threads', '1', '-update', '1', str(output / 'home.png')],
                              cwd=unrelated, env=env, capture_output=True, timeout=20)
        require(shot.returncode == 0, f'Home screenshot failed: {shot.stderr.decode()}')
        x11.close_window(home_window)
        require(home.wait(timeout=12) == 0, 'Home supervisor did not exit cleanly')
        require(not Path(f'/proc/{home_pid}').exists(), 'Home native process survived')
        text = home_log.read_text()
        require(records(text, 'MENU_READY '), 'Exported Home did not complete menu initialization')
        require('PACKAGE_SERVER_READY ' not in text and 'SCRIPT ERROR' not in text and 'ERROR:' not in text,
                'Home produced an authority or native error')
        results.append({'case':'home', 'exit':0, 'authority_owned_by_launcher':False,
                        'native_pid':home_pid, 'native_closed':True, 'readiness':'exported-menu-marker-and-window'})
        (output / 'cases.json').write_text(json.dumps(results, indent=2) + '\n')
        print('home PASS', flush=True)

        launch('host-setup', ['--experience=combat'], active=False)
        launch('lobby-menu', ['--experience=lobby'], active=False)
        # An independent authority belongs to this verifier, not the launcher.
        # Check actual exported-client close/interrupt without stopping that server.
        external_log = output / 'external-authority.log'
        server_code = '''
import {createGameServer} from './runtime/server/game-server.mjs';
const game=createGameServer({historyPath:null,progressionPath:null});
await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve);});
console.log('EXTERNAL_READY '+JSON.stringify({port:game.server.address().port}));
process.once('SIGTERM',async()=>{for(const socket of game.wss.clients)socket.terminate();game.server.closeAllConnections();await game.close();console.log('EXTERNAL_CLOSED');});
'''
        with external_log.open('w') as stream:
            authority = subprocess.Popen([nodebin / 'node', '--input-type=module', '-e', server_code], cwd=package, env=env, stdout=stream, stderr=subprocess.STDOUT)
        children.append(authority)
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            ready = records(external_log.read_text(), 'EXTERNAL_READY ')
            if ready:
                break
            require(authority.poll() is None, 'External authority startup failed')
            time.sleep(0.05)
        require(bool(ready), 'External authority readiness timed out')
        external_port = ready[0]['port']
        with urllib.request.urlopen(f'http://127.0.0.1:{external_port}/', timeout=5) as response:
            external = {'host':'127.0.0.1', 'port':external_port, 'health':json.load(response)}
        external_cli = ['--experience=lobby', f'--endpoint=ws://127.0.0.1:{external_port}']
        launch('lobby-external', external_cli, active=False, external=external)
        launch('lobby-external-interrupt', external_cli, action='interrupt', active=False, external=external)
        authority.terminate()
        require(authority.wait(timeout=10) == 0 and 'EXTERNAL_CLOSED' in external_log.read_text(), 'Verifier authority cleanup failed')
        with socket.socket() as connection:
            require(connection.connect_ex(('127.0.0.1', external_port)) != 0, 'Verifier authority listener survived')
        launch('combat', ['--play','--native-trace'])
        launch('combat-instagib', ['--play','--map=meridian-exchange','--mode=instagib','--native-trace'])
        launch('lattice-world', ['--experience=lattice-world','--map=monsoon-foundry','--mode=cocs-coop','--native-trace'], start_click=(640, 556))
        launch('lattice-board', ['--experience=lattice','--map=asterion-relay','--mode=cocs'], trace=False, expect_map='asterion-relay', connect_click=(95, 151), start_click=(260, 151))
        # These standalone routes do not expose the combat trace option. Require
        # actual authority traffic and review their exported HUD screenshots;
        # never substitute a fixed wait for gameplay-completion evidence.
        launch('domination', ['--experience=zones','--map=meridian-exchange','--mode=domination'], trace=False)
        launch('koth', ['--experience=zones','--map=verdant-reliquary','--mode=koth'], trace=False)
        # Extracted graphical startup/ownership for each new map/mode pairing.
        # Source-correlated completion/crew journeys are separate gates.
        for mode in ['uplink', 'holdout']:
            for map_id in ['meridian-exchange', 'verdant-reliquary', 'ember-crucible']:
                launch(mode + '-' + map_id, ['--experience=zones', '--mode=' + mode,
                       '--map=' + map_id], trace=False)
        for map_id in ['tidal-citadel', 'sunscar-convoy']:
            launch('assault-' + map_id, ['--experience=assault', '--map=' + map_id], trace=False)
        launch('assault-compact', ['--experience=assault', '--map=sunscar-convoy'], trace=False, compact=True)
        launch('uplink-compact', ['--experience=zones', '--mode=uplink', '--map=meridian-exchange'], trace=False, compact=True)
        launch('combined-arms', ['--experience=combined-arms'], trace=False)
        launch('arms-race', ['--experience=arms-race'], trace=False)
        launch('race', ['--experience=sports','--map=ion-speedway'], trace=False)
        launch('soccer', ['--experience=sports','--map=aurora-stadium'], trace=False)
        launch('interrupt', ['--play','--native-trace'], action='interrupt')
        launch('native-crash', ['--play','--native-trace'], action='crash')
        launch('horde', ['--experience=horde'], trace=False)
        # Cinderwake/Nacre identity horde routes select their own scene from the
        # reviewed options allowlist; require the local horde authority health, the
        # rendered window and the launcher's reported source map, nothing more.
        launch('cinderwake', ['--experience=horde','--map=cinderwake-drydock'], trace=False, expect_map='cinderwake-drydock')
        launch('nacre-horde', ['--experience=horde','--map=nacre-engine'], trace=False, expect_map='nacre-engine')
        launch('horde-native-crash', ['--experience=horde'], trace=False, action='crash')
        from horde_verify import run_cases
        horde_results = run_cases(package, fresh, unrelated, nodebin, env, output, x11, children)
        bad = subprocess.run([nodebin / 'node', package / 'run.mjs', '--experience=sports', '--mode=deathmatch'], cwd=unrelated, env=env, capture_output=True, text=True, timeout=10)
        (output / 'invalid-argument.log').write_text(bad.stdout + bad.stderr)
        require(bad.returncode == 1 and 'PACKAGE_SERVER_READY' not in bad.stdout, 'Invalid arguments started a server')
        binary = package / 'cocs.x86_64'
        absent = package / 'cocs.x86_64.absent'
        binary.rename(absent)
        try:
            failed = subprocess.run([nodebin / 'node', package / 'run.mjs', '--play'], cwd=unrelated, env=env, capture_output=True, text=True, timeout=12)
        finally:
            absent.rename(binary)
        (output / 'missing-binary.log').write_text(failed.stdout + failed.stderr)
        require(failed.returncode == 1 and 'PACKAGE_STOPPED' in failed.stdout and 'ENOENT' in failed.stderr, 'Spawn failure not cleaned up')
        missing_port = records(failed.stdout, 'PACKAGE_SERVER_READY ')[0]['port']
        with socket.socket() as connection:
            require(connection.connect_ex(('127.0.0.1', missing_port)) != 0, 'Spawn failure left server listening')
        require(not [p for p in fresh.glob('cocs-native-*') if p != package], 'Temporary launcher state survived')
        # Final byte equality, file inventory and manifest-anchored source identity
        # after play, including the executable restored after the failure test; no
        # hidden project/import cache may appear and no runtime byte may change.
        validate_artifact(package, ROOT.resolve(), output, 'manifest-validation-final')
        summary = {'passed':True, 'archive_sha256':build['archive_sha256'], 'manifest_sha256':build['manifest_sha256'], 'fresh_directory':str(fresh), 'play_cwd':str(unrelated), 'play_PATH':env['PATH'], 'no_git':True, 'no_editor_git_npm_on_PATH':True, 'no_package_symlinks':True, 'no_original_checkout_paths':True, 'locked_source_unchanged':True, 'package_bytes_unchanged':True, 'release_probe':records(probe.stdout, 'PACKAGE_INSPECT_OK ')[0], 'cases':results, 'invalid_arguments_rejected_before_server':True, 'spawn_failure_cleaned_up':True, 'xvfb_arguments':['-nolisten','tcp','-nolisten','unix'], 'test_audio':'private ALSA null sink', 'verification_inputs':{p:sha(ROOT / p) for p in ['tools/godot-package/verify.py','tools/godot-package/manifest_validation.mjs','godot/tests/package_inspect.gd']}}
        summary['horde_product'] = horde_results
        summary['verification_inputs'].update({p:sha(ROOT / p) for p in ['tools/godot-package/horde_verify.py', 'tools/godot-package/horde_observer.gd', 'tools/godot-package/horde_authority.mjs']})
        (output / 'verification.json').write_text(json.dumps(summary, indent=2) + '\n')
        print('PACKAGE_VERIFY_OK', output, flush=True)
    finally:
        for process in children:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        if x11:
            x11.close()
        os.close(readfd)
        xvfb.terminate()
        xvfb.wait(timeout=10)
        xvfb_log.close()
        # Preserve extracted bytes/evidence for inspection, but never processes.


if __name__ == '__main__':
    main()
