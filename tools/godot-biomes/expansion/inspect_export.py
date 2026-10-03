"""Blender-independent GLB stream/PNG evidence, strict selective material rules."""
import hashlib
import json
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
rows = []
for path in sorted((ROOT / 'godot/biomes/expansion/art').glob('*.glb')):
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    binary = raw[28 + size:]
    streams = []
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert 'NORMAL' in primitive['attributes']
            assert 'TEXCOORD_0' in primitive['attributes']
            streams.append(primitive['attributes'])
    images = []
    for image in doc.get('images', []):
        view = doc['bufferViews'][image['bufferView']]
        data = binary[view.get('byteOffset', 0):view.get('byteOffset', 0) + view['byteLength']]
        target = Path('/tmp/opencode') / (image['name'] + '.png')
        target.write_bytes(data)
        images.append({'name': image['name'], 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'preview': str(target)})
    rows.append({'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(raw).hexdigest(), 'materials': doc['materials'], 'attributes': streams, 'images': images})
output = ROOT / 'port/expansion-four/scenery/production-f/representative-streams.json'
output.write_text(json.dumps(rows, indent=2) + '\n')
print(json.dumps([{'path': r['path'], 'images': r['images'], 'attributes': r['attributes']} for r in rows], indent=2))
