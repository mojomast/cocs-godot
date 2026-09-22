"""Private-Xvfb capture of the real native map with explicitly synthetic frames."""
import os
from pathlib import Path
import select
import subprocess
import sys

# Give Xvfb its own socket directory; shared /tmp/.X11-unix may be read-only.
if "--private-tmp" not in sys.argv:
    os.execvp("bwrap", ["bwrap", "--bind", "/", "/", "--tmpfs", "/tmp", "--dev", "/dev", "--proc", "/proc", "--", sys.executable, str(Path(__file__).resolve()), "--private-tmp"])

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "evidence"
GODOT = os.environ.get("GODOT_BIN", "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64")
OUT.mkdir(exist_ok=True)
read_fd, write_fd = os.pipe()
xlog = (OUT / "xvfb-fixture.log").open("w")
server = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x720x24", "-nolisten", "tcp"], pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=xlog)
os.close(write_fd)
try:
    if not select.select([read_fd], [], [], 10)[0]:
        raise RuntimeError("Private Xvfb startup timed out; see xvfb-fixture.log")
    with os.fdopen(read_fd) as pipe:
        display = pipe.readline().strip()
    if not display:
        raise RuntimeError("Private Xvfb failed")
    env = dict(os.environ, DISPLAY=f":{display}", LIBGL_ALWAYS_SOFTWARE="1")
    for setup in [False, True]:
        name = "setup-fixture" if setup else "prism-native-actors-fixture"
        args = [GODOT, "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--resolution", "1280x720", "res://tests/native_arenas/session/visual_fixture.tscn", "--", "--mute", f"--capture={OUT / (name + '.png')}"]
        if setup:
            args.append("--capture-setup")
        run = subprocess.run(args, cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
        log = run.stdout + run.stderr
        (OUT / (name + ".log")).write_text(log)
        if run.returncode != 0 or "SCRIPT ERROR" in log or "ERROR:" in log:
            raise RuntimeError(log)
        print(log.strip())
finally:
    server.terminate()
    try:
        server.wait(timeout=5)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait()
    xlog.close()
