"""Assemble the offline Windows rendered-GPU checks from a committed checkout."""
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
import zipfile

EDITOR_NAME = 'Godot_v4.5.2-stable_win64.exe.zip'
EDITOR_SHA512 = 'b21115cf3620438e17959d13946bf9c7dceabb6ff71ed32a68996a21e08615edd2d1a3d25641bb3e260d084b31f500231aa59fcf026a5228bcc20ac4e8bade60'
NODE_NAME = 'node-v22.22.0-win-x64.zip'
NODE_SHA256 = 'c97fa376d2becdc8863fcd3ca2dd9a83a9f3468ee7ccf7a6d076ec66a645c77a'
IMPORT = re.compile(r'''(?:\bimport\s*(?:\(\s*|(?:[\s\S]*?\s+from\s*)?)|\bexport\s+(?:[^;]*?\s+from\s*))['"]([^'"]+)['"]''')
ROOT_FILES = ('package.json', 'tools/godot-package/run-gpu-checks.cmd', 'tools/godot-package/tee-gpu-check.mjs')
ENTRYPOINTS = ('scripts/world-weather-journey.mjs', 'godot/tests/horde/upgrade_loopback.mjs')


def digest(path, algorithm):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def tracked(root):
    return {p.decode() for p in subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z']).split(b'\0') if p}


def closure(root, files):
    seen = set()
    pending = list(ENTRYPOINTS)
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        if path not in files or not (root / path).is_file():
            raise RuntimeError(f'Missing tracked module: {path}')
        seen.add(path)
        text = (root / path).read_text()
        for spec in IMPORT.findall(text):
            if spec.startswith('.'):
                target = (Path(path).parent / spec).as_posix()
                import posixpath
                target = posixpath.normpath(target)
                pending.append(target)
            elif spec not in ('ws',) and not spec.startswith('node:'):
                raise RuntimeError(f'Unexpected dependency {spec!r} in {path}')
    return seen


def extract_one(archive, name, target):
    with zipfile.ZipFile(archive) as source:
        if name not in source.namelist():
            raise RuntimeError(f'{archive}: missing {name}')
        target.parent.mkdir(parents=True, exist_ok=True)
        with source.open(name) as src, target.open('wb') as dst:
            shutil.copyfileobj(src, dst)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('repo_root', type=Path)
    parser.add_argument('--toolchain', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path, help='dedicated output/state directory outside the checkout')
    args = parser.parse_args()
    root, toolchain, output = (p.resolve() for p in (args.repo_root, args.toolchain, args.output))
    if root == output or root in output.parents or output in root.parents:
        raise RuntimeError('Output must be outside the checkout')
    bundle = output / 'cocs-gpu-checks-windows'
    if bundle.exists() or (output / 'cocs-gpu-checks-windows.zip').exists():
        raise RuntimeError(f'Refusing to overwrite existing build in {output}')
    files = tracked(root)
    modules = closure(root, files)
    selected = modules | set(ROOT_FILES)
    # Runtime modules also read local JSON via fs/new URL (not ESM imports).
    parents = {str(Path(p).parent) for p in modules}
    selected |= {p for p in files if str(Path(p).parent) in parents and p.endswith('.json')}
    # All tracked Godot resources: the scenes have transitive resource and import
    # dependencies beyond the JavaScript module graph. Never copy .godot cache.
    selected |= {p for p in files if p.startswith('godot/')}
    selected |= {p for p in files if p.startswith('port/contracts/') and p.endswith('.json')}
    for name in selected:
        if name not in files or not (root / name).is_file() or (root / name).is_symlink():
            raise RuntimeError(f'Missing ordinary tracked source: {name}')
    editor, node, ws = (toolchain / p for p in ('editor.zip', NODE_NAME, 'ws-8.21.3.tgz'))
    for archive in (editor, node, ws, toolchain / 'SHA512-SUMS.txt', toolchain / 'NODE-SHASUMS256.txt'):
        if not archive.is_file():
            raise RuntimeError(f'Missing toolchain input: {archive}')
    if (EDITOR_SHA512 + '  ' + EDITOR_NAME) not in (toolchain / 'SHA512-SUMS.txt').read_text() or digest(editor, 'sha512') != EDITOR_SHA512:
        raise RuntimeError('Wrong Windows Godot editor.zip or SHA512-SUMS.txt')
    if (NODE_SHA256 + '  ' + NODE_NAME) not in (toolchain / 'NODE-SHASUMS256.txt').read_text() or digest(node, 'sha256') != NODE_SHA256:
        raise RuntimeError('Wrong Node archive or checksum')
    lock = json.loads((root / 'package-lock.json').read_text())['packages']['node_modules/ws']
    if lock['version'] != '8.21.3' or 'sha512-' + base64.b64encode(bytes.fromhex(digest(ws, 'sha512'))).decode() != lock['integrity']:
        raise RuntimeError('Wrong ws archive (package-lock integrity)')
    bundle.mkdir(parents=True)
    for name in sorted(selected):
        destination = bundle / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / name, destination)
    generated = bundle / 'godot/content/generated'
    if generated.exists():
        raise RuntimeError(f'Unexpected tracked semantic output: {generated}')
    # The Godot editor import does not build the source-owned content catalog.
    # semantic.mjs resolves its source lock and derivative relative to the git
    # checkout, but writes the resulting maps into the staged project.
    env = os.environ.copy()
    env.pop('COCS_SOURCE_DERIVATIVE', None)  # use the reviewed active-source descriptor
    subprocess.run(['node', str(root / 'tools/godot-export/semantic.mjs'), str(generated)],
                   cwd=root, env=env, check=True)
    manifest_file = generated / 'manifest.json'
    if not manifest_file.is_file() or not manifest_file.stat().st_size:
        raise RuntimeError('Semantic export did not write a non-empty manifest')
    manifest = json.loads(manifest_file.read_text())
    if not manifest.get('maps') or any(not (generated / row['path']).is_file() for row in manifest['maps']):
        raise RuntimeError('Semantic export did not write its declared maps')
    extract_one(editor, 'Godot_v4.5.2-stable_win64.exe', bundle / 'Godot.exe')
    extract_one(node, 'node-v22.22.0-win-x64/node.exe', bundle / 'node.exe')
    with tarfile.open(ws, 'r:gz') as archive:
        for member in archive:
            if member.isdir():
                continue
            name = Path(member.name)
            if not member.isfile() or name.parts[0] != 'package' or len(name.parts) < 2 or '..' in name.parts:
                raise RuntimeError(f'Unexpected ws member: {member.name}')
            dest = bundle / 'node_modules/ws' / Path(*name.parts[1:])
            dest.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(member) as src, dest.open('wb') as dst:
                shutil.copyfileobj(src, dst)
    (bundle / 'GPU Checks.cmd').write_bytes((root / 'tools/godot-package/GPU Checks.cmd').read_bytes())
    (bundle / 'README-GPU-CHECKS.md').write_bytes((root / 'tools/godot-package/README-GPU-CHECKS.md').read_bytes())
    archive_path = output / 'cocs-gpu-checks-windows.zip'
    raw = 0
    with zipfile.ZipFile(archive_path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as archive:
        for path in sorted((p for p in bundle.rglob('*') if p.is_file()), key=lambda p: p.relative_to(bundle).as_posix()):
            relative = path.relative_to(bundle).as_posix()
            info = zipfile.ZipInfo(relative, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=6)
            raw += path.stat().st_size
    print(f'Modules: {len(modules)}; tracked Godot: {sum(p.startswith("godot/") for p in files)} files')
    print(f'Semantic content: {len(manifest["maps"])} maps, {sum(p.stat().st_size for p in generated.rglob("*") if p.is_file()):,} bytes')
    print(f'Raw: {raw:,} bytes; zip: {archive_path.stat().st_size:,} bytes; archive: {archive_path}')


if __name__ == '__main__':
    main()
