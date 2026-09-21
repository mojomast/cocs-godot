#!/usr/bin/env python3
"""Offline integrity/correlation check; acceptance failure remains a failure."""
import gzip
import hashlib
import json
import math
from pathlib import Path
import sys


def records(folder, name):
    path = folder / name
    if path.exists(): return [json.loads(s) for s in path.read_text().splitlines()]
    with gzip.open(str(path)+'.gz', 'rt') as stream: return [json.loads(s) for s in stream]


def main():
    folder = Path(sys.argv[1])
    result = json.loads((folder/'result.json').read_text())
    native = records(folder, 'native.jsonl')
    wire = records(folder, 'wire.jsonl')
    actions = records(folder, 'actions.jsonl')
    queued = [r for r in native if r['event'] == 'input_queue']
    received = [r for r in wire if r['event'] == 'input']
    assert queued and len(queued) == len(received), 'Unequal native/wire input counts'
    assert all(r['queued'] for r in queued), 'Queue failure'
    assert [r['seq'] for r in received] == list(range(1, len(received)+1)), 'Wire input sequence gap'
    for n, w in zip(queued, received):
        assert n['controls'].keys() == w['controls'].keys()
        assert all(math.isclose(v, w['controls'][k], rel_tol=1e-9, abs_tol=1e-9)
                   for k, v in n['controls'].items()), 'Native/wire controls differ'
    assert result['completionProven'] is False and result['nativeTerminalMarker'] is None
    assert actions[0]['event'] == 'harness_start' and actions[-1]['event'] == 'harness_terminated'
    assert all(c['proc_absent'] for c in result['cleanup']['children'])
    assert all(result['cleanup'][k] for k in ['server_port_absent','display_socket_absent','abstract_display_socket_absent'])
    for name, digest in result['provenance']['tools'].items():
        assert hashlib.sha256((Path(__file__).parent/name).read_bytes()).hexdigest() == digest, f'Harness changed: {name}'
    snapshots = [r for r in native if r['event'] == 'snapshot']
    assert all(r['lifecycle'] == 'alive' for r in snapshots), 'Run left active-alive scope'
    print(f'Evidence correlation PASS: {len(queued)} native queues match {len(received)} consecutive server inputs; all local snapshots alive.')
    print(f"Recorded acceptance status: {result['status']}; completionProven=false.")
    for c in result['checks']:
        if not c['passed']: print('Acceptance failure:', c['name'])


if __name__ == '__main__': main()
