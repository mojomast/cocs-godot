"""Read-only use of the final runner's exact identity, without executing gates."""
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(root / 'tools/godot-dev'))
from finish_runner import input_identity, load_matrix

report = json.loads(Path(sys.argv[1]).read_text())
if Path(report['root']).resolve() != root:
    raise ValueError('Ledger belongs to another checkout')
environment = report['input_identity']['environment']
if any(os.environ.get(key, '') != value for key, value in environment.items()):
    raise ValueError('Final ledger environment changed')
matrix = load_matrix(root / 'port/finish/final_matrix.json', root=root)
if report['queue'] != matrix['jobs']:
    raise ValueError('Different final gate contract')
actual = input_identity(root, matrix, environment)
if actual != report['input_identity']:
    raise ValueError('Final candidate identity changed; fresh ledger and capture required')
print(json.dumps(actual))
