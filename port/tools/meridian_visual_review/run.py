#!/usr/bin/env python3
"""Private, pinned-input graphical causal review. No exporter/server invocation."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
from owned_process import private_environment, run_owned

ROOT = Path(__file__).resolve().parents[3]
SHA = "a41094bdbafd7a6796d86d175982aab958e3500e8d8514f820dfa36c362d73ea"
GODOT = "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--content-from", type=Path, default=ROOT / "godot/content")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", default=GODOT)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if (output / "run.json").exists():
        raise SystemExit("Refusing to overwrite an existing run; choose a fresh output directory")
    content = args.content_from.resolve()
    glb = content / "probes/meridian-exchange/world.glb"
    assert sha(glb) == SHA, "Input must match the historical reproducibility report"
    data = glb.read_bytes()
    gltf = json.loads(data[20:20 + struct.unpack_from("<I", data, 12)[0]])
    node = gltf["nodes"][56]
    primitive = gltf["meshes"][node["mesh"]]["primitives"][0]
    accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
    material = gltf["materials"][primitive["material"]]
    assert accessor["min"] == [-185, -185, -185] and accessor["max"] == [185, 185, 185]
    assert not material.get("doubleSided", False)
    summary = {
        "execution_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "godot_binary": args.godot, "godot_binary_sha256": sha(Path(args.godot)),
        "input_glb": str(glb), "input_glb_sha256": SHA, "input_glb_bytes": len(data),
        "sky_gltf": {"node_index": 56, "node": node, "primitive": primitive,
                     "position_accessor": accessor, "material_index": primitive["material"], "material": material},
        "tracked_inputs": {}, "generated_inputs": {}, "commands": [],
        "production_fix": False, "status": "running",
    }
    for relative in ["godot/world/viewer.gd", "godot/project.godot", "godot/main.tscn",
                     "game/environment.mjs", "game/view.mjs", "tools/godot-export/harness.html",
                      "port/tools/meridian_visual_review/review.gd", "port/tools/meridian_visual_review/run.py",
                      "port/tools/meridian_visual_review/owned_process.py"]:
        summary["tracked_inputs"][relative] = sha(ROOT / relative)
    for path in sorted((content / "generated").rglob("*.json")):
        summary["generated_inputs"][str(path.relative_to(content))] = sha(path)

    def save():
        (output / "run.json").write_text(json.dumps(summary, indent=2) + "\n")

    save()
    try:
        with tempfile.TemporaryDirectory(prefix="meridian-render-", dir="/tmp/opencode") as directory:
            private = Path(directory)
            project = private / "godot"
            shutil.copytree(ROOT / "godot", project, ignore=shutil.ignore_patterns(".godot", "content", ".meridian_visual_review"))
            shutil.copytree(content / "generated", project / "content/generated")
            (project / "content/probes/meridian-exchange").mkdir(parents=True)
            shutil.copyfile(glb, project / "content/probes/meridian-exchange/world.glb")
            shutil.copyfile(ROOT / "port/tools/meridian_visual_review/review.gd", project / "review.gd")
            env = private_environment(private / "environment")
            for case in ["baseline", "source-cull-only", "camera-inside", "semantic"]:
                command = ["xvfb-run", "-a", args.godot, "--audio-driver", "Dummy", "--path", str(project)]
                if case == "semantic":
                    command += ["--", "--capture=" + str(output / "semantic.png")]
                else:
                    command += ["--script", "res://review.gd", "--", "--visual-probe",
                                "--review-case=" + case, "--review-output=" + str(output)]
                completed = run_owned(command, env=env, cwd=ROOT, timeout=120)
                text = completed.pop("stdout") + completed.pop("stderr")
                (output / (case + ".log")).write_text(text)
                summary["commands"].append({"case": case, **completed})
                save()
                assert completed["cleanup_complete"], completed
                if completed["timed_out"]:
                    raise TimeoutError(f"{case} exceeded 120s; owned group cleanup recorded")
                assert completed["returncode"] == 0 and "SCRIPT ERROR" not in text and "ERROR:" not in text, text
                assert (output / (case + ".png")).is_file()
            summary["status"] = "completed_causal_experiments_not_parity_acceptance"
    except BaseException as error:
        summary["status"] = "failed"
        summary["error"] = repr(error)
        raise
    finally:
        summary["artifacts"] = {p.name: sha(p) for p in sorted(output.iterdir()) if p.is_file() and p.name != "run.json"}
        save()
    print(summary["status"])


if __name__ == "__main__":
    main()
