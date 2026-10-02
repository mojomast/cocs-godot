"""Linux/Windows x86_64 demo package builder. Generated files live outside git."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
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


def allowed_state_root(state):
    """Keep the old tmpfs root; permit an explicitly chosen disk-backed root."""
    roots = [Path("/tmp/opencode")]
    disk = os.environ.get("COCS_PACKAGE_DISK_ROOT", "")
    if disk:
        candidate = Path(disk)
        if not candidate.is_absolute() or not candidate.is_dir() or candidate.is_symlink():
            raise RuntimeError("COCS_PACKAGE_DISK_ROOT must be an existing absolute directory")
        roots.append(candidate.resolve())
    return any(state != root and state.is_relative_to(root) for root in roots)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, required=True, help="owned /tmp/opencode directory outside any checkout")
    parser.add_argument("--archive-directory", type=Path, help="optional read-only source of editor.zip/templates.tpz; official hashes required")
    parser.add_argument("--target", choices=["linux", "windows"], default="linux")
    parser.add_argument("--source-derivative", action="store_true", help="opt into the reviewed combined LATTICE/Horde source derivative; the original source lock stays unchanged")
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
    if not allowed_state_root(state) or state.is_relative_to(ROOT) or ROOT.is_relative_to(state):
        raise RuntimeError("Choose dedicated state under /tmp/opencode or COCS_PACKAGE_DISK_ROOT, outside the checkout")
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
    port_commit = git("rev-parse", "HEAD")
    derivative_path = ROOT / "port/contracts/lattice-catalog-derivative.json"
    derivative = json.loads(derivative_path.read_text()) if args.source_derivative else None
    if lock["godot_version"] != EXACT or git("rev-parse", "--is-shallow-repository") != "false":
        raise RuntimeError("Exact Godot lock and full git history required")
    # Existing verifier checks ancestry plus every tracked locked source/dependency byte.
    verify = "import {verifySource} from './tools/godot-export/semantic.mjs'; import fs from 'node:fs'; const derivative=process.env.COCS_SOURCE_DERIVATIVE; verifySource(JSON.parse(fs.readFileSync('port/contracts/source-lock.json')),derivative?JSON.parse(fs.readFileSync(derivative)):null);"
    derivative_env = {**os.environ, "COCS_SOURCE_DERIVATIVE": str(derivative_path)} if derivative else os.environ.copy()
    if not derivative:
        derivative_env.pop("COCS_SOURCE_DERIVATIVE", None)
    run(["node", "--input-type=module", "-e", verify], env=derivative_env)
    closure = json.loads(run(["node", "--no-warnings", "--experimental-vm-modules", ROOT / "tools/godot-package/discover.mjs", ROOT]))
    write_json(logs / "server-closure.json", closure)
    arena_data = closure.get("dataFiles", [])
    identity_data = closure.get("identityDataFiles", [])
    # Optional discovery family introduced by the Cinderwake lane. Absent on the
    # baseline discover.mjs, so an empty list is valid there.
    horde_data = closure.get("hordeDataFiles", [])
    campaign_data = closure.get("campaignDataFiles", [])
    world_data = closure.get("worldDataFiles", [])
    edge_data = closure.get("edgeDataFiles", [])
    expected_edge_data = ["port/edge-effects/structure-faces.json"] if "port/edge-effects/structure-rays.mjs" in closure["adapterModules"] else []
    if edge_data != expected_edge_data:
        raise RuntimeError("Unexpected campaign facade data closure")
    allowed_campaign_data = {f"godot/campaign/generated/{name}.json" for name in ["rootfall-verge", "siltwake-crossing", "emberline-ascent", "crown-array"]}
    # discover validates the production registry against the unchanged original
    # pairs and bounded prospective IDs. Unregistered recipe files never enter.
    allowed_world_data = set(world_data)
    allowed_arena_data = {f"godot/native_arenas/generated/{name}.json" for name in ["prism-foundry", "aurora-basin", "cinder-array"]}
    allowed_identity_data = {f"godot/identity_maps/generated/{name}.json" for name in ["lacuna-court", "vermilion-fold", "nacre-engine", "canopy-divide", "basalt-reach"]}
    for label, declared, allowed in [("native-arena", arena_data, allowed_arena_data),
                                     ("identity-map", identity_data, allowed_identity_data),
                                     ("multiplayer-world", world_data, allowed_world_data),
                                     ("campaign", campaign_data, allowed_campaign_data)]:
        if (not isinstance(declared, list) or any(not isinstance(p, str) or p not in allowed for p in declared)
                or len(declared) != len(set(declared))):
            raise RuntimeError(f"Unexpected {label} data closure")
    # Horde-map data stays scoped to the reviewed generator directory; the exact
    # files come from the dynamic closure, never a hardcoded name list.
    horde_data_pattern = re.compile(r"^godot/horde_maps/generated/[a-z0-9-]+\.json$")
    if (not isinstance(horde_data, list) or any(not isinstance(p, str) or not horde_data_pattern.fullmatch(p) for p in horde_data)
            or len(horde_data) != len(set(horde_data))):
        raise RuntimeError("Unexpected horde-map data closure")
    if any(p.startswith("port/native-arenas/") for p in closure["adapterModules"]):
        if set(arena_data) != allowed_arena_data or set(identity_data) != allowed_identity_data:
            raise RuntimeError("Native deathmatch adapter requires all six committed arena data files")
    if any(p.startswith("port/multiplayer-worlds/") for p in closure["adapterModules"]):
        if set(world_data) != allowed_world_data:
            raise RuntimeError("Multiplayer world adapter requires its accepted committed gameplay recipes")
    input_paths = set(closure["modules"])
    if any(p.startswith("port/native-campaign/") for p in closure["adapterModules"]):
        if set(campaign_data) != allowed_campaign_data:
            raise RuntimeError("Campaign adapter requires all four committed chapter data files")
    input_paths.update(closure["adapterModules"])
    input_paths.update(arena_data)
    input_paths.update(identity_data)
    input_paths.update(horde_data)
    input_paths.update(campaign_data)
    input_paths.update(world_data)
    input_paths.update(edge_data)
    replay_files = ["game/demo.mjs", "godot/replay/admission.json", "tools/port/replay/adapter.mjs", "tools/port/replay/service.mjs"] if (ROOT / "godot/replay/bridge.gd").is_file() else []
    input_paths.update(replay_files)
    feature_files = json.loads(run(["node", ROOT / "tools/godot-package/feature_resources.mjs", ROOT]))
    input_paths.update(feature_files)
    if edge_data:
        run(["node", "port/edge-effects/bake-structures.mjs", "--check"])
        input_paths.add("port/edge-effects/bake-structures.mjs")
    input_paths.update(["package.json", "package-lock.json", "port/contracts/source-lock.json", "port/contracts/map-selection.json", "tools/godot-export/semantic.mjs"])
    campaign_core_generator = "port/native-campaign/generate-core.mjs"
    if (ROOT / campaign_core_generator).is_file():
        run(["node", campaign_core_generator, "--check"], env=derivative_env)
        input_paths.add(campaign_core_generator)
    world_derivative_generator = "port/multiplayer-worlds/generate-derivative.mjs"
    if (ROOT / world_derivative_generator).is_file():
        run(["node", world_derivative_generator, "--check"])
        input_paths.add(world_derivative_generator)
    world_catalog_generator = "port/multiplayer-worlds/build-world-catalog.mjs"
    if (ROOT / world_catalog_generator).is_file():
        run(["node", world_catalog_generator, "--check"])
        input_paths.add(world_catalog_generator)
        input_paths.update(git("ls-files", "port/native-multiplayer-worlds/worlds").splitlines())
        # Editable masters, recipe generators and Blender scripts are part of
        # the reviewed build provenance even though only GLBs ship in the PCK.
        input_paths.update(git("ls-files", "tools/godot-multiplayer").splitlines())
    if world_data:
        input_paths.update(json.loads(run(["node", ROOT / "tools/godot-package/world_resources.mjs", ROOT])))
    if derivative:
        input_paths.add("port/contracts/lattice-catalog-derivative.json")
    # The Career catalog and its generator arrive with a later lane; include them
    # as build inputs only when present so the baseline build never fails first.
    career_catalog = "godot/career/catalog.json"
    if (ROOT / career_catalog).is_file():
        input_paths.add(career_catalog)
    if (ROOT / "tools/godot-export/career_catalog.mjs").is_file():
        input_paths.add("tools/godot-export/career_catalog.mjs")
        run(["node", "tools/godot-export/career_catalog.mjs", "--check"], env=derivative_env)
    finish_catalog = "godot/first_person/generated/finishes.gd"
    if (ROOT / finish_catalog).is_file():
        input_paths.update([finish_catalog, "tools/godot-weapons/finishes.mjs"])
        run(["node", "tools/godot-weapons/finishes.mjs", "--check"], env=derivative_env)
    caption_generator = "tools/experience/extract.mjs"
    if (ROOT / caption_generator).is_file():
        run(["node", caption_generator, "--check"], env=derivative_env)
        input_paths.update([caption_generator, "game/hud.mjs", "game/data.mjs",
                            "game/assistive-announce.mjs", "game/alt-fire.mjs",
                            "game/lattice-feedback.mjs", "game/deaths.mjs"])
    gameplay_catalog_generator = "port/next-port/gameplay/catalog.mjs"
    if (ROOT / gameplay_catalog_generator).is_file():
        run(["node", gameplay_catalog_generator, "--check"], env=derivative_env)
        input_paths.update([gameplay_catalog_generator, "game/kits.mjs",
                            "game/harness-profiles.mjs", "game/operator-verbs.mjs"])
    audio_pack = ROOT / "tools/godot-audiovisual/music_pack.mjs"
    telegraph_generator = "tools/godot-audiovisual/expansion/telegraph_pack.mjs"
    if "godot/audio/telegraphs/manifest.json" in feature_files:
        run(["node", telegraph_generator, "--check"], env=derivative_env)
        input_paths.add(telegraph_generator)
    if audio_pack.is_file():
        run(["node", audio_pack, "--check"], env=derivative_env)
        input_paths.update(git("ls-files", "tools/godot-audiovisual", "assets/music/THIRD_PARTY_LICENSES.md").splitlines())
        input_paths.update(["game/music.mjs", "game/sampler.mjs", "game/feedback.mjs",
                            "game/lattice-feedback.mjs", "game/environment.mjs", "game/announcer-clips.mjs",
                            "public/music/manifest.json", "public/audio/announcer/manifest.json"])
        music = json.loads((ROOT / "godot/audio/music/manifest.json").read_text())
        voices = json.loads((ROOT / "godot/audio/announcer/manifest.json").read_text())
        input_paths.update("public/music/" + entry["file"] for entry in music["samples"])
        input_paths.update("public/audio/announcer/" + entry["file"] for entry in voices["clips"])
        input_paths.add("public/moth/files/bed-ritual/clip.wav")
        bed_hash = "d518d47b8f4e1722d47a5a5261921edb8d9063bbe6645adc71e54f5509dc829e"
        bed = json.loads((ROOT / "godot/audio/moth/manifest.json").read_text())
        if (bed.get("sha256") != bed_hash or bed.get("file") != "bed-ritual.wav"
                or digest(ROOT / "public/moth/files/bed-ritual/clip.wav") != bed_hash
                or digest(ROOT / "godot/audio/moth/bed-ritual.wav") != bed_hash):
            raise RuntimeError("Moth ritual bed differs from reviewed source asset")
    native_files = [p for p in git("ls-files", "godot").splitlines() if not p.startswith(("godot/tests/", "godot/content/", "godot/.godot/")) and p not in ["godot/.gitignore", "godot/export_presets.cfg"]]
    input_paths.update(native_files)
    input_paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT / "tools/godot-package").glob("*") if p.is_file())
    input_paths.add("port/native-linux-package/PLAY.md")
    if windows:
        input_paths.add("port/native-windows-package/PLAY.md")
    # Bind native presentation/assets and packaging tools to the same reviewed
    # revision as the authority. Unrelated untracked evidence may remain, but no
    # undeclared or locally modified build input may enter either platform.
    tracked_inputs = set(git("ls-files", "--", *sorted(input_paths)).splitlines())
    if input_paths - tracked_inputs:
        raise RuntimeError(f"Uncommitted build inputs: {sorted(input_paths - tracked_inputs)}")
    changed_inputs = git("diff", "--name-only", port_commit, "--", *sorted(input_paths))
    if changed_inputs:
        raise RuntimeError(f"Build inputs differ from reviewed HEAD:\n{changed_inputs}")
    inputs = {p:digest(ROOT / p) for p in sorted(input_paths)}
    # New/untracked authoritative modules must not silently enter the closure.
    for p in closure["modules"]:
        revision = derivative["derivative_commit"] if derivative and p in derivative["runtime_files"] else lock["source_commit"]
        expected = subprocess.check_output(["git", "show", f"{revision}:{p}"], cwd=ROOT)
        if hashlib.sha256(expected).hexdigest() != inputs[p]:
            raise RuntimeError(f"Runtime source differs from lock: {p}")
    # Port-owned adapters and data have separate provenance, never source-lock
    # exemptions. Require committed reviewed bytes; record exact hashes.
    port_owned = [*closure["adapterModules"], *arena_data, *identity_data, *horde_data, *campaign_data, *world_data, *edge_data]
    if career_catalog in input_paths:
        port_owned.append(career_catalog)
    if finish_catalog in input_paths:
        port_owned.append(finish_catalog)
    for p in port_owned:
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
    env = dict(derivative_env)
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
    run(["node", ROOT / "tools/godot-export/semantic.mjs", generated], env=env, log=logs / "semantic.log")
    preset = '''[preset.0]
name="Private Linux Prototype"
platform="Linux"
runnable=true
advanced_options=false
dedicated_server=false
custom_features="private_local_prototype"
export_filter="all_resources"
include_filter="content/generated/*.json,content/generated/maps/*/*.json,moth/generated/*.json,moth/derived/*.json,first_person/*.json,first_person/generated/*.json,native_arenas/generated/*.json,identity_maps/generated/*.json,horde_maps/generated/*.json,multiplayer_worlds/generated/*.json,multiplayer_worlds/generated/worlds/*.json,campaign/generated/*.json,career/*.json,experience/*.json,player_gameplay/catalog.json,ui/*.json,ui/attract/*.json,audio/music/*.json,audio/music/orchestral/*.json,audio/announcer/*.json,audio/moth/*.json"
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
    # Explicit dynamically-read feature catalogs; imported WAV/GDScript resources
    # remain covered by all_resources. Never export tests or arbitrary JSON.
    preset = preset.replace('include_filter="', 'include_filter="input_bindings/contexts.json,replay/admission.json,audio/telegraphs/manifest.json,')
    if windows:
        preset = preset.replace('name="Private Linux Prototype"', f'name="{preset_name}"').replace('platform="Linux"', 'platform="Windows Desktop"')
        preset += '\ncodesign/enable=false\napplication/modify_resources=false\ndebug/export_console_wrapper=0\n'
    (project / "export_presets.cfg").write_text(preset)
    run([editor, "--headless", "--path", project, "--editor", "--import"], env=env, log=logs / "import.log")
    package = work / ("cocs-native-" + args.target)
    package.mkdir()
    replay_hashes = json.loads(run(["node", ROOT / "tools/godot-package/replay_runtime.mjs", ROOT, package / "replay-runtime", port_commit])) if replay_files else {}
    run([editor, "--headless", "--path", project, "--export-release", preset_name, package / executable], env=env, log=logs / "export.log")
    if not (package / "cocs.pck").is_file():
        raise RuntimeError("Expected separate PCK")
    if not windows and run([package / executable, "--version"], env=env) != EXACT:
        raise RuntimeError("Exported runtime exact version mismatch")
    for p in [*closure["modules"], *closure["adapterModules"], *arena_data, *identity_data, *horde_data, *campaign_data, *world_data, *edge_data]:
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
    launcher_helpers = ["run.mjs", "options.mjs", "settings_path.mjs", "career_path.mjs", "endpoint.mjs"]
    for name in launcher_helpers:
        copy(ROOT / "tools/godot-package" / name, package / name)
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
        for name in ["Play.cmd", "Demo Menu.cmd", "Campaign.cmd", "Operator Preview.cmd", "Graphics Showcase.cmd", "Native Deathmatch.cmd", "Domination.cmd", "Cheats.cmd"]:
            (package / name).write_bytes((ROOT / "tools/godot-package" / name).read_text().replace("\r\n", "\n").replace("\n", "\r\n").encode())
    else:
        # Linux parity: the same reviewed entry points as shell scripts, copied with
        # the executable bit. They only set the environment (cheats) and forward to
        # run.mjs with fixed reviewed options.
        for name in ["Domination.sh", "Cheats.sh"]:
            path = package / name
            path.write_bytes((ROOT / "tools/godot-package" / name).read_bytes())
            path.chmod(0o755)
    # The reviewed launcher surface, recorded in the manifest and asserted here.
    # `settings_path.mjs` is the shared menu/route preference-path helper; a
    # missing entry point must fail the build, never ship a partial surface.
    launchers = [*launcher_helpers, "catalog.json", "README.md",
                 *(["Play.cmd", "Demo Menu.cmd", "Campaign.cmd", "Operator Preview.cmd", "Graphics Showcase.cmd", "Native Deathmatch.cmd", "Domination.cmd", "Cheats.cmd"] if windows else ["Domination.sh", "Cheats.sh"])]
    for name in launchers:
        if not (package / name).is_file():
            raise RuntimeError(f"Launcher surface file missing: {name}")
    for name in ["LICENSE.txt", "COPYRIGHT.txt"]:
        download(f"https://raw.githubusercontent.com/godotengine/godot/4.5.2-stable/{name}", notices / ("Godot-" + name))
    if audio_pack.is_file():
        copy(ROOT / "assets/music/THIRD_PARTY_LICENSES.md", notices / "MUSIC_CC0_NOTICES.md")
        copy(ROOT / "godot/audio/README.md", notices / "AUDIO_PROVENANCE.md")
    resources = {"content/generated/" + k:v for k,v in tree(generated).items()}
    # Inventory generated import/export resources, not editor layout/lock caches.
    for p in sorted((project / ".godot").rglob("*")):
        if p.is_file() and "editor" not in p.relative_to(project / ".godot").parts:
            resources[p.relative_to(project).as_posix()] = digest(p)
    run(["node", "--input-type=module", "-e", verify], env=env)
    if inputs != {p:digest(ROOT / p) for p in inputs}:
        raise RuntimeError("Build inputs changed during packaging")
    if git("rev-parse", "HEAD") != port_commit:
        raise RuntimeError("Reviewed revision changed during packaging")
    manifest = {
        "schema_version":1, "kind":"windows-playable-demo" if windows else "private-local-linux-prototype", "release_ready":False,
        "target":args.target, "operator_models":args.operator_models, "staged_native_overrides":staged_overrides,
        "redistribution_rights":"unresolved; local use only; no asset rights asserted",
        "source_commit":lock["source_commit"], "source_derivative_commit":derivative["derivative_commit"] if derivative else None,
        "source_derivative_sha256":digest(derivative_path) if derivative else None, "port_commit":port_commit,
        "worktree_status":git("status", "--short"), "full_history":True, "godot_version":EXACT,
        "godot_export":"release template; assertions disabled; no test fixtures in production PCK",
        "build_node":run(["node", "--version"]), "play_node":f"{NODE_VERSION} (bundled)" if windows else ">=22.13.0 (external prerequisite)", "bundled_node":bundled_node,
        "maps":lock["map_ids"], "native_arenas":[Path(p).stem for p in arena_data],
        "identity_arenas":[Path(p).stem for p in identity_data], "horde_maps":[Path(p).stem for p in horde_data],
        "career_catalog_sha256":inputs.get(career_catalog), "server_closure":closure,
        "server_data_reads":"Owned source-server progression and recent server match history use private persistent configuration paths outside the artifact. Credentials are separate and endpoint-scoped. Locked map modules and explicitly hashed native-arena, identity-map and horde-map JSON are included in the runtime closure.",
        "ws":{"version":ws["version"], "integrity":ws["integrity"], "resolved":ws["resolved"], "license":"MIT; retained in runtime/node_modules/ws/LICENSE; optional native accelerators omitted"},
        "toolchain":{"checksums_source":BASE + "SHA512-SUMS.txt", "archives":{v[0]:v[1] for v in ARCHIVES.values()}, "editor_sha256":digest(editor), "release_template_sha256":digest(templates / template_name)},
        "inputs":inputs, "input_sha256":tree_hash(inputs), "generated_resources":resources,
        "source_runtime_sha256":{p:inputs[p] for p in closure["modules"]},
        "port_adapter_sha256":{p:inputs[p] for p in closure["adapterModules"]},
        "native_arena_data_sha256":{p:inputs[p] for p in arena_data},
        "identity_arena_data_sha256":{p:inputs[p] for p in identity_data},
        "horde_map_data_sha256":{p:inputs[p] for p in horde_data},
        "campaign_data_sha256":{p:inputs[p] for p in campaign_data},
        "edge_data_sha256":{p:inputs[p] for p in edge_data},
        "generated_resources_sha256":tree_hash(resources), "staged_export_preset":preset,
        "launchers":launchers,
        "replay_runtime_sha256":replay_hashes,
        "feature_resource_sha256":{p:inputs[p] for p in feature_files},
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
