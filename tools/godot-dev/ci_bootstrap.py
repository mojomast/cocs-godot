"""Stage only this run's bounded native CI logs, including failed setup output."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
state = Path(sys.argv[1]).resolve()
destination = state / "artifact"
destination.mkdir(parents=True, exist_ok=True)
started = state / "started"
since = started.stat().st_mtime_ns if started.exists() else 0
sources = [("setup", path) for path in sorted(state.glob("*.log"))]
# Checkout already contains historical reports. Never upload them as new results.
if started.exists():
    reports = root / "port/reports"
    # Keep the current summary ahead of optional individual logs as the gate
    # count grows. The 80-file cap must not silently discard verification.json.
    sources += [("reports", path) for path in sorted(reports.glob("*.json"), key=lambda path: (path.name != "verification.json", path.name))
                if path.stat().st_mtime_ns >= since]
    sources += [("gates", path) for path in sorted(reports.glob("*.log"))
                if path.stat().st_mtime_ns >= since]

limit = 128 * 1024
manifest = {"max_files": 80, "max_bytes_per_file": limit, "files": [],
            "omitted_files": max(0, len(sources) - 80)}
for group, source in sources[:80]:
    size = source.stat().st_size
    truncated = size > limit
    target = destination / group / (source.name + (".tail.txt" if truncated else ""))
    target.parent.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as stream:
        stream.seek(max(0, size - limit))
        target.write_bytes(stream.read(limit))
    manifest["files"].append({"path": str(target.relative_to(destination)),
                              "source_bytes": size, "truncated": truncated})
(destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Staged {len(manifest['files'])} files in {destination}")
