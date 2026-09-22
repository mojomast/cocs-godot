#!/usr/bin/env python3
"""Production combat review with actual X11 input and passive snapshot observation."""
import argparse
import gzip
import importlib.util
import json
import os
from pathlib import Path
import select
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT = ROOT.parent / "godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"
spec = importlib.util.spec_from_file_location("native_x11_review", ROOT / "port/native-graphics-independent/review.py")
x11_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(x11_module)


def stop(process):
    if process is None or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--map", default="meridian-exchange")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    results = []
    server = display = game = x = None
    summary = {"passed": False, "graphical": True, "platform": "Linux X11 / llvmpipe", "input": "XTest OS events", "state_injection": False, "checks": results}
    with tempfile.TemporaryDirectory(prefix="combat-input-review-", dir=os.environ.get("TMPDIR", "/tmp/opencode")) as temporary:
        private = Path(temporary)
        env = {**os.environ, "HOME": str(private), "LIBGL_ALWAYS_SOFTWARE": "1", "LP_NUM_THREADS": "2", "PORT": "0"}
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR"]:
            path = private / key
            path.mkdir(mode=0o700)
            env[key] = str(path)
        env.update(COMBAT_REVIEW_OUTPUT=str(output), COMBAT_REVIEW_SCENE="res://world/session.tscn")
        with (output / "server.log").open("w") as server_log, (output / "xvfb.log").open("w") as display_log, (output / "native.log").open("w") as native_log:
            try:
                ready = private / "authority.json"
                server = subprocess.Popen(["node", str(ROOT / "port/native-player-models/server.mjs"), str(ready)], cwd=ROOT, env=env, stdout=server_log, stderr=subprocess.STDOUT)
                deadline = time.monotonic() + 15
                while not ready.exists():
                    if server.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError("Private authority readiness failed")
                    time.sleep(.05)
                port = json.loads(ready.read_text())["port"]
                read_fd, write_fd = os.pipe()
                try:
                    display = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp", "-nolisten", "unix"], env=env, pass_fds=[write_fd], stdout=display_log, stderr=subprocess.STDOUT)
                    os.close(write_fd)
                    if not select.select([read_fd], [], [], 10)[0]:
                        raise RuntimeError("Private X11 display readiness failed")
                    env["DISPLAY"] = ":" + os.read(read_fd, 64).decode().strip()
                finally:
                    os.close(read_fd)
                x = x11_module.X11(env["DISPLAY"])
                command = [os.environ.get("GODOT_BIN", str(DEFAULT_GODOT)), "--path", str(ROOT / "godot"), "--script", str(ROOT / "port/combat-expansion/observe.gd"), "--display-driver", "x11", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--resolution", "960x640", "--position", "0,0", "--", f"--endpoint=ws://127.0.0.1:{port}", f"--map={args.map}", "--mode=deathmatch", "--mute"]
                summary["command"] = command
                game = subprocess.Popen(command, cwd=ROOT, env=env, stdout=native_log, stderr=subprocess.STDOUT)

                def wait_file(path, condition=lambda value: True, timeout=20):
                    until = time.monotonic() + timeout
                    while time.monotonic() < until:
                        try:
                            value = json.loads(path.read_text())
                            if condition(value):
                                return value
                        except (FileNotFoundError, json.JSONDecodeError):
                            pass
                        if game.poll() is not None:
                            raise RuntimeError("Production client exited before observation")
                        time.sleep(.05)
                    raise RuntimeError("Timed out waiting for " + path.name)

                def state(predicate):
                    return wait_file(output / "latest.json", predicate)

                def mark(name, capture=True, finish=False):
                    request = output / "request.pending"
                    request.write_text(json.dumps({"marker": name, "capture": capture, "finish": finish}))
                    request.replace(output / "request.json")
                    return wait_file(output / (name + ".json"))

                def check(name, condition, **detail):
                    results.append({"name": name, "passed": bool(condition), **detail})
                    if not condition:
                        raise AssertionError(name)

                wait_file(output / "ready.json")
                state(lambda row: row["phase"] == 3 and row["actor"].get("health", 0) > 0)
                windows = x.windows()
                if not windows:
                    raise RuntimeError("No native review window")
                window = windows[0][0]
                x.focus(window)
                x.click(480, 320)
                state(lambda row: row["captured"] and row["rig_showing"])
                hip = mark("hip-960x640")
                x.button(3, True)
                aimed = state(lambda row: row["actor"].get("ads") is True and row["fov"] < hip["fov"] - 1)
                check("RMB reaches authoritative ADS and narrows production FOV", aimed["rig_showing"], hip_fov=hip["fov"], ads_fov=aimed["fov"])
                mark("ads-960x640")
                x.button(3, False)
                state(lambda row: row["actor"].get("ads") is False)
                check("RMB release reaches authoritative hip state", True)
                x.button(3, True)
                state(lambda row: row["actor"].get("ads") is True)
                x.key("d", True)
                x.tap("Escape")
                released = state(lambda row: not row["captured"] and row["actor"].get("ads") is False)
                check("Escape cancels ADS with RMB held", not released.get("aim_requested", True))
                mark("escaped-held", capture=False)
                x.key("d", False)
                x.button(3, False)
                x.click(480, 320)
                x.button(3, True)
                state(lambda row: row["actor"].get("ads") is True)
                x.focus(x.root)
                unfocused = state(lambda row: not row["focused"] and not row["captured"] and row["actor"].get("ads") is False)
                check("Real focus loss cancels source ADS", not unfocused.get("aim_requested", True))
                x.button(3, False)
                x.focus(window)
                x.click(480, 320)
                state(lambda row: row["captured"] and row["actor"].get("ads") is False)
                check("Refocus requires fresh ADS input", True)
                x.x.XResizeWindow(x.d, window, 1280, 800)
                x.flush()
                time.sleep(.5)
                mark("hip-1280x800")
                x.button(3, True)
                state(lambda row: row["actor"].get("ads") is True)
                mark("ads-1280x800")
                x.button(1, True)
                time.sleep(.8)
                x.button(1, False)
                mark("ads-fire-1280x800")
                x.button(3, False)
                finished = mark("finished", capture=False, finish=True)
                game.wait(timeout=15)
                native_log.flush()
                text = (output / "native.log").read_text()
                check("Clean native exit", game.returncode == 0 and "ERROR:" not in text)
                raw = (output / "recording.json").read_bytes()
                recording = json.loads(raw)
                check("Public snapshots and local source fire observed", len(recording["snapshots"]) > 30 and any(event.get("type") in ["shot", "launch"] and event.get("actor") == finished["actor"].get("id") for event in recording["events"]))
                (output / "recording.json.gz").write_bytes(gzip.compress(raw, mtime=0))
                (output / "recording.json").unlink()
                summary["passed"] = True
            except Exception as error:
                summary["error"] = str(error)
            finally:
                stop(game)
                stop(server)
                if x is not None:
                    x.x.XCloseDisplay(x.d)
                stop(display)
                summary["cleanup"] = {"client": None if game is None else game.returncode, "authority": None if server is None else server.returncode, "display": None if display is None else display.returncode}
                (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))
    if not summary["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
