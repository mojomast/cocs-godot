"""Check recorded ephemeral endpoints and runtime processes in this worktree."""
import json
import os
from pathlib import Path
import socket

root = Path.cwd().resolve()
evidence = root / 'port/native-lattice-world/evidence'
ports = []
for path in evidence.glob('*/*/manifest.json'):
    port = json.loads(path.read_text())['port']
    with socket.socket() as connection:
        connection.settimeout(0.25)
        closed = connection.connect_ex(('127.0.0.1', port)) != 0
    ports.append(dict(port=port, closed=closed))
processes = []
for path in Path('/proc').iterdir():
    if not path.name.isdigit() or int(path.name) == os.getpid():
        continue
    try:
        exe = (path / 'exe').resolve().name
        cwd = (path / 'cwd').resolve()
        if cwd == root and (exe in ['node', 'Xvfb'] or exe.startswith('Godot')):
            processes.append(dict(pid=int(path.name), executable=exe))
    except (OSError, PermissionError):
        pass
result = dict(passed=all(p['closed'] for p in ports) and not processes, ports=ports, runtimeProcesses=processes)
(evidence / 'cleanup.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
raise SystemExit(0 if result['passed'] else 1)
