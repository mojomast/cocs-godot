#!/usr/bin/env python3
"""Serial rendered evidence in a private Xvfb. Standard library only."""
import argparse
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT", "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=int, default=72)
    parser.add_argument("--only", choices=["baseline", "high", "extreme"])
    args = parser.parse_args()
    out = ROOT / "port/native-combat-particles/evidence"
    out.mkdir(parents=True, exist_ok=True)
    records = []
    with tempfile.TemporaryDirectory(prefix="combat-particles-", dir=os.environ.get("TMPDIR", "/tmp/opencode")) as temporary:
        read_fd, write_fd = os.pipe()
        with (out / "xvfb.log").open("w") as xlog:
            # Linux abstract local sockets avoid changing the shared/root-owned
            # /tmp/.X11-unix directory. No TCP listener is exposed.
            xvfb = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp", "-nolisten", "unix"], pass_fds=(write_fd,), stdout=xlog, stderr=xlog)
            os.close(write_fd)
            try:
                with os.fdopen(read_fd) as display_file:
                    display = display_file.readline().strip()
                if not display:
                    raise RuntimeError("private Xvfb did not allocate a display")
                env = {**os.environ, "DISPLAY": ":" + display, "TMPDIR": temporary}
                for mode in ([args.only] if args.only else ["baseline", "high", "extreme"]):
                    for width, height in [(1280, 800), (800, 600)]:
                        prefix = out / f"{mode}-{width}"
                        command = [GODOT, "--path", str(ROOT / "godot"), "--resolution", f"{width}x{height}", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "res://tests/combat_particles/replay.tscn", "--", f"--samples={args.samples}", f"--output={prefix}", "--quality=" + ("High" if mode == "high" else "Extreme")]
                        if width == 800:
                            command.append("--small")
                        if mode == "baseline":
                            command.append("--baseline")
                        with prefix.with_suffix(".log").open("w") as log:
                            result = subprocess.run(command, env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=240)
                        text = prefix.with_suffix(".log").read_text()
                        if result.returncode or "SCRIPT ERROR" in text or "SHADER ERROR" in text or "ERROR:" in text:
                            raise RuntimeError(f"{mode}-{width} failed; retained {prefix}.log")
                        png = prefix.with_suffix(".png").read_bytes()
                        actual_size = struct.unpack(">II", png[16:24])
                        record = json.loads(prefix.with_suffix(".json").read_text())
                        if actual_size != (width, height) or record["viewport"] != [width, height]:
                            raise RuntimeError(f"actual resolution mismatch: {actual_size}, {record['viewport']}")
                        if mode == "extreme" and (record["draw_slots"] != 1_000_000 or record["scene_primitives"] < 2_000_000):
                            raise RuntimeError("Extreme did not submit one million world-space quads")
                        records.append({key: record[key] for key in ["quality", "baseline", "viewport", "renderer", "sample_count", "median_ms", "p95_ms", "max_ms", "allocated_slots", "draw_slots", "scene_primitives", "scene_draw_calls"]})
                        print(json.dumps(records[-1]), flush=True)
            finally:
                xvfb.terminate()
                xvfb.wait(timeout=10)
    (out / "measurement-summary.json").write_text(json.dumps(records, indent=2) + "\n")


if __name__ == "__main__":
    main()
