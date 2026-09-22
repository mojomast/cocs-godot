"""Linux/Windows x86_64 demo package builder. Generated files live outside git."""
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


NODE_VERSION = "22.22.0"
NODE_WINDOWS_SHA256 = "c97fa376d2becdc8863fcd3ca2dd9a83a9f3468ee7ccf7a6d076ec66a645c77a"


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
    parser.add_argument("--target", choices=["linux", "windows"], default="linux")
    parser.add_argument("--operator-models", choices=["source-operators", "baseline", "candidate"], default="source-operators",
                        help="source-operators (default) ships the released presentation.gd source-operator preload; baseline is an accepted alias; candidate is retired")
    args = parser.parse_args()
    if args.operator_models == "candidate":
        raise RuntimeError("--operator-models candidate is retired: godot/world/presentation.gd now defaults to "
                           "res://source_operators/operator_visual.gd; there is no staging patch to apply")
    if args.operator_models == "baseline":
        args.operator_models = "source-operators"
    windows = args.target == "windows"
    template_name = "windows_release_x86_64.exe" if windows else "linux_release.x86_64"
    executable = "cocs.exe" if windows else "cocs.x86_64"
    preset_name = "Windows Desktop Demo" if windows else "Private Linux Prototype"
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
    arena_data = closure.get("dataFiles", [])
    identity_data = closure.get("identityDataFiles", [])
    allowed_arena_data = {f"godot/native_arenas/generated/{name}.json" for name in ["prism-foundry", "aurora-basin", "cinder-array"]}
    allowed_identity_data = {f"godot/identity_maps/generated/{name}.json" for name in ["lacuna-court", "vermilion-fold", "nacre-engine"]}
    for label, declared, allowed in [("native-arena", arena_data, allowed_arena_data),
                                     ("identity-map", identity_data, allowed_identity_data)]:
        if (not isinstance(declared, list) or any(not isinstance(p, str) or p not in allowed for p in declared)
                or len(declared) != len(set(declared))):
            raise RuntimeError(f"Unexpected {label} data closure")
    if any(p.startswith("port/native-arenas/") for p in closure["adapterModules"]):
        if set(arena_data) != allowed_arena_data or set(identity_data) != allowed_identity_data:
            raise RuntimeError("Native deathmatch adapter requires all six committed arena data files")
    input_paths = set(closure["modules"])
    input_paths.update(closure["adapterModules"])
    input_paths.update(arena_data)
    input_paths.update(identity_data)
    input_paths.update(["package.json", "package-lock.json", "port/contracts/source-lock.json", "port/contracts/map-selection.json", "tools/godot-export/semantic.mjs"])
    native_files = [p for p in git("ls-files", "godot").splitlines() if not p.startswith(("godot/tests/", "godot/content/", "godot/.godot/")) and p not in ["godot/.gitignore", "godot/export_presets.cfg"]]
    input_paths.update(native_files)
    input_paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT / "tools/godot-package").glob("*") if p.is_file())
    input_paths.add("port/native-linux-package/PLAY.md")
    if windows:
        input_paths.add("port/native-windows-package/PLAY.md")
    inputs = {p:digest(ROOT / p) for p in sorted(input_paths)}
    # New/untracked authoritative modules must not silently enter the closure.
    for p in closure["modules"]:
        expected = subprocess.check_output(["git", "show", f"{lock['source_commit']}:{p}"], cwd=ROOT)
        if hashlib.sha256(expected).hexdigest() != inputs[p]:
            raise RuntimeError(f"Runtime source differs from lock: {p}")
    # Port-owned adapters have separate provenance, never source-lock exemptions.
    # Require committed reviewed bytes; record their exact hashes independently.
    for p in [*closure["adapterModules"], *arena_data, *identity_data]:
        expected = subprocess.check_output(["git", "show", f"HEAD:{p}"], cwd=ROOT)
        if hashlib.sha256(expected).hexdigest() != inputs[p]:
            raise RuntimeError(f"Uncommitted runtime adapter/data: {p}")

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
        for name in [template_name, "version.txt"]:
            (templates / name).write_bytes(archive.read("templates/" + name))
    if (templates / "version.txt").read_text().strip() != "4.5.2.stable":
        raise RuntimeError("Export template version mismatch")
    (templates / template_name).chmod(0o755)

    project = work / "project"
    for p in native_files:
        copy(ROOT / p, project / Path(p).relative_to("godot"))
    staged_overrides = {}
    # The shipped composition already preloads the source operators; any future
    # staged operator override must be explicit and hashed, never silent.
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
include_filter="content/generated/*.json,content/generated/maps/*/*.json,moth/generated/*.json,first_person/*.json,first_person/generated/*.json,native_arenas/generated/*.json,identity_maps/generated/*.json"
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
    if (project / "player_models/recipes.json").is_file():
        preset = preset.replace('include_filter="', 'include_filter="player_models/*.json,')
    if windows:
        preset = preset.replace('name="Private Linux Prototype"', f'name="{preset_name}"').replace('platform="Linux"', 'platform="Windows Desktop"')
        preset += '\ncodesign/enable=false\napplication/modify_resources=false\ndebug/export_console_wrapper=0\n'
    (project / "export_presets.cfg").write_text(preset)
    run([editor, "--headless", "--path", project, "--editor", "--import"], env=env, log=logs / "import.log")
    package = work / ("cocs-native-" + args.target)
    package.mkdir()
    run([editor, "--headless", "--path", project, "--export-release", preset_name, package / executable], env=env, log=logs / "export.log")
    if not (package / "cocs.pck").is_file():
        raise RuntimeError("Expected separate PCK")
    if not windows and run([package / executable, "--version"], env=env) != EXACT:
        raise RuntimeError("Exported runtime exact version mismatch")
    for p in [*closure["modules"], *closure["adapterModules"], *arena_data, *identity_data]:
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
    copy(ROOT / ("port/native-windows-package/PLAY.md" if windows else "port/native-linux-package/PLAY.md"), package / "README.md")
    notices = package / "licenses"
    notices.mkdir()
    bundled_node = None
    if windows:
        node_name = f"node-v{NODE_VERSION}-win-x64.zip"
        node_base = f"https://nodejs.org/dist/v{NODE_VERSION}/"
        download(node_base + "SHASUMS256.txt", toolchain / "NODE-SHASUMS256.txt")
        node_sums = {line.split()[-1]:line.split()[0] for line in (toolchain / "NODE-SHASUMS256.txt").read_text().splitlines() if len(line.split()) == 2}
        if node_sums.get(node_name) != NODE_WINDOWS_SHA256:
            raise RuntimeError("Official Node checksum differs from pinned Windows runtime")
        node_archive = toolchain / node_name
        if not node_archive.is_file():
            download(node_base + node_name, node_archive)
        if digest(node_archive) != NODE_WINDOWS_SHA256:
            raise RuntimeError("Node Windows archive checksum mismatch")
        with zipfile.ZipFile(node_archive) as archive:
            prefix = f"node-v{NODE_VERSION}-win-x64/"
            (package / "node.exe").write_bytes(archive.read(prefix + "node.exe"))
            (notices / "Node-LICENSE.txt").write_bytes(archive.read(prefix + "LICENSE"))
        bundled_node = {"version":NODE_VERSION, "url":node_base + node_name, "archive_sha256":NODE_WINDOWS_SHA256, "executable_sha256":digest(package / "node.exe")}
        for name in ["Play.cmd", "Demo Menu.cmd", "Operator Preview.cmd", "Graphics Showcase.cmd", "Native Deathmatch.cmd"]:
            (package / name).write_bytes((ROOT / "tools/godot-package" / name).read_text().replace("\r\n", "\n").replace("\n", "\r\n").encode())
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
        "schema_version":1, "kind":"windows-playable-demo" if windows else "private-local-linux-prototype", "release_ready":False,
        "target":args.target, "operator_models":args.operator_models, "staged_native_overrides":staged_overrides,
        "redistribution_rights":"unresolved; local use only; no asset rights asserted",
        "source_commit":lock["source_commit"], "port_commit":git("rev-parse", "HEAD"),
        "worktree_status":git("status", "--short"), "full_history":True, "godot_version":EXACT,
        "godot_export":"release template; assertions disabled; no test fixtures in production PCK",
        "build_node":run(["node", "--version"]), "play_node":f"{NODE_VERSION} (bundled)" if windows else ">=22.13.0 (external prerequisite)", "bundled_node":bundled_node,
        "maps":lock["map_ids"], "native_arenas":[Path(p).stem for p in arena_data],
        "identity_arenas":[Path(p).stem for p in identity_data], "server_closure":closure,
        "server_data_reads":"Optional history/progression stores are null. Locked map modules and explicitly hashed native-arena plus identity-map JSON are included in the runtime closure.",
        "ws":{"version":ws["version"], "integrity":ws["integrity"], "resolved":ws["resolved"], "license":"MIT; retained in runtime/node_modules/ws/LICENSE; optional native accelerators omitted"},
        "toolchain":{"checksums_source":BASE + "SHA512-SUMS.txt", "archives":{v[0]:v[1] for v in ARCHIVES.values()}, "editor_sha256":digest(editor), "release_template_sha256":digest(templates / template_name)},
        "inputs":inputs, "input_sha256":tree_hash(inputs), "generated_resources":resources,
        "source_runtime_sha256":{p:inputs[p] for p in closure["modules"]},
        "port_adapter_sha256":{p:inputs[p] for p in closure["adapterModules"]},
        "native_arena_data_sha256":{p:inputs[p] for p in arena_data},
        "identity_arena_data_sha256":{p:inputs[p] for p in identity_data},
        "generated_resources_sha256":tree_hash(resources), "staged_export_preset":preset,
        "files":tree(package),
    }
    write_json(package / "manifest.json", manifest)
    archive_path = work / (package.name + (".zip" if windows else ".tar.gz"))
    if windows:
        with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for p in sorted(package.rglob("*")):
                if p.is_file():
                    archive.write(p, p.relative_to(work).as_posix())
    else:
        with tarfile.open(archive_path, "w:gz") as archive:
            archive.add(package, arcname=package.name)
    archive_sha = digest(archive_path)
    archive_path.with_name(archive_path.name + ".sha256").write_text(f"{archive_sha}  {archive_path.name}\n")
    summary = {"archive":str(archive_path), "archive_sha256":archive_sha, "manifest_sha256":digest(package / "manifest.json"), "package":str(package), "build":str(work), "inputs_sha256":manifest["input_sha256"], "generated_resources_sha256":manifest["generated_resources_sha256"]}
    write_json(work / "build-result.json", summary)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
