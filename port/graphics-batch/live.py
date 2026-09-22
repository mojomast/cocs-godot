"""Graphical integration evidence against an owned, normal-rate Node authority."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
DEFAULT = "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"


def stop(process):
    if process is None:
        return
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--map", default="meridian-exchange")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="graphics-live-", dir="/tmp/opencode") as temporary:
        stage = Path(temporary)
        env = {"PATH":os.environ["PATH"], "HOME":temporary, "LANG":"C.UTF-8", "LIBGL_ALWAYS_SOFTWARE":"1", "PORT":"0"}
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            env[key] = str(stage / key)
            Path(env[key]).mkdir()
        binary = os.environ.get("GODOT_BIN", DEFAULT)

        def run(command, name, timeout=120):
            result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
            (output / name).write_text(result.stdout)
            if result.returncode or "ERROR:" in result.stdout:
                raise RuntimeError(f"Failed {name}: {result.stdout}")
            return result.stdout

        project = stage / "godot"
        shutil.copytree(ROOT / "godot", project, ignore=shutil.ignore_patterns(".godot", "content"))
        run(["node", ROOT / "tools/godot-export/semantic.mjs", project / "content/generated"], "semantic.log")
        run([binary, "--headless", "--path", project, "--editor", "--import"], "import.log")
        server = display = None
        read_fd = None
        with (output / "server.log").open("w") as server_log, (output / "xvfb.log").open("w") as display_log:
            try:
                ready = stage / "ready.json"
                server = subprocess.Popen(["node", ROOT / "port/native-player-models/server.mjs", ready], cwd=ROOT, env=env, stdout=server_log, stderr=subprocess.STDOUT)
                deadline = time.monotonic() + 10
                while not ready.exists():
                    if server.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError("Owned authority failed readiness")
                    time.sleep(.05)
                port = json.loads(ready.read_text())["port"]
                read_fd, write_fd = os.pipe()
                display = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp", "-nolisten", "unix"], env=env, pass_fds=[write_fd], stdout=display_log, stderr=subprocess.STDOUT)
                os.close(write_fd)
                if not select.select([read_fd], [], [], 10)[0]:
                    raise RuntimeError("Private display failed readiness")
                env["DISPLAY"] = ":" + os.read(read_fd, 64).decode().strip()
                text = run([binary, "--audio-driver", "Dummy", "--path", project, "--resolution", "960x640", "--script", "res://tests/graphics_batch/live.gd", "--", f"--endpoint=ws://127.0.0.1:{port}", "--map=" + args.map, "--mode=teamdeathmatch", "--mute", "--output=" + str(output)], "live.log", timeout=120)
                if "GRAPHICS_LIVE_RESULT" not in text:
                    raise RuntimeError("Missing live completion")
                raw = (output / "live.json").read_bytes()
                summary = json.loads(raw)["summary"]
                if not summary["passed"]:
                    raise RuntimeError("Live report failed")
                (output / "live.json.gz").write_bytes(gzip.compress(raw, mtime=0))
                (output / "live.json.sha256").write_text(hashlib.sha256(raw).hexdigest() + "  live.json\n")
                (output / "live.json").unlink()
                (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
                print(json.dumps(summary, indent=2))
            finally:
                stop(server)
                stop(display)
                if read_fd is not None:
                    os.close(read_fd)
                (output / "cleanup.json").write_text(json.dumps({"authority_exit":None if server is None else server.returncode, "xvfb_exit":None if display is None else display.returncode}) + "\n")


if __name__ == "__main__":
    main()
