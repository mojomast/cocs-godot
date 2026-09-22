"""Inspect only this worktree's children and recorded loopback ports."""
import json
import os
from pathlib import Path
import socket

root = Path.cwd().resolve()
evidence = root / 'port/native-lattice-physical/evidence'
ports = sorted({json.loads(path.read_text())['port'] for path in evidence.glob('*/*/manifest.json')})
port_checks = []
for port in ports:
    with socket.socket() as connection:
        connection.settimeout(0.2)
        port_checks.append({'port': port, 'closed': connection.connect_ex(('127.0.0.1', port)) != 0})
children = []
for path in Path('/proc').iterdir():
    if not path.name.isdigit() or int(path.name) == os.getpid():
        continue
    try:
        if (path / 'cwd').resolve() != root:
            continue
        command = (path / 'cmdline').read_bytes().split(b'\0')
        if any(b'Godot_v' in arg or b'Xvfb' in arg or b'port/native-lattice-physical/run.mjs' == arg for arg in command):
            children.append({'pid': int(path.name), 'executable': command[0].decode()})
    except (OSError, PermissionError):
        pass
report = {'ports': port_checks, 'ownedRuntimeChildren': children, 'passed': all(check['closed'] for check in port_checks) and not children}
(evidence / 'cleanup.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
raise SystemExit(0 if report['passed'] else 1)
