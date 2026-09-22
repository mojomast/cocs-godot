#!/usr/bin/env python3
"""Pinned native Compatibility checks; every attempted run keeps its evidence."""
import argparse
import json
import os
from pathlib import Path
import select
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PINNED = "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=PINNED)
    parser.add_argument("--quick", action="store_true", help="Contract + 960x640 only, still preserved")
    args = parser.parse_args()
    evidence = ROOT / "port/native-shader-lab/evidence"
    evidence.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="run-", dir=evidence))
    private = Path(tempfile.mkdtemp(prefix="shader-lab-private-", dir="/tmp/opencode"))
    env = os.environ.copy()
    for key in ["HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR"]:
        folder = private / key.lower()
        folder.mkdir(mode=0o700)
        env[key] = str(folder)
    env.update(PORT="0", LIBGL_ALWAYS_SOFTWARE="1")
    results = []
    xvfb = None

    def run(name, command, timeout=180):
        try:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
            text = process.stdout.decode(errors="replace")
            returncode = process.returncode
        except subprocess.TimeoutExpired as error:
            text = (error.stdout or b"").decode(errors="replace") + "\nVERIFIER TIMEOUT\n"
            returncode = 124
        (output / (name + ".log")).write_text(text)
        passed = returncode == 0 and not any(marker in text for marker in ["SCRIPT ERROR:", "SHADER ERROR:", "ERROR:"])
        if name == "contract":
            passed = passed and "SHADER_LAB_CONTRACT_OK" in text
        elif "x" in name:
            passed = passed and "SHADER_LAB_GRAPHICS_OK" in text
        results.append(dict(name=name, returncode=returncode, passed=passed))
        print(name, "PASS" if passed else "FAIL", flush=True)
        if not passed:
            raise RuntimeError(text[-14000:])

    try:
        common = [args.godot, "--path", str(ROOT / "godot"), "--audio-driver", "Dummy"]
        run("import", common + ["--headless", "--editor", "--import"])
        run("contract", common + ["--headless", "--script", "res://tests/shader_lab/validate.gd"])
        readfd, writefd = os.pipe()
        with (output / "xvfb.log").open("wb") as log:
            xvfb = subprocess.Popen(["Xvfb", "-displayfd", str(writefd), "-screen", "0", "1280x800x24", "-nolisten", "tcp", "-nolisten", "unix"], pass_fds=(writefd,), stdout=log, stderr=subprocess.STDOUT, env=env)
        os.close(writefd)
        if not select.select([readfd], [], [], 10)[0]:
            raise RuntimeError("Private Xvfb allocation timed out")
        display = os.read(readfd, 32).decode().strip()
        os.close(readfd)
        if not display.isdigit():
            raise RuntimeError("Invalid private display")
        env["DISPLAY"] = ":" + display
        for size in (["960x640"] if args.quick else ["960x640", "1280x800"]):
            target = output / size
            target.mkdir()
            run(size, common + ["--resolution", size, "--rendering-method", "gl_compatibility", "--script", "res://tests/shader_lab/graphics.gd", "--", "--output=" + str(target), "--size=" + size], timeout=240)
    finally:
        if xvfb is not None:
            xvfb.terminate()
            xvfb.wait(timeout=10)
        (output / "summary.json").write_text(json.dumps({"results": results, "private_state": str(private), "godot": args.godot, "renderer": "native GL Compatibility / software Mesa llvmpipe / isolated Xvfb", "quick": args.quick}, indent=2) + "\n")
        print("Evidence:", output, flush=True)


if __name__ == "__main__":
    main()
