"""XTest input and OS focus-loss verification on the harness's private X display."""
import ctypes as C
import json
from pathlib import Path
import subprocess
import time


def verify(base, env, output):
    output = Path(output)
    log = (output / "native-input.log").open("w")
    command = base + ["--rendering-method", "gl_compatibility", "--resolution", "960x640", "--script", "res://tests/showcase/native_controls.gd", "--", "--control-dir=" + str(output)]
    process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
    x = C.CDLL("libX11.so.6")
    xt = C.CDLL("libXtst.so.6")
    display_type, window_type = C.c_void_p, C.c_ulong
    x.XOpenDisplay.argtypes, x.XOpenDisplay.restype = [C.c_char_p], display_type
    x.XDefaultRootWindow.argtypes, x.XDefaultRootWindow.restype = [display_type], window_type
    x.XQueryTree.argtypes = [display_type, window_type, C.POINTER(window_type), C.POINTER(window_type), C.POINTER(C.POINTER(window_type)), C.POINTER(C.c_uint)]
    x.XFetchName.argtypes = [display_type, window_type, C.POINTER(C.c_char_p)]
    x.XFree.argtypes = [C.c_void_p]
    x.XSetInputFocus.argtypes = [display_type, window_type, C.c_int, C.c_ulong]
    x.XStringToKeysym.argtypes, x.XStringToKeysym.restype = [C.c_char_p], C.c_ulong
    x.XKeysymToKeycode.argtypes, x.XKeysymToKeycode.restype = [display_type, C.c_ulong], C.c_uint
    x.XFlush.argtypes = [display_type]
    x.XCloseDisplay.argtypes = [display_type]
    xt.XTestFakeKeyEvent.argtypes = [display_type, C.c_uint, C.c_int, C.c_ulong]
    xt.XTestFakeButtonEvent.argtypes = [display_type, C.c_uint, C.c_int, C.c_ulong]
    xt.XTestFakeRelativeMotionEvent.argtypes = [display_type, C.c_int, C.c_int, C.c_ulong]
    display = x.XOpenDisplay(env["DISPLAY"].encode())
    if not display: raise RuntimeError("Cannot open private X display")
    root = x.XDefaultRootWindow(display)
    checks = []

    def state():
        return json.loads((output / "state.json").read_text())

    def wait_for(predicate, timeout=15):
        deadline = time.monotonic() + timeout
        last = None
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError("Native observer exited before input completed")
            try:
                last = state()
                if predicate(last): return last
            except (FileNotFoundError, json.JSONDecodeError):
                pass
            time.sleep(0.08)
        raise AssertionError("Native observation timeout: " + str(last))

    def key(name, down):
        code = x.XKeysymToKeycode(display, x.XStringToKeysym(name.encode()))
        xt.XTestFakeKeyEvent(display, code, int(down), 0)
        x.XFlush(display)

    def tap(name):
        key(name, True)
        time.sleep(0.12)
        key(name, False)

    def click():
        xt.XTestFakeButtonEvent(display, 1, 1, 0)
        xt.XTestFakeButtonEvent(display, 1, 0, 0)
        x.XFlush(display)

    def record(name, before, after):
        checks.append({"check": name, "before": before, "after": after})

    try:
        before = wait_for(lambda s: s["on_floor"])
        root_ret, parent_ret = window_type(), window_type()
        children, count = C.POINTER(window_type)(), C.c_uint()
        x.XQueryTree(display, root, C.byref(root_ret), C.byref(parent_ret), C.byref(children), C.byref(count))
        window = None
        for index in range(count.value):
            title = C.c_char_p()
            if x.XFetchName(display, children[index], C.byref(title)):
                if title.value and b"Prism Foundry" in title.value: window = int(children[index])
                x.XFree(title)
        x.XFree(children)
        if window is None: raise AssertionError("Native Godot window missing")
        x.XSetInputFocus(display, window, 2, 0)
        x.XFlush(display)
        click()
        before = wait_for(lambda s: s["focus"] and s["mouse_mode"] == 2)
        key("w", True)
        after = wait_for(lambda s: s["position"][2] < before["position"][2] - 1.5)
        record("OS physical W moves native character", before, after)
        key("Shift_L", True)
        # Lose native OS focus with movement and sprint still held.
        x.XSetInputFocus(display, root, 2, 0)
        x.XFlush(display)
        lost = wait_for(lambda s: not s["focus"] and s["mouse_mode"] == 0 and not s["keys"])
        time.sleep(0.5)
        stopped = state()
        assert abs(stopped["position"][2] - lost["position"][2]) < 0.10
        record("OS focus loss clears held movement and releases cursor", lost, stopped)
        key("w", False)
        key("Shift_L", False)
        x.XSetInputFocus(display, window, 2, 0)
        x.XFlush(display)
        wait_for(lambda s: s["focus"])
        click()
        captured = wait_for(lambda s: s["mouse_mode"] == 2)
        record("native click recaptures", stopped, captured)
        xt.XTestFakeRelativeMotionEvent(display, 44, -17, 0)
        x.XFlush(display)
        looked = wait_for(lambda s: abs(s["yaw"] - captured["yaw"]) > 0.05 and s["pitch"] > captured["pitch"] + 0.015)
        record("OS relative mouse changes yaw and pitch", captured, looked)
        tap("space")
        jumped = wait_for(lambda s: s["position"][1] > 0.35)
        record("OS Space jumps", looked, jumped)
        wait_for(lambda s: s["on_floor"])
        tap("Escape")
        released = wait_for(lambda s: s["mouse_mode"] == 0)
        record("OS Escape releases", jumped, released)
        click()
        wait_for(lambda s: s["mouse_mode"] == 2)
        tap("r")
        reset = wait_for(lambda s: s["reset_count"] > released["reset_count"])
        assert abs(reset["position"][2] - 15) < 0.2
        record("OS R resets to spawn", released, reset)
        tap("p")
        photo = wait_for(lambda s: s["tour"] == 0)
        tap("bracketright")
        next_view = wait_for(lambda s: s["tour"] == 1)
        tap("p")
        walking = wait_for(lambda s: s["tour"] == -1)
        record("OS P / bracket / P photo tour returns to exploration", photo, walking)
        (output / "finish").touch()
        process.wait(timeout=15)
        text = (output / "native-input.log").read_text()
        assert process.returncode == 0 and "ERROR:" not in text
        (output / "native-input.json").write_text(json.dumps({"passed": True, "checks": checks, "command": command}, indent=2) + "\n")
        return True
    except Exception as error:
        (output / "native-input.json").write_text(json.dumps({"passed": False, "error": str(error), "checks": checks, "command": command}, indent=2) + "\n")
        print("Native input failure:", error, flush=True)
        return False
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        x.XCloseDisplay(display)
        log.close()
