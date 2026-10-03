"""Assemble closed, exact-final-asset journey evidence; never runs an authority."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path('/home/mojo/.tmp-on-disk/cocs-expansion-four-scenery-evidence-20261002/connected')
OUT = ROOT / 'port/expansion-four/scenery/production-f/journeys-final'
catalog = json.loads((ROOT / 'godot/biomes/expansion/catalog.json').read_text())
expected = {(chapter, False) for chapter in catalog['chapters']} | {('rootfall-verge', True)}
selected = {}
for directory in sorted(SOURCE.iterdir()):
    if not (directory / 'witness.json').is_file() or not (directory / 'journey.json').is_file():
        continue
    witness = json.loads((directory / 'witness.json').read_text())
    journey = json.loads((directory / 'journey.json').read_text())
    if not witness['success'] or journey['plan']['recipeHash'] != catalog['recipeSha256']:
        continue
    profile = next(row['viewport'] for row in journey['observations'] if 'viewport' in row)
    key = (journey['plan']['id'], profile[0] == 760)
    selected[key] = (directory, witness, journey)
assert set(selected) == expected, ('Incomplete final native profiles', set(selected), expected)
OUT.mkdir(exist_ok=True)
summary = []
for (chapter, compact), (directory, witness, journey) in sorted(selected.items()):
    assert witness['code'] == 0 and witness['closed'] and not witness['forced']
    assert witness['home']['code'] == 0 and witness['home']['closed'] and not witness['home']['forced']
    assert journey['success']
    for path, digest in witness['resources'].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, ('Stale journey GLB', path)
    evidence = witness['witness']
    assert evidence['blockedSamples'] == 0 and evidence['ack'] > 0 and evidence['shots'] > 0
    assert set(evidence['workshops']) == set(journey['plan']['workshops'])
    returned = next(row for row in journey['observations'] if row.get('returnedToStart'))
    destination = OUT / (chapter + ('-compact' if compact else '-wide'))
    destination.mkdir(exist_ok=True)
    files = []
    for path in sorted(directory.iterdir()):
        if not path.is_file(): continue
        data = path.read_bytes()
        files.append({'source': str(path), 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
        if path.suffix in ('.json', '.log') and path.name != 'native-live.log':
            shutil.copy2(path, destination / path.name)
        if path.name in ('ordinary-combat-0.png', 'source-camera-return.png', 'home-return.png'):
            shutil.copy2(path, destination / path.name)
    (destination / 'manifest.json').write_text(json.dumps(files, indent=2) + '\n')
    summary.append({'chapter': chapter, 'compact': compact, 'sourceElapsed': returned['sourceElapsed'],
                    'shots': evidence['shots'], 'ack': evidence['ack'], 'workshops': evidence['workshops'],
                    'clearSamples': evidence['clearSamples'], 'blockedSamples': evidence['blockedSamples'],
                    'nativeExit': witness['code'], 'homeExit': witness['home']['code'],
                    'returnedToStart': True, 'directory': str(destination.relative_to(ROOT))})
(OUT / 'summary.json').write_text(json.dumps({'recipeSHA256': catalog['recipeSha256'], 'accepted': False,
    'rendering': 'capture-paced llvmpipe; not continuous rendered playability', 'journeys': summary}, indent=2) + '\n')
print(json.dumps(summary, indent=2))
