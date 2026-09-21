"""Install the exact editor and Linux templates outside the source checkout."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.5.2"
BASE = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/"
parser = argparse.ArgumentParser()
parser.add_argument("--directory", type=Path, default=Path("../godot-toolchain"))
args = parser.parse_args()
directory = args.directory.resolve()
directory.mkdir(parents=True, exist_ok=True)
sums = urllib.request.urlopen(BASE + "SHA512-SUMS.txt", timeout=60).read().decode()
expected = {line.split()[-1].lstrip("*"): line.split()[0] for line in sums.splitlines() if len(line.split()) == 2}
files = {
    f"Godot_v{VERSION}-stable_linux.x86_64.zip": "editor.zip",
    f"Godot_v{VERSION}-stable_export_templates.tpz": "templates.tpz",
}
report = {"version": VERSION, "checksums_source": BASE + "SHA512-SUMS.txt", "files": {}}
for official, local in files.items():
    target = directory / local
    if not target.exists():
        urllib.request.urlretrieve(BASE + official, target)
    hasher = hashlib.sha512()
    with target.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    actual = hasher.hexdigest()
    if expected.get(official) != actual:
        raise RuntimeError(f"Checksum mismatch: {target}")
    report["files"][official] = actual
with zipfile.ZipFile(directory / "editor.zip") as archive:
    name = f"Godot_v{VERSION}-stable_linux.x86_64"
    (directory / name).write_bytes(archive.read(name))
    (directory / name).chmod(0o755)
templates = directory / "data/godot/export_templates" / f"{VERSION}.stable"
templates.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(directory / "templates.tpz") as archive:
    for name in ["linux_debug.x86_64", "linux_release.x86_64", "version.txt"]:
        (templates / name).write_bytes(archive.read("templates/" + name))
        (templates / name).chmod(0o755)
Path("port/reports/toolchain.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"Verified official SHA512 checksums; installed {VERSION} editor and matching Linux templates in {directory}")
