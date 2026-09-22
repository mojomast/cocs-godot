"""Run a display-requiring gate command under a private owned Xvfb display.

Some Godot fixtures exercise real pointer capture (MOUSE_MODE_CAPTURED), which the
dummy/headless display server ignores. Those gates are real acceptance, so they must
run against a display rather than being weakened or dropped.

Two private-server modes are attempted, tightest first:

1. Unix-socket display (default). Works wherever ``/tmp/.X11-unix`` is usable, which
   includes normal hosts and CI images.
2. Loopback TCP display (``-nolisten unix -listen tcp``). Needed on hosts where
   ``/tmp/.X11-unix`` is root-owned and not world-writable, so no Unix listener can be
   created at all. The server lives only for the duration of the gate.

The owned server is always torn down, and neither mode reuses another session's
display. No dependency on the ``xvfb-run`` shell helper.

Usage: python3 tools/godot-dev/xvfb_run.py <command> [args...]
"""
import os
import select
import socket
import subprocess
import sys


def start_server(prefer_unix: bool):
    """Start Xvfb and return (process, display, env) or (None, reason, None)."""
    read_fd, write_fd = os.pipe()
    arguments = ["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24"]
    arguments += ["-nolisten", "tcp"] if prefer_unix else ["-nolisten", "unix", "-listen", "tcp"]
    process = subprocess.Popen(
        arguments,
        pass_fds=[write_fd],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    os.close(write_fd)
    try:
        if not select.select([read_fd], [], [], 15)[0]:
            process.kill()
            process.wait()
            return None, "display readiness timed out", None
        number = os.read(read_fd, 64).decode().strip()
    finally:
        os.close(read_fd)
    if not number.isdigit():
        process.terminate()
        process.wait()
        return None, f"unexpected display number {number!r}", None
    display = ":" + number if prefer_unix else "localhost:" + number
    if not _reachable(process, int(number), prefer_unix):
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        return None, "display not reachable after startup", None
    return process, display, {**os.environ, "DISPLAY": display}


def _reachable(process, number: int, unix: bool) -> bool:
    if process.poll() is not None:
        return False
    if unix:
        return os.path.exists(f"/tmp/.X11-unix/X{number}")
    connection = socket.socket()
    connection.settimeout(3)
    try:
        connection.connect(("127.0.0.1", 6000 + number))
        return True
    except OSError:
        return False
    finally:
        connection.close()


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: xvfb_run.py <command> [args...]", file=sys.stderr)
        return 2
    reasons = []
    for prefer_unix in (True, False):
        server, display, env = start_server(prefer_unix)
        if server is None:
            reasons.append(("unix" if prefer_unix else "tcp") + f": {display}")
            continue
        try:
            return subprocess.call([str(a) for a in sys.argv[1:]], env=env)
        finally:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
    print("No private display could be started: " + "; ".join(reasons), file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
