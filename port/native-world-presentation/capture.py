#!/usr/bin/env python3
"""Bounded, private-Xvfb art review. No shared desktop or server is used."""
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN", "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64")
OUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).parent
OUT.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="native-world-", dir="/tmp/opencode") as runtime:
    read_fd, write_fd = os.pipe()
    with (OUT / "xvfb.log").open("w") as log:
        display = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp", "-nolisten", "unix"], pass_fds=(write_fd,), stdout=log, stderr=log)
        os.close(write_fd)
        try:
            if not select.select([read_fd], [], [], 10)[0]:
                raise RuntimeError("Private Xvfb startup timed out")
            number = os.read(read_fd, 32).decode().strip()
            if not number.isdigit():
                raise RuntimeError("Private Xvfb did not supply a display")
            env = dict(os.environ, DISPLAY=":" + number, LIBGL_ALWAYS_SOFTWARE="1", XDG_DATA_HOME=runtime + "/data", XDG_CONFIG_HOME=runtime + "/config", XDG_CACHE_HOME=runtime + "/cache")
            for map_id, view in [("meridian-exchange", "overview"), ("meridian-exchange", "street"), ("tidal-citadel", "overview")]:
                name = map_id + "-" + view
                command = [GODOT, "--path", str(ROOT / "godot"), "--audio-driver", "Dummy", "--script", str(Path(__file__).with_suffix(".gd")), "--", map_id, str(OUT / (name + ".png")), view]
                result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
                (OUT / (name + ".log")).write_text(result.stdout)
                print(result.stdout, end="")
                if result.returncode or "SCRIPT ERROR" in result.stdout or "ERROR:" in result.stdout:
                    raise RuntimeError("Capture failed: " + name)
        finally:
            os.close(read_fd)
            display.terminate()
            try:
                display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill()
                display.wait(timeout=5)
