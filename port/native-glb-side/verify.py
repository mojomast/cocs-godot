#!/usr/bin/env python3
"""Private export/import/render evidence; generated GLBs stay ignored."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "port/tools/meridian_visual_review"))
from owned_process import private_environment, run_owned

GODOT = "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"
HISTORICAL = "70e9075dfb93a5cc25be8229d362d0e9f9a66835"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--original-glb", type=Path, required=True)
    parser.add_argument("--chromium", required=True)
    parser.add_argument("--godot", default=GODOT)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    lock = json.loads((ROOT / "port/contracts/source-lock.json").read_text())
    original = args.original_glb.resolve()
    tracked = subprocess.check_output(["git", "ls-files", "game", "server", "assets", "public", "package.json", "package-lock.json", "port/contracts"], cwd=ROOT, text=True).splitlines()
    source = {path: sha(ROOT / path) for path in tracked}
    report = {"base": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "source_commit": lock["source_commit"], "source_hashes_before": source,
              "original_glb_sha256": sha(original), "godot_sha256": sha(args.godot),
              "chromium_sha256": sha(args.chromium), "commands": [], "status": "running"}

    def save():
        (output / "run.json").write_text(json.dumps(report, indent=2) + "\n")

    def run(name, command, env, timeout=180):
        result = run_owned(command, env=env, cwd=ROOT, timeout=timeout)
        text = result.pop("stdout") + result.pop("stderr")
        (output / (name + ".log")).write_text(text)
        report["commands"].append({"name": name, **result})
        save()
        assert result["cleanup_complete"] and result["returncode"] == 0 and not result["timed_out"], name
        assert "SCRIPT ERROR" not in text and "ERROR:" not in text, text

    save()
    try:
        with tempfile.TemporaryDirectory(prefix="glb-side-verify-", dir="/tmp/opencode") as temporary:
            private = Path(temporary)
            env = private_environment(private / "environment")
            env.update(CHROMIUM_PATH=str(Path(args.chromium).resolve()), GLTF_REPORT_DIR=str(output / "exports"))
            run("unit", ["node", "--test", "tools/godot-export/gltf_side.test.mjs"], env)
            run("semantic", ["node", "tools/godot-export/semantic.mjs"], env)
            for map_id in [None, *lock["map_ids"]]:
                run("export-" + (map_id or "axis-weapon"), ["node", "tools/godot-export/browser-export.mjs", *([map_id] if map_id else [])], env)
            # Actual pinned native importer, including existing axis/instance gate.
            run("import-existing", [args.godot, "--headless", "--path", "godot", "--script", "res://tests/import.gd"], env)
            run("import-sides", [args.godot, "--headless", "--path", "godot", "--script", "res://tests/glb_side_import.gd"], env)
            run("logical-glb-comparison", [sys.executable, "-B", "port/native-glb-side/analyze.py", "--before", str(original),
                                           "--after", str(ROOT / "godot/content/probes/meridian-exchange/world.glb")], env)
            project = private / "godot"
            shutil.copytree(ROOT / "godot", project, ignore=shutil.ignore_patterns(".godot"))
            historical_viewer = subprocess.check_output(["git", "show", HISTORICAL + ":godot/world/viewer.gd"], cwd=ROOT)
            current_viewer = (ROOT / "godot/world/viewer.gd").read_bytes()
            report["viewer_sha256"] = {"historical": hashlib.sha256(historical_viewer).hexdigest(), "current": hashlib.sha256(current_viewer).hexdigest()}
            report["historical_viewer_revision"] = HISTORICAL
            repaired = (ROOT / "godot/content/probes/meridian-exchange/world.glb").read_bytes()
            for viewer_name, viewer in [("historical", historical_viewer), ("current", current_viewer)]:
                (project / "world/viewer.gd").write_bytes(viewer)
                for case, glb in [("before", original.read_bytes()), ("after", repaired)]:
                    (project / "content/probes/meridian-exchange/world.glb").write_bytes(glb)
                    name = viewer_name + "-" + case
                    # Linux abstract socket remains available; neither TCP nor a
                    # filesystem X socket is exposed. Owned session is reaped.
                    run(name, ["xvfb-run", "-a", "-s", "-screen 0 1280x800x24 -nolisten tcp -nolisten unix",
                               args.godot, "--audio-driver", "Dummy", "--path", str(project), "--",
                               "--visual-probe", "--capture=" + str(output / (name + ".png"))], env)
            report["historical_failure_image_matches"] = sha(output / "historical-before.png") == sha(ROOT / "port/reports/meridian-glb.png")
            assert report["historical_failure_image_matches"]
            run("image-analysis", [args.godot, "--headless", "--path", "godot", "--script", "res://tests/glb_side_images.gd", "--", str(output)], env)
        report["source_hashes_after"] = {path: sha(ROOT / path) for path in tracked}
        assert source == report["source_hashes_after"]
        report["source_unchanged"] = True
        report["status"] = "passed_export_import_matched_captures_not_art_parity"
    except BaseException as error:
        report.update(status="failed", error=repr(error))
        raise
    finally:
        report["artifacts"] = {str(path.relative_to(output)): sha(path) for path in sorted(output.rglob("*")) if path.is_file() and path.name != "run.json"}
        save()
    print(report["status"])


if __name__ == "__main__":
    main()
