#!/usr/bin/env python3
"""Blood FX verification: headless contracts plus rendered fixture evidence.

Everything runs in a private Xvfb display, a private HOME and a private TMPDIR.
No hardware GPU claim is made: this is llvmpipe software rendering. Standard
library only, matching port/native-combat-particles/measure.py.
"""
import argparse
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT", "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64")
EVIDENCE = ROOT / "port/native-blood-fx/evidence"
HEADLESS = [
    ("contracts", "res://tests/blood_fx/contracts.gd"),
    ("surfaces", "res://tests/blood_fx/surfaces.gd"),
    ("stress", "res://tests/blood_fx/stress.gd"),
]


def run(command, env, log_path, timeout=300):
    with log_path.open("w") as log:
        return subprocess.run(command, env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)


def log_failures(text):
    found = []
    for line in text.splitlines():
        if "SCRIPT ERROR" in line or "SHADER ERROR" in line or line.startswith("ERROR:") or line.startswith("ERROR "):
            found.append(line.strip())
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=["headless", "render", "all"], default="all")
    parser.add_argument("--samples", type=int, default=0, help="unused; fixture is deterministic")
    args = parser.parse_args()
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    records = []

    with tempfile.TemporaryDirectory(prefix="blood-fx-", dir=os.environ.get("TMPDIR", "/tmp/opencode")) as temporary:
        home = Path(temporary) / "home"
        home.mkdir()
        env = {**os.environ, "TMPDIR": temporary, "HOME": str(home)}
        if args.only in ("render", "all"):
            records.extend(render(env))

        if args.only in ("headless", "all"):
            env.pop("DISPLAY", None)
            records.extend(headless(env))

    summary = EVIDENCE / "verification-summary.json"
    summary.write_text(json.dumps(records, indent=2) + "\n")
    failed = [record for record in records if not record["ok"]]
    print(json.dumps({"passed": len(records) - len(failed), "failed": len(failed),
                      "cases": [record["case"] for record in failed]}, indent=2))
    return 1 if failed else 0


def headless(env):
    records = []
    for case, script in HEADLESS:
        log = EVIDENCE / (case + ".log")
        result = run([GODOT, "--headless", "--path", str(ROOT / "godot"), "--script", script], env, log)
        text = log.read_text()
        marker = [line for line in text.splitlines() if line.startswith("BLOOD_FX_")]
        summary = next((line for line in marker if "PASS" in line or "FAIL" in line), "")
        ok = result.returncode == 0 and "FAIL" not in summary and not log_failures(text)
        records.append({"case": case, "kind": "headless", "ok": ok, "returncode": result.returncode,
                        "summary": summary, "errors": log_failures(text)[:5], "log": str(log.name),
                        "metrics": marker[-1] if len(marker) > 1 else ""})
        print(("PASS " if ok else "FAIL ") + case + " " + summary)
    return records


def xvfb_session():
    """Private Xvfb per case: a slow software renderer or a neighbouring lane
    cannot take the whole matrix down with one dead display."""
    read_fd, write_fd = os.pipe()
    log = (EVIDENCE / "xvfb.log").open("a")
    server = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24",
                               "-nolisten", "tcp", "-nolisten", "unix"],
                              pass_fds=(write_fd,), stdout=log, stderr=log)
    os.close(write_fd)
    with os.fdopen(read_fd) as display_file:
        display = display_file.readline().strip()
    return server, log, display


def render(env):
    records = []
    for width, height in [(960, 640), (1280, 800)]:
        for quality in ["High", "Extreme"]:
            case = f"fixture-{width}x{height}-{quality.lower()}"
            prefix = EVIDENCE / case
            command = [GODOT, "--path", str(ROOT / "godot"), "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--resolution", f"{width}x{height}", "--quit-after", "2500",
                       "res://tests/blood_fx/render.tscn", "--", f"--width={width}", f"--height={height}",
                       f"--quality={quality}", f"--output={prefix}"]
            log = prefix.with_suffix(".log")
            for stale in EVIDENCE.glob(case + "*"):
                stale.unlink()
            started = time.time()
            result = None
            server, server_log, display = xvfb_session()
            try:
                if not display:
                    raise RuntimeError("private Xvfb did not allocate a display")
                case_env = dict(env)
                case_env["DISPLAY"] = ":" + display
                result = run(command, case_env, log, timeout=600)
            finally:
                server.terminate()
                server.wait(timeout=10)
                server_log.close()
            text = log.read_text()
            errors = log_failures(text)
            ok = result is not None and result.returncode == 0 and not errors and "BLOOD_FX_RENDER PASS" in text
            record = {"case": case, "kind": "render", "ok": ok,
                      "returncode": result.returncode if result is not None else None,
                      "errors": errors[:5], "log": log.name, "display": display}
            png = Path(str(prefix) + "-action.png")
            if not png.exists() or png.stat().st_mtime < started or not prefix.with_suffix(".json").exists():
                ok = False
                record["ok"] = False
                record["errors"].append("fixture did not produce a fresh PNG/JSON (killed before the final capture?)")
            if png.exists():
                size = struct.unpack(">II", png.read_bytes()[16:24])
                record["png_bytes"] = png.stat().st_size
                record["png_size"] = list(size)
                if tuple(size) != (width, height):
                    ok = False
                    record["ok"] = False
                    record["errors"].append(f"actual PNG resolution {size} != requested {(width, height)}")
            json_path = prefix.with_suffix(".json")
            if json_path.exists():
                data = json.loads(json_path.read_text())
                record.update({key: data[key] for key in [
                    "quality", "allocated_slots", "submitted_slots", "active_emitters", "concurrent_cap",
                    "stains_live", "stain_cap", "stains_placed", "stains_recycled", "death_bursts", "spurts",
                    "behind_wall_stains_placed", "behind_wall_changed_pixels", "front_control_stains_placed",
                    "front_control_changed_pixels", "local_changed_fraction", "remote_changed_fraction",
                    "occlusion_negative_zero_pixels", "renderer", "rendering_method", "viewport"] if key in data})
            records.append(record)
            print(("PASS " if record["ok"] else "FAIL ") + case + " " + json.dumps(
                {key: record[key] for key in ["behind_wall_changed_pixels", "front_control_changed_pixels",
                                              "local_changed_fraction", "remote_changed_fraction"] if key in record}))
    return records


if __name__ == "__main__":
    raise SystemExit(main())
