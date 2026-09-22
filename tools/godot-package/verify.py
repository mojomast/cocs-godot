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


class X11:
    """Only the verifier uses Xlib; the artifact has no automation dependency."""
    def __init__(self, display):
        self.lib = C.CDLL(ctypes.util.find_library('X11'))
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
            'XKeysymToKeycode': (C.c_ubyte, [C.c_void_p, C.c_ulong]),
            'XSync': (C.c_int, [C.c_void_p, C.c_int]),
        }
        for name, (result, args) in bindings.items():
            function = getattr(self.lib, name)
            function.restype, function.argtypes = result, args
        self.display = self.lib.XOpenDisplay(display.encode())
        require(self.display, 'Cannot open private Xvfb display')
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

    def window(self, pid):
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

    def close(self):
        self.lib.XCloseDisplay(self.display)

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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-result', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--world-commands-capture', action='store_true', help='Send X11 C to the exported world and save a panel image for direct review')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    build = json.loads(args.build_result.read_text())
    archive = Path(build['archive'])
    require(sha(archive) == build['archive_sha256'], 'Archive SHA mismatch')
    fresh = Path(tempfile.mkdtemp(prefix='cocs-package-play-', dir='/tmp/opencode'))
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
    for name, checksum in manifest['files'].items():
        require(sha(package / name) == checksum, f'File checksum mismatch: {name}')
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

        def launch(name, cli, action='window', active=True, trace=True):
            log = output / (name + '.log')
            with log.open('w') as stream:
                process = subprocess.Popen([nodebin / 'node', package / 'run.mjs', *cli], cwd=unrelated, env=env, stdout=stream, stderr=subprocess.STDOUT)
            children.append(process)
            deadline = time.monotonic() + 35
            earliest_setup = time.monotonic() + 8
            ready, native, frames, health = None, None, [], None
            while time.monotonic() < deadline:
                text = log.read_text()
                ready_records = records(text, 'PACKAGE_SERVER_READY ')
                native_records = records(text, 'PACKAGE_NATIVE_STARTED ')
                ready = ready_records[0] if ready_records else None
                native = native_records[0] if native_records else None
                frames = records(text, 'PORT_NATIVE_TRACE ')
                if ready and native and native.get('pid') and x11.window(native['pid']):
                    if ((not active or not trace) and time.monotonic() >= earliest_setup) or (active and trace and any(f['event'] == 'round_start' for f in frames) and sum(f['event'] == 'snapshot' and f.get('pose_present') and f.get('phase') == 3 for f in frames) >= 3):
                        break
                require(process.poll() is None, f'{name}: launcher exited early; see {log}')
                time.sleep(0.05)
            else:
                raise RuntimeError(f'{name}: actual started/snapshot/window evidence timed out; see {log}')
            native_pid = native['pid']
            with urllib.request.urlopen(f"http://127.0.0.1:{ready['port']}/", timeout=5) as response:
                health = json.load(response)
            require(health['port'] == ready['port'], 'Dynamic owned health port mismatch')
            if active:
                require(health['players'] == 1 and health['rooms'] == ready['health']['rooms'] + 1 and health['snapshot']['fullFrames'] > 0, f'{name}: real authority did not publish snapshots')
            else:
                require(health['players'] == 0 and health['rooms'] == ready['health']['rooms'] and health['snapshot']['fullFrames'] == 0, 'Native setup should wait for user Start')
            if action == 'window':
                shot = subprocess.run(['/usr/bin/ffmpeg', '-loglevel', 'error', '-f', 'x11grab', '-video_size', '1280x800', '-i', env['DISPLAY'], '-frames:v', '1', '-threads', '1', '-update', '1', str(output / (name + '.png'))], cwd=unrelated, env=env, capture_output=True, timeout=20)
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
            require(not Path(f'/proc/{native_pid}').exists(), f'{name}: native process survived')
            with socket.socket() as connection:
                require(connection.connect_ex(('127.0.0.1', ready['port'])) != 0, f'{name}: owned server port survived')
            require('SCRIPT ERROR' not in text and 'ERROR:' not in text, f'{name}: Godot error in native log')
            result = {'case':name, 'exit':code, 'scene':native['scene'], 'host':ready['host'], 'dynamic_port':ready['port'], 'health':health, 'readiness':'setup-window' if not active else ('native-trace' if trace else 'authority-traffic-and-window; inspect PNG separately'), 'round_start_seen':any(f['event'] == 'round_start' for f in frames), 'pose_snapshots_seen':sum(f['event'] == 'snapshot' and f.get('pose_present') for f in frames), 'native_pid':native_pid, 'native_closed':True, 'server_closed':True, 'action':action}
            results.append(result)
            (output / 'cases.json').write_text(json.dumps(results, indent=2) + '\n')
            print(name, 'PASS', flush=True)

        launch('host-setup', [], active=False)
        launch('combat', ['--play','--native-trace'])
        launch('lattice-world', ['--experience=lattice-world','--map=monsoon-foundry','--mode=cocs-coop','--native-trace'])
        # These standalone routes do not expose the combat trace option. Require
        # actual authority traffic and review their exported HUD screenshots;
        # never substitute a fixed wait for gameplay-completion evidence.
        launch('domination', ['--experience=zones','--map=meridian-exchange','--mode=domination'], trace=False)
        launch('koth', ['--experience=zones','--map=verdant-reliquary','--mode=koth'], trace=False)
        launch('combined-arms', ['--experience=combined-arms'], trace=False)
        launch('race', ['--experience=sports','--map=ion-speedway'], trace=False)
        launch('soccer', ['--experience=sports','--map=aurora-stadium'], trace=False)
        launch('interrupt', ['--play','--native-trace'], action='interrupt')
        launch('native-crash', ['--play','--native-trace'], action='crash')
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
        # Final byte equality and file inventory, including the executable restored
        # after the failure test; no hidden project/import cache may appear.
        require({p.relative_to(package).as_posix() for p in package.rglob('*') if p.is_file()} == set(manifest['files']) | {'manifest.json'}, 'Play added package files')
        for name, checksum in manifest['files'].items():
            require(sha(package / name) == checksum, f'Play changed package bytes: {name}')
        source_check = subprocess.run(['node', '--input-type=module', '-e', "import {verifySource} from './tools/godot-export/semantic.mjs'; import fs from 'node:fs'; verifySource(JSON.parse(fs.readFileSync('port/contracts/source-lock.json')));"], cwd=ROOT, capture_output=True, text=True, timeout=30)
        require(source_check.returncode == 0, 'Locked source changed')
        summary = {'passed':True, 'archive_sha256':build['archive_sha256'], 'manifest_sha256':build['manifest_sha256'], 'fresh_directory':str(fresh), 'play_cwd':str(unrelated), 'play_PATH':env['PATH'], 'no_git':True, 'no_editor_git_npm_on_PATH':True, 'no_package_symlinks':True, 'no_original_checkout_paths':True, 'locked_source_unchanged':True, 'package_bytes_unchanged':True, 'release_probe':records(probe.stdout, 'PACKAGE_INSPECT_OK ')[0], 'cases':results, 'invalid_arguments_rejected_before_server':True, 'spawn_failure_cleaned_up':True, 'xvfb_arguments':['-nolisten','tcp','-nolisten','unix'], 'test_audio':'private ALSA null sink', 'verification_inputs':{p:sha(ROOT / p) for p in ['tools/godot-package/verify.py','godot/tests/package_inspect.gd']}}
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
