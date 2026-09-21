"""Read-only inventory of existing recorded evidence, not a gameplay test."""
from collections import Counter
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
path = root / 'godot/tests/protocol/captured.json'
data = json.loads(path.read_text())
counts = Counter()
dead = set()
for record in data['frames']:
    if record.get('direction') != 'server' or record.get('client') != 1:
        continue
    frame = record['frame']
    counts['frame:' + frame['type']] += 1
    for event in frame.get('items', []):
        counts['event:' + event['type']] += 1
    for actor in frame.get('state', {}).get('actors', []):
        if actor.get('dead', 0) > 0:
            dead.add(actor['id'])
print(json.dumps({'classification': 'recorded_replay', 'method': 'offline inventory only, no replay execution',
                  'capture_report': data['report'], 'client': 1,
                  'counts': dict(sorted(counts.items())), 'actors_seen_dead_in_retained_states': sorted(dead)}, indent=2))
