"""Serial, bounded LATTICE contract/import runner; natural acceptance is separate.

Examples:
  python3 port/tools/native_lattice_flagship/verify.py --node --semantic
  GODOT_BIN=/path/to/pinned/godot python3 port/tools/native_lattice_flagship/verify.py --engine

Engine work requires the release coordinator's on-disk slot marker. Every
attempt has independent logs and a summary; failed attempts are retained.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / "port/native-lattice/evidence/flagship"
DISK = Path("/home/mojo/.tmp-on-disk")
SLOT = DISK / "cocs-lattice-engine-slot-granted"
LOCK = json.loads((ROOT / "port/contracts/source-lock.json").read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(name, argv, out, env, timeout):
    started = time.monotonic()
    process = subprocess.Popen(argv, cwd=ROOT, env=env, text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True)
    try:
        output, _ = process.communicate(timeout=timeout)
        code = process.returncode
    except subprocess.TimeoutExpired as error:
        os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
        output += "\nVERIFIER_TIMEOUT (not a natural source result)\n"
        code = 124
    (out / f"{name}.log").write_text(output)
    passed = code == 0 and "SCRIPT ERROR" not in output and "ERROR:" not in output
    result = {"name": name, "command": argv, "exit": code, "passed": passed,
              "seconds": round(time.monotonic() - started, 3),
              "log": str(out / f"{name}.log"), "evidence_class": "contract"}
    print(f"{name}: {'PASS' if passed else 'FAIL'} — {result['log']}", flush=True)
    if not passed:
        print(output[-3000:], file=sys.stderr)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--node", action="store_true", help="focused Node source/option/audit contracts")
    parser.add_argument("--semantic", action="store_true", help="pinned semantic export")
    parser.add_argument("--engine", action="store_true", help="one import followed by serial Godot fixture scripts")
    args = parser.parse_args()
    if not (args.node or args.semantic or args.engine):
        parser.error("select at least one check group")
    # Refuse heavy work before making any engine child or display allocation.
    if args.engine and (not SLOT.is_file() or not os.environ.get("GODOT_BIN")):
        parser.error(f"--engine requires {SLOT} and pinned GODOT_BIN")
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    out = EVIDENCE / f"contracts-{time.time_ns()}"
    out.mkdir()
    tracked = subprocess.check_output(["git", "ls-files", "godot/lattice", "godot/tests/lattice",
                                       "port/tools/native_lattice_flagship", "tools/godot-package"],
                                      cwd=ROOT, text=True).splitlines()
    # Include newly created lane files before commit, too; only paths in the
    # reviewed LATTICE ownership and shared package seam are inventoried.
    files = {ROOT / entry for entry in tracked}
    for pattern in ("godot/lattice/*.gd", "godot/tests/lattice/flagship_l*.gd",
                    "port/tools/native_lattice_flagship/*", "tools/godot-package/endpoint*"):
        files.update(ROOT.glob(pattern))
    hashes = {str(path.relative_to(ROOT)): digest(path) for path in sorted(files) if path.is_file()}
    manifest = {"schema_version": 1, "base": "d23d02a56ba622defffc94c249a08af9b32350c6",
                "source_commit": LOCK["source_commit"],
                "port_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "input_sha256": hashes, "groups": vars(args), "evidence_class": "contract",
                "note": "Fixtures/import do not establish full-round, multiplayer or human acceptance."}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    results = []
    with tempfile.TemporaryDirectory(prefix="lattice-contracts-", dir=DISK) as runtime:
        env = dict(os.environ)
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            env[key] = str(Path(runtime) / key)
            Path(env[key]).mkdir()
        if args.node:
            suites = ["game/cocs-wire.test.mjs", "game/cocs-spend-surface.test.mjs",
                      "game/cocs-intel.test.mjs", "game/lattice-support.test.mjs",
                      "game/lattice-guide.test.mjs", "game/destination-lattice.test.mjs", "game/cocs-pvp.test.mjs",
                      "game/cocs-coop.test.mjs", "server/cocs-net.test.mjs",
                      "tools/godot-dev/launch_options.test.mjs", "tools/godot-package/options.test.mjs",
                      "tools/godot-package/route_parity.test.mjs", "tools/godot-package/endpoint.test.mjs"]
            suites.extend(str(p.relative_to(ROOT)) for p in sorted((ROOT / "port/tools/native_lattice_flagship").glob("*.test.mjs")))
            suites.extend(str(p.relative_to(ROOT)) for p in sorted((ROOT / "godot/tests/lattice").glob("flagship_l*.mjs")))
            results.append(run("node-contracts", ["node", "--test", *suites], out, env, 180))
        if args.semantic:
            results.append(run("semantic", ["node", "tools/godot-export/semantic.mjs"], out, env, 180))
        if args.engine:
            binary = os.environ["GODOT_BIN"]
            results.append(run("engine-version", [binary, "--version"], out, env, 20))
            if (out / "engine-version.log").read_text().strip() != LOCK["godot_version"]:
                results[-1]["passed"] = False
            if results[-1]["passed"]:
                results.append(run("import", [binary, "--headless", "--path", "godot", "--editor", "--import"], out, env, 300))
            if results[-1]["passed"]:
                for path in sorted((ROOT / "godot/tests/lattice").glob("flagship_l*.gd")):
                    name = path.stem
                    results.append(run(name, [binary, "--headless", "--path", "godot", "--script",
                                               f"res://tests/lattice/{path.name}"], out, env, 40))
    (out / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    (out / "cleanup.json").write_text(json.dumps({"subprocesses_waited": True,
                                                   "temporary_xdg_removed": True,
                                                   "owned_servers": 0, "owned_displays": 0}, indent=2) + "\n")
    print(f"Attempt evidence: {out}", flush=True)
    return 0 if results and all(item["passed"] for item in results) else 1


if __name__ == "__main__":
    sys.exit(main())
