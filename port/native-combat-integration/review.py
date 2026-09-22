#!/usr/bin/env python3
"""Normal-rate production session; private authority/Xvfb, OS inputs, passive observer."""
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
spec = importlib.util.spec_from_file_location("existing_review", ROOT / "port/combat-expansion/input_review.py")
existing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(existing)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    summary = {"passed": False, "platform": "Linux X11 llvmpipe", "normal_rate": True, "state_injection": False, "checks": []}
    game = server = display = x = None
    with tempfile.TemporaryDirectory(prefix="combat-integration-", dir="/tmp/opencode") as temporary:
        private = Path(temporary)
        env = {**os.environ, "HOME": str(private), "LIBGL_ALWAYS_SOFTWARE": "1", "LP_NUM_THREADS": "2", "PORT": "0", "COMBAT_REVIEW_OUTPUT": str(output)}
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR"]:
            path = private / key
            path.mkdir(mode=0o700)
            env[key] = str(path)
        with (output / "server.log").open("w") as server_log, (output / "xvfb.log").open("w") as display_log, (output / "native.log").open("w") as native_log:
            try:
                ready = private / "authority.json"
                server = subprocess.Popen(["node", str(ROOT / "port/native-player-models/server.mjs"), str(ready)], cwd=ROOT, env=env, stdout=server_log, stderr=subprocess.STDOUT)
                deadline = time.monotonic()+15
                while not ready.exists():
                    if server.poll() is not None or time.monotonic()>deadline:
                        raise RuntimeError("Authority readiness failed")
                    time.sleep(.05)
                port = json.loads(ready.read_text())["port"]
                read_fd, write_fd = os.pipe()
                try:
                    display = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp", "-nolisten", "unix"], env=env, pass_fds=[write_fd], stdout=display_log, stderr=subprocess.STDOUT)
                    os.close(write_fd)
                    if not select.select([read_fd], [], [], 10)[0]:
                        raise RuntimeError("Display readiness failed")
                    env["DISPLAY"] = ":"+os.read(read_fd, 64).decode().strip()
                finally:
                    os.close(read_fd)
                x = existing.x11_module.X11(env["DISPLAY"])
                command = [str(existing.DEFAULT_GODOT), "--path", str(ROOT / "godot"), "--script", str(ROOT / "port/native-combat-integration/observe.gd"), "--display-driver", "x11", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--resolution", "800x600", "--position", "0,0", "--", f"--endpoint=ws://127.0.0.1:{port}", "--map=meridian-exchange", "--mode=deathmatch", "--mute"]
                summary["command"] = command
                game = subprocess.Popen(command, cwd=ROOT, env=env, stdout=native_log, stderr=subprocess.STDOUT)

                def wait_file(name, predicate=lambda value: True, timeout=25):
                    until = time.monotonic()+timeout
                    while time.monotonic()<until:
                        try:
                            value = json.loads((output / name).read_text())
                            if predicate(value):
                                return value
                        except (FileNotFoundError, json.JSONDecodeError):
                            pass
                        if game.poll() is not None:
                            raise RuntimeError("Production client exited")
                        time.sleep(.03)
                    raise RuntimeError("Timed out: "+name)

                def state(predicate):
                    return wait_file("latest.json", predicate)

                def mark(name, capture=True, finish=False):
                    request = output / "request.pending"
                    request.write_text(json.dumps({"marker":name,"capture":capture,"finish":finish}))
                    request.replace(output / "request.json")
                    return wait_file(name+".json")

                def check(name, condition, **details):
                    summary["checks"].append({"name": name, "passed": bool(condition), **details})
                    if not condition:
                        raise AssertionError(name)

                wait_file("ready.json")
                state(lambda s:s["phase"]==3 and s["actor"].get("health",0)>0)
                window = x.windows()[0][0]
                x.focus(window)
                x.click(400,300)
                state(lambda s:s["captured"] and s["rig_showing"])
                for width,height in [(800,600),(1280,800)]:
                    x.x.XResizeWindow(x.d, window, width, height)
                    x.flush()
                    state(lambda s:s["viewport"]==[width,height])
                    before = mark(f"hip-{width}x{height}")
                    x.button(3,True)
                    state(lambda s:s["actor"].get("ads") is True and s["fov"]<before["fov"]-1)
                    x.button(1,True)
                    fired = state(lambda s:s["weapon_flashes"]>before["weapon_flashes"] and s["weapon_tracers"]>before["weapon_tracers"])
                    mark(f"ads-fire-{width}x{height}")
                    x.button(1,False)
                    x.button(3,False)
                    check(f"actual source fire reaches animated FX {width}x{height}", fired["legacy_tracers"]==fired["legacy_blasts"]==fired["legacy_moth"]==0, flashes=fired["weapon_flashes"],tracers=fired["weapon_tracers"])
                    state(lambda s:s["actor"].get("ads") is False)
                x.tap("F10")
                state(lambda s:s["telemetry"])
                mark("high-metrics")
                x.tap("F9")
                extreme = state(lambda s:s["quality"]==2 and s["particles"]["allocated_slots"]==1000000)
                # One brief shared-session allocation confirmation; no repeated stress loop.
                mark("extreme-confirmed", capture=False)
                x.tap("F9")
                low = state(lambda s:s["quality"]==0 and s["particles"]["allocated_slots"]==8192)
                mark("low-metrics")
                x.tap("F9")
                state(lambda s:s["quality"]==1 and s["particles"]["allocated_slots"]==32768)
                check("OS F9 High/Extreme/Low/High resizes one pool", extreme["particles"]["pool_nodes"]==low["particles"]["pool_nodes"]==32)
                x.button(3,True)
                state(lambda s:s["actor"].get("ads") is True)
                x.focus(x.root)
                state(lambda s:not s["focused"] and not s["captured"] and s["particles"]["active_emitters"]==0)
                x.button(3,False)
                x.focus(window)
                x.click(640,400)
                recovered = state(lambda s:s["captured"] and s["actor"].get("ads") is False)
                check("focus drains effects and ADS does not resume held", not recovered["aim_requested"])
                mark("finished",capture=False,finish=True)
                game.wait(timeout=20)
                native_log.flush()
                check("clean native exit", game.returncode==0 and "ERROR:" not in (output / "native.log").read_text())
                raw = (output / "recording.json").read_bytes()
                recording = json.loads(raw)
                check("live source evidence saved", len(recording["snapshots"])>20 and any(e.get("type")=="shot" and e.get("actor")==0 for e in recording["events"]))
                (output / "recording.json.gz").write_bytes(gzip.compress(raw,mtime=0))
                (output / "recording.json").unlink()
                summary["passed"] = True
            except Exception as error:
                summary["error"] = str(error)
            finally:
                existing.stop(game)
                existing.stop(server)
                if x is not None:
                    x.x.XCloseDisplay(x.d)
                existing.stop(display)
                summary["cleanup"] = {"client":None if game is None else game.returncode,"authority":None if server is None else server.returncode,"display":None if display is None else display.returncode}
                (output / "summary.json").write_text(json.dumps(summary,indent=2)+"\n")
    print(json.dumps(summary,indent=2))
    if not summary["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
