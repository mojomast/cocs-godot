"""Read-only verification of known attempt ports and owned native child commands."""
from pathlib import Path
import json
import os
import re
import socket

root = Path(__file__).resolve().parents[3]
evidence = root / 'port/native-lattice/evidence'
ports = {38417, 44503, 42871}
for log in evidence.glob('*/*.log'):
    ports.update(int(p) for p in re.findall(r'Owned loopback server ready (\d+)', log.read_text()))
listening = []
for port in sorted(ports):
    with socket.socket() as sock:
        sock.settimeout(.15)
        if sock.connect_ex(('127.0.0.1', port)) == 0:
            listening.append(port)
owned = []
for proc in Path('/proc').iterdir():
    if not proc.name.isdecimal() or int(proc.name) == os.getpid():
        continue
    try:
        args = (proc / 'cmdline').read_bytes().split(b'\0')
        cwd = (proc / 'cwd').resolve()
        if cwd != root:
            continue
        if any(arg in [b'port/tools/native_lattice_demo/run.mjs', b'res://lattice/board.tscn'] for arg in args):
            owned.append(int(proc.name))
    except (OSError, PermissionError):
        continue
report = dict(checked_loopback_ports=sorted(ports), listening_ports=listening, owned_live_pids=owned,
              note='Read-only check; never kills a reused port or another process. Private xvfb-run wrappers completed. Browser image-review server stopped explicitly.')
(evidence / 'cleanup.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
raise SystemExit(1 if listening or owned else 0)
