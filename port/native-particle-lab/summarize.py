#!/usr/bin/env python3
"""Summarize retained native measurements; never substitute requested for actual."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    rows = []
    for path in sorted(args.directory.glob("*/metrics.json")):
        data = json.loads(path.read_text())
        actual = data["emitter_amount"] if data["backend"] == "gpu" else data["visible_instance_count"]
        assert actual == data["draw_slots"] == data["requested_count"], path
        assert data["primitives"] >= actual * 2, path
        intervals = sorted(data["raw_intervals_ms"])
        assert len(intervals) == data["timing"]["samples"], path
        index = (len(intervals) - 1) / 2
        median = (intervals[int(index)] + intervals[int(index + 0.5)]) / 2
        assert abs(median - data["timing"]["median_ms"]) < 0.001, path
        rows.append({"case": path.parent.name, "actual": actual, "backend": data["backend"],
                     "preset": data["preset"], "window": data["window_size"],
                     "target": data["render_target"], "n": len(intervals),
                     "median_ms": round(data["timing"]["median_ms"], 3),
                     "p95_ms": round(data["timing"]["p95_ms"], 3),
                     "max_ms": round(data["timing"]["max_ms"], 3),
                     "engine_buffer_mib": round(data["render_buffer_bytes"] / 1048576, 2),
                     "primitives": data["primitives"], "ok": data["ok"]})
    print("| Window / target | Preset / backend | Actual slots | n | Median ms | p95 ms | Engine buffers MiB |")
    print("| --- | --- | ---: | ---: | ---: | ---: | ---: |")
    for r in rows:
        window = "×".join(map(str, r["window"]))
        target = "×".join(map(str, r["target"]))
        print(f'| {window} / {target} | {r["preset"]} / {r["backend"]} | {r["actual"]:,} | {r["n"]} | {r["median_ms"]:.2f} | {r["p95_ms"]:.2f} | {r["engine_buffer_mib"]:.2f} |')
    (args.directory / "summary.json").write_text(json.dumps(rows, indent=2) + "\n")


if __name__ == "__main__":
    main()
