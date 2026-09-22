"""Private, Linux x86_64 package builder. All generated files live outside git."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION = "4.5.2"
EXACT = "4.5.2.stable.official.6ce3de25a"
BASE = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/"
# Verified against the official release SHA512-SUMS.txt; also re-fetch that file.
ARCHIVES = {
    "editor.zip": (f"Godot_v{VERSION}-stable_linux.x86_64.zip", "e3ce6194b6d4d2dcef5e5b5136752c084d9d8b9071c10bc2d2011b947ec7439a257c8d23c541cb30699f16d9edea6dff36e6e84d2bec14a8fe9b4e9aacbe5a8d"),
    "templates.tpz": (f"Godot_v{VERSION}-stable_export_templates.tpz", "003aa33743f58fb657717f090fc872ed3975e48d08a6012201a2259970d458a63d4d8a83090585307c23455ebfa4e6e0050e1057761c34863536095e3fcfab6c"),
}


def digest(path, kind="sha256"):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, kind).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def run(args, *, cwd=ROOT, env=None, log=None):
    result = subprocess.run([str(a) for a in args], cwd=cwd, env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=300)
    if log:
        Path(log).write_text(result.stdout)
    if result.returncode or "SCRIPT ERROR" in result.stdout or "ERROR:" in result.stdout:
        raise RuntimeError(f"Command failed ({result.returncode}): {args}\n{result.stdout[-6000:]}")
    return result.stdout.strip()


def git(*args):
    return run(["git", *args])


def copy(source, target):
    if source.is_symlink() or not source.is_file():
        raise RuntimeError(f"Expected ordinary file: {source}")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def download(url, target):
    partial = target.with_name(target.name + ".partial")
    with urllib.request.urlopen(url, timeout=120) as response, partial.open("wb") as stream:
        shutil.copyfileobj(response, stream)
    partial.replace(target)


def tree(path):
    return {p.relative_to(path).as_posix(): digest(p) for p in sorted(path.rglob("*")) if p.is_file()}


def tree_hash(records):
    return hashlib.sha256(json.dumps(records, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, required=True, help="owned /tmp/opencode directory outside any checkout")
    parser.add_argument("--archive-directory", type=Path, help="optional read-only source of editor.zip/templates.tpz; official hashes required")
    args = parser.parse_args()
    state = args.state.resolve()
    if not state.is_relative_to(Path("/tmp/opencode")) or state == Path("/tmp/opencode") or state.is_relative_to(ROOT) or ROOT.is_relative_to(state):
        raise RuntimeError("Choose a dedicated /tmp/opencode state directory outside the checkout")
    if any((parent / ".git").exists() for parent in [state, *state.parents]):
        raise RuntimeError("Generated package/toolchain state must be outside every git checkout")
    marker = state / ".cocs-package-state"
    if state.exists() and not marker.is_file():
        raise RuntimeError("Refusing an existing unowned state directory")
    state.mkdir(parents=True, exist_ok=True)
    marker.write_text("private native-linux-package build state\n")
    work = state / "builds" / str(time.time_ns())
    work.mkdir(parents=True)
    logs = work / "logs"
    logs.mkdir()
    lock = json.loads((ROOT / "port/contracts/source-lock.json").read_text())
    if lock["godot_version"] != EXACT or git("rev-parse", "--is-shallow-repository") != "false":
        raise RuntimeError("Exact Godot lock and full git history required")
    # Existing verifier checks ancestry plus every tracked locked source/dependency byte.
    verify = "import {verifySource} from './tools/godot-export/semantic.mjs'; import fs from 'node:fs'; verifySource(JSON.parse(fs.readFileSync('port/contracts/source-lock.json')));"
    run(["node", "--input-type=module", "-e", verify])
    closure = json.loads(run(["node", "--no-warnings", "--experimental-vm-modules", ROOT / "tools/godot-package/discover.mjs", ROOT]))
    write_json(logs / "server-closure.json", closure)
    input_paths = set(closure["modules"])
    input_paths.update(["package.json", "package-lock.json", "port/contracts/source-lock.json", "port/contracts/map-selection.json", "tools/godot-export/semantic.mjs"])
    native_files = [p for p in git("ls-files", "godot").splitlines() if not p.startswith(("godot/tests/", "godot/content/", "godot/.godot/")) and p not in ["godot/.gitignore", "godot/export_presets.cfg"]]
    input_paths.update(native_files)
    input_paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT / "tools/godot-package").glob("*") if p.is_file())
    input_paths.add("port/native-linux-package/PLAY.md")
    inputs = {p:digest(ROOT / p) for p in sorted(input_paths)}
    # New/untracked authoritative modules must not silently enter the closure.
    for p in closure["modules"]:
        expected = subprocess.check_output(["git", "show", f"{lock['source_commit']}:{p}"], cwd=ROOT)
        if hashlib.sha256(expected).hexdigest() != inputs[p]:
            raise RuntimeError(f"Runtime source differs from lock: {p}")

    toolchain = state / "toolchain"
    toolchain.mkdir(exist_ok=True)
    download(BASE + "SHA512-SUMS.txt", toolchain / "SHA512-SUMS.txt")
    sums = {line.split()[-1].lstrip("*"):line.split()[0] for line in (toolchain / "SHA512-SUMS.txt").read_text().splitlines() if len(line.split()) == 2}
    for local, (official, checksum) in ARCHIVES.items():
        if sums.get(official) != checksum:
            raise RuntimeError(f"Official checksum no longer matches pinned archive: {official}")
        target = toolchain / local
        if not target.exists():
            existing = args.archive_directory / local if args.archive_directory else None
            if existing and existing.is_file():
                copy(existing, target)
            else:
                download(BASE + official, target)
        if digest(target, "sha512") != checksum:
            raise RuntimeError(f"Official archive checksum mismatch: {target}")
    editor = toolchain / f"Godot_v{VERSION}-stable_linux.x86_64"
    with zipfile.ZipFile(toolchain / "editor.zip") as archive:
        editor.write_bytes(archive.read(editor.name))
    editor.chmod(0o755)
    env = dict(os.environ)
    for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
        env[key] = str(work / key)
        Path(env[key]).mkdir()
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    if run([editor, "--version"], env=env) != EXACT:
        raise RuntimeError("Editor exact version mismatch")
    templates = Path(env["XDG_DATA_HOME"]) / "godot/export_templates/4.5.2.stable"
    templates.mkdir(parents=True)
    with zipfile.ZipFile(toolchain / "templates.tpz") as archive:
        for name in ["linux_release.x86_64", "version.txt"]:
            (templates / name).write_bytes(archive.read("templates/" + name))
    if (templates / "version.txt").read_text().strip() != "4.5.2.stable":
        raise RuntimeError("Export template version mismatch")
    (templates / "linux_release.x86_64").chmod(0o755)

    project = work / "project"
    for p in native_files:
        copy(ROOT / p, project / Path(p).relative_to("godot"))
    generated = project / "content/generated"
    run(["node", ROOT / "tools/godot-export/semantic.mjs", generated], log=logs / "semantic.log")
    preset = '''[preset.0]
name="Private Linux Prototype"
platform="Linux"
runnable=true
advanced_options=false
dedicated_server=false
custom_features="private_local_prototype"
export_filter="all_resources"
include_filter="content/generated/*.json,content/generated/maps/*/*.json"
exclude_filter="tests/*,content/probes/*"
export_path=""
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
binary_format/embed_pck=false
binary_format/architecture="x86_64"
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
ssh_remote_deploy/enabled=false
'''
    (project / "export_presets.cfg").write_text(preset)
    run([editor, "--headless", "--path", project, "--editor", "--import"], env=env, log=logs / "import.log")
    package = work / "cocs-native-linux"
    package.mkdir()
    run([editor, "--headless", "--path", project, "--export-release", "Private Linux Prototype", package / "cocs.x86_64"], env=env, log=logs / "export.log")
    if not (package / "cocs.pck").is_file():
        raise RuntimeError("Expected separate PCK")
    if run([package / "cocs.x86_64", "--version"], env=env) != EXACT:
        raise RuntimeError("Exported runtime exact version mismatch")
    for p in closure["modules"]:
        copy(ROOT / p, package / "runtime" / p)

    # Fetch only the already-locked ordinary ws dependency. No npm/install scripts.
    ws = json.loads((ROOT / "package-lock.json").read_text())["packages"]["node_modules/ws"]
    if ws["resolved"] != f"https://registry.npmjs.org/ws/-/ws-{ws['version']}.tgz" or ws.get("license") != "MIT":
        raise RuntimeError("Review unexpected ws provenance/license")
    ws_archive = toolchain / f"ws-{ws['version']}.tgz"
    if not ws_archive.exists():
        download(ws["resolved"], ws_archive)
    integrity = "sha512-" + base64.b64encode(bytes.fromhex(digest(ws_archive, "sha512"))).decode()
    if integrity != ws["integrity"]:
        raise RuntimeError("Locked ws integrity mismatch")
    with tarfile.open(ws_archive) as archive:
        for member in archive.getmembers():
            name = Path(member.name)
            if member.isdir():
                continue
            if not member.isfile() or name.parts[0] != "package" or ".." in name.parts:
                raise RuntimeError("Unexpected ws archive member")
            target = package / "runtime/node_modules/ws" / name.relative_to("package")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.extractfile(member).read())
    if not (package / "runtime/node_modules/ws/LICENSE").is_file():
        raise RuntimeError("ws license missing")
    copy(ROOT / "tools/godot-package/run.mjs", package / "run.mjs")
    copy(ROOT / "tools/godot-package/options.mjs", package / "options.mjs")
    copy(ROOT / "tools/godot-package/endpoint.mjs", package / "endpoint.mjs")
    copy(ROOT / "port/contracts/map-selection.json", package / "catalog.json")
    copy(ROOT / "port/native-linux-package/PLAY.md", package / "README.md")
    notices = package / "licenses"
    notices.mkdir()
    for name in ["LICENSE.txt", "COPYRIGHT.txt"]:
        download(f"https://raw.githubusercontent.com/godotengine/godot/4.5.2-stable/{name}", notices / ("Godot-" + name))
    resources = {"content/generated/" + k:v for k,v in tree(generated).items()}
    # Inventory generated import/export resources, not editor layout/lock caches.
    for p in sorted((project / ".godot").rglob("*")):
        if p.is_file() and "editor" not in p.relative_to(project / ".godot").parts:
            resources[p.relative_to(project).as_posix()] = digest(p)
    run(["node", "--input-type=module", "-e", verify])
    if inputs != {p:digest(ROOT / p) for p in inputs}:
        raise RuntimeError("Build inputs changed during packaging")
    manifest = {
        "schema_version":1, "kind":"private-local-linux-prototype", "release_ready":False,
        "redistribution_rights":"unresolved; local use only; no asset rights asserted",
        "source_commit":lock["source_commit"], "port_commit":git("rev-parse", "HEAD"),
        "worktree_status":git("status", "--short"), "full_history":True, "godot_version":EXACT,
        "godot_export":"release template; assertions disabled; no test fixtures in production PCK",
        "build_node":run(["node", "--version"]), "play_node":">=22.13.0 (external prerequisite)",
        "maps":lock["map_ids"], "server_closure":closure, "server_data_reads":"Only optional history/progression stores; both null. Map/data modules included in closure.",
        "ws":{"version":ws["version"], "integrity":ws["integrity"], "resolved":ws["resolved"], "license":"MIT; retained in runtime/node_modules/ws/LICENSE; optional native accelerators omitted"},
        "toolchain":{"checksums_source":BASE + "SHA512-SUMS.txt", "archives":{v[0]:v[1] for v in ARCHIVES.values()}, "editor_sha256":digest(editor), "release_template_sha256":digest(templates / "linux_release.x86_64")},
        "inputs":inputs, "input_sha256":tree_hash(inputs), "generated_resources":resources,
        "generated_resources_sha256":tree_hash(resources), "staged_export_preset":preset,
        "files":tree(package),
    }
    write_json(package / "manifest.json", manifest)
    archive_path = work / "cocs-native-linux.tar.gz"
    with tarfile.open(archive_path, "w:gz") as archive:
        archive.add(package, arcname=package.name)
    archive_sha = digest(archive_path)
    (work / "cocs-native-linux.tar.gz.sha256").write_text(f"{archive_sha}  {archive_path.name}\n")
    summary = {"archive":str(archive_path), "archive_sha256":archive_sha, "manifest_sha256":digest(package / "manifest.json"), "package":str(package), "build":str(work), "inputs_sha256":manifest["input_sha256"], "generated_resources_sha256":manifest["generated_resources_sha256"]}
    write_json(work / "build-result.json", summary)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
