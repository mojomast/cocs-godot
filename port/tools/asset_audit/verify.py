"""Run focused offline checks and retain real evidence in the audit directory."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'port/asset-audit'


def main():
    test = subprocess.run([sys.executable, '-B', '-m', 'unittest', 'discover',
                           '-s', 'port/tools/asset_audit', '-v'], cwd=ROOT,
                          capture_output=True, text=True)
    (OUT / 'tests.txt').write_text(test.stdout + test.stderr)
    print(test.stdout + test.stderr, end='')
    if test.returncode:
        return test.returncode
    command = [sys.executable, '-B', 'port/tools/asset_audit/inventory.py']
    first = subprocess.check_output(command, cwd=ROOT)
    second = subprocess.check_output(command, cwd=ROOT)
    saved = (OUT / 'inventory.json').read_bytes()
    if not first == second == saved:
        raise ValueError('inventory is stale or nondeterministic')
    data = json.loads(first)
    missing = [r for r in data['references'] if not r['exists']]
    mismatches = [r for r in data['references'] if r.get('hash_matches_manifest') is False]
    for file in data['files']:
        digest = hashlib.sha256((ROOT / file['path']).read_bytes()).hexdigest()
        if digest != file['sha256']:
            raise ValueError('source changed during verification: ' + file['path'])
    report = {'schema_version': 1, 'base_commit': '9e46ad9d0b11dc21538b8c21087c4d2205798fd8',
              'tests_exit_code': test.returncode, 'deterministic_and_matches_saved': True,
              'source_hashes_rechecked': len(data['files']), 'inventory_bytes': len(first),
              'inventory_sha256': hashlib.sha256(first).hexdigest(),
              'missing_references': missing, 'manifest_hash_mismatches': mismatches,
              'test_command': 'python3 -B -m unittest discover -s port/tools/asset_audit -v'}
    (OUT / 'verification.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(json.dumps(report, indent=2, sort_keys=True))
    return 1 if missing or mismatches else 0


if __name__ == '__main__':
    sys.exit(main())
