"""Adapt cinematic retained PGIDs to K/L's existing read-only release scanner."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import time

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('motion_release', ROOT / 'tools/motion-review/release.py')
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--grant', required=True)
    options = parser.parse_args()
    evidence = options.evidence.resolve()
    groups, receipts = set(), []
    for pattern, field in [('*.process.json', 'pid'), ('*.supervision.json', 'owned_process_group')]:
        for path in evidence.rglob(pattern):
            data = json.loads(path.read_text())
            if data.get(field):
                groups.add(data[field])
            receipts.append(str(path))
    if not receipts:
        raise ValueError('No actual process receipts; cannot issue an empty production release')
    audits = []
    for index in range(3):
        found, foreign = scanner.processes(groups, str(ROOT), str(evidence))
        audits.append({'at': datetime.now(timezone.utc).isoformat(), 'matches': found,
                       'unowned_native_observations': foreign})
        if index < 2:
            time.sleep(.3)
    released = not any(a['matches'] for a in audits)
    result = {'grant': options.grant, 'released': released, 'owned_groups': sorted(groups),
              'receipts': receipts, 'audits': audits, 'scope': 'all cinematic native and encoder groups; no processes signalled'}
    path = evidence / ('release.json' if released else 'release-blocked.json')
    with path.open('x') as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps({'released': released, 'path': str(path)}))
    return 0 if released else 1


if __name__ == '__main__':
    raise SystemExit(main())
