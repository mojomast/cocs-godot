"""Blender-independent GLB stream/PNG evidence, strict selective material rules."""
import hashlib
import json
import struct
import subprocess
import argparse
import math
from pathlib import Path
from compare_captures import pixels as decode_png

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='representative-streams.json')
parser.add_argument('--require-colors', action='store_true')
parser.add_argument('--asset')
args = parser.parse_args()
palette = json.loads((ROOT / 'tools/godot-biomes/expansion/meshes.json').read_text())['palette']
rows = []
for path in sorted((ROOT / 'godot/biomes/expansion/art').glob('*.glb')):
    if args.asset and path.stem not in (args.asset+'-0',args.asset+'-1'): continue
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    binary = raw[28 + size:]
    streams = []
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert 'NORMAL' in primitive['attributes']
            assert 'TEXCOORD_0' in primitive['attributes']
            accessor = doc['accessors'][primitive['attributes']['TEXCOORD_0']]
            assert accessor['componentType'] == 5126 and accessor['type'] == 'VEC2'
            view = doc['bufferViews'][accessor['bufferView']]
            offset = view.get('byteOffset',0)+accessor.get('byteOffset',0)
            uv = [struct.unpack_from('<ff',binary,offset+i*view.get('byteStride',8)) for i in range(accessor['count'])]
            assert all(math.isfinite(v) for pair in uv for v in pair)
            bounds = [[min(pair[i] for pair in uv),max(pair[i] for pair in uv)] for i in range(2)]
            assert all(hi>lo for lo,hi in bounds), 'Collapsed surface UV'
            streams.append({'attributes': primitive['attributes'], 'uvBounds':bounds})
    images = []
    for image in doc.get('images', []):
        view = doc['bufferViews'][image['bufferView']]
        data = binary[view.get('byteOffset', 0):view.get('byteOffset', 0) + view['byteLength']]
        target = Path('/tmp/opencode') / (image['name'] + '.png')
        target.write_bytes(data)
        width, height, channels, decoded = decode_png(target)
        rgb = [[row[i] for row in decoded for i in range(channel,len(row),channels)] for channel in range(3)]
        means = [sum(values)/len(values) for values in rgb]
        ranges = [[min(values),max(values)] for values in rgb]
        assert any(hi>lo for lo,hi in ranges), 'Flat texture: '+image['name']
        item = {'name': image['name'], 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'preview': str(target), 'meanRGB': means, 'rangeRGB': ranges}
        if image['name'].startswith('MothLocal_biome4_'):
            role = image['name'].removeprefix('MothLocal_biome4_')
            color = palette[role][0]
            expected = [int(color[i:i+2],16) for i in (0,2,4)]
            item['authoredSRGB'] = expected
            item['maxSwatchDifference'] = max(abs(a-b) for a,b in zip(means,expected))
            if args.require_colors: assert item['maxSwatchDifference'] < 12, item
        images.append(item)
    rows.append({'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(raw).hexdigest(), 'materials': doc['materials'], 'attributes': streams, 'images': images})
assert rows, 'No actual exports selected'
if args.require_colors:
    assert len(rows) == (2 if args.asset else 24)
output = ROOT / 'port/expansion-four/scenery/production-f' / args.output
output.write_text(json.dumps(rows, indent=2) + '\n')
print(json.dumps([{'path': r['path'], 'images': r['images'], 'attributes': r['attributes']} for r in rows], indent=2))
