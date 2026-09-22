#!/usr/bin/env python3
"""Reproducible native map verification and GL evidence, in a private environment."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path("/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["import", "verify", "capture", "smoke"])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--size", default="1280x800", choices=["960x640", "1280x800"])
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="cinder-env-", dir="/tmp/opencode") as temporary:
        private = Path(temporary)
        env = dict(os.environ)
        for key, folder in [("HOME", "home"), ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"), ("XDG_RUNTIME_DIR", "runtime")]:
            path = private / folder
            path.mkdir(mode=0o700)
            env[key] = str(path)
        env["LIBGL_ALWAYS_SOFTWARE"] = "1"
        env["LP_NUM_THREADS"] = "4"
        xvfb = None
        display_log = None
        command = [str(GODOT), "--path", str(ROOT / "godot"), "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"]
        try:
            if args.mode in ("capture", "smoke"):
                # No TCP or filesystem socket: Xlib uses the private display's abstract Unix socket.
                read_fd, write_fd = os.pipe()
                display_log = (output / "xvfb.log").open("w")
                xvfb = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", args.size + "x24", "-nolisten", "tcp", "-nolisten", "unix", "-ac"], env=env, pass_fds=(write_fd,), stdout=display_log, stderr=subprocess.STDOUT)
                os.close(write_fd)
                with os.fdopen(read_fd) as stream:
                    display = stream.readline().strip()
                if not display:
                    raise RuntimeError("Private Xvfb failed to allocate a display")
                env["DISPLAY"] = ":" + display
                command += ["--resolution", args.size, "--position", "0,0", "--disable-vsync"]
            else:
                command += ["--headless"]
            if args.mode == "import":
                command += ["--editor", "--import"]
            elif args.mode == "verify":
                command += ["--script", "res://tests/cinder_array/verify.gd", "--", str(output / "report.json")]
            elif args.mode == "capture":
                command += ["--script", "res://tests/cinder_array/capture.gd", "--", str(output), "--cinder-dev-walker"]
            else:
                command += ["res://cinder_array/demo.tscn", "--", "--smoke", "--cinder-dev-walker"]
            start = time.monotonic()
            timed_out = False
            with (output / "godot.log").open("w") as log:
                try:
                    result = subprocess.run(command, env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180)
                    returncode = result.returncode
                except subprocess.TimeoutExpired:
                    timed_out = True
                    returncode = 124
            log_text = (output / "godot.log").read_text()
            engine_errors = [line for line in log_text.splitlines() if "ERROR:" in line]
            metadata = {"command": command, "returncode": returncode, "timed_out": timed_out, "engine_errors": engine_errors, "wall_seconds": round(time.monotonic() - start, 3), "renderer": "gl_compatibility", "software_rendering": True, "llvmpipe_threads": 4, "xvfb_listeners": "abstract local only; -nolisten tcp -nolisten unix", "isolated_home_xdg": True}
            (output / "run.json").write_text(json.dumps(metadata, indent=2) + "\n")
            print(log_text)
            raise SystemExit(returncode or (1 if engine_errors else 0))
        finally:
            if xvfb is not None:
                xvfb.terminate()
                xvfb.wait(timeout=10)
            if display_log is not None:
                display_log.close()


if __name__ == "__main__":
    main()
