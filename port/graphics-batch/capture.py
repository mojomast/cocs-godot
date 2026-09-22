"""Capture matched all-nine-map static cameras on an owned private X11 display."""
import argparse
import os
from pathlib import Path
import select
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
DEFAULT = "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--label", required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="graphics-gallery-", dir="/tmp/opencode") as temporary:
        env = {"PATH": os.environ["PATH"], "HOME": temporary, "LANG": "C.UTF-8", "LIBGL_ALWAYS_SOFTWARE": "1"}
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            env[key] = str(Path(temporary) / key)
            Path(env[key]).mkdir()
        read_fd, write_fd = os.pipe()
        with (output / "xvfb.log").open("w") as log:
            display = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp", "-nolisten", "unix"], env=env, pass_fds=[write_fd], stdout=log, stderr=subprocess.STDOUT)
            os.close(write_fd)
            try:
                if not select.select([read_fd], [], [], 10)[0]:
                    raise RuntimeError("Private display failed readiness")
                env["DISPLAY"] = ":" + os.read(read_fd, 64).decode().strip()
                command = [os.environ.get("GODOT_BIN", DEFAULT), "--audio-driver", "Dummy", "--path", ROOT / "godot", "--script", "res://tests/graphics_batch/gallery.gd", "--", "--gallery-output=" + str(output), "--gallery-label=" + args.label]
                result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
                (output / "capture.log").write_text(result.stdout)
                if result.returncode or "ERROR:" in result.stdout or "GRAPHICS_GALLERY_OK" not in result.stdout:
                    raise RuntimeError(result.stdout)
                print(result.stdout)
            finally:
                os.close(read_fd)
                display.terminate()
                try:
                    display.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    display.kill()
                    display.wait()


if __name__ == "__main__":
    main()
