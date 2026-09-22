#!/usr/bin/env python3
"""Isolated native verification; does not connect to the shared gallery or any service."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
from native_input import verify as verify_native_input

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ENGINE = "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=DEFAULT_ENGINE)
    parser.add_argument("--steps", default="import,parse,physics,smoke,native-input,gallery")
    args = parser.parse_args()
    evidence = ROOT / "port/native-showcase/evidence"
    evidence.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="run-", dir=evidence))
    private = Path(tempfile.mkdtemp(prefix="prism-home-", dir="/tmp/opencode"))
    env = os.environ.copy()
    for variable, child in [("HOME", "home"), ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"), ("XDG_RUNTIME_DIR", "runtime")]:
        path = private / child
        path.mkdir(mode=0o700)
        env[variable] = str(path)
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    steps = args.steps.split(",")
    summary = {"engine": args.godot, "software_renderer": True, "steps": []}
    base = [args.godot, "--path", str(ROOT / "godot"), "--audio-driver", "Dummy"]
    xvfb = None

    def execute(name, command, timeout=180):
        started = time.monotonic()
        with (run / (name + ".log")).open("w") as logfile:
            try:
                result = subprocess.run(command, env=env, stdout=logfile, stderr=subprocess.STDOUT, timeout=timeout)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
                logfile.write("\nHARNESS_TIMEOUT seconds=" + str(timeout) + "\n")
        text = (run / (name + ".log")).read_text()
        errors = any(token in text for token in ["SCRIPT ERROR:", "SHADER ERROR:", "Parse Error:", "ERROR:"])
        item = {"name": name, "command": command, "exit_code": code, "errors": errors, "wall_seconds": round(time.monotonic() - started, 2)}
        summary["steps"].append(item)
        (run / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(name, "PASS" if code == 0 and not errors else "FAIL", str(run), flush=True)
        if code or errors:
            print(text[-18000:])
            return False
        return True

    try:
        if "import" in steps and not execute("import", base + ["--headless", "--editor", "--import"], 240): return 1
        if "parse" in steps:
            for script in ["showcase/demo.gd", "tests/showcase/physics.gd", "tests/showcase/gallery.gd", "tests/showcase/native_controls.gd"]:
                if not execute("parse-" + Path(script).stem, base + ["--headless", "--check-only", "--script", "res://" + script], 30): return 1
        if any(step in steps for step in ["physics", "smoke", "native-input", "gallery"]):
            # -nolisten unix suppresses filesystem sockets; Xlib uses the private Linux abstract socket.
            for display in range(121, 220):
                probe = socket.socket(socket.AF_UNIX)
                try:
                    probe.connect("\0/tmp/.X11-unix/X" + str(display))
                except OSError:
                    break
                finally:
                    probe.close()
            xvfb_log = (run / "xvfb.log").open("w")
            xvfb = subprocess.Popen(["Xvfb", ":" + str(display), "-screen", "0", "1280x800x24", "-nolisten", "tcp", "-nolisten", "unix", "-noreset"], stdout=xvfb_log, stderr=subprocess.STDOUT, env=env)
            env["DISPLAY"] = ":" + str(display)
            for _ in range(100):
                probe = socket.socket(socket.AF_UNIX)
                try:
                    probe.connect("\0/tmp/.X11-unix/X" + str(display))
                    break
                except OSError:
                    time.sleep(0.05)
                finally:
                    probe.close()
            else:
                raise RuntimeError("private Xvfb did not start")
        if "physics" in steps and not execute("physics", base + ["--rendering-method", "gl_compatibility", "--disable-render-loop", "--fixed-fps", "60", "--script", "res://tests/showcase/physics.gd"], 240): return 1
        if "smoke" in steps and not execute("smoke", base + ["--rendering-method", "gl_compatibility", "--resolution", "960x640", "res://showcase/demo.tscn", "--", "--smoke"]): return 1
        if "native-input" in steps:
            ok = verify_native_input(base, env, run)
            summary["steps"].append({"name": "native-input", "passed": ok})
            (run / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
            print("native-input", "PASS" if ok else "FAIL", str(run), flush=True)
            if not ok: return 1
        if "gallery" in steps:
            for size in ["960x640", "1280x800"]:
                if not execute("gallery-" + size, base + ["--rendering-method", "gl_compatibility", "--resolution", size, "--script", "res://tests/showcase/gallery.gd", "--", "--output=" + str(run), "--size=" + size], 240): return 1
        return 0
    finally:
        if xvfb:
            xvfb.terminate()
            xvfb.wait(timeout=10)


if __name__ == "__main__":
    raise SystemExit(main())
