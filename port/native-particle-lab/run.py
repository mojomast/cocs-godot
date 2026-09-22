#!/usr/bin/env python3
"""Private pinned-Godot native render checks. Real frames; no shared services."""
import argparse
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"


def run(command, env, log, timeout=90, expected=None):
    started = time.monotonic()
    timed_out = False
    with log.open("w") as stream:
        try:
            result = subprocess.run(command, env=env, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=timeout)
            code = result.returncode
        except subprocess.TimeoutExpired:
            timed_out = True
            code = -1
            stream.write(f"\nBOUNDED_TIMEOUT after {timeout}s; process killed/reaped\n")
    text = log.read_text()
    ok = code == 0 and "SCRIPT ERROR" not in text and "ERROR:" not in text
    if expected:
        ok = ok and expected in text
    record = {"ok": ok, "exit_code": code, "timed_out": timed_out,
              "wall_seconds": round(time.monotonic() - started, 3), "log": str(log),
              "command": command}
    print(json.dumps(record), flush=True)
    if not ok:
        print(text[-6000:], flush=True)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).parent / "evidence")
    parser.add_argument("--checks-only", action="store_true")
    parser.add_argument("--quick", action="store_true", help="One 32K native capture after checks")
    parser.add_argument("--stress-lifecycle", action="store_true", help="Three explicit native 128K/512K/1M/32K resize cycles")
    parser.add_argument("--case", help="Single case: WIDTHxHEIGHT:COUNT:PRESET:BACKEND:SCALE")
    parser.add_argument("--energy", type=float, default=0.85, help="Explicit additive energy for every capture (default 0.85; dense view 0.06)")
    args = parser.parse_args()
    if not 0.05 <= args.energy <= 2.0:
        parser.error("--energy must be in 0.05..2.0")
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    results = []
    with tempfile.TemporaryDirectory(prefix="particle-lab-", dir="/tmp/opencode") as runtime:
        stage = Path(runtime) / "godot"
        stage.mkdir()
        for folder in ["particle_lab", "moth", "tests/particle_lab"]:
            shutil.copytree(ROOT / "godot" / folder, stage / folder)
        # Minimal private manifest: no semantic catalog or unrelated scenes.
        (stage / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Native Particle Lab"\n'
            'run/main_scene="res://particle_lab/demo.tscn"\n'
            'config/features=PackedStringArray("4.5", "GL Compatibility")\n'
            '[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=800\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = dict(os.environ, HOME=runtime + "/home", PORT="0", LIBGL_ALWAYS_SOFTWARE="1",
                   XDG_DATA_HOME=runtime + "/data", XDG_CONFIG_HOME=runtime + "/config",
                   XDG_CACHE_HOME=runtime + "/cache", XDG_RUNTIME_DIR=runtime + "/xdg")
        Path(env["HOME"]).mkdir()
        Path(env["XDG_RUNTIME_DIR"]).mkdir(mode=0o700)
        base = [GODOT, "--path", str(stage), "--audio-driver", "Dummy"]
        results.append(run(base + ["--headless", "--editor", "--import", "--quit"], env, out / "import.log", 120))
        if results[-1]["ok"]:
            results.append(run(base + ["--headless", "--", "--smoke"], env, out / "smoke.log", expected="PARTICLE_LAB_SMOKE"))
            results.append(run(base + ["--headless", "--script", "res://tests/particle_lab/verify.gd"], env, out / "verify-headless.log", expected="PARTICLE_LAB_VERIFY"))
        if not all(r["ok"] for r in results) or args.checks_only:
            (out / "runs.json").write_text(json.dumps(results, indent=2) + "\n")
            return 0 if all(r["ok"] for r in results) else 1
        read_fd, write_fd = os.pipe()
        with (out / "xvfb.log").open("w") as log:
            display = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24",
                                        "-nolisten", "tcp", "-nolisten", "unix"],
                                       pass_fds=(write_fd,), stdout=log, stderr=log, env=env)
            os.close(write_fd)
            try:
                if not select.select([read_fd], [], [], 10)[0]:
                    raise RuntimeError("Private Xvfb startup timeout")
                number = os.read(read_fd, 32).decode().strip()
                if not number.isdigit():
                    raise RuntimeError("Private Xvfb did not return display number")
                env["DISPLAY"] = ":" + number
                graphical = base + ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]
                results.append(run(graphical + ["--script", "res://tests/particle_lab/verify.gd"], env, out / "verify-native.log", expected="PARTICLE_LAB_VERIFY"))
                if args.stress_lifecycle:
                    results.append(run(graphical + ["--script", "res://tests/particle_lab/stress_lifecycle.gd"], env, out / "stress-lifecycle.log", 90, "PARTICLE_LAB_STRESS_LIFECYCLE"))
                cases = [(960, 640, 32768, "vortex", "gpu", 1.0)]
                if args.case:
                    resolution, count, preset, backend, scale = args.case.split(":")
                    width, height = resolution.split("x")
                    cases = [(int(width), int(height), int(count), preset, backend, float(scale))]
                elif not args.quick:
                    cases += [(1280, 800, 32768, preset, "gpu", 1.0) for preset in ["vortex", "galaxy", "burst", "fountain"]]
                    cases += [(1280, 800, count, "galaxy", "gpu", 1.0) for count in [8192, 131072, 524288, 1048576]]
                    cases += [(960, 640, 524288, "vortex", "gpu", 1.0),
                              (1280, 800, 32768, "galaxy", "analytic", 1.0),
                              (1280, 800, 1048576, "galaxy", "analytic", 1.0),
                              (960, 640, 1048576, "galaxy", "analytic", 0.5)]
                for width, height, count, preset, backend, scale in cases:
                    case = out / f"{width}x{height}-{preset}-{backend}-{count}-{scale:g}x"
                    case.mkdir(exist_ok=True)
                    command = graphical + ["--resolution", f"{width}x{height}", "--script", "res://tests/particle_lab/capture.gd",
                                           "--", str(case), str(count), preset, backend, str(scale), str(args.energy)]
                    results.append(run(command, env, case / "capture.log", 90, "PARTICLE_LAB_CAPTURE"))
                    # Preserve failures/timeouts and continue bounded independent cases.
                    (out / "runs.json").write_text(json.dumps(results, indent=2) + "\n")
            finally:
                os.close(read_fd)
                display.terminate()
                try:
                    display.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    display.kill()
                    display.wait(timeout=5)
    (out / "runs.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0 if all(r["ok"] for r in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
