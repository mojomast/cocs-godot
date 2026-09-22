"""Linux-only serial command ownership, including orphaned group descendants."""
import ctypes
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def private_environment(directory, inherited=None):
    env = dict(os.environ if inherited is None else inherited)
    for key in ("DISPLAY", "XAUTHORITY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET",
                "DBUS_SESSION_BUS_ADDRESS", "SESSION_MANAGER"):
        env.pop(key, None)
    for key, leaf in {"HOME": "home", "TMPDIR": "tmp", "TMP": "tmp", "TEMP": "tmp",
                      "XDG_DATA_HOME": "data", "XDG_CONFIG_HOME": "config",
                      "XDG_CACHE_HOME": "cache", "XDG_RUNTIME_DIR": "runtime"}.items():
        path = Path(directory) / leaf
        path.mkdir(mode=0o700, parents=True, exist_ok=True)
        env[key] = str(path)
    return env


def group_members(group):
    """Include zombies: success means absent, not merely no longer running."""
    members = []
    for path in Path("/proc").glob("[0-9]*/stat"):
        try:
            fields = path.read_text().rsplit(")", 1)[1].split()
            if int(fields[2]) == group and int(fields[3]) == group:
                members.append(int(path.parent.name))
        except (FileNotFoundError, ProcessLookupError):
            pass
    return sorted(members)


def run_owned(command, *, env, cwd, timeout, term_grace=1.0, kill_grace=3.0):
    """Own a fresh session; TERM/KILL and reap its group even on normal exit.

    Temporary Linux subreaper status lets us reap xvfb-run's orphaned children
    instead of relying on the host's PID 1. Only waitpid(-our_pgid) is used for
    adopted descendants. Commands must not escape this session with setsid().
    This helper is deliberately serial (subreaper status is process-wide).
    """
    libc = ctypes.CDLL(None, use_errno=True)

    def prctl(option, argument):
        if libc.prctl(option, argument, 0, 0, 0) != 0:
            raise OSError(ctypes.get_errno(), "prctl child subreaper")

    previous = ctypes.c_int()
    prctl(37, ctypes.byref(previous))  # PR_GET_CHILD_SUBREAPER
    prctl(36, 1)  # PR_SET_CHILD_SUBREAPER
    process = None
    record = {"argv": command, "timed_out": False, "signals": [], "observed_pids": [],
              "remaining_pids": [], "cleanup_complete": False}
    seen = set()
    started = time.monotonic()
    try:
        # Regular files avoid an inherited pipe keeping communicate() blocked.
        with tempfile.TemporaryFile(dir=env["TMPDIR"]) as stdout, tempfile.TemporaryFile(dir=env["TMPDIR"]) as stderr:
            try:
                process = subprocess.Popen(command, env=env, cwd=cwd, stdout=stdout,
                                           stderr=stderr, start_new_session=True)
                record["pgid"] = process.pid
                try:
                    process.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    record["timed_out"] = True
            finally:
                if process is not None:
                    group = process.pid

                    def reap_and_scan():
                        # Popen owns the leader's status; do not steal it.
                        process.poll()
                        if process.returncode is not None:
                            while True:
                                try:
                                    pid, _ = os.waitpid(-group, os.WNOHANG)
                                except ChildProcessError:
                                    break
                                if pid == 0:
                                    break
                                seen.add(pid)
                        members = group_members(group)
                        seen.update(members)
                        return members

                    remaining = reap_and_scan()
                    for sig, grace in ((signal.SIGTERM, term_grace), (signal.SIGKILL, kill_grace)):
                        if not remaining:
                            break
                        # Every scanned member has our new PGID *and* SID.
                        # Never signal a shared/inherited session or guessed PID.
                        try:
                            os.killpg(group, sig)
                            record["signals"].append(sig.name)
                        except ProcessLookupError:
                            pass
                        deadline = time.monotonic() + grace
                        while True:
                            remaining = reap_and_scan()
                            if not remaining or time.monotonic() >= deadline:
                                break
                            time.sleep(0.02)
                    record.update(returncode=process.poll(), remaining_pids=remaining,
                                  cleanup_complete=not remaining, observed_pids=sorted(seen))
                stdout.seek(0)
                stderr.seek(0)
                record["stdout"] = stdout.read().decode("utf-8", errors="replace")
                record["stderr"] = stderr.read().decode("utf-8", errors="replace")
    finally:
        prctl(36, previous.value)
    record["duration_seconds"] = time.monotonic() - started
    return record
