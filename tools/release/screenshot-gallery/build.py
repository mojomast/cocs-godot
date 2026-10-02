#!/usr/bin/env python3
"""Snapshot recent game screenshots, retaining duplicate provenance and capture frames."""
import argparse
import collections
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import shutil
import time

p = argparse.ArgumentParser()
p.add_argument('--candidates', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--hours', type=float, default=12)
p.add_argument('--end', type=float, default=time.time())
a = p.parse_args()
start = a.end - a.hours * 3600
base = Path('/home/mojo/.tmp-on-disk')
canonical = base / 'cocs-relay-campaign-20260930'
a.output.mkdir(parents=True, exist_ok=False)
(a.output / 'images').mkdir()
images = {}
excluded = collections.Counter()
for line in a.candidates.read_text().splitlines():
    timestamp, size, filename = line.split('\t', 2)
    timestamp = float(timestamp)
    path = Path(filename)
    if not start <= timestamp <= a.end:
        excluded['outside_window'] += 1
        continue
    parts = path.parts
    if path.is_relative_to(base):
        rel = path.relative_to(base)
        root = rel.parts[0]
        if not root.startswith('cocs-'):
            excluded['other_project'] += 1
            continue
        tail = Path(*rel.parts[1:])
        # Fresh worktree checkout mtimes do not establish fresh captures.
        original = canonical / tail
        if root != canonical.name and '-evidence-' not in root and original.is_file():
            if original.stat().st_mtime < start:
                excluded['historical_checkout_copy'] += 1
                continue
        if not any(s in str(tail).lower() for s in ('evidence', 'capture', 'screenshot', 'verification', 'render', 'inspection')) and '-evidence-' not in root:
            excluded['runtime_asset_or_non_capture'] += 1
            continue
        group = root.removeprefix('cocs-')
        label = str(tail)
    elif path.is_relative_to(Path('/tmp/opencode')):
        rel = path.relative_to('/tmp/opencode')
        if not rel.parts[0].startswith(('campaign-ui-verification', 'modes-engine-', 'benchmark-autostart-gate', 'cocs-')):
            excluded['other_project'] += 1
            continue
        group, label = rel.parts[0], str(Path(*rel.parts[1:]))
    else:
        excluded['outside_game_roots'] += 1
        continue
    if any(s in parts for s in ('.git', 'node_modules', '.godot')):
        excluded['cache'] += 1
        continue
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    frame = bool(re.search(r'(?:^|/)(?:frame[-_]?\d+|\d{4,})\.', label, re.I))
    occurrence = {'path': filename, 'label': label, 'group': group, 'mtime': timestamp, 'kind': 'Capture frame' if frame else 'Screenshot'}
    if digest in images:
        images[digest]['sources'].append(occurrence)
        # Prefer a named screenshot to an identical numbered video frame.
        if images[digest]['kind'] == 'Capture frame' and not frame:
            images[digest].update(occurrence)
        continue
    name = digest + path.suffix.lower()
    (a.output / 'images' / name).write_bytes(data)
    images[digest] = {**occurrence, 'url': 'images/' + name, 'sha256': digest, 'bytes': len(data), 'sources': [occurrence]}

items = sorted(images.values(), key=lambda x: x['mtime'], reverse=True)
manifest = {'start': start, 'end': a.end, 'timeBasis': 'File modification time; known historical worktree copies excluded. Copy/export time may differ from capture time.', 'items': items, 'excluded': dict(excluded)}
(a.output / 'manifest.json').write_text(json.dumps(manifest, separators=(',', ':')))
shutil.copyfile(Path(__file__).with_name('index.html'), a.output / 'index.html')
summary = {'uniqueImages': len(items), 'sourceFiles': sum(len(x['sources']) for x in items), 'kinds': dict(collections.Counter(x['kind'] for x in items)), 'groups': dict(collections.Counter(x['group'] for x in items)), 'bytes': sum(x['bytes'] for x in items), 'start': dt.datetime.fromtimestamp(start).astimezone().isoformat(), 'end': dt.datetime.fromtimestamp(a.end).astimezone().isoformat(), 'excluded': dict(excluded)}
(a.output / 'summary.json').write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
