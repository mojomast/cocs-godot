#!/usr/bin/env python3
"""Run real Godot raster tests on a private socket-free Xvfb display."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path("/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("label")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    output = (args.output or Path(__file__).resolve().parent / "evidence" / args.label).resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="graphics-depth-", dir="/tmp/opencode") as temporary:
        private = Path(temporary)
        env = os.environ.copy()
        for key, name in [("HOME", "home"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"), ("XDG_DATA_HOME", "data"), ("XDG_RUNTIME_DIR", "runtime")]:
            directory = private / name
            directory.mkdir(mode=0o700)
            env[key] = str(directory)
        read_fd, write_fd = os.pipe()
        with (output / "xvfb.log").open("w") as xlog:
            xvfb = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp", "-nolisten", "unix"], pass_fds=(write_fd,), stdout=xlog, stderr=subprocess.STDOUT, env=env)
            os.close(write_fd)
            try:
                with os.fdopen(read_fd) as display:
                    number = display.readline().strip()
                if not number or xvfb.poll() is not None:
                    raise RuntimeError("Private Xvfb failed")
                env["DISPLAY"] = ":" + number
                env["LIBGL_ALWAYS_SOFTWARE"] = "1"
                statuses = []
                for width, height in [(960, 640), (1280, 800)]:
                    target = output / f"{width}x{height}"
                    target.mkdir(exist_ok=True)
                    command = [str(GODOT), "--path", str(ROOT / "godot"), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--resolution", f"{width}x{height}", "--position", "0,0", "--script", "res://tests/graphics_depth/capture.gd", "--", str(target), args.label]
                    with (target / "godot.log").open("w") as log:
                        log.write("COMMAND " + " ".join(command) + "\n")
                        log.flush()
                        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
                        log.write(f"\nEXIT_STATUS {result.returncode}\n")
                    statuses.append(result.returncode)
                    print(f"{args.label} {width}x{height}: exit {result.returncode}", flush=True)
                return 1 if any(statuses) else 0
            finally:
                xvfb.terminate()
                xvfb.wait(timeout=10)


if __name__ == "__main__":
    raise SystemExit(main())
