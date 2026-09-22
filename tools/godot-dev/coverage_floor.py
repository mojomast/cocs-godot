#!/usr/bin/env python3
"""Fail the aggregate when Moth asset coverage regresses.

`tools/godot-moth/coverage.mjs` is a reporting tool: it always exits 0, so registering
it as a gate would prove nothing. The asset coverage pass exists to raise coverage, so
this wrapper runs the scan and asserts the measured totals stay at or above the
recorded floor. A key that stops being referenced anywhere in the project is a
regression and fails here with the specific keys named.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FLOOR = ROOT / "port/contracts/moth-coverage-floor.json"


def main() -> int:
    floor = json.loads(FLOOR.read_text())
    with tempfile.TemporaryDirectory(prefix="moth-coverage-", dir="/tmp/opencode") as temporary:
        report_path = Path(temporary) / "coverage.json"
        result = subprocess.run(
            ["node", "tools/godot-moth/coverage.mjs", f"--json={report_path}"],
            cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300,
        )
        if result.returncode != 0:
            print(result.stdout)
            print("coverage scan failed")
            return 1
        report = json.loads(report_path.read_text())
    totals = report["totals"]
    failures = []
    for key, minimum in floor.items():
        measured = totals.get(key)
        if not isinstance(measured, (int, float)):
            failures.append(f"{key}: missing from the scan")
        elif measured < minimum:
            failures.append(f"{key}: {measured} < recorded floor {minimum}")
    if failures:
        print("MOTH_COVERAGE_FLOOR_FAILED")
        for failure in failures:
            print("  " + failure)
        for bucket, rows in report.get("buckets", {}).items():
            unused = [name for name, row in rows.items() if not row.get("strict")]
            if unused:
                print(f"  {bucket} unreferenced: {', '.join(sorted(unused))}")
        return 1
    print("MOTH_COVERAGE_FLOOR_OK " + json.dumps({**totals, "floor": floor}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
